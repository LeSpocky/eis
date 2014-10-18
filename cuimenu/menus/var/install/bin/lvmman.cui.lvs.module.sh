#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/lvmman.cui.lvs.module.sh - lvs module for eisfair lvm mananger
#
# Creation:     2014-05-04 Jens Vehlhaber jens@eisfair.org
# Copyright (c) 2001-2014 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#============================================================================
# control constants
#============================================================================
IDC_LVS_LIST='12'

IDC_LVSDLG_BUTOK='10'
IDC_LVSDLG_BUTCANCEL='11'
IDC_LVSDLG_LABEL1='12'
IDC_LVSDLG_LABEL2='13'
IDC_LVSDLG_LABEL3='14'
IDC_LVSDLG_LABEL4='15'
IDC_LVSDLG_LABEL5='16'
IDC_LVSDLG_VGGROUP='20'
IDC_LVSDLG_VOLNAME='21'
IDC_LVSDLG_EDSIZE='22'

IDC_VOLUMESIZE_BUTOK='10'
IDC_VOLUMESIZE_BUTCANCEL='11'
IDC_VOLUMESIZE_LABEL1='12'
IDC_VOLUMESIZE_LABEL2='13'
IDC_VOLUMESIZE_NEWSIZE='20'

#============================================================================
# helper functions for lv management
#============================================================================

#----------------------------------------------------------------------------
# lvs_get_mountpoint
# if device mounted get the mountpoint
# expects: $1 : /dev/vg01/vol1
# returns:    : lvs_mountpoint=/mnt/foobar
#----------------------------------------------------------------------------
function lvs_get_mountpoint()
{
    lvs_mountpoint="$( mount | grep "$1 " | cut -d ' ' -f 3 )"
}

#----------------------------------------------------------------------------
# lvs_get_mountpoint
# if device mounted get the filesystem
# expects: $1 : /dev/vg01/vol1
# returns:    : lvs_fs=ext4 xfs ...
#----------------------------------------------------------------------------
function lvs_get_filesystem()
{
    lvs_fs="$( mount | grep "$1 " | cut -d ' ' -f 5 )"
}

#============================================================================
# terminal window callbacks
#============================================================================

#----------------------------------------------------------------------------
# terminal_exit (command run in terminal terminated)
#    $p2 --> mainwin window handle
#    $p3 --> terminal window
#----------------------------------------------------------------------------
function terminal_exit()
{
    local win="$p2"
    local ctrl="$p3"
    cui_window_destroy "$ctrl"
    cui_return 1
}

#============================================================================
# lvsdlg - dialog to create and edit lvs
#============================================================================

#----------------------------------------------------------------------------
# lvsdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function lvsdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_LVSDLG_VGGROUP" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_combobox_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_combobox_get "$ctrl" "$index"
            lvsdlg_lvgroup="$p2"
        else
            cui_message "$win" "No lv group selected! Please select a valid volume group" \
                               "Missing lv group" "$MB_ERROR"
            cui_return 1
            return
        fi
    fi

    cui_window_getctrl "$win" "$IDC_LVSDLG_VOLNAME" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        lvsdlg_lvname="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_LVSDLG_EDSIZE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        lvsdlg_lvsize="$p2"
    fi

    if [ -z "$lvsdlg_lvname" ]
    then
        cui_message "$win" "Please enter a valid volume name (vol1 or lvol1 ...)" \
                           "Missing volume name" "$MB_ERROR"
        cui_return 1
        return
    fi
    if [ -z "$lvsdlg_lvsize" ]
    then
        cui_message "$win" "Please enter a valid volume size (500m or 10g ...)" \
                           "Missing volume size" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# lvsdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function lvsdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# lvsdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function lvsdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    if cui_label_new "$dlg" "Volume group:" 2 1 14 1 $IDC_LVSDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Volume name:" 2 3 14 1 $IDC_LVSDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "(vol1)" 29 3 14 1 $IDC_LVSDLG_LABEL3 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Size:" 2 5 14 1 $IDC_LVSDLG_LABEL4 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "(500m, 10g)" 29 5 14 1 $IDC_LVSDLG_LABEL5 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_combobox_new "$dlg" 17 1 12 10 $IDC_LVSDLG_VGGROUP $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        _ifs="$IFS"
        vgs --separator=! --noheadings | while read line
        do
            IFS="!"
            set -- $line
            cui_combobox_add "$ctrl" "$1"
            IFS="$_ifs"
        done
        [ -z "$lvsdlg_lvgroup" ] && cui_combobox_get "$ctrl" 0 && lvsdlg_lvgroup="$p2"
        cui_combobox_select   "$ctrl" "$lvsdlg_lvgroup"
        cui_window_create     "$ctrl"
    fi

    cui_edit_new "$dlg" "" 17 3 11 1 40 $IDC_LVSDLG_VOLNAME $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${lvsdlg_lvname}"
    fi
    cui_edit_new "$dlg" "" 17 5 11 1 40 $IDC_LVSDLG_EDSIZE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${lvsdlg_lvsize}"
    fi

    cui_button_new "$dlg" "&OK" 10 7 10 1 $IDC_LVSDLG_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" lvsdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
    cui_button_new "$dlg" "&Cancel" 21 7 10 1 $IDC_LVSDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" lvsdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# lvsresizedlg - dialog to manage additional groups
#============================================================================

#----------------------------------------------------------------------------
# lvsresizedlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function lvsresizedlg_ok_clicked()
{
    local win="$p2"
    local ctrl

    cui_window_getctrl "$win" "$IDC_VOLUMESIZE_NEWSIZE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        lvsresizedlg_changesize="$p2"
    fi

    if [ -z "$lvsresizedlg_changesize" ]
    then
        cui_message "$win" "Please enter a valid volume size (500m or 10g ...)" \
                           "Missing volume resize" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# lvsresizedlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function lvsresizedlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# lvsresizedlg_create_hook
# Create controls for additional groups dialog
# expects: $1 : window handle of dialog window
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function lvsresizedlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local lstall
    local lstsel

    if cui_label_new "$dlg" "Inc./Dec. size:" 2 1 16 1 $IDC_VOLUMESIZE_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "(50m, 2g)" 30 1 14 1 $IDC_VOLUMESIZE_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 18 1 11 1 40 $IDC_VOLUMESIZE_NEWSIZE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "$lvsresizedlg_changesize"
    fi

    cui_button_new "$dlg" "&OK" 10 4 10 1 $IDC_VOLUMESIZE_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" lvsresizedlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&Cancel" 26 4 10 1 $IDC_VOLUMESIZE_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" lvsresizedlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# functions to create modify or delete lvs
#============================================================================

#----------------------------------------------------------------------------
# lvs_resize_inc_dialog
# Modify volume size
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function lvs_resize_inc_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index
    local dlg
    lvs_fs=""
    lvs_mountpoint=""

    cui_window_getctrl "$win" "$IDC_LVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && lvsresizedlg_lv="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && lvsresizedlg_vg="$p2"
            cui_listview_gettext "$ctrl" "$index" "3" && lvsresizedlg_size="$p2"

            cui_window_new "$win" 0 0 47 8 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Extending volume size"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  lvsresizedlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal   "$dlg" && result="$p2"
                if [ "$result" == "$IDOK" ]
                then
                    lvs_get_filesystem "/dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                    lvs_get_mountpoint "/dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                    if [ -n "$lvs_mountpoint" ]
                    then
                        cui_message "$win" "Umount logical volume $lvs_mountpoint before resize?" "Volume is mounted" "${MB_YESNO}"
                        if [ "$p2" == "$IDYES" ]
                        then
                            umount -f $lvs_mountpoint
                        else
                            cui_window_destroy "$dlg"
                            return 1
                        fi
                    fi
                    if (lvextend -t -f -L+$lvsresizedlg_changesize /dev/$lvsresizedlg_vg/$lvsresizedlg_lv)
                    then
                        cui_message "$win" "Extending logical volume \"$lvsresizedlg_vg/$lvsresizedlg_lv\" with $lvsresizedlg_changesize ?" "Question" "${MB_YESNO}"
                        if [ "$p2" == "$IDYES" ]
                        then
                            local exec_cmd="&& sleep 2"
                            case "$lvs_fs" in
                                ext*)
                                    exec_cmd="$exec_cmd && e2fsck -f /dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                                    exec_cmd="$exec_cmd && resize2fs /dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                                    [ -n "$lvs_mountpoint" ] && exec_cmd="$exec_cmd && mount $lvs_mountpoint && sleep 2"
                                    ;;
                                xfs)
                                    if [ -n "$lvs_mountpoint" ]
                                    then
                                        exec_cmd="$exec_cmd && mount $lvs_mountpoint"
                                        exec_cmd="$exec_cmd && xfs_growfs $lvs_mountpoint && sleep 2"
                                    fi
                                    ;;
                            esac
                            local termwin
                            cui_getclientrect "$win"
                            local w="$p4"
                            local h="$p5"
                            local p="$[$h - $h / 2 + $h / 10]"
                            cui_terminal_new "$win" "" "0" "$p" "$[$w - 2]" "$[$h -$p + 1]" "${IDC_TERMWIN}" "$CWS_POPUP" "$CWS_NONE" && termwin="$p2"
                            if cui_valid_handle $termwin
                            then
                                cui_terminal_callback "$termwin" "$TERMINAL_EXIT" "$win" terminal_exit
                                cui_window_create     "$termwin"
#                                cui_terminal_write    "$termwin" "extend volume $lvsresizedlg_lv ..." 1
                                cui_terminal_run      "$termwin" "lvextend -f -L+$lvsresizedlg_changesize /dev/$lvsresizedlg_vg/$lvsresizedlg_lv 2>/dev/null $exec_cmd"
                            fi
                        fi
                    else
                        cui_message "$win" "Failed to extending the volume $lvsresizedlg_lv with $lvsresizedlg_changesize !" "Test failed" "$MB_ERROR"
                    fi
                fi
                cui_window_destroy "$dlg"
            fi
        fi
    fi
    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# lvs_resize_dec_dialog
# Modify volume size
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function lvs_resize_dec_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index
    local dlg
    lvs_fs=""
    lvs_mountpoint=""

    cui_window_getctrl "$win" "$IDC_LVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && lvsresizedlg_lv="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && lvsresizedlg_vg="$p2"
            cui_listview_gettext "$ctrl" "$index" "3" && lvsresizedlg_size="$p2"

            cui_window_new "$win" 0 0 47 8 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Reduce volume size"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  lvsresizedlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal   "$dlg" && result="$p2"
                if [ "$result" == "$IDOK" ]
                then
                    lvs_get_filesystem "/dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                    lvs_get_mountpoint "/dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                    if [ -n "$lvs_mountpoint" ]
                    then
                        cui_message "$win" "Umount logical volume $lvs_mountpoint before resize?" "Volume is mounted" "${MB_YESNO}"
                        if [ "$p2" == "$IDYES" ]
                        then
                            umount -f $lvs_mountpoint
                        else
                            cui_window_destroy "$dlg"
                            return 1
                        fi
                    fi
                    if ( lvreduce -t -f -L-$lvsresizedlg_changesize /dev/$lvsresizedlg_vg/$lvsresizedlg_lv )
                    then
                        cui_message "$win" "Reduce logical volume \"$lvsresizedlg_vg/$lvsresizedlg_lv\" with $lvsresizedlg_changesize ?" "Question" "${MB_YESNO}"
                        if [ "$p2" == "$IDYES" ]
                        then
                            local exec_cmd="&& sleep 2"
                            case "$lvs_fs" in
                                ext*)
                                    exec_cmd="$exec_cmd && e2fsck -f /dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                                    exec_cmd="$exec_cmd && resize2fs /dev/$lvsresizedlg_vg/$lvsresizedlg_lv"
                                    [ -n "$lvs_mountpoint" ] && exec_cmd="$exec_cmd && mount $lvs_mountpoint && sleep 2"
                                    ;;
                                xfs)
                                    if [ -n "$lvs_mountpoint" ]
                                    then
                                        exec_cmd="$exec_cmd && mount $lvs_mountpoint"
                                        exec_cmd="$exec_cmd && xfs_growfs $lvs_mountpoint && sleep 2"
                                    fi
                                    ;;
                            esac
                            local termwin
                            cui_getclientrect "$win"
                            local w="$p4"
                            local h="$p5"
                            local p="$[$h - $h / 2 + $h / 10]"
                            cui_terminal_new "$win" "" "0" "$p" "$[$w - 2]" "$[$h -$p + 1]" "${IDC_TERMWIN}" "$CWS_POPUP" "$CWS_NONE" && termwin="$p2"
                            if cui_valid_handle $termwin
                            then
                                cui_terminal_callback "$termwin" "$TERMINAL_EXIT" "$win" terminal_exit
                                cui_window_create     "$termwin"
#                                cui_terminal_write    "$termwin" "reduce volume $lvsresizedlg_lv ..." 1
                                cui_terminal_run      "$termwin" "lvreduce -f -L-$lvsresizedlg_changesize /dev/$lvsresizedlg_vg/$lvsresizedlg_lv 2>/dev/null $exec_cmd"
                            fi
                        fi
                    else
                        cui_message "$win" "Failed to reduce the volume $lvsresizedlg_lv with $lvsresizedlg_changesize !" "Test failed" "$MB_ERROR"
                    fi
                fi
                cui_window_destroy "$dlg"
            fi
        fi
    fi
    [ "$result" == "$IDOK" ]
    return "$?"
}


#----------------------------------------------------------------------------
# lvs_createlv_dialog
# Create a new lv entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function lvs_createlv_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg

    lvsdlg_lvname=""
    lvsdlg_lvgroup=""
    lvsdlg_lvsize=""

    cui_window_new "$win" 0 0 45 10 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle "$dlg"
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create logical volume"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  lvsdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            if ( lvcreate -t -n $lvsdlg_lvname -L ${lvsdlg_lvsize} $lvsdlg_lvgroup )
            then
                cui_message "$win" "Create logical volume \"${lvsdlg_lvgroup}/${lvsdlg_lvname}\" with ${lvsdlg_lvsize} ?" "Question" "${MB_YESNO}"
                if [ "$p2" == "$IDYES" ]
                then
                    lvcreate -n $lvsdlg_lvname -L ${lvsdlg_lvsize} $lvsdlg_lvgroup
                fi
            else
                cui_message "$win" "Failed to create the volume $lvsdlg_lvname with $lvsdlg_lvsize !" "Test failed" "$MB_ERROR"
            fi
        fi
        cui_window_destroy "$dlg"
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# lvs_deletelv_dialog
# Remove the lv entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function lvs_deletelv_dialog()
{
    local win="$1"
    local ctrl
    local index
    local lvsdlg_lv
    local lvsdlg_vg
    lvs_mountpoint=""

    cui_window_getctrl "$win" "$IDC_LVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && lvsdlg_lv="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && lvsdlg_vg="$p2"

            lvs_get_mountpoint "/dev/$lvsdlg_vg/$lvsdlg_lv"
            if [ -n "$lvs_mountpoint" ]
            then
                cui_message "$win" "Umount logical volume $lvs_mountpoint before delete?" "Volume is mounted" "${MB_YESNO}"
                if [ "$p2" == "$IDYES" ]
                then
                    umount -f $lvs_mountpoint
                else
                    return 1
                fi
            fi
            cui_message "$win" "Delete logical volume \"${lvsdlg_vg}/${lvsdlg_lv}\"?" "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                umount -f /dev/${lvsdlg_vg}/${lvsdlg_lv} >/dev/null 2>&1
                lvremove -f /dev/${lvsdlg_vg}/${lvsdlg_lv}
                return 0
            fi
        fi
    fi
    return 1
}

#============================================================================
# functions to sort the list view control and to select the sort column
#============================================================================

#----------------------------------------------------------------------------
# lvs_sort_list
# Sort the list view control by the column specified in lvs_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------
function lvs_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${lvs_sortcolumn}" != "-1" ]
    then
        if [ "${lvs_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${lvs_sortcolumn}" == "1" -o "${lvs_sortcolumn}" == "3" ]
        then
            cui_listview_numericsort "$ctrl" "${lvs_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${lvs_sortcolumn}" "$mode"
        fi
    fi
}

#----------------------------------------------------------------------------
# lvs_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function lvs_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# lvs_sortmenu_escape_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function lvs_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}

#----------------------------------------------------------------------------
# lvs_sortmenu_postkey_hook
# expects: $p2 : window handle
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------
function lvs_sortmenu_postkey_hook()
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
# lvs_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle
# returns: nothing
#----------------------------------------------------------------------------
function lvs_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item
    local oldcolumn="${lvs_sortcolumn}"
    local oldmode="${lvs_sortmode}"

    cui_menu_new "$win" "Sort column" 0 0 36 15 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_additem      "$menu" "Don't sort" 1
        cui_menu_additem      "$menu" "Sort by LV    (ascending)"  2
        cui_menu_additem      "$menu" "Sort by LV    (descending)" 3
        cui_menu_additem      "$menu" "Sort by VG    (ascending)"  4
        cui_menu_additem      "$menu" "Sort by VG    (descending)" 5
        cui_menu_additem      "$menu" "Sort by Size  (ascending)"  6
        cui_menu_additem      "$menu" "Sort by Size  (descending)" 7
        cui_menu_additem      "$menu" "Sort by Data  (ascending)"  8
        cui_menu_additem      "$menu" "Sort by Data  (descending)" 9
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" lvs_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" lvs_sortmenu_escape_hook
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" lvs_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1)
               lvs_sortcolumn="-1"
               ;;
            2)
               lvs_sortcolumn="0"
               lvs_sortmode="up"
               ;;
            3)
               lvs_sortcolumn="0"
               lvs_sortmode="down"
               ;;
            4)
               lvs_sortcolumn="1"
               lvs_sortmode="up"
               ;;
            5)
               lvs_sortcolumn="1"
               lvs_sortmode="down"
               ;;
            6)
               lvs_sortcolumn="3"
               lvs_sortmode="up"
               ;;
            7)
               lvs_sortcolumn="3"
               lvs_sortmode="down"
               ;;
            8)
               lvs_sortcolumn="6"
               lvs_sortmode="up"
               ;;
            9)
               lvs_sortcolumn="6"
               lvs_sortmode="down"
               ;;
            esac
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${lvs_sortcolumn}" -o "$oldmode" != "${lvs_sortmode}" ]
        then
            lvs_readdata      "$win"
        fi
    fi
}

#============================================================================
# lvs module (module functions called from lvman.cui.sh)
#============================================================================
#----------------------------------------------------------------------------
# lvs_menu : menu text for this module
#----------------------------------------------------------------------------
lvs_menu="Logical Volumes"
lvs_sortcolumn="-1"
lvs_sortmode="up"

#----------------------------------------------------------------------------
#  lvs_list_postkey_hook (catch ENTER key)
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------
function lvs_list_postkey_hook()
{
    local win="$p2"
    local key="$p4"

    if [ "$key" == "${KEY_ENTER}" ]
    then
        lvs_key "$win" "$KEY_F4"
        cui_return 1
    else
        cui_return 0
    fi
}

#----------------------------------------------------------------------------
# lvs_init (init the lvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function lvs_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 7 "${IDC_LVS_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "LV"
        cui_listview_setcoltext "$ctrl" 1 "VG"
        cui_listview_setcoltext "$ctrl" 2 "Attr"
        cui_listview_setcoltext "$ctrl" 3 "Size"
        cui_listview_setcoltext "$ctrl" 4 "Pool"
        cui_listview_setcoltext "$ctrl" 5 "Origin"
        cui_listview_setcoltext "$ctrl" 6 "Data%"
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" lvs_list_postkey_hook
        cui_window_create "$ctrl"
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_add "$ctrl" "Add, modify or delete lvs" 1
        cui_window_totop "$ctrl"
    fi

    cui_window_setlstatustext "$win" "Commands:F1=Help F4=Size+ F5=Size- F7=Create F8=Delete F9=Sort F10=Exit"
}

#----------------------------------------------------------------------------
# lvs_close (close the lvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function lvs_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_LVS_LIST}" && ctrl="$p2"
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
# lvs_size (resize the lvs module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------
function lvs_size()
{
    local ctrl

    cui_window_getctrl "$1" "$IDC_LVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi
}

#----------------------------------------------------------------------------
# lvs_readdata (read data of the lvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function lvs_readdata()
{
    local ctrl
    local win="$1"
    local sel;
    local count;
    local index;

    # read lv inforamtion
    cui_window_getctrl "$win" "$IDC_LVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && sel="$p2"
        cui_listview_clear  "$ctrl"

        _ifs="$IFS"
        lvs --separator=! --noheadings | while read line
        do
            IFS="!"
            set -- $line
            cui_listview_add "$ctrl" && index="$p2"

            cui_listview_settext "$ctrl" "$index" 0 "$1"         # LV
            cui_listview_settext "$ctrl" "$index" 1 "$2"         # VG
            cui_listview_settext "$ctrl" "$index" 2 "$3"         # Attr
            cui_listview_settext "$ctrl" "$index" 3 "$4"         # Size
            cui_listview_settext "$ctrl" "$index" 4 "$5"         # Pool
            cui_listview_settext "$ctrl" "$index" 5 "$6"         # Origin
            cui_listview_settext "$ctrl" "$index" 6 "$7"         # Data
            IFS="$_ifs"
        done

        cui_listview_update   "$ctrl"
        cui_listview_getcount "$ctrl" && count="$p2"

        if [ "$sel" -ge "0" -a "$count" -gt "0" ]
        then
            if [ "$sel" -ge "$count" ]
            then
                sel=$[$count - 1]
            fi
            lvs_sort_list     "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            lvs_sort_list     "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi
    fi
}

#----------------------------------------------------------------------------
# lvs_activate (activate the lvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function lvs_activate()
{
    local ctrl
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_LVS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_window_setfocus "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# lvs_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboad input
#----------------------------------------------------------------------------
function lvs_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F4")
        if lvs_resize_inc_dialog $win
        then
            lvs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F5")
        if lvs_resize_dec_dialog $win
        then
            lvs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F7")
        if lvs_createlv_dialog $win
        then
            lvs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if lvs_deletelv_dialog $win
        then
            lvs_readdata $win
        fi
        return 0
        ;; 
    "$KEY_F9")
        lvs_select_sort_column $win
        return 0
        ;;
    esac
    return 1
}

#============================================================================
# end of lvs module
#============================================================================
