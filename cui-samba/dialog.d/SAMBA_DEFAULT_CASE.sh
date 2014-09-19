#!/bin/bash
#-----------------------------------------------------------------------------
# /var/install/dialog.d/SAMBA_DEFAULT_CASE.sh - script dialog for ece
#
# Creation:     2014-09-19 starwarsfan
#
# Copyright (c) 2014 the eisfair team <team@eisfair.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

#-----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
#-----------------------------------------------------------------------------
exec_dialog()
{
    win="${p2}"
    sellist="upper,lower"
    ece_select_list_dlg "${win}" "${p3}" "${sellist}"
}

#-----------------------------------------------------------------------------
# main routine
#-----------------------------------------------------------------------------
cui_init
cui_run

#-----------------------------------------------------------------------------
# end
#-----------------------------------------------------------------------------
exit 0
