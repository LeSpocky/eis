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
    sed -e "s/BIND_INTERFACES_ONLY/${SAMBA_BIND_INTERFACES_ONLY}/g" \
        -e "s/DEADTIME/${SAMBA_DEADTIME}/g" \
        -e "s/DEFAULT_CASE/${SAMBA_DEFAULT_CASE}/g" \
        -e "s/DISABLE_NETBIOS/${SAMBA_DISABLE_NETBIOS}/g" \
        -e "s/DNS_PROXY/${SAMBA_DNS_PROXY}/g" \
        -e "s/DOMAIN_MASTER/${SAMBA_DOMAIN_MASTER}/g" \
        -e "s/ENCRYPT_PASSWORDS/${SAMBA_ENCRYPT_PASSWORDS}/g" \
        -e "s/GUEST_OK/${SAMBA_GUEST_OK}/g" \
        -e "s/GUEST_ONLY/${SAMBA_GUEST_ONLY}/g" \
        -e "s#HOSTS_ALLOW#${SAMBA_HOSTS_ALLOW}#g" \
        -e "s/HOSTS_DENY/${SAMBA_HOSTS_DENY}/g" \
        -e "s/INTERFACES/${SAMBA_INTERFACES}/g" \
        -e "s/INVALID_USERS/${SAMBA_INVALID_USERS}/g" \
        -e "s/LOAD_PRINTERS/${SAMBA_LOAD_PRINTERS}/g" \
        -e "s/MAX_CONNECTIONS/${SAMBA_MAX_CONNECTIONS}/g" \
        -e "s/NETBIOS_NAME/${SAMBA_NETBIOS_NAME}/g" \
        -e "s/PREFERRED_MASTER/${SAMBA_PREFERRED_MASTER}/g" \
        -e "s/PRESERVE_CASE/${SAMBA_PRESERVE_CASE}/g" \
        -e "s/PRINTABLE/${SAMBA_PRINTABLE}/g" \
        -e "s/SECURITY/${SAMBA_SECURITY}/g" \
        -e "s/SERVER_STRING/${SAMBA_SERVER_STRING}/g" \
        -e "s/SOCKET_OPTIONS/${SAMBA_SOCKET_OPTIONS}/g" \
        -e "s/STRICT_SYNC/${SAMBA_STRICT_SYNC}/g" \
        -e "s/SYNC_ALWAYS/${SAMBA_SYNC_ALWAYS}/g" \
        -e "s/SYSLOG/${SAMBA_SYSLOG}/g" \
        -e "s/SYSLOG_ONLY/${SAMBA_SYSLOG_ONLY}/g" \
        -e "s/WORKGROUP/${SAMBA_WORKGROUP}/g" \
        /etc/default.d/samba.global.template > ${sambaNativeConfig}
}

# --------------------------------------------
# Create share sections of samba configuration
createShareConfiguration()
{
    idx=1
    while [ ${idx} -le ${SAMBA_SHARE_N} ] ; do
        eval SAMBA_SHARE_NAME='$SAMBA_SHARE_'${idx}'_NAME'
        eval SAMBA_SHARE_CREATE_MASK='$SAMBA_SHARE_'${idx}'_CREATE_MASK'
        eval SAMBA_SHARE_DIRECTORY_MASK='$SAMBA_SHARE_'${idx}'_DIRECTORY_MASK'
        eval SAMBA_SHARE_DIRECTORY_PATH='$SAMBA_SHARE_'${idx}'_DIRECTORY_PATH'
        eval SAMBA_SHARE_WRITEABLE='$SAMBA_SHARE_'${idx}'_WRITEABLE'

        sed -e "s/SHARE_NAME/${SAMBA_SHARE_NAME}/g" \
            -e "s/CREATE_MASK/${SAMBA_SHARE_CREATE_MASK}/g" \
            -e "s/DIRECTORY_MASK/${SAMBA_SHARE_DIRECTORY_MASK}/g" \
            -e "s#DIRECTORY_PATH#${SAMBA_SHARE_DIRECTORY_PATH}#g" \
            -e "s/WRITEABLE/${SAMBA_SHARE_WRITEABLE}/g" \
            /etc/default.d/samba.share.template >> ${sambaNativeConfig}
        idx=$((idx+1))
    done
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
