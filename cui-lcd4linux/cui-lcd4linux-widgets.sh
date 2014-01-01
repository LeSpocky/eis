#!/bin/bash
# ----------------------------------------------------------------------------
# cui-lcd4linux-update - update or generate new lcd configuration
#
# Creation:    2010-10-03 Y. Schumann
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
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
