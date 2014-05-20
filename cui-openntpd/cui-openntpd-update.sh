#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-openntpd-update.sh - update or generate a new ntp
#                                                configuration
#
# Copyright (c) 2001-2014 The Eisfair Team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

# include eislib
. /var/install/include/eislib
. /var/install/include/configlib

#-----------------------------------------------------------------------------
# rename variables
#-----------------------------------------------------------------------------
rename_variables ()
{
    renamed=0
    mecho -n "Renaming parameter(s)... "

    # v0.90.2
    if [ $NTP_CLOCK_N -eq 0 ]
    then
        imax=1
    else
        imax=$NTP_CLOCK_N
    fi

    renamedParams=false
    idx=1
    while [ $idx -le $imax ]
    do
        if [ ! -z "`grep ^NTP_CLOCK_${idx}_LINK_DEVICE_N= $source_conf`" ]
        then
            eval ntp_link_device_nbr='$NTP_CLOCK_'${idx}'_LINK_DEVICE_N'

            echo "- NTP_CLOCK_${idx}_LINK_DEVICE_N -> NTP_CLOCK_${idx}_LINK_DEVICE_NBR"
            eval NTP_CLOCK_${idx}_LINK_DEVICE_NBR="$ntp_link_device_nbr"
            renamedParams=true
        fi
        
        # ------------------------------------------------------
        # Transfer 'NTP_CLOCK_%_MODE' if 'NTP_CLOCK_%_TYPE' == 8
        eval currentClockType='$NTP_CLOCK_'${idx}'_TYPE'
        currentClockMode=`echo ${currentClockType} | cut -d " " -f2`
        currentClockType=`echo ${currentClockType} | cut -d " " -f1`
        if [ "${currentClockType}" = '8' ]
        then
            eval preferCurrentClock='$NTP_CLOCK_'${idx}'_PREFER'
            if [ -z "${preferCurrentClock}" ]
            then
                # ------------------------------------------------------------
                # $NTP_CLOCK_'${idx}'_PREFER not found, so this must be an old
                # installation with the other setup method for the clock mode
                eval currentClockMode='$NTP_CLOCK_'${idx}'_MODE'
                
                # ---------------------------------------------------------------
                # Now search the string 'prefer' and de-/activate the new setting
                echo "${currentClockMode}" | grep prefer > /dev/null 2>&1
                if [ $? -eq 0 ]
                then
                    eval NTP_CLOCK_${idx}_PREFER='yes'
                else
                    eval NTP_CLOCK_${idx}_PREFER='no'
                fi
                
                # ----------------------------------------------------------
                # Set default value for the case that no mode could be found
                if [ -z "${currentClockMode}" ]
                then
                    eval NTP_CLOCK_${idx}_TYPE="'${currentClockType} 14'"
                fi
                
                # --------------------------
                # Now detect the mode to use
                modeEntries=`echo ${currentMode} | wc -w`
                modeIdx=1
                while [ ${modeIdx} -le ${modeEntries} ]
                do
                    modeToUse=`echo ${currentMode} | cut -d " " -f ${modeIdx}`
                    # ----------------------------------------------------------
                    # Check if it is a number. If so, use it as the mode number.
                    expr ${modeToUse} + 0 > /dev/null 2>&1
                    if [ $? -lt 3 ]
                    then
                        eval NTP_CLOCK_${idx}_TYPE="'${currentClockType} ${modeToUse}'"
                        break
                    fi
                    modeIdx=$((modeIdx+1))
                done
            fi
        else
            # ----------------------------------
            # Set parameter for all other clocks
            eval NTP_CLOCK_${idx}_PREFER='no'
        fi
        
        idx=`expr $idx + 1`
    done
    
    # ------------------------------------------------------
    # V1.1.1 - Added cui script to choose log events, so the 
    # old var 'NTP_LOG_CONFIG' must be removed
    if [ -n "${NTP_LOG_CONFIG}" ]
    then
        idx=0
        for currentLogConfigParam in ${NTP_LOG_CONFIG}
        do
            if [ "${currentLogConfigParam}" != "+" ]
            then
                idx=$((idx+1))
                eval NTP_LOG_EVENT_${idx}_ENTRY="${currentLogConfigParam}"
            fi
        done
        NTP_LOG_EVENT_N=${idx}
        renamedParams=true
    fi


    if ${renamedParams}
    then
        mecho "Done."
    else
        mecho "Nothing renamed, parameters up to date."
    fi
}



#-----------------------------------------------------------------------------
# modify variables
#-----------------------------------------------------------------------------
modify_variables ()
{
    modifiedParams=false
    mecho -n "Modifying parameter(s)... "

    if ${modifiedParams}
    then
        mecho "Done."
    else
        mecho "Nothing modified, parameters up to date."
    fi
}



#-----------------------------------------------------------------------------
# add variables
#-----------------------------------------------------------------------------
add_variables ()
{
    addedParams=false
    mecho -n "Adding new parameter(s)... "

    # v0.90.2
    if [ -z "`grep ^NTP_LOG_COUNT $source_conf`" ]
    then
#        echo "- NTP_LOG_COUNT='10'"
        NTP_LOG_COUNT='10'
        addedParams=true
    fi

    if [ -z "`grep ^NTP_LOG_INTERVAL $source_conf`" ]
    then
#        echo "- NTP_LOG_INTERVAL='weekly'"
        NTP_LOG_INTERVAL='weekly'
        addedParams=true
    fi

    if [ -z "${NTP_PEER_N}" ]
    then
        NTP_PEER_N=0
        NTP_PEER_1=''
        addedParams=true
    fi

    if ${addedParams}
    then
        mecho "Done."
    else
        mecho "No new parameters available."
    fi
}



#-----------------------------------------------------------------------------
# delete variables
#-----------------------------------------------------------------------------
delete_variables ()
{
    deleted=0
    mecho -n "Removing old parameters... "

    for varname in NTP_DRIFT_FILE NTP_LOG_FILE NTP_LOG_ROTATE NTP_MAX_LOGSIZE
    do
        if [ ! -z "`grep \"^$varname\" $source_conf`" ]
        then
#            echo "- $varname"
            deleted=1
        fi
    done

    if [ ${deleted} -eq 1 ]
    then
        mecho "Done."
    else
        mecho "Nothing to remove, parameters up to date."
    fi
}



#-----------------------------------------------------------------------------
# create new configuration
#-----------------------------------------------------------------------------
create_config ()
{
    config_level="$1"

    mecho -n "Updating/creating configuration... "

    {
        #---------------------------------------------------------------------
        printgpl "ntp" "27.12.2003" "jed" "Copyright (c) 2001-2006 The Eisfair Team, team(at)eisfair(dot)org"
        #---------------------------------------------------------------------
        printgroup "NTP configuration"
        #--------------------------------------------------------------------------------
        printvar "START_NTP" "use ntp: yes or no"
        cat << EOF
#-----------------------------------------------------------------------------
# Clock types
#
# NTP_CLOCK_#_TYPE  
# |
# |    Comprehensive list of clock drivers
# 1    Type  1 - undisciplined local clock (LOCAL)
# 2    Type  2 - Trak 8820 GPS receiver (GPS_TRAK)
# 3    Type  3 - PSTI/Traconex 1020 WWV/WWVH receiver (WWV_PST)
# 4    Type  4 - Spectracom WWVB and GPS receivers (WWVB_SPEC)
# 5    Type  5 - TrueTime GPS/GOES/OMEGA receivers (TRUETIME)
# 6    Type  6 - IRIG audio decoder (IRIG_AUDIO)
# 7    Type  7 - radio CHU audio demodulator/decoder (CHU)
#      Type  8 - generic reference driver (PARSE)
# 8 0            * server 127.127.8.0-3 mode 0
#                Meinberg PZF535/PZF509 receiver (FM demodulation/TCXO / 50us)
# 8 1            * server 127.127.8.0-3 mode 1
#                Meinberg PZF535/PZF509 receiver (FM demodulation/OCXO / 50us)
# 8 2            * server 127.127.8.0-3 mode 2
#                Meinberg DCF U/A 31/DCF C51 receiver (AM demodulation / 4ms)
# 8 3            * server 127.127.8.0-3 mode 3
#                ELV DCF7000 (sloppy AM demodulation / 50ms)
# 8 4            * server 127.127.8.0-3 mode 4
#                Walter Schmid DCF receiver Kit (AM demodulation / 1ms)
# 8 5            * server 127.127.8.0-3 mode 5
#                RAW DCF77 100/200ms pulses (Conrad DCF77 receiver module / 5ms)
# 8 6            * server 127.127.8.0-3 mode 6
#                RAW DCF77 100/200ms pulses (TimeBrick DCF77 receiver module / 5ms)
# 8 7            * server 127.127.8.0-3 mode 7
#                Meinberg GPS166/GPS167 receiver (GPS / <<1us)
# 8 8            * server 127.127.8.0-3 mode 8
#                IGEL clock
# 8 9            * server 127.127.8.0-3 mode 9
#                Trimble SVeeSix GPS receiverTAIP protocol (GPS / <<1us)
# 8 10           * server 127.127.8.0-3 mode 10
#                Trimble SVeeSix GPS receiver TSIP protocol (GPS / <<1us) (no kernel support yet)
# 8 11           * server 127.127.8.0-3 mode 11
#                Radiocode Clocks Ltd RCC 8000 Intelligent Off-Air master clock support
# 8 12           * server 127.127.8.0-3 mode 12
#                HOPF Funkuhr 6021
# 8 13           * server 127.127.8.0-3 mode 13
#                Diem's Computime radio clock
# 8 14           * server 127.127.8.0-3 mode 14
#                RAWDCF receiver (DTR=high/RTS=low)
#                e. g. Expert mouseCLOCK
# 8 15           * server 127.127.8.0-3 mode 15
#                WHARTON 400A Series Clocks with a 404.2 serial interface
# 8 16           * server 127.127.8.0-3 mode 16
#                RAWDCF receiver (DTR=low/RTS=high)
# 8 17           * server 127.127.8.0-3 mode 17
#                VARITEXT receiver (MSF)
# 9    Type  9 - Magnavox MX4200 GPS receiver (GPS_MX4200)
# 10   Type 10 - Austron 2200A/2201A GPS receivers (GPS_AS2201)
# 11   Type 11 - Arbiter 1088A/B GPS receiver (GPS_ARBITER)
# 12   Type 12 - KSI/Odetics TPRO/S IRIG interface (IRIG_TPRO)
# 13   Type 13 - Leitch CSD 5300 master clock controller (ATOM_LEITCH)
# 14   Type 14 - EES M201 MSF receiver (MSF_EES)
# 15   Type 15 - TrueTime generic receivers
# 16   Type 16 - Bancomm GPS/IRIG receiver (GPS_BANCOMM)
# 17   Type 17 - Datum Precision time system (GPS_DATUM)
# 18   Type 18 - NIST Modem time service (ACTS_NIST)
# 19   Type 19 - Heath WWV/WWVH receiver (WWV_HEATH)
# 20   Type 20 - Generic NMEA GPS receiver (NMEA)
# 21   Type 21 - TrueTime GPS-VME interface (GPS_VME)
# 22   Type 22 - PPS Clock Discipline (PPS)
# 23   Type 23 - PTB Modem time service (ACTS_PTB)
# 24   Type 24 - USNO Modem time service (ACTS_USNO)
# 25   Type 25 - * TrueTime generic receivers
# 26   Type 26 - Hewlett Packard 58503A GPS receiver (GPS_HP)
# 27   Type 27 - Arcron MSF receiver (MSF_ARCRON)
# 28   Type 28 - Shared memory driver (SHM)
# 29   Type 29 - Trimble Navigation Palisade GPS (GPS_PALISADE)
# 30   Type 30 - Motorola UT Oncore GPS GPS_ONCORE)
# 31   Type 31 - Rockwell Jupiter GPS (GPS_JUPITER)
# 32   Type 32 - Chrono-log K-series WWVB receiver (CHRONOLOG)
# 33   Type 33 - Dumb Clock (DUMBCLOCK)
# 34   Type 34 - Ultralink WWVB receivers (ULINK)
# 35   Type 35 - Conrad Parallel port radio clock (PCF)
# 36   Type 36 - Radio WWV/H audio demodulator/decoder (WWV)
# 37   Type 37 - Forum Graphic GPS dating station (FG)
# 38   Type 38 - hopf GPS/DCF77 6021/komp for serial line (HOPF_S)
# 39   Type 39 - hopf GPS/DCF77 6039 for PCI-Bus (HOPF_P)
# 40   Type 40 - JJY receivers (JJY)
# 41   Type 41 - TrueTime 560 IRIG-B decoder
# 42   Type 42 - Zyfer GPStarplus receiver
# 43   Type 43 - RIPE NCC interface for Trimble Palisade
# 44   Type 44 - NeoClock4X - DCF77 / TDF serial line
#
# For additionally Information look at:
# http://www.eecis.udel.edu/~mills/ntp/html/refclock.html
#
EOF
        #---------------------------------------------------------------------
        printgroup "Clock settings"
        #---------------------------------------------------------------------
        printvar "NTP_CLOCK_N" "Nbr of clock's"

        if [ $NTP_CLOCK_N -eq 0 ]
        then
            if [ "$config_level" = "update" ]
            then
                imax=3
            else
                imax=1
            fi
        else
            imax=$NTP_CLOCK_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "NTP_CLOCK_${idx}_TYPE"            "${idx}. clock type"
            printvar "NTP_CLOCK_${idx}_PREFER"          "   prefer this clock?"
            printvar "NTP_CLOCK_${idx}_DEVICE"          "   clock device, default: ''"
            printvar "NTP_CLOCK_${idx}_LINK_DEVICE"     "   clock link device, default: ''"
            printvar "NTP_CLOCK_${idx}_LINK_DEVICE_NBR" "   clock link device dumber, default: ''"
            printvar "NTP_CLOCK_${idx}_STRATUM"         "   clock stratum, default: ''"
            echo
            idx=`expr $idx + 1`
        done

        #---------------------------------------------------------------------
        printgroup "Peers to synchronize with"
        #---------------------------------------------------------------------
        printvar "NTP_PEER_N" "Nbr of peers"

        if [ ${NTP_PEER_N} -eq 0 ]
        then
            if [ "${config_level}" = "update" ]
            then
                imax=2
            else
                imax=0
            fi
        else
            imax=${NTP_PEER_N}
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "NTP_PEER_${idx}" "${idx}. NTP peer"
            idx=`expr $idx + 1`
        done

        #---------------------------------------------------------------------
        printgroup "Inside server settings -- Server's to include into the peer"
        #---------------------------------------------------------------------
        printvar "NTP_SERVER_N" "Nbr of server's"

        if [ $NTP_SERVER_N -eq 0 ]
        then
            if [ "$config_level" = "update" ]
            then
                imax=2
            else
                imax=0
            fi
        else
            imax=$NTP_SERVER_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "NTP_SERVER_${idx}" "${idx}. NTP server"

            idx=`expr $idx + 1`
        done

        #---------------------------------------------------------------------
        printgroup "Outside server settings -- Server's used for synchronization via menu"
        #---------------------------------------------------------------------
        printvar "NTP_SET_SERVER_N" "Nbr of server's"

        if [ $NTP_SET_SERVER_N -eq 0 ]
        then
            if [ "$config_level" = "update" ]
            then
                imax=2
            else
                imax=0
            fi
        else
            imax=$NTP_SET_SERVER_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "NTP_SET_SERVER_${idx}" "${idx}. NTP server"
            idx=`expr $idx + 1`
        done

        #---------------------------------------------------------------------
        printgroup "Additional parameter" "*** YOU SHOULD NOW WHAT YOU DO, USE IT ON YOUR OWN RISK !!! ***"
        #---------------------------------------------------------------------
        printvar "NTP_ADD_PARAM_N" "Nbr of additional parameter"

        if [ $NTP_ADD_PARAM_N -eq 0 ]
        then
            if [ "$config_level" = "update" ]
            then
                imax=5
            else
                imax=0
            fi
        else
            imax=$NTP_ADD_PARAM_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "NTP_ADD_PARAM_${idx}" "${idx}. parameter"

            idx=`expr $idx + 1`
        done

        cat << EOF
#-----------------------------------------------------------------------------
# log handling
#
# Here you can specify how many logs should be saved and in with interval.
#
# Example:
#   NTP_LOG_EVENT_N='1'           - Amount of different log events to log
#   NTP_LOG_EVENT_1_ENTRY='all'   - Log all events
#   NTP_LOG_COUNT='10'            - Save the last 10 log files
#   NTP_LOG_INTERVAL='daily'      - Save one log file per day
#-----------------------------------------------------------------------------
EOF
        printvar "NTP_LOG_EVENT_N"    "Amount of different log events to log"
        idx=1
        while [ ${idx} -le ${NTP_LOG_EVENT_N} ]
        do
            printvar "NTP_LOG_EVENT_${idx}_ENTRY" "Event type to log: all, syncstatus, sysevents, syncall, clockall"
            idx=$((idx+1))
        done
        printvar "NTP_LOG_COUNT"      "Nbr of log files to save"
        printvar "NTP_LOG_INTERVAL"   "Interval: daily, weekly, monthly"
        #---------------------------------------------------------------------
        printend
        #---------------------------------------------------------------------
    } > $generate_conf

    mecho " Done."
    anykey
}

#==============================================================================
# main
#==============================================================================

LOGNAME='jed'

#testroot=/cvs/eis/etc/ntp
 testroot=''

ntpfile=$testroot/etc/config.d/ntp
installfile=$testroot/var/run/ntp.install

# setting defaults
source_conf=$installfile
generate_conf=$ntpfile

goflag=0

case "$1"
in
    update)
        goflag=1
        ;;

    test)
      # source_conf=$ntpfile
        source_conf=$testroot/etc/default.d/ntp

      # generate_conf=$testroot/tmp/config.d/mk_ntp.test
        generate_conf=$testroot/tmp/mk_ntp.test
        goflag=1
        ;;

    *)
        mecho
        mecho "Use one of the following options:"
        mecho
        mecho "  ntp-update.sh [update] - the file $ntpfile.import will be read, the configuration will"
        mecho "                           be checked and an updated mail configuration file will be written."
        mecho
        goflag=0
esac

if [ $goflag -eq 1 ]
then
    if [ -f $source_conf ]
    then
        # previous configuration file exists
        mecho -info "previous configuration found ..."
        . $source_conf

        rename_variables
        modify_variables
        add_variables
        delete_variables

        create_config update
    else
        mecho -error "no configuration $source_conf found - exiting."
        anykey
    fi
fi

#==============================================================================
# end
#==============================================================================
