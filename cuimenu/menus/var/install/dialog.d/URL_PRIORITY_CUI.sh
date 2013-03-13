#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/URL_PRIORITY_CUI.sh - script dialog for ece
# Copyright (c) 2012 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

# ---------------------------------------------------------------------------
# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ---------------------------------------------------------------------------
exec_dialog()
{
    win="${p2}"

    sellist="high,normal,low"

    ece_select_list_dlg "${win}" "Priority level" "${sellist}"
}

# ---------------------------------------------------------------------------
# main routine
# ---------------------------------------------------------------------------

cui_init
cui_run

# ---------------------------------------------------------------------------
# end
# ---------------------------------------------------------------------------

exit 0
