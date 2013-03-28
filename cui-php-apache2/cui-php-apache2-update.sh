#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
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

    printvar "PHP_EXTENSION_DIR" "/usr/lib/php5/extensions"
    printvar "" "Where to find the extensions for PHP"
    printvar "" "default: /usr/lib/php5/extensions"

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
    printvar "" "default: 32M --> meens 32 Magabytes"

    printvar "PHP_MAX_UPLOAD_FILESIZE" "Max. filesize for uploads"
    printvar "" "default: 2M --> meens 2 Megabytes"

    printvar "PHP_MEMORY_LIMIT" "Memory, PHP is allowed to use"
    printvar "" "default: 128M --> meens 128 Megabytes"

    printvar "PHP_UPLOAD_DIR" "Where to temporary save uploaded file"
    printvar "" "default: /tmp"

    #------------------------------------------------------------------------------
    printgroup "EXTENSION CONFIGURATION - CACHE"
    #------------------------------------------------------------------------------
    printvar "PHP_EXT_CACHE" "Activate chaching module in PHP."
    printvar "" "apc: for APC"
    printvar "" "eac: for eAccelerator"
    printvar "" "default: no -> switch chaching module off"
    printvar "PHP_EXT_SOAP" "Activate SOAP module in PHP."
    printvar "PHP_EXT_LDAP" "Activate LDAP module in PHP."
    #------------------------------------------------------------------------------
    printgroup "EXTENSION CONFIGURATION - DATABASE"
    #------------------------------------------------------------------------------

    printvar "PHP_EXT_MYSQL" "include MySQL extension in PHP"
    printvar "PHP_EXT_MYSQL_SOCKET" "default socket to connect the"
    printvar "" "MySQL Database."
    printvar "" "Eisfair-2 -> /var/run/mysql/mysql.sock"
    printvar "" "Eisfair-1 -> /var/lib/mysql/mysql.sock"
    printvar "" "MySQL 3.x.y -> /tmp/mysql.sock"
    printvar "PHP_EXT_MYSQL_HOST" "Hostname or IP address if use port connect"
    printvar "PHP_EXT_MYSQL_PORT" "MySQL connect port (3306)"
    printvar "PHP_EXT_MSSQL" "include msSQL extension in PHP"
    printvar "PHP_EXT_PGSQL" "include PostgreSQL extension in PHP"
    printvar "PHP_EXT_INTER" "include INTERBASE extension in PHP"
    printvar "PHP_EXT_SQLITE3" "include SQLite3 extension in PHP"
#    if [ "`cat /etc/eisfair-system`" = "eisfair-1" ]
#    then
#        printvar "PHP_EXT_ADVANTAGE" "include Advantage extension in PHP"
#    fi
    #------------------------------------------------------------------------------
    printend
    #------------------------------------------------------------------------------
) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

### -------------------------------------------------------------------------
### Create the check.d file
### -------------------------------------------------------------------------
make_check_file()
{
cat >/etc/check.d/${packages_name} <<EOF_INT
#--------------------------------------------------------------------------
# /etc/check.d/${packages_name} - eischk check file
#
# Copyright (c) 2005-2006 Eisfair Team
# Copyright (c) ${my_copy}
#
# Creation:     ${datum_creation} ${my_initial}
# Last Update:  ${datum_update} ${my_initial}
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#--------------------------------------------------------------------------
# Variable               OPT_VARIABLE             VARIABLE_N      VALUE

PHP_MAX_EXECUTION_TIME    -                         -        NUMERIC
PHP_DISPLAY_ERRORS        -                         -        YESNO
PHP_LOG_ERROR             -                         -        YESNO
PHP_INCLUDE_PATH          -                         -        NOTEMPTY
PHP_REGISTER_GLOBALS      -                         -        YESNO
PHP_EXTENSION_DIR         -                         -        NOTEMPTY
PHP_INFO                  -                         -        YESNO
PHP_MAX_POST_SIZE         -                         -        NOTEMPTY
PHP_MAX_UPLOAD_FILESIZE   -                         -        NOTEMPTY
PHP_MEMORY_LIMIT          -                         -        NOTEMPTY
PHP_UPLOAD_DIR            -                         -        NOTEMPTY
PHP_SENDMAIL_PATH         -                         -        NONE
PHP_SENDMAIL_APP          -                         -        NONE
PHP_DATE_TIMEZONE         -                         -        PHP_DATE_TIMEZONE
PHP_EXT_MYSQL             -                         -        YESNO
PHP_EXT_MYSQL_SOCKET      PHP_EXT_MYSQL            -         PHP_MYSQL_SOCKET
PHP_EXT_MYSQL_HOST        PHP_EXT_MYSQL            -         PHP_MYSQL_HOST
PHP_EXT_MYSQL_PORT        PHP_EXT_MYSQL            -         ENUMERIC
PHP_EXT_MSSQL             -                         -        YESNO
PHP_EXT_PGSQL             -                         -        YESNO
PHP_EXT_INTER             -                         -        YESNO
PHP_EXT_SQLITE3           -                         -        YESNO
PHP_EXT_CACHE             -                         -        PHP_CACHING_MODULE
PHP_EXT_SOAP              -                         -        YESNO
PHP_EXT_LDAP              -                         -        YESNO
EOF_INT

#if [ "`cat /etc/eisfair-system`" = "eisfair-1" ]
#then
#    (
#        echo "PHP_EXT_ADVANTAGE         -                         -        YESNO"
#    ) >> /etc/check.d/${packages_name}
#fi
    # Set rights for check.d file
    chmod 0644 /etc/check.d/${packages_name}
    chown root /etc/check.d/${packages_name}

### ---------------------------------------------------------------------------
### Create the EXTENTED check.d file
### ---------------------------------------------------------------------------
sellist="Europe/Amsterdam|Europe/Andorra|"
sellist="${sellist}Europe/Athens|Europe/Belfast|Europe/Belgrade|Europe/Berlin|Europe/Bratislava|Europe/Brussels|Europe/Bucharest|Europe/Budapest|"
sellist="${sellist}Europe/Chisinau|Europe/Copenhagen|Europe/Dublin|Europe/Gibraltar|Europe/Guernsey|Europe/Helsinki|Europe/Isle_of_Man|Europe/Istanbul|"
sellist="${sellist}Europe/Jersey|Europe/Kaliningrad|Europe/Kiev|Europe/Lisbon|Europe/Ljubljana|Europe/London|Europe/Luxembourg|Europe/Madrid|"
sellist="${sellist}Europe/Malta|Europe/Mariehamn|Europe/Minsk|Europe/Monaco|Europe/Moscow|Europe/Nicosia|Europe/Oslo|Europe/Paris|Europe/Podgorica|"
sellist="${sellist}Europe/Prague|Europe/Riga|Europe/Rome|Europe/Samara|Europe/San_Marino|Europe/Sarajevo|Europe/Simferopol|Europe/Skopje|Europe/Sofia|"
sellist="${sellist}Europe/Stockholm|Europe/Tallinn|Europe/Tirane|Europe/Tiraspol|Europe/Uzhgorod|Europe/Vaduz|Europe/Vatican|Europe/Vienna|Europe/Vilnius|"
sellist="${sellist}Europe/Volgograd|Europe/Warsaw|Europe/Zagreb|Europe/Zaporozhye|Europe/Zurich|Etc/GMT|Etc/GMT+0|Etc/GMT+1|Etc/GMT+10|Etc/GMT+11|"
sellist="${sellist}Etc/GMT+12|Etc/GMT+2|Etc/GMT+3|Etc/GMT+4|Etc/GMT+5|"
sellist="${sellist}Etc/GMT+6|Etc/GMT+7|Etc/GMT+8|Etc/GMT+9|Etc/GMT-0|Etc/GMT-1|Etc/GMT-10|Etc/GMT-11|Etc/GMT-12|Etc/GMT-13|Etc/GMT-14|Etc/GMT-2|"
sellist="${sellist}Etc/GMT-3|Etc/GMT-4|Etc/GMT-5|Etc/GMT-6|Etc/GMT-7|Etc/GMT-8|Etc/GMT-9|Etc/GMT0|Etc/Greenwich|Etc/UCT|Etc/Universal|Etc/UTC|"
sellist="${sellist}Etc/Zulu"

printgpl "${packages_name}.exp" "${datum_update}" "${my_initial}" "${my_name}" > /etc/check.d/${packages_name}.exp
cat >> /etc/check.d/${packages_name}.exp <<EOF_INT
PHP_MYSQL_SOCKET = '/var/run/mysql/mysql.sock|/var/lib/mysql/mysql.sock|/tmp/mysql.sock|()'
                  : 'Use only: Eisfair-2 /var/run/mysql/mysql.sock Eisfair-1: /var/lib/mysql/mysql.sock or MySQL 3.x.y: /tmp/mysql.sock'
PHP_MYSQL_HOST = 'localhost|(RE:FQDN)|(RE:IPADDR)|()'
                  : 'Use only: localhost, hostname.domain.tld, ip-address or empty for not use'
PHP_CACHING_MODULE = 'no|apc|eac'
                    : 'Use "apc" for the APC chaching module or "eac" for eAccelerator. default = "no" -> no chaching modul'
PHP_DATE_TIMEZONE = "${sellist}"
                    : 'Select a predefinde Date/Timezone'

EOF_INT
    # Set rights for check.exp file
    chmod 0644 /etc/check.d/${packages_name}.exp
    chown root /etc/check.d/${packages_name}.exp
}
### ---------------------------------------------------------------------------
### Main
### ---------------------------------------------------------------------------
# write default config file
make_config_file /etc/default.d/${packages_name}

# update from old version
rename_old_variables

# write new config file
make_config_file /etc/config.d/${packages_name}

# write check.d file
make_check_file

### ---------------------------------------------------------------------------
### end
### ---------------------------------------------------------------------------

