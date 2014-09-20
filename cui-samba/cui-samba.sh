#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-samba.sh - configuration generator script for Samba
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
. /var/install/include/eislib
. /etc/config.d/base
. /etc/config.d/samba

sambaNativeConfig=/tmp/smb.conf

# --------------------------------------------
# Create global section of samba configuration
createGlobalSambaConfiguration()
{
    sed -e "s/BIND_INTERFACES_ONLY/${BIND_INTERFACES_ONLY}/g" \
        -e "s/DEADTIME/${DEADTIME}/g" \
        -e "s/DEFAULT_CASE/${DEFAULT_CASE}/g" \
        -e "s/DISABLE_NETBIOS/${DISABLE_NETBIOS}/g" \
        -e "s/DNS_PROXY/${DNS_PROXY}/g" \
        -e "s/DOMAIN_MASTER/${DOMAIN_MASTER}/g" \
        -e "s/ENCRYPT_PASSWORDS/${ENCRYPT_PASSWORDS}/g" \
        -e "s/GUEST_OK/${GUEST_OK}/g" \
        -e "s/GUEST_ONLY/${GUEST_ONLY}/g" \
        -e "s/HOSTS_ALLOW/${HOSTS_ALLOW}/g" \
        -e "s/HOSTS_DENY/${HOSTS_DENY}/g" \
        -e "s/INTERFACES/${INTERFACES}/g" \
        -e "s/INVALID_USERS/${INVALID_USERS}/g" \
        -e "s/LOAD_PRINTERS/${LOAD_PRINTERS}/g" \
        -e "s/MAX_CONNECTIONS/${MAX_CONNECTIONS}/g" \
        -e "s/NETBIOS_NAME/${NETBIOS_NAME}/g" \
        -e "s/PREFERRED_MASTER/${PREFERRED_MASTER}/g" \
        -e "s/PRESERVE_CASE/${PRESERVE_CASE}/g" \
        -e "s/PRINTABLE/${PRINTABLE}/g" \
        -e "s/SECURITY/${SECURITY}/g" \
        -e "s/SERVER_STRING/${SERVER_STRING}/g" \
        -e "s/SOCKET_OPTIONS/${SOCKET_OPTIONS}/g" \
        -e "s/STRICT_SYNC/${STRICT_SYNC}/g" \
        -e "s/SYNC_ALWAYS/${SYNC_ALWAYS}/g" \
        -e "s/SYSLOG/${SYSLOG}/g" \
        -e "s/SYSLOG_ONLY/${SYSLOG_ONLY}/g" \
        -e "s/WORKGROUP/${WORKGROUP}/g" \
        /etc/default.d/samba.global.template > ${sambaNativeConfig}
}

# --------------------------------------------
# Create share sections of samba configuration
createShareConfiguration()
{
    sed -e "s/SHARE_NAME/${SHARE_NAME}/g" \
        -e "s/CREATE_MASK/${CREATE_MASK}/g" \
        -e "s/DIRECTORY_MASK/${DIRECTORY_MASK}/g" \
        -e "s/DIRECTORY_PATH/${DIRECTORY_PATH}/g" \
        -e "s/WRITEABLE/${WRITEABLE}/g" \
        /etc/default.d/samba.share.template >> ${sambaNativeConfig}
}

# ----------------------------------------------------------------------------
# Main
if [ "$START_SAMBA" = 'yes' ] ; then
    createGlobalSambaConfiguration
    createShareConfiguration
    rc-update add samba
else
    rc-update del samba
fi
exit 0
