# !/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/userman.cui.samba20.module.sh - samba user manager
#
# Creation:     2010-11-07 dv
# Last update:  $Id: userman.cui.samba20.module.sh 34201 2013-08-01 19:19:48Z knuffel $
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
IDC_SAMBA20_LIST='12'

IDC_SAMBA20CREATEDLG_EDNAME='13'
IDC_SAMBA20CREATEDLG_LABEL1='14'
IDC_SAMBA20CREATEDLG_BUTOK='15'
IDC_SAMBA20CREATEDLG_BUTCANCEL='16'

#============================================================================
# helper functions
#============================================================================

function load_samba_machines
{
    local ctrl="$1"

    local pdbeditbin='/usr/bin/pdbedit'

    $pdbeditbin -Lw | grep "^.*$:" | sort -t: -k2n |
    (
        while read line
        do
            local oldifs="$IFS"
            local index

            local IFS=':'
            set -- $line
            local workstation=`echo "$1" | cut -d'$' -f1`
            local uid="$2"
            IFS="$oldifs"

            cui_listview_add     "$ctrl" && index="$p2"
            cui_listview_settext "$ctrl" "$index" 0 "$workstation"
            cui_listview_settext "$ctrl" "$index" 1 "$uid"
        done
    )
}

#============================================================================
# samba20createdlg - dialog to create samba workstations
#============================================================================

#----------------------------------------------------------------------------
# samba20createdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba20createdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_SAMBA20CREATEDLG_EDNAME" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        samba20createdlg_name="$p2"
    fi

    if [ -z "${samba20createdlg_name}" ]
    then
        cui_message "$win" "No valid workstation name entered!" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba20createdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba20createdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba20createdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------

function samba20createdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    cui_label_new "$dlg" "NETBIOS name:" 2 1 14 1 $IDC_SAMBA20CREATEDLG_LABEL1 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
    fi

    cui_edit_new "$dlg" "" 16 1 20 1 16 $IDC_SAMBA20CREATEDLG_EDNAME $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${samba20createdlg_name}"
    fi

    cui_button_new "$dlg" "&OK" 10 3 10 1 ${IDC_SAMBA20CREATEDLG_BUTOK} $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba20createdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 21 3 10 1 ${IDC_SAMBA20CREATEDLG_BUTCANCEL} $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" samba20createdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# functions to add or delete samba workstations
#============================================================================

#----------------------------------------------------------------------------
# samba20_createworkstation_dialog
# create a new samba workstation
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba20_createworkstation_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg

    samba20createdlg_name=""

    cui_window_new "$win" 0 0 40 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle "$dlg"
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create samba workstation"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  samba20createdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"
        cui_window_destroy   "$dlg"

        if  [ "$result" == "$IDOK" ]
        then
            local groupfile='/etc/group'
            local smbpasswdbin='/usr/bin/smbpasswd'
            local pdbeditbin='/usr/bin/pdbedit'
            local passwdfile='/etc/passwd'
            local workstation=`echo ${samba20createdlg_name} | tr [:upper:] [:lower:]`
            local password='*'
            local uid=''
            local gid='777'
            local name='machine_account'
            local home='/dev/null'
            local shell='/bin/false'
            local errmsg

            workstation="$workstation\$"

            if ! grep -q "^machines:" $groupfile
            then
                errmsg=`/var/install/bin/add-group "machines" "777" 2>&1`
                if [ "$?" != 0 ]
                then
                    cui_message "$win" "$errmsg" "Error" "$MB_ERROR"
                    return 1
                fi
            fi
            if grep -q "^$workstation:" "$passwdfile"
            then
                cui_message "$win" \
                    "Workstation $workstation already exist in $passwdfile" \
                    "Message" "$MB_OK"
            else
                errmsg=`/var/install/bin/add-user "$workstation" "$password" \
                       "$uid" "$gid" "$name" "$home" "$shell" 2>&1`
                if [ "$?" != 0 ]
                then
                    cui_message "$win" "$errmsg" "Error" "$MB_ERROR"
                    return 1
                fi
            fi
            if ! $pdbeditbin -Lw | grep -q "^${workstation}:"
            then
                errmsg=`"$smbpasswdbin" -a -m "$workstation" 2>&1`
                if [ "$?" != 0 ]
                then
                    cui_message "$win" "$errmsg" "Error" "$MB_ERROR"
                    return 1
                fi
                "$smbpasswdbin" -e -m "$workstation"
            else
                cui_message "$win" \
                    "Workstation $workstation already exists in samba database" \
                    "Message" "$MB_OK"
                "$smbpasswdbin" -e -m "$workstation"
            fi
        fi
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# samba20_deleteworkstation_dialog
# delete selected samba workstation
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function samba20_deleteworkstation_dialog()
{
    local win="$1"
    local ctrl
    local index
    local result="$IDCANCEL"

    cui_window_getctrl "$win" "$IDC_SAMBA20_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && samba20createdlg_name="$p2"

            cui_message "$win" \
                "Really remove samba workstation \"${samba20createdlg_name}\"?" \
                "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                local workstation="${samba20createdlg_name}"
                local workstationid
                local pdbeditbin='/usr/bin/pdbedit'
                local smbpasswdbin='/usr/bin/smbpasswd'
                local passwdfile='/etc/passwd'
                local errmsg

                # remove from passdb.tdb
                workstation=`echo $workstation | tr [:upper:] [:lower:]`
                workstationid="$workstation\$"
                if ! $pdbeditbin -Lw | grep -q "^${workstationid}:"
                then
                    workstation=`echo $workstation | tr [:lower:] [:upper:]`
                    workstationid="$workstation\$"
                    if ! $pdbeditbin -Lw | grep -q "^${workstationid}:"
                    then
                        cui_message "$win" \
                           "Workstation $workstation does not exist" \
                           "Error" "$MB_ERROR"
                        return 1
                    fi
                fi
                errmsg=`"$smbpasswdbin" -m -x "$workstation" 2>&1`
                if [ "$?" != 0 ]
                then
                    cui_message "$win" "$errmsg" "Error" "$MB_ERROR"
                    return 1
                fi

                # remove from passwd
                workstation=`echo $workstation | tr [:upper:] [:lower:]`
                workstationid="$workstation\$"
                if ! grep -q "^$workstationid:" "$passwdfile"
                then
                    workstation=`echo $workstation | tr [:lower:] [:upper:]`
                    workstationid="$workstation\$"
                    if ! grep -q "^$workstationid:" "$passwdfile"
                    then
                        cui_message "$win" \
                           "Workstation $workstation does not exist in $passwdfile" \
                           "Error" "$MB_ERROR"
                        return 1
                    fi
                fi
                errmsg=`/var/install/bin/remove-user "$workstationid" 'no' 2>&1`
                if [ "$?" != "0" ]
                then
                    cui_message "$win" "$errmsg" "Error" "$MB_ERROR"
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

#============================================================================
# functions to sort the list view control and to select the sort column
#============================================================================

#----------------------------------------------------------------------------
# samba20_sort_list
# Sort the list view control by the column specified in samba20_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba20_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${samba20_sortcolumn}" != "-1" ]
    then
        if [ "${samba20_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${samba20_sortcolumn}" == "1" ]
        then
            cui_listview_numericsort "$ctrl" "${samba20_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${samba20_sortcolumn}" "$mode"
        fi
    fi
}

#----------------------------------------------------------------------------
# samba20_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba20_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# samba20_sortmenu_escape_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba20_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}

#----------------------------------------------------------------------------
# samba20_sortmenu_postkey_hook
# expects: $p2 : window handle
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function samba20_sortmenu_postkey_hook()
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
# samba20_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle
# returns: nothing
#----------------------------------------------------------------------------

function samba20_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item
    local oldcolumn="${samba20_sortcolumn}"
    local oldmode="${samba20_sortmode}"

    cui_menu_new "$win" "Sort column" 0 0 36 11 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_additem      "$menu" "Don't sort" 1
        cui_menu_additem      "$menu" "Sort by Name     (ascending)"  2
        cui_menu_additem      "$menu" "Sort by Name     (descending)" 3
        cui_menu_additem      "$menu" "Sort by Uid      (ascending)"  4
        cui_menu_additem      "$menu" "Sort by Uid      (descending)" 5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" samba20_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" samba20_sortmenu_escape_hook
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" samba20_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1)
               samba20_sortcolumn="-1"
               ;;
            2)
               samba20_sortcolumn="0"
               samba20_sortmode="up"
               ;;
            3)
               samba20_sortcolumn="0"
               samba20_sortmode="down"
               ;;
            4)
               samba20_sortcolumn="1"
               samba20_sortmode="up"
               ;;
            5)
               samba20_sortcolumn="1"
               samba20_sortmode="down"
               ;;
            esac
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${samba20_sortcolumn}" -o "$oldmode" != "${samba20_sortmode}" ]
        then
            samba20_readdata      "$win"
        fi
    fi
}

#============================================================================
# samba users module (module functions called from userman.cui.sh)
#============================================================================

#----------------------------------------------------------------------------
# samba20_menu : menu text for this module
#----------------------------------------------------------------------------

samba20_menu="Samba computers"
samba20_sortcolumn="-1"
samba20_sortmode="up"

#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# samba20_listview_clicked_hook
# listitem has been clicked
# expects: $p1 : window handle of parent window
#          $p2 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------

function samba20_listview_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local menu
    local result
    local item
    local dlg

    cui_menu_new "$win" "Options" 0 0 30 12 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Create new entry"  1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Sort by column"    3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"  4
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
                if samba20_createworkstation_dialog $win
                then
                    samba20_readdata $win
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if samba20_deleteworkstation_dialog $win
                then
                    samba20_readdata $win
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                samba20_select_sort_column $win
                ;;
            4)
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
#  samba20_list_postkey_hook (catch ENTER key)
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------

function samba20_list_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"

    if [ "$key" == "${KEY_ENTER}" ]
    then
        samba20_listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
    fi
}

#----------------------------------------------------------------------------
# samba20_init (init the module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba20_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 2 "${IDC_SAMBA20_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setcolors    "$ctrl" "WINDOW"
        cui_listview_setcoltext "$ctrl" 0 "   Workstation   "
        cui_listview_setcoltext "$ctrl" 1 "  Uid  "
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED"  "$win" samba20_listview_clicked_hook
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" samba20_list_postkey_hook
        cui_window_create "$ctrl"
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_wordwrap "$ctrl" 1
        cui_textview_add "$ctrl" "CREATE (F7) or DELETE (F8) samba workstation accounts."
        cui_window_totop "$ctrl"
    fi

    cui_window_setlstatustext "$win" "Commands: F7=Create F8=Delete F10=Exit"
}

#----------------------------------------------------------------------------
# samba20_close (close the module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba20_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_SAMBA20_LIST}" && ctrl="$p2"
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
# samba20_size (resize the module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------

function samba20_size()
{
    local ctrl

    cui_window_getctrl "$1" "$IDC_SAMBA20_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi
}

#----------------------------------------------------------------------------
# samba20_readdata (read data of the samba20 module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba20_readdata()
{
    local ctrl
    local win="$1"
    local sel;
    local count;
    local index;

    # read workstation inforamtion
    cui_window_getctrl "$win" "$IDC_SAMBA20_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel   "$ctrl" && sel="$p2"
        cui_listview_clear    "$ctrl"

        load_samba_machines   "$ctrl"

        cui_listview_getcount "$ctrl" && count="$p2"

        if [ "$sel" -ge "0" -a "$count" -gt "0" ]
        then
            if [ "$sel" -ge "$count" ]
            then
                sel=$[$count - 1]
            fi
            samba20_sort_list   "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            samba20_sort_list   "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi
    fi
}

#----------------------------------------------------------------------------
# samba20_activate (activate the samba20 module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function samba20_activate()
{
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_SAMBA20_LIST"
    if cui_valid_handle "$p2"
    then
        cui_window_setfocus "$p2"
    fi
}

#----------------------------------------------------------------------------
# samba20_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboad input
#----------------------------------------------------------------------------

function samba20_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F7")
        if samba20_createworkstation_dialog $win
        then
            samba20_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if samba20_deleteworkstation_dialog $win
        then
            samba20_readdata $win
        fi
        return 0
        ;;
    "$KEY_F9")
        samba20_select_sort_column $win
        return 0
        ;;
    esac

    return 1
}

#============================================================================
# end of samba20 module
#============================================================================
