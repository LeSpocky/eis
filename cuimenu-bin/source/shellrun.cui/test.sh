#! /bin/sh
#------------------------------------------------------------------------------
# /var/install/bin/test.sh - test script for libcui interface
#
# Copyright (c) 2007 eisfair-Team
#
# Creation:    2007-06-30 dv
# Last update: $Id: test.sh 23498 2010-03-14 21:57:47Z dv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib

terminal_exit()
{
    win="$p2"
    ctrl="$p3"
    cui_window_close "$ctrl" "$IDOK"
    cui_return ""
}

listview_timer()
{
    myctrl="$p2"

    cui_listview_add "$myctrl"
    idx="$p2"
    cui_listview_settext "$myctrl" "$idx" 0 "Timer1"
    cui_listview_settext "$myctrl" "$idx" 1 "Timer2"
    cui_listview_settext "$myctrl" "$idx" 2 "Timer3"
    cui_listview_update  "$myctrl"
    cui_return ""
}

listview_clicked()
{
    win="$p2"
    ctrl="$p3"
    cui_window_close "$ctrl" "$IDOK"
    cui_return ""
}

listview_postkey()
{
    win="$p2"
    ctrl="$p3"
    key="$p4"

    case "$key"
    in
        ${KEY_F10})
            cui_message "$ctrl" "F10 pressed!" "Key pressed" $MB_OK
            cui_window_close "$ctrl" $IDOK
            cui_window_close "$win" $IDOK
            cui_return "1"
            return 
            ;;
        ${KEY_ENTER})
            cui_window_close "$ctrl" $IDOK
            cui_return "1"
            return
            ;;
    esac
    cui_return "0"
}

menu_clicked()
{
    win="$p2"
    ctrl="$p3"
    cui_window_close "$ctrl" "$IDOK"
    cui_return ""
}

ok_button()
{
    win="$p2"
    ctrl="$p3"

#    if cui_window_getctrl "$win" 4710
#    then
#        myedit="$p2"
#        if cui_edit_gettext "$myedit"
#        then
#            cui_message 0 "Text = $p2" "Info" $MB_OK
#        fi
#    fi

    cui_window_close "$win" $IDOK
    cui_return ""
}

cancel_button()
{
    win="$p2"
    cui_window_close "$win" $IDCANCEL
    cui_return ""
}

listview_button()
{
    win="$p2"
    ctrl="$p3"

    if cui_listview_new "$win" "Listview" 0 0 40 15 3 1111 $CWS_POPUP $CWS_NONE
    then
        myctrl="$p2"
        cui_listview_callback "$myctrl" "$LISTVIEW_CLICKED" "$win" "listview_clicked"
        cui_listview_callback "$myctrl" "$LISTVIEW_POSTKEY" "$win" "listview_postkey"

        cui_listview_setcoltext "$myctrl" 0 "Column1"
        cui_listview_setcoltext "$myctrl" 1 "Column2"
        cui_listview_setcoltext "$myctrl" 2 "Column3"

        cui_listview_add "$myctrl"
        idx="$p2"
        cui_listview_settext "$myctrl" "$idx" 0 "Item1"
        cui_listview_settext "$myctrl" "$idx" 1 "Item2"
        cui_listview_settext "$myctrl" "$idx" 2 "Item3"

        cui_listview_add "$myctrl"
        idx="$p2"
        cui_listview_settext "$myctrl" "$idx" 0 "Item1"
        cui_listview_settext "$myctrl" "$idx" 1 "Item2"
        cui_listview_settext "$myctrl" "$idx" 2 "Item3"

        cui_window_sethook   "$myctrl" "$HOOK_TIMER" "listview_timer"
        cui_window_setcolors "$myctrl" "MYCOLORS"
        cui_window_create    "$myctrl"
        cui_settimer         "$myctrl" 333 2000
        cui_window_modal     "$myctrl"
        cui_killtimer        "$myctrl" 333
        cui_window_destroy   "$myctrl"
    fi
    cui_return ""
}

terminal_button()
{
    win="$p2"
    ctrl="$p3"

    if cui_terminal_new "$win" "Listview" 0 0 40 15 1112 $CWS_POPUP $CWS_NONE
    then
        myctrl="$p2"
        cui_terminal_callback "$myctrl" "$TERMINAL_EXIT" "$win" "terminal_exit"
        cui_window_create  "$myctrl"
	cui_terminal_run   "$myctrl" "bash -i"
        cui_window_modal   "$myctrl"
        cui_window_destroy "$myctrl"
    fi
    cui_return ""
}

menu_button()
{
    win="$p2"
    ctrl="$p3"

    if cui_menu_new "$win" "Select Item" 0 0 40 6 1113 $[$CWS_POPUP + $CWS_CENTERED] $CWS_NONE
    then
        myctrl="$p2"
        cui_menu_callback  "$myctrl" "$MENU_CLICKED" "$win" "menu_clicked"
        cui_menu_additem   "$myctrl" "Item 1" 1
        cui_menu_additem   "$myctrl" "Item 2" 2
        cui_menu_selitem   "$myctrl" 1
        cui_window_create  "$myctrl"
        cui_window_modal   "$myctrl"
        cui_window_destroy "$myctrl"
    fi
    cui_return ""
}


key_hook()
{
    win="$p2"
    key="$p3"

    if [ "$key" == "${KEY_F10}" ]
    then
        cui_message "$win" "F10 pressed!" "Key pressed" $MB_OK
        cui_window_close "$win" $IDOK
        cui_return "1"
        return
    fi
    cui_return "0"
}


init()
{
    cui_addcolors "MYCOLORS" \
         "$COLOR_RED" \
         "$COLOR_BLACK" \
         "$COLOR_WHITE" \
         "$COLOR_LIGHTGRAY" \
         "$COLOR_DARKGRAY" \
         "$COLOR_YELLOW" \
         "$COLOR_BLACK" \
         "$COLOR_LIGHTGRAY" \
         "$COLOR_LIGHTGRAY" \
         "$COLOR_BLACK" \
         "$COLOR_LIGHTGRAY"

    if cui_window_new 0 0 0 0 0 $[$CWS_POPUP + $CWS_CAPTION + $CWS_STATUSBAR + $CWS_MAXIMIZED]
    then
        mainwin="$p2"
        cui_window_setcolors      "$mainwin" "DESKTOP"
        cui_window_settext        "$mainwin" "shellrun - Demo Script"
        cui_window_setlstatustext "$mainwin" "Commands: F10=Exit"
        cui_window_setrstatustext "$mainwin" "V1.0.0"
        cui_window_create         "$mainwin"
   
        if cui_window_new "$mainwin" 1 1 47 20 $[$CWS_POPUP + $CWS_BORDER + $CWS_CENTERED]
        then
            mywin="$p2"
            cui_window_sethook "$mywin" "$HOOK_KEY" "key_hook"
            cui_window_create  "$mywin"

            if cui_label_new "$mywin" "Enter Text:" 2 1 12 1 4709 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_window_create "$myctrl"
            fi

#            if xml_read_tag "/var/install/packages/base" "package:short"
#            then
#                myedittext="$p2"
#            fi

            if cui_edit_new "$mywin" "$myedittext" 15 1 20 1 80 4710 $CWS_NONE $CWS_NONE
            then
                myedit="$p2"
                cui_window_create "$myedit"
            fi

            if cui_groupbox_new "$mywin" "Group 1" 2 3 20 4 $CWS_NONE $CWS_NONE
            then
                mygroup="$p2"
                cui_window_create "$mygroup"

                if cui_radio_new "$mygroup" "Click Me 1" 1 0 20 1 4711 $CWS_NONE $CWS_NONE
                then
                    myctrl="$p2"
                    cui_window_create "$myctrl"
                fi

                if cui_radio_new "$mygroup" "Click Me 2" 1 1 20 1 4712 $CWS_NONE $CWS_NONE
                then
                    myctrl="$p2"
                    cui_window_create "$myctrl"
                fi
            fi

            if cui_groupbox_new "$mywin" "Group 2" 23 3 20 4 $CWS_NONE $CWS_NONE
            then
                mygroup="$p2"
                cui_window_create "$mygroup"

                if cui_checkbox_new "$mygroup" "Check Me 1" 1 0 20 1 4713 $CWS_NONE $CWS_NONE
                then
                    myctrl="$p2"
                    cui_window_create "$myctrl"
                fi 

                if cui_checkbox_new "$mygroup" "Check Me 2" 1 1 20 1 4714 $CWS_NONE $CWS_NONE
                then
                    myctrl="$p2"
                    cui_window_create "$myctrl"
                fi
            fi

            if cui_listbox_new "$mywin" "Listbox" 2 7 20 6 4715 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_window_create  "$myctrl"
                cui_listbox_add    "$myctrl" "Item 1"
                cui_listbox_add    "$myctrl" "Item 2"
                cui_listbox_add    "$myctrl" "Item 3"
                cui_listbox_setsel "$myctrl" "0"
            fi

            if cui_combobox_new "$mywin" 24 8 19 6 4716 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_window_create  "$myctrl"
                cui_combobox_add    "$myctrl" "Item 1"
                cui_combobox_add    "$myctrl" "Item 2"
                cui_combobox_add    "$myctrl" "Item 3"
                cui_combobox_setsel "$myctrl" "0"
            fi

            if cui_progress_new "$mywin" "Progress" 23 10 20 3 4717 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_window_create     "$myctrl"
                cui_progress_setrange "$myctrl" 100
                cui_progress_setpos   "$myctrl" 50
            fi

            if cui_button_new "$mywin" "&Ok" 5 15 10 1 4790 $CWS_DEFOK $CWS_NONE
            then
                myctrl="$p2"
                cui_button_callback "$myctrl" "$BUTTON_CLICKED" "$mywin" "ok_button"
                cui_window_create   "$myctrl"
            fi

            if cui_button_new "$mywin" "&Cancel" 16 15 10 1 4791 $CWS_DEFCANCEL $CWS_NONE
            then
                myctrl="$p2"
                cui_button_callback "$myctrl" "$BUTTON_CLICKED" "$mywin" "cancel_button"
                cui_window_create   "$myctrl"
            fi

            if cui_button_new "$mywin" "&List" 27 14 10 1 4792 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_button_callback "$myctrl" "$BUTTON_CLICKED" "$mywin" "listview_button"
                cui_window_create   "$myctrl"
            fi

            if cui_button_new "$mywin" "&Term" 27 15 10 1 4793 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_button_callback "$myctrl" "$BUTTON_CLICKED" "$mywin" "terminal_button"
                cui_window_create   "$myctrl"
            fi

            if cui_button_new "$mywin" "&Menu" 27 16 10 1 4794 $CWS_NONE $CWS_NONE
            then
                myctrl="$p2"
                cui_button_callback "$myctrl" "$BUTTON_CLICKED" "$mywin" "menu_button"
                cui_window_create   "$myctrl"
            fi
        fi

        cui_message 0 "Hallo Welt" "Hallo" $[$MB_INFO + $MB_YESNO]
        cui_window_modal   "$mywin"
        cui_window_destroy "$mywin"

        cui_window_quit 0
    fi

    cui_return ""
}

cui_init
cui_run

exit 0

