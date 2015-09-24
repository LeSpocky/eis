#!/bin/bash
# ----------------------------------------------------------------------------
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"
    sellist="1,2,4,5,6,7,8"
    ece_select_list_dlg "$win" "Amount of lines" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
