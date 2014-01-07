#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-user-forwarings.cui.sh
# Copyright (c) 2001-2009 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/mysqllib-2

#============================================================================
# global constants
#============================================================================

IDC_LISTVIEW='10'                # listview ID
IDC_HELPTEXT='11'                # help text ID

IDC_USERDLG_BUTOK='10'           # dlg OK button ID
IDC_USERDLG_BUTCANCEL='11'       # dlg Cancel button ID
IDC_USERDLG_LABEL1='12'          # dlg label ID
IDC_USERDLG_LABEL2='13'          # dlg label ID
IDC_USERDLG_EDPASSWD1='21'       # dlg edit ID
IDC_USERDLG_EDPASSWD2='22'       # dlg edit ID

IDC_INPUTDLG_BUTOK='10'          # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'      # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'        # dlg edit ID

selected_entry=''
current_host_name=""
current_user_name=""
show_help="no"

#============================================================================
# helper functions
#============================================================================


#============================================================================
# data input dialog
#============================================================================

#----------------------------------------------------------------------------
# inputdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function inputdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_USERDLG_EDPASSWD1" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        userdlg_passwd1="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_USERDLG_EDPASSWD2" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        userdlg_passwd2="$p2"
    fi

    if [ -z "${userdlg_passwd1}" ]
    then
        cui_message "$win" "Empty password supplied! Please enter a valid password" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ "${userdlg_passwd1}" != "${userdlg_passwd2}" ]
    then
        cui_message "$win" "Passwords do not match. Please reenter passwords." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# inputdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function inputdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# inputdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled      
#----------------------------------------------------------------------------
function inputdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "Password:" 2 1 14 1 "$IDC_USERDLG_LABEL1" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Retype passwd.:" 2 3 14 1 "$IDC_USERDLG_LABEL2" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 25 1 255 "$IDC_USERDLG_EDPASSWD1" "$EF_PASSWORD" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${userdlg_passwd1}"
    fi

    cui_edit_new "$dlg" "" 17 3 25 1 255 "$IDC_USERDLG_EDPASSWD2" "$EF_PASSWORD" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${userdlg_passwd2}"
    fi

    cui_button_new "$dlg" "&OK" 11 5 10 1 $IDC_INPUTDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 22 5 10 1 $IDC_INPUTDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
# user_password_dialog
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function user_password_dialog()
{
    local win="$p2"
    local dlg

    cui_window_new "$win" 0 0 46 9 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Password"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  inputdlg_create_hook
        cui_window_create    "$dlg"

        userdlg_passwd1=""
        userdlg_passwd2=""

        cui_window_modal     "$dlg" && result="$p2"
        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"
            mysqladmin -u root password $userdlg_passwd1
cat > /root/.my.cnf <<EOF
[client]
user=root
password=$userdlg_passwd1

[mysqladmin]
user=root
password=$userdlg_passwd1

[mysqldump]
user=root
password=$userdlg_passwd1

[mysql]
user=root
password=$userdlg_passwd1
EOF
        else
            cui_window_destroy "$dlg"
        fi
    fi
}

#============================================================================
# main window hooks
#============================================================================

#----------------------------------------------------------------------------
# mainwin_create_hook (for creation of child windows)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function mainwin_create_hook()
{
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_init_hook (load data)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function mainwin_init_hook()
{
    local win="$p2"
    user_password_dialog "$win" "$p2"
    cui_window_quit 0
    cui_return 1
}
#----------------------------------------------------------------------------
# mainwin_key_hook (handle key events for mainwin)
#    $p2 --> mainwin window handle
#    $p3 --> key code
#----------------------------------------------------------------------------
function mainwin_key_hook()
{
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_size_hook (handle resize events for mainwin)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function mainwin_size_hook()
{
    resize_windows "$p2"
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_destroy_hook (destroy mainwin object)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function mainwin_destroy_hook()
{
    cui_return 1
}

#----------------------------------------------------------------------------
# init routine (entry point of all shellrun.cui based programs)
#    $p2 --> desktop window handle
#----------------------------------------------------------------------------
function init()
{
    local win="$p2"

    # prepare mysql connection
#   my_initmodule
#   if [ "$?" != "0" ]
#   then
#       cui_message "$win" "Unable to load mysql shell extension!" "Error" "$MB_ERROR"
#       cui_return 0
#       return
#   fi

    # setup main window    
    cui_window_new "$win" 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED] && mainwin="$p2"
    if cui_valid_handle $mainwin
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "MySQL user 'root' password"
        cui_window_setlstatustext "$mainwin" ""
        cui_window_setrstatustext "$mainwin" "V1.0.0"
        cui_window_sethook        "$mainwin" "$HOOK_CREATE"  mainwin_create_hook
        cui_window_sethook        "$mainwin" "$HOOK_INIT"    mainwin_init_hook
        cui_window_sethook        "$mainwin" "$HOOK_KEY"     mainwin_key_hook
        cui_window_sethook        "$mainwin" "$HOOK_SIZE"    mainwin_size_hook
        cui_window_sethook        "$mainwin" "$HOOK_DESTROY" mainwin_destroy_hook
        cui_window_create         "$mainwin"
    fi
    cui_return 0
}

#----------------------------------------------------------------------------
# main routines (always at the bottom of the file)
#----------------------------------------------------------------------------
cui_init
cui_run

exit 0
