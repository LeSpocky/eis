#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/PHP_CACHING_MODULE.sh
# Creation:    2010-08-05 the eisfair team, team(at)eisfair(dot)org
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
    sellist="no,apc,memcache"
    ece_select_list_dlg "$win" "Cache Method" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
