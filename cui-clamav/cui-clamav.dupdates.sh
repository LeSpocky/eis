#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/CLAMD_UPDATES.sh
# Creation:    2010-08-05 the eisfair team, team(at)eisfair(dot)org
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

    sellist="2,3,4,8,12,24"
    ece_select_list_dlg "$win" "Update hours" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
