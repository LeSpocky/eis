#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2015 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=mysql

# include libs for using
# ----------------------
. /var/install/include/configlib     # configlib from eisfair

### -------------------------------------------------------------------------
### read old configuration and rename old variables
### -------------------------------------------------------------------------
# set the defaults from default.d file
. /etc/default.d/${packages_name}

. /etc/config.d/${packages_name}

### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    #------------------------------------------------------------------------
    printgpl --conf "$packages_name"

    printgroup "General settings"

    printvar "START_MYSQL"            "Start mysql service yes or no"
    printvar "MYSQL_NETWORK"          "enable the TCP/IP external connection"
    printvar "MYSQL_BIND"             "If set, then bind the MySQL port only to ip-address."
    printvar "MYSQL_CONNECT_PORT"     "MySQL remote port, default=3306"
    printvar "MYSQL_RAM"              "Use 256 MB ... 64 GB RAM"

    printgroup "Optimization settings"

    printvar "MYSQL_MAX_CONNECTIONS"  "max client connections"
    printvar "MYSQL_QCACHE_SIZE"      "query cache size"
    printvar "MYSQL_QCACHE_ENTRY_MAX" "max size of query cache entry"
    printvar "MYSQL_QCACHE_ENTRY_MIN" "min size of query cache entry"
    echo ""
    printvar "MYSQL_LOG_INTERVAL"     "logrotate interval"
    printvar "MYSQL_LOG_MAXCOUNT"     "max count of logfiles"
    echo ""
    printvar "MYSQL_BACKUP_CRON_SCHEDULE" "start time for database backup"

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
