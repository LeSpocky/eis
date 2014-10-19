#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/lvmman.cui.vgs.module.sh - module for eisfair lvm mananger
#
# Creation:     2014-06-10 Jens Vehlhaber jens@eisfair.org
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
IDC_VGS_LIST='12'

IDC_VGSDLG_BUTOK='10'  
IDC_VGSDLG_BUTCANCEL='11'
IDC_VGSDLG_LABEL1='12'
IDC_VGSDLG_LABEL2='13'
IDC_VGSDLG_EDNAME='20'
IDC_VGSDLG_EDPV='21'
IDC_VGSDLG_CBGROUP='30'

#============================================================================
# vgsdlg - dialog to create and edit vgs
#============================================================================

#----------------------------------------------------------------------------
# vgsdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function vgsdlg_ok_clicked()
{
    local win="$p2"
    local ctrl

    cui_window_getctrl "$win" "$IDC_VGSDLG_EDNAME"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_edit_gettext "$ctrl"
        vgName="$p2"
    fi

    if [ -z "${vgName}" ]
    then
        cui_message "$win" "No vgs name entered! Please enter a valid name" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_getctrl "$win" "$IDC_VGSDLG_CBGROUP" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_combobox_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_combobox_get "$ctrl" "$index"
            pvName="$p2"
        else
            cui_message "$win" "No physical volume selected!" \
                               "Missing data" "$MB_ERROR"
            cui_return 1
            return
        fi
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# vgsdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function vgsdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# vgsdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled
#----------------------------------------------------------------------------
function vgsdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    if cui_label_new "$dlg" "Volume Group Name:" 2 1 14 1 $IDC_VGSDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_label_new "$dlg" "Physical Device:" 2 3 14 1 $IDC_VGSDLG_LABEL2 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi
    if cui_edit_new "$dlg" "" 17 1 14 1 40 $IDC_VGSDLG_EDNAME $CWS_NONE $CWS_NONE
    then
        ctrl="$p2" 
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${vgName}"
    fi
    if cui_edit_new "$dlg" "" 17 3 14 1 40 $IDC_VGSDLG_EDPV $CWS_NONE $CWS_NONE
    then
        ctrl="$p2"
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${pvName}"
    fi
    if cui_combobox_new "$dlg" 17 3 12 10 $IDC_VGSDLG_CBGROUP $CWS_NONE $CWS_NONE
    then
        ctrl="$p2"
        pvs | while read line
        do
            set -- $line
            if [ "$1" != "PV" ]
            then
                cui_combobox_add      "$ctrl" "$1"
            fi
        done
        cui_combobox_select   "$ctrl" "${pvCombo}"
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&OK" 10 5 10 1 $IDC_VGSDLG_BUTOK $CWS_DEFOK $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" vgsdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi

    if cui_button_new "$dlg" "&Cancel" 21 5 10 1 $IDC_VGSDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" vgsdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}

#============================================================================
# functions to create modify or delete vgs (using vgsdlg)
#============================================================================

#----------------------------------------------------------------------------
# vgs_editvgs_dialog
# Modify the vgs entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function vgs_editvgs_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_VGS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"

        cui_listview_getsel "$ctrl"
        if [ "$p2" != "-1" ]
        then
            index="$p2"

            cui_listview_gettext "$ctrl" "$index" "0" && vgName="$p2"

            local orig_vgsname="${vgName}"

            if cui_window_new "$win" 0 0 36 9 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED]
            then
                local dlg="$p2"

                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Volume Group"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  vgsdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    if [ "${orig_vgsname}" != "${vgName}" ]
                    then
                        grep "^${vgName}:" /etc/vgs >/dev/null
                        if [ $? == 0 ]
                        then
                            cui_message "$win" \
                                "Group \"${vgName}\" already exists!" \
                                "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        else
                            errmsg=$(/sbin/vgsmod -n "${vgName}" ${orig_vgsname} 2>&1)
                            if [ "$?" != "0" ]
                            then
                                cui_message "$win" \
                                    "Error! $errmsg" "Error" "$MB_ERROR"
                                result="$IDCANCEL"
                            fi
                        fi
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
# vgs_createvgs_dialog
# Create a new vgs entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function vgs_createvgs_dialog()
{
    local win="$1"
    local result="$IDCANCEL"

    vgName=""

    if cui_window_new "$win" 0 0 36 9 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED]
    then
        local dlg="$p2"

        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Volume Group"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  vgsdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            pvs | grep "^${vgName}:" >/dev/null
            if [ $? != 0 ]
            then
                errmsg=$(vgcreate ${vgName} ${pvName} 2>&1)

                if [ "$?" != "0" ]
                then
                    cui_message "$win" "Error! $errmsg" "Error" "$MB_ERROR"
                    result="$IDCANCEL"
                fi
            else
                cui_message "$win" "Group \"${vgName}\" already exists!" \
                    "Error" "$MB_ERROR"
                result="$IDCANCEL"
            fi
        fi

        cui_window_destroy "$dlg"
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#----------------------------------------------------------------------------
# deleteVGsDialog
# Remove the vgs entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function deleteVGsDialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl 
    local index

    cui_window_getctrl "$win" "$IDC_VGS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"

        cui_listview_getsel "$ctrl"
        if [ "$p2" != "-1" ]
        then
            index="$p2"

            cui_listview_gettext "$ctrl" "$index" "0" && vgName="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && vgsdlg_vgsgid="$p2"

            cui_message "$win" "Really Delete Volume Group \"${vgName}\"?" "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                local errmsg=$(vgremove ${vgName} 2>&1)
                if [ "$?" == "0" ]
                then
                    result="$IDOK"
                else
                    cui_message "$win" \
                         "Error! $errmsg" "Error" "$MB_ERROR"
                    result="$IDCANCEL"
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
# vgs_sort_list
# Sort the list view control by the column specified in vgs_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------
function vgs_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${vgs_sortcolumn}" != "-1" ]
    then
        if [ "${vgs_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${vgs_sortcolumn}" == "1" ]
        then
            cui_listview_numericsort "$ctrl" "${vgs_sortcolumn}" "$mode"
        elif [ "${vgs_sortcolumn}" == "2" ]
        then
            cui_listview_numericsort "$ctrl" "${vgs_sortcolumn}" "$mode"
        elif [ "${vgs_sortcolumn}" == "3" ]
        then
            cui_listview_numericsort "$ctrl" "${vgs_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${vgs_sortcolumn}" "$mode"
        fi
    fi
}

#----------------------------------------------------------------------------
# vgs_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function vgs_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# vgs_sortmenu_escape_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function vgs_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}
 
#----------------------------------------------------------------------------
# vgs_sortmenu_postkey_hook
# expects: $p2 : window handle
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------
function vgs_sortmenu_postkey_hook()
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
# selectSortColumn
# Show menu to select the sort column
# expects: $1 : base window handle   
# returns: nothing
#----------------------------------------------------------------------------
function selectSortColumn()
{
    local win="$1"
    local menu
    local result
    local item  
    local oldcolumn="${vgs_sortcolumn}"
    local oldmode="${vgs_sortmode}"

    if cui_menu_new "$win" "Sort column" 0 0 36 10 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE"
    then
        menu="$p2"
        cui_menu_additem      "$menu" "Don't sort"                  1
        cui_menu_additem      "$menu" "Sort by VG    (ascending)"   2
        cui_menu_additem      "$menu" "Sort by VG    (descending)"  3
        cui_menu_additem      "$menu" "Sort by #PV   (ascending)"   4
        cui_menu_additem      "$menu" "Sort by #PV   (descending)"  5
        cui_menu_additem      "$menu" "Sort by #VG   (ascending)"   6
        cui_menu_additem      "$menu" "Sort by #VG   (descending)"  7
        cui_menu_additem      "$menu" "Sort by #SN   (ascending)"   8
        cui_menu_additem      "$menu" "Sort by #SN   (descending)"  9
        cui_menu_additem      "$menu" "Sort by Attr  (ascending)"  10
        cui_menu_additem      "$menu" "Sort by Attr  (descending)" 11
        cui_menu_additem      "$menu" "Sort by Size (ascending)"  12
        cui_menu_additem      "$menu" "Sort by Size (descending)" 13
        cui_menu_additem      "$menu" "Sort by Free (ascending)"  14
        cui_menu_additem      "$menu" "Sort by Free (descending)" 15
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" vgs_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" vgs_sortmenu_escape_hook 
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" vgs_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1)
               vgs_sortcolumn="-1"
               ;;
            2)
               vgs_sortcolumn="0"
               vgs_sortmode="up" 
               ;;
            3)
               vgs_sortcolumn="0"
               vgs_sortmode="down"
               ;;
            4)
               vgs_sortcolumn="1"
               vgs_sortmode="up" 
               ;;
            5)
               vgs_sortcolumn="1"
               vgs_sortmode="down"
               ;;
            6)
               vgs_sortcolumn="2"
               vgs_sortmode="up" 
               ;;
            7)
               vgs_sortcolumn="2"
               vgs_sortmode="down"
               ;;
            8)
               vgs_sortcolumn="3"
               vgs_sortmode="up" 
               ;;
            9)
               vgs_sortcolumn="3"
               vgs_sortmode="down"
               ;;
            10)
               vgs_sortcolumn="4"
               vgs_sortmode="up" 
               ;;
            11)
               vgs_sortcolumn="4"
               vgs_sortmode="down"
               ;;
            12)
               vgs_sortcolumn="5"
               vgs_sortmode="up" 
               ;;
            13)
               vgs_sortcolumn="5"
               vgs_sortmode="down"
               ;;
            14)
               vgs_sortcolumn="6"
               vgs_sortmode="up"
               ;;
            15)
               vgs_sortcolumn="6"
               vgs_sortmode="down"
               ;;
            esac
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${vgs_sortcolumn}" -o "$oldmode" != "${vgs_sortmode}" ]
        then
            vgs_readdata      "$win"
        fi
    fi
}

#============================================================================
# vgs module (module functions called from userman.cui.sh)
#============================================================================
#----------------------------------------------------------------------------
# vgs module
#----------------------------------------------------------------------------
vgs_menu="Volume Groups"
vgs_sortcolumn="-1"
vgs_sortmode="up"

#----------------------------------------------------------------------------
#  vgs_list_postkey_hook (catch ENTER key)      
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------
function vgs_list_postkey_hook()
{
    local win="$p2"
    local key="$p4"

    if [ "$key" == "${KEY_ENTER}" ]
    then
        vgs_key "$win" "$KEY_F4"
        cui_return 1
    else
        cui_return 0
    fi
}

#----------------------------------------------------------------------------
# vgs_init (init the grous module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function vgs_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 7 "${IDC_VGS_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "VG"
        cui_listview_setcoltext "$ctrl" 1 "#PV" 
        cui_listview_setcoltext "$ctrl" 2 "#LV"
        cui_listview_setcoltext "$ctrl" 3 "#SN" 
        cui_listview_setcoltext "$ctrl" 4 "Attr" 
        cui_listview_setcoltext "$ctrl" 5 "Size"
        cui_listview_setcoltext "$ctrl" 6 "Free"
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" vgs_list_postkey_hook
        cui_window_create "$ctrl"
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_add "$ctrl" "Add, modify or delete vgs" 1
        cui_window_totop "$ctrl"
    fi

    cui_window_setlstatustext "$win" "Commands: F4=Edit F7=Create F8=Delete F9=Sort F10=Exit"
}

#----------------------------------------------------------------------------
# vgs_close (close the vgs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function vgs_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_VGS_LIST}" && ctrl="$p2"
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
# vgs_size (resize the vgs module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------
function vgs_size()
{
    local ctrl

    cui_window_getctrl "$1" "${IDC_VGS_LIST}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi
}

#----------------------------------------------------------------------------
# vgs_readdata (read data of the vgs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function vgs_readdata()
{
    local ctrl
    local win="$1"
    local sel
    local count
    local index

    # read vgs inforamtion
    cui_window_getctrl "$win" "$IDC_VGS_LIST"  && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && sel="$p2"
        cui_listview_clear  "$ctrl"

        _ifs="$IFS"
        vgs --separator=! --noheadings | while read line
        do
            IFS="!"
            set -- $line
            cui_listview_add "$ctrl" && index="$p2"
            cui_listview_settext "$ctrl" "$index" 0 "$1"         # VG
            cui_listview_settext "$ctrl" "$index" 1 "$2"         # #PV
            cui_listview_settext "$ctrl" "$index" 2 "$3"         # #LV
            cui_listview_settext "$ctrl" "$index" 3 "$4"         # #SN
            cui_listview_settext "$ctrl" "$index" 4 "$5"         # Attr
            cui_listview_settext "$ctrl" "$index" 5 "$6"         # VSize
            cui_listview_settext "$ctrl" "$index" 6 "$7"         # VFree
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
            vgs_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            vgs_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi
    fi
}

#----------------------------------------------------------------------------
# vgs_activate (activate the vgs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function vgs_activate()
{
    local ctrl
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_VGS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_window_setfocus "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# vgs_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboard input
#----------------------------------------------------------------------------
function vgs_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F4")
        if vgs_editvgs_dialog $win
        then
            vgs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F7")
        if vgs_createvgs_dialog $win
        then
            vgs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if deleteVGsDialog $win
        then
            vgs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F9")
        selectSortColumn $win
        return 0
        ;;
    esac

    return 1
}

#============================================================================
# end of vgs module
#============================================================================
