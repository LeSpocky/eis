#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/ROUNDCUBE_CHARSET.sh
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

    sellist="utf-8,iso-8859-1,iso-8859-11,iso-8859-13,iso-8859-15,iso-8859-2,iso-8859-21"
    sellist="${sellist},iso-8859-25,iso-8859-4,iso-8859-5,iso-8859-7,iso-8859-71"
    sellist="${sellist},iso-8859-75,iso-8859-9,iso-8859-91,iso-8859-95,koi8"

    ece_select_list_dlg "${win}" "Default charset" "${sellist}"
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
