#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/MYSQL_QCSIZE.sh
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
    sellist="default,8M,16M,32M,64M,128M,256M,512M"
    ece_select_list_dlg "$win" "Query cache size" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
