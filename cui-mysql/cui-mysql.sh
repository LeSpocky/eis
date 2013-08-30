#!/bin/sh
#-------------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#-------------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/mysql-trace$$.log
#set -x


MYSQL_CONNECT_PORT="3306"
MYSQL_NETWORK="yes"
MYSQL_BIND_IP_ADDRESS="127.0.0.1"
MYSQL_MEMORY_OPT="medium"
MYSQL_MAX_ALLOWED_PACKET="1"
MYSQL_MAX_CONNECTIONS="300"
MYSQL_DEFAULT_COLLATION="latin1_german1_ci"

. /etc/config.d/mysql

#-------------------------------------------------------------------------------
# setup defaults
#-------------------------------------------------------------------------------

[ -e /var/lib/mysql/mysql ] || rc-service --quiet mysql setup

#/usr/bin/mysqladmin -u root password 'new-password'
#/usr/bin/mysqladmin -u root -h alpeis password 'new-password'

#-------------------------------------------------------------------------------
# creating/edit config file
#-------------------------------------------------------------------------------
{
# The following options will be passed to all MySQL clients
echo "[client]
#password	    = your_password
port		    = $MYSQL_CONNECT_PORT
socket		    = /var/run/mysqld/mysqld.sock
"

# Here follows entries for some specific programs

# set mysql to syslog output
echo "[mysqld_safe]
syslog
syslog-tag=mysqld
"

# The MySQL server
echo "[mysqld]
port		    = $MYSQL_CONNECT_PORT
socket		    = /var/run/mysqld/mysqld.sock
skip-external-locking"

# Don't listen on a TCP/IP port at all. This can be a security enhancement,
# if all processes that need to connect to mysqld run on the same host.
# All interaction with mysqld must be made via Unix sockets or named pipes.
# Note that using this option without enabling named pipes on Windows
# (via the "enable-named-pipe" option) will render mysqld useless!
# 
#skip-networking
if [ "$MYSQL_NETWORK" != "yes" ]; then
    echo "skip-networking"
else
    [ -n "$MYSQL_BIND_IP_ADDRESS" ] && echo "bind-address = $MYSQL_BIND_IP_ADDRESS"
fi

if [ "$MYSQL_MEMORY_OPT" = "small" ]; then
echo "
key_buffer_size = 16K
max_allowed_packet = 1M
table_open_cache = 4
sort_buffer_size = 64K
read_buffer_size = 256K
read_rnd_buffer_size = 256K
net_buffer_length = 2K
thread_stack = 128K"
idbh=""
idfp=""
ibps=""
iams=""
ilfs=""
ilbs=""
iflc=""
ilwt=""
kbs="8M"
elif [ "$MYSQL_MEMORY_OPT" = "medium" ]; then
echo "
key_buffer_size = 16M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M"
idbh="innodb_data_home_dir = /var/lib/mysql"
idfp="innodb_data_file_path = ibdata1:10M:autoextend"
ibps="innodb_buffer_pool_size = 32M"
iams="innodb_additional_mem_pool_size = 2M"
ilfs="innodb_log_file_size = 5M"
ilbs="innodb_log_buffer_size = 8M"
iflc="innodb_flush_log_at_trx_commit = 1"
ilwt="innodb_lock_wait_timeout = 50"
kbs="20M"
elif [ "$MYSQL_MEMORY_OPT" = "large" ]; then
echo "
key_buffer_size = 256M
table_open_cache = 256
sort_buffer_size = 1M
read_buffer_size = 1M
read_rnd_buffer_size = 4M
myisam_sort_buffer_size = 64M
thread_cache_size = 8"
idbh="innodb_data_home_dir = /var/lib/mysql"
idfp="innodb_data_file_path = ibdata1:10M:autoextend"
ibps="innodb_buffer_pool_size = 256M"
iams="innodb_additional_mem_pool_size = 20M"
ilfs="innodb_log_file_size = 64M"
ilbs="innodb_log_buffer_size = 8M"
iflc="innodb_flush_log_at_trx_commit = 1"
ilwt="innodb_lock_wait_timeout = 50"
kbs="128M"
elif [ "$MYSQL_MEMORY_OPT" = "huge" ]; then
echo "
key_buffer_size = 384M
table_open_cache = 512
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
myisam_sort_buffer_size = 64M
thread_cache_size = 8"
idbh="innodb_data_home_dir = /var/lib/mysql"
idfp="innodb_data_file_path = ibdata1:2000M;ibdata2:10M:autoextend"
ibps="innodb_buffer_pool_size = 384M"
iams="innodb_additional_mem_pool_size = 20M"
ilfs="innodb_log_file_size = 100M"
ilbs="innodb_log_buffer_size = 8M"
iflc="innodb_flush_log_at_trx_commit = 1"
ilwt="innodb_lock_wait_timeout = 50"
kbs="256M"
fi
echo "
max_allowed_packet = ${MYSQL_MAX_ALLOWED_PACKET}M
max_connections = $MYSQL_MAX_CONNECTIONS
"

# Replication master option
if [ "$MYSQL_ACTIVATE_BINLOG" = "yes" ]; then
    # Replication Master Server (default)
    # binary logging is required for replication
    echo "log-bin = mysql-bin"
    # binary logging format - mixed recommended
    echo "binlog_format = mixed"
fi
# required unique id between 1 and 2^32 - 1
# defaults to 1 if master-host is not set
# but will not function as a master if omitted
echo "server-id	= 1"

# Replication Slave (comment out master section to use this)
#
# To configure this host as a replication slave, you can choose between
# two methods :
#
# 1) Use the CHANGE MASTER TO command (fully described in our manual) -
#    the syntax is:
#
#    CHANGE MASTER TO MASTER_HOST=<host>, MASTER_PORT=<port>,
#    MASTER_USER=<user>, MASTER_PASSWORD=<password> ;
#
#    where you replace <host>, <user>, <password> by quoted strings and
#    <port> by the master's port number (3306 by default).
#
#    Example:
#
#    CHANGE MASTER TO MASTER_HOST='125.564.12.1', MASTER_PORT=3306,
#    MASTER_USER='joe', MASTER_PASSWORD='secret';
#
# OR
#
# 2) Set the variables below. However, in case you choose this method, then
#    start replication for the first time (even unsuccessfully, for example
#    if you mistyped the password in master-password and the slave fails to
#    connect), the slave will create a master.info file, and any later
#    change in this file to the variables' values below will be ignored and
#    overridden by the content of the master.info file, unless you shutdown
#    the slave server, delete master.info and restart the slaver server.
#    For that reason, you may want to leave the lines below untouched
#    (commented) and instead use CHANGE MASTER TO (see above)
#
# required unique id between 2 and 2^32 - 1
# (and different from the master)
# defaults to 2 if master-host is set
# but will not function as a slave if omitted
#server-id       = 2
#
# The replication master for this slave - required
#master-host     =   <hostname>
#
# The username the slave will use for authentication when connecting
# to the master - required
#master-user     =   <username>
#
# The password the slave will authenticate with when connecting to
# the master - required
#master-password =   <password>
#
# The port the master is listening on.
# optional - defaults to 3306
#master-port     =  <port>
#
# binary logging - not required for slaves, but recommended
#log-bin=mysql-bin

# Uncomment the following if you are using InnoDB tables
#innodb_data_home_dir = /var/lib/mysql
echo "$idbh"
#innodb_data_file_path = ibdata1:10M:autoextend
echo "$idfp"
#innodb_log_group_home_dir = /var/lib/mysql
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
#innodb_buffer_pool_size = 16M
echo "$ibps"
#innodb_additional_mem_pool_size = 2M
echo "$iams"
# Set .._log_file_size to 25 % of buffer pool size
#innodb_log_file_size = 5M
echo "$ilfs"
#innodb_log_buffer_size = 8M
echo "$ilbs"
#innodb_flush_log_at_trx_commit = 1
echo "$iflc"
#innodb_lock_wait_timeout = 50
echo "$ilwt"
echo
# character set:
#echo "character-set-server = `echo "$MYSQL_DEFAULT_COLLATION" | cut -f 1 -d '_'`"
#echo "collation-server = $MYSQL_DEFAULT_COLLATION"
#echo

echo "[mysqldump]"
echo "quick"
echo "max_allowed_packet = 16M"
echo

echo "[mysql]"
echo "no-auto-rehash"
# Remove the next comment character if you are not familiar with SQL
#safe-updates

echo "
[myisamchk]
key_buffer_size = $kbs
sort_buffer_size = $kbs
read_buffer = 2M
write_buffer = 2M
"
echo "[mysqlhotcopy]"
echo "interactive-timeout"

} > /etc/mysql/my.cnf

chmod 0644 /etc/mysql/my.cnf

#-------------------------------------------------------------------------------
# setup logrotate
#-------------------------------------------------------------------------------
cat > /etc/logrotate.d/mysql <<EOF
/var/log/mysql.log {
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

exit 0
