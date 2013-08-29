#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
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
    printgpl "$packages_name" "2006-07-31" "team" "2008-2013 team <team@eisfair.org>"

    printgroup "General settings"

    printvar "START_MYSQL"          "Start mysql service 'yes' or 'no'"

    printvar "MYSQL_BIND"           "If set, then bind the MySQL port only to ip-address."

    printvar "MYSQL_LOG_INTERVAL"   "logrotate interval"

    printvar "MYSQL_LOG_MAXCOUNT"   "max count of logfiles"

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}


exit 0
