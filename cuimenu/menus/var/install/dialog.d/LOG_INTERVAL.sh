#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/dialog.d/LOG_INTERVAL.sh - script dialog for ece
# Copyright (c) 2011 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="${p2}"
    sellist="daily,weekly,monthly"
    ece_select_list_dlg "${win}" "Logrotate interval" "${sellist}"
}

# main routine
cui_init
cui_run

# end
exit 0
