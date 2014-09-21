#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/samba-usermapping-update.sh - creating or updating
# /etc/config.d/samba-usermapping
#
# Copyright (c) 2014 the eisfair team <team@eisfair.org>
#
# Creation   : 2014-09-21 starwarsfan
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
#set -x

packageName=samba-usermapping

. /var/install/include/eislib
. /var/install/include/configlib

SAMBA_USERMAP_N=1
SAMBA_USERMAP_1_ACTIVE='no'
SAMBA_USERMAP_1_EISNAME='root'
SAMBA_USERMAP_1_WINNAME_N=1
SAMBA_USERMAP_1_WINNAME_1='administrator'



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
    local configFile=${1}
    {
    # ------------------------------------------------------------------------
    printgpl -conf ${packageName} "2014-09-21" "Y. Schumann <yves@eisfair.org>"
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    printgroup "Configuration of user mappings"
    # ------------------------------------------------------------------------
    printvar "SAMBA_USERMAP_N"
    idx=1
    while [ "${idx}" -le "${SAMBA_USERMAP_N}" ] ; do
        printvar "SAMBA_USERMAP_${idx}_ACTIVE"
        printvar "SAMBA_USERMAP_${idx}_EISNAME"
        printvar "SAMBA_USERMAP_${idx}_WINNAME_N"
        idx2=1
        eval amountOfMappings='${SAMBA_USERMAP_'${idx}'_WINNAME_N}'
        amountOfMappings=${amountOfMappings:-0} # Set to 0 if empty
        while [ "${idx2}" -le "${amountOfMappings}" ] ; do
            printvar "SAMBA_USERMAP_${idx}_WINNAME_${idx2}"
            idx2=$((idx2+1))
        done
        idx=$((idx+1))
    done

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------

    } > ${configFile}
    # Set rights
    chmod 0600 ${configFile}
    chown root ${configFile}
}



# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
# Write default config file
if [ -f /etc/config.d/${packageName} ] ; then
    mecho --info -n "Updating configuration."
else
    mecho --info -n "Creating configuration."
fi

makeConfigFile /etc/default.d/${packageName}

# Update from old version
mecho --info -n "."
renameOldVariables

# Write new config file
mecho --info -n "."
makeConfigFile /etc/config.d/${packageName}

mecho --info " Finished."

exit 0
