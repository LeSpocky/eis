#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/packages-all.cui.sh - list all packages
#
# Creation:     2013-05-01 jens vehlhaber
# Copyright (c) 2001-2015 The Eisfair Team <team@eisfair.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/apklib-2

#----------------------------------------------------------------------------
# global constants
#----------------------------------------------------------------------------
IDC_MENU='10'                    # menu ID
IDC_INFOTEXT='11'                # info text ID
IDC_LISTVIEW='12'                # package list ID

IDC_INPUTDLG_BUTOK='10'          # dlg OK button ID
IDC_INPUTDLG_BUTCANCEL='11'      # dlg Cancel button ID
IDC_INPUTDLG_EDVALUE='20'        # dlg edit ID

lastsection="?"

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
    local menu
    local list
    local index=0
    local sel
    local section
    local count

    cui_window_getctrl "$win" "$IDC_MENU" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_getselitem "$menu" && section="$p2"
    fi

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && list="$p2"
    if cui_valid_handle "$list"
    then
        cui_listview_getsel    "$list" && sel="$p2"
        cui_listview_clear     "$list"

        # transfer data into list view
        if [ -z $keyword ]
        then
            pm_packages_tolist "$list" "$section"
            cui_window_settext     "$list" ""
        else
            pm_packages_tolist "$list" "$section" "$keyword"
            cui_window_settext     "$list" "Keyword=\"$keyword\""
        fi
        cui_listview_update    "$list"

        cui_listview_getcount  "$list" && count="$p2"
        cui_window_setrtext    "$win" "packages: $count"

        # restore selection index
        if [ "$section" == "$lastsection" -a "$sel" -gt 0 ]
        then
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
            cui_listview_setsel     "$list" "0"
        fi

        lastsection=$section
    fi
}

#----------------------------------------------------------------------------
# install or upgrade a package
# $1 --> mainwin window handle
#----------------------------------------------------------------------------
function install_package()
{
    local win="$1"
    local menu
    local list
    local index=0
    local section
    local package
    local version
    local exitcode

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && list="$p2"
    if cui_valid_handle "$list"
    then
        cui_listview_getsel "$list" && index="$p2"

        if cui_valid_index "$index"
        then
            cui_listview_gettext "$list" "$index" "0" && package="$p2"
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
                cui_terminal_write    "$termwin" "Install $package ..." 1
                cui_terminal_run      "$termwin" "apk add $package && sleep 2"
            fi
        fi
    fi
}

#----------------------------------------------------------------------------
# uninstall a package
# $1 --> mainwin window handle
#----------------------------------------------------------------------------
function uninstall_package()
{
    local win="$1"
    local menu
    local list
    local index=0
    local package
    local status
    local exitcode
    local res;

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && list="$p2"
    if cui_valid_handle "$list"
    then
        cui_listview_getsel "$list" && index="$p2"

        if cui_valid_index "$index"
        then
            cui_listview_gettext "$list" "$index" "0" && package="$p2"

            pm_delpackage_tolist "$package"
            required_by="$p2"

            if [ -n "${required_by}" ]
            then
                cui_message "$win" "Package is required by the following packages:${CUINL}${CUINL}${required_by}" "Abort" "$MB_ERROR"
            else
                cui_message $win "Really uninstall package \"$package\"?" "Question" "$[$MB_YESNO + $MB_DEFBUTTON2]" && res="$p2"

                if [ "$res" == "$IDYES" ]
                then
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
#                        cui_terminal_write    "$termwin" "Deinstall $package ..." 1
                        cui_terminal_run      "$termwin" "apk del $package && sleep 2"
                    fi
                    load_data "$win"
                fi
            fi
        fi
    fi
}

#----------------------------------------------------------------------------
# show installed package info
# $1 --> mainwin window handle
#----------------------------------------------------------------------------
function show_package_info()
{
    local win="$1"
    local list
    local info
    local index
    local package
    local txt

    cui_window_getctrl "$win" "$IDC_LISTVIEW" && list="$p2"
    if cui_valid_handle $list
    then
        cui_listview_getsel "$list" && index="$p2"
        if cui_valid_index "$index"
        then
            cui_listview_gettext "$list" "$index" "0" && package="$p2"
            cui_getclientrect "$win"
            local w="$[$p4 - 4]"
            local h="$[$p5 - 2]"

            cui_textview_new "$win" "Package info" 0 0 $w $h "${IDC_INFOTEXT}" "$[$CWS_POPUP + $CWS_CENTERED]" "$CWS_NONE" && txt="$p2"
            if cui_valid_handle "$txt"
            then
                cui_textview_callback   "$txt" "${TEXTVIEW_POSTKEY}" "$win" textview_postkey_hook
                cui_window_setcolors    "$txt" "HELP"
                cui_window_create       "$txt"
                pm_info_totext "$txt" "$package"

                cui_window_modal        "$txt"
                cui_window_destroy      "$txt"
            fi
        fi
    fi
}

#============================================================================
# popup textview callback
#============================================================================

#----------------------------------------------------------------------------
# textview_postkey_hook
# check if user pressed ENTER or ESCAPE
# expects: $p2 : window handle of main window
#          $p3 : popup textview control handle
#          $p4 : key that has been pressed
# returns: 1   : event handled
#----------------------------------------------------------------------------
function textview_postkey_hook()
{
    local win="$p2"
    local ctrl="$p3"
    local key="$p4"

    case $key in
    ${KEY_ENTER})
        cui_window_close "$ctrl" "$IDOK"
        cui_return 1
        ;;
    ${KEY_F10})
        cui_window_close "$ctrl" "$IDOK"
        cui_return 1
        ;;
    *)
        cui_return 0
        ;;
    esac
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
    load_data $win

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

#----------------------------------------------------------------------------
# menu_changed_hook (menu selection changed)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------
function menu_changed_hook()
{
    load_data "$p2"
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
        cui_menu_additem      "$menu" "View package info"       1
        cui_menu_additem      "$menu" "Install package"         2
        cui_menu_additem      "$menu" "Uninstall package"       3
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Search filter"           4
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Exit application"        5
        cui_menu_addseparator "$menu"
        cui_menu_additem      "$menu" "Close menu"              0
        cui_menu_selitem      "$menu" 1

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
                show_package_info $win
                ;;
            2)
                cui_window_destroy  "$menu"
                install_package $win
                ;;
            3)
                cui_window_destroy  "$menu"
                uninstall_package $win
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

    cui_listview_new "$win" "" 0 0 30 25 6 "${IDC_LISTVIEW}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_listview_setcoltext "$ctrl" 0 "Package       "
        cui_listview_setcoltext "$ctrl" 1 "Version "
        cui_listview_setcoltext "$ctrl" 2 "Date    "
        cui_listview_setcoltext "$ctrl" 3 "Installed "
        cui_listview_setcoltext "$ctrl" 4 "Description   "
        cui_listview_setcoltext "$ctrl" 5 "Repo"

        cui_listview_settitlealignment "$ctrl" 0 "${ALIGN_LEFT}"
        cui_listview_settitlealignment "$ctrl" 1 "${ALIGN_LEFT}"
        cui_listview_settitlealignment "$ctrl" 2 "${ALIGN_LEFT}"
        cui_listview_settitlealignment "$ctrl" 3 "${ALIGN_LEFT}"
        cui_listview_settitlealignment "$ctrl" 4 "${ALIGN_LEFT}"
        cui_listview_settitlealignment "$ctrl" 5 "${ALIGN_LEFT}"

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
    local termwin

    cui_getclientrect "$win"
    local w="$p4"
    local h="$p5"
    local p="$[$h - $h / 3 + $h / 10]"

    cui_terminal_new "$win" "" "0" "$p" "$[$w - 2]" "$[$h -$p + 1]" "${IDC_TERMWIN}" "$CWS_POPUP" "$CWS_NONE" && termwin="$p2"
    if cui_valid_handle $termwin
    then
        cui_terminal_callback "$termwin" "$TERMINAL_EXIT" "$win" terminal_exit
        cui_window_create     "$termwin"
        cui_terminal_write    "$termwin" "Synchronizing repositories..." 1
        cui_terminal_run      "$termwin" "apk update"
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
    "$KEY_F2")
        keyword="-u"
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
        show_package_info $win
        ;;
    "$KEY_F7")
        install_package $win
        ;;
    "$KEY_F8")
        uninstall_package $win
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

#----------------------------------------------------------------------------
# mainwin_timer_hook (handle timer events)
#    $p2 --> mainwin window handle
#    $p3 --> timer id
#----------------------------------------------------------------------------
function mainwin_timer_hook()
{
    local win="$p2"
    cui_killtimer "$win" "$IDC_TIMER"
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
    pm_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load apk shellrun extension!" "Error" "$MB_ERROR"
        cui_return 0
        return
    fi

    cui_window_new "$win" 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED] && mainwin="$p2"
    if cui_valid_handle "$mainwin"
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "Package manager"
        cui_window_setlstatustext "$mainwin" "Commands: F3=Search F4=View F7=Install F8=Uninstall F10=Exit"
        cui_window_setrstatustext "$mainwin" "V1.0.0"
        cui_window_sethook        "$mainwin" "$HOOK_CREATE"  mainwin_create_hook
        cui_window_sethook        "$mainwin" "$HOOK_INIT"    mainwin_init_hook
        cui_window_sethook        "$mainwin" "$HOOK_KEY"     mainwin_key_hook
        cui_window_sethook        "$mainwin" "$HOOK_SIZE"    mainwin_size_hook
        cui_window_sethook        "$mainwin" "$HOOK_TIMER"   mainwin_timer_hook
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
