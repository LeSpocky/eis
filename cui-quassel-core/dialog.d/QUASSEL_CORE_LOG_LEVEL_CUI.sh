#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/QUASSEL_CORE_LOG_LEVEL_CUI.sh - script dialog for ece
#
# Creation:     2009-12-26 Marcel Weiler
#
# Copyright (c) 2001-2013 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

#----------------------------------------------------------------------------
# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
#----------------------------------------------------------------------------
exec_dialog()
{
    win="$p2"

    sellist="debug,info,warning,error"

    ece_select_list_dlg "$win" "Log Level" "$sellist"
}

#----------------------------------------------------------------------------
# main routine
#----------------------------------------------------------------------------

cui_init
cui_run

#----------------------------------------------------------------------------
# end
#----------------------------------------------------------------------------

exit 0
