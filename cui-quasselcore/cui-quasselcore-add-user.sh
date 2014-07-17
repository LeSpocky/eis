#!/bin/bash
# ---------------------------------------------------------------------------
# /var/install/bin/quasselcore-add-user.sh - add user to quasselcore
# Copyright (c) 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

. /etc/config.d/quasselcore

# start add-user function of core, its interactive
/usr/bin/quasselcore --add-user -c ${QUASSELCORE_DATADIR}
