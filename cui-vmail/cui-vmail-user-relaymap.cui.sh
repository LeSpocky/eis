#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-user-relaymap.cui.sh
# Copyright (c) 2001-2011 the eisfair team, team(at)eisfair(dot)org
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
IDC_USERDLG_LABEL3='14'          # dlg label ID
IDC_USERDLG_LABEL4='15'          # dlg label ID
IDC_USERDLG_LABEL5='16'          # dlg label ID
IDC_USERDLG_EDMAILAD='22'        # dlg edit ID
IDC_USERDLG_EDLOGIN='23'         # dlg edit ID
IDC_USERDLG_EDPASSWD1='24'       # dlg edit ID
IDC_USERDLG_EDPASSWD2='25'       # dlg edit ID
IDC_USERDLG_EDNOTE='26'          # dlg edit ID
IDC_USERDLG_CHKACTIVE='27'       # dlg edit ID

IDC_INPUTDLG_BUTOK='10'          # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'      # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'        # dlg edit ID

selected_entry=''
userdlg_id='0'
current_domain=''
current_domain_id="0"
show_help="no"

vmail_sql_server="localhost"
vmail_sql_db_name="vmaildata"
vmail_sql_user="vmailprovider"
vmail_sql_pass="vmail"
POSTFIX_SMARTHOST="no"

if [ -e /etc/config.d/vmail ]
then
    . /etc/config.d/vmail
    vmail_sql_server="$VMAIL_SQL_HOST"
    vmail_sql_db_name="$VMAIL_SQL_DATABASE"
    vmail_sql_user="$VMAIL_SQL_USER"
    vmail_sql_pass="$VMAIL_SQL_PASS"
fi

#============================================================================
# helper functions
#============================================================================

#----------------------------------------------------------------------------
# check if is a valid list index
#----------------------------------------------------------------------------
function p_valid_index()
{
    if [ -n "$1" -a "$1" -ge "0" ]
    then
        return 0
    fi
    return 1
}

#----------------------------------------------------------------------------
# check if SQL command was successful
#----------------------------------------------------------------------------
function p_sql_success()
{
    if [ -n "$1" -a "$1" != "0" ]
    then
        return 0
    fi
    return 1
}

#----------------------------------------------------------------------------
# check if parameter is numeric
#----------------------------------------------------------------------------
function p_is_numeric()
{
    [ "$(echo $*|grep -v "[^0-9]")" ];
    return $?
}

#----------------------------------------------------------------------------
# read data from a MySQL database and copy result to the listview window
#----------------------------------------------------------------------------
function load_data()
{
    local win="$1"
    local ctrl
    local myres

    # execute query and return result
    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_clear  "$ctrl"

        if [ -z "$keyword" ]
        then
            my_query_sql "$myconn" \
                "SELECT email, username, active, note, id \
                 FROM   virtual_relayhosts \
                 WHERE  domain_id = ${current_domain_id}  \
                 ORDER BY email" && myres="$p2"
        else
            my_query_sql "$myconn" \
                "SELECT email, username, active, note, id \
                 FROM   virtual_relayhosts \
                 WHERE  domain_id = ${current_domain_id} AND email REGEXP '$keyword' \
                 ORDER BY email" && myres="$p2"
        fi

        if cui_valid_handle "$myres"
        then
            my_result_status "$myres"
            if [ "$p2" == "$SQL_DATA_READY" ]
            then
                my_result_tolist "$myres" "$ctrl" "0" "$selected_entry"
            else
                my_server_geterror "$myconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi

            my_result_free "$myres"
        fi
        cui_listview_update "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# resize client windows
#----------------------------------------------------------------------------
function resize_windows()
{
    local win="$1"
    local ctrl

    cui_getclientrect "$win"
    local w="$p4"
    local h="$p5"
    local p="$[$h - $h / 4]"

    if [ "$show_help" == "yes" ]
    then    
        cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
        if cui_valid_handle $ctrl
        then
            cui_window_move  "$ctrl" "0" "0" "$w" "$p"
        fi

        cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
        if cui_valid_handle $ctrl
        then
            cui_window_move  "$ctrl" "0" "$p" "$w" "$[$h -$p]"
            cui_window_hide  "$ctrl" "0"
        fi
    else
        cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
        if cui_valid_handle $ctrl
        then
            cui_window_move "$ctrl" "0" "0" "$w" "$h"
        fi

        cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
        if cui_valid_handle $ctrl
        then
            cui_window_move "$ctrl" "0" "$h" "$w" "2"
            cui_window_hide "$ctrl" "1"

            cui_window_getfocus
            if [ "$p2" == "$ctrl" ]
            then
                cui_window_getctrl "$win" "$IDC_LISTVIEW"
                if cui_valid_handle $p2
                then
                    cui_window_setfocus "$p2"
                fi
            fi
        fi
    fi
}

#============================================================================
# select menu hooks
#============================================================================

#----------------------------------------------------------------------------
# menu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function menu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# menu_escape_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function menu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}

#----------------------------------------------------------------------------
# menu_postkey_hook
# expects: $p2 : window handle
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------
function menu_postkey_hook()
{
   local ctrl="$p3"

   if [ "$p4" == "$KEY_F10" ]
   then
       cui_window_close "$ctrl" "$IDCANCEL"
       cui_window_quit 0
       cui_return 1
   else
       cui_return 0
   fi
}

#============================================================================
# mail domain selection menu
#============================================================================

#----------------------------------------------------------------------------
# resize menu depending on number of entries
# $1 --> appl. window
# $2 --> menu
# $3 --> no. of domains
#----------------------------------------------------------------------------
function resize_menu()
{
    local win="$1"
    local menu="$2"
    local count="$3"

    cui_getclientrect "$win"
    local w="$p4"
    local h="$p5"

    local mh=$[$count + 5]
    local mx=$[($w - 50) / 2]
    local my=$[($h - $mh) / 2]
    cui_window_move  "$menu" "$mx" "$my" "50" "$mh"
}

#----------------------------------------------------------------------------
# select a domain to append/edit user
#----------------------------------------------------------------------------
function select_domain()
{
    local win="$1"
    local ctrl
    local myres
    local idx='1'
    local menu
    local result
    local item
    local domains
    local domain_ids

    cui_menu_new "$win" "Select smarthost domain" 0 0 50 11 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        # execute query and return result
        my_query_sql "$myconn" \
            "SELECT name, id FROM view_domains_relay;" && myres="$p2"

        if cui_valid_handle "$myres"
        then
            my_result_status "$myres"
            if [ "$p2" == "$SQL_DATA_READY" ]
            then
                my_result_fetch "$myres"
                while [ "$p2" == "1" ]
                do
                    my_result_data    "$myres" "0"
                    domains[$idx]="$p2"
                    cui_menu_additem  "$menu" "$p2" "$idx"
                    my_result_data    "$myres" "1"
                    domain_ids[$idx]="$p2"
                    idx=$[$idx + 1]
                    my_result_fetch "$myres"
                done
            else
                my_server_geterror "$myconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi
            my_result_free "$myres"
        fi
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit"        0
        cui_menu_selitem      "$menu" 1
        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" "menu_clicked_hook"
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" "menu_escape_hook"
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" "menu_postkey_hook"
        resize_menu           "$win" "$menu" "$idx"
        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu" && item="$p2"
            if [ "$item" != "0" ]
            then
                current_domain=${domains[$item]}
                current_domain_id=${domain_ids[$item]}
            fi
        fi
        cui_window_destroy "$menu"
    fi
}

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

    cui_window_getctrl "$win" "$IDC_INPUTDLG_EDVALUE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        inputdlg_value="$p2"
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

    if cui_label_new "$dlg" "E-Mail:" 2 1 14 1 "$IDC_INPUTDLG_LABEL1" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 25 8 255 "$IDC_INPUTDLG_EDVALUE" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$inputdlg_value"
    fi

    cui_button_new "$dlg" "&OK" 11 3 10 1 $IDC_INPUTDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 22 3 10 1 $IDC_INPUTDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#============================================================================
# user edit/create dialog
#============================================================================

#----------------------------------------------------------------------------
# userdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function userdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_USERDLG_EDMAILAD" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        userdlg_email="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_USERDLG_EDLOGIN" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        userdlg_loginname="$p2"
    fi

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

    cui_window_getctrl "$win" "$IDC_USERDLG_EDNOTE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        userdlg_note="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_USERDLG_CHKACTIVE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl"  && userdlg_active="$p2"
    fi

    if [ -z "$userdlg_email" ]
    then
        cui_message "$win" "No email address entered! Please enter a valid email!" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$userdlg_loginname" ]
    then
        cui_message "$win" "No user login name entered! Please enter a valid user name!" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$userdlg_passwd1" ]
    then
        cui_message "$win" "Empty password supplied! Please enter a valid password" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ "$userdlg_passwd1" != "$userdlg_passwd2" ]
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
# userdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function userdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# userdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------
function userdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "E-Mail address:" 2 1 16 1 "$IDC_USERDLG_LABEL1" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Login username:" 2 3 16 1 "$IDC_USERDLG_LABEL2" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Login password:" 2 5 16 1 "$IDC_USERDLG_LABEL3" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Retype password:" 2 7 16 1 "$IDC_USERDLG_LABEL4" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Comment:" 2 9 16 1 "$IDC_USERDLG_LABEL5" "$CWS_NONE" "$CWS_NONE"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 19 1 27 1 255 "$IDC_USERDLG_EDMAILAD" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$userdlg_email"
    fi

    cui_edit_new "$dlg" "" 19 3 27 1 255 "$IDC_USERDLG_EDLOGIN" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$userdlg_loginname"
    fi

    cui_edit_new "$dlg" "" 19 5 25 1 255 "$IDC_USERDLG_EDPASSWD1" "$EF_PASSWORD" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$userdlg_passwd1"
    fi

    cui_edit_new "$dlg" "" 19 7 25 1 255 "$IDC_USERDLG_EDPASSWD2" "$EF_PASSWORD" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$userdlg_passwd2"
    fi

    cui_edit_new "$dlg" "" 19 9 27 1 255 "$IDC_USERDLG_EDNOTE" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$userdlg_note"
    fi

    cui_checkbox_new "$dlg" "Account is &active" 15 11 22 1 "$IDC_USERDLG_CHKACTIVE" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_checkbox_setcheck "$ctrl" "$userdlg_active"
    fi

    cui_button_new "$dlg" "&OK" 13 13 10 1 $IDC_USERDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" userdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 24 13 10 1 $IDC_USERDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" userdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#============================================================================
# invoke user dialog due to key or menu selection
#============================================================================

#----------------------------------------------------------------------------
# users_createuser_dialog
# Create a new mail user
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function users_createuser_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg

    userdlg_loginname=""
    userdlg_email=""
    userdlg_passwd1=""
    userdlg_passwd2=""
    userdlg_note=""
    userdlg_active="1"

    cui_window_new "$win" 0 0 50 17 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create entry"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  userdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"
            my_exec_sql "$myconn" \
                "INSERT INTO virtual_relayhosts(domain_id, email, username, password, active, note) \
                 VALUES ('${current_domain_id}', \
                         '${userdlg_email}', \
                         '${userdlg_loginname}', \
                         AES_ENCRYPT('${userdlg_passwd1}','${VMAIL_SQL_ENCRYPT_KEY}'), \
                         '${userdlg_active}', \
                         '${userdlg_note}' );"
            if p_sql_success "$p2"
            then
                selected_entry=${userdlg_email}
            else
                my_server_geterror "$myconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi
        else
            cui_window_destroy "$dlg"
        fi
    fi
    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# users_edituser_dialog
# Modify an existing mail user
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function users_edituser_dialog()
{
    local win="$1"
    local dlg
    local result="$IDCANCEL"
    local ctrl
    local idx
    local entryname

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"

        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0"
            userdlg_email="$p2"
            cui_listview_gettext "$ctrl" "$idx" "1"
            userdlg_loginname="$p2"
            cui_listview_gettext "$ctrl" "$idx" "2"
            userdlg_active="$p2"
            cui_listview_gettext "$ctrl" "$idx" "3"
            userdlg_note="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4"
            userdlg_id="$p2"

            userdlg_passwd1="xxxxxxxxxxxxxxxx"
            userdlg_passwd2="xxxxxxxxxxxxxxxx"

            cui_window_new "$win" 0 0 50 17 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle $dlg
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit User"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  userdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    cui_window_destroy "$dlg"

                    if [ "$userdlg_passwd1" != "xxxxxxxxxxxxxxxx" ]
                    then
                        my_exec_sql "$myconn" \
                            "UPDATE virtual_relayhosts \
                                SET email= '${userdlg_email}', \
                                    username= '${userdlg_loginname}', \
                                    password=AES_ENCRYPT('${userdlg_passwd1}','${VMAIL_SQL_ENCRYPT_KEY}'), \
                                    active='${userdlg_active}', \
                                    note= '${userdlg_note}' \
                              WHERE id = '${userdlg_id}';"
                    else
                        my_exec_sql "$myconn" \
                            "UPDATE virtual_relayhosts \
                                SET email= '${userdlg_email}', \
                                    username= '${userdlg_loginname}', \
                                    active='${userdlg_active}', \
                                    note='${userdlg_note}' \
                              WHERE id = '${userdlg_id}';"
                    fi

                    if p_sql_success "$p2"
                    then
                        selected_entry=${userdlg_email}
                    else
                        my_server_geterror "$myconn"
                        cui_message "$win" "$p2" "Error" "$MB_ERROR"
                    fi
                else
                    cui_window_destroy "$dlg"
                fi
            fi
        else
            cui_message "$win" "No item selected" "Info" "$MB_OK"
        fi
    fi
    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# users_deleteuser_dialog
# Delete an existing mail user
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function users_deleteuser_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local idx
    local entryname

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"
        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0"
            userdlg_email="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4"
            userdlg_id="$p2"

            cui_message "$win" "Really delete \"$userdlg_email\"?" "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                my_exec_sql "$myconn" \
                    "DELETE FROM virtual_relayhosts WHERE id = '${userdlg_id}';"
                if p_sql_success "$p2"
                then
                    result="$IDOK"
                    selected_entry=''
                else
                    my_server_geterror "$myconn"
                    cui_message "$win" "$p2" "Error" "$MB_ERROR"
                fi
            fi
        else
            cui_message "$win" "No item selected" "Info" "$MB_OK"
        fi
    fi
    [ "$result" == "$IDOK" ]
    return "$?"
}

#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# listview_clicked_hook
# listitem has been clicked
# expects: $p1 : window handle of parent window
#          $p2 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------
function listview_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local menu
    local result
    local item
    local dlg

    cui_menu_new "$win" "Options" 0 0 25 14 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Edit entry"        1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_additem      "$menu" "Create new entry"  3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Search filter"     4
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Select domain"     5
        cui_menu_additem      "$menu" "Exit application"  6
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu"        0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" "menu_clicked_hook"
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" "menu_escape_hook"
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" "menu_postkey_hook"

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu" && item="$p2"

            case $item in
            1)
                cui_window_destroy  "$menu"
                if users_edituser_dialog $win
                then
                     load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if users_deleteuser_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if users_createuser_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            4)
                cui_window_destroy  "$menu"
                cui_window_new "$win" 0 0 46 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
                if cui_valid_handle $dlg
                then
                    cui_window_setcolors "$dlg" "DIALOG"
                    cui_window_settext   "$dlg" "Search Filter"
                    cui_window_sethook   "$dlg" "$HOOK_CREATE"  inputdlg_create_hook
                    cui_window_create    "$dlg"

                    inputdlg_value=${keyword}

                    cui_window_modal     "$dlg" && result="$p2"
                    if  [ "$result" == "$IDOK" ]
                    then
                        cui_window_destroy "$dlg"
                        keyword=${inputdlg_value}
                        load_data "$win"
                    else
                        cui_window_destroy "$dlg"
                    fi
                fi
                ;;
            5)
                cui_window_destroy  "$menu"
                local old_domain=${current_domain}
                select_domain $win
                if [ "$old_domain" != "$current_domain" ]
                then
                    cui_window_settext "$mainwin" "Smarthost user for relay domain: ${current_domain}"
                    load_data "$win"
                fi
                ;;
            6)
                cui_window_destroy  "$menu"
                cui_window_quit 0
                ;;
            *)
                cui_window_destroy  "$menu"
                ;;
            esac
        else
            cui_window_destroy  "$menu"
        fi
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
#  listview_postkey_hook (catch ENTER key)
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------
function listview_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"

    if [ "$key" == "$KEY_ENTER" ]
    then
        listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
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
    local win="$p2"
    local ctrl

    cui_listview_new "$win" "" 0 0 10 10 5 "$IDC_LISTVIEW" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED" "$win" "listview_clicked_hook"
        cui_listview_callback   "$ctrl" "$LISTBOX_POSTKEY" "$win" "listview_postkey_hook"
        cui_listview_setcoltext "$ctrl" 0 "E-Mail address"
        cui_listview_setcoltext "$ctrl" 1 "Login username"
        cui_listview_setcoltext "$ctrl" 2 "Active"
        cui_listview_setcoltext "$ctrl" 3 "Comment"
        cui_listview_setcoltext "$ctrl" 4 "Nr"
        cui_window_create       "$ctrl"
    fi
    cui_textview_new "$win" "Help" 0 0 10 10 "$IDC_HELPTEXT" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_window_setcolors  "$ctrl" "HELP"
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_init_hook (load data)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function mainwin_init_hook()
{
    local win="$p2"
    local ctrl

    cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_add "$ctrl" "Use function keys to edit (F4), create (F7) or delete (F8) relay users." "0"
        cui_textview_add "$ctrl" " E-Mail: user@domain.tld  or  mail.domain.tld for all sender" "0"
        cui_textview_add "$ctrl" " Login:  username  or  username@domain.tld" "1"
     fi

    my_server_connect "$vmail_sql_server" \
        "0" \
        "$vmail_sql_user" \
        "$vmail_sql_pass" \
        "$vmail_sql_db_name" && myconn="$p2"

    if cui_valid_handle $myconn
    then
        my_server_isconnected "$myconn"
        if p_sql_success "$p2"
        then
            if [ "$POSTFIX_SMARTHOST" = "no" ]
            then
                cui_message "$win" "POSTFIX_SMARTHOST if not set to yes" \
                           "Missing configuration" "$MB_ERROR"
                cui_window_quit 0
            else
                selected_entry=''
                select_domain "$win"
                if [ -n "$current_domain" ]
                then
                    cui_window_settext "$mainwin" "Smarthost user administration: ${current_domain}"
                    load_data "$win"
                else
                    cui_window_quit 0
                fi
            fi
        else
            my_server_geterror "$myconn"
            cui_message "$win" "$p2" "Error" "$MB_ERROR"
            cui_window_quit 0
        fi
    else
        cui_message "$win" "Unable to connect to database!" "Error" "$MB_ERROR"
        cui_window_quit 0
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_key_hook (handle key events for mainwin)
#    $p2 --> mainwin window handle
#    $p3 --> key code
#----------------------------------------------------------------------------
function mainwin_key_hook()
{
    local win="$p2"
    local key="$p3"
    local dlg

    case $key in
    "$KEY_F1")
        if [ "$show_help" == "yes" ]
        then
            show_help="no"
        else
            show_help="yes"
        fi
        resize_windows $win
        ;;
    "$KEY_F4")
        if users_edituser_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F3")
        cui_window_new "$win" 0 0 46 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
        if cui_valid_handle $dlg
        then
            cui_window_setcolors "$dlg" "DIALOG"
            cui_window_settext   "$dlg" "Search Filter"
            cui_window_sethook   "$dlg" "$HOOK_CREATE"  inputdlg_create_hook
            cui_window_create    "$dlg"

            inputdlg_value=${keyword}

            cui_window_modal     "$dlg" && result="$p2"
            if  [ "$result" == "$IDOK" ]
            then
                cui_window_destroy "$dlg"
                keyword=${inputdlg_value}
                load_data "$win"
            else
                cui_window_destroy "$dlg"
            fi
        fi
        ;;
    "$KEY_F7")
        if users_createuser_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if users_deleteuser_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F9")
        local old_domain="$current_domain"
        select_domain $win
        if [ "$old_domain" != "$current_domain" ]
        then
            cui_window_settext "$mainwin" "Smarthost user administration: ${current_domain}"
            load_data "$win"
        fi
        ;;
    "$KEY_F10")
        cui_window_quit 0
        ;;
    *)
        cui_return 0
        return
        ;;
    esac
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
    local win="$p2"
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
    my_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load mysql shell extension!" "Error" "$MB_ERROR"
        cui_return 0
        return
    fi

    # setup main window
    cui_window_new "$win" 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED] && mainwin="$p2"
    if cui_valid_handle $mainwin
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "Smarthost user administration:"
        cui_window_setlstatustext "$mainwin" "Commands:F1=Help F3=Search F4=Edit F7=Create F8=Delete F9=Domain F10=Exit"
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
