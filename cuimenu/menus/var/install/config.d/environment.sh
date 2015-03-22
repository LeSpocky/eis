#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/config.d/environment.sh - apply script for environment
# Copyright (c) 2001-2015 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

wgetrcfile='/etc/wgetrc'
wgetrcfiles_auth='/root/.wgetrc'

### read configuration file
. /etc/config.d/environment

### remove default proxy script
rm -f /etc/profile.d/proxy.sh

### begin writing wgetrc config
cat >${wgetrcfile} <<EOF
#ca_directory=/usr/local/ssl/certs
check_certificate=off
EOF

### http proxy
if [ -n "$HTTP_PROXY" ]  ; then
    mkdir -p /etc/profile.d
    cat >/etc/profile.d/proxy.sh <<EOF
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTP_PROXY
export ftp_proxy=$HTTP_PROXY
EOF

    cat >>${wgetrcfile} <<EOF
use_proxy=on
http_proxy=$HTTP_PROXY
https_proxy=$HTTP_PROXY
ftp_proxy=$HTTP_PROXY
EOF

    old_umask=`umask`
    umask 077
    for rcfile in $wgetrcfiles_auth
    do
        if [ -n "$HTTP_PROXY_USER" ] ; then
            {
            echo "proxy_user=$HTTP_PROXY_USER"
            echo "proxy_password=$HTTP_PROXY_PASSWD"
            } > $rcfile
        else
            rm -f $rcfile
        fi
    done
    umask $old_umask
fi

exit 0
