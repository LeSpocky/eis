#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-quasselcore-add-user.sh - add user to quasselcore
# database
#
# Copyright (c) 2001-2013 The Eisfair Team, team(at)eisfair(dot)org
#
# Creation: 2009-12-23 marwe
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

# Load eislib and quasselcore configuration
. /var/install/include/eislib
. /etc/config.d/cui-quasselcore

# start add-user function of core, its interactive
/usr/bin/quasselcore --add-user -c ${QUASSEL_CORE_DATADIR}
