#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/userman.cui.users.module.sh - users module for eisfair user mananger
#
# Creation:     2008-03-09 dv
# Last update:  $Id: userman.cui.users.module.sh 31617 2012-09-17 12:29:15Z dv $
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
IDC_USERS_LIST='12'

IDC_USERSDLG_BUTOK='10'
IDC_USERSDLG_BUTCANCEL='11'
IDC_USERSDLG_LABEL1='12'
IDC_USERSDLG_LABEL2='13'
IDC_USERSDLG_LABEL3='14'
IDC_USERSDLG_LABEL4='15'
IDC_USERSDLG_LABEL5='16'
IDC_USERSDLG_EDLOGIN='20'
IDC_USERSDLG_EDNAME='21'
IDC_USERSDLG_EDPASS1='22'
IDC_USERSDLG_EDPASS2='23'
IDC_USERSDLG_CBGROUP='24'

IDC_ADDGROUPS_BUTOK='10'
IDC_ADDGROUPS_BUTCANCEL='11'
IDC_ADDGROUPS_LSTALL='12'
IDC_ADDGROUPS_LSTSEL='13'
IDC_ADDGROUPS_BUTADD='14'
IDC_ADDGROUPS_BUTREMOVE='15'


#============================================================================
# helper functions for user management
#============================================================================

#----------------------------------------------------------------------------
# users_get_additional_groups
# expects: user name in ${usersdlg_userlogin}
# returns: group list in ${addgroupsdlg_groups} 
#----------------------------------------------------------------------------

function users_get_additional_groups()
{
    local oldifs="$IFS"
    local line
    IFS=':'
    
    addgroupsdlg_groups=""
    
    while read line
    do
        set -- $line
        local g="$1"
        local u="$4"
        local j
                                                    
        IFS=','
        set -- $u

        for j in $*
        do
            if [ "$j" = "${usersdlg_userlogin}" ]
            then
                addgroupsdlg_groups="${addgroupsdlg_groups} $g"
                break
            fi
        done
        IFS=':'
    done </etc/group
    
    IFS="$oldifs"
}

#----------------------------------------------------------------------------
# users_create_uid
# expects: nothing
# returns: next free uid in ${usersdlg_useruid} 
#----------------------------------------------------------------------------

function users_create_uid()
{
   local oldifs="$IFS"
   IFS=':'     
   usersdlg_useruid=2000
   while read line
   do
       set -- $line
       if [ $3 -gt ${usersdlg_useruid} -a $3 -lt 3000 ]
       then
           usersdlg_useruid=$3
       fi
   done </etc/passwd
   IFS="$oldifs"

   usersdlg_useruid=$[${usersdlg_useruid} + 1]
}

#----------------------------------------------------------------------------
# users_get_gid
# expects: name of group in ${usersdlg_usergroup}
# returns: group id in ${usersdlg_usergid}
#----------------------------------------------------------------------------

function users_get_gid()
{
   oldifs="$IFS"
   IFS=':'     
   usersdlg_usergid=100
   while read line
   do
       set -- $line
       if [ "$1" == "${usersdlg_usergroup}" ]
       then
           usersdlg_usergid="$3"
       fi
   done </etc/group
   IFS="$oldifs"
} 

#----------------------------------------------------------------------------
# check if password is valid
# input : $1 - user name
# return:  0 - valid password
#          1 - invalid password
#----------------------------------------------------------------------------

function users_is_valid_pw()
{
    local ret=1
    local user=$1
        
    if [ "$user" != "" ]
    then
        pword=`grep "^$user:" /etc/shadow|cut -d: -f2`

        [ "$pword" != "*" ] && ! echo "$pword"|grep -q "^!"
                                
        if [ $? -eq 0 ] 
        then
            ret=0   
        fi
    fi

    return $ret
}

#============================================================================
# usersdlg - dialog to create and edit users
#============================================================================

#----------------------------------------------------------------------------
# usersdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function usersdlg_ok_clicked()
{
    local win="$p2"
    local ctrl
    local index
    
    cui_window_getctrl "$win" "$IDC_USERSDLG_EDLOGIN" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_userlogin="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_USERSDLG_EDNAME" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_username="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_USERSDLG_EDPASS1" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_userpass1="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_USERSDLG_EDPASS2" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_userpass2="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_USERSDLG_CBGROUP" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_combobox_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_combobox_get "$ctrl" "$index"
            usersdlg_usergroup="$p2"
        else
            cui_message "$win" "No user group selected! Please select a valid group" \
                               "Missing data" "$MB_ERROR"
            cui_return 1
            return        
        fi
    fi

    if [ -z "${usersdlg_userlogin}" ]
    then
        cui_message "$win" "No login name entered! Please enter a valid name" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi
    
    if [ "${usersdlg_userpass1}" != "${usersdlg_userpass2}" ]
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
# usersdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function usersdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}
                        
#----------------------------------------------------------------------------
# usersdlg_create_hook
# Dialog create hook - create dialog controls
# expects: $1 : window handle of dialog window
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function usersdlg_create_hook()
{
    local dlg="$p2"
    local ctrl

    cui_label_new "$dlg" "Login name:" 2 1 14 1 $IDC_USERSDLG_LABEL1 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Real name:" 2 3 14 1 $IDC_USERSDLG_LABEL2 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Group:" 2 5 14 1 $IDC_USERSDLG_LABEL3 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi    
    cui_label_new "$dlg" "New password:" 2 7 14 1 $IDC_USERSDLG_LABEL4 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Reenter pw.:" 2 9 14 1 $IDC_USERSDLG_LABEL5 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi

    cui_edit_new "$dlg" "" 17 1 18 1 40 $IDC_USERSDLG_EDLOGIN $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl" 
        cui_edit_settext      "$ctrl" "${usersdlg_userlogin}"
    fi
    cui_edit_new "$dlg" "" 17 3 18 1 40 $IDC_USERSDLG_EDNAME $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${usersdlg_username}"
    fi
    cui_combobox_new "$dlg" 17 5 12 10 $IDC_USERSDLG_CBGROUP $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        _ifs="$IFS"
        while read line
        do
            IFS=':'
            set -- $line
            cui_combobox_add      "$ctrl" "$1"
            IFS="$_ifs"
        done < /etc/group        
        cui_combobox_select   "$ctrl" "${usersdlg_usergroup}"        
        cui_window_create     "$ctrl"
    fi
    cui_edit_new "$dlg" "" 17 7 18 1 40 $IDC_USERSDLG_EDPASS1 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${usersdlg_userpass1}"
    fi
    cui_edit_new "$dlg" "" 17 9 18 1 40 $IDC_USERSDLG_EDPASS2 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"        
        cui_edit_settext      "$ctrl" "${usersdlg_userpass2}"
    fi
        
    cui_button_new "$dlg" "&OK" 10 11 10 1 $IDC_USERSDLG_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" usersdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
                                    
    cui_button_new "$dlg" "&Cancel" 21 11 10 1 $IDC_USERSDLG_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" usersdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi
                                                                        
    cui_return 1
}
             
#============================================================================
# addgroupsdlg - dialog to manage additional groups
#============================================================================
             
#----------------------------------------------------------------------------
# addgroupsdlg_butadd_clicked
# button or listbox clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------
             
function addgroupsdlg_butadd_clicked()
{
    local win="$p2"
    local lstall
    local lstsel
    local index
    local newindex
    
    cui_window_getctrl "$win" "$IDC_ADDGROUPS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$win" "$IDC_ADDGROUPS_LSTSEL" && lstsel="$p2"
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
# addgroupsdlg_butrem_clicked
# button or listbox clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function addgroupsdlg_butrem_clicked()
{
    local win="$p2"
    local lstall
    local lstsel
    local index
    local newindex
    
    cui_window_getctrl "$win" "$IDC_ADDGROUPS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$win" "$IDC_ADDGROUPS_LSTSEL" && lstsel="$p2"
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
# addgroupsdlg_ok_clicked
# Ok button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled
#----------------------------------------------------------------------------

function addgroupsdlg_ok_clicked()
{
    local dlg="$p2"
    local lstsel
    local count
    local index
    
    addgroupsdlg_groups=""
    
    cui_window_getctrl "$dlg" "$IDC_ADDGROUPS_LSTSEL" && lstsel="$p2"
    if cui_valid_handle "$lstsel"
    then
        count=0
        index=0
        
        cui_listbox_getcount "$lstsel"  && count="$p2"
        
        while [ "$index" -lt "$count" ]
        do
            cui_listbox_get "$lstsel" "$index"
            
            if [ -z "${addgroupsdlg_groups}" ]
            then
                addgroupsdlg_groups="$p2"
            else
                addgroupsdlg_groups="${addgroupsdlg_groups},$p2"
            fi
            
            index=$[$index + 1]
        done
    fi    

    cui_window_close "$dlg" "$IDOK"
    cui_return 1
}
                
#----------------------------------------------------------------------------
# addgroupsdlg_cancel_clicked
# Cancel button clicked hook
# expects: $1 : window handle of dialog window
#          $2 : button control id
# returns: 1  : event handled     
#----------------------------------------------------------------------------

function addgroupsdlg_cancel_clicked()
{
    cui_window_close "$p2" "$IDCANCEL"
    cui_return 1
}

#----------------------------------------------------------------------------
# addgroupsdlg_create_hook
# Create controls for additional groups dialog
# expects: $1 : window handle of dialog window
# returns: 1  : event handled     
#----------------------------------------------------------------------------
             
function addgroupsdlg_create_hook()
{
    local dlg="$p2"
    local ctrl
    local lstall
    local lstsel

    cui_listbox_new "$dlg" "Unselected" 2 1 17 10 $IDC_ADDGROUPS_LSTALL $LB_SORTED $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listbox_callback  "$ctrl" "$LISTBOX_CLICKED" "$dlg" addgroupsdlg_butadd_clicked
        cui_window_create     "$ctrl"
    fi

    cui_button_new "$dlg" "&>" 20 3 5 1 $IDC_ADDGROUPS_BUTADD $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" addgroupsdlg_butadd_clicked
        cui_window_create     "$ctrl"    
    fi

    cui_button_new "$dlg" "&<" 20 5 5 1 $IDC_ADDGROUPS_BUTREMOVE $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" addgroupsdlg_butrem_clicked
        cui_window_create     "$ctrl"    
    fi

    cui_listbox_new "$dlg" "Selected" 26 1 17 10 $IDC_ADDGROUPS_LSTSEL $LB_SORTED $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listbox_callback  "$ctrl" "$LISTBOX_CLICKED" "$dlg" addgroupsdlg_butrem_clicked
        cui_window_create     "$ctrl"
    fi

    cui_label_new  "$dlg" "Tip: use Space-key to select!" 2 11 30 1 0 $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"  
    then
        cui_window_create     "$ctrl"
    fi
                        
    cui_button_new "$dlg" "&OK" 10 13 10 1 $IDC_ADDGROUPS_BUTOK $CWS_DEFOK $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" addgroupsdlg_ok_clicked
        cui_window_create     "$ctrl"
    fi
                                    
    cui_button_new "$dlg" "&Cancel" 26 13 10 1 $IDC_ADDGROUPS_BUTCANCEL $CWS_DEFCANCEL $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" addgroupsdlg_cancel_clicked
        cui_window_create     "$ctrl"
    fi

    cui_window_getctrl "$dlg" "$IDC_ADDGROUPS_LSTALL" && lstall="$p2"
    if cui_valid_handle "$lstall"
    then
        cui_window_getctrl "$dlg" "$IDC_ADDGROUPS_LSTSEL" && lstsel="$p2"
        if cui_valid_handle "$lstsel"
        then
            _ifs="$IFS"
            while read line
            do
                IFS=':'
                set -- $line
                IFS="$_ifs"

                # search group
                local found=0                
                for group in ${addgroupsdlg_groups}
                do
                    if [ "$group" == "$1" ]
                    then
                        found=1
                        break
                    fi
                done
                
                # add group
                if [ $found == 1 ]
                then
                    cui_listbox_add "$lstsel" "$1"
                else
                    cui_listbox_add "$lstall" "$1"
                fi                
            done < /etc/group 
            
            cui_listbox_setsel "$lstsel" "0"
            cui_listbox_setsel "$lstall" "0"
            cui_window_setfocus "$lstall"
        fi                
    fi
                                                                        
    cui_return 1            
}             
             
#============================================================================
# functions to create modify or delete users (using usersdlg and addgroupsdlg)
#============================================================================

#----------------------------------------------------------------------------
# users_addgroups_dialog
# Modify additional groups a user is member of
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function users_addgroups_dialog()
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
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"            
            users_get_additional_groups

            cui_window_new "$win" 0 0 47 17 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg"
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Additional Groups"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  addgroupsdlg_create_hook
                cui_window_create    "$dlg"
        
                cui_window_modal   "$dlg" && result="$p2"
                if [ "$result" == "$IDOK" ]
                then
                    local errmsg=$(/usr/sbin/adduser -G "${addgroupsdlg_groups}" "${usersdlg_userlogin}" 2>&1)
                    if [ "$?" != "0" ]
                    then
                        cui_message "$win" \
                             "Error! $errmsg!" "Error" "$MB_ERROR"
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
# users_edituser_dialog
# Modify the user entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function users_edituser_dialog()
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
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"
            cui_listview_gettext "$ctrl" "$index" "2" && usersdlg_usergroup="$p2"
            cui_listview_gettext "$ctrl" "$index" "5" && usersdlg_username="$p2"
            
            usersdlg_userpass1="xxxxxxxxxxxx"
            usersdlg_userpass2="xxxxxxxxxxxx"
            
            local orig_userlogin="${usersdlg_userlogin}"
            local orig_username="${usersdlg_username}"
            local orig_usergroup="${usersdlg_usergroup}"

            cui_window_new "$win" 0 0 40 15 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
            if cui_valid_handle "$dlg" 
            then
                cui_window_setcolors "$dlg" "DIALOG"
                cui_window_settext   "$dlg" "Edit User"
                cui_window_sethook   "$dlg" "$HOOK_CREATE"  usersdlg_create_hook
                cui_window_create    "$dlg"
        
                cui_window_modal   "$dlg" && result="$p2"
                if  [ "$result" == "$IDOK" ]
                then
                    if [ "${orig_userlogin}" != "${usersdlg_userlogin}" ]
                    then                
                        grep "^${usersdlg_userlogin}:" /etc/passwd >/dev/null  
                        if [ $? == 0 ]
                        then
                            cui_message "$win" \
                                "User \"${usersdlg_userlogin}\" already exists!" \
                                "Error" "$MB_ERROR"
                            result="$IDCANCEL"                        
                        fi
                    fi
                fi
                if  [ "$result" == "$IDOK" ]
                then
                    local args=""
                    
                    if [ "${orig_userlogin}" != "${usersdlg_userlogin}" ]
                    then
                        args="$args -l \"${usersdlg_userlogin}\""
                        args="$args -h \"/home/${usersdlg_userlogin}\" -m"
                    fi
                    
                    if [ "${orig_username}" != "${usersdlg_username}" ]
                    then
                        args="$args -g \"${usersdlg_username}\""
                    fi
                    
                    if [ "${orig_usergroup}" != "${usersdlg_usergroup}" ]
                    then
                        args="$args -G \"${usersdlg_usergroup}\""
                    fi
                    
                    if [ ! -z "$args" ]
                    then
                        args="$args \"${orig_userlogin}\""

                        errmsg=$(eval /usr/sbin/adduser $args 2>&1)
                        if [ "$?" != "0" ]
                        then
                            cui_message "$win" \
                                "Error! $errmsg" "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        else
                            if [ "${usersdlg_userpass1}" != "xxxxxxxxxxxx" ]
                            then
                                errmsg=`(echo "${usersdlg_userpass1}"; echo "${usersdlg_userpass1}") | \
                                     passwd "${usersdlg_userlogin}" 2>&1`
                                if [ "$?" != "0" ]
                                then
                                    cui_message "$win" \
                                         "Error! $errmsg" "Error" "$MB_ERROR"
                                fi
                            fi  
                        fi
                    else  
                        if [ "${usersdlg_userpass1}" != "xxxxxxxxxxxx" ]
                        then
                            errmsg=`(echo "${usersdlg_userpass1}"; echo "${usersdlg_userpass1}") | \
                                passwd "${usersdlg_userlogin}" 2>&1`
                            if [ "$?" != "0" ]
                            then
                                cui_message "$win" \
                                    "Error! $errmsg" "Error" "$MB_ERROR"
                                result="$IDCANCEL"
                            fi
                        else  
                            result="$IDCANCEL"
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
# users_createuser_dialog
# Create a new user entry
# returns: 0  : created (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------
              
function users_createuser_dialog()
{
    local win="$1"
    local result="$IDCANCEL"
    local dlg
    
    usersdlg_userlogin=""
    usersdlg_username=""
    usersdlg_usergroup="users"
    usersdlg_userpass1=""
    usersdlg_userpass2=""

    cui_window_new "$win" 0 0 40 15 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED] && dlg="$p2"
    if cui_valid_handle "$dlg"
    then
        cui_window_setcolors "$dlg" "DIALOG"
        cui_window_settext   "$dlg" "Create User"        
        cui_window_sethook   "$dlg" "$HOOK_CREATE"  usersdlg_create_hook
        cui_window_create    "$dlg"
        
        cui_window_modal     "$dlg" && result="$p2"
        
        if  [ "$result" == "$IDOK" ]
        then
            grep "^${usersdlg_userlogin}:" /etc/passwd >/dev/null  
            if [ $? != 0 ]
            then            
                users_create_uid
                #users_get_gid

                errmsg=$(/usr/sbin/adduser \
                    -u "${usersdlg_useruid}" \
                    -G "${usersdlg_usergroup}" \
                    -g "${usersdlg_username}" \
                    -s "/bin/bash" \
                    -h "/home/${usersdlg_userlogin}" -m \
                    ${usersdlg_userlogin} 2>&1)
                    
                if [ "$?" != "0" ]
                then
                    cui_message "$win" \
                        "Error! $errmsg" "Error" "$MB_ERROR"
                    result="$IDCANCEL"
                else
                    errmsg=`(echo "${usersdlg_userpass1}"; echo "${usersdlg_userpass1}") | \
                        passwd "${usersdlg_userlogin}" 2>&1`
                    if [ "$?" != "0" ]
                    then
                        cui_message "$win" \
                            "Error! $errmsg" "Error" "$MB_ERROR"
                    fi
                fi
            else
                cui_message "$win" \
                    "User \"${usersdlg_userlogin}\" already exists!" \
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
# users_deleteuser_dialog
# Remove the user entry that has been selected in the list view
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function users_deleteuser_dialog()
{
    local win="$1"
    local ctrl
    local index
    local result

    cui_window_getctrl "$win" "$IDC_USERS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"

            cui_message "$win" "Delete home of user \"${usersdlg_userlogin}\" too?" "Question" "${MB_YESNOCANCEL}"
            if [ "$p2" == "$IDYES" -o "$p2" == "$IDNO" ]
            then
                result=$(/usr/sbin/deluser ${usersdlg_userlogin})
                [ "$p2" == "$IDYES" ] && rm -rf /home/${usersdlg_userlogin}
                if [ "$?" == 0 ]
                then
                    return 0
                else
                    if [ "$result" == "" ]
                    then
                        cui_message "$win" "Error: user can't be deleted" "Error" "$MB_ERROR"
                    else
                        cui_message "$win" "$result" "Error" "$MB_ERROR"
                    fi
                    return 1
                fi
                
                return 1
            fi
        fi
    fi
    
    return 1
}

#----------------------------------------------------------------------------
# users_invalidate_passwd
# Invalidate users password (hence locking access)
# returns: 0  : modified (reload data)
#          1  : not modified (don't reload data)
#----------------------------------------------------------------------------

function users_invalidate_passwd()
{
    local win="$1"
    local ctrl
    local index

    cui_window_getctrl "$win" "$IDC_USERS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index" 
        then
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"

            if users_is_valid_pw "${usersdlg_userlogin}"
            then
                passwd -l "${usersdlg_userlogin}"
                case "$?" in
                0) return 0
                   ;;
                *) cui_message "$win" "Error: failed to invalidate passwd" "Error" "$MB_ERROR"
                   return 1
                   ;;
                esac
                
                return 1
            fi
        fi
    fi
    
    return 1
}

#============================================================================
# functions to sort the list view control and to select the sort column
#============================================================================

#----------------------------------------------------------------------------
# users_sort_list
# Sort the list view control by the column specified in users_sortcolumn
# expects: $1 : listview window handle
# returns: nothing
#----------------------------------------------------------------------------

function users_sort_list()
{
    local ctrl=$1
    local mode="0"

    if [ "${users_sortcolumn}" != "-1" ]
    then
        if [ "${users_sortmode}" == "up" ]
        then
            mode="1"
        fi

        if [ "${users_sortcolumn}" == "1" -o "${users_sortcolumn}" == "3" ]
        then
            cui_listview_numericsort "$ctrl" "${users_sortcolumn}" "$mode"
        else
            cui_listview_alphasort "$ctrl" "${users_sortcolumn}" "$mode"
        fi
    fi
}

#----------------------------------------------------------------------------
# users_sortmenu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function users_sortmenu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# users_sortmenu_escape_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function users_sortmenu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}

#----------------------------------------------------------------------------
# users_sortmenu_postkey_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function users_sortmenu_postkey_hook()
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
# users_select_sort_column
# Show menu to select the sort column
# expects: $1 : base window handle
# returns: nothing
#----------------------------------------------------------------------------

function users_select_sort_column()
{
    local win="$1"
    local menu
    local result
    local item
    local oldcolumn="${users_sortcolumn}"
    local oldmode="${users_sortmode}"

    cui_menu_new "$win" "Sort column" 0 0 36 15 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_additem      "$menu" "Don't sort" 1
	cui_menu_additem      "$menu" "Sort by User  (ascending)"  2
        cui_menu_additem      "$menu" "Sort by User  (descending)" 3
	cui_menu_additem      "$menu" "Sort by Uid   (ascending)"  4
        cui_menu_additem      "$menu" "Sort by Uid   (descending)" 5
	cui_menu_additem      "$menu" "Sort by Group (ascending)"  6
        cui_menu_additem      "$menu" "Sort by Group (descending)" 7
	cui_menu_additem      "$menu" "Sort by Gid   (ascending)"  8
        cui_menu_additem      "$menu" "Sort by Gid   (descending)" 9
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu" 0
        cui_menu_selitem      "$menu" 1
        
        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" users_sortmenu_clicked_hook
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" users_sortmenu_escape_hook
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" users_sortmenu_postkey_hook

        cui_window_create     "$menu"
        cui_window_modal      "$menu" && result="$p2"
        if [ "$result" == "$IDOK" ]
        then
            cui_menu_getselitem "$menu"
            item="$p2"

            case $item in
            1) 
               users_sortcolumn="-1"
               ;;
            2) 
               users_sortcolumn="0"
               users_sortmode="up"
               ;;
            3) 
               users_sortcolumn="0"
               users_sortmode="down"
               ;;
            4) 
               users_sortcolumn="1"
               users_sortmode="up"
               ;;
            5) 
               users_sortcolumn="1"
               users_sortmode="down"
               ;;
            6) 
               users_sortcolumn="2"
               users_sortmode="up"
               ;;
            7) 
               users_sortcolumn="2"
               users_sortmode="down"
               ;;
            8) 
               users_sortcolumn="3"
               users_sortmode="up"
               ;;
            9) 
               users_sortcolumn="3"
               users_sortmode="down"
               ;;
            esac
        fi

        cui_window_destroy  "$menu"

        if [ "$oldcolumn" != "${users_sortcolumn}" -o "$oldmode" != "${users_sortmode}" ]
        then
            users_readdata      "$win"
        fi
    fi
}


#============================================================================
# users module (module functions called from userman.cui.sh)
#============================================================================
#----------------------------------------------------------------------------
# users_menu : menu text for this module
#----------------------------------------------------------------------------

users_menu="Unix users"
users_sortcolumn="-1"
users_sortmode="up"
users_max_filter="$[$USERS_HIDE_SYSTEM + $USERS_HIDE_NOBODY + $USERS_HIDE_MACHINES + $USERS_HIDE_ROOT]"
users_min_filter="$USERS_SHOW_ALL"
users_show_filter="$users_max_filter"


#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# users_listview_clicked_hook
# listitem has been clicked
# expects: $p1 : window handle of parent window
#          $p2 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------

function users_listview_clicked_hook()
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
        cui_menu_additem      "$menu" "Edit entry"        1
        cui_menu_additem      "$menu" "Delete entry"      2
        cui_menu_additem      "$menu" "Create new entry"  3
        cui_menu_additem      "$menu" "Invalidate Password" 4
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Additional groups" 5
        cui_menu_additem      "$menu" "Sort by column"    6

        if [ "$users_show_filter" == "$users_max_filter" ]
        then
            cui_menu_additem      "$menu" "Show all users" 7
        else
            cui_menu_additem      "$menu" "Show normal users" 7
        fi

        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"  8
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
                if users_edituser_dialog $win
                then
                    users_readdata $win
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if users_deleteuser_dialog $win
                then
                    users_readdata "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if users_createuser_dialog $win
                then
                    users_readdata "$win"
                fi
                ;;
            4)
                cui_window_destroy "$menu"
                if users_invalidate_passwd $win
                then
                    users_readdata "$win"
                fi
                ;;
            5)
                cui_window_destroy  "$menu"
                users_addgroups_dialog $win
                ;;
            6)
                cui_window_destroy  "$menu"
                users_select_sort_column $win
                ;;
            7)
                cui_window_destroy  "$menu"
                if [ "$users_show_filter" == "$users_min_filter" ]
                then
                    users_show_filter="$users_max_filter"
                else
                    users_show_filter="$users_min_filter"
                fi
                users_readdata $win
                ;;
            8)
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
#  users_list_postkey_hook (catch ENTER key)
#    $p2 --> window handle of main window
#    $p3 --> window handle of list control
#    $p4 --> key
#----------------------------------------------------------------------------

function users_list_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"
    
    if [ "$key" == "${KEY_ENTER}" ]
    then
        users_listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
    fi
}
             
#----------------------------------------------------------------------------
# users_init (init the users module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function users_init()
{
    local win="$1"
    local ctrl
    
    cui_listview_new "$win" "" 0 0 30 10 6 "${IDC_USERS_LIST}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setcolors    "$ctrl" "WINDOW"
        cui_listview_setcoltext "$ctrl" 0 "  User  "
        cui_listview_setcoltext "$ctrl" 1 " Uid "
        cui_listview_setcoltext "$ctrl" 2 " Group "
        cui_listview_setcoltext "$ctrl" 3 " Gid "
        cui_listview_setcoltext "$ctrl" 4 "Valid-PW"
        cui_listview_setcoltext "$ctrl" 5 "  Name  "
        cui_listview_callback   "$ctrl" "$LISTBOX_CLICKED"  "$win" users_listview_clicked_hook
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" users_list_postkey_hook
        cui_window_create "$ctrl"
    fi

    cui_window_getctrl "$win" "${IDC_HELPTEXT}" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_textview_wordwrap "$ctrl" 1
        cui_textview_add "$ctrl" "CREATE (F7), EDIT (F4) and DELETE (F8) users. Note that normally \
only regular users are displayed in the list. If you want to see \
system users too, you can toggle the view mode by pressing F3 key. \
Further you can change the way the list is sorted by pressing the F9 key." 
        cui_textview_add "$ctrl" "If the user shall be a member of additional groups, this can be \
changed by pressing F5 key."
        cui_window_totop "$ctrl"
    fi
    
    cui_window_setlstatustext "$win" "Commands: F3=Show F4=Edit F5=Groups F7=Create F8=Delete F9=Sort F10=Exit"
}

#----------------------------------------------------------------------------
# users_close (close the users module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function users_close()
{
    local win="$1"
    local ctrl
        
    cui_window_getctrl "$win" "${IDC_USERS_LIST}" && ctrl="$p2"
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
# users_size (resize the users module windows)
#    $1 --> window handle of main window
#    $2 --> x
#    $3 --> y
#    $4 --> w
#    $5 --> h
#----------------------------------------------------------------------------

function users_size()
{
    local ctrl
    
    cui_window_getctrl "$1" "$IDC_USERS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_move "$ctrl" "$2" "$3" "$4" "$5"
    fi        
}

#----------------------------------------------------------------------------
# users_readdata (read data of the users module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function users_readdata()
{
    local ctrl
    local win="$1"
    local sel;
    local count;
    local index;
    
    # read user inforamtion
    cui_window_getctrl "$win" "$IDC_USERS_LIST" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel   "$ctrl" && sel="$p2"
        cui_listview_clear    "$ctrl" 

        sys_users_tolist      "$ctrl" "$users_show_filter" ""

        cui_listview_getcount "$ctrl" && count="$p2"
        
        if [ "$sel" -ge "0" -a "$count" -gt "0" ]
        then
            if [ "$sel" -ge "$count" ]
            then
                sel=$[$count - 1]
            fi
            users_sort_list     "$ctrl"
            cui_listview_setsel "$ctrl" "$sel"
        else
            users_sort_list     "$ctrl"
            cui_listview_setsel "$ctrl" "0"
        fi        
    fi
}

#----------------------------------------------------------------------------
# users_activate (activate the users module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function users_activate()
{
    local win="$1"

    # set focus to list
    cui_window_getctrl "$win" "$IDC_USERS_LIST"
    if cui_valid_handle "$p2"
    then
        cui_window_setfocus "$p2"
    fi
}

#----------------------------------------------------------------------------
# users_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboad input
#----------------------------------------------------------------------------

function users_key()
{
    local win="$1"
    local key="$2"

    case "$key" in
    "$KEY_F3")
        if [ "$users_show_filter" == "$users_min_filter" ]
        then
            users_show_filter="$users_max_filter"
        else
            users_show_filter="$users_min_filter"
        fi
        users_readdata $win
        return 0
        ;;
    "$KEY_F4")
        if users_edituser_dialog $win
        then
            users_readdata $win
        fi
        return 0
        ;;
    "$KEY_F5")
        users_addgroups_dialog $win
        return 0
        ;;
    "$KEY_F7")
        if users_createuser_dialog $win
        then
            users_readdata $win
        fi
        return 0
        ;;
    "$KEY_F8")
        if users_deleteuser_dialog $win
        then
            users_readdata $win
        fi
        return 0
        ;; 
    "$KEY_F9")
        users_select_sort_column $win
        return 0
        ;;       
    esac
    
    return 1
}

#============================================================================
# end of users module
#============================================================================


