#!/bin/sh
# ----------------------------------------------------------------------------
# eisfair-ng configuration generator script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /etc/config.d/cui-acme

# ----------------------------------------------------------------------------
# Setup all necessary configuration files and perform necessary steps
generateNewCert()
{
    echo "To be done..."
    anykey
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$START_ACME" = 'yes' ] ; then
    generateNewCert
fi

exit 0
