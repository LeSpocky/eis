#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/phpmyadmin-update.sh - parameter update script
#
# Creation:     2006-09-15 starwarsfan
#
# Copyright (c) 2006-2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------


#exec 2>/tmp/phpmyadmin-update-trace$$.log
#set -x

package_name=phpmyadmin

# include configlib for using printvar
. /var/install/include/configlib

installFolder=/usr/share/webapps/phpmyadmin
webConfigFolder=${installFolder}/setup
backupFolder=/var/lib/phpmyadmin
configFolder=/etc/phpmyadmin
ownerToUse='apache:apache'


# ----------------------------------------------------------------------------
# Set the default values for configuration
START_PHPMYADMIN='no'



# ----------------------------------------------------------------------------
# Write config and default files
createConfigFile()
{
    internal_conf_file=${1}
    (
    #-------------------------------------------------------------------------
    printgpl --conf ${package_name}
    #-------------------------------------------------------------------------

    #-------------------------------------------------------------------------
    printgroup "phpMyAdmin configuration"
    #-------------------------------------------------------------------------

    printvar "START_PHPMYADMIN"              "Use: yes or no"

    #-------------------------------------------------------------------------
    printend
    #-------------------------------------------------------------------------

    ) > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Per default phpmyadmin comes with webbased setup pages. These pages should
# be deactivated and could be reactivated if neccessary using eisfair setup
deactivateWebSetup ()
{
    if [ ! -d ${backupFolder} ] ; then
        mkdir -p ${backupFolder}
    else
        rm -rf ${backupFolder}/setup
    fi
    if [ -d ${webConfigFolder} ] ; then
        mv -f ${webConfigFolder} ${backupFolder}/
    fi
    mkdir ${webConfigFolder}
    echo "Use eisfair setup to activate webbased phpmyadmin configuration!" > ${webConfigFolder}/index.php
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# write default config file
createConfigFile /etc/default.d/${package_name}

# write new config file
createConfigFile /etc/config.d/${package_name}

deactivateWebSetup

chown -R ${ownerToUse} ${configFolder}

exit 0
