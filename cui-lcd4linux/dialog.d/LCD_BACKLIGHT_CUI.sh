#!/bin/bash
# ----------------------------------------------------------------------------
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"
    ece_select_list_dlg "$win" "Display backlight" "$sellist"
}

# main routine
# Load current config
. /etc/config.d/cui-lcd4linux

# Setup list of possible backlight value settings
LCD_DRIVER=`echo $LCD_TYPE | cut -d ":" -f 1`
case ${LCD_DRIVER} in
	'Cwlinux' )
	    sellist=`seq -s , 8 -1 0`
		;;
  'Crystalfontz' )
	    sellist=`seq -s , 100 -1 0`
    	;;
  'LCD2USB'|'GLCD2USB' )
    	sellist=`seq -s , 255 -1 0`
    	;;
    * )
    	sellist=`seq -s , 255 -1 0`
    	;;
esac

cui_init
cui_run

# end
exit 0
