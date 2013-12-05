#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/INADYN_SYSTEM_CUI.sh - script dialog for ece
#
# Creation:     2011-02-13 starwarsfan
#
# Copyright (c) 2011 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

# ----------------------------------------------------------------------------
# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------
exec_dialog()
{
    win="$p2"

    sellist="dynamic,static,custom,zoneedit,no-ip,changeip"

    ece_select_list_dlg "$win" "Select used dynamic DNS system" "$sellist"
}

# ----------------------------------------------------------------------------
# Main routine
# ----------------------------------------------------------------------------

cui_init
cui_run

# ----------------------------------------------------------------------------
# end
# ----------------------------------------------------------------------------

exit 0
