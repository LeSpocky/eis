# !/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/userman.cui.samba10.module.sh - samba user manager
#
# Creation:     2010-11-07 dv
# Last update:  $Id: userman.cui.samba10.module.sh 34201 2013-08-01 19:19:48Z knuffel $
#
# Copyright (c) 2001-2013 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#============================================================================
# control constants
#============================================================================
IDC_SAMBA10_LIST='12'

IDC_SAMBA10CREATEDLG_LIST='13'
IDC_SAMBA10CREATEDLG_BUTOK='14'
IDC_SAMBA10CREATEDLG_BUTCANCEL='15'

IDC_SAMBA10PASSWDDLG_EDPASS1='20'
IDC_SAMBA10PASSWDDLG_EDPASS2='21'
IDC_SAMBA10PASSWDDLG_BUTOK='22'
IDC_SAMBA10PASSWDDLG_BUTCANCEL='23'
IDC_SAMBA10PASSWDDLG_LABEL1='24'
IDC_SAMBA10PASSWDDLG_LABEL2='25'

#============================================================================
# helper functions
#============================================================================

#----------------------------------------------------------------------------
# load samba users into the listbox
# expects: $1 listview control
#----------------------------------------------------------------------------

function load_samba_users
{
    local ctrl="$1"
    local pdbeditbin='/usr/bin/pdbedit'

    $pdbeditbin -Lw | grep -v "^.*$:" | sort -t: -k2n |
    (
        while read line
        do
            local oldifs="$IFS"
            local index

            local IFS=':'

            set -- $line
            local user="$1"
            local uid="$2"
            local pass="$4"
            local active="$5"

            IFS="$oldifs"

            if [ "$pass" != "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]
            then
                pass='set'
            else
                pass='not_set'
            fi

            if [ -n "`echo $active | grep "\[U"`" -a "$pass" != "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]
            then
                active='yes'
            else
                active='no'
            fi

            cui_listview_add     "$ctrl" && index="$p2"
            cui_listview_settext "$ctrl" "$index" 0 "$user"
            cui_listview_settext "$ctrl" "$index" 1 "$uid"
            cui_listview_settext "$ctrl" "$index" 2 "$pass"
            cui_listview_settext "$ctrl" "$index" 3 "$active"
        done
    )
}

samba10passwddlg_create_hook

#============================================================================
# samba10passwddlg - dialog to set samba users password
#============================================================================

#----------------------------------------------------------------------------
# samba10passwddlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10passwddlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_SAMBA10PASSWDDLG_EDPASS1" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        samba10passwddlg_pass1="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_SAMBA10PASSWDDLG_EDPASS2" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        samba10passwddlg_pass2="$p2"
    fi

    if [ "${samba10passwddlg_pass1}" != "${samba10passwddlg_pass2}" ]
    then
        cui_message "$win" "Passwords do not match. Please enter them again" \
                           "Wrong Password" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba10passwddlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10passwddlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba10passwddlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10passwddlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    cui_label_new "$dlg" "New password:" 2 1 14 1 $IDC_SAMBA10PASSWDDLG_LABEL1 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Reenter pw.:" 2 3 14 1 $IDC_SAMBA10PASSWDDLG_LABEL2 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 18 1 40 $IDC_SAMBA10PASSWDDLG_EDPASS1 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${samba10passwddlg_pass1}"
    fi
    cui_edit_new "$dlg" "" 17 3 18 1 40 $IDC_SAMBA10PASSWDDLG_EDPASS2 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"        
        cui_edit_settext      "$ctrl" "${samba10passwddlg_pass2}"
    fi

    cui_button_new "$dlg" "&OK" 9 5 10 1 ${IDC_SAMBA10PASSWDDLG_BUTOK} $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba10passwddlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 20 5 10 1 ${IDC_SAMBA10PASSWDDLG_BUTCANCEL} $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba10passwddlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# samba10createdlg - dialog to create and edit samba users
#============================================================================

#----------------------------------------------------------------------------
# samba10createdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10createdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_SAMBA10CREATEDLG_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" 0
            samba10createdlg_userlogin="$p2"
        fi
    fi

    if [ -z "${samba10createdlg_userlogin}" ]
    then
        cui_message "$win" "No valid user selected! Please select one from the list" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba10createdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10createdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba10createdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba10createdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    cui_listview_new "$dlg" "" 0 0 57 10 6 ${IDC_SAMBA10CREATEDLG_LIST} ${CWS_NONE} ${CWS_BORDER} && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "  User  "
        cui_listview_setcoltext "$ctrl" 1 " Uid "
        cui_listview_setcoltext "$ctrl" 2 " Group "
        cui_listview_setcoltext "$ctrl" 3 " Gid "
        cui_listview_setcoltext "$ctrl" 4 "Valid-PW"
        cui_listview_setcoltext "$ctrl" 5 "  Name  "
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED"  "$dlg" samba10createdlg_ok_clicked
        cui_window_create "$ctrl"

        sys_users_tolist      "$ctrl" "$[$USERS_HIDE_SYSTEM + $USERS_HIDE_NOBODY + $USERS_HIDE_MACHINES]" ""
    fi

    cui_button_new "$dlg" "&OK" 18 11 10 1 ${IDC_SAMBA10CREATEDLG_BUTOK} $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba10createdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 29 11 10 1 ${IDC_SAMBA10CREATEDLG_BUTCANCEL} $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba10createdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# functions to add, delete, activate or deactivate samba users
#============================================================================

#----------------------------------------------------------------------------
# samba10_createuser_dialog
# create a new users by selecting one from a list of unix users
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba10_createuser_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    local errmsg

    local smbpasswdbin='/usr/bin/smbpasswd'
    local pdbeditbin='/usr/bin/pdbedit'

    samba10createdlg_userlogin=""

    cui_window_new "$win" 0 0 59 15 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle "$dlg"
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Select Samba User to Create"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  samba10createdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"
        cui_window_destroy   "$dlg"

        if  [ "$result" == "$IDOK" ]
        then
            if $pdbeditbin -Lw | grep -q "^${samba10createdlg_userlogin}:"
            then
                cui_message "$win" "Info: User already exists!" "Message" "$MB_OK"
            else
                cui_window_new "$win" 0 0 40 9 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
                if cui_valid_handle "$dlg"
                then
                    cui_window_setcolors "$dlg" "DIALOG"
                    cui_window_settext   "$dlg" "Enter Password"
                    cui_window_sethook   "$dlg" "$HOOK_CREATE"  samba10passwddlg_create_hook
                    cui_window_create    "$dlg"

                    samba10passwddlg_pass1=""
                    samba10passwddlg_pass2=""

                    cui_window_modal     "$dlg" && result="$p2"
                    cui_window_destroy   "$dlg"

                    if [ "$result" == "$IDOK" ]
                    then
                        errmsg=$( \
                            (echo "${samba10passwddlg_pass1}"; echo "${samba10passwddlg_pass1}") | \
                            "$smbpasswdbin" -sa "${samba10createdlg_userlogin}" 2>&1)
                        if [ "$?" != "0" ]
                        then
                            cui_message "$win" \
                                "Error! Failed to add samba user!${CUINL}${errmsg}" "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        fi

                        "$smbpasswdbin" -e "${samba10createdlg_userlogin}"
                    fi
                fi
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# samba10_deleteuser_dialog
# delete selected samba user
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba10_deleteuser_dialog()
{
    local win="$1"
    local ctrl
    local index
    local result="$IDCANCEL"
    local errmsg

    local pdbeditbin='/usr/bin/pdbedit'

    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && samba10createdlg_userlogin="$p2"

            cui_message "$win" \
                "Really remove samba user \"${samba10createdlg_userlogin}\"?" \
                "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                errmsg=$("$pdbeditbin" -x "${samba10createdlg_userlogin}" 2>&1)

                if [ "$?" != "0" ]
                then
                    cui_message "$win" \
                        "Error! Failed to remove samba user!${CUINL}$errmsg" \
                        "Error" "$MB_ERROR"
                    result="$IDCANCEL"
                else
                    result="$IDOK"
                fi
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# samba10_setpassword
# redefine users password
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba10_setpassword()
{
    local win="$1"
    local ctrl
    local index
    local result="$IDCANCEL"
    local dlg

    local smbpasswdbin='/usr/bin/smbpasswd'

    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && samba10createdlg_userlogin="$p2"

            cui_window_new "$win" 0 0 40 9 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                samba10passwddlg_pass1="XXXXXXXXXXXXXXX"
                samba10passwddlg_pass2="XXXXXXXXXXXXXXX"

                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Enter Password"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  samba10passwddlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                cui_window_destroy   "$dlg"

                if [ "$result" == "$IDOK" -a ${samba10passwddlg_pass1} != "XXXXXXXXXXXXXXX" ]
                then
                    errmsg=$( \
                        (echo "${samba10passwddlg_pass1}"; echo "${samba10passwddlg_pass1}") | \
                        "$smbpasswdbin" -s "${samba10createdlg_userlogin}" 2>&1)
                    if [ "$?" != "0" ]
                    then
                        cui_message "$win" \
                            "Error! Failed to set password for samba user!${CUINL}${errmsg}" \
                            "Error" "$MB_ERROR"
                        result="$IDCANCEL"
                    fi
                fi
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# samba10_activate_user
# activate samba user
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba10_activate_user()
{
    local win="$1"
    local ctrl
    local index
    local result="$IDCANCEL"
    local errmsg

    local smbpasswdbin='/usr/bin/smbpasswd'

    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && samba10createdlg_userlogin="$p2"

            errmsg=$("$smbpasswdbin" -e "${samba10createdlg_userlogin}" 2>&1)

            if [ "$?" != "0" ]
            then
                cui_message "$win" \
                    "Error! Failed to activate samba user!${CUINL}${errmsg}" \
                    "Error" "$MB_ERROR"
                result="$IDCANCEL"
            else
                result="$IDOK"
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# samba10_deactivate_user
# deactivate samba user
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba10_deactivate_user()
{
    local win="$1"
    local ctrl
    local index
    local result="$IDCANCEL"
    local errmsg

    local smbpasswdbin='/usr/bin/smbpasswd'

    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && samba10createdlg_userlogin="$p2"

            errmsg=$("$smbpasswdbin" -d "${samba10createdlg_userlogin}" 2>&1)

            if [ "$?" != "0" ]
            then
                cui_message "$win" \
                    "Error! Failed to deactivate samba user!${CUINL}${errmsg}" \
                    "Error" "$MB_ERROR"
                result="$IDCANCEL"
            else
                result="$IDOK"
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#============================================================================
# functions to sort the list view control and to select the sort column
#============================================================================

#----------------------------------------------------------------------------
# samba10_sort_list
# Sort the list view control by the column specified in samba10_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba10_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${samba10_sortcolumn}" != "-1" ]
    then
        if [ "${samba10_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${samba10_sortcolumn}" == "1" ]
        then
            cui_listview_numericsort "$ctrl" "${samba10_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${samba10_sortcolumn}" "$mode"
        fi
    fi
}

#----------------------------------------------------------------------------
# samba10_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba10_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba10_sortmenu_escape_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba10_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}

#----------------------------------------------------------------------------
# samba10_sortmenu_postkey_hook
# expects: $p2 : window handle
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function samba10_sortmenu_postkey_hook()
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

#----------------------------------------------------------------------------
# samba10_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba10_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item
    local oldcolumn="${samba10_sortcolumn}"
    local oldmode="${samba10_sortmode}"

    cui_menu_new "$win" "Sort column" 0 0 36 15 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_additem      "$menu" "Don't sort" 1
        cui_menu_additem      "$menu" "Sort by User     (ascending)"  2
        cui_menu_additem      "$menu" "Sort by User     (descending)" 3
        cui_menu_additem      "$menu" "Sort by Uid      (ascending)"  4
        cui_menu_additem      "$menu" "Sort by Uid      (descending)" 5
        cui_menu_additem      "$menu" "Sort by Password (ascending)"  6
        cui_menu_additem      "$menu" "Sort by Password (descending)" 7
        cui_menu_additem      "$menu" "Sort by Active   (ascending)"  8
        cui_menu_additem      "$menu" "Sort by Active   (descending)" 9
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" samba10_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" samba10_sortmenu_escape_hook
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" samba10_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1)
               samba10_sortcolumn="-1"
               ;;
            2)
               samba10_sortcolumn="0"
               samba10_sortmode="up"
               ;;
            3)
               samba10_sortcolumn="0"
               samba10_sortmode="down"
               ;;
            4)
               samba10_sortcolumn="1"
               samba10_sortmode="up"
               ;;
            5)
               samba10_sortcolumn="1"
               samba10_sortmode="down"
               ;;
            6)
               samba10_sortcolumn="2"
               samba10_sortmode="up"
               ;;
            7)
               samba10_sortcolumn="2"
               samba10_sortmode="down"
               ;;
            8)
               samba10_sortcolumn="3"
               samba10_sortmode="up"
               ;;
            9)
               samba10_sortcolumn="3"
               samba10_sortmode="down"
               ;;
            esac
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${samba10_sortcolumn}" -o "$oldmode" != "${samba10_sortmode}" ]
        then
            samba10_readdata      "$win"
        fi
    fi
}

#============================================================================
# samba users module (module functions called from userman.cui.sh)
#============================================================================

#----------------------------------------------------------------------------
# samba10_menu : menu text for this module
#----------------------------------------------------------------------------

samba10_menu="Samba users"
samba10_sortcolumn="-1"
samba10_sortmode="up"

#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# samba10_listview_clicked_hook
# listitem has been clicked
# expects: $p1 : window handle of parent window
#          $p2 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------

function samba10_listview_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local menu
    local result
    local item
    local dlg

    cui_menu_new "$win" "Options" 0 0 30 16 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Create new entry"  1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_additem      "$menu" "Set password"      3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Activate entry"    4
        cui_menu_additem      "$menu" "Deactivate entry"  5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Sort by column"    6
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"  7
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu"        0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" "module_menu_clicked_hook"
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" "module_menu_escape_hook"
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" "module_menu_postkey_hook"

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu" && item="$p2"

            case $item in
            1)
                cui_window_destroy  "$menu"
                if samba10_createuser_dialog $win
                then
                    samba10_readdata $win
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if samba10_deleteuser_dialog $win
                then
                    samba10_readdata $win
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if samba10_setpassword $win
                then
                    samba10_readdata $win
                fi
                ;;
            4)
                cui_window_destroy  "$menu"
                if samba10_activate_user $win
                then
                    samba10_readdata $win
                fi
                ;;
            5)
                cui_window_destroy  "$menu"
                if samba10_deactivate_user $win
                then
                    samba10_readdata $win
                fi
                ;;
            6)
                cui_window_destroy  "$menu"
                samba10_select_sort_column $win
                ;;
            7)
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
#  samba10_list_postkey_hook (catch ENTER key)
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------

function samba10_list_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"

    if [ "$key" == "${KEY_ENTER}" ]
    then
        samba10_listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
    fi
}

#----------------------------------------------------------------------------
# samba10_init (init the module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba10_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 4 "${IDC_SAMBA10_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setcolors    "$ctrl" "WINDOW"
        cui_listview_setcoltext "$ctrl" 0 "   User   "
        cui_listview_setcoltext "$ctrl" 1 "   Uid   "
        cui_listview_setcoltext "$ctrl" 2 " Password "
        cui_listview_setcoltext "$ctrl" 3 " Active "
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED"  "$win" samba10_listview_clicked_hook
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" samba10_list_postkey_hook
        cui_window_create "$ctrl"
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_wordwrap "$ctrl" 1
        cui_textview_add "$ctrl" "CREATE (F7), DELETE (F8), ACTIVATE (F4) or \
DEACTIVATE (F5) samba users. Further it is possible to set a new password for an existing \
samba user (F6)."
        cui_textview_add "$ctrl" "Please note that users are created by selection of an \
existing unix user account. Remember to create this unix accounts before you \
go on creating samba users."
        cui_window_totop "$ctrl"
    fi

    cui_window_setlstatustext "$win" "Commands: F4=Activate F5=Deact. F6=Passwd F7=Create F8=Delete F10=Exit"
}

#----------------------------------------------------------------------------
# samba10_close (close the module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba10_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_SAMBA10_LIST}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_destroy "$ctrl" 
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_clear "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# samba10_size (resize the module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------

function samba10_size()
{
    local ctrl

    cui_window_getctrl "$1" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi
}

#----------------------------------------------------------------------------
# samba10_readdata (read data of the samba10 module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba10_readdata()
{
    local ctrl
    local win="$1"
    local sel;
    local count;
    local index;

    # read user inforamtion
    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel   "$ctrl" && sel="$p2"
        cui_listview_clear    "$ctrl" 

        load_samba_users      "$ctrl"

        cui_listview_getcount "$ctrl" && count="$p2"

        if [ "$sel" -ge "0" -a "$count" -gt "0" ]
        then
            if [ "$sel" -ge "$count" ]
            then
                sel=$[$count - 1]
            fi
            samba10_sort_list   "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            samba10_sort_list   "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi
    fi
}

#----------------------------------------------------------------------------
# samba10_activate (activate the samba10 module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba10_activate()
{
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_SAMBA10_LIST"
    if cui_valid_handle "$p2"
    then
        cui_window_setfocus "$p2"
    fi
}

#----------------------------------------------------------------------------
# samba10_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboad input
#----------------------------------------------------------------------------

function samba10_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F4")
        if samba10_activate_user $win
        then
            samba10_readdata $win
        fi
        return 0
        ;;
    "$KEY_F5")
        if samba10_deactivate_user $win
        then
            samba10_readdata $win
        fi
        return 0
        ;;
    "$KEY_F6")
        if samba10_setpassword $win
        then
            samba10_readdata $win
        fi
        return 0
        ;;
    "$KEY_F7")
        if samba10_createuser_dialog $win
        then
            samba10_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if samba10_deleteuser_dialog $win
        then
            samba10_readdata $win
        fi
        return 0
        ;; 
    "$KEY_F9")
        samba10_select_sort_column $win
        return 0
        ;;
    esac

    return 1
}

#============================================================================
# end of samba10 module
#============================================================================
