#!/bin/bash
# ---------------------------------------------------------------------------
# /var/install/bin/cui-quassel-core-change-userpass.sh - change password of a
# quasselcore user
# Copyright (c) 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# Load eislib and quasselcore configuration
. /var/install/include/eislib
. /etc/config.d/cui-quassel-core

# ask for username and call change-pass function with it
USER_INPUT=`/var/install/bin/ask "Name of User to change Password" "" "+"`

/usr/bin/quasselcore --change-userpass=${USER_INPUT} -c ${QUASSEL_CORE_DATADIR}
