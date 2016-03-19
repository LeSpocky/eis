#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/skeleton-trace$$.log
#set -x

# include eisfair config file
. /etc/config.d/skeleton

#----------------------------------------------------------------------------------------
# creating/edit config file - use one of the examples 1...3
#----------------------------------------------------------------------------------------

# 1. example edit/patch exists config file (better) -------------------------------------
sed -i "s|^skeleton_data_port=.*|skeleton_data_port=${SKELETON_PORT}|" /etc/skeleton/skeleton.conf
sed -i "s|^listen_address=.*|listen_address=${SKELETON_BIND}|"         /etc/skeleton/skeleton.conf
sed -i "s|^syslog_enable=.*|syslog_enable=YES|"                        /etc/skeleton/skeleton.conf


# 2. example remove line if exist and append new value ----------------------------------
# port
sed -i '/^skeleton_data_port/d'               /etc/skeleton/skeleton.conf
echo "skeleton_data_port=${SKELETON_PORT}" >> /etc/skeleton/skeleton.conf
# address
sed -i '/^listen_address=/d'                  /etc/skeleton/skeleton.conf
echo "listen_address=${SKELETON_BIND}"     >> /etc/skeleton/skeleton.conf
# syslog
sed -i '/^syslog_enable=/d'                   /etc/skeleton/skeleton.conf
echo "syslog_enable=YES"                   >> /etc/skeleton/skeleton.conf


# 3. example write new config (overwrite) -----------------------------------------------
cat > /etc/skeleton/skeleton.conf <<EOF
skeleton_data_port=${SKELETON_PORT}
listen_address=${SKELETON_BIND}
syslog_enable=YES
# all required values of configuration:
# ...
EOF


#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat > /etc/logrotate.d/skeleton <<EOF
/var/log/skeleton*log {
    ${SKELETON_LOG_INTERVAL}
    missingok
	rotate ${SKELETON_LOG_MAXCOUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet skeleton reload > /dev/null 2>/dev/null || true
    endscript
}
EOF

#----------------------------------------------------------------------------------------
exit 0
