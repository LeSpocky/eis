#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/dialog.d/CONSOLE_KEYMAP.sh
# Copyright (c) 2001-2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"
    cd /lib/kbd/keymaps
    for I in *
    do 
        [ -n "$sellist" ] && sellist="$sellist,"
        sellist="$sellist$(echo $I | sed 's#.bmap.gz##g')"
    done
    ece_select_list_dlg "$win" "Keyboard layout" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
