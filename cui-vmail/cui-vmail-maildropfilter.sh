#!/bin/sh
#-----------------------------------------------------------------------------
# Creation:     2010-05-28 Jens Vehlhaber  jv <jens(at)eisfair(dot)org>
#-----------------------------------------------------------------------------
if [ "$1" = "-v" ]; then
    . /var/install/include/eislib
    clear
    sverb="-v"
fi
. /etc/config.d/vmail
if [ "$VMAIL_SQL_HOST" = 'localhost' ]; then
    vmail_sql_connect="unix:/run/mysqld/mysqld.sock"
else
    vmail_sql_connect="inet:$VMAIL_SQL_HOST"
fi
# get uid/gid for user vmail:
uidvmail=$(id -u mail)
gidvmail=$(id -g mail)
# run program:
/usr/bin/mysql2sieve $sverb -s $vmail_sql_connect -d $VMAIL_SQL_DATABASE -u $VMAIL_SQL_USER -p $VMAIL_SQL_PASS -b $uidvmail -c $gidvmail
[ "$1" = "-v" ] && anykey
exit 0
