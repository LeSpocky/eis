#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-tools-sender-access.cui.sh
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

IDC_LISTVIEW='10'                   # listview ID
IDC_HELPTEXT='11'                   # help text ID

IDC_SENDERDLG_BUTOK='10'            # dlg OK button ID
IDC_SENDERDLG_BUTCANCEL='11'        # dlg Cancel button ID
IDC_SENDERDLG_LABEL1='12'           # dlg label ID
IDC_SENDERDLG_LABEL2='13'           # dlg label ID
IDC_SENDERDLG_LABEL3='14'           # dlg label ID
IDC_SENDERDLG_EDSENDER='20'         # dlg edit ID
IDC_SENDERDLG_EDRESPONSE='21'       # dlg edit ID
IDC_SENDERDLG_EDCOMMENT='22'        # dlg edit ID
IDC_SENDERDLG_CHKACTIVE='26'        # dlg edit ID

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
                "SELECT source, LEFT(response,50), ELT(active +1, ' ', 'x'), LEFT(note,50), id \
                 FROM access \
                 WHERE type='sender' ORDER BY source;" && myres="$p2"
        else
            my_query_sql "$myconn" \
                "SELECT source ,LEFT(response,50), ELT(active +1, ' ', 'x'), LEFT(note,50), id \
                 FROM access \
                 WHERE type='sender' AND source REGEXP '$keyword' \
                 ORDER BY source;" && myres="$p2"
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
# edit/create dialog
#============================================================================
#----------------------------------------------------------------------------
# senderdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function senderdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_SENDERDLG_EDSENDER" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        senderdlg_sender="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_SENDERDLG_EDRESPONSE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        senderdlg_response="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_SENDERDLG_EDCOMMENT" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        senderdlg_comment="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_SENDERDLG_CHKACTIVE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && senderdlg_active="$p2"
    fi

    if [ -z "$senderdlg_sender" ]
    then
        cui_message "$win" "No sender soruce entered! Please enter a valid sender" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$senderdlg_response" ]
    then
        cui_message "$win" "No response entered! Please enter a valid response." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# senderdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function senderdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# senderdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------
function senderdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "Sender:" 2 1 10 1 $IDC_SENDERDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Response:" 2 3 10 1 $IDC_SENDERDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Comment:" 2 5 10 1 $IDC_SENDERDLG_LABEL3 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 13 1 26 1 255 $IDC_SENDERDLG_EDSENDER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$senderdlg_sender"
    fi

    cui_edit_new "$dlg" "" 13 3 26 1 255 $IDC_SENDERDLG_EDRESPONSE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$senderdlg_response"
    fi

    cui_edit_new "$dlg" "" 13 5 26 1 255 $IDC_SENDERDLG_EDCOMMENT $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$senderdlg_comment"
    fi

    cui_checkbox_new "$dlg" "Entry is &active" 13 7 20 1 $IDC_SENDERDLG_CHKACTIVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$senderdlg_active"
    fi

    cui_button_new "$dlg" "&OK" 9 9 10 1 $IDC_SENDERDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" senderdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 20 9 10 1 $IDC_SENDERDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" senderdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#============================================================================
# invoke dialog due to key or menu selection
#============================================================================
#----------------------------------------------------------------------------
# sender_create_dialog
# Create a new entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function sender_create_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    local myres;

    senderdlg_sender=""
    senderdlg_response="DUNNO"
    senderdlg_comment=""
    senderdlg_active="1"

    cui_window_new "$win" 0 0 42 12 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Recipient Handling"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  senderdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"

            my_exec_sql "$myconn" \
                "INSERT INTO access(source, response, type, note, active) \
                 VALUES ('${senderdlg_sender}', \
                         '${senderdlg_response}', \
                         'sender', \
                         '${senderdlg_comment}', \
                         '${senderdlg_active}');"
            if p_sql_success "$p2"
            then
                selected_entry="$senderdlg_sender"
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
# sender_edit_dialog
# Modify a entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function sender_edit_dialog()
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
            cui_listview_gettext "$ctrl" "$idx" "0" && senderdlg_sender="$p2"
            cui_listview_gettext "$ctrl" "$idx" "1" && senderdlg_response="$p2"
            cui_listview_gettext "$ctrl" "$idx" "2" && senderdlg_active="$p2"
            cui_listview_gettext "$ctrl" "$idx" "3" && senderdlg_comment="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4" && entryname="$p2"
            [ "$senderdlg_active" = "x" ] && senderdlg_active="1" || senderdlg_active="0"

            cui_window_new "$win" 0 0 42 12 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle $dlg
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Recipient Handling"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  senderdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    cui_window_destroy "$dlg"

                    my_exec_sql "$myconn" \
                        "UPDATE access \
                            SET source='${senderdlg_sender}', \
                                response='${senderdlg_response}', \
                                note='${senderdlg_comment}', \
                                active='${senderdlg_active}' \
                          WHERE id='$entryname';"

                    if p_sql_success "$p2"
                    then
                        selected_entry=${senderdlg_sender}
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
# sender_delete_dialog
# Delete a entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function sender_delete_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local idx
    local senderdlg_sender
    local entryname

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"

        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0" && senderdlg_sender="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4" && entryname="$p2"

            cui_message "$win" "Really delete entry '$senderdlg_sender'?" "Question" "$MB_YESNO"
            if [ "$p2" == "$IDYES" ]
            then
                my_exec_sql "$myconn" \
                    "DELETE FROM access \
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
                if sender_edit_dialog $win
                then
                     load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if sender_delete_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if sender_create_dialog $win
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

    cui_listview_new "$win" "" 0 0 10 10 5 "$IDC_LISTVIEW" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle $ctrl
    then
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED" "$win" "listview_clicked_hook"
        cui_listview_callback   "$ctrl" "$LISTBOX_POSTKEY" "$win" "listview_postkey_hook"
        cui_listview_setcoltext "$ctrl" 0 "Sender"
        cui_listview_setcoltext "$ctrl" 1 "Response"
        cui_listview_setcoltext "$ctrl" 2 "Active"
        cui_listview_setcoltext "$ctrl" 3 "Comment"
        cui_listview_setcoltext "$ctrl" 4 "-"
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
        cui_textview_add "$ctrl" "sender access handling." "0"
        cui_textview_add "$ctrl" "Sender   = e-mail sender name. Example: hotmail.com." "0"
        cui_textview_add "$ctrl" "Response = response handling, see follow options:" "0"
        cui_textview_add "$ctrl" "reject_unverified_sender" "0"
        cui_textview_add "$ctrl" "   Check if sender e-mail user exists." "0"
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
        cui_textview_add "$ctrl" "   Reject the entire message." "1"
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
        if sender_edit_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F7")
        if sender_create_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if sender_delete_dialog $win
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
        cui_window_settext        "$mainwin" "E-Mail sender access administration:"
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
