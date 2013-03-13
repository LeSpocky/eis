#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/CONSOLEFONT_NAME.sh
# Copyright (c) 2001-2013 the eisfair team, team(at)eisfair(dot)org
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

    for sel in `ls -m /lib/kbd/consolefonts`
    do
        echo $sel | grep -vq ".psf*" || \
        sellist="$sellist$(echo $sel | sed 's#\.psf.*\.gz##g')"
    done

    ece_select_list_dlg "$win" "Console font face" "$sellist"
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
