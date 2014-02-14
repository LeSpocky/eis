#!/bin/sh
# restore mysql backups
 
MyUSER="root"
DATA_DIR="/var/lib/mysql"
BACKUP_DIR="/var/lib/mysql_backup"

#-------------------------------------------------------------------------------
# check if password set
mysqladmin -u root status >/dev/null 2>&1
if [ "$?" -eq 1 ] ; then
    echo "Passwort fail for login with MySQL user root@localhost!" | logger -t 'mysql-restore' -p 'local5.error'
    echo ""
    echo "MySQL user root@localhost password not set or false!"
    sleep 2
    exit 1
fi

#-------------------------------------------------------------------------------
# extract dump
restore_mysql_database()
{
    local backupname="$1"
    local database_only_name=`echo $backupname | sed "s/\(-........-..\....\...\)//"`
    mkdir -p -m 0770 /var/lib/mysql/$database_only_name
    chown mysql:mysql /var/lib/mysql/$database_only_name
    gunzip ${BACKUP_DIR}/${backupname} -c | mysql -u $MyUSER ${database_only_name}
    if [ "$?" -eq 0 ] ; then
        echo "database restored: $backupname" | logger -t 'mysql-restore' -p 'local5.info'
        echo "Database restored: $database_only_name    [ Ok ]"
    fi
    sleep 1
}

#-------------------------------------------------------------------------------
# select restore image
if [ "$1" = "--select" ] ; then
    /var/install/bin/list-files.cui -t "Select SQL file" \
                                -c "Restore from:" \
                                -p ${BACKUP_DIR} \
                                -f "*[0-2][0-9][0-9][0-9]*-[0-5][0-9].???*" \
                                -o 1 -d -n -w \
                                -s "/usr/bin/cui-mysql-restore.sh" \
                                --helpfile=/var/install/help/mysql \
                                --helpname=MYSQL_MENU_RESTORE \
                                --helpview
else
    restore_mysql_database "$1"
fi

exit 0
