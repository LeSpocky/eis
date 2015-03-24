#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/MAIL_TRANSPORT.sh
#
# Copyright (c) 2001-2011 The Eisfair Team, team(at)eisfair(dot)org
# Creation:     2009-10-03  jed
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
    sellist="default,tls,both"
    ece_select_list_dlg "${win}" "Transport type" "${sellist}"
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
