#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-tools-fetchmail.cui.sh
# Copyright (c) 2001-2016 the eisfair team, team(at)eisfair(dot)org
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

IDC_LISTVIEW='10'                   # listview ID
IDC_HELPTEXT='11'                   # help text ID

IDC_FETCHMAILDLG_BUTOK='10'         # dlg OK button ID
IDC_FETCHMAILDLG_BUTCANCEL='11'     # dlg Cancel button ID
IDC_FETCHMAILDLG_LABEL1='12'        # dlg label ID
IDC_FETCHMAILDLG_LABEL2='13'        # dlg label ID
IDC_FETCHMAILDLG_LABEL3='14'        # dlg label ID
IDC_FETCHMAILDLG_LABEL4='15'        # dlg label ID
IDC_FETCHMAILDLG_LABEL5='16'        # dlg label ID
IDC_FETCHMAILDLG_LABEL6='17'        # dlg label ID
IDC_FETCHMAILDLG_EDSERVER='20'      # dlg edit ID
IDC_FETCHMAILDLG_EDLOGIN='21'       # dlg edit ID
IDC_FETCHMAILDLG_EDPASSWD1='22'     # dlg edit ID
IDC_FETCHMAILDLG_EDPASSWD2='23'     # dlg edit ID
IDC_FETCHMAILDLG_EDRECIPIENT='24'   # dlg edit ID
IDC_FETCHMAILDLG_EDOPTIONS='25'     # dlg edit ID
IDC_FETCHMAILDLG_CHKACTIVE='26'     # dlg edit ID

IDC_INPUTDLG_BUTOK='10'             # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'         # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'           # dlg edit ID

current_user=''
current_user_id="0"

selected_entry=''
show_help="no"


vmail_sql_server="localhost"
vmail_sql_db_name="vmaildata"
vmail_sql_user="vmailprovider"
vmail_sql_pass="vmail"

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
    if [ "$1" != "" -a "$1" -ge "0" ]
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
    if [ "$1" != "" -a "$1" != "0" ]
    then
        return 0
    fi
    return 1
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
                "SELECT loginname, servername, recipient, options, \
                 prot, ELT(active +1, ' ', 'x'), id \
                 FROM fetchmail WHERE ownerid = $current_user_id \
                 ORDER BY servername, loginname" && myres="$p2"
        else
            my_query_sql "$myconn" \
                "SELECT loginname, servername, recipient, options, \
                 prot, ELT(active +1, ' ', 'x'), id \
                 FROM fetchmail \
                 WHERE ownerid = $current_user_id AND a.recipient REGEXP '$keyword' \
                 ORDER BY servername, loginname" && myres="$p2"
        fi

        if cui_valid_handle "$myres"
        then
            my_result_status "$myres"
            if [ "$p2" == "$SQL_DATA_READY" ]
            then
                my_result_tolist "$myres" "$ctrl" "7" "$selected_entry"
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
# mail user selection menu
#============================================================================
#----------------------------------------------------------------------------
# resize menu depending on number of entries
# $1 --> appl. window
# $2 --> menu
# $3 --> no. of users
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
    [ $mh -gt $h ] && mh=$h-2

    cui_window_move  "$menu" "$mx" "$my" "50" "$mh"
}

#----------------------------------------------------------------------------
# select a user to edit fetchmail entries
#----------------------------------------------------------------------------
function select_user()
{
    local win="$1"
    local ctrl
    local myres
    local idx='1'
    local menu
    local result
    local item
    local user
    local user_ids

    cui_menu_new "$win" "Select user" 0 0 50 11 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        # execute query and return result
        my_query_sql "$myconn" \
            "SELECT    email, id \
             FROM      view_users;" && myres="$p2"
        if cui_valid_handle "$myres"
        then
            my_result_status "$myres"
            if [ "$p2" == "$SQL_DATA_READY" ]
            then
                my_result_fetch "$myres"
                while [ "$p2" == "1" ]
                do
                    my_result_data    "$myres" "0"
                    user[$idx]="$p2"
                    cui_menu_additem  "$menu" "$p2" "$idx"
                    my_result_data    "$myres" "1"
                    user_ids[$idx]="$p2"
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
                current_user=${user[$item]}
                current_user_id=${user_ids[$item]}
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

    if cui_label_new "$dlg" "Keyword:" 2 1 14 1 "$IDC_INPUTDLG_LABEL1" "$CWS_NONE" "$CWS_NONE"
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
# edit/create dialog
#============================================================================
#----------------------------------------------------------------------------
# fetchmaildlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function fetchmaildlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDSERVER" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_server="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDLOGIN" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_login="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDPASSWD1" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_passwd1="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDPASSWD2" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_passwd2="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDRECIPIENT" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_recipient="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_EDOPTIONS" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        fetchmaildlg_options="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_FETCHMAILDLG_CHKACTIVE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && dlgdata_active="$p2"
    fi

    if [ -z "$fetchmaildlg_server" ]
    then
        cui_message "$win" "No server name entered! Please enter a valid server" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ -z "$fetchmaildlg_login" ]
    then
        cui_message "$win" "No login name given! Please enter a valid name." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ -z "$fetchmaildlg_passwd1" ]
    then
        cui_message "$win" "Empty password supplied! Please enter a valid password." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ "$fetchmaildlg_passwd1" != "$fetchmaildlg_passwd2" ]
    then
        cui_message "$win" "Passwords do not match! Please reenter passwords." \
                           "Invalid data" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ -z "$fetchmaildlg_recipient" ]
    then
        cui_message "$win" "No recipient given! Please enter a valid recipient address." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# fetchmaildlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function fetchmaildlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# fetchmaildlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------
function fetchmaildlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "Server:" 2 1 14 1 $IDC_FETCHMAILDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Loginname:" 2 3 14 1 $IDC_FETCHMAILDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Password:" 2 5 14 1 $IDC_FETCHMAILDLG_LABEL3 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Retype passwd:" 2 7 14 1 $IDC_FETCHMAILDLG_LABEL4 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Recipient:" 2 9 14 1 $IDC_FETCHMAILDLG_LABEL5 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Options:" 2 11 14 1 $IDC_FETCHMAILDLG_LABEL6 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 20 1 255 $IDC_FETCHMAILDLG_EDSERVER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_server"
    fi
    cui_edit_new "$dlg" "" 17 3 20 1 255 $IDC_FETCHMAILDLG_EDLOGIN $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_login"
    fi
    cui_edit_new "$dlg" "" 17 5 20 1 255 $IDC_FETCHMAILDLG_EDPASSWD1 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_passwd1"
    fi
    cui_edit_new "$dlg" "" 17 7 20 1 255 $IDC_FETCHMAILDLG_EDPASSWD2 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_passwd2"
    fi
    cui_edit_new "$dlg" "" 17 9 20 1 255 $IDC_FETCHMAILDLG_EDRECIPIENT $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_recipient"
    fi
    cui_edit_new "$dlg" "" 17 11 20 1 255 $IDC_FETCHMAILDLG_EDOPTIONS $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$fetchmaildlg_options"
    fi
    cui_checkbox_new "$dlg" "Account is &active" 13 13 20 1 $IDC_FETCHMAILDLG_CHKACTIVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$dlgdata_active"
    fi

    cui_button_new "$dlg" "&OK" 9 15 10 1 $IDC_FETCHMAILDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" fetchmaildlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
    cui_button_new "$dlg" "&Cancel" 20 15 10 1 $IDC_FETCHMAILDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" fetchmaildlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# invoke dialog due to key or menu selection
#============================================================================
#----------------------------------------------------------------------------
# fetchmails_create_dialog
# Create a new mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function fetchmails_create_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    local myres

    fetchmaildlg_server=""
    fetchmaildlg_login=""
    fetchmaildlg_passwd1=""
    fetchmaildlg_passwd2=""
    fetchmaildlg_recipient=""
    fetchmaildlg_options="keep"
    dlgdata_active="1"

    cui_window_new "$win" 0 0 42 18 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Fetchmail Query"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  fetchmaildlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"
            my_exec_sql "$myconn" \
                "INSERT INTO fetchmail(ownerid, loginname, servername, password, recipient, options, active) \
                 VALUES ('${current_user_id}', \
                         '${fetchmaildlg_login}', \
                         '${fetchmaildlg_server}', \
                         AES_ENCRYPT('${fetchmaildlg_passwd1}','${VMAIL_SQL_ENCRYPT_KEY}'), \
                         '${fetchmaildlg_recipient}', \
                         '${fetchmaildlg_options}', \
                         '${dlgdata_active}');"
            if p_sql_success "$p2"
            then
                my_query_sql "$myconn" \
                    "SELECT id FROM fetchmail \
                      WHERE recipient='${fetchmaildlg_recipient}' \
                        AND servername='${fetchmaildlg_server}' \
                        AND loginname='${fetchmaildlg_login}'" && myres="$p2"
                if cui_valid_handle "$myres"
                then
                    my_result_status "$myres"
                    if [ "$p2" == "$SQL_DATA_READY" ]
                    then
                        my_result_fetch "$myres"
                        if p_sql_success "$p2"
                        then
                            my_result_data "$myres" "0" && selected_entry="$p2"
                        fi
                    else
                        my_server_geterror "$myconn"
                        cui_message "$win" "$p2" "Error" "$MB_ERROR"
                    fi
                    my_result_free "$myres"
                else
                    my_server_geterror "$myconn"
                    cui_message "$win" "$p2" "Error" "$MB_ERROR"
                fi
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
# fetchmails_edit_dialog
# Modify a mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function fetchmails_edit_dialog()
{
    local win="$1"
    local dlg
    local result="$IDCANCEL"
    local ctrl
    local idx
    local edit_id

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"

        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0" && fetchmaildlg_login="$p2"
            cui_listview_gettext "$ctrl" "$idx" "1" && fetchmaildlg_server="$p2"
            cui_listview_gettext "$ctrl" "$idx" "2" && fetchmaildlg_recipient="$p2"
            cui_listview_gettext "$ctrl" "$idx" "3" && fetchmaildlg_options="$p2"
            cui_listview_gettext "$ctrl" "$idx" "5" && dlgdata_active="$p2"
            cui_listview_gettext "$ctrl" "$idx" "6" && edit_id="$p2"

            fetchmaildlg_passwd1="xxxxxxxxxxxxxxxx"
            fetchmaildlg_passwd2="xxxxxxxxxxxxxxxx"
            [ "$dlgdata_active" = "x" ] && dlgdata_active="1" || dlgdata_active="0"

            cui_window_new "$win" 0 0 42 18 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle $dlg
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Fetchmail Query"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  fetchmaildlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    cui_window_destroy "$dlg"

                    if [ "$fetchmaildlg_passwd1" != "xxxxxxxxxxxxxxxx" ]
                    then
                        my_exec_sql "$myconn" \
                            "UPDATE fetchmail \
                                SET loginname='${fetchmaildlg_login}', \
                                    servername='${fetchmaildlg_server}', \
                                    recipient='${fetchmaildlg_recipient}', \
                                    options='${fetchmaildlg_options}', \
                                    password=AES_ENCRYPT('${fetchmaildlg_passwd1}','${VMAIL_SQL_ENCRYPT_KEY}'), \
                                    active='${dlgdata_active}' \
                              WHERE id='${edit_id}';"
                    else
                        my_exec_sql "$myconn" \
                            "UPDATE fetchmail \
                                SET loginname='${fetchmaildlg_login}', \
                                    servername='${fetchmaildlg_server}', \
                                    recipient='${fetchmaildlg_recipient}', \
                                    options='${fetchmaildlg_options}', \
                                    active='${dlgdata_active}' \
                              WHERE id='${edit_id}';"
                    fi

                    if p_sql_success "$p2"
                    then
                        selected_entry="$edit_id"
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
# fetchmails_delete_dialog
# Delete a mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function fetchmails_delete_dialog()
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
            cui_listview_gettext "$ctrl" "$idx" "7" && entryname="$p2"

            cui_message "$win" "Really delete selected fetchmail query?" "Question" "$MB_YESNO"
            if [ "$p2" == "$IDYES" ]
            then

                my_exec_sql "$myconn" \
                    "DELETE FROM fetchmail \
                      WHERE id='${entryname}';"
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
# select menu when hitting "ENTER" or "SPACE" on the list
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

    cui_menu_new "$win" "Options" 0 0 25 13 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Edit entry"        1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_additem      "$menu" "Create new entry"  3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Search filter"     4
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Select user"       5  
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
                if fetchmails_edit_dialog $win
                then
                     load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if fetchmails_delete_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if fetchmails_create_dialog $win
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

                local old_user=${current_user}
                select_user $win
                if [ "$old_user" != "$current_user" ]
                then
                    cui_window_settext "$mainwin" "Fetchmail administration for: ${current_user}"
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

    cui_listview_new "$win" "" 0 0 10 10 7 "$IDC_LISTVIEW" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED" "$win" "listview_clicked_hook"
        cui_listview_callback   "$ctrl" "$LISTBOX_POSTKEY" "$win" "listview_postkey_hook"
        cui_listview_setcoltext "$ctrl" 0 "Loginname"
        cui_listview_setcoltext "$ctrl" 1 "Servername"
        cui_listview_setcoltext "$ctrl" 2 "Recipient"
        cui_listview_setcoltext "$ctrl" 3 "Options"
        cui_listview_setcoltext "$ctrl" 4 "Prot"
        cui_listview_setcoltext "$ctrl" 5 "Active"
        cui_listview_setcoltext "$ctrl" 6 "-"
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
        cui_textview_add "$ctrl" "Use function keys to edit (F4), create (F7) or delete (F8) fetchmail queries." "0"
        cui_textview_add "$ctrl" "F3  = Search entry with regular expression" "0"
        cui_textview_add "$ctrl" "F4  = Edit current fetchmail entry" "0"
        cui_textview_add "$ctrl" "F7  = Create new fetchmail entry" "0"
        cui_textview_add "$ctrl" "F8  = Remove fetchmail entry" "0"
        cui_textview_add "$ctrl" "F10 = Exit" "1"
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
            selected_entry=''
            select_user "$win"

            if [ -n "$current_user" ]
            then
                cui_window_settext "$mainwin" "Fetchmail administration for: ${current_user}"
                load_data "$win"
            else
                cui_window_quit 0
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
    "$KEY_F4")
        if fetchmails_edit_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F7")
        if fetchmails_create_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if fetchmails_delete_dialog $win
        then
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
        cui_window_settext        "$mainwin" "Fetchmail user administration:"
        cui_window_setlstatustext "$mainwin" "Commands: F1=Help F3=Search F4=Edit F7=Create F8=Delete F10=Exit"
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
