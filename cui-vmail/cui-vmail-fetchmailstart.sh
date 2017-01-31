#!/bin/sh

. /etc/config.d/vmail

logging="-s"
[ "$FETCHMAIL_LOG" = "yes" ] && logging="--syslog"

if [ "$1" = "-v" ]; then
    mkdir -p -m0755 /var/log/fetchmail
    logging="-L /var/log/fetchmail/fetchmail.log"
    echo -n "" > /var/log/fetchmail/fetchmail.log
fi

fetchfile=".fetchmailrc.$$"

/usr/bin/mysql2fetchmail -t /var/spool/postfix/virtual/${fetchfile} -a 0 -u $VMAIL_SQL_USER -s $VMAIL_SQL_HOST -d $VMAIL_SQL_DATABASE -p $VMAIL_SQL_PASS -e $VMAIL_SQL_ENCRYPT_KEY
/usr/bin/fetchmail -t ${FETCHMAIL_TIMEOUT} -f /var/spool/postfix/virtual/$fetchfile $logging -B 300 -b 1 --nobounce --sslcertpath /etc/ssl/certs 2>/dev/null

rm -f /var/spool/postfix/virtual/$fetchfile

[ "$1" = "-v" ] && echo "--- End ---" >> /var/log/fetchmail/fetchmail.log

exit 0
