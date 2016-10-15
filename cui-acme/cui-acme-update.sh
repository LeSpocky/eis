#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/acme-update.sh - parameter update script
#
# Creation:     2016-20-14 starwarsfan
#
# Copyright (c) 2006-2016 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------


#exec 2>/tmp/acme-update-trace$$.log
#set -x

packageName=cui-acme

# include configlib for using printvar
. /var/install/include/configlib

# ----------------------------------------------------------------------------
# Set the default values for configuration
START_ACME='no'
ACME_DOMAIN_N='1'
ACME_DOMAIN_1_ACTIVE='yes'
ACME_DOMAIN_1_NAME='eis.lan'
ACME_DOMAIN_1_WEBROOTFOLDER='/var/www/localhost/htdocs'



# ----------------------------------------------------------------------------
# Read current configuration if existing
loadCurrentConfiguration()
{
    # read old values
    [ -f /etc/config.d/${packageName} ] && . /etc/config.d/${packageName}
}


# ----------------------------------------------------------------------------
# Write config and default files
createConfigFile()
{
    internal_conf_file=${1}
    (
    #-------------------------------------------------------------------------
    printgpl --conf ${packageName}
    #-------------------------------------------------------------------------

    #-------------------------------------------------------------------------
    printgroup "ACME configuration"
    #-------------------------------------------------------------------------

    printvar "START_ACME"                      "Use: yes or no"

    printvar "ACME_DOMAIN_N"                   "Amount of domains for which a certificate should be aquired"
    idx=1
    while [ "${idx}" -le "${ACME_DOMAIN_N}" ] ; do
        printvar "ACME_DOMAIN_${idx}_ACTIVE"          "Is the current domain active or not"
        printvar "ACME_DOMAIN_${idx}_NAME"            "Domain to get a certificate for"
        printvar "ACME_DOMAIN_${idx}_WEBROOTFOLDER"   "Path to webroot folder for this domain"
        idx=$((idx+1))
    done

    #-------------------------------------------------------------------------
    printend
    #-------------------------------------------------------------------------

    ) > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# Write default config file
createConfigFile /etc/default.d/${packageName}

# Update from old version
loadCurrentConfiguration

# Write new config file
createConfigFile /etc/config.d/${packageName}

exit 0
