#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/ROUNDCUBE_IMAP_TRANSPORT.sh
#
# Copyright (c) 2012 - 2016 The eisfair team, team(at)eisfair(dot)org>
# Creation:     2012-12-20  jed
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

    sellist="default,ssl,tls"
    ece_select_list_dlg "${win}" "IMAP transport" "${sellist}"
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
