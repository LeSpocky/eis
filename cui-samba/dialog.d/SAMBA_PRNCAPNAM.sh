#! /bin/sh
#-----------------------------------------------------------------------------
# /var/install/dialog.d/SAMBA_PRNCAPNAM.sh - script dialog for ece
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

    if [ -n "${sellist}" ]
    then
        ece_select_list_dlg "$win" "${p3}" "$sellist"
    else
        # No fileset entries found, so show a message according to this
        cui_message "$win" "No printcap entries found." "${p3}" "$MB_OK"
        # set value of config variable to empty
        value=''
        cui_return "$IDOK"
    fi
}

#-----------------------------------------------------------------------------
# Create the selection list out of all configured and active filesets
#-----------------------------------------------------------------------------
createSelection ()
{
    if [ -f /etc/printcap ]
    then
        printcapnames=`grep -E '^pr[[:digit:]]*:$|^usbpr[[:digit:]]*:$|^repr[[:digit:]]*:$' /etc/printcap | cut -d: -f1`
        separator=','

        for pcn in $printcapnames
        do
            sellist="${sellist}${separator}$pcn"
        done
    fi
}

#-----------------------------------------------------------------------------
# main routine
#-----------------------------------------------------------------------------
sellist=''
createSelection
cui_init
cui_run

#-----------------------------------------------------------------------------
# end
#-----------------------------------------------------------------------------
exit 0
