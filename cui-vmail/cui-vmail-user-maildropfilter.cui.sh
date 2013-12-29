#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/cui-vmail-user-maildrophandling.cui.sh
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

IDC_MAILDROPDLG_BUTOK='10'       # dlg OK button ID
IDC_MAILDROPDLG_BUTCANCEL='11'   # dlg Cancel button ID
IDC_MAILDROPDLG_LABEL1='12'      # dlg label ID
IDC_MAILDROPDLG_LABEL2='13'      # dlg label ID
IDC_MAILDROPDLG_LABEL3='14'      # dlg label ID
IDC_MAILDROPDLG_LABEL4='15'      # dlg label ID
IDC_MAILDROPDLG_LABEL5='16'      # dlg label ID
IDC_MAILDROPDLG_LABEL6='17'      # dlg label ID
IDC_MAILDROPDLG_LABEL7='18'      # dlg label ID
IDC_MAILDROPDLG_LABEL8='19'      # dlg label ID
IDC_MAILDROPDLG_LABEL9='20'      # dlg label ID
IDC_MAILDROPDLG_EDOWNER='30'     # dlg edit ID
IDC_MAILDROPDLG_CBFILTER='31'    # dlg edit ID
IDC_MAILDROPDLG_EDHEADER='32'    # dlg edit ID
IDC_MAILDROPDLG_EDVALUE='33'     # dlg edit ID
IDC_MAILDROPDLG_EDFOLDER='34'    # dlg edit ID
IDC_MAILDROPDLG_CHKFLAG1='35'    # dlg edit ID
IDC_MAILDROPDLG_CHKFLAG2='36'    # dlg edit ID
IDC_MAILDROPDLG_CHKFLAG4='37'    # dlg edit ID
IDC_MAILDROPDLG_CHKFLAG8='38'    # dlg edit ID
IDC_MAILDROPDLG_EDPOSITION='39'  # dlg edit ID
IDC_MAILDROPDLG_EDSTART='40'     # dlg edit ID
IDC_MAILDROPDLG_EDEND='41'       # dlg edit ID
IDC_MAILDROPDLG_CHKACTIVE='42'   # dlg edit ID

IDC_INPUTDLG_BUTOK='10'          # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'      # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'        # dlg edit ID

maildropdlg_id='0'
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
# check if handle is valid
#----------------------------------------------------------------------------
function p_valid_handle()
{
    if [ -n "$1" -a "$1" != "0" ]
    then
        return 0
    fi
    return 1
}

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
    if p_valid_handle $ctrl
    then
        cui_listview_clear  "$ctrl"

        if [ -z "$keyword" ]
        then
            my_query_sql "$myconn" \
                "SELECT a.email, b.filtertype, b.fieldname, \
                        b.fieldvalue, b.tofolder, b.flags , b.position, b.active,\
                        FROM_UNIXTIME(b.datefrom), FROM_UNIXTIME(b.dateend), b.id \
                 FROM view_users AS a JOIN maildropfilter AS b ON a.id = b.ownerid \
                 WHERE (b.dateend > UNIX_TIMESTAMP(NOW()) OR b.dateend = 0) \
                 ORDER BY b.ownerid, b.position, b.id" && myres="$p2"
        else
            my_query_sql "$myconn" \
                "SELECT a.email, b.filtertype, b.fieldname, \
                        b.fieldvalue, b.tofolder, b.flags, b.position, b.active,\
                        FROM_UNIXTIME(b.datefrom), FROM_UNIXTIME(b.dateend), b.id \
                 FROM view_users AS a JOIN maildropfilter AS b ON a.id = b.ownerid \
                 WHERE a.email REGEXP '$keyword' \
                 ORDER BY b.ownerid, b.position, b.id" && myres="$p2"
        fi

        if p_valid_handle "$myres"
        then
            my_result_status "$myres"
            if [ "$p2" == "$SQL_DATA_READY" ]
            then
                my_result_tolist "$myres" "$ctrl" "10" "$selected_entry"
            else
                my_server_geterror "$myconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi
            my_result_free "$myres"
        else
            my_server_geterror "$myconn"
            cui_message "$win" "$p2" "Error" "$MB_ERROR"
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
        if p_valid_handle $ctrl
        then
            cui_window_move  "$ctrl" "0" "0" "$w" "$p"
        fi

        cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
        if p_valid_handle $ctrl
        then
            cui_window_move  "$ctrl" "0" "$p" "$w" "$[$h -$p]"
            cui_window_hide  "$ctrl" "0"
        fi
    else
        cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
        if p_valid_handle $ctrl
        then
            cui_window_move "$ctrl" "0" "0" "$w" "$h"
        fi

        cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
        if p_valid_handle $ctrl
        then
            cui_window_move "$ctrl" "0" "$h" "$w" "2"
            cui_window_hide "$ctrl" "1"

            cui_window_getfocus
            if [ "$p2" == "$ctrl" ]
            then
                cui_window_getctrl "$win" "$IDC_LISTVIEW"
                if p_valid_handle $p2
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
    if p_valid_handle $ctrl
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
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$inputdlg_value"
    fi

    cui_button_new "$dlg" "&OK" 11 3 10 1 $IDC_INPUTDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 22 3 10 1 $IDC_INPUTDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" inputdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#============================================================================
# maildrop edit/create dialog
#============================================================================

#----------------------------------------------------------------------------
# maildropdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function maildropdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local idx
    local myres

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDOWNER" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_owner="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CBFILTER" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_combobox_getsel "$ctrl"        && idx="$p2"
        cui_combobox_get    "$ctrl" "$idx" && maildropdlg_filter="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDHEADER" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_header="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDVALUE" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_value="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDFOLDER" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_folder="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CHKFLAG1" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && maildropdlg_flag1="$p2" 
        [ "$maildropdlg_flag1" -gt 0 ] && maildropdlg_flags=`expr $maildropdlg_flags + 1`
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CHKFLAG2" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && maildropdlg_flag2="$p2" 
        [ "$maildropdlg_flag2" -gt 0 ] && maildropdlg_flags=`expr $maildropdlg_flags + 2`
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CHKFLAG4" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl" && maildropdlg_flag4="$p2" 
        [ "$maildropdlg_flag4" -gt 0 ] && maildropdlg_flags=`expr $maildropdlg_flags + 4`
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CHKFLAG8" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
         cui_checkbox_getcheck "$ctrl" && maildropdlg_flag8="$p2" 
        [ "$maildropdlg_flag8" -gt 0 ] && maildropdlg_flags=`expr $maildropdlg_flags + 8`
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDPOSITION" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_position="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDSTART" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_datestart="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_EDEND" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_edit_gettext "$ctrl"
        maildropdlg_dateend="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_MAILDROPDLG_CHKACTIVE" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_checkbox_getcheck "$ctrl"      && maildropdlg_active="$p2"
    fi

    if [ -z "$maildropdlg_owner" ]
    then
        cui_message "$win" "No filter owner entered! Please enter a valid owner" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$maildropdlg_header" -a "$maildropdlg_filter" != "anymessage" ]
    then
        cui_message "$win" "No mail header for filter given! Please enter a valid header." \
                           "Missing data  > $maildropdlg_filter <" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$maildropdlg_folder" ]
    then
        cui_message "$win" "No target for filter given! Please enter a valid folder (Trash), target (!user@domain.com) or option (+days=2)." \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    # check if owner exists
    my_query_sql "$myconn" \
       "SELECT id FROM view_users \
        WHERE email='${maildropdlg_owner}'" && myres="$p2"
    if p_valid_handle "$myres"
    then
        my_result_status "$myres"
        if [ "$p2" == "$SQL_DATA_READY" ]
        then
            my_result_fetch "$myres"
            if p_sql_success "$p2"
            then
                my_result_data "$myres" "0" && maildropdlg_ownerid="$p2"
            else
                cui_message "$win" "Owner not found! Please enter a valid owner email address." \
                                   "Invalid data" "$MB_ERROR"
                my_result_free "$myres"
                cui_return 1
                return
            fi
        else
            my_server_geterror "$myconn"
            cui_message "$win" "$p2" "Error" "$MB_ERROR"
            my_result_free "$myres"
            cui_return 1
            return
        fi
        my_result_free "$myres"
    else
        my_server_geterror "$myconn"
        cui_message "$win" "$p2" "Error" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# maildropdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function maildropdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# maildropdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled      
#----------------------------------------------------------------------------
function maildropdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local idx

    if cui_label_new "$dlg" "Owner:" 2 1 10 1 $IDC_MAILDROPDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Filter:" 2 3 10 1 $IDC_MAILDROPDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Header:" 2 4 10 1 $IDC_MAILDROPDLG_LABEL3 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Value:" 2 5 10 1 $IDC_MAILDROPDLG_LABEL4 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Folder:" 2 6 10 1 $IDC_MAILDROPDLG_LABEL5 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Flags:" 2 7 10 1 $IDC_MAILDROPDLG_LABEL6 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Position:" 2 11 10 1 $IDC_MAILDROPDLG_LABEL7 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Date:" 2 13 10 1 $IDC_MAILDROPDLG_LABEL8 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "to:" 23 13 10 1 $IDC_MAILDROPDLG_LABEL8 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 12 1 25 1 255 $IDC_MAILDROPDLG_EDOWNER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_owner"
    fi

    cui_combobox_new "$dlg" 12 3 25 8 "$IDC_MAILDROPDLG_CBFILTER" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_combobox_add      "$ctrl" "anymessage"
        cui_combobox_add      "$ctrl" "startswith"
        cui_combobox_add      "$ctrl" "endswith"
        cui_combobox_add      "$ctrl" "contains"
        cui_combobox_add      "$ctrl" "hasrecipient"
        cui_combobox_add      "$ctrl" "mimemultipart"
        cui_combobox_add      "$ctrl" "textplain"
        cui_combobox_add      "$ctrl" "islargerthan"

        cui_combobox_select   "$ctrl" "$maildropdlg_filter"
        cui_combobox_getsel   "$ctrl" && idx="$p2"
    fi

    cui_edit_new "$dlg" "" 12 4 25 1 255 $IDC_MAILDROPDLG_EDHEADER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_header"
    fi

    cui_edit_new "$dlg" "" 12 5 25 1 255 $IDC_MAILDROPDLG_EDVALUE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_value"
    fi

    cui_edit_new "$dlg" "" 12 6 25 1 255 $IDC_MAILDROPDLG_EDFOLDER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_folder"
    fi

    cui_checkbox_new "$dlg" "Invert filter" 12 7 30 1 $IDC_MAILDROPDLG_CHKFLAG1 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$maildropdlg_flag1"
    fi
    cui_checkbox_new "$dlg" "Applied to body" 12 8 30 1 $IDC_MAILDROPDLG_CHKFLAG2 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$maildropdlg_flag2"
    fi
    cui_checkbox_new "$dlg" "Continue filtering" 12 9 30 1 $IDC_MAILDROPDLG_CHKFLAG4 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$maildropdlg_flag4"
    fi
    cui_checkbox_new "$dlg" "Plain string (not regex)" 12 10 30 1 $IDC_MAILDROPDLG_CHKFLAG8 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$maildropdlg_flag8"
    fi

    cui_edit_new "$dlg" "" 12 11 2 1 255 $IDC_MAILDROPDLG_EDPOSITION $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_position"
    fi

    cui_edit_new "$dlg" "" 12 13 10 1 255 $IDC_MAILDROPDLG_EDSTART $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_datestart"
    fi

    cui_edit_new "$dlg" "" 27 13 10 1 255 $IDC_MAILDROPDLG_EDEND $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "$maildropdlg_dateend"
    fi

    cui_checkbox_new "$dlg" "Entry is &active" 12 15 20 1 $IDC_MAILDROPDLG_CHKACTIVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_checkbox_setcheck "$ctrl" "$maildropdlg_active"
    fi

    cui_button_new "$dlg" "&OK" 9 17 10 1 $IDC_MAILDROPDLG_BUTOK $CWS_DEFOK $CWS_NONE  && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" maildropdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 20 17 10 1 $IDC_MAILDROPDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE  && ctrl="$p2"
    if p_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" maildropdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
    cui_return 1
}

#============================================================================
# invoke maildrop dialog due to key or menu selection
#============================================================================

#----------------------------------------------------------------------------
# maildrops_createmaildrop_dialog
# Create a new mail maildrop
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function maildrops_createmaildrop_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg

    maildropdlg_owner=""
    maildropdlg_filter="contains"
    maildropdlg_header="subject"
    maildropdlg_value=""
    maildropdlg_folder=""
    maildropdlg_flag1="0"
    maildropdlg_flag2="0"
    maildropdlg_flag4="0"
    maildropdlg_flag8="0"
    maildropdlg_flags="0"
    maildropdlg_position="50"
    maildropdlg_datestart="1970-01-01"
    maildropdlg_dateend="1970-01-01"
    maildropdlg_active="1"

    cui_window_new "$win" 0 0 46 20 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if p_valid_handle $dlg
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Filter"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  maildropdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            cui_window_destroy "$dlg"

            my_exec_sql "$myconn" \
                "INSERT INTO maildropfilter(ownerid, filtertype, fieldname, fieldvalue, tofolder, flags, position, active, datefrom, dateend) \
                 VALUES ('${maildropdlg_ownerid}', \
                         '${maildropdlg_filter}', \
                         '${maildropdlg_header}', \
                         '${maildropdlg_value}', \
                         '${maildropdlg_folder}', \
                         '${maildropdlg_flags}', \
                         '${maildropdlg_position}', \
                         '${maildropdlg_active}', \
                         UNIX_TIMESTAMP('${maildropdlg_datestart}'), \
                         UNIX_TIMESTAMP('${maildropdlg_dateend}'));"
            if p_sql_success "$p2"
            then
                my_query_sql "$myconn" \
                    "SELECT id FROM maildropfilter \
                      WHERE ownerid='${maildropdlg_ownerid}' \
                        AND filtertype='${maildropdlg_filter}' \
                        AND fieldname='${maildropdlg_header}' \
                        AND fieldvalue='${maildropdlg_value}' \
                        AND tofolder='${maildropdlg_folder}';" && myres="$p2"
                if p_valid_handle "$myres"
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
# maildrops_editmaildrop_dialog
# Modify a mail maildrop
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function maildrops_editmaildrop_dialog()
{
    local win="$1"
    local dlg
    local result="$IDCANCEL"
    local ctrl
    local idx
    local nflags
    maildropdlg_flag1="0"
    maildropdlg_flag2="0"
    maildropdlg_flag4="0"
    maildropdlg_flag8="0"

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"
        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "0"
            maildropdlg_owner="$p2"
            cui_listview_gettext "$ctrl" "$idx" "1"
            maildropdlg_filter="$p2"
            cui_listview_gettext "$ctrl" "$idx" "2"
            maildropdlg_header="$p2"
            cui_listview_gettext "$ctrl" "$idx" "3"
            maildropdlg_value="$p2"
            cui_listview_gettext "$ctrl" "$idx" "4"
            maildropdlg_folder="$p2"
            cui_listview_gettext "$ctrl" "$idx" "5"
            maildropdlg_flags="$p2"
            cui_listview_gettext "$ctrl" "$idx" "6"
            maildropdlg_position="$p2"
            cui_listview_gettext "$ctrl" "$idx" "7"
            maildropdlg_active="$p2"
            cui_listview_gettext "$ctrl" "$idx" "8"
            maildropdlg_datestart="$p2"
            cui_listview_gettext "$ctrl" "$idx" "9"
            maildropdlg_dateend="$p2"
            cui_listview_gettext "$ctrl" "$idx" "10"
            maildropdlg_id="$p2"

            nflags=`expr $maildropdlg_flags - 8`
            if [ $nflags -ge 0 ]
            then
                maildropdlg_flag8="1"
                maildropdlg_flags=$nflags
            fi
            nflags=`expr $maildropdlg_flags - 4`
            if [ $nflags -ge 0 ]
            then
                maildropdlg_flag4="1"
                maildropdlg_flags=$nflags
            fi
            nflags=`expr $maildropdlg_flags - 2`
            if [ $nflags -ge 0 ]
            then
                maildropdlg_flag2="1"
                maildropdlg_flags=$nflags
            fi
            nflags=`expr $maildropdlg_flags - 1`
            if [ $nflags -ge 0 ]
            then
                maildropdlg_flag1="1"
                maildropdlg_flags=$nflags
            fi
            maildropdlg_flags="0"

            cui_window_new "$win" 0 0 46 20 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if p_valid_handle $dlg
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Filter"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  maildropdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    cui_window_destroy "$dlg"
                    my_exec_sql "$myconn" \
                        "UPDATE maildropfilter \
                            SET ownerid='${maildropdlg_ownerid}', \
                                filtertype='${maildropdlg_filter}', \
                                fieldname='${maildropdlg_header}', \
                                fieldvalue='${maildropdlg_value}', \
                                tofolder='${maildropdlg_folder}', \
                                flags='${maildropdlg_flags}', \
                                position='${maildropdlg_position}', \
                                active='${maildropdlg_active}', \
                                datefrom=UNIX_TIMESTAMP('${maildropdlg_datestart}'), \
                                dateend=UNIX_TIMESTAMP('${maildropdlg_dateend}') \
                          WHERE id='${maildropdlg_id}';"
                    if p_sql_success "$p2"
                    then
                        selected_entry="$maildropdlg_id"
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
# maildrops_deletemaildrop_dialog
# Delete a mail maildrop
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function maildrops_deletemaildrop_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local idx

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_listview_getsel "$ctrl" && idx="$p2"
        if p_valid_index $idx
        then
            cui_listview_gettext "$ctrl" "$idx" "10"
            maildropdlg_id="$p2"

            cui_message "$win" "Really delete selected maildrop filter?" "Question" "$MB_YESNO"
            if [ "$p2" == "$IDYES" ]
            then

                my_exec_sql "$myconn" \
                    "DELETE FROM maildropfilter WHERE id='${maildropdlg_id}';"
                if p_sql_success "$p2"
                then
                    result="$IDOK"
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
    local dlg
    local menu
    local result
    local item

    cui_menu_new "$win" "Options" 0 0 25 13 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if p_valid_handle $menu
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
                if maildrops_editmaildrop_dialog $win
                then
                     load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if maildrops_deletemaildrop_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if maildrops_createmaildrop_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            4)
                cui_window_destroy  "$menu"
                cui_window_new "$win" 0 0 46 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
                if p_valid_handle $dlg
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

    cui_listview_new "$win" "" 0 0 10 10 11 "$IDC_LISTVIEW" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if p_valid_handle $ctrl
    then
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED" "$win" "listview_clicked_hook"
        cui_listview_callback   "$ctrl" "$LISTBOX_POSTKEY" "$win" "listview_postkey_hook"
        cui_listview_setcoltext "$ctrl" 0 "Owner"
        cui_listview_setcoltext "$ctrl" 1 "Filtertype"
        cui_listview_setcoltext "$ctrl" 2 "Header"
        cui_listview_setcoltext "$ctrl" 3 "Value"
        cui_listview_setcoltext "$ctrl" 4 "Folder"
        cui_listview_setcoltext "$ctrl" 5 "Flags"
        cui_listview_setcoltext "$ctrl" 6 "Position"
        cui_listview_setcoltext "$ctrl" 7 "Active"
        cui_listview_setcoltext "$ctrl" 8 "Start date:"
        cui_listview_setcoltext "$ctrl" 9 "End date:"
        cui_listview_setcoltext "$ctrl" 10 "Nr"
        cui_window_create       "$ctrl"
    fi

    cui_textview_new "$win" "Help" 0 0 10 10 "$IDC_HELPTEXT" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if p_valid_handle $ctrl
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
    if p_valid_handle "$ctrl"
    then
        cui_textview_add "$ctrl" "Use function keys to edit (F4), create (F7) or delete (F8) e-mail filter." "0"
        cui_textview_add "$ctrl" "Folder" "0"
        cui_textview_add "$ctrl" " INBOX.Trash = store message to Trash folder" "0" 
        cui_textview_add "$ctrl" " INBOX.News = store message to News folder" "0" 
        cui_textview_add "$ctrl" " !user@virtual.test = send message to user@virtual.test" "0" 
        cui_textview_add "$ctrl" " + = send autoreply message" "0"
        cui_textview_add "$ctrl" " +days=4 = send autoreply message not on the next 4 days"  "0"
        cui_textview_add "$ctrl" "Flags" "0"
        cui_textview_add "$ctrl" "1 = Negates pretty much every condition" "0" 
        cui_textview_add "$ctrl" "2 = startswith/endswith/contains applied to body" "0" 
        cui_textview_add "$ctrl" "4 = Continue filtering (cc: instead of to:)" "0" 
        cui_textview_add "$ctrl" "8 = Pattern is a plain string, not a regex" "1" 
     fi

    my_server_connect "$vmail_sql_server" \
        "0" \
        "$vmail_sql_user" \
        "$vmail_sql_pass" \
        "$vmail_sql_db_name" && myconn="$p2"

    if p_valid_handle $myconn
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
        if p_valid_handle $dlg
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
        if maildrops_editmaildrop_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F7")
        if maildrops_createmaildrop_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if maildrops_deletemaildrop_dialog $win
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
    if p_valid_handle $mainwin
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "Sieve filter (from MySQL table):"
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
