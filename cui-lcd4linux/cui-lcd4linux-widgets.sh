#!/bin/bash
# ----------------------------------------------------------------------------
# cui-lcd4linux-update - update or generate new lcd configuration
# Creation:    2010-10-03 Y. Schumann
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------

# Include libs, helpers a.s.o.
. /var/install/include/eislib
. /var/install/include/configlib

# Set variables
mainPackageName=cui-lcd4linux
packageName=cui-lcd4linux-widgets
configfile=/etc/config.d/${packageName}

# Load configuration
. ${configfile}

# ============================================================================
# Main
# ============================================================================
if [ "${START_LCD_WIDGET}" == 'yes' ] ; then
	# Rewrite main config
    /var/install/config.d/${mainPackageName}.sh
fi
