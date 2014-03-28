#!/bin/sh
#-------------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#-------------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/mysql-trace$$.log
#set -x

. /etc/config.d/mysql

#-------------------------------------------------------------------------------
# setup defaults
#-------------------------------------------------------------------------------
[ -e /var/lib/mysql/mysql ] || rc-service --quiet mysql setup
mkdir -p    /var/lib/mysql_backup
chmod 0750  /var/lib/mysql_backup
chown mysql /var/lib/mysql_backup

#-------------------------------------------------------------------------------
# creating/edit config file
#-------------------------------------------------------------------------------
bindaddr="bind-address                = 127.0.0.1"
if [ "$MYSQL_NETWORK" = "yes" ] ; then
    bindaddr="#bind-address               = 127.0.0.1"
    [ -n "$MYSQL_BIND_IP_ADDRESS" ] && bindaddr="bind-address                = $MYSQL_BIND_IP_ADDRESS"
fi

# ---- count cpu cores ---------------------------------------------------------
ncpu=$(grep -c processor /proc/cpuinfo)
[ -z "$ncpu" ] && ncpu=1
ncpu=$(( $ncpu * 2 ))

# ---- set to 32/64Bit ---------------------------------------------------------
xarch=$(cat /etc/apk/arch)
[ "$xarch" = "x86_64" ] && thread_stack="256K" || thread_stack="192K"

# ---- set options for xx GB RAM -----------------------------------------------
blg="" # activate binlog
if [ "$MYSQL_RAM" = "256MB" ]; then
    blg="#"
    sort_buffer_size="256K"
    read_buffer_size="256K"
    read_rnd_buffer_size="256K"
    join_buffer_size="256K"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 134400K = 131.25MB
    ## Query Cache - global buffer
    query_cache_size="8M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="60"
    #thread_cache_size - recommend 5% (10%?) of max_connections
    thread_cache_size="5"
    ## Table and TMP settings
    tmp_table_size="16M"
    bulk_insert_buffer_size="8M"
    ## MyISAM Engine - global buffer
    key_buffer_size="4M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="32M"
    innodb_log_buffer_size="8M"

elif [ "$MYSQL_RAM" = "1GB" ]; then
    sort_buffer_size="256K"
    read_buffer_size="256K"
    read_rnd_buffer_size="256K"
    join_buffer_size="256K"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 134400K = 131.25MB
    ## Query Cache - global buffer
    query_cache_size="32M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="100"
    #thread_cache_size - recommend 5% (10%?) of max_connections
    thread_cache_size="8"
    ## Table and TMP settings
    tmp_table_size="64M"
    bulk_insert_buffer_size="64M"
    ## MyISAM Engine - global buffer
    key_buffer_size="16M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="128M"
    innodb_log_buffer_size="16M"

elif [ "$MYSQL_RAM" = "2GB" ]; then
    sort_buffer_size="256K"
    read_buffer_size="256K"
    read_rnd_buffer_size="256K"
    join_buffer_size="256K"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 672000K = 656.25MB
    ## Query Cache - global buffer
    query_cache_size="64M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="400"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="20"
    ## Table and TMP settings
    tmp_table_size="128M"
    bulk_insert_buffer_size="128M"
    ## MyISAM Engine - global buffer
    key_buffer_size="16M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="768M"
    innodb_log_buffer_size="32M"

elif [ "$MYSQL_RAM" = "4GB" ]; then
    sort_buffer_size="512K"
    read_buffer_size="512K"
    read_rnd_buffer_size="512K"
    join_buffer_size="512K"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 2368000K = 2.312G
    ## Query Cache - global buffer
    query_cache_size="128M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="600"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="30"
    ## Table and TMP settings
    tmp_table_size="512M"
    bulk_insert_buffer_size="512M"
    ## MyISAM Engine - global buffer
    key_buffer_size="32M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="1G"
    innodb_log_buffer_size="64M"

elif [ "$MYSQL_RAM" = "8GB" ]; then
    sort_buffer_size="512K"
    read_buffer_size="512K"
    read_rnd_buffer_size="512K"
    join_buffer_size="512K"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 4736000K = 4.625GB
    ## Query Cache - global buffer
    query_cache_size="256M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="1000"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="50"
    ## Table and TMP settings
    tmp_table_size="1G"
    bulk_insert_buffer_size="1G"
    ## MyISAM Engine - global buffer
    key_buffer_size="64M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="4G"
    innodb_log_buffer_size="128M"

elif [ "$MYSQL_RAM" = "16GB" ]; then
    sort_buffer_size="1M"
    read_buffer_size="1M"
    read_rnd_buffer_size="1M"
    join_buffer_size="1M"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 8832000K = 8.625GB
    ## Query Cache - global buffer
    query_cache_size="256M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="2000"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="100"
    ## Table and TMP settings
    tmp_table_size="1G"
    bulk_insert_buffer_size="1G"
    ## MyISAM Engine - global buffer
    key_buffer_size="128M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="10G"
    innodb_log_buffer_size="128M"

elif [ "$MYSQL_RAM" = "32GB" ]; then
    sort_buffer_size="1M"
    read_buffer_size="1M"
    read_rnd_buffer_size="1M"
    join_buffer_size="1M"
    binlog_cache_size="64K"
    ## total per-thread buffer memory usage: 8832000K = 8.625GB
    ## Query Cache - global buffer
    query_cache_size="256M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="2000"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="100"
    ## Table and TMP settings
    tmp_table_size="1G"
    bulk_insert_buffer_size="1G"
    ## MyISAM Engine - global buffer
    key_buffer_size="256M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="18G"
    innodb_log_buffer_size="128M"

elif [ "$MYSQL_RAM" = "64GB" ]; then
    ## Per-Thread Buffers * (max_connections) = total per-thread mem usage
    thread_stack="512K"
    sort_buffer_size="2M"
    read_buffer_size="2M"
    read_rnd_buffer_size="2M"
    join_buffer_size="2M"
    binlog_cache_size="128K"
    ## total per-thread buffer memory usage: 17664000K = 17.250GB
    ## Query Cache - global buffer
    query_cache_size="256M"
    ## Connections - multiplier for memory usage via per-thread buffers
    max_connections="2000"
    #thread_cache_size - recommend 5% of max_connections
    thread_cache_size="100"
    ## Table and TMP settings
    tmp_table_size="1G"
    bulk_insert_buffer_size="1G"
    ## MyISAM Engine - global buffer
    key_buffer_size="256M"
    ## InnoDB Plugin Independent Settings
    innodb_buffer_pool_size="38G"
    innodb_log_buffer_size="128M"
fi


# ---- write config file -------------------------------------------------------
cat > /etc/mysql/my.cnf <<EOF
[mysqld_safe]
#nice                       = -15
#syslog
#syslog-tag=mysqld

[client]
socket                      = /var/run/mysqld/mysqld.sock
default-character-set       = utf8

[mysqld]
## Charset and Collation
character-set-server        = utf8
collation-server            = utf8_general_ci

## Files
back_log                    = 300
open_files_limit            = 8192
$bindaddr
port                        = $MYSQL_CONNECT_PORT
socket                      = /var/run/mysqld/mysqld.sock
skip-external-locking
skip-name-resolve

## Logging
datadir                     = /var/lib/mysql
relay_log                   = mysql-relay-bin
relay_log_index             = mysql-relay-index
#log                        = mysql-gen.log
log_error                   = mysql-error.log
log_warnings
${blg}log_bin                     = mysql-bin
slow-query-log
slow-query-log-file         = mysql-slow.log
#log_queries_not_using_indexes
long_query_time             = 10    #default: 10
${blg}max_binlog_size             = 256M  #max size for binlog before rolling
${blg}expire_logs_days            = 4     #binlog files older than this will be purged

## Per-Thread Buffers * (max_connections) = total per-thread mem usage
thread_stack                = $thread_stack  #default: 32bit: 192K, 64bit: 256K
sort_buffer_size            = $sort_buffer_size
read_buffer_size            = $read_buffer_size
read_rnd_buffer_size        = $read_rnd_buffer_size
join_buffer_size            = $join_buffer_size
${blg}binlog_cache_size           = $binlog_cache_size

## Query Cache
query_cache_size            = $query_cache_size
query_cache_limit           = 2M     #512K #max query result size to put in cache

## Connections
max_connections             = $max_connections
max_connect_errors          = 100
concurrent_insert           = 2     #default: 1, 2: enable insert for all instances
connect_timeout             = 60    #default -5.1.22: 5, +5.1.22: 10
max_allowed_packet          = 32M   #max size of incoming data to allow

## Default Table Settings
sql_mode                    = NO_AUTO_CREATE_USER

## Table and TMP settings
max_heap_table_size         = $tmp_table_size
tmp_table_size              = $tmp_table_size
#tmpdir                     = /data/mysql-tmp0:/data/mysql-tmp1 #Recommend using RAMDISK for tmpdir
bulk_insert_buffer_size     = $bulk_insert_buffer_size

## Table cache settings
table_open_cache            = 1024	#5.5.x <default: 64>
table_definition_cache      = 1024

## Thread settings
thread_concurrency          = $ncpu  #recommend 2x CPU cores
thread_cache_size           = $thread_cache_size   #recommend 5% of max_connections

## Replication
#read_only
#skip-slave-start
#slave-skip-errors          = <default: none, recommend:1062>
#slave-net-timeout          = <default: 3600>
#slave-load-tmpdir          = <location of slave tmpdir>
#slave_transaction_retries  = <default: 10>
#server-id                  = <unique value>
#replicate-same-server-id   = <default: 0, recommend: 0, !if log_slave_updates=1> 
#auto-increment-increment   = <default: none>
#auto-increment-offset      = <default: none>
#master-connect-retry       = <default: 60>
#log-slave-updates          = <default: 0 disable>
#report-host                = <master_server_ip>
#report-user                = <replication_user>
#report-password            = <replication_user_pass>
#report-port                = <default: 3306>
#replicate-do-db            =
#replicate-ignore-db        =
#replicate-do-table         = 
#relicate-ignore-table      =
#replicate-rewrite-db       =
#replicate-wild-do-table    =
#replicate-wild-ignore-table =

## Replication Semi-Synchronous 5.5.x only, requires dynamic plugin loading ability 
#rpl_semi_sync_master_enabled	= 1 #enable = 1, disable = 0
#rpl_semi_sync_master_timeout	= 1000 #in milliseconds <default: 10000>, master only setting

## 5.1.x and 5.5.x replication related setting. 
#binlog_format              = MIXED

## MyISAM Engine
key_buffer_size             = $key_buffer_size
myisam_sort_buffer_size     = 128M   #index buffer size for creating/altering indexes
myisam_max_sort_file_size   = 256M   #max file size for tmp table when creating/alering indexes
myisam_repair_threads       = 4      #thread quantity when running repairs
myisam-recover-options      = BACKUP #repair mode, recommend BACKUP

## InnoDB Plugin Dependent Settings
#ignore-builtin-innodb
#plugin-load=innodb=ha_innodb_plugin.so;innodb_trx=ha_innodb_plugin.so;innodb_locks=ha_innodb_plugin.so;innodb_cmp=ha_innodb_plugin.so;innodb_cmp_reset=ha_innodb_plugin.so;innodb_cmpmem=ha_innodb_plugin.so;innodb_cmpmem_reset=ha_innodb_plugin.so;innodb_lock_waits=ha_innodb_plugin.so

## InnoDB IO Capacity - 5.1.x plugin, 5.5.x
#innodb_io_capacity         = 200

## InnoDB IO settings -  5.1.x only
#innodb_file_io_threads     = 16

## InnoDB IO settings -  5.5.x and greater
#innodb_write_io_threads    = 16
#innodb_read_io_threads     = 16

## InnoDB Plugin Independent Settings
innodb_data_home_dir        = /var/lib/mysql
innodb_data_file_path       = ibdata1:128M;ibdata2:10M:autoextend
innodb_log_file_size        = 64M 
innodb_log_files_in_group   = 2
innodb_buffer_pool_size     = $innodb_buffer_pool_size
innodb_additional_mem_pool_size = 4M  #global buffer
innodb_status_file                  #extra reporting
innodb_file_per_table       = 1     #enable always
innodb_flush_log_at_trx_commit = 2  #2/0 = perf, 1 = ACID
innodb_table_locks          = 0     #preserve table locks
innodb_log_buffer_size      = $innodb_log_buffer_size
innodb_lock_wait_timeout    = 60
innodb_thread_concurrency   = $ncpu  #recommend 2x core quantity
innodb_commit_concurrency   = 4    #recommend 4x num disks
#innodb_flush_method        = O_DIRECT   #O_DIRECT = local/DAS, O_DSYNC = SAN/iSCSI
innodb_support_xa           = 0          #recommend 0, disable xa to negate extra disk flush
skip-innodb-doublewrite

## Binlog sync settings
## XA transactions = 1, otherwise set to 0 for best performance
sync_binlog                 = 0

## TX Isolation
transaction-isolation       = REPEATABLE-READ #REPEATABLE-READ req for ACID, SERIALIZABLE req XA

## Per-Thread Buffer memory utilization equation:
#(read_buffer_size + read_rnd_buffer_size + sort_buffer_size + thread_stack + join_buffer_size + binlog_cache_size) * max_connections

## Global Buffer memory utilization equation:
# innodb_buffer_pool_size + innodb_additional_mem_pool_size + innodb_log_buffer_size + key_buffer_size + query_cache_size

[mysqldump]
quick
quote-names
max_allowed_packet          = 128M

EOF


chmod 0644 /etc/mysql/my.cnf

#-------------------------------------------------------------------------------
# setup logrotate
#-------------------------------------------------------------------------------
cat > /etc/logrotate.d/mysql <<EOF
/var/lib/mysql/mysql-*.log {
    ${MYSQL_LOG_INTERVAL}
    missingok
	rotate ${MYSQL_LOG_MAXCOUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet mysql restart > /dev/null 2>/dev/null || true
    endscript
}
EOF

#-------------------------------------------------------------------------------
# add error logfile view
#-------------------------------------------------------------------------------
/var/install/bin/add-menu --logfile setup.system.logfileview.menu "/var/lib/mysql/mysql-error.log" "MySQL errors"

#-------------------------------------------------------------------------------
# setup cron for database backup
#-------------------------------------------------------------------------------
echo "$MYSQL_BACKUP_CRON_SCHEDULE /usr/bin/cui-mysql-backup.sh" > /etc/cron/root/mysql
/sbin/rc-service --quiet fcron reload

exit 0
