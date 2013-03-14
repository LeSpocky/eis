#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/dialog.d/MODULE_ACTION.sh
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog() 
{
    local  win="$p2" sellist
    sellist="option,alias,blacklist,forcedstart"
    ece_select_list_dlg "$win" "Desired action" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
