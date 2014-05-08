#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-tools-client-access.cui.sh
# Copyright (c) 2001-2014 the eisfair team, team(at)eisfair(dot)org
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

IDC_CLIENTDLG_BUTOK='10'            # dlg OK button ID
IDC_CLIENTDLG_BUTCANCEL='11'        # dlg Cancel button ID
IDC_CLIENTDLG_LABEL1='12'           # dlg label ID
IDC_CLIENTDLG_LABEL2='13'           # dlg label ID
IDC_CLIENTDLG_LABEL3='14'           # dlg label ID
IDC_CLIENTDLG_LABEL4='15'           # dlg label ID
IDC_CLIENTDLG_LABEL5='16'           # dlg label ID
IDC_CLIENTDLG_EDCLIENT='20'         # dlg edit ID
IDC_CLIENTDLG_EDIPSTART='21'        # dlg edit ID
IDC_CLIENTDLG_EDIPEND='22'          # dlg edit ID
IDC_CLIENTDLG_EDRESPONSE='23'       # dlg edit ID
IDC_CLIENTDLG_EDCOMMENT='24'        # dlg edit ID
IDC_CLIENTDLG_CHKACTIVE='25'        # dlg edit ID

IDC_INPUTDLG_BUTOK='10'             # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'         # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'           # dlg edit ID

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
    if [ -n "$1" -a "$1" -ge "0" ]
    then
        return 0
    fi
    return 1
}

#----------------------------------------------------------------------------
# check if ip and convert to start - end range
#----------------------------------------------------------------------------
function convert_ip_range()
{
    local ip="$1"
    local startip=""
    clientdlg_ip_start="0"
    clientdlg_ip_end="0"
    startip=$(echo "$ip" | grep -oE "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)")
    if [ $? -eq 0 -a -n "$startip" ]
    then
        clientdlg_ip_start="$startip"
        clientdlg_ip_end=$(/var/install/bin/netcalc broadcast "$ip")
    fi
}

#----------------------------------------------------------------------------
# check if ip or empty
#----------------------------------------------------------------------------
function check_ip_or_empty()
{
    local ip="$1"
    local startip=""
    [ -z "$ip" ] && return 1
    startip=$(echo "$ip" | grep -oE "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
    if [ $? -eq 0 -a -n "$startip" ]
    then
        return 1
    fi
    return 0
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
                "SELECT source,INET_NTOA(sourcestart),INET_NTOA(sourceend),LEFT(response,50),active,LEFT(note,50),id \
                 FROM access \
                 WHERE type='client' ORDER BY sourcestart, source;" && myres="$p2"
        else
            my_query_sql "$myconn" \
                "SELECT source,INET_NTOA(sourcestart),INET_NTOA(sourceend),LEFT(response,50),active,LEFT(note,50),id \
                 FROM access \
                 WHERE type='client' AND source REGEXP '$keyword' \
                 ORDER BY sourcestart, source;" && myres="$p2"
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
# fetchmail edit/create dialog
#============================================================================

#----------------------------------------------------------------------------
# clientdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function clientdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_CLIENTDLG_EDCLIENT" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        clientdlg_client="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_CLIENTDLG_EDIPSTART" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        clientdlg_ip_start="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_CLIENTDLG_EDIPEND" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        clientdlg_ip_end="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_CLIENTDLG_EDRESPONSE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        clientdlg_response="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_CLIENTDLG_EDCOMMENT" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        clientdlg_comment="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_CLIENTDLG_CHKACTIVE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && clientdlg_active="$p2"
    fi

    if [ -z "$clientdlg_client" ]
    then
        cui_message "$win" "No client source entered! Please enter a valid client" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi
    if check_ip_or_empty "$clientdlg_ip_start"
    then
        cui_message "$win" "Input IP address or empty!" \
                           "Input IP start fail" "$MB_ERROR"
        cui_return 1
        return
    fi
    if check_ip_or_empty "$clientdlg_ip_end"
    then
        cui_message "$win" "Input IP address or empty!" \
                           "Input IP end fail" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ -z "$clientdlg_response" ]
    then
        cui_message "$win" "No response entered! Please enter a valid response. (OK or 554 ...)" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# clientdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function clientdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# clientdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------
function clientdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "Client:" 2 1 10 1 $IDC_CLIENTDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "IP start:" 2 3 10 1 $IDC_CLIENTDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "IP end:" 2 5 10 1 $IDC_CLIENTDLG_LABEL3 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Response:" 2 7 10 1 $IDC_CLIENTDLG_LABEL4 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Comment:" 2 9 10 1 $IDC_CLIENTDLG_LABEL5 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 13 1 26 1 255 $IDC_CLIENTDLG_EDCLIENT $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$clientdlg_client"
    fi
    cui_edit_new "$dlg" "" 13 3 26 1 255 $IDC_CLIENTDLG_EDIPSTART $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$clientdlg_ip_start"
    fi
    cui_edit_new "$dlg" "" 13 5 26 1 255 $IDC_CLIENTDLG_EDIPEND $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$clientdlg_ip_end"
    fi
    cui_edit_new "$dlg" "" 13 7 26 1 255 $IDC_CLIENTDLG_EDRESPONSE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$clientdlg_response"
    fi
    cui_edit_new "$dlg" "" 13 9 26 1 255 $IDC_CLIENTDLG_EDCOMMENT $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$clientdlg_comment"
    fi
    cui_checkbox_new "$dlg" "Entry is &active" 13 11 20 1 $IDC_CLIENTDLG_CHKACTIVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$clientdlg_active"
    fi

    cui_button_new "$dlg" "&OK" 10 13 10 1 $IDC_CLIENTDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" clientdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
    cui_button_new "$dlg" "&Cancel" 21 13 10 1 $IDC_CLIENTDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" clientdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# invoke fetchmail dialog due to key or menu selection
#============================================================================

#----------------------------------------------------------------------------
# client_createclient_dialog
# Create a new mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function client_createclient_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    local myres

    clientdlg_client=""
    clientdlg_ip_start=""
    clientdlg_ip_end=""
    clientdlg_response="DUNNO"
    clientdlg_comment=""
    clientdlg_active="1"

    cui_window_new "$win" 0 0 44 16 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Recipient Handling"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  clientdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"

            if [ -z "$clientdlg_ip_start" ]
            then
                convert_ip_range $clientdlg_client
            else
                [ -z "$clientdlg_ip_end" ] && clientdlg_ip_end="$clientdlg_ip_start"
            fi
            my_exec_sql "$myconn" \
                "INSERT INTO access(source, sourcestart, sourceend, response, type, note, active) \
                 VALUES ('${clientdlg_client}', \
                         INET_ATON('${clientdlg_ip_start}'), \
                         INET_ATON('${clientdlg_ip_end}'), \
                         '${clientdlg_response}', \
                         'client', \
                         '${clientdlg_comment}', \
                         '${clientdlg_active}');"
            if p_sql_success "$p2"
            then
                selected_entry="$clientdlg_client"
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
# client_editclient_dialog
# Modify a mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function client_editclient_dialog()
{
    local win="$1"
    local dlg
    local result="$IDCANCEL"
    local ctrl
    local idx
    local entryid
    sourstart=0
    sourend=0

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"

        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0" && clientdlg_client="$p2"
            cui_listview_gettext "$ctrl" "$idx" "1" && clientdlg_ip_start="$p2"
            cui_listview_gettext "$ctrl" "$idx" "2" && clientdlg_ip_end="$p2"
            cui_listview_gettext "$ctrl" "$idx" "3" && clientdlg_response="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4" && clientdlg_active="$p2"
            cui_listview_gettext "$ctrl" "$idx" "5" && clientdlg_comment="$p2"
            cui_listview_gettext "$ctrl" "$idx" "6" && entryid="$p2"

            [ "$clientdlg_ip_start" = "0.0.0.0" ] && clientdlg_ip_start=""
            [ "$clientdlg_ip_end" = "0.0.0.0" ] && clientdlg_ip_end=""

            cui_window_new "$win" 0 0 44 16 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle $dlg
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Recipient Handling"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  clientdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    cui_window_destroy "$dlg"
                    if [ -z "$clientdlg_ip_start" ]
                    then
                        convert_ip_range $clientdlg_client
                    else
                        sourstart="$clientdlg_ip_start"
                        [ -z "$clientdlg_ip_end" ] && sourend="$clientdlg_ip_start" || sourend="$clientdlg_ip_end"
                    fi
                    my_exec_sql "$myconn" \
                        "UPDATE access \
                            SET source='${clientdlg_client}', \
                                sourcestart=INET_ATON('${sourstart}'), \
                                sourceend=INET_ATON('${sourend}'), \
                                response='${clientdlg_response}', \
                                note='${clientdlg_comment}', \
                                active='${clientdlg_active}' \
                          WHERE id='$entryid';"

                    if p_sql_success "$p2"
                    then
                        selected_entry=${clientdlg_client}
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
# client_deleteclient_dialog
# Delete a mail fetchmail
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function client_deleteclient_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local idx
    local clientdlg_client
    local entryid

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"

        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0" && clientdlg_client="$p2"
            cui_listview_gettext "$ctrl" "$idx" "6" && entryid="$p2"

            cui_message "$win" "Really delete entry '$clientdlg_client'?" "Question" "$MB_YESNO"
            if [ "$p2" == "$IDYES" ]
            then
                my_exec_sql "$myconn" "DELETE FROM access WHERE id='$entryid';"
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
        cui_menu_additem      "$menu" "Exit application"  5
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
                if client_editclient_dialog $win
                then
                     load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if client_deleteclient_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if client_createclient_dialog $win
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
        cui_listview_setcoltext "$ctrl" 0 "Client, domain or IP"
        cui_listview_setcoltext "$ctrl" 1 "IP range start"
        cui_listview_setcoltext "$ctrl" 2 "IP range end  "
        cui_listview_setcoltext "$ctrl" 3 "Resp."
        cui_listview_setcoltext "$ctrl" 4 "Act."
        cui_listview_setcoltext "$ctrl" 5 "Comment"
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
        cui_textview_add "$ctrl" "Use function keys to edit (F4), create (F7) or delete (F8) rules for" "0"
        cui_textview_add "$ctrl" "email client access handling." "0"
        cui_textview_add "$ctrl" "Client   = e-mail client IP or hostname." "0"
        cui_textview_add "$ctrl" "Response = response handling, see follow options:" "0"
        cui_textview_add "$ctrl" "OK" "0"
        cui_textview_add "$ctrl" "   Accept the address etc. that matches the pattern." "0"
        cui_textview_add "$ctrl" "DISCARD [optional text]" "0"
        cui_textview_add "$ctrl" "   Claim successful delivery and silently discard the message." "0"
        cui_textview_add "$ctrl" "   Log the optional text if specified." "0"
        cui_textview_add "$ctrl" "DUNNO" "0"
        cui_textview_add "$ctrl" "   Pretend that the input line did not match any pattern, and" "0"
        cui_textview_add "$ctrl" "   inspect the next input line." "0"
        cui_textview_add "$ctrl" "FILTER transport:destination" "0"
        cui_textview_add "$ctrl" "   Write a content filter request to the queue" "0"
        cui_textview_add "$ctrl" "   Example: 'FILTER dspam-retrain:innocent'" "0"
        cui_textview_add "$ctrl" "HOLD [optional text]" "0"
        cui_textview_add "$ctrl" "   Arrange  for  the  message to be placed on the hold queue." "0"
        cui_textview_add "$ctrl" "IGNORE" "0"
        cui_textview_add "$ctrl" "   Delete the current line." "0"
        cui_textview_add "$ctrl" "PREPEND text" "0"
        cui_textview_add "$ctrl" "   Append a text after current line." "0"
        cui_textview_add "$ctrl" "REDIRECT user@domain" "0"
        cui_textview_add "$ctrl" "   Write a message redirection request to the queue." "0"
        cui_textview_add "$ctrl" "   This action overrides the FILTER action!" "0"
        cui_textview_add "$ctrl" "REPLACE text" "0"
        cui_textview_add "$ctrl" "   Replace the current line with the specified text." "0"
        cui_textview_add "$ctrl" "REJECT [optional text]" "0"
        cui_textview_add "$ctrl" "   Reject the entire message. Reply with optional text." "0"
        cui_textview_add "$ctrl" "WARN [optional text]" "0"
        cui_textview_add "$ctrl" "   Log a warning with the optional text." "0"
        cui_textview_add "$ctrl" "450 [optional text]" "0"
        cui_textview_add "$ctrl" "   Temporaly reject." "0"
        cui_textview_add "$ctrl" "550 [optional text]" "0"
        cui_textview_add "$ctrl" "   Reject the entire message." "0"
        cui_textview_add "$ctrl" "554 Reject" "1"
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
            load_data "$win"
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
        if client_editclient_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F7")
        if client_createclient_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if client_deleteclient_dialog $win
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
        cui_window_settext        "$mainwin" "E-Mail client access administration:"
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
