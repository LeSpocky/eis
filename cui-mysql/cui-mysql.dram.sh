#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/MYSQL_RAM.sh
# Creation:    2013-09-04 the eisfair team, team(at)eisfair(dot)org
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
    sellist="256MB,1GB,2GB,4GB,8GB,16BG,32GB,64GB"
    ece_select_list_dlg "$win" "Using RAM" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
