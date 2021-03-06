#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=vsftpd

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

    printvar "START_FTP"          "Start ftp service yes or no"

    printvar "FTP_PORT"           "Listen for an incoming connection. Default 21."

    printvar "FTP_BIND"           "If set, then bind the FTP port only to ip-address."
    
    printvar "FTP_LIST_DOT_FILES" "List files beginning with a dot ('.')"   

    printvar "FTP_LOG_INTERVAL"   "logrotate interval"

    printvar "FTP_LOG_MAXCOUNT"   "max count of logfiles"

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}


exit 0
