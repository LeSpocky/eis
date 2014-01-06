#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/LCD_ROWS_CUI.sh - script dialog for ece
#
# Creation:     2010-09-26 starwarsfan
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

# ----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------
exec_dialog()
{
    win="$p2"

    sellist="1,2,4,5,6,7,8"

    ece_select_list_dlg "$win" "Amount of lines" "$sellist"
}

# ----------------------------------------------------------------------------
# main routine
# ----------------------------------------------------------------------------

cui_init
cui_run

# ----------------------------------------------------------------------------
# end
# ----------------------------------------------------------------------------

exit 0
