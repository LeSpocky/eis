#!/bin/sh
# create backup for mysql tables
 
MyUSER="root"

# DO NOT BACKUP these databases
EXCLUDE="information_schema performance_schema test"
 
DATA_DIR="/var/lib/mysql"
BACKUP_DIR="/var/lib/mysql_backup"
EXPIRETIME=14
DATENOW=`date "+%Y%m%d-%H"`
 
# force create $BACKUP_DIR
mkdir -p -m 0700 $BACKUP_DIR

#-------------------------------------------------------------------------------
# check if password set
mysqladmin -u root status >/dev/null 2>&1
if [ "$?" -eq 1 ] ; then
    echo "Passwort fail for login with MySQL user root@localhost!" | logger -t 'mysql-backup' -p 'local5.error'
    echo ""
    echo "MySQL user root@localhost password not set or false!"
    sleep 2
    exit 1
fi

#-------------------------------------------------------------------------------
# write dump
backup_mysql_database()
{
    local lastupdate=""
    local dbname="$1"
    echo "database: $dbname" | logger -t 'mysql-backup' -p 'local5.info'
    lastupdate=$(mysql -u $MyUSER -Bse "SELECT DATE_FORMAT(UPDATE_TIME,'%Y%m%d-%H' ) FROM information_schema.tables WHERE table_schema='$dbname' GROUP BY TABLE_SCHEMA ORDER BY UPDATE_TIME DESC")
    [ -z "$lastupdate" -o "$lastupdate" = "NULL" ] && lastupdate="$DATENOW"
    mysqldump -u $MyUSER --hex-blob --events $dbname | gzip -9 > ${BACKUP_DIR}/${dbname}-${lastupdate}.sql.gz
    [ "$?" = "1" ] && sleep 2
}

#-------------------------------------------------------------------------------
# select database or backup all
if [ -n "$1" ] ; then
    if [ "$1" = "--select" ] ; then
        /var/install/bin/list-files.cui -t "Select database for backup"\
                                -c "Database:"\
                                -p ${DATA_DIR} \
                                -o 2 -d -w \
                                -s "/usr/bin/cui-mysql-backup.sh" \
                                --helpfile=/var/install/help/mysql \
                                --helpname=MYSQL_MENU_BACKUP
    else
        backup_mysql_database "$1"
    fi
else
    # get all database names
    DBS="$(mysql -u $MyUSER -Bse 'show databases')"
    [ "$?" = "1" ] && exit 1
    for db in $DBS
    do
        skipdb=0
        if [ -n "$EXCLUDE" ] ; then
            for i in $EXCLUDE
            do
                [ "$db" = "$i" ] && skipdb=1
            done
        fi
        [ "$skipdb" = "0" ] && backup_mysql_database "$db"
    done
    #remove old backups
    #find $BACKUP_DIR -mtime +${EXPIRETIME} -exec rm {} \;
fi

exit 0
