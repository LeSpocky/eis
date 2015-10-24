#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/dialog.d/TIMEZONE_LIST.sh - script dialog for ece
# Copyright (c) 2012 - 2015 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="${p2}"
    sellist="UTC" 
    if [ -e /usr/share/zoneinfo/Etc ]
    then    
        cd /usr/share/zoneinfo/Etc
        for I in *
        do 
            sellist="$sellist, Etc/$I"
        done    
    fi
    if [ -e /usr/share/zoneinfo/Europe ]
    then    
        cd /usr/share/zoneinfo/Europe
        for I in *
        do 
            sellist="$sellist, Europe/$I"
        done    
    fi
    ece_select_list_dlg "${win}" "Timezone" "${sellist}"
}

# main routine
cui_init
cui_run

# end
exit 0
