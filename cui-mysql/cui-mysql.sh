#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/mysql-trace$$.log
#set -x

. /etc/config.d/mysql

#----------------------------------------------------------------------------------------
# creating/edit config file
#----------------------------------------------------------------------------------------

[ -e /var/lib/mysql/mysql ] || rc-service --quiet mysql setup

#/usr/bin/mysqladmin -u root password 'new-password'
#/usr/bin/mysqladmin -u root -h alpeis password 'new-password'

#sed -i -e "s/bind-address=.*/bind-address=${MYSQL_BIND}/" /etc/mysql/my.cnf

# cat > /etc/mysql/my.cnf <<EOF

#EOF

#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat > /etc/logrotate.d/mysql <<EOF
/var/lib/mysql/*.err {
    ${MYSQL_LOG_INTERVAL}
    missingok
	rotate ${MYSQL_LOG_MAXCOUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet mysql reload > /dev/null 2>/dev/null || true
    endscript
}
EOF

exit 0
