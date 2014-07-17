#!/bin/sh
# ------------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
# ------------------------------------------------------------------------------

package_name=php-apache2

# Include required libs
. /var/install/include/configlib

# Set defaults from default.d file
. /etc/default.d/${package_name}
# Read old values if exists
[ -f /etc/config.d/${package_name} ] && . /etc/config.d/${package_name}

### ----------------------------------------------------------------------------
### Write the new config
(
    printgpl --conf "$package_name"

    # ------------------------------------------------------------------------
    printgroup  "General settings"
    # ------------------------------------------------------------------------

    printvar "PHP_MAX_EXECUTION_TIME" "Time in sec. until the script will be"
    printvar "" "terminated."
    printvar "" "default: 240"

    printvar "PHP_DISPLAY_ERRORS" "Show syntaxerrors of your PHP-Scripts"
    printvar "" "in your Browser."
    printvar "" "yes=ON (default) / no=OFF"

    printvar "PHP_LOG_ERROR" "Write Error to a logfile"
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

    # ------------------------------------------------------------------------
    printgroup "Info Settings"
    # ------------------------------------------------------------------------

    printvar "PHP_INFO" "Puts some PHP-Scripts in your htdoc-dir"
    printvar "" "for testing functionallity for php, gd."

    # ------------------------------------------------------------------------
    printgroup "Memory Settings"
    # ------------------------------------------------------------------------

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

    # ------------------------------------------------------------------------
    printgroup "Extension Configuration - Cache/other"
    # ------------------------------------------------------------------------
    printvar "PHP_EXT_CACHE" "Activate caching module in PHP."
    printvar "" "apc: for APC"
    printvar "" "xcache: for XCache"
    printvar "" "default: no -> switch caching module off"
    printvar "PHP_EXT_CTYPE" "Activate CURL module in PHP."
    printvar "PHP_EXT_CURL" "Activate CURL module in PHP."
    printvar "PHP_EXT_SOAP" "Activate SOAP module in PHP."
    printvar "PHP_EXT_GD" "Activate GD extension for PHP."
    printvar "PHP_EXT_JSON" "Activate json extension for PHP."
    printvar "PHP_EXT_GETTEXT" "Activate Native Language extension."
    printvar "PHP_EXT_ICONV" "Activate iconv character set conversion."
    printvar "PHP_EXT_IMAP" "Activate IMAP mail extension for PHP."
    printvar "PHP_EXT_SSL" "Activate OpenSSL extension for PHP."
    printvar "PHP_EXT_XML" "Activate XML extension for PHP."
    printvar "PHP_EXT_ZIP" "Activate ZIP extension for PHP."
    printvar "PHP_EXT_ZLIB" "Activate ZLIB extension for PHP."

    # ------------------------------------------------------------------------
    printgroup "Extension Configuration - Database"
    # ------------------------------------------------------------------------

    printvar "PHP_EXT_MYSQL" "Include MySQL extension in PHP"
    printvar "PHP_EXT_MYSQL_SOCKET" "Default socket to connect the MySQL Database. Default  /run/mysqld/mysqld.sock"
    printvar "PHP_EXT_MYSQL_HOST" "Hostname or IP address if use port connect"
    printvar "PHP_EXT_MYSQL_PORT" "MySQL connect port (3306)"
    printvar "PHP_EXT_MSSQL" "Include msSQL extension in PHP"
    printvar "PHP_EXT_PGSQL" "Include PostgreSQL extension in PHP"
    printvar "PHP_EXT_INTER" "Include INTERBASE extension in PHP"
    printvar "PHP_EXT_SQLITE3" "Include SQLite3 extension in PHP"
    printvar "PHP_EXT_LDAP" "Activate LDAP module in PHP."
    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------
) > /etc/config.d/${package_name}
# Set rights
chmod 0644  /etc/config.d/${package_name}
chown root  /etc/config.d/${package_name}

exit 0
### ----------------------------------------------------------------------------
