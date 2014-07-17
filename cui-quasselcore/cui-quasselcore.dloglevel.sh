#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/QUASSELCORE_LOG_LEVEL_CUI.sh
# Creation:    2014-07-17 the eisfair team, team(at)eisfair(dot)org
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
    sellist="debug,info,warning,error"
    ece_select_list_dlg "$win" "Loglevel" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
