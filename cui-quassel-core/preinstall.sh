#!/bin/bash
# ----------------------------------------------------------------------------
# /tmp/preinstall.sh - quassel-core preinstallation script
#
# Creation   : 2009-12-14 Marcel Weiler
# Last update: $Id: preinstall.sh 32624 2013-01-09 20:39:54Z starwarsfan $
#
# Copyright (c) 2001-2010 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

# include eislib
. /var/install/include/eislib

# set packages name
packageName=quassel-core
neededBase='2.0.1'

### check base version
if [ ! -f /var/install/bin/check-version ] ||
   [ `/var/install/bin/check-version base ${neededBase}` = 'new' ] ; then
    echo
    echo
    colecho "The version of eisfair must be ${neededBase} or higher." rd w brinv
    colecho 'Please update your eisfair system first!' rd w brinv
    echo
    echo
    exit 1
fi

# ----------------------------------------------------------------------------
# Check for old installation
# ----------------------------------------------------------------------------


# ----------------------------------------------------------------------------
# Update system
# ----------------------------------------------------------------------------

if [ -f /var/install/deinstall/${packageName} ] ; then
   sh /var/install/deinstall/${packageName} update
fi

exit 0
# ----------------------------------------------------------------------------
# End
# ----------------------------------------------------------------------------

