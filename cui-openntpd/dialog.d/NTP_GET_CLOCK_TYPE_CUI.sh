#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/dialog.d/NTP_GET_CLOCK_TYPE_CUI.sh - script dialog for ece
#
# Copyright (c) 2001-2014 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

# ----------------------------------------------------------------------------
# control constants
# ----------------------------------------------------------------------------
IDC_LISTBOX='10'
IDC_BUTOK='100'
IDC_BUTCANCEL='100'

# ----------------------------------------------------------------------------
# Definition of known clock types
# ----------------------------------------------------------------------------
 clockType[1]='Type  1 - undisciplined local clock (LOCAL)'
 clockType[2]='Type  2 - Trak 8820 GPS receiver (GPS_TRAK)'
 clockType[3]='Type  3 - PSTI/Traconex 1020 WWV/WWVH receiver (WWV_PST)'
 clockType[4]='Type  4 - Spectracom WWVB and GPS receivers (WWVB_SPEC)'
 clockType[5]='Type  5 - TrueTime GPS/GOES/OMEGA receivers (TRUETIME)'
 clockType[6]='Type  6 - IRIG audio decoder (IRIG_AUDIO)'
 clockType[7]='Type  7 - radio CHU audio demodulator/decoder (CHU)'
 clockType[8]='Type  8 - generic reference driver (PARSE) mode 0'
 clockType[9]='Type  8 - generic reference driver (PARSE) mode 1'
clockType[10]='Type  8 - generic reference driver (PARSE) mode 2'
clockType[11]='Type  8 - generic reference driver (PARSE) mode 3'
clockType[12]='Type  8 - generic reference driver (PARSE) mode 4'
clockType[13]='Type  8 - generic reference driver (PARSE) mode 5'
clockType[14]='Type  8 - generic reference driver (PARSE) mode 6'
clockType[15]='Type  8 - generic reference driver (PARSE) mode 7'
clockType[16]='Type  8 - generic reference driver (PARSE) mode 8'
clockType[17]='Type  8 - generic reference driver (PARSE) mode 9'
clockType[18]='Type  8 - generic reference driver (PARSE) mode 10'
clockType[19]='Type  8 - generic reference driver (PARSE) mode 11'
clockType[20]='Type  8 - generic reference driver (PARSE) mode 12'
clockType[21]='Type  8 - generic reference driver (PARSE) mode 13'
clockType[22]='Type  8 - generic reference driver (PARSE) mode 14'
clockType[23]='Type  8 - generic reference driver (PARSE) mode 15'
clockType[24]='Type  8 - generic reference driver (PARSE) mode 16'
clockType[25]='Type  8 - generic reference driver (PARSE) mode 17'
clockType[26]='Type  9 - Magnavox MX4200 GPS receiver (GPS_MX4200)'
clockType[27]='Type 10 - Austron 2200A/2201A GPS receivers (GPS_AS2201)'
clockType[28]='Type 11 - Arbiter 1088A/B GPS receiver (GPS_ARBITER)'
clockType[29]='Type 12 - KSI/Odetics TPRO/S IRIG interface (IRIG_TPRO)'
clockType[30]='Type 13 - Leitch CSD 5300 master clock controller (ATOM_LEITCH)'
clockType[31]='Type 14 - EES M201 MSF receiver (MSF_EES)'
clockType[32]='Type 15 - TrueTime generic receivers'
clockType[33]='Type 16 - Bancomm GPS/IRIG receiver (GPS_BANCOMM)'
clockType[34]='Type 17 - Datum Precision time system (GPS_DATUM)'
clockType[35]='Type 18 - NIST Modem time service (ACTS_NIST)'
clockType[36]='Type 19 - Heath WWV/WWVH receiver (WWV_HEATH)'
clockType[37]='Type 20 - Generic NMEA GPS receiver (NMEA)'
clockType[38]='Type 21 - TrueTime GPS-VME interface (GPS_VME)'
clockType[39]='Type 22 - PPS Clock Discipline (PPS)'
clockType[40]='Type 23 - PTB Modem time service (ACTS_PTB)'
clockType[41]='Type 24 - USNO Modem time service (ACTS_USNO)'
clockType[42]='Type 25 - * TrueTime generic receivers'
clockType[43]='Type 26 - Hewlett Packard 58503A GPS receiver (GPS_HP)'
clockType[44]='Type 27 - Arcron MSF receiver (MSF_ARCRON)'
clockType[45]='Type 28 - Shared memory driver (SHM)'
clockType[46]='Type 29 - Trimble Navigation Palisade GPS (GPS_PALISADE)'
clockType[47]='Type 30 - Motorola UT Oncore GPS GPS_ONCORE)'
clockType[48]='Type 31 - Rockwell Jupiter GPS (GPS_JUPITER)'
clockType[49]='Type 32 - Chrono-log K-series WWVB receiver (CHRONOLOG)'
clockType[50]='Type 33 - Dumb Clock (DUMBCLOCK)'
clockType[51]='Type 34 - Ultralink WWVB receivers (ULINK)'
clockType[52]='Type 35 - Conrad Parallel port radio clock (PCF)'
clockType[53]='Type 36 - Radio WWV/H audio demodulator/decoder (WWV)'
clockType[54]='Type 37 - Forum Graphic GPS dating station (FG)'
clockType[55]='Type 38 - hopf GPS/DCF77 6021/komp for serial line (HOPF_S)'
clockType[56]='Type 39 - hopf GPS/DCF77 6039 for PCI-Bus (HOPF_P)'
clockType[57]='Type 40 - JJY receivers (JJY)'
clockType[58]='Type 41 - TrueTime 560 IRIG-B decoder'
clockType[59]='Type 42 - Zyfer GPStarplus receiver'
clockType[60]='Type 43 - RIPE NCC interface for Trimble Palisade'
clockType[61]='Type 44 - NeoClock4X - DCF77 / TDF serial line'


#----------------------------------------------------------------------------
#  ok_button_clicked
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
#----------------------------------------------------------------------------

function ok_button_clicked()
{
    local dlg="$p2"
    local ctrl="$p3"
    local index="3"
    local closeDialog=true

    cui_window_getctrl $dlg $IDC_LISTBOX
    cui_listbox_getsel $p2
    index="$p2"
    case "${index}" in
        0|1|2|3|4|5|6)
            value="$((index+1))"
            cui_window_close "$dlg" "$IDOK"
            ;;

        7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24)
            value="8 $((index-7))"
            cui_window_close "$dlg" "$IDOK"
            ;;

        25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50|51|52|53|54|55|56|57|58|59|60|61)
            value="$((index-16))"
            cui_window_close "$dlg" "$IDOK"
            ;;

        *)
            closeDialog=false
            ;;
    esac

    if [ closeDialog == true ]
    then
        cui_window_close "$dlg" "$IDOK"
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
# cancel_button_clicked
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
#----------------------------------------------------------------------------

function cancel_button_clicked()
{
    # -----------------------------
    # Just for sure: use the backup
    value=${valueBackup}
    valueBackup=''

    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# listbox_changed
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
#----------------------------------------------------------------------------

function listbox_changed()
{
    local dlg="$p2"
    local list="$p3"
    local index="0"

    cui_listbox_getsel "$list"
    cui_return 1
}

#----------------------------------------------------------------------------
# testdlg_create_hook
#         $p2 --> dialog window handle
#----------------------------------------------------------------------------

function testdlg_create_hook()
{
    valueBackup=${value}
    local dlg="$p2"
    local ctrl

    local currentSelection='21'
    if [ -n "${value}" ]
    then
        local firstVal=`echo ${value} | cut -d " " -f 1`
        local secondVal=`echo ${value} | cut -d " " -f 2`
        if [ -n ${firstVal} -a ${firstVal} -ge 1 -a ${firstVal} -le 7 ]
        then
            currentSelection=${firstVal}
        elif [ -n ${firstVal} -a ${firstVal} -ge 9 -a ${firstVal} -le 44 ]
        then
            currentSelection=$((firstVal+17))
        elif [ -n ${firstVal} -a ${firstVal} -eq 8 ]
        then
            if [ -n ${secondVal} -a ${secondVal} -ge 0 -a ${secondVal} -le 17 ]
            then
                currentSelection=`expr ${firstVal} + ${secondVal}`
            fi
        fi
    fi

    if cui_listbox_new "$dlg" "" 1 1 66 10 $IDC_LISTBOX $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_listbox_callback  "$ctrl" "$LISTBOX_CHANGED" "$dlg" listbox_changed
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"

        # ------------------------
        # Fill the list of entries
        for currentClockType in "${clockType[@]}"
        do
            cui_listbox_add   "$ctrl" "${currentClockType}"
        done
        
        # ------------------------------------------
        # Set the entry out of the old configuration
        cui_listbox_select    "$ctrl" "${clockType[$currentSelection]}"
    fi

    if cui_button_new "$dlg" "&OK"     23 12 10 1 $IDC_BUTOK     $CWS_DEFOK     $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" ok_button_clicked
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&Cancel" 34 12 10 1 $IDC_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" cancel_button_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#----------------------------------------------------------------------------
# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
#----------------------------------------------------------------------------

function exec_dialog()
{
    local win="$p2"
    local res="$IDCANCEL"

    if cui_window_new "$p2" 0 0 70 16 $[$CWS_POPUP + $CWS_CENTERED + $CWS_BORDER]
    then
        local dlgwin="$p2"
        cui_window_setcolors      "$dlgwin" "DIALOG"
        cui_window_settext        "$dlgwin" "Choose clock type"
        cui_window_sethook        "$dlgwin" "$HOOK_CREATE"  testdlg_create_hook
        cui_window_create         "$dlgwin"

        cui_window_modal          "$dlgwin"
        res="$p2"
        cui_window_destroy        "$dlgwin"
    fi

    cui_return "$res"
}

#----------------------------------------------------------------------------
# init() routine (makes it executable under shellrun.cui too)
#----------------------------------------------------------------------------

function init()
{
    exec_dialog $p2
}

#----------------------------------------------------------------------------
# main routine
#----------------------------------------------------------------------------

cui_init
cui_run

#----------------------------------------------------------------------------
# end
#----------------------------------------------------------------------------

exit 0
