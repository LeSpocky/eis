#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/userman.cui.grous.module.sh - module for eisfair user mananger
#
# Creation:     2008-03-09 dv
# Last update:  $Id: userman.cui.groups.module.sh 32221 2012-11-16 21:49:12Z dv $
#
# Copyright (c) 2001-2007 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#============================================================================
# control constants
#============================================================================
IDC_GROUPS_LIST='12'

IDC_GROUPSDLG_BUTOK='10'  
IDC_GROUPSDLG_BUTCANCEL='11'
IDC_GROUPSDLG_LABEL1='12'
IDC_GROUPSDLG_EDNAME='20'

IDC_EDITMEMBERS_BUTOK='10'
IDC_EDITMEMBERS_BUTCANCEL='11'
IDC_EDITMEMBERS_LSTALL='12'
IDC_EDITMEMBERS_LSTSEL='13'
IDC_EDITMEMBERS_BUTADD='14'
IDC_EDITMEMBERS_BUTREMOVE='15'


#----------------------------------------------------------------------------
# is_group_empty
# expects: $1 group id
# returns: 0 if empty (success) or 1 if not empty (failure)
#----------------------------------------------------------------------------

function is_group_empty
{
    local gid=$1
    local oldifs=$IFS
    
    while read line
    do
        IFS=':'
        set -- $line
        g="$4"
        IFS="$oldifs"
                
        if [ $g = $gid ]
        then
            found_user=$1
            return 1
        fi
    done </etc/passwd
    return 0                                                                                                                                
}


#----------------------------------------------------------------------------
# groups_create_gid
# expects: nothing
# returns: next free gid in ${groupsdlg_groupgid} 
#----------------------------------------------------------------------------

function groups_create_gid
{
    oldifs="$IFS"   
    IFS=':'
    groupsdlg_groupgid=200
    while read line
    do
        set -- $line 
        if [ $3 -gt ${groupsdlg_groupgid} -a $3 -lt 300 ]
        then
            groupsdlg_groupgid=$3
        fi
    done </etc/group
    IFS="$oldifs"

    groupsdlg_groupgid=$[${groupsdlg_groupgid} + 1]
}


#============================================================================
# groupsdlg - dialog to create and edit groups
#============================================================================

#----------------------------------------------------------------------------
# groupsdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function groupsdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    
    cui_window_getctrl "$win" "$IDC_GROUPSDLG_EDNAME" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        groupsdlg_groupname="$p2"
    fi

    if [ -z "${groupsdlg_groupname}" ]
    then
        cui_message "$win" "No group name entered! Please enter a valid name" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    cui_window_close "$win" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# groupsdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function groupsdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# groupsdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled      
#----------------------------------------------------------------------------

function groupsdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    cui_label_new "$dlg" "Group name:" 2 1 14 1 $IDC_GROUPSDLG_LABEL1 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 21 1 32 $IDC_GROUPSDLG_EDNAME $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${groupsdlg_groupname}"
    fi

    cui_button_new "$dlg" "&OK" 10 3 10 1 $IDC_GROUPSDLG_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupsdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
      
    cui_button_new "$dlg" "&Cancel" 21 3 10 1 $IDC_GROUPSDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupsdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
      
    cui_return 1
}

#============================================================================
# groupmembersdlg - dialog to manage group members
#============================================================================

#----------------------------------------------------------------------------
# groupmembersdlg_butadd_clicked
# button or listbox clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function groupmembersdlg_butadd_clicked()
{
    local win="$p2"
    local lstall
    local lstsel
    local index
    local newindex
    
    cui_window_getctrl "$win" "$IDC_EDITMEMBERS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$win" "$IDC_EDITMEMBERS_LSTSEL" && lstsel="$p2"
        if cui_valid_handle "$lstsel"
        then
            cui_listbox_getsel "$lstall" && index="$p2"
            if cui_valid_index "$index"
            then
                cui_listbox_get    "$lstall" "$index"
                cui_listbox_add    "$lstsel" "$p2" && newindex="$p2"
                cui_listbox_delete "$lstall" "$index"
                cui_listbox_setsel "$lstsel" "$newindex"
            fi
        fi                
    fi
    
    cui_return 1
}

#----------------------------------------------------------------------------
# groupmembersdlg_butrem_clicked
# button or listbox clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function groupmembersdlg_butrem_clicked()
{
    local win="$p2"
    local lstall
    local lstsel
    local index
    local newindex
    
    cui_window_getctrl "$win" "$IDC_EDITMEMBERS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$win" "$IDC_EDITMEMBERS_LSTSEL" && lstsel="$p2"
        if cui_valid_handle "$lstsel"
        then
            cui_listbox_getsel "$lstsel" && index="$p2"
            if cui_valid_index "$index"
            then
                cui_listbox_get    "$lstsel" "$index"
                cui_listbox_add    "$lstall" "$p2" && newindex="$p2"
                cui_listbox_delete "$lstsel" "$index"
                cui_listbox_setsel "$lstall" "$newindex"
            fi
        fi                
    fi
    
    cui_return 1
}

#----------------------------------------------------------------------------
# groupmembersdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function groupmembersdlg_ok_clicked()
{
    local dlg="$p2"
    local lstsel
    local count
    local index
    
    groupmembersdlg_members=""
    
    cui_window_getctrl "$dlg" "$IDC_EDITMEMBERS_LSTSEL" && lstsel="$p2"
    if cui_valid_handle "$lstsel"
    then
        count=0
        index=0
        
        cui_listbox_getcount "$lstsel"  && count="$p2"
        
        while [ "$index" -lt "$count" ]
        do
            cui_listbox_get "$lstsel" "$index"
            
            if [ -z "${groupmembersdlg_members}" ]
            then
                groupmembersdlg_members="$p2"
            else
                groupmembersdlg_members="${groupmembersdlg_members},$p2"
            fi
            
            index=$[$index + 1]
        done
    fi    

    cui_window_close "$dlg" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# groupmembersdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function groupmembersdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# groupmembersdlg_create_hook
# Create controls for additional groups dialog
# expects: $1 : window handle of dialog window
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function groupmembersdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local lstall
    local lstsel

    cui_listbox_new "$dlg" "Unselected" 2 1 17 10 $IDC_EDITMEMBERS_LSTALL $LB_SORTED $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listbox_callback  "$ctrl" "$LISTBOX_CLICKED" "$dlg" groupmembersdlg_butadd_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&>" 20 3 5 1 $IDC_EDITMEMBERS_BUTADD $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupmembersdlg_butadd_clicked
        cui_window_create     "$ctrl"    
    fi

    cui_button_new "$dlg" "&<" 20 5 5 1 $IDC_EDITMEMBERS_BUTREMOVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupmembersdlg_butrem_clicked
        cui_window_create     "$ctrl"    
    fi

    cui_listbox_new "$dlg" "Selected" 26 1 17 10 $IDC_EDITMEMBERS_LSTSEL $LB_SORTED $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listbox_callback  "$ctrl" "$LISTBOX_CLICKED" "$dlg" groupmembersdlg_butrem_clicked
        cui_window_create     "$ctrl"
    fi
    
    cui_label_new  "$dlg" "Tip: use Space-key to select!" 2 11 30 1 0 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&OK" 10 13 10 1 $IDC_EDITMEMBERS_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupmembersdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
                                    
    cui_button_new "$dlg" "&Cancel" 26 13 10 1 $IDC_EDITMEMBERS_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" groupmembersdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_window_getctrl "$dlg" "$IDC_EDITMEMBERS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$dlg" "$IDC_EDITMEMBERS_LSTSEL" && lstsel="$p2"
        if cui_valid_handle "$lstsel"
        then
            sys_group_member_selection "$lstall" "$lstsel" "${groupmembersdlg_group}"
            
            cui_listbox_setsel "$lstsel" "0"
            cui_listbox_setsel "$lstall" "0"
            cui_window_setfocus "$lstall"
        fi                
    fi
                                                                        
    cui_return 1            
}             
             

#============================================================================
# functions to create modify or delete groups (using groupsdlg and groupmembersdlg)
#============================================================================

#----------------------------------------------------------------------------
# groups_editmembers_dialog
# Edit group members
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function groups_editmembers_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index
    local dlg

    cui_window_getctrl "$win" "$IDC_USERS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && groupmembersdlg_group="$p2"            

            cui_window_new "$win" 0 0 47 17 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Group members"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  groupmembersdlg_create_hook
                cui_window_create    "$dlg"
        
                cui_window_modal   "$dlg" && result="$p2"
                if [ "$result" == "$IDOK" ]
                then
                     sys_set_group_members "${groupmembersdlg_group}" "${groupmembersdlg_members}"
                     if [ "$p2" != "1" ]
                     then
                         cui_message "$win" \
                              "Error! Failed to write user list!" "Error" "$MB_ERROR"
                         result="$IDCANCEL"
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
# groups_editgroup_dialog
# Modify the group entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function groups_editgroup_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl
    local index
    local dlg

    cui_window_getctrl "$win" "$IDC_GROUPS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && groupsdlg_groupname="$p2"

            local orig_groupname="${groupsdlg_groupname}"

            cui_window_new "$win" 0 0 42 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit Group"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  groupsdlg_create_hook
                cui_window_create    "$dlg"

                cui_window_modal     "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    if [ "${orig_groupname}" != "${groupsdlg_groupname}" ]
                    then                
                        grep "^${groupsdlg_groupname}:" /etc/group >/dev/null
                        if [ $? == 0 ]
                        then
                            cui_message "$win" \
                                "Group \"${groupsdlg_groupname}\" already exists!" \
                                "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        else
                            errmsg=$(/usr/sbin/groupmod -n "${groupsdlg_groupname}" ${orig_groupname} 2>&1)
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
# groups_creategroup_dialog
# Create a new group entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
              
function groups_creategroup_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    
    groupsdlg_groupname=""

    cui_window_new "$win" 0 0 42 7 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle "$dlg"
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create Group"
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  groupsdlg_create_hook
        cui_window_create    "$dlg"

        cui_window_modal     "$dlg" && result="$p2"

        if  [ "$result" == "$IDOK" ]
        then
            grep "^${groupsdlg_groupname}:" /etc/group >/dev/null
            if [ $? != 0 ]
            then          
                groups_create_gid

                errmsg=$(/usr/sbin/addgroup \
                    -g "${groupsdlg_groupgid}" \
                    ${groupsdlg_groupname} 2>&1)

                if [ "$?" != "0" ]
                then
                    cui_message "$win" \
                        "Error! $errmsg" "Error" "$MB_ERROR"
                    result="$IDCANCEL"
                fi
            else  
                cui_message "$win" \
                    "Group \"${groupsdlg_groupname}\" already exists!" \
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
# groups_deletegroup_dialog
# Remove the group entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function groups_deletegroup_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local ctrl 
    local index

    cui_window_getctrl "$win" "$IDC_GROUPS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && groupsdlg_groupname="$p2"
            cui_listview_gettext "$ctrl" "$index" "1" && groupsdlg_groupgid="$p2"

            if [ "${groupsdlg_groupgid}" -lt 200 -o "${groupsdlg_groupgid}" -ge 65534 ]
            then
                cui_message "$win" "It is not allowed to remove group \"${groupsdlg_groupname}\", sorry!" "Error" "${MB_ERROR}"
            else
                if is_group_empty ${groupsdlg_groupgid}
                then
                    cui_message "$win" "Really Delete group \"${groupsdlg_groupname}\"?" "Question" "${MB_YESNO}"
                    if [ "$p2" == "$IDYES" ]
                    then
                        local errmsg=$(/usr/sbin/delgroup "${groupsdlg_groupname}" 2>&1)
                        if [ "$?" == "0" ]
                        then
                            result="$IDOK"
                        else
                            cui_message "$win" \
                                 "Error! $errmsg" "Error" "$MB_ERROR"
                        fi
                    fi
                else
                    cui_message "$win" "Cannot remove group \"${groupsdlg_groupname}\"! ${CUINL}User \"${found_user}\" is still member of this group." "Error" "${MB_ERROR}"
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
# groups_sort_list
# Sort the list view control by the column specified in groups_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------

function groups_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${groups_sortcolumn}" != "-1" ]
    then
        if [ "${groups_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${groups_sortcolumn}" == "1" ]
        then
            cui_listview_numericsort "$ctrl" "${groups_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${groups_sortcolumn}" "$mode"
        fi
    fi
}
 
#----------------------------------------------------------------------------
# groups_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function groups_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# groups_sortmenu_escape_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function groups_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}
 
#----------------------------------------------------------------------------
# groups_sortmenu_postkey_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function groups_sortmenu_postkey_hook()
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
# groups_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle   
# returns: nothing
#----------------------------------------------------------------------------

function groups_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item  
    local oldcolumn="${groups_sortcolumn}"
    local oldmode="${groups_sortmode}"

    cui_menu_new "$win" "Sort column" 0 0 36 10 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_additem      "$menu" "Don't sort" 1
        cui_menu_additem      "$menu" "Sort by Group (ascending)"  2
        cui_menu_additem      "$menu" "Sort by Group (descending)" 3
        cui_menu_additem      "$menu" "Sort by Gid   (ascending)"  4
        cui_menu_additem      "$menu" "Sort by Gid   (descending)" 5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1
        
        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" groups_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" groups_sortmenu_escape_hook 
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" groups_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1) 
               groups_sortcolumn="-1"
               ;;
            2)   
               groups_sortcolumn="0"
               groups_sortmode="up" 
               ;;
            3)   
               groups_sortcolumn="0"
               groups_sortmode="down"
               ;;
            4)   
               groups_sortcolumn="1"
               groups_sortmode="up" 
               ;;
            5)   
               groups_sortcolumn="1"
               groups_sortmode="down"
               ;;
            esac 
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${groups_sortcolumn}" -o "$oldmode" != "${groups_sortmode}" ]
        then
            groups_readdata      "$win"
        fi
    fi
}


#============================================================================
# groups module (module functions called from userman.cui.sh)
#============================================================================
#----------------------------------------------------------------------------
# groups module
#----------------------------------------------------------------------------

groups_menu="Unix groups"
groups_sortcolumn="-1"
groups_sortmode="up"


#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# groups_listview_clicked_hook
# listitem has been clicked
# expects: $p1 : window handle of parent window
#          $p2 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------

function groups_listview_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local menu
    local result
    local item
    local dlg

    cui_menu_new "$win" "Options" 0 0 27 14 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Edit entry"        1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_additem      "$menu" "Create new entry"  3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Edit members"      4
        cui_menu_additem      "$menu" "Sort by column"    5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"  6
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
                if groups_editgroup_dialog $win
                then
                    groups_readdata $win
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if groups_deletegroup_dialog $win
                then
                    groups_readdata "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if groups_creategroup_dialog $win
                then
                    groups_readdata "$win"
                fi
                ;;
            4)
                cui_window_destroy "$menu"
                if groups_editmembers_dialog $win
                then
                    groups_readdata "$win"
                fi
                ;;
            5)
                cui_window_destroy  "$menu"
                groups_select_sort_column $win
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
#  groups_list_postkey_hook (catch ENTER key)      
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------

function groups_list_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"
    
    if [ "$key" == "${KEY_ENTER}" ]
    then
        groups_listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
    fi
}

#----------------------------------------------------------------------------
# groups_init (init the grous module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function groups_init()
{
    local win="$1"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 3 "${IDC_GROUPS_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setcolors    "$ctrl" "WINDOW"
        cui_listview_setcoltext "$ctrl" 0 " Group "
        cui_listview_setcoltext "$ctrl" 1 "  Gid  " 
        cui_listview_setcoltext "$ctrl" 2 " Additional Members "
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED"  "$win" groups_listview_clicked_hook
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" groups_list_postkey_hook
        cui_window_create "$ctrl"
    fi
    
    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_wordwrap "$ctrl" 1
        cui_textview_add "$ctrl" "CREATE (F7), EDIT (F4) and DELETE (F8) user groups. Note that \
you can change the way the list is sorted by pressing the F9 key. \
If the group shall be populated with member users, this can be \
changed by pressing F5 key."
        cui_window_totop "$ctrl"
    fi
    
    cui_window_setlstatustext "$win" "Commands: F4=Edit F5=Members F7=Create F8=Delete F9=Sort F10=Exit"
}

#----------------------------------------------------------------------------
# groups_close (close the groups module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function groups_close()
{
    local win="$1"
    local ctrl

    cui_window_getctrl "$win" "${IDC_GROUPS_LIST}" && ctrl="$p2"
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
# groups_size (resize the groups module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------

function groups_size()
{
    cui_window_getctrl "$1" "${IDC_GROUPS_LIST}"
    if cui_valid_handle "$p2"
    then
        cui_window_move "$p2" "$2" "$3" "$4" "$5"
    fi        
}

#----------------------------------------------------------------------------
# groups_readdata (read data of the groups module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function groups_readdata()
{
    local ctrl
    local win="$1"
    local sel;  
    local count;
    local index;
 
    # read user inforamtion
    cui_window_getctrl "$win" "$IDC_GROUPS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel   "$ctrl" && sel="$p2"
        cui_listview_clear    "$ctrl"

        sys_groups_tolist     "$ctrl" "$GROUPS_SHOW_ALL" ""

        cui_listview_getcount "$ctrl" && count="$p2"

        if [ "$sel" -ge "0" -a "$count" -gt "0" ]
        then
            if [ "$sel" -ge "$count" ]
            then
                sel=$[$count - 1]
            fi
            groups_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            groups_sort_list    "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi        
    fi
}

#----------------------------------------------------------------------------
# groups_activate (activate the groups module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function groups_activate()
{
    local ctrl
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_GROUPS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setfocus "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# groups_key (handle keyboard input)         
#    $1 --> window handle of main window
#    $2 --> keyboard input
#----------------------------------------------------------------------------

function groups_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F4")
        if groups_editgroup_dialog $win
        then
            groups_readdata $win
        fi
        return 0
        ;;
    "$KEY_F5")
        if groups_editmembers_dialog $win
        then
            groups_readdata "$win"
        fi
        ;;
    "$KEY_F7")
        if groups_creategroup_dialog $win
        then
            groups_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if groups_deletegroup_dialog $win
        then
            groups_readdata $win
        fi
        return 0
        ;;      
    "$KEY_F9")
        groups_select_sort_column $win
        return 0  
        ;;
    esac        

    return 1
} 
 
#============================================================================
# end of groups module
#============================================================================

