#!/bin/bash
# ----------------------------------------------------------------------------
# /tmp/install.sh - quassel-core installation
#
# Creation   : 2009-12-14 Marcel Weiler
# Last update: $Id: install.sh 32624 2013-01-09 20:39:54Z starwarsfan $
#
# Copyright (c) 2001-2010 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/quassel-core-install-trace_$$.log
#set -x

# include eislib
. /var/install/include/eislib

# set package name
packageName=quassel-core

# some variables
QUASSEL_GROUP=quassel
QUASSEL_GROUP_ID=179
QUASSEL_USER=quasselcore
QUASSEL_USER_ID=179
QUASSEL_HOME=/data/packages/quassel-core
QUASSEL_LOG=/var/log/quassel-core
QUASSEL_CERT=${QUASSEL_HOME}/quasselCert.pem

# ----------------------------------------------------------------------------
# Creating Data Directory
# ----------------------------------------------------------------------------
if [ ! -d ${QUASSEL_HOME} ] ; then
    mecho -info "Creating data directory in ${QUASSEL_HOME}"
    mkdir -p ${QUASSEL_HOME}
fi

# ----------------------------------------------------------------------------
# Add Group and User
# ----------------------------------------------------------------------------
/var/install/bin/add-group ${QUASSEL_GROUP} ${QUASSEL_GROUP_ID} >/dev/null
/var/install/bin/add-user ${QUASSEL_USER} '*' ${QUASSEL_USER_ID} ${QUASSEL_GROUP_ID} "System User for quassel-core" ${QUASSEL_HOME} /bin/false >/dev/null

# ----------------------------------------------------------------------------
# Change rights of QUASSEL_HOME
# ----------------------------------------------------------------------------
chown ${QUASSEL_USER}:${QUASSEL_GROUP} -R ${QUASSEL_HOME}
chmod 755 ${QUASSEL_HOME}

# ----------------------------------------------------------------------------
# Creating Log Directory
# ----------------------------------------------------------------------------
if [ ! -d ${QUASSEL_LOG} ] ; then
    mecho -info "Creating log directory in ${QUASSEL_LOG}"
    mkdir -p ${QUASSEL_LOG}
    chown ${QUASSEL_USER}:${QUASSEL_GROUP} -R ${QUASSEL_LOG}
fi

# ----------------------------------------------------------------------------
# Creating SSL Certificate
# ----------------------------------------------------------------------------

# If there is no CA-Certifcate, then create one
if [ ! -f /usr/local/ssl/certs/ca.pem ] ; then
    mecho -info "Creating CA for SSL ..."
    /var/install/bin/certs-create-tls-certs ca batch
fi

# Check if there is already a certificate or a link to one,
# if not, then create it
if [ ! -L /usr/local/ssl/certs/quassel-core.pem -a \
     ! -f /usr/local/ssl/certs/quassel-core.pem ] ; then
    mecho -info "Creating quassel-core.pem"
    mecho -warn "Notice: The Common Name (you will type it in a moment) has to be the ServerName!"
    /var/install/bin/certs-create-tls-certs client batch "quassel-core"
fi

# Now create a link to the certificate in the quassel data directory
if [ ! -L ${QUASSEL_CERT} -a \
     ! -f ${QUASSEL_CERT} ] ; then
    ln -s /usr/local/ssl/certs/quassel-core.pem ${QUASSEL_CERT}
fi

# ----------------------------------------------------------------------------
# Add menu
# ----------------------------------------------------------------------------
/var/install/bin/add-menu setup.services.menu setup.services.${packageName}.menu "Quassel-Core"

# ----------------------------------------------------------------------------
# Create default config or update current config
# ----------------------------------------------------------------------------
/var/install/config.d/${packageName}-update.sh

exit 0
# ----------------------------------------------------------------------------
# End
# ----------------------------------------------------------------------------
