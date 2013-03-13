# !/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/CUI_COLOR.sh - script dialog for ece
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

    sellist="BLACK,RED,GREEN,BROWN,BLUE,MAGENTA,CYAN,LIGHTGRAY"
    sellist="$sellist,DARKGRAY,LIGHTRED,LIGHTGREEN,YELLOW"
    sellist="$sellist,LIGHTBLUE,LIGHTMAGENTA,LIGHTCYAN,WHITE"

    ece_select_list_dlg "$win" "Colors" "$sellist"
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
