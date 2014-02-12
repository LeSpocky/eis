#!/bin/sh
# restore mysql backups
 
MyUSER="root"
DATA_DIR="/var/lib/mysql"
BACKUP_DIR="/var/lib/mysql_backup"

#-------------------------------------------------------------------------------
# extract dump
restore_mysql_database()
{
    local backupname="$1"
    local database_only_name=`echo $backupname | sed "s/\(-........-..\....\...\)//"`
    mkdir -p -m 0770 /var/lib/mysql/$database_only_name
    chown mysql:root /var/lib/mysql/$database_only_name
    gunzip < ${BACKUP_DIR}/${dbname} | mysql -u $MyUSER "$database_only_name"
    if [ "$?" -eq 0 ] ; then
        echo "database restored: $dbname" | logger -t 'mysql-restore' -p 'local5.info'
        echo "Database restored: $database_only_name    [ Ok ]"
    fi
    sleep 3
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
