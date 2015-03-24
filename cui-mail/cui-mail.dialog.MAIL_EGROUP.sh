#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/MAIL_EGROUP.sh
#
# Copyright (c) 2001-2015 The Eisfair Team, team(at)eisfair(dot)org
# Creation:     2014-05-29  jed
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
    if [ -z ${value} ]
    then
        # set default value
        value=''
    fi
    sellist=",`cut -d: -f1 /etc/group | sort | tr '\n' ','`"
    ece_select_list_dlg "${win}" "Group list" "${sellist}"
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
