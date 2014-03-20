#!/bin/sh

. /etc/config.d/vmail

if [ "$VMAIL_SQL_HOST" = 'localhost' ]; then
    vmail_sql_connect="unix:/run/mysqld/mysqld.sock"
else
    vmail_sql_connect="inet:$VMAIL_SQL_HOST"
fi

# get uid/gid for user vmail:
uidvmail=$(id -u mail)
gidvmail=$(id -g mail)

if [ "$1" = "-v" ]; then
    echo -n "" > /var/log/mysql2sieve.log
    /usr/bin/mysql2sieve -v -s $vmail_sql_connect -d $VMAIL_SQL_DATABASE -u $VMAIL_SQL_USER -p $VMAIL_SQL_PASS -b $uidvmail -c $gidvmail >> /var/log/mysql2sieve.log
else
    /usr/bin/mysql2sieve -s $vmail_sql_connect -d $VMAIL_SQL_DATABASE -u $VMAIL_SQL_USER -p $VMAIL_SQL_PASS -b $uidvmail -c $gidvmail
fi

exit 0
