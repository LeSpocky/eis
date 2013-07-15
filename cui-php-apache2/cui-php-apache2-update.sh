#!/bin/sh
#----------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=php-apache2

# include libs for using
# ----------------------
. /var/install/include/configlib     

### -------------------------------------------------------------------------
### read old configuration and rename old variables
### -------------------------------------------------------------------------
# set the defaults from default.d file
. /etc/default.d/${packages_name}
# read old values if exists
[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}

### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    printgpl "$packages_name" "2006-07-31" "schlotze" "2008-2013 Sebastian Scholze <sebastian@eisfair.org>"

    #------------------------------------------------------------------------------
    printgroup  "General settings"
    #------------------------------------------------------------------------------

    printvar "PHP_MAX_EXECUTION_TIME" "Time in sec. until the script will be"
    printvar "" "terminated."
    printvar "" "default: 30"

    printvar "PHP_DISPLAY_ERRORS" "Show syntaxerrors of your PHP-Scripts"
    printvar "" "in your Browser."
    printvar "" "yes=ON (default) / no=OFF"

    printvar "PHP_LOG_ERROR" "Write Error to an logfile"
    printvar "" "yes=ON / no=OFF (default)"

    printvar "PHP_INCLUDE_PATH" "Path were include files are located"
    printvar "" "default: .:/usr/share/php:/usr/include/php"

    printvar "PHP_REGISTER_GLOBALS" "Fixes some errors with some old scripts."
    printvar "" "BUT it is strongly recommed to disable"
    printvar "" "this! -> SECURITY REASONS!!!"
    printvar "" "(use \$_POST[] and \$_GET[] varables)"
    printvar "" "yes=ON / no=OFF (default)"

    printvar "PHP_SENDMAIL_PATH" "Here you can change your path to"
    printvar "" "sendmail if needed."
    printvar "" "default: empty"
    printvar "" "(this will use the deafult one)"

    printvar "PHP_SENDMAIL_APP" "Enter additional command that needed to"
    printvar "" "run sendmail correctly."
    printvar "" "default: empty"
    printvar "" "(this will use the deafult one)"
    
    printvar "PHP_DATE_TIMEZONE" "Enter your timezone here"

    #------------------------------------------------------------------------------
    printgroup "Info Settings"
    #------------------------------------------------------------------------------

    printvar "PHP_INFO" "Puts some PHP-Scripts in your htdoc-dir"
    printvar "" "for testing functionallity for"
    printvar "" "php, gd, pdf."

    #------------------------------------------------------------------------------
    printgroup "Memory Settings"
    #------------------------------------------------------------------------------

    printvar "PHP_MAX_POST_SIZE" "Maximal POST size"
    printvar "" "If you use the POST-Method for uploads"
    printvar "" "this value must be bigger/equal than"
    printvar "" "PHP_MAX_UPLOAD_FILESIZE"
    printvar "" "default: 32M --> means 32 Megabytes"

    printvar "PHP_MAX_UPLOAD_FILESIZE" "Max. filesize for uploads"
    printvar "" "default: 16M --> means 16 Megabytes"

    printvar "PHP_MEMORY_LIMIT" "Memory, PHP is allowed to use"
    printvar "" "default: 128M --> means 128 Megabytes"

    printvar "PHP_UPLOAD_DIR" "Where to temporary save uploaded file"
    printvar "" "default: /tmp"

    #------------------------------------------------------------------------------
    printgroup "EXTENSION CONFIGURATION - CACHE/OTHER"
    #------------------------------------------------------------------------------
    printvar "PHP_EXT_CACHE" "Activate chaching module in PHP."
    printvar "" "apc: for APC"
    printvar "" "xcache: for XCache"
    printvar "" "default: no -> switch chaching module off"
    printvar "PHP_EXT_SOAP" "Activate SOAP module in PHP."

    #------------------------------------------------------------------------------
    printgroup "EXTENSION CONFIGURATION - DATABASE"
    #------------------------------------------------------------------------------

    printvar "PHP_EXT_MYSQL" "include MySQL extension in PHP"
    printvar "PHP_EXT_MYSQL_SOCKET" "default socket to connect the"
    printvar "" "MySQL Database."
    printvar "" "default  /run/mysqld/mysqld.sock"
    printvar "PHP_EXT_MYSQL_HOST" "Hostname or IP address if use port connect"
    printvar "PHP_EXT_MYSQL_PORT" "MySQL connect port (3306)"
    printvar "PHP_EXT_MSSQL" "include msSQL extension in PHP"
    printvar "PHP_EXT_PGSQL" "include PostgreSQL extension in PHP"
    printvar "PHP_EXT_INTER" "include INTERBASE extension in PHP"
    printvar "PHP_EXT_SQLITE3" "include SQLite3 extension in PHP"
    printvar "PHP_EXT_LDAP" "Activate LDAP module in PHP."
    #------------------------------------------------------------------------------
    printend
    #------------------------------------------------------------------------------
) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}


### ---------------------------------------------------------------------------
### end
### ---------------------------------------------------------------------------

