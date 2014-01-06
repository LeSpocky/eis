#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/LCD_SPEED_CUI.sh - script dialog for ece
#
# Creation:     2010-09-26 starwarsfan
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

# ----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------
exec_dialog()
{
    win="$p2"
    ece_select_list_dlg "$win" "Serial speed" "$sellist"
}

# ----------------------------------------------------------------------------
# main routine
# ----------------------------------------------------------------------------

# Load current config
. /etc/config.d/lcd

# Setup list of possible serial speed
LCD_DRIVER=`echo ${LCD_TYPE} | cut -d ":" -f 1`
case ${LCD_DRIVER} in
	# Cwlinux:            1200, 2400, 9600, 19200
    # MatrixOrbital:      1200, 2400, 9600, 19200
	'Cwlinux'|'MatrixOrbital' )
	    sellist="1200,2400,9600,19200"
		;;
    # Crystalfontz:       1200, 2400, 4800, 9600, 19200, 38400, 115200
    # MilfordInstruments: 1200, 2400, 4800, 9600, 19200, 38400, 115200
    'Crystalfontz'|'MilfordInstruments' )
	    sellist="1200,2400,9600,19200,38400,115200"
    	;;
    * )
    	sellist='---'
    	;;
esac

cui_init
cui_run

# ----------------------------------------------------------------------------
# end
# ----------------------------------------------------------------------------

exit 0
