#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/LCD_DRIVER_CUI.sh - script dialog for ece
#
# Creation:     2010-09-26 starwarsfan
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib


# ----------------------------------------------------------------------------
# All known selections and subselections
# ----------------------------------------------------------------------------
drivers='Crystalfontz Curses HD44780 MatrixOrbital MilfordInstruments M50530 Cwlinux T6963 WincorNixdorf LCD2USB serdisplib'

driversCrystalfontz='626 631 632 633 634 636'
driversCurses=''
driversHD44780='generic Noritake Soekris HD66712 LCM-162'
driversMatrixOrbitel='LCD0821 LCD2021 LCD1641 LCD2041 LCD4021 LCD4041 LK202-25 LK204-25 LK404-55 VFD2021 VFD2041 VFD4021 VK202-25 VK204-25 GLC12232 GLC24064 GLK24064-25 GLK12232-25 LK404-AT VFD1621 LK402-12 LK162-12 LK204-25PC LK202-24-USB LK204-24-USB'
driversMilfordInstruments='MI216 MI220 MI240 MI420'
driversM50530=''
driversCwlinux='CW1602 CW12232'
driversT6963=''
driversWincorNixdorf='BA63 BA66'
driversLCD2USB=''
driversserdisplib='OPTREX323 PCD8544 LPH7366 LPH7690 NOKIA7110 ERICSSONT2X LSU7S1011A T6963 TLX1391 SED133X NEC21A LPH7508 HP12542R N3510I ERICSSONR520 KS0108 CTINCLUD'



# ----------------------------------------------------------------------------
# Control constants
# ----------------------------------------------------------------------------
IDC_LABEL__DISPLAYTYPE='10'
IDC_LABEL__DISPLAYMODEL='11'
IDC_LISTBOX__DISPLAYTYPE='12'
IDC_LISTBOX__DISPLAYMODEL='13'
IDC_BUTOK='100'
IDC_BUTCANCEL='100'



# ----------------------------------------------------------------------------
#  ok_button_clicked
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
# ----------------------------------------------------------------------------
function ok_button_clicked()
{
    local dlg="$p2"
    local ctrl="$p3"
    local index="3"
    local closeDialog=true

    cui_window_getctrl $dlg $IDC_LISTBOX__DISPLAYTYPE
    cui_listbox_getsel $p2
    index="$p2"


    case "$index" in
    0)
        # Crystalfontz
        value="Crystalfontz"
        getChoosenModel "$driversCrystalfontz"
        cui_window_close "$dlg" "$IDOK"
        ;;
    1)
        # Curses
        value="Curses"
        getChoosenModel "$driversCurses"
        cui_window_close "$dlg" "$IDOK"
        ;;
    2)
        # HD44780
        value="HD44780"
        getChoosenModel "$driversHD44780"
        cui_window_close "$dlg" "$IDOK"
        ;;
    3)
        # MatrixOrbital
        value="MatrixOrbital"
        getChoosenModel "$driversMatrixOrbitel"
        cui_window_close "$dlg" "$IDOK"
        ;;
    4)
        # MilfordInstruments
        value="MilfordInstruments"
        getChoosenModel "$driversMilfordInstruments"
        cui_window_close "$dlg" "$IDOK"
        ;;
    5)
        # M50530
        value="M50530"
        getChoosenModel "$driversM50530"
        cui_window_close "$dlg" "$IDOK"
        ;;
    6)
        # Cwlinux
        value="Cwlinux"
        getChoosenModel "$driversCwlinux"
        cui_window_close "$dlg" "$IDOK"
        ;;
    7)
        # T6963
        value="T6963"
        getChoosenModel "$driversT6963"
        cui_window_close "$dlg" "$IDOK"
        ;;
    8)
        # WincorNixdorf
        value="WincorNixdorf"
        getChoosenModel "$driversWincorNixdorf"
        cui_window_close "$dlg" "$IDOK"
        ;;
    9)
        # LCD2USB
        value="LCD2USB"
        getChoosenModel "$driversLCD2USB"
        cui_window_close "$dlg" "$IDOK"
        ;;
    10)
        # serdisplib
        value="serdisplib"
        getChoosenModel "$driversserdisplib"
        cui_window_close "$dlg" "$IDOK"
        ;;
    *)
        closeDialog=false
        ;;
    esac


    echo $value >> /tmp/outcui.log

    if [ closeDialog == true ]
    then
        cui_window_close "$dlg" "$IDOK"
    fi
    cui_return 1
}



# ----------------------------------------------------------------------------
# Update the return value $value with the coosen entry out of the list of
# selectable models given with $1.
# ----------------------------------------------------------------------------
function getChoosenModel ()
{
    cui_window_getctrl $dlg $IDC_LISTBOX__DISPLAYMODEL
    cui_listbox_getsel $p2
    index="$p2"

    counter=0
    for currentModel in $1
    do
        if [ $index -eq $counter ]
        then
            value="${value}:${currentModel}"
            return
        fi
        counter=$((counter+1))
    done
}



# ----------------------------------------------------------------------------
# cancel_button_clicked
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
# ----------------------------------------------------------------------------
function cancel_button_clicked()
{
    # -----------------------------
    # Just for sure: use the backup
    value=${valueBackup}
    valueBackup=''

    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}



# ----------------------------------------------------------------------------
# listbox_changed
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
# ----------------------------------------------------------------------------
function listbox_changed()
{
    local dlg="$p2"
    local list="$p3"
    local index="0"

    cui_listbox_getsel "$list"
    index="$p2"

    case "$index" in
    0)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversCrystalfontz"
        ;;
    1)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversCurses"
        ;;
    2)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversHD44780"
        ;;
    3)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversMatrixOrbitel"
        ;;
    4)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversMilfordInstruments"
        ;;
    5)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversM50530"
        ;;
    6)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversCwlinux"
        ;;
    7)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversT6963"
        ;;
    8)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversWincorNixdorf"
        ;;
    9)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversLCD2USB"
        ;;
    10)
        updateListboxContent $dlg $IDC_LISTBOX__DISPLAYMODEL "$driversserdisplib"
        ;;
    esac

    cui_return 1
}



# ----------------------------------------------------------------------------
# Clear the listbox given with param $2 on control element $1 and fill it with
# elements given on the list $3.
# ----------------------------------------------------------------------------
function updateListboxContent ()
{
    local dialogElement=$1
    local controlElement=$2
    local listboxContentToSet=$3

      cui_window_getctrl $dlg $controlElement
      ctrl="$p2"
      cui_listbox_clear "$ctrl"

    for currentListboxElement in $listboxContentToSet
    do
        cui_listbox_add   "$ctrl" "$currentListboxElement"
    done
}



# ----------------------------------------------------------------------------
# dlg_setup_hook
#         $p2 --> dialog window handle
# ----------------------------------------------------------------------------
function dlg_setup_hook()
{
    valueBackup=${value}
    local dlg="$p2"
    local ctrl

    if [ -z "${value}" ]
    then
        local displayType=''
        local displayModel=''
    else
        local displayType=`echo ${value} | cut -d ":" -f 1`
        local displayModel=`echo ${value} | cut -d ":" -f 2`
    fi

    if cui_label_new "$dlg" "Type:"   1 1 13 1 $IDC_LABEL__DISPLAYTYPE $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 1 3 21 5 $IDC_LISTBOX__DISPLAYTYPE $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_listbox_callback  "$ctrl" "$LISTBOX_CHANGED" "$dlg" listbox_changed
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        for currentDisplayType in $drivers
        do
            cui_listbox_add   "$ctrl" "$currentDisplayType"
        done
        cui_listbox_select    "$ctrl" "$displayType"
    fi

    if cui_label_new "$dlg" "Model:"   24 1 13 1 $IDC_LABEL__DISPLAYMODEL $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 24 3 21 5 $IDC_LISTBOX__DISPLAYMODEL $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        for currentDisplayModel in $driversCrystalfontz
        do
            cui_listbox_add   "$ctrl" "$currentDisplayModel"
        done
        cui_listbox_select    "$ctrl" "$displayModel"
    fi

    if cui_button_new "$dlg" "&OK" 24 9 10 1 $IDC_BUTOK $CWS_DEFOK $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" ok_button_clicked
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&Cancel" 35 9 10 1 $IDC_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" cancel_button_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}



# ----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------

function exec_dialog()
{
    local win="$p2"
    local res="$IDCANCEL"

    if cui_window_new "$p2" 0 0 48 13 $[$CWS_POPUP + $CWS_CENTERED + $CWS_BORDER]
    then
        local dlgwin="$p2"
        cui_window_setcolors      "$dlgwin" "DIALOG"
        cui_window_settext        "$dlgwin" "Driver and display type"
        cui_window_sethook        "$dlgwin" "$HOOK_CREATE"  dlg_setup_hook
        cui_window_create         "$dlgwin"

        cui_window_modal          "$dlgwin"
        res="$p2"
        cui_window_destroy        "$dlgwin"
    fi

    cui_return "$res"
}



# ----------------------------------------------------------------------------
# init() routine (makes it executable under shellrun.cui too)
# ----------------------------------------------------------------------------
function init()
{
    exec_dialog $p2
}



# ----------------------------------------------------------------------------
# main routine
# ----------------------------------------------------------------------------

cui_init
cui_run

# ----------------------------------------------------------------------------
# end
# ----------------------------------------------------------------------------

exit 0
