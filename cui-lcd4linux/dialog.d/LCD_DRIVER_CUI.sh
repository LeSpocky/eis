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
amountOfEntries=46

driverName[0]='ASTUSB'
driverName[1]='Beckmann+Egle'
driverName[2]='BWCT'
driverName[3]='Crystalfontz'
driverName[4]='Curses'
driverName[5]='Cwlinux'
driverName[6]='D4D'
driverName[7]='DPF'
driverName[8]='EA232graphic'
driverName[9]='EFN'
driverName[10]='FutabaVFD'
driverName[11]='FW8888'
driverName[12]='G-15'
driverName[13]='GLCD2USB'
driverName[14]='HD44780'
driverName[15]='Image'
driverName[16]='IRLCD'
driverName[17]='LCD2USB'
driverName[18]='LCDTerm'
driverName[19]='LEDMatrix'
driverName[20]='LPH7508'
driverName[21]='LW_ABP'
driverName[22]='M50530'
driverName[23]='MatrixOrbital'
driverName[24]='MatrixOrbitalGX'
driverName[25]='MDM166A'
driverName[26]='MilfordInstruments'
driverName[27]='Newhaven'
driverName[28]='Noritake'
driverName[29]='NULL'
driverName[30]='Pertelian'
driverName[31]='PHAnderson'
driverName[32]='PICGraphic'
driverName[33]='picoLCD'
driverName[34]='picoLCDGraphic'
driverName[35]='RouterBoard'
driverName[36]='Sample'
driverName[37]='SamsungSPF'
driverName[38]='ShuttleVFD'
driverName[39]='SimpleLCD'
driverName[40]='T6963'
driverName[41]='TeakLCM'
driverName[42]='TREFON'
driverName[43]='USBHUB'
driverName[44]='USBLCD'
driverName[45]='WincorNixdorf'

drivers[0]=''
drivers[1]='MT16x1 MT16x2 MT16x4 MT20x1 MT20x2 MT20x4 MT24x1 MT24x2 MT32x1 MT32x2 MT40x1 MT40x2 MT40x4 CT20x4'
drivers[2]=''
drivers[3]='626 631 632 633 634 635 636'
drivers[4]=''
drivers[5]='CW1602 CW12232 CW12832'
drivers[6]=''
drivers[7]=''
drivers[8]='GE120-5NV24 GE128-6N3V24 GE128-6N9V24 KIT160-6 KIT160-7 KIT240-6 KIT240-7 KIT320-8 GE128-7KV24 GE240-6KV24 GE240-6KCV24 GE240-7KV24 GE240-7KLWV24 GE240-6KLWV24 KIT120-5 KIT129-6'
drivers[9]=''
drivers[10]=''
drivers[11]=''
drivers[12]=''
drivers[13]=''
drivers[14]=''
drivers[15]='PPM PNG'
drivers[16]=''
drivers[17]=''
drivers[18]=''
drivers[19]=''
drivers[20]=''
drivers[21]=''
drivers[22]=''
drivers[23]='LCD0821 LCD2021 LCD1641 LCD2041 LCD4021 LCD4041 LK202-25 LK204-25 LK404-55 VFD2021 VFD2041 VFD4021 VK202-25 VK204-25 GLC12232 GLC24064 GLK24064-25 GLK12232-25 LK404-AT VFD1621 LK402-12 LK162-12 LK204-25PC LK202-24-USB LK204-24-USB VK204-24-USB DE-LD011 DE-LD021 DE-LD023'
drivers[24]=''
drivers[25]=''
drivers[26]='MI216 MI220 MI240 MI420'
drivers[27]=''
drivers[28]='GU311 GU311_Graphic'
drivers[29]=''
drivers[30]=''
drivers[31]=''
drivers[32]=''
drivers[33]=''
drivers[34]=''
drivers[35]='HD44780 HD66712'
drivers[36]=''
drivers[37]=''
drivers[38]=''
drivers[39]=''
drivers[40]=''
drivers[41]=''
drivers[42]=''
drivers[43]=''
drivers[44]=''
drivers[45]='BA63 BA66'



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
function ok_button_clicked() {
    local dlg="$p2"
    local ctrl="$p3"
    local index="3"
    local closeDialog=true

    cui_window_getctrl ${dlg} ${IDC_LISTBOX__DISPLAYTYPE}
    cui_listbox_getsel ${p2}
    index="$p2"

    if [ ${index} -lt 0 -a ${index} -gt ${amountOfEntries} ] ; then
        closeDialog=false
    else
        value="${driverName[index]}"
        getChoosenModel "${drivers[index]}"
        cui_window_close "$dlg" "$IDOK"
    fi

    echo ${value} >> /tmp/outcui.log

    if [ closeDialog == true ] ; then
        cui_window_close "$dlg" "$IDOK"
    fi
    cui_return 1
}



# ----------------------------------------------------------------------------
# Update the return value $value with the coosen entry out of the list of
# selectable models given with $1.
# ----------------------------------------------------------------------------
function getChoosenModel () {
    cui_window_getctrl ${dlg} ${IDC_LISTBOX__DISPLAYMODEL}
    cui_listbox_getsel ${p2}
    index="$p2"

    counter=0
    for currentModel in $1 ; do
        if [ ${index} -eq ${counter} ] ; then
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
function cancel_button_clicked() {
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
function listbox_changed() {
    local dlg="$p2"
    local list="$p3"
    local index="0"

    cui_listbox_getsel "$list"
    index="$p2"

    updateListboxContent ${dlg} ${IDC_LISTBOX__DISPLAYMODEL} "${drivers[index]}"

    cui_return 1
}



# ----------------------------------------------------------------------------
# Clear the listbox given with param $2 on control element $1 and fill it with
# elements given on the list $3.
# ----------------------------------------------------------------------------
function updateListboxContent () {
    local dialogElement=$1
    local controlElement=$2
    local listboxContentToSet=$3

    cui_window_getctrl ${dlg} ${controlElement}
    ctrl="$p2"
    cui_listbox_clear "$ctrl"

    for currentListboxElement in ${listboxContentToSet} ; do
        cui_listbox_add   "$ctrl" "$currentListboxElement"
    done
}



# ----------------------------------------------------------------------------
# dlg_setup_hook
#         $p2 --> dialog window handle
# ----------------------------------------------------------------------------
function dlg_setup_hook() {
    valueBackup=${value}
    local dlg="$p2"
    local ctrl

    if [ -z "${value}" ] ; then
        local displayType=''
        local displayModel=''
    else
        local displayType=`echo ${value} | cut -d ":" -f 1`
        local displayModel=`echo ${value} | cut -d ":" -f 2`
    fi

    if cui_label_new "$dlg" "Type:"   1 1 13 1 ${IDC_LABEL__DISPLAYTYPE} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 1 3 21 5 ${IDC_LISTBOX__DISPLAYTYPE} ${CWS_NONE} ${CWS_BORDER} ; then
        ctrl="$p2"
        cui_listbox_callback  "$ctrl" "$LISTBOX_CHANGED" "$dlg" listbox_changed
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        idx=0
        while [ ${idx} -lt ${amountOfEntries} ] ; do
            cui_listbox_add   "$ctrl" "${driverName[idx]}"
            idx=$((idx+1))
        done
        cui_listbox_select    "$ctrl" "$displayType"
    fi

    if cui_label_new "$dlg" "Model:"   24 1 13 1 ${IDC_LABEL__DISPLAYMODEL} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 24 3 21 5 ${IDC_LISTBOX__DISPLAYMODEL} ${CWS_NONE} ${CWS_BORDER} ; then
        ctrl="$p2"
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        for currentDisplayModel in ${driversCrystalfontz} ; do
            cui_listbox_add   "$ctrl" "$currentDisplayModel"
        done
        cui_listbox_select    "$ctrl" "$displayModel"
    fi

    if cui_button_new "$dlg" "&OK" 24 9 10 1 ${IDC_BUTOK} ${CWS_DEFOK} ${CWS_NONE} ; then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" ok_button_clicked
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&Cancel" 35 9 10 1 ${IDC_BUTCANCEL} ${CWS_DEFCANCEL} ${CWS_NONE} ; then
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
function exec_dialog() {
    local win="$p2"
    local res="$IDCANCEL"

    if cui_window_new "$p2" 0 0 48 13 $[$CWS_POPUP + $CWS_CENTERED + $CWS_BORDER] ; then
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
function init() {
    exec_dialog ${p2}
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
