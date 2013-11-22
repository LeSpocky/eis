#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/BIND_TRANSFER.sh - script dialog for ece
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
    sellist="any,localnets,nslist,none"
    ece_select_list_dlg "$win" "Allow transfer to" "$sellist"
}

# main routine
cui_init
cui_run

exit 0
