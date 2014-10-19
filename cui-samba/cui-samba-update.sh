#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/samba-update.sh - creating or updating
#                                             /etc/config.d/samba
#
# Copyright (c) 2014 the eisfair team <team@eisfair.org>
#
# Creation   : 2014-04-29 starwarsfan
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
#set -x

packageName=samba

. /var/install/include/eislib
. /var/install/include/configlib

# Load default config values
. /etc/default.d/samba.global.default
. /etc/default.d/samba.share.default

START_SAMBA='no'

SAMBA_INTERFACES=${INTERFACES}
SAMBA_HOSTS_ALLOW=${HOSTS_ALLOW}
SAMBA_HOSTS_DENY=${HOSTS_DENY}
SAMBA_SERVER_STRING=${SERVER_STRING}

SAMBA_ADVANCED_SETTINGS='no'
SAMBA_BIND_INTERFACES_ONLY=${BIND_INTERFACES_ONLY}
SAMBA_DEADTIME=${DEADTIME}
SAMBA_DEFAULT_CASE=${DEFAULT_CASE}
SAMBA_DISABLE_NETBIOS=${DISABLE_NETBIOS}
SAMBA_DNS_PROXY=${DNS_PROXY}
SAMBA_DOMAIN_MASTER=${DOMAIN_MASTER}
SAMBA_ENCRYPT_PASSWORDS=${ENCRYPT_PASSWORDS}
SAMBA_GUEST_OK=${GUEST_OK}
SAMBA_GUEST_ONLY=${GUEST_ONLY}
SAMBA_INVALID_USERS=${INVALID_USERS}
SAMBA_LOAD_PRINTERS=${LOAD_PRINTERS}
SAMBA_MAX_CONNECTIONS=${MAX_CONNECTIONS}
SAMBA_NETBIOS_NAME=${NETBIOS_NAME}
SAMBA_PREFERRED_MASTER=${PREFERRED_MASTER}
SAMBA_PRESERVE_CASE=${PRESERVE_CASE}
SAMBA_PRINTABLE=${PRINTABLE}
SAMBA_SECURITY=${SECURITY}
SAMBA_SOCKET_OPTIONS=${SOCKET_OPTIONS}
SAMBA_STRICT_SYNC=${STRICT_SYNC}
SAMBA_SYNC_ALWAYS=${SYNC_ALWAYS}
SAMBA_SYSLOG_LEVEL=${SYSLOG_LEVEL}
SAMBA_SYSLOG_ONLY=${SYSLOG_ONLY}
SAMBA_WORKGROUP=${WORKGROUP}

SAMBA_SHARE_HOMES_COMMENT='Home directories on %h'
SAMBA_SHARE_HOMES_ACTIVE='yes'
SAMBA_SHARE_HOMES_ADVANCED_SETTINGS='no'
SAMBA_SHARE_HOMES_CREATE_MASK=${CREATE_MASK}
SAMBA_SHARE_HOMES_DIRECTORY_MASK=${DIRECTORY_MASK}
SAMBA_SHARE_HOMES_WRITEABLE=${WRITEABLE}
SAMBA_SHARE_HOMES_VALID_USERS='%S root'
SAMBA_SHARE_HOMES_FORCE_CREATE_MODE=${FORCE_CREATE_MODE}
SAMBA_SHARE_HOMES_FORCE_DIRECTORY_MODE=${FORCE_DIRECTORY_MODE}

SAMBA_SHARE_N=1
SAMBA_SHARE_1_NAME=${SHARE_NAME}
SAMBA_SHARE_1_COMMENT='Share ... on %h'
SAMBA_SHARE_1_ACTIVE='no'
SAMBA_SHARE_1_CREATE_MASK=${CREATE_MASK}
SAMBA_SHARE_1_DIRECTORY_MASK=${DIRECTORY_MASK}
SAMBA_SHARE_1_DIRECTORY_PATH=${DIRECTORY_PATH}
SAMBA_SHARE_1_WRITEABLE=${WRITEABLE}
SAMBA_SHARE_1_BROWSEABLE=${BROWSEABLE}
SAMBA_SHARE_1_VALID_USERS=${VALID_USERS}
SAMBA_SHARE_1_FORCE_CREATE_MODE=${FORCE_CREATE_MODE}
SAMBA_SHARE_1_FORCE_DIRECTORY_MODE=${FORCE_DIRECTORY_MODE}



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
    printgpl -conf ${packageName} "2014-09-18" "Y. Schumann <yves@eisfair.org>"
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    printgroup "General configuration"
    # ------------------------------------------------------------------------
    printvar "START_SAMBA" "Use: yes or no"
    printvar "SAMBA_WORKGROUP" "Workgroup name of windows clients"

    # ------------------------------------------------------------------------
    printgroup "Basic configuration"
    # ------------------------------------------------------------------------
    printvar "SAMBA_INTERFACES" "Userdefined interfaces for Samba."
    printcomment "Be careful, use this only, if you don't want to use all interfaces from /etc/config.d/base You have to specify interfaces like this: '192.168.7.1/255.255.255.0'"
    printvar "SAMBA_HOSTS_ALLOW" "If your network is 192.168.6.0/24 and you want to grant access also to net 192.168.7.0/24, you have to add this here like this: '192.168.7.0/24'"
    printvar "SAMBA_HOSTS_DENY" "The opposite of SAMBA_HOSTS_ALLOW - hosts listed here are NOT permitted access to services unless the specific services have their own lists to override this one."
    printvar "SAMBA_SERVER_STRING" "Comment in network neighborhood. Empty for no string or anything else for your string"

    # ------------------------------------------------------------------------
    printgroup "Advanced configuration"
    # ------------------------------------------------------------------------
    printvar "SAMBA_ADVANCED_SETTINGS"      "Activate samba advanced settings, yes or no"

    printvar "SAMBA_BIND_INTERFACES_ONLY"   "Limit what interfaces on a machine will serve SMB requests"
    printvar "SAMBA_DEADTIME"               "The value of the parameter (a decimal integer) represents the number of minutes of inactivity before a connection is considered dead, and it is disconnected"
    printvar "SAMBA_DEFAULT_CASE"           "Controls what the default case is for new filenames"
    printvar "SAMBA_DISABLE_NETBIOS"        "Disable netbios support"
    printvar "SAMBA_DNS_PROXY"              "When acting as a WINS server and finding that a NetBIOS name has not been registered, should treat the NetBIOS name word-for-word as a DNS name and do a lookup with the DNS server for that name on behalf of the name-querying client."
    printvar "SAMBA_DOMAIN_MASTER"          "Enable WAN-wide browse list collation"
    printvar "SAMBA_ENCRYPT_PASSWORDS"      "Controls whether encrypted passwords will be negotiated with the client."
    printvar "SAMBA_GUEST_OK"               "No password is required. Privileges will be those of the guest account."
    printvar "SAMBA_GUEST_ONLY"             "Only guest connections to the service are permitted."
    printvar "SAMBA_INVALID_USERS"          "List of users that should not be allowed to login to this service."
    printvar "SAMBA_LOAD_PRINTERS"          "Controls whether all printers in the printcap will be loaded for browsing by default."
    printvar "SAMBA_MAX_CONNECTIONS"        "Number of simultaneous connections to a service to be limited."
    printvar "SAMBA_NETBIOS_NAME"           "Sets the NetBIOS name by which a Samba server is known."
    printvar "SAMBA_PREFERRED_MASTER"       "Should this be a preferred master browser for its workgroup."
    printvar "SAMBA_PRESERVE_CASE"          "Filenames are created with the case that the client passes, or if they are forced to be the default case."
    printvar "SAMBA_PRINTABLE"              "Clients may open, write to and submit spool files on the directory specified for the service."
    printvar "SAMBA_SECURITY"               "Affects how clients respond to Samba."
    printvar "SAMBA_SOCKET_OPTIONS"         "Set socket options to be used when talking with the client."
    printvar "SAMBA_STRICT_SYNC"            "Setting this parameter to no (the default) means that smbd ignores the Windows applications requests for a sync call."
    printvar "SAMBA_SYNC_ALWAYS"            "Controls whether writes will always be written to stable storage before the write call returns."
    printvar "SAMBA_SYSLOG_LEVEL"           "Maps how Samba debug messages are logged onto the system syslog logging levels."
    printvar "SAMBA_SYSLOG_ONLY"            "Samba debug messages are logged into the system syslog only, and not to the debug log files."

    # ------------------------------------------------------------------------
    printgroup "Homes configuration"
    # ------------------------------------------------------------------------

    printvar "SAMBA_SHARE_HOMES_COMMENT"                "Comment string to associate with the home share."
    printvar "SAMBA_SHARE_HOMES_ACTIVE"                 "Should user's home available as a share."
    printvar "SAMBA_SHARE_HOMES_ADVANCED_SETTINGS"      "Activate configuration of advanced settings."
    printvar "SAMBA_SHARE_HOMES_CREATE_MASK"            "A bit-wise MASK for the UNIX modes of a file."
    printvar "SAMBA_SHARE_HOMES_DIRECTORY_MASK"         "A bit-wise MASK for the UNIX modes of a file."
    printvar "SAMBA_SHARE_HOMES_WRITEABLE"              "Users of a service may create or modify files in the service's directory."
    printvar "SAMBA_SHARE_HOMES_VALID_USERS"            "List of users that should be allowed to login to this service."
    printvar "SAMBA_SHARE_HOMES_FORCE_CREATE_MODE"      "A bit-wise MASK for the UNIX modes of a file."
    printvar "SAMBA_SHARE_HOMES_FORCE_DIRECTORY_MODE"   "A bit-wise MASK for the UNIX modes of a file."

    # ------------------------------------------------------------------------
    printgroup "Share configuration"
    # ------------------------------------------------------------------------
    printvar "SAMBA_SHARE_N"            "Number of shares"
    idx=1
    while [ "${idx}" -le "${SAMBA_SHARE_N}" ] ; do
        printvar "SAMBA_SHARE_${idx}_NAME"                  "The name of the share."
        printvar "SAMBA_SHARE_${idx}_COMMENT"               "Comment string to associate with the new share."
        printvar "SAMBA_SHARE_${idx}_ACTIVE"                "Should this share be activated or not."
        printvar "SAMBA_SHARE_${idx}_CREATE_MASK"           "A bit-wise MASK for the UNIX modes of a file."
        printvar "SAMBA_SHARE_${idx}_DIRECTORY_MASK"        "A bit-wise MASK for the UNIX modes of a file."
        printvar "SAMBA_SHARE_${idx}_DIRECTORY_PATH"        "The path to the directory which should be shared."
        printvar "SAMBA_SHARE_${idx}_WRITEABLE"             "Users of a service may create or modify files in the service's directory."
        printvar "SAMBA_SHARE_${idx}_BROWSEABLE"            "Controls wether the share is seen in the list of availbale shares."
        printvar "SAMBA_SHARE_${idx}_VALID_USERS"           "List of users that should be allowed to login to this service."
        printvar "SAMBA_SHARE_${idx}_FORCE_CREATE_MODE"     "A bit-wise MASK for the UNIX modes of a file."
        printvar "SAMBA_SHARE_${idx}_FORCE_DIRECTORY_MODE"  "A bit-wise MASK for the UNIX modes of a file."
        idx=$((idx+1))
    done

    # ------------------------------------------------------------------------
    printgroup "SAMBA advanced settings"
    # ------------------------------------------------------------------------

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
