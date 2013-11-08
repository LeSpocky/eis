#!/bin/sh
 # mysqlbackup.sh
 
MyUSER="root"
MyPASS="-p"

# DO NOT BACKUP these databases
IGGY="information_schema performance_schema test"
 
BACKUP_DIR=${1:-/var/lib/mysql_backup}
EXPIRETIME=14
DATE=`date "+%Y%m%d-%H"`
 
# Sicherstellen, dass $BACKUP_DIR existiert
mkdir -p $BACKUP_DIR
chmod 0700 $BACKUP_DIR


# get all database names
DBS="$(mysql -u $MyUSER $MyPASS -Bse 'show databases')" 

# Backups erstellen
for db in $DBS
do
    skipdb=0
    if [ -n "$IGGY" ] ; then
        for i in $IGGY
        do
            [ "$db" = "$i" ] && skipdb=1 || :
        done
    fi
    if [ "$skipdb" = "0" ] ; then
        LASTUPDATE=$(mysql -u $MyUSER $MyPASS -Bse "SELECT DATE_FORMAT(UPDATE_TIME,'%Y%m%d-%H' ) FROM information_schema.tables WHERE table_schema='$db' GROUP BY TABLE_SCHEMA ORDER BY UPDATE_TIME DESC")
        [ -z "$LASTUPDATE" -o "$LASTUPDATE" = "NULL" ] && LASTUPDATE="$DATE"
        mysqldump -u $MyUSER $MyPASS --hex-blob $db | gzip -9 > ${BACKUP_DIR}/${db}-${LASTUPDATE}.sql.gz
    fi
done
 
 
#Alte Backups loeschen
#find $BACKUP_DIR -mtime +${EXPIRETIME} -exec rm {} \;
