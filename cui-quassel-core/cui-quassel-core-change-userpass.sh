#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-quassel-core-change-userpass.sh - change password of a
# quasselcore user
#
# Copyright (c) 2001-2010 The eisfair Team, team(at)eisfair(dot)org
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
. /etc/config.d/cui-quassel-core

# ask for username and call change-pass function with it
USER_INPUT=`/var/install/bin/ask "Name of User to change Password" "" "+"`

/usr/bin/quasselcore --change-userpass=${USER_INPUT} -c ${QUASSEL_CORE_DATADIR}
