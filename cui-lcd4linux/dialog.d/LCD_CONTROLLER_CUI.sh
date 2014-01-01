#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/LCD_CONTROLLER_CUI.sh - script dialog for ece
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

    sellist="HD44780,HD66712,M50530,LCD0821,LCD1621,LCD2021,LCD2041,LCD4021,LK202-25,LK204-25,626,632,634,636,MI216,MI220,MI240,MI420,CW12232,CW1602,Text"

    ece_select_list_dlg "$win" "Controller type" "$sellist"
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
