#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/vsftpd-user.cui.sh - virtual user management for vsftpd
#
# Creation:     2013-07-04 jv
#
# Copyright (c) 2001-2016 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/pwdfilelib-2

#----------------------------------------------------------------------------
# global constants
#----------------------------------------------------------------------------
IDC_MENU='10'                    # menu ID
IDC_INFOTEXT='11'                # info text ID
IDC_LISTVIEW='12'                # package list ID

IDC_INPUTDLG_BUTOK='10'          # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'      # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'        # dlg edit ID

IDC_USERSDLG_BUTOK='30'
IDC_USERSDLG_BUTCANCEL='31'
IDC_USERSDLG_LABEL1='32'
IDC_USERSDLG_LABEL4='33'
IDC_USERSDLG_LABEL5='34'
IDC_USERSDLG_LABEL6='35'
IDC_USERSDLG_LABEL7='36'
IDC_USERSDLG_EDLOGIN='40'
IDC_USERSDLG_EDPASS1='41'
IDC_USERSDLG_EDPASS2='42'
IDC_USERSDLG_CHUSER='43'
IDC_USERSDLG_CHROOT='44'

lastsection="?"
passwdfile="/etc/vsftpd/passwd"
keyword=""

#============================================================================
# help routines
#============================================================================
function write_user_config()
{
    [ -z "$usersdlg_chuser" ] && usersdlg_chuser="apache"
    [ -z "$usersdlg_chroot" ] && usersdlg_chroot="/var/www"
    mkdir -p /etc/vsftpd/users
    {
        echo "guest_username=$usersdlg_chuser"
        echo "local_root=$usersdlg_chroot"
        echo "dirlist_enable=YES"
        echo "download_enable=YES"
        echo "write_enable=YES"
    } > /etc/vsftpd/users/${usersdlg_userlogin}
}


function read_user_config()
{
    if [ -f /etc/vsftpd/users/${usersdlg_userlogin} ]
    then
        . /etc/vsftpd/users/${usersdlg_userlogin}
        usersdlg_chuser="$guest_username"
        usersdlg_chroot="$local_root"
        return 0
    else
        return 1
    fi
}


#============================================================================
# general routines
#============================================================================

#----------------------------------------------------------------------------
# read packages and transfer them to list
# $1 --> mainwin window handle
#----------------------------------------------------------------------------

function load_data()
{
    local win="$1"
    local list
    local sel
    local count
    local n=0

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && list="$p2"
    if cui_valid_handle "$list"
    then
        cui_listview_getsel    "$list" && sel="$p2"
        cui_listview_clear     "$list"

        # transfer data into list view
        pwdfile_users_tolist   "$list" "$passwdfile" "$keyword"
        cui_listview_getcount  "$list" && count="$p2"
        while [ $n -lt $count ]
        do
            usersdlg_userlogin=""
            cui_listview_gettext "$list" "$n" "0" && usersdlg_userlogin="$p2"
            if read_user_config
            then
                cui_listview_settext "$list" "$n" "1" "$usersdlg_chuser"
                cui_listview_settext "$list" "$n" "2" "$usersdlg_chroot"
            fi
            n=$[ $n + 1 ]
        done
                
        cui_listview_update    "$list"
        if [ -z "$keyword" ]
        then
            cui_listview_alphasort "$list" "0" "1"
            cui_listview_getcount   "$list" && count="$p2"                   
            if [ "$sel" -lt "$count" ]
            then
                cui_listview_setsel "$list" "$sel"
            elif [ "$count" -gt 0 ]
            then
                cui_listview_setsel "$list" $[$count -1]
            else
                cui_listview_setsel "$list" "0"
            fi
        else
            cui_window_settext     "$list" "Search='$keyword'"
        fi 
    fi
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
    cui_window_getctrl "$win" "$IDC_USERSDLG_CHUSER" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_chuser="$p2"
    fi
    cui_window_getctrl "$win" "$IDC_USERSDLG_CHROOT" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_edit_gettext "$ctrl"
        usersdlg_chroot="$p2"
    fi
    
    if [ -z "${usersdlg_userlogin}" ]
    then
        cui_message "$win" "No login name entered! Please enter a valid name" \
                           "Missing data" "$MB_ERROR"
        cui_return 1
        return
    fi

    if [ -z "$usersdlg_userpass1" ]
    then
        cui_message "$win" "Password is not set. Please enter password!" \
                           "Missing Password" "$MB_ERROR"
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
    cui_label_new "$dlg" "New password:" 2 3 14 1 $IDC_USERSDLG_LABEL4 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Reenter pw.:" 2 5 14 1 $IDC_USERSDLG_LABEL5 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Chuser name:" 2 7 14 1 $IDC_USERSDLG_LABEL6 $CWS_NONE $CWS_NONE
    if cui_valid_handle "$p2"
    then
        cui_window_create     "$p2"
    fi
    cui_label_new "$dlg" "Chroot path:" 2 9 14 1 $IDC_USERSDLG_LABEL7 $CWS_NONE $CWS_NONE
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

    cui_edit_new "$dlg" "" 17 3 18 1 40 $IDC_USERSDLG_EDPASS1 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"
        cui_edit_settext      "$ctrl" "${usersdlg_userpass1}"
    fi

    cui_edit_new "$dlg" "" 17 5 18 1 40 $IDC_USERSDLG_EDPASS2 $EF_PASSWORD $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"        
        cui_edit_settext      "$ctrl" "${usersdlg_userpass2}"
    fi

    cui_edit_new "$dlg" "" 17 7 18 1 40 $IDC_USERSDLG_CHUSER $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"        
        cui_edit_settext      "$ctrl" "${usersdlg_chuser}"
    fi

    cui_edit_new "$dlg" "" 17 9 18 1 40 $IDC_USERSDLG_CHROOT $CWS_NONE $CWS_NONE && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_create     "$ctrl"        
        cui_edit_settext      "$ctrl" "${usersdlg_chroot}"
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
    local rndval
    local keyval

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"

            usersdlg_userpass1="xxxxxxxxxxxx"
            usersdlg_userpass2="xxxxxxxxxxxx"
            local orig_userlogin="${usersdlg_userlogin}"
            read_user_config

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
                    if [ "${orig_userlogin}" = "${usersdlg_userlogin}" ]
                    then
                        if [ "$usersdlg_userpass2" = "xxxxxxxxxxxx"  ]
                        then
                            write_user_config
                        else
                            rndval=$(openssl rand -base64 9)
                            keyval=$(openssl passwd -1 -salt ${rndval} ${usersdlg_userpass1})
                            if sed -i "s|^${usersdlg_userlogin}:.*|${usersdlg_userlogin}:${keyval}|" ${passwdfile}
                            then
                                write_user_config
                                result="$IDOK"
                            else
                                cui_message "$win" "User \"${usersdlg_userlogin}\" cannot change password!" "Error" "$MB_ERROR"
                                result="$IDCANCEL"
                            fi
                        fi
                    else
                        # copy user to other name
                        grep -q "^${usersdlg_userlogin}:" ${passwdfile}
                        if [ $? == 0 ]
                        then
                            cui_message "$win" "User \"${usersdlg_userlogin}\" already exists!" "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        fi
                        if [ "$usersdlg_userpass2" = "xxxxxxxxxxxx" ] 
                        then
                            cui_message "$win" "User \"${usersdlg_userlogin}\" cannot set new password!" "Error" "$MB_ERROR"
                            result="$IDCANCEL"
                        fi                        
                        if [ "$result" = "$IDOK" ]
                        then
                            rndval=$(openssl rand -base64 9)
                            keyval=$(openssl passwd -1 -salt ${rndval} ${usersdlg_userpass1})
                            echo "${usersdlg_userlogin}:${keyval}" >> ${passwdfile}
                            write_user_config
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
    local rndval
    local keyval
    local nret=1

    usersdlg_userlogin=""
    usersdlg_userpass1=""
    usersdlg_userpass2=""
    usersdlg_chuser="apache"
    usersdlg_chroot="/var/www"
    
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
            if [ "$usersdlg_userpass1"  = "xxxxxxxxxxxx"  ]
            then
                cui_message "$win" "Password is not set. Please enter password!" \
                           "Missing Password" "$MB_ERROR"
                cui_return 1
            else
                if ! grep -q -e "^${usersdlg_userlogin}:" ${passwdfile}
                then
                    rndval=$(openssl rand -base64 9)
                    keyval=$(openssl passwd -1 -salt ${rndval} ${usersdlg_userpass1})
                    echo "${usersdlg_userlogin}:${keyval}" >> ${passwdfile}
                    write_user_config
                    nret=0
                fi    
            fi
        fi
        cui_window_destroy "$dlg"
    fi
    return $nret
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

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_getsel "$ctrl" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$ctrl" "$index" "0" && usersdlg_userlogin="$p2"

            cui_message "$win" "Delete user \"${usersdlg_userlogin}\" too?" "Question" "${MB_YESNO}"
            if [ "$p2" == "$IDYES" ]
            then
                if sed -i "/^${usersdlg_userlogin}:.*/d" ${passwdfile}
                then
                    rm -f  /etc/vsftpd/users/${usersdlg_userlogin}
                    return 0
                else
                    return 1
                fi
                return 1
            fi
        fi
    fi
    return 1
}

#============================================================================
# data input dialog
#============================================================================

#----------------------------------------------------------------------------
# inputdlg_ok_clicked
# Ok button clicked hook
# expects: $p2 : window handle of dialog window
#          $p3 : button control id
# returns: 1   : event handled
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
        cui_edit_settext      "$ctrl" "${inputdlg_value}"
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
# popup menu callbacks
#============================================================================

#----------------------------------------------------------------------------
# popup_menu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function popup_menu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# popup_menu_escape_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function popup_menu_escape_hook()
{
    cui_window_close "$p3" "$IDCANCEL"
    cui_return 1
}
 
#----------------------------------------------------------------------------
# popup_menu_postkey_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function popup_menu_postkey_hook()
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
# section menu callbacks
#============================================================================

#----------------------------------------------------------------------------
# menu_clicked_hook (menu selection by user)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function menu_clicked_hook()
{
    local win="$p2"
    local ctrl

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setfocus "$ctrl"
    fi
    cui_return 1
}


#============================================================================
# listview callbacks
#============================================================================

#----------------------------------------------------------------------------
# listview_clicked_hook
# listitem has been clicked
# expects: $p2 : window handle of parent window
#          $p3 : control id
# returns: 1   : event handled
#----------------------------------------------------------------------------

function listview_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local menu
    local result
    local item
    local dlg

    cui_menu_new "$win" "Options" 0 0 30 13 1 "$[$CWS_CENTERED + $CWS_POPUP]" "$CWS_NONE" && menu="$p2"
    if cui_valid_handle $menu
    then
        cui_menu_additem      "$menu" "Edit entry"              1
        cui_menu_additem      "$menu" "Delete entry"            2
        cui_menu_additem      "$menu" "Create new entry"        3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Search filter"           5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"        6
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu"              0
        cui_menu_selitem      "$menu"                           1

        cui_menu_callback     "$menu" "$MENU_CLICKED" "$win" "popup_menu_clicked_hook"
        cui_menu_callback     "$menu" "$MENU_ESCAPE"  "$win" "popup_menu_escape_hook"
        cui_menu_callback     "$menu" "$MENU_POSTKEY" "$win" "popup_menu_postkey_hook"

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
                    load_data "$win"
                fi
                ;;
            2)
                cui_window_destroy  "$menu"
                if users_deleteuser_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            3)
                cui_window_destroy  "$menu"
                if users_createuser_dialog $win
                then
                    load_data "$win"
                fi
                ;;
            5)
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

    if [ "$key" == "${KEY_ENTER}" ]
    then
        listview_clicked_hook "$win" "$ctrl"
    else
        cui_return 0
    fi
}


#============================================================================
# main window callbacks
#============================================================================

#----------------------------------------------------------------------------
# mainwin_create_hook (for creation of child windows)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_create_hook()
{
    local win="$p2"
    local ctrl

    cui_listview_new "$win" "" 0 0 30 10 3 "${IDC_LISTVIEW}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "Login username"
        cui_listview_setcoltext "$ctrl" 1 "Guest username"
        cui_listview_setcoltext "$ctrl" 2 "chroot path"

        cui_listview_settitlealignment "$ctrl" 0 "${ALIGN_LEFT}"

        cui_listview_callback   "$ctrl" "$LISTVIEW_CLICKED" "$win" listview_clicked_hook
        cui_listview_callback   "$ctrl" "$LISTVIEW_POSTKEY" "$win" listview_postkey_hook
        cui_window_create "$ctrl"
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
    load_data "$win"
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
    "$KEY_F2")
        load_data "$win"
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
        if users_edituser_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F7")
        if users_createuser_dialog $win
        then
            load_data "$win"
        fi
        ;;
    "$KEY_F8")
        if users_deleteuser_dialog $win
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
    local win="$p2"

    cui_getclientrect "$win"
    local x="$p2"
    local y="$p3"
    local w="$p4"
    local h="$p5"

    cui_window_getctrl "$win" "$IDC_LISTVIEW"
    if cui_valid_handle "$p2"
    then
        cui_window_move "$p2" "0" "0" "$w" "$h"
    fi

    cui_return 1
}


#============================================================================
# shellrun entry function
#============================================================================

#----------------------------------------------------------------------------
# init routine (entry point of all shellrun.cui based programs)
#    $p2 --> desktop window handle
#----------------------------------------------------------------------------

function init()
{
    local win="$p2"

    # initialize shell extension library
    pwdfile_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load pwdfile shellrun extension!" "Error" "$MB_ERROR"
        cui_return 0
        return
    fi

    cui_window_new "$win" 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED] && mainwin="$p2"
    if cui_valid_handle "$mainwin"
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "vsFTPd user"
        cui_window_setlstatustext "$mainwin" "Commands: F3=Search F4=Edit F7=Create F8=Delete F10=Exit"
        cui_window_setrstatustext "$mainwin" "V1.0.0"
        cui_window_sethook        "$mainwin" "$HOOK_CREATE"  mainwin_create_hook
        cui_window_sethook        "$mainwin" "$HOOK_INIT"    mainwin_init_hook
        cui_window_sethook        "$mainwin" "$HOOK_KEY"     mainwin_key_hook
        cui_window_sethook        "$mainwin" "$HOOK_SIZE"    mainwin_size_hook
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
