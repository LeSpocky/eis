#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/config.d/cui.sh - menu configuration script
#
# Creation:     2005-08-07  dv
# Last Update:  $Id: cui.sh 24471 2010-06-10 21:14:01Z schlotze $
#
#------------------------------------------------------------------------------

cp -p /etc/config.d/cui /etc/cui.conf
chmod 0644 /etc/cui.conf
chown root /etc/cui.conf

exit 0
