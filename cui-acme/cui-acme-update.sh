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

    printvar "START_ACME"              "Use: yes or no"

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

# Write new config file
createConfigFile /etc/config.d/${packageName}

exit 0
