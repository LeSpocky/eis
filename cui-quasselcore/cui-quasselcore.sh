#!/bin/sh
#----------------------------------------------------------------------------
# quasselcore configuration generator script
# Copyright (c) 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

. /etc/config.d/quasselcore

# ---------------------------------------------------------------------------
# create configuration file
# ---------------------------------------------------------------------------
cat > /etc/conf.d/quasselcore <<EOF
# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-irc/quassel/files/quasselcore.conf,v 1.5 2010/11/04 14:22:44 scarabeus Exp $

# Loglevel Debug|Info|Warning|Error. Default is: Info
# The logfile is located at /var/log/quassel.log.
LOGLEVEL="$QUASSELCORE_LOG_LEVEL"

# The address(es) quasselcore will listen on. Default is 0.0.0.0
#LISTEN="0.0.0.0"

# The port quasselcore will listen at. Default is: 4242
PORT="$QUASSELCORE_PORT"

# User we want our daemon to run under.
USER="quassel"

# Directory we store all quasselcore content.
CONFIGDIR="$QUASSELCORE_DATADIR"

# File quasselcore will log all its events into.
LOGFILE="/var/log/quassel.log"
EOF

# ---------------------------------------------------------------------------
# create logratation file
# ---------------------------------------------------------------------------
cat > /etc/logrotate.d/quasselcore <<-EOF
    /var/log/quassel.log {
    rotate ${QUASSELCORE_LOG_COUNT}
    ${QUASSELCORE_LOG_INTERVAL}
    compress
    delaycompress
    copytruncate
    missingok
    notifempty
    }
EOF

chmod 0600 /etc/logrotate.d/quasselcore
chown root /etc/logrotate.d/quasselcore

exit 0
