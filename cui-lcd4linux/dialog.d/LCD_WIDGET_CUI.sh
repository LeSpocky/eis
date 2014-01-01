#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/LCD_WIDGET_CUI.sh - script dialog for ece
#
# Creation:     2010-10-03 starwarsfan
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
widgetTypes='Text Bar Icon'



# ----------------------------------------------------------------------------
# Control constants
# ----------------------------------------------------------------------------
IDC_LABEL__WIDGETTYPE='10'
IDC_LABEL__WIDGETNAME='11'
IDC_LISTBOX__WIDGETTYPE='12'
IDC_LISTBOX__WIDGETNAME='13'
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

    cui_window_getctrl $dlg $IDC_LISTBOX__WIDGETTYPE
    cui_listbox_getsel $p2
    index="$p2"


    case "$index" in
    0)
        value="Text"
        getChoosenModel "$textWidgets"
        cui_window_close "$dlg" "$IDOK"
        ;;
    1)
        value="Bar"
        getChoosenModel "$barWidgets"
        cui_window_close "$dlg" "$IDOK"
        ;;
    2)
        value="Icon"
        getChoosenModel "$iconWidgets"
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
    cui_window_getctrl $dlg $IDC_LISTBOX__WIDGETNAME
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
        updateListboxContent $dlg $IDC_LISTBOX__WIDGETNAME "$textWidgets"
        ;;
    1)
        updateListboxContent $dlg $IDC_LISTBOX__WIDGETNAME "$barWidgets"
        ;;
    2)
        updateListboxContent $dlg $IDC_LISTBOX__WIDGETNAME "$iconWidgets"
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
        local widgetType=''
        local widgetName=''
    else
        local widgetType=`echo ${value} | cut -d ":" -f 1`
        local widgetName=`echo ${value} | cut -d ":" -f 2`
    fi

    if cui_label_new "$dlg" "Type:"   1 1 13 1 $IDC_LABEL__WIDGETTYPE $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 1 3 21 5 $IDC_LISTBOX__WIDGETTYPE $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_listbox_callback  "$ctrl" "$LISTBOX_CHANGED" "$dlg" listbox_changed
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        for currentWidgetType in $widgetTypes
        do
            cui_listbox_add   "$ctrl" "$currentWidgetType"
        done
        cui_listbox_select    "$ctrl" "$widgetType"
    fi

    if cui_label_new "$dlg" "Name:"   24 1 13 1 $IDC_LABEL__WIDGETNAME $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 24 3 21 5 $IDC_LISTBOX__WIDGETNAME $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        if [ -f /etc/config.d/lcd-widgets ]
        then
            . /etc/config.d/lcd-widgets
            idx=1
            separator=''
            while [ $idx -le $LCD_WIDGET_TEXT_N ]
            do
                eval name='$LCD_WIDGET_TEXT_'$idx'_NAME'
                eval active='$LCD_WIDGET_TEXT_'$idx'_ACTIVE'
                if [ "$active" == 'yes' ]
                then
                    cui_listbox_add   "$ctrl" "$name"
                    textWidgets="${textWidgets}${separator}${name}"
                    separator=' '
                fi
                idx=$((idx+1))
            done

            idx=1
            separator=''
            while [ $idx -le $LCD_WIDGET_BAR_N ]
            do
                eval name='$LCD_WIDGET_BAR_'$idx'_NAME'
                eval active='$LCD_WIDGET_BAR_'$idx'_ACTIVE'
                if [ "$active" == 'yes' ]
                then
                    barWidgets="${barWidgets}${separator}${name}"
                    separator=' '
                fi
                idx=$((idx+1))
            done

            idx=1
            separator=''
            while [ $idx -le $LCD_WIDGET_ICON_N ]
            do
                eval name='$LCD_WIDGET_ICON_'$idx'_NAME'
                eval active='$LCD_WIDGET_ICON_'$idx'_ACTIVE'
                if [ "$active" == 'yes' ]
                then
                    iconWidgets="${iconWidgets}${separator}${name}"
                    separator=' '
                fi
                idx=$((idx+1))
            done
        else
            cui_listbox_add   "$ctrl" "Widgets config not found"
        fi
        cui_listbox_select    "$ctrl" "$widgetName"
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
        cui_window_settext        "$dlgwin" "Widget to use"
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
