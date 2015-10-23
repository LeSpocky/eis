#!/bin/sh
# ---------------------------------------------------------------------------
# /var/install/config.d/cui-openntpd.sh - configuration generator script
#
# Copyright (c) 2001-2015 The eisfair Team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ---------------------------------------------------------------------------

# read eislib
. /var/install/include/eislib

#exec 2>/var/install/config.d/ntp-trace-$$.log
#set -x

pgmname=`basename $0`
packageName=openntpd


### set file names ###
ntpConfigfile=/etc/config.d/${packageName}
ntpDriftfile=/etc/ntp.drift
ntpLogfile=/var/log/ntp.log
generate_ntpconf=/etc/ntp.conf
generate_ntplinks=/etc/ntp.links
generate_logrotate=/etc/logrotate.d/ntp

### other parameters ###
packageVersion=$(apk info cui-${packageName} -d | grep description | sort -u -r | head -n1 | cut -d ' ' -f1)

### load configuration ###
. ${ntpConfigfile}
chmod 600 ${ntpConfigfile}

# ---------------------------------------------------------------------------
# Check NTP_LINK_N and delete the old links device
# ---------------------------------------------------------------------------
delete_oldlinkdevice () {
    if [ -f ${generate_ntplinks} ] ; then
        . ${generate_ntplinks}

        idx=1
        while [ ${idx} -le ${NTP_LINK_N} ] ; do
            eval softlinkdevice='$NTP_LINK_'${idx}
            if [ -n "$softlinkdevice" ] ; then
                mecho -n "Removing soft link '${softlinkdevice}'..."
                rm -f ${softlinkdevice}
                mecho " Done."
            fi
            idx=$((idx+1))
        done
    fi
}



# ---------------------------------------------------------------------------
# create NTP configuration file /etc/ntp.conf
# ---------------------------------------------------------------------------
create_ntpconf () {
    mecho -n "Creating ntp configuration file..."

    {
        # ---------------------------------------------------------------------------
        print_short_header "$generate_ntpconf" "$pgmname" "${packageVersion}"
        # ---------------------------------------------------------------------------

        idx=1
        while [ ${idx} -le ${NTP_CLOCK_N} ] ; do
            eval clock_type='$NTP_CLOCK_'${idx}'_TYPE'
            eval clock_prefer='$NTP_CLOCK_'${idx}'_PREFER'
            eval clock_link_device_nbr='$NTP_CLOCK_'${idx}'_LINK_DEVICE_NBR'
            eval clock_stratum='$NTP_CLOCK_'${idx}'_STRATUM'

            # --------------------------------------------------------------
            # Split the clock type here because if it is of type '8' it will
            # be folled by another number, which leads to an error on the 
            # next test.
            local mode=$(echo ${clock_type} | cut -d " " -f 2)
            clock_type=$(echo ${clock_type} | cut -d " " -f 1)
            if [ ${clock_type} -eq 1 ] ; then
                echo "server    127.127.$clock_type.1"

                if [ -n "$clock_stratum" ] ; then
                    echo "fudge     127.127.$clock_type.1 stratum $clock_stratum"
                fi
            else
                # --------------------------------------------------------
                # If NTP_CLOCK_%_PREFER='yes', setup additional parameter.
                # Otherwise clear it.
                if [ "${clock_prefer}" = "yes" ] ; then
                    prefer='prefer'
                else
                    prefer=''
                fi
                
                # ------------------
                # Write server setup
                if [ -n ${clock_type} -a ${clock_type} -ge 1 -a ${clock_type} -le 7 ] || [ -n ${clock_type} -a ${clock_type} -ge 9 -a ${clock_type} -le 44 ] ; then
                    # -------------------------------------
                    # It's a clock type between 1-7 or 9-44
                    echo "server    127.127.$clock_type.$clock_link_device_nbr ${prefer}"
                else
                    # --------------------------------------------------------
                    # It's a clock of type 8, which requires the 'mode' option
                    if [ -n ${mode} -a ${mode} -ge 0 -a ${mode} -le 17 ] ; then
                        # -------------------------------------------------------------
                        # 'mode' option is in the correct range 1-17, so write settings
                        echo "server    127.127.$clock_type.$clock_link_device_nbr mode ${mode} ${prefer}" 
                    fi
                fi

                if [ -n "$clock_stratum" ] ; then
                    echo "fudge     127.127.$clock_type.$clock_link_device_nbr stratum $clock_stratum"
                fi
            fi

            idx=$((idx+1))
        done

        idx=1
        while [ ${idx} -le ${NTP_SERVER_N} ] ; do
            eval server='$NTP_SERVER_'${idx}
            echo "server    $server"
            idx=$((idx+1))
        done

        idx=1
        while [ ${idx} -le ${NTP_PEER_N} ] ; do
            eval peer='$NTP_PEER_'${idx}
            echo "peer      $peer"
            idx=$((idx+1))
        done

        echo
        echo "driftfile ${ntpDriftfile}"
        echo "logfile   ${ntpLogfile}"
        
        # ---------------------------------------
        # Write the log config, the events to log
        echo -n "logconfig ="
        separator=''
        idx=1
        while [ ${idx} -le ${NTP_LOG_EVENT_N} ] ; do
            eval currentEvent='$NTP_LOG_EVENT_'${idx}'_ENTRY'
            echo -n "${separator}${currentEvent}"
            separator=' +'
            idx=$((idx+1))
        done
        echo ""

        idx=1
        while [ ${idx} -le ${NTP_ADD_PARAM_N} ] ; do
            eval addparam='$NTP_ADD_PARAM_'${idx}

            echo "$addparam"

            idx=$((idx+1))
        done
    } >${generate_ntpconf}
    mecho " Done."
}



# ---------------------------------------------------------------------------
# Create NTP Links File /etc/ntp.links
# ---------------------------------------------------------------------------
create_ntplinks () {

    mecho -n "Creating ntp links file..."

    {
        # ---------------------------------------------------------------------------
        print_short_header "$generate_ntplinks" "$pgmname" "${packageVersion}"
        # ---------------------------------------------------------------------------

        idx=1
        jdx=0
        while [ ${idx} -le $NTP_CLOCK_N ]
        do
            eval clock_device='$NTP_CLOCK_'${idx}'_DEVICE'
            eval clock_link_device='$NTP_CLOCK_'${idx}'_LINK_DEVICE''$NTP_CLOCK_'${idx}'_LINK_DEVICE_NBR'

            if [ "$clock_device" != "" ] && [ "$clock_link_device" != "" ] ; then
                jdx=$((jdx+1))
            fi

            idx=$((idx+1))
        done

        echo "NTP_LINK_N='$jdx'"

        idx=1
        jdx=0
        while [ ${idx} -le $NTP_CLOCK_N ]
        do
            eval clock_device='$NTP_CLOCK_'${idx}'_DEVICE'
            eval clock_link_device='$NTP_CLOCK_'${idx}'_LINK_DEVICE''$NTP_CLOCK_'${idx}'_LINK_DEVICE_NBR'

            if [ -n "$clock_device" ] && [ -n "$clock_link_device" ] ; then
                jdx=$((jdx+1))
                echo "NTP_DEVICE_${jdx}='$clock_device'"
                echo "NTP_LINK_${jdx}='$clock_link_device'"
            fi

            idx=$((idx+1))
        done
    } >${generate_ntplinks}
    mecho " Done."
}



# ------------------------------------------------------------------------------
# Create NTP link device
# ------------------------------------------------------------------------------
create_ntplinkdevice () {
    idx=1
    while [ ${idx} -le ${NTP_CLOCK_N} ]
    do
        eval clock_device='$NTP_CLOCK_'${idx}'_DEVICE'
        eval clock_link_device='$NTP_CLOCK_'${idx}'_LINK_DEVICE''$NTP_CLOCK_'${idx}'_LINK_DEVICE_NBR'

        if [ -n "$clock_device" ] && [ -n "$clock_link_device" ] ; then
            mecho "Creating soft link '${clock_device}' to '${clock_link_device}'..."
            ln -sf ${clock_device} ${clock_link_device}
            mecho " Done."
        fi
        idx=$((idx+1))
    done
}



# ------------------------------------------------------------------------------------
# Create logrotate file
# ------------------------------------------------------------------------------------
create_logrotate () {
    mecho -n "Creating logrotate configuration file..."

    {
        # ---------------------------------------------------------------------------
        print_short_header "$generate_logrotate" "$pgmname" "${packageVersion}"
        # ---------------------------------------------------------------------------

        if [ "$START_NTP" = "yes" ] ; then
            echo "${ntpLogfile} {"
            echo "    rotate $NTP_LOG_COUNT"
            echo "    $NTP_LOG_INTERVAL"
            echo "    compress"
            echo "    missingok"
            echo "    notifempty"
            echo "    postrotate"
            echo "        /etc/init.d/ntp --quiet restart"
            echo "    endscript"
            echo "    }"
            echo
        else
            echo "# NTP disabled!"
        fi
    } >${generate_logrotate}
    mecho " Done."
}

#===============================================================================
# Main
#===============================================================================

mecho
mecho "Package version: ${packageVersion}"

delete_oldlinkdevice
create_ntpconf
create_ntplinks
create_ntplinkdevice
create_logrotate

mecho -info "Finished."

exit 0
