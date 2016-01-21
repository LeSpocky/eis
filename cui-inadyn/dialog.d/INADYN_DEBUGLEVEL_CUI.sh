#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/INADYN_DEBUGLEVEL_CUI.sh - script dialog for ece
# Creation: 2011-02-13 starwarsfan
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
    sellist="0,1,2,3,4,5"
    ece_select_list_dlg "$win" "Select debug level" "$sellist"
}

# Main routine
cui_init
cui_run

# end
exit 0
