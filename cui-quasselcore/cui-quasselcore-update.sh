#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-quasselcore-update.sh - paramater update script
#
# Creation   : 2009-12-14 Marcel Weiler
#
# Copyright (c) 2001-2013 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/quasselcore-update-trace$$.log
#set -x

packageName=cui-quasselcore
packageNameBinary=quasselcore

# include configlib for using printvar
. /var/install/include/configlib

# include eislib
. /var/install/include/eislib

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
    if [ -f /etc/config.d/${packageName} ] ; then
        . /etc/config.d/${packageName}
    fi
}

# ----------------------------------------------------------------------------
# Write config and default files
# ----------------------------------------------------------------------------
makeConfigFile()
{
    internal_conf_file=${1}
    {
    # ------------------------------------------------------------------------
    printgpl -conf ${packageName} '2009-12-14' 'Marcel Weiler'
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    printgroup "Basic configuration"
    # ------------------------------------------------------------------------
    printvar 'START_QUASSEL_CORE'          'Use: yes or no'
    printvar 'QUASSEL_CORE_PORT'           'Port for quasselcore'

    # --------------------------------------------------------------
    printgroup 'Log settings'
    # --------------------------------------------------------------
    printvar 'QUASSEL_CORE_LOG_LEVEL'      'Loglevel (debug,info,warning,error)'
    printvar 'QUASSEL_CORE_LOG_COUNT'      'Number of log files to save'
    printvar 'QUASSEL_CORE_LOG_INTERVAL'   'Interval: daily, weekly, monthly'
    printvar 'QUASSEL_CORE_LOG_FILE'       'Default: /var/log/quassel/quasselcore.log'

    printvar 'QUASSEL_CORE_DATADIR'        'Default: /usr/local/quasselcore'

    printvar 'QUASSEL_CORE_DAEMON_OPTS'    'Default: empty'

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------

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
    printgpl -check ${packageName} '2009-12-23' 'Marcel Weiler' >/etc/check.d/${packageName}
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

    printgpl -check_exp ${packageName} '2009-12-23' 'Marcel Weiler' >/etc/check.d/${packageName}.exp
    cat >> /etc/check.d/${packageName}.exp <<EOFG
QUASSEL_CORE_LOG_LEVEL_CUI  = 'debug|info|warning|error'
                            : 'No valid loglevel. Must be "debug", "info", "warning" or "error".'
EOFG

    # Set rights for check.exp file
    chmod 0600 /etc/check.d/${packageName}.exp
    chown root /etc/check.d/${packageName}.exp

#    printgpl -check_ext ${packageName} '2009-12-14' 'Marcel Weiler' >/etc/check.d/${packageName}.ext
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
    creationTime=`date --iso-8601='seconds'`

    {
        echo '# ----------------------------------------------------------------------------'
        echo "# /etc/logrotate.d/${packageNameBinary} created by ${0}"
        echo '#'
        echo '# DO NOT EDIT THIS FILE BY HAND! (use eisfair setup!)'
        echo '#'
        echo "# Created: ${creationTime}"
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
if [ -f /etc/config.d/${packageName} ] ; then
    mecho -info -n 'Updating configuration ...'
else
    mecho -info -n 'Creating configuration ...'
    askForEdit=true
fi

makeConfigFile /etc/default.d/${packageName}

# Update from old version
mecho -info -n '.'
renameOldVariables

# Write new config file
mecho -info -n '.'
makeConfigFile /etc/config.d/${packageName}

# Write check.d file
mecho -info -n '.'
makeCheckFile

# Write logrotate file
#mecho -info -n '.'
#makeLogrotateFile

mecho -info ' Finished.'

# Write configuration, either after editing config or automatically when
# this is an update or config variables changed
if ${askForEdit} && /var/install/bin/ask "Edit ${packageName} configuration now?" ; then
    # triggers restart of daemon if user configures it
    # no need for an extra restart
    /var/install/bin/edit -apply ${packageName} "Edit ${packageName} configuration ..."
else
    /var/install/config.d/${packageName}.sh --quiet
fi

exit 0
# ----------------------------------------------------------------------------
# End
# ----------------------------------------------------------------------------
