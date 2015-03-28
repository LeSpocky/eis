#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/dialog.d/PHPMYADMIN_GET_AUTH_METHOD_CUI.sh - script dialog for
# ece to get the authentication method and if requested the username and
# password.
#
# Creation:     2008-03-22 starwarsfan
# Last update:  $Id: PHPMYADMIN_GET_AUTH_METHOD_CUI.sh 21582 2009-10-17 09:17:35Z alex $
#
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

#----------------------------------------------------------------------------
# control constants
#----------------------------------------------------------------------------

IDC_LISTBOX='10'
IDC_EDIT__USERNAME='11'
IDC_EDIT__PASSWORD1='12'
IDC_EDIT__PASSWORD2='13'
IDC_LABEL__USERNAME='14'
IDC_LABEL__PASSWORD1='15'
IDC_LABEL__PASSWORD2='16'
IDC_BUTOK='100'
IDC_BUTCANCEL='100'

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

    case "$index" in
    0)
        value="http"
        cui_window_close "$dlg" "$IDOK"
        ;;
    1)
        value="cookie"
        cui_window_close "$dlg" "$IDOK"
        ;;
    2)
        # ----------------------------------------
        # Authentication via configuration choosen
        cui_window_getctrl $dlg $IDC_EDIT__USERNAME

        # -----------------------------------------------------
        # Workaround:
        # $p2 must be empty before the call of cui_edit_gettext
        # to be able to detect empty edit fields
        ctrl="$p2"
        p2='' && cui_edit_gettext "$ctrl"

        local username=$p2

        cui_window_getctrl $dlg $IDC_EDIT__PASSWORD1
        ctrl="$p2"
        p2='' && cui_edit_gettext "$ctrl"
        local password1=$p2

        cui_window_getctrl $dlg $IDC_EDIT__PASSWORD2
        ctrl="$p2"
        p2='' && cui_edit_gettext "$ctrl"
        local password2=$p2

        if [ -z "${username}" ]
        then
            cui_message $dlg "Username can't be empty!" "Error" "$MB_ERROR"
            closeWindow=false
        elif [ "${username}" == "root" ] || [ "${username}" == "eis" ]
        then
            cui_message $dlg "Username '${username}' is not allowed!" "Error" "$MB_ERROR"
            closeWindow=false
        elif [ -z "${password1}" ]
        then
            cui_message $dlg "Password can't be empty!" "Error" "$MB_ERROR"
            closeWindow=false
        elif [ "${username}" == "${password1}" ]
        then
            cui_message $dlg "Username and password can't be the same!" "Error" "$MB_ERROR"
            closeWindow=false
        elif [ "${password1}" == "${password2}" ]
        then
            value="config:${username}:${password1}"
            cui_window_close "$dlg" "$IDOK"
        else
            cui_message $dlg "Passwords do not match" "Error" "$MB_ERROR"
            closeDialog=false
        fi
        ;;
    3)
        value="signon"
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
    index="$p2"

    # hide all controls first
    cui_window_getctrl $dlg $IDC_LABEL__USERNAME
    cui_window_hide    $p2  1
    cui_window_getctrl $dlg $IDC_LABEL__PASSWORD1
    cui_window_hide    $p2  1
    cui_window_getctrl $dlg $IDC_LABEL__PASSWORD2
    cui_window_hide    $p2  1
    cui_window_getctrl $dlg $IDC_EDIT__USERNAME
    cui_window_hide    $p2  1
    cui_window_getctrl $dlg $IDC_EDIT__PASSWORD1
    cui_window_hide    $p2  1
    cui_window_getctrl $dlg $IDC_EDIT__PASSWORD2
    cui_window_hide    $p2  1

    case "$index" in
    2)  cui_window_getctrl $dlg $IDC_LABEL__USERNAME
        cui_window_hide    $p2  0
        cui_window_getctrl $dlg $IDC_LABEL__PASSWORD1
        cui_window_hide    $p2  0
        cui_window_getctrl $dlg $IDC_LABEL__PASSWORD2
        cui_window_hide    $p2  0
        cui_window_getctrl $dlg $IDC_EDIT__USERNAME
        cui_window_hide    $p2  0
        cui_window_getctrl $dlg $IDC_EDIT__PASSWORD1
        cui_window_hide    $p2  0
        cui_window_getctrl $dlg $IDC_EDIT__PASSWORD2
        cui_window_hide    $p2  0
        ;;
    esac

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

    if [ -z "${value}" ]
    then
        local authType=''
        local username=''
        local password=''
    else
        local authType=`echo ${value} | cut -d ":" -f 1`
        local username=`echo ${value} | cut -d ":" -f 2`
        local password=`echo ${value} | cut -d ":" -f 3`
    fi

    if cui_listbox_new "$dlg" "" 1 1 13 3 $IDC_LISTBOX $CWS_NONE $CWS_BORDER
    then
        ctrl="$p2"
        cui_listbox_callback  "$ctrl" "$LISTBOX_CHANGED" "$dlg" listbox_changed
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        cui_listbox_add       "$ctrl" "http"
        cui_listbox_add       "$ctrl" "cookie"
        cui_listbox_add       "$ctrl" "config"
        cui_listbox_add       "$ctrl" "signon"
        cui_listbox_select    "$ctrl" "${authType}"
    fi

    if [ "${authType}" == "config" ]
    then
        setStyle=$CWS_NONE
    else
        setStyle=$CWS_HIDDEN
    fi

    if cui_label_new "$dlg" "Username:"   1 5 13 1 $IDC_LABEL__USERNAME $setStyle $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Password:"   1 7 13 1 $IDC_LABEL__PASSWORD1 $setStyle $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Once again:" 1 9 13 1 $IDC_LABEL__PASSWORD2 $setStyle $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_edit_new "$dlg" "" 15 5 21 1 40 $IDC_EDIT__USERNAME $setStyle $CWS_NONE
    then
        ctrl="$p2"
        cui_window_create     "${ctrl}"
        if [ "${authType}" == "config" ]
        then
            cui_edit_settext      "${ctrl}" "${username}"
        fi
    fi

    if cui_edit_new "$dlg" "" 15 7 21 1 40 $IDC_EDIT__PASSWORD1 $((setStyle+EF_PASSWORD)) $CWS_NONE
    then
        ctrl="$p2"
        cui_window_create     "${ctrl}"
        if [ "${authType}" == "config" ]
        then
            cui_edit_settext      "${ctrl}" "${password}"
        fi
    fi

    if cui_edit_new "$dlg" "" 15 9 21 1 40 $IDC_EDIT__PASSWORD2 $((setStyle+EF_PASSWORD)) $CWS_NONE
    then
        ctrl="$p2"
        cui_window_create     "${ctrl}"
        if [ "${authType}" == "config" ]
        then
            cui_edit_settext      "${ctrl}" "${password}"
        fi
    fi

    if cui_button_new "$dlg" "&OK" 15 11 10 1 $IDC_BUTOK $CWS_DEFOK $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" ok_button_clicked
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&Cancel" 26 11 10 1 $IDC_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE
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

    if cui_window_new "$p2" 0 0 40 15 $[$CWS_POPUP + $CWS_CENTERED + $CWS_BORDER]
    then
        local dlgwin="$p2"
        cui_window_setcolors      "$dlgwin" "DIALOG"
        cui_window_settext        "$dlgwin" "Choose authentication method"
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
