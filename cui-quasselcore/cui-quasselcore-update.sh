#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/quasselcore-update.sh - paramater update script
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
# ----------------------------------------------------------------------------

package_name=quasselcore

# Include required libs
. /var/install/include/configlib

# Set defaults from default.d file
. /etc/default.d/${package_name}
# Read old values if exists
[ -f /etc/config.d/${package_name} ] && . /etc/config.d/${package_name}

### ----------------------------------------------------------------------------
### Write the new config
(
    printgpl --conf "$package_name"

    # ------------------------------------------------------------------------
    printgroup  "General settings"
    # ------------------------------------------------------------------------

    printvar 'START_QUASSELCORE'          'Use: yes or no'
    printvar 'QUASSELCORE_PORT'           'Port for quasselcore'
    printvar 'QUASSELCORE_DATADIR'        'Default: /var/lib/quassel'
    printvar 'QUASSELCORE_DAEMON_OPTS'    'Default: empty'

    # --------------------------------------------------------------------
    printgroup 'Log settings'
    # --------------------------------------------------------------------

    printvar 'QUASSELCORE_LOG_LEVEL'      'Loglevel (debug,info,warning,error)'
    printvar 'QUASSELCORE_LOG_COUNT'      'Number of log files to save'
    printvar 'QUASSELCORE_LOG_INTERVAL'   'Interval: daily, weekly, monthly'

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------
) > /etc/config.d/${package_name}
# Set rights
chmod 0640  /etc/config.d/${package_name}
chown root  /etc/config.d/${package_name}

exit 0
### ----------------------------------------------------------------------------
