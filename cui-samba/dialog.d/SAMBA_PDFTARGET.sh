#! /bin/sh
#-----------------------------------------------------------------------------
# /var/install/dialog.d/SAMBA_PDFTARGET.sh - script dialog for ece
#
# Creation:     2013-05-08 tb
# Last update:  2013-05-08 tb
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
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
    sellist="homedir,public,mail"
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
