#!/bin/sh
#-----------------------------------------------------------------------------
# /var/install/config.d/cui.sh - menu configuration script
# Copyright (c) 2001-2014 The Eisfair Team <team@eisfair.org>
#-----------------------------------------------------------------------------

cp -p /etc/config.d/cui /etc/cui.conf
chmod 0644 /etc/cui.conf
chown root /etc/cui.conf

exit 0
