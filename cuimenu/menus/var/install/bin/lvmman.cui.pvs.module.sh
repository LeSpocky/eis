#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/lvmman.cui.pvs.module.sh - module for eisfair lvm mananger
#
# Creation:     2014-10-01 Jens Vehlhaber jens@eisfair.org
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
IDC_PVS_LIST='12'

IDC_PVSDLG_BUTOK='10'  
IDC_PVSDLG_BUTCANCEL='11'
IDC_PVSDLG_LABEL1='12'
IDC_PVSDLG_EDNAME='20'

#----------------------------------------------------------------------------
# pvs_create_gid
# expects: nothing
# returns: next free gid in ${pvsdlg_pvsgid} 
#----------------------------------------------------------------------------
function pvs_create_gid
{
    oldifs="$IFS"   
    IFS=':'
    pvsdlg_pvsgid=200
    while read line
    do
        set -- $line 
        if [ $3 -gt ${pvsdlg_pvsgid} -a $3 -lt 300 ]
        then
            pvsdlg_pvsgid=$3
        fi
    done </etc/pvs
    IFS="$oldifs"

    pvsdlg_pvsgid=$[${pvsdlg_pvsgid} + 1]
}


#============================================================================
# pvsdlg - dialog to create and edit pvs
#============================================================================

#----------------------------------------------------------------------------
# pvsdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
function pvsdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    
    cui_window_getctrl "$win" "$IDC_PVSDLG_EDNAME"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_edit_gettext "$ctrl"
        pvsdlg_pvsname="$p2"
    fi

    if [ -z "${pvsdlg_pvsname}" ]
    then
        cui_message "$win" "No pvs name entered! Please enter a valid name" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# pvsdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------
function pvsdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# pvsdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled      
#----------------------------------------------------------------------------
function pvsdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    if cui_label_new "$dlg" "Group name:" 2 1 14 1 $IDC_PVSDLG_LABEL1 $CWS_NONE $CWS_NONE
    then
        cui_window_create     "$p2"
    fi

    if cui_edit_new "$dlg" "" 17 1 11 1 8 $IDC_PVSDLG_EDNAME $CWS_NONE $CWS_NONE
    then
        ctrl="$p2" 
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${pvsdlg_pvsname}"
    fi

    if cui_button_new "$dlg" "&OK" 5 3 10 1 $IDC_PVSDLG_BUTOK $CWS_DEFOK $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" pvsdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
      
    if cui_button_new "$dlg" "&Cancel" 16 3 10 1 $IDC_PVSDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE
    then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" pvsdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
      
    cui_return 1
}

#============================================================================
# functions to create modify or delete pvs (using pvsdlg)
#============================================================================

#----------------------------------------------------------------------------
# pvs_editpvs_dialog
# Modify the pvs entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function pvs_editpvs_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_PVS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        
        cui_listview_getsel "$ctrl"
        if [ "$p2" != "-1" ]
        then
            index="$p2"
            
            cui_listview_gettext "$ctrl" "$index" "0" && pvsdlg_pvsname="$p2"

            local orig_pvsname="${pvsdlg_pvsname}"

            if cui_window_new "$win" 0 0 32 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED]
            then
                local dlg="$p2"

                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Group"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  pvsdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    if [ "${orig_pvsname}" != "${pvsdlg_pvsname}" ]
                    then                
                        grep "^${pvsdlg_pvsname}:" /etc/pvs >/dev/null
                        if [ $? == 0 ]
                        then
                            cui_message "$win" \
                                "Group \"${pvsdlg_pvsname}\" already exists!" \
                                "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        else
                            errmsg=$(/sbin/pvsmod -n "${pvsdlg_pvsname}" ${orig_pvsname} 2>&1)
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
# pvs_createpvs_dialog
# Create a new pvs entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function pvs_createpvs_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    
    pvsdlg_pvsname=""

    if cui_window_new "$win" 0 0 32 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED]
    then
        local dlg="$p2"

        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Group"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  pvsdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            grep "^${pvsdlg_pvsname}:" /etc/pvs >/dev/null
            if [ $? != 0 ]
            then          
                pvs_create_gid

                errmsg=$(/sbin/pvcreate /dev/sdb4 2>&1)

                if [ "$?" != "0" ]
                then
                    cui_message "$win" \
                        "Error! $errmsg" "Error" "$MB_ERROR"
                    result="$IDCANCEL"
                fi
            else  
                cui_message "$win" \
                    "Group \"${pvsdlg_pvsname}\" already exists!" \
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
# pvs_deletepvs_dialog
# Remove the pvs entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
function pvs_deletepvs_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl 
    local index

    cui_window_getctrl "$win" "$IDC_PVS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"

        cui_listview_getsel "$ctrl"
        if [ "$p2" != "-1" ]
        then
            index="$p2"

            cui_listview_gettext "$ctrl" "$index" "0" && pvsdlg_pvsname="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && pvsdlg_pvsgid="$p2"

            if [ "${pvsdlg_pvsgid}" -lt 200 -o "${pvsdlg_pvsgid}" -ge 65534 ]
            then
                cui_message "$win" "It is not allowed to remove pvs \"${pvsdlg_pvsname}\", sorry!" "Error" "${MB_ERROR}"
            else
                cui_message "$win" "Really Delete pvs \"${pvsdlg_pvsname}\"?" "Question" "${MB_YESNO}"
                if [ "$p2" == "$IDYES" ]
                then
                    local errmsg=$(/usr/sbin/pvsdel "${pvsdlg_pvsname}" 2>&1)
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
    fi

    [ "$result" == "$IDOK" ]
    return "$?"
}

#============================================================================
# functions to sort the list view control and to select the sort column
#============================================================================

#----------------------------------------------------------------------------
# pvs_sort_list
# Sort the list view control by the column specified in pvs_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------
function pvs_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${pvs_sortcolumn}" != "-1" ]
    then
        if [ "${pvs_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${pvs_sortcolumn}" == "1" ]
        then
            cui_listview_numericsort "$ctrl" "${pvs_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${pvs_sortcolumn}" "$mode"
        fi
    fi
}
 
#----------------------------------------------------------------------------
# pvs_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function pvs_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# pvs_sortmenu_escape_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------
function pvs_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}
 
#----------------------------------------------------------------------------
# pvs_sortmenu_postkey_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------
function pvs_sortmenu_postkey_hook()
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
# pvs_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle   
# returns: nothing
#----------------------------------------------------------------------------
function pvs_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item  
    local oldcolumn="${pvs_sortcolumn}"
    local oldmode="${pvs_sortmode}"

    if cui_menu_new "$win" "Sort column" 0 0 36 10 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE"
    then
        menu="$p2"
        cui_menu_additem      "$menu" "Don't sort" 1
        cui_menu_additem      "$menu" "Sort by Group (ascending)"  2
        cui_menu_additem      "$menu" "Sort by Group (descending)" 3
        cui_menu_additem      "$menu" "Sort by Gid   (ascending)"  4
        cui_menu_additem      "$menu" "Sort by Gid   (descending)" 5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1
        
        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" pvs_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" pvs_sortmenu_escape_hook 
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" pvs_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1) 
               pvs_sortcolumn="-1"
               ;;
            2)   
               pvs_sortcolumn="0"
               pvs_sortmode="up" 
               ;;
            3)   
               pvs_sortcolumn="0"
               pvs_sortmode="down"
               ;;
            4)   
               pvs_sortcolumn="1"
               pvs_sortmode="up" 
               ;;
            5)   
               pvs_sortcolumn="1"
               pvs_sortmode="down"
               ;;
            esac 
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${pvs_sortcolumn}" -o "$oldmode" != "${pvs_sortmode}" ]
        then
            pvs_readdata      "$win"
        fi
    fi
}


#============================================================================
# pvs module (module functions called from userman.cui.sh)
#============================================================================
#----------------------------------------------------------------------------
# pvs module
#----------------------------------------------------------------------------
pvs_menu="Physical Volume"
pvs_sortcolumn="-1"
pvs_sortmode="up"

#----------------------------------------------------------------------------
#  pvs_list_postkey_hook (catch ENTER key)      
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------
function pvs_list_postkey_hook()
{
    local win="$p2"
    local key="$p4"
    
    if [ "$key" == "${KEY_ENTER}" ]
    then
        pvs_key "$win" "$KEY_F4"
        cui_return 1
    else
        cui_return 0
    fi       
}

#----------------------------------------------------------------------------
# pvs_init (init the grous module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function pvs_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 6 "${IDC_PVS_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "PV"
        cui_listview_setcoltext "$ctrl" 1 "VG"
        cui_listview_setcoltext "$ctrl" 2 "Format"
        cui_listview_setcoltext "$ctrl" 3 "Attr"
        cui_listview_setcoltext "$ctrl" 4 "Size"
        cui_listview_setcoltext "$ctrl" 5 "Free"
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" pvs_list_postkey_hook
        cui_window_create "$ctrl"
    fi
    
    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_add "$ctrl" "Add, modify or delete pvs" 1
        cui_window_totop "$ctrl"
    fi
    
    cui_window_setlstatustext "$win" "Commands: F4=Edit F7=Create F8=Delete F9=Sort F10=Exit"
}

#----------------------------------------------------------------------------
# pvs_close (close the pvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function pvs_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_PVS_LIST}" && ctrl="$p2"
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
# pvs_size (resize the pvs module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------
function pvs_size()
{
    local ctrl
    
    cui_window_getctrl "$1" "${IDC_PVS_LIST}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi        
}

#----------------------------------------------------------------------------
# pvs_readdata (read data of the pvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function pvs_readdata()
{
    local ctrl
    local win="$1"
    local sel;  
    local count;
    local index;

    # read user inforamtion
    cui_window_getctrl "$win" "$IDC_PVS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && sel="$p2"
        cui_listview_clear  "$ctrl"

        _ifs="$IFS"
		pvs --separator=! --noheadings | while read line
		do
            IFS="!"
            set -- $line
			cui_listview_add "$ctrl" && index="$p2"

			cui_listview_settext "$ctrl" "$index" 0 "$1"         # PV
			cui_listview_settext "$ctrl" "$index" 1 "$2"         # VG
			cui_listview_settext "$ctrl" "$index" 2 "$3"         # Format
			cui_listview_settext "$ctrl" "$index" 3 "$4"         # Attr
			cui_listview_settext "$ctrl" "$index" 4 "$5"         # Size
			cui_listview_settext "$ctrl" "$index" 5 "$6"         # Free
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
            pvs_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            pvs_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi        
    fi
}

#----------------------------------------------------------------------------
# pvs_activate (activate the pvs module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------
function pvs_activate()
{
    local ctrl
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_PVS_LIST"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_window_setfocus "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# pvs_key (handle keyboard input)         
#    $1 --> window handle of main window
#    $2 --> keyboard input
#----------------------------------------------------------------------------
function pvs_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F4")
        if pvs_editpvs_dialog $win
        then
            pvs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F7")
        if pvs_createpvs_dialog $win
        then
            pvs_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if pvs_deletepvs_dialog $win
        then
            pvs_readdata $win
        fi
        return 0
        ;;      
    "$KEY_F9")
        pvs_select_sort_column $win
        return 0  
        ;;
    esac        

    return 1
} 
 
#============================================================================
# end of pvs module
#============================================================================
