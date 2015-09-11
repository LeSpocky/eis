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
exec_dialog(){
    win="$p2"
    ece_select_list_dlg "$win" "Serial speed" "$sellist"
}

# main routine
# Load current config
. /etc/config.d/cui-lcd4linux

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
  *)
    	sellist='---'
    ;;
esac

cui_init
cui_run

# ----------------------------------------------------------------------------
# end
# ----------------------------------------------------------------------------

exit 0
