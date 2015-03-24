#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/MYSQL_MAXCONN.sh
# Creation:    2015-03-18 the eisfair team, team(at)eisfair(dot)org
# ----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"
    sellist="default,60,100,150,200,300,400,600,1000"
    ece_select_list_dlg "$win" "Max connections" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
