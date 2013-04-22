#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/bin/userman.cui.sh - eisfair user mananger
#
# Creation:     2008-03-09 dv
# Last update:  $Id: userman.cui.sh 33444 2013-04-10 20:41:15Z dv $
#
# Copyright (c) 2001-2007 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/syslib-2

#============================================================================
# global constants
#============================================================================
IDC_MENU='10'                    # menu ID
IDC_HELPTEXT='11'                # help text ID
IDC_TIMER='13'                   # update delay timer

current_module="users"           # current (first) module
modules="empty users groups"     # buildin modules
programdir="`dirname $0`"

help_visible="yes"               # flag if help is visible or not (F1)

#============================================================================
# select menu hooks
#============================================================================

#----------------------------------------------------------------------------
# module_menu_clicked_hook
# expects: $p2 : window handle
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function module_menu_clicked_hook()
{
    cui_window_close "$p3" "$IDOK"
    cui_return 1
}

#----------------------------------------------------------------------------
# module_menu_escape_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
# returns: nothing
#----------------------------------------------------------------------------

function module_menu_escape_hook()
{
   cui_window_close "$p3" "$IDCANCEL"
   cui_return 1
}
 
#----------------------------------------------------------------------------
# module_menu_postkey_hook
# expects: $p2 : window handle                                          
#          $p3 : control window handle
#          $p4 : key code
# returns: 1 : Key handled, 2 : Key ignored
#----------------------------------------------------------------------------

function module_menu_postkey_hook()
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
# empty module functions
#============================================================================
#----------------------------------------------------------------------------
# empty_menu : menu text for this module
#----------------------------------------------------------------------------

empty_menu="Exit"

#----------------------------------------------------------------------------
# empty_init (init the empty module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function empty_init()
{
    local win="$1"
    local ctrl
    
    cui_window_getctrl "$win" "$IDC_HELPTEXT"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_textview_add "$ctrl" "Use the menu item \"Exit\" or the key F10 to exit" 1
    fi
    
    cui_window_setlstatustext "$win" "Commands: F10=Exit"
}

#----------------------------------------------------------------------------
# empty_close (close the empty module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function empty_close()
{
    local win="$1"
    local ctrl
        
    cui_window_getctrl "$win" "$IDC_HELPTEXT"
    if [ "$p2" != "0" ]
    then
        ctrl="$p2"
        cui_textview_clear "$ctrl"
    fi
}

#----------------------------------------------------------------------------
# empty_size (resize the empty module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function empty_size()
{
    echo "do nothing" > /dev/null
}

#----------------------------------------------------------------------------
# empty_readdata (read data of the empty module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function empty_readdata()
{
    echo "do nothing" > /dev/null
}

#----------------------------------------------------------------------------
# empty_activate (activate the empty module)
#    $1 --> window handle of main window
#----------------------------------------------------------------------------

function empty_activate()
{
    echo "do nothing" > /dev/null
}

#----------------------------------------------------------------------------
# empty_key (handle keyboard input)
#    $1 --> window handle of main window
#    $2 --> keyboard input
#----------------------------------------------------------------------------

function empty_key()
{
    return 1
}

                                
#============================================================================
# base module helper functions
#============================================================================

#----------------------------------------------------------------------------
# read_modules
#    $1 --> menu window handle
#----------------------------------------------------------------------------

function read_modules()
{
    local ctrl=$1
    local index=3

    # predefined modules (should always be at the upmost positions)    
    . $programdir/userman.cui.users.module.sh
    cui_menu_additem      "$ctrl" "${users_menu}"  "1"
    . $programdir/userman.cui.groups.module.sh
    cui_menu_additem      "$ctrl" "${groups_menu}" "2"
    
    # additional modules
    local files=$(ls $programdir/userman.cui.*.sh)
    local modfile
    local idx="3"

    for modfile in $files
    do
        local modname=$(basename $modfile)
        local menuitem

        modname=${modname//'userman.cui.'/''}
        modname=${modname//'.module.sh'/''}

        if [ "$modname" != "groups" -a "$modname" != "users" ]
        then
            . $modfile
            
            eval menuitem="\$${modname}_menu"

            cui_menu_additem  "$ctrl" "$menuitem" "$idx"
            idx=$[$idx + 1]
            
            modules="$modules $modname"
        fi
    done
    
    # empty module is build in
    cui_menu_addseparator "$ctrl"
    cui_menu_additem      "$ctrl" "${empty_menu}" "0"
}


#============================================================================
# base module menu and window hooks
#============================================================================

function menu_clicked_hook()
{
    local win="$p2"
    local ctrl="$p3"
    
    cui_menu_getselitem "$ctrl"
    if [ "$p2" == "0" ]
    then
        cui_window_quit 0
    else
        ${current_module}_activate $win
    fi
    cui_return 1
}

#----------------------------------------------------------------------------
# menu_changed_hook (menu selection changed)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function menu_changed_hook()
{
    local win="$p2"
    local menu
    local module
    local index="0"
    local count="0"

    cui_settimer "$win" "$IDC_TIMER" 50

    cui_window_getctrl "$win" "$IDC_MENU" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_menu_getselitem "$menu" && index="$p2"
    fi
        
    ${current_module}_close $win

    for module in $modules
    do
        if [ "$count" == "$index" ]
        then
            current_module="$module"
        fi
        count=$[$count + 1]
    done

    ${current_module}_init $win

    cui_getclientrect "$win"
    local w="$p4"
    local h="$p5"
    local s="$[$w / 3 - $w / 20]"
    local p="$[$h - $h / 3 + $h / 10]"

    ${current_module}_size "$win" "$s" "0" "$[$w - $s]" "$p"

    cui_return 1    
}

#----------------------------------------------------------------------------
# mainwin_create_hook (for creation of child windows)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_create_hook()
{
    local win="$p2"
    local ctrl

    cui_menu_new "$win" "Options" 0 0 10 10 "${IDC_MENU}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        read_modules          "$ctrl"
        cui_menu_callback     "$ctrl" "$MENU_CHANGED" "$win" menu_changed_hook
        cui_menu_callback     "$ctrl" "$MENU_CLICKED" "$win" menu_clicked_hook
        cui_window_create     "$ctrl"
        cui_menu_selitem      "$ctrl" 1
        mymenu="$ctrl"
    fi
        
    cui_textview_new "$win" "Help" 0 0 10 10 "${IDC_HELPTEXT}" "$CWS_NONE" "$CWS_NONE" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        cui_window_setcolors  "$ctrl" "HELP"
        cui_window_create     "$ctrl"
    fi
    
    ${current_module}_init $win
    
    cui_return 1    
}

#----------------------------------------------------------------------------
# mainwin_init_hook (load data)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_init_hook()
{
    local win="$p2"
    ${current_module}_readdata $win

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

    if ${current_module}_key $win $key
    then
        cui_return 1
        return
    else
        case $key in
        "$KEY_F1")
            if [ "${help_visible}" == "yes" ]
            then
                help_visible="no"
            else
                help_visible="yes"
            fi
            mainwin_render_layout $win
            cui_return 1
            return
            ;;
        "$KEY_F10")
            cui_window_quit 0
            cui_return 1
            return
            ;;
        esac
    fi
    cui_return 0
}

#----------------------------------------------------------------------------
# mainwin_render_layout (reorder windows)
#    $1 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_render_layout()
{
    local win="$1"
    local ctrl
    local menu
    local focus
    
    cui_getclientrect "$win"
    local w="$p4"
    local h="$p5"
    local s="$[$w / 3 - $w / 20]"
    local p="$h"
    
    if [ "${help_visible}" == "yes" ]
    then
        p="$[$h - $h / 3 + $h / 10]"
    fi

    # move menu window    
    cui_window_getctrl "$win" "$IDC_MENU" && menu="$p2"
    if cui_valid_handle "$menu"
    then
        cui_window_move "$menu" "0" "0" "$s" "$p"
    fi

    # move help window (hide if necessary)
    cui_window_getctrl "$win" "$IDC_HELPTEXT" && ctrl="$p2"
    if cui_valid_handle "$ctrl"
    then
        if [ "${help_visible}" == "yes" ]
        then
            cui_window_hide "$ctrl" "0"
            cui_window_move "$ctrl" "0" "$p" "$w" "$[$h -$p]"
        else
            cui_window_getfocus && focus="$p2"
            if [ "$focus" == "$ctrl" ]
            then
               cui_window_setfocus "$menu"
            fi            

            cui_window_hide "$ctrl" "1"
            cui_window_move "$ctrl" "0" "$p" "$w" "1"
        fi
    fi

    # pass resize request to current module    
    ${current_module}_size "$win" "$s" "0" "$[$w - $s]" "$p"
}

#----------------------------------------------------------------------------
# mainwin_size_hook (handle resize events for mainwin)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_size_hook()
{
    mainwin_render_layout $p2
    cui_return 1
}

#----------------------------------------------------------------------------
# mainwin_destroy_hook (destroy mainwin object)
#    $p2 --> mainwin window handle
#----------------------------------------------------------------------------

function mainwin_destroy_hook()
{
    local win="$p2"

    cui_killtimer "$win" "$IDC_TIMER"
 
    ${current_module}_close "$win"
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

    ${current_module}_readdata $win
    
    cui_return 1
}

#----------------------------------------------------------------------------
# init routine (entry point of all shellrun.cui based programs)
#    $p2 --> desktop window handle
#----------------------------------------------------------------------------

function init()
{
    local win="$p2"

    # initialize shell extension library
    sys_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load system shell extension!" "Error" "$MB_ERROR"
        cui_return 0
        return
    fi

    cui_window_new "$win" 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED] && mainwin="$p2"
    if cui_valid_handle "$mainwin"
    then
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "eisfair User Manager"
        cui_window_setlstatustext "$mainwin" "Commands: F10=Exit"
        cui_window_setrstatustext "$mainwin" "V2.0.0"
        cui_window_sethook        "$mainwin" "$HOOK_CREATE"  mainwin_create_hook
        cui_window_sethook        "$mainwin" "$HOOK_INIT"    mainwin_init_hook
        cui_window_sethook        "$mainwin" "$HOOK_KEY"     mainwin_key_hook
        cui_window_sethook        "$mainwin" "$HOOK_SIZE"    mainwin_size_hook
        cui_window_sethook        "$mainwin" "$HOOK_DESTROY" mainwin_destroy_hook
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

#============================================================================
# end of cui program
#============================================================================

exit 0

