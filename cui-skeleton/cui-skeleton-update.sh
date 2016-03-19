#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=skeleton

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

    printvar "START_SKELETON"          "Start ftp service yes or no"

    printvar "SKELETON_PORT"           "Listen for an incoming connection. Default 21."

    printvar "SKELETON_BIND"           "If set, then bind the SKELETON port only to ip-address."
    
    printvar "SKELETON_LIST_DOT_FILES" "List files beginning with a dot ('.')"

    printvar "SKELETON_LOG_INTERVAL"   "logrotate interval"

    printvar "SKELETON_LOG_MAXCOUNT"   "max count of logfiles"

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
