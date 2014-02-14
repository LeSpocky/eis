#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-quassel-core-update.sh - paramater update script
#
# Creation: 2009-12-14 Marcel Weiler
# Copyright (c) 2001-2013 The eisfair Team, <team(at)eisfair(dot)org>
#
# ----------------------------------------------------------------------------

#exec 2> /tmp/quasselcore-update-trace$$.log
#set -x

packageName=cui-quassel-core
packageNameBinary=quasselcore

# include configlib for using printvar
. /var/install/include/configlib

# local variables
askForEdit=false

# ----------------------------------------------------------------------------
# Set the default values for configuration
# ----------------------------------------------------------------------------
START_QUASSEL_CORE='no'

QUASSEL_CORE_PORT='4242'

QUASSEL_CORE_LOG_LEVEL='info'
QUASSEL_CORE_LOG_COUNT='4'
QUASSEL_CORE_LOG_INTERVAL='weekly'
QUASSEL_CORE_LOG_FILE='/var/log/quassel/quasselcore.log'

QUASSEL_CORE_DATADIR='/usr/local/quasselcore'

QUASSEL_CORE_DAEMON_OPTS=''


# ----------------------------------------------------------------------------
# Read old configuration and rename old variables
# ----------------------------------------------------------------------------
renameOldVariables()
{
    # read old values
    [ -f /etc/configd/${packageName} ] && . /etc/config.d/${packageName}
}

# ----------------------------------------------------------------------------
# Write config and default files
# ----------------------------------------------------------------------------
makeConfigFile()
{
    local internal_conf_file=${1}
    {
        # --------------------------------------------------------------------
        printgpl --conf ${packageName}
        # --------------------------------------------------------------------

        # --------------------------------------------------------------------
        printgroup "Basic configuration"
        # --------------------------------------------------------------------
        printvar 'START_QUASSEL_CORE'          'Use: yes or no'
        printvar 'QUASSEL_CORE_PORT'           'Port for quasselcore'

        # --------------------------------------------------------------------
        printgroup 'Log settings'
        # --------------------------------------------------------------------
        printvar 'QUASSEL_CORE_LOG_LEVEL'      'Loglevel (debug,info,warning,error)'
        printvar 'QUASSEL_CORE_LOG_COUNT'      'Number of log files to save'
        printvar 'QUASSEL_CORE_LOG_INTERVAL'   'Interval: daily, weekly, monthly'
        printvar 'QUASSEL_CORE_LOG_FILE'       'Default: /var/log/quassel/quasselcore.log'

        printvar 'QUASSEL_CORE_DATADIR'        'Default: /usr/local/quasselcore'

        printvar 'QUASSEL_CORE_DAEMON_OPTS'    'Default: empty'

        # --------------------------------------------------------------------
        printend
        # --------------------------------------------------------------------

    } > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Create the check.d file
# ----------------------------------------------------------------------------
makeCheckFile()
{
    printgpl --check ${packageName} >/etc/check.d/${packageName}
    cat >> /etc/check.d/${packageName} <<EOFG
# Variable                  OPT_VARIABLE         VARIABLE_N          VALUE
START_QUASSEL_CORE          -                    -                   YESNO
QUASSEL_CORE_PORT           START_QUASSEL_CORE   -                   PORT
QUASSEL_CORE_LOG_LEVEL      START_QUASSEL_CORE   -                   QUASSEL_CORE_LOG_LEVEL_CUI
QUASSEL_CORE_LOG_COUNT      START_QUASSEL_CORE   -                   NUMERIC
QUASSEL_CORE_LOG_INTERVAL   START_QUASSEL_CORE   -                   LOG_INTERVAL
QUASSEL_CORE_LOG_FILE       START_QUASSEL_CORE   -                   NOTEMPTY
QUASSEL_CORE_DATADIR        START_QUASSEL_CORE   -                   NOTEMPTY
QUASSEL_CORE_DAEMON_OPTS    START_QUASSEL_CORE   -                   NONE
EOFG

    # Set rights for check.d file
    chmod 0600 /etc/check.d/${packageName}
    chown root /etc/check.d/${packageName}

    printgpl --check_exp ${packageName} >/etc/check.d/${packageName}.exp
    cat >> /etc/check.d/${packageName}.exp <<EOFG
QUASSEL_CORE_LOG_LEVEL_CUI  = 'debug|info|warning|error'
                            : 'No valid loglevel. Must be "debug", "info", "warning" or "error".'
EOFG

    # Set rights for check.exp file
    chmod 0600 /etc/check.d/${packageName}.exp
    chown root /etc/check.d/${packageName}.exp

#    printgpl --check_ext ${packageName} >/etc/check.d/${packageName}.ext
#    cat >> /etc/check.d/${packageName}.ext <<EOFG
#
#
#EOFG

    # Set rights for check.ext file
#    chmod 0600 /etc/check.d/${packageName}.ext
#    chown root /etc/check.d/${packageName}.ext
}

makeLogrotateFile()
{
    creationTime=`date -Iseconds`

    {
        echo '# ----------------------------------------------------------------------------'
        echo "# /etc/logrotate.d/${packageNameBinary} created by ${0}"
        echo '# DO NOT EDIT THIS FILE BY HAND! (use eisfair setup!)'
        echo '# ----------------------------------------------------------------------------'
        echo "$QUASSEL_CORE_LOG_FILE {"
    } > /etc/logrotate.d/${packageNameBinary}

    cat >> /etc/logrotate.d/${packageNameBinary} <<-EOFG
    rotate ${QUASSEL_CORE_LOG_COUNT}
    ${QUASSEL_CORE_LOG_INTERVAL}
    compress
    delaycompress
    copytruncate
    missingok
    notifempty
    }
EOFG

    chmod 0600 /etc/logrotate.d/${packageNameBinary}
    chown root /etc/logrotate.d/${packageNameBinary}
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
# Write default config file
[ -f /etc/config.d/${packageName} ] || askForEdit=true

makeConfigFile /etc/default.d/${packageName}

# Update from old version
renameOldVariables

# Write new config file
makeConfigFile /etc/config.d/${packageName}

# Write check.d file
makeCheckFile

# Write logrotate file
#makeLogrotateFile

exit 0
