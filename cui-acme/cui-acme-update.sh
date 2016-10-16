#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/acme-update.sh - parameter update script
#
# Creation:     2016-10-14 starwarsfan
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

packageName=acme

# include configlib for using printvar
. /var/install/include/configlib

# ----------------------------------------------------------------------------
# Set the default values for configuration
START_ACME='no'

ACME_WEBROOT_N='1'
ACME_WEBROOT_1_ACTIVE='yes'
ACME_WEBROOT_1_PATH='/var/www/localhost/htdocs'
ACME_WEBROOT_1_DOMAIN_N='1'
ACME_WEBROOT_1_DOMAIN_1_ACTIVE='yes'
ACME_WEBROOT_1_DOMAIN_1_NAME='eis.lan'
ACME_WEBROOT_1_DOMAIN_1_SUBDOMAIN_N='1'
ACME_WEBROOT_1_DOMAIN_1_SUBDOMAIN_1_ACTIVE='yes'
ACME_WEBROOT_1_DOMAIN_1_SUBDOMAIN_1_NAME='www'


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
    printgroup "ACME Let's Encrypt configuration"
    #-------------------------------------------------------------------------

    printvar "START_ACME"                         "Use: yes or no"

    printvar "ACME_WEBROOT_N"                     "Amount of separate webroot folders"
    idx=1
    while [ "${idx}" -le "${ACME_WEBROOT_N}" ] ; do
        printvar "ACME_WEBROOT_${idx}_ACTIVE"     "Is the current webroot folder active or not"
        printvar "ACME_WEBROOT_${idx}_PATH"       "Path to webroot folder for this domain"
        printvar "ACME_WEBROOT_${idx}_DOMAIN_N"   "Amount of domains for this webroot folder"
        eval amountOfDomains='${ACME_WEBROOT_'${idx}'_DOMAIN_N}'
        amountOfDomains=${amountOfDomains:-0} # Set to 0 if empty
        idx2=1
        while [ "${idx2}" -le "${amountOfDomains}" ] ; do
            printvar "ACME_WEBROOT_${idx}_DOMAIN_${idx2}_ACTIVE"        "Is this domain active or not"
            printvar "ACME_WEBROOT_${idx}_DOMAIN_${idx2}_NAME"          "Domain to get a certificate for"
            printvar "ACME_WEBROOT_${idx}_DOMAIN_${idx2}_SUBDOMAIN_N"   "Amount of subdomains for this webroot folder"
            eval amountOfSubDomains='${ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_SUBDOMAIN_N}'
            amountOfSubDomains=${amountOfSubDomains:-0} # Set to 0 if empty
            idx3=1
            while [ "${idx3}" -le "${amountOfSubDomains}" ] ; do
                printvar "ACME_WEBROOT_${idx}_DOMAIN_${idx2}_SUBDOMAIN_${idx3}_ACTIVE"   "Is this subdomain active or not"
                printvar "ACME_WEBROOT_${idx}_DOMAIN_${idx2}_SUBDOMAIN_${idx3}_NAME"     "Subdomain to get a certificate for"
                idx3=$((idx3+1))
            done
            idx2=$((idx2+1))
        done
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
