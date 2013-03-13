#!/bin/bash
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
#
# Creation:     2006-2013 the eisfair team, team(at)eisfair(dot)org
# Last Update:  $Id: apache2-update.sh 31505 2013-03-07 15:36:29Z jv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

### -------------------------------------------------------------------------
### major variables
### -------------------------------------------------------------------------
# presonal data
# -------------
my_name='Sebastian Scholze'
my_initial='schlotze'
my_copy="`date +%Y` ${my_name} <sebastian(at)eisfair(dot)org>"

# date settings
# -------------
datum_creation="2006-07-31"
datum_update=`date +%Y-%m-%d`

# name of the current package
# ---------------------------
packages_name=apache2

### -------------------------------------------------------------------------
### include libs for using
### -------------------------------------------------------------------------
. /var/install/include/configlib     # configlib from eisfair
. /var/install/include/apache2

### -------------------------------------------------------------------------
### Set the default values for configuration
### ----------------------------------------
START_APACHE2='no'
APACHE2_PORT='80'
APACHE2_SERVER_ADMIN='webmaster@foo.bar'
APACHE2_SERVER_NAME='eis.lan.fli4l'
APACHE2_SERVER_SIGNATURE='Off'
APACHE2_DIRECTORY_INDEX='index.html index.htm'
APACHE2_HOSTNAME_LOOKUPS='yes'
APACHE2_VIEW_DIRECTORY_CONTENT='yes'
APACHE2_ACCESS_CONTROL='all'
APACHE2_ENABLE_SSI='no'
APACHE2_ENABLE_USERDIR='yes'

#----------------------------------------------------------------------------
# Error and Access Logs
#----------------------------------------------------------------------------
APACHE2_ERROR_LOG='/var/www/log/error.log'
APACHE2_ACCESS_LOG='/var/www/log/access.log'
#----------------------------------------------------------------------------
# Scrip-Aliases [DON'T FORGET TO APPEND A SLASH (/) AFTER PATHNAMES!]
#----------------------------------------------------------------------------
APACHE2_SCRIPT_ALIAS='/cgi-bin/'
APACHE2_SCRIPT_DIR='/var/www/cgi-bin/'
#----------------------------------------------------------------------------
# Error Documents
#----------------------------------------------------------------------------
APACHE2_ERROR_DOCUMENT_N='0'
APACHE2_ERROR_DOCUMENT_1_ERROR='404'
APACHE2_ERROR_DOCUMENT_1_DOCUMENT='/404error.html'
#----------------------------------------------------------------------------
# Directory Settings + Alias
#----------------------------------------------------------------------------
APACHE2_DIR_N='2'
APACHE2_DIR_1_ACTIVE='yes'
APACHE2_DIR_1_ALIAS='yes'
APACHE2_DIR_1_ALIAS_NAME='/icons/'
APACHE2_DIR_1_PATH='/usr/share/apache2/icons/'
APACHE2_DIR_1_AUTH_NAME=''
APACHE2_DIR_1_AUTH_TYPE='Basic'
APACHE2_DIR_1_AUTH_N='0'
APACHE2_DIR_1_AUTH_1_USER=''
APACHE2_DIR_1_AUTH_1_PASS=''
APACHE2_DIR_1_ACCESS_CONTROL='all'
APACHE2_DIR_1_CGI='none'
APACHE2_DIR_1_SSI='no'
APACHE2_DIR_1_VIEW_DIR_CONTENT='no'
APACHE2_DIR_1_WEBDAV='no'
APACHE2_DIR_2_ACTIVE='no'
APACHE2_DIR_2_ALIAS='no'
APACHE2_DIR_2_ALIAS_NAME=''
APACHE2_DIR_2_PATH='/var/www/localhost/htdocs/geheim/'
APACHE2_DIR_2_AUTH_NAME='Members only!'
APACHE2_DIR_2_AUTH_TYPE='Basic'
APACHE2_DIR_2_AUTH_N='0'
APACHE2_DIR_2_AUTH_1_USER='user'
APACHE2_DIR_2_AUTH_1_PASS='secret'
APACHE2_DIR_2_ACCESS_CONTROL='all'
APACHE2_DIR_2_CGI='none'
APACHE2_DIR_2_SSI='no'
APACHE2_DIR_2_VIEW_DIR_CONTENT='no'
APACHE2_DIR_2_WEBDAV='no'
#----------------------------------------------------------------------------
# SSL
#----------------------------------------------------------------------------
APACHE2_SSL='no'
APACHE2_SSL_PORT='443'
APACHE2_SSL_LOGDIR='/var/www/log/'
#----------------------------------------------------------------------------
# Settings for Log-file handling
#----------------------------------------------------------------------------
APACHE2_LOG_LEVEL='warn'
APACHE2_LOG_COUNT='10'
APACHE2_LOG_INTERVAL='weekly'
#----------------------------------------------------------------------------
# Settings for performance tuning
#----------------------------------------------------------------------------
APACHE2_MAX_KEEP_ALIVE_TIMEOUT='15'
APACHE2_MAX_KEEP_ALIVE_REQUESTS='100'
APACHE2_MAX_CLIENTS='256'
APACHE2_MAX_REQUESTS_PER_CHILD='4000'
#----------------------------------------------------------------------------
# Settings for VHost
#----------------------------------------------------------------------------
APACHE2_VHOST_N='1'
APACHE2_VHOST_1_ACTIVE='no'
APACHE2_VHOST_1_IP='*'
APACHE2_VHOST_1_PORT='80'
APACHE2_VHOST_1_SERVER_NAME='foo'
APACHE2_VHOST_1_SERVER_ALIAS='*.foo'
APACHE2_VHOST_1_SERVER_ADMIN='webmaster@foo.bar'
APACHE2_VHOST_1_DOCUMENT_ROOT='/var/www/foo/htdocs'
APACHE2_VHOST_1_SCRIPT_ALIAS='/cgi-bin/'
APACHE2_VHOST_1_SCRIPT_DIR='/var/www/foo/cgi-bin/'
APACHE2_VHOST_1_ERROR_LOG='/var/www/log/foo_error.log'
APACHE2_VHOST_1_ACCESS_LOG='/var/www/log/foo_access.log'
APACHE2_VHOST_1_ACCESS_CONTROL='all'
APACHE2_VHOST_1_VIEW_DIRECTORY_CONTENT='no'
APACHE2_VHOST_1_ENABLE_SSI='no'
APACHE2_VHOST_1_MOD_CACHE='no'
APACHE2_VHOST_1_DIR_N='1'
APACHE2_VHOST_1_DIR_1_ACTIVE='no'
APACHE2_VHOST_1_DIR_1_ALIAS='no'
APACHE2_VHOST_1_DIR_1_ALIAS_NAME=''
APACHE2_VHOST_1_DIR_1_PATH='/var/www/localhost/htdocs/geheim'
APACHE2_VHOST_1_DIR_1_AUTH_NAME='Members only!'
APACHE2_VHOST_1_DIR_1_AUTH_TYPE='Basic'
APACHE2_VHOST_1_DIR_1_AUTH_N='0'
APACHE2_VHOST_1_DIR_1_AUTH_1_USER='user'
APACHE2_VHOST_1_DIR_1_AUTH_1_PASS='secret'
APACHE2_VHOST_1_DIR_1_ACCESS_CONTROL='all'
APACHE2_VHOST_1_DIR_1_CGI='none'
APACHE2_VHOST_1_DIR_1_SSI='no'
APACHE2_VHOST_1_DIR_1_VIEW_DIR_CONTENT='no'
APACHE2_VHOST_1_DIR_1_WEBDAV='no'
APACHE2_VHOST_1_SSL='no'
APACHE2_VHOST_1_SSL_PORT='443'
APACHE2_VHOST_1_SSL_FORCE='no'
APACHE2_VHOST_1_SSL_CERT_NAME='apache'
#----------------------------------------------------------------------------
# Settings for apache modules
#----------------------------------------------------------------------------
APACHE2_MOD_CACHE='no'

### -------------------------------------------------------------------------
### read old configuration and rename old variables
### -------------------------------------------------------------------------
rename_old_variables()
{
    # read old values
    if [ -f /etc/config.d/${packages_name} ]
    then
        . /etc/config.d/${packages_name}
    fi
}

### -------------------------------------------------------------------------
### Write config and default files
### -------------------------------------------------------------------------
make_config_file()
{
    internal_conf_file=${1}
    (
    #------------------------------------------------------------------------
    printgpl -conf "$packages_name" "$datum_creation" "schlotze" "2008-2010 Sebastian Scholze <sebastian@eisfair.org>"

    #------------------------------------------------------------------------
    printgroup  "Start Apache2 Webserver during startup"
    #------------------------------------------------------------------------
    printvar "START_APACHE2"         "Start the Apache Webserver"
    printvar ""                      "yes=ON / no=OFF (default)"
    printvar

    #------------------------------------------------------------------------
    printgroup  "General settings"
    #------------------------------------------------------------------------
    printvar "APACHE2_PORT"             "TCP/IP port"
    printvar
    printvar "APACHE2_SERVER_ADMIN"     "Email address of webmaster "
    printvar
    printvar "APACHE2_SERVER_NAME"      "FQND of the server e.g."
    printvar ""                         "meineis.eisfair.net"
    printvar "APACHE2_SERVER_SIGNATURE" "On/Off/Email"
    printvar

    #------------------------------------------------------------------------------
    printgroup "Gerneral SSL Settings"
    #------------------------------------------------------------------------------
    printvar "APACHE2_SSL"        "Start SSL-Engine?"
    printvar "APACHE2_SSL_PORT"   "Port on which SSL should run"
    printvar "APACHE2_SSL_LOGDIR" "SSL error and access logfiles directory"
    printvar ""                   "!!!DON'T FORGET TO APPEND A SLASH!!!"
    printvar

    #------------------------------------------------------------------------
    printgroup  "Special Settings"
    #------------------------------------------------------------------------
    printvar "APACHE2_DIRECTORY_INDEX"        "Default document"
    printvar
    printvar "APACHE2_HOSTNAME_LOOKUPS"       "Resolve IPs in logfile?"
    printvar
    printvar "APACHE2_VIEW_DIRECTORY_CONTENT" "If there's no index.html view files in dir"
    printvar
    printvar "APACHE2_ACCESS_CONTROL"         "Who get access e.g. 192.168.0.0/24"
    printvar
    printvar "APACHE2_ENABLE_SSI"             "Enable SSI 'yes' or 'no'"
    printvar
	printvar "APACHE2_ENABLE_USERDIR"         "Show content of /home/USER/public_html"
    printvar


    #------------------------------------------------------------------------------
    printgroup "Error and Access Logs "
    #------------------------------------------------------------------------------
    printvar "APACHE2_ERROR_LOG"  "Error log file"
    printvar "APACHE2_ACCESS_LOG" "Access log file"
    printvar

    #------------------------------------------------------------------------------
    printgroup "Scrip Aliases [DON'T FORGET TO APPEND A SLASH (/) AFTER PATHNAMES!]"     #'
    #------------------------------------------------------------------------------
    printvar "APACHE2_SCRIPT_ALIAS"    ""
    printvar "APACHE2_SCRIPT_DIR"      "Root where to put the CGIs in"
    printvar

    #------------------------------------------------------------------------------
    printgroup "Error Documents"
    #------------------------------------------------------------------------------
    printvar "APACHE2_ERROR_DOCUMENT_N"          "no. costum of Error Documents"

    idx='1'
    count=`expr $APACHE2_ERROR_DOCUMENT_N + 1`

    while [ $idx -le $count ]
    do
        eval name='$APACHE2_ERROR_DOCUMENT_'$idx'_ERROR'
        if [ -n "$name" ] ; then
            printvar "APACHE2_ERROR_DOCUMENT_"$idx"_ERROR"    "HTTP-Error number"
            printvar "APACHE2_ERROR_DOCUMENT_"$idx"_DOCUMENT" "HTML-Document to view "
        fi
        idx=`expr $idx + 1`
    done

    printvar

    #------------------------------------------------------------------------------
    printgroup "Directory Settings + Aliases"
    #------------------------------------------------------------------------------
    printvar "APACHE2_DIR_N"                  "No. of dirs"

    idx='1'
    count=`expr $APACHE2_DIR_N + 1`

    while [ $idx -le $count ]
    do
        eval name='$APACHE2_DIR_'$idx'_PATH'
        if [ -n "$name" ] ; then
            printvar "APACHE2_DIR_"$idx"_ACTIVE"           "Dir Active? yes/no"
            eval tmpAlias='$APACHE2_DIR_'$idx'_ALIAS'
            if [ "$tmpAlias" = "" ] 
            then
                eval "APACHE2_DIR_"$idx"_ALIAS"='no'
                eval "APACHE2_DIR_"$idx"_ALIAS_NAME"=''
            fi
            printvar "APACHE2_DIR_"$idx"_ALIAS"            "Create an alias?"
            printvar "APACHE2_DIR_"$idx"_ALIAS_NAME"       "Name of alias"
            printvar "APACHE2_DIR_"$idx"_PATH"             "Name of 1. dir"
            printvar "APACHE2_DIR_"$idx"_AUTH_NAME"        "Name of the area to protect"
            printvar "APACHE2_DIR_"$idx"_AUTH_TYPE"        "Authentication type: Basic or Digest"
            printvar "APACHE2_DIR_"$idx"_AUTH_N"           "No. of usernames"

            idy='1'
            eval countauth='$APACHE2_DIR_'$idx'_AUTH_N'
            count2=`expr $countauth + 1`

            while [ $idy -le $count2 ]
            do
                eval auth='$APACHE2_DIR_'$idx'_AUTH_'$idy'_USER'
                if [ -n "$auth" ] ; then
                    printvar "APACHE2_DIR_"$idx"_AUTH_"$idy"_USER"      "User no. $idy."
                    printvar "APACHE2_DIR_"$idx"_AUTH_"$idy"_PASS"      "Password for user $idy."
                fi
                idy=`expr $idy + 1`
            done

            printvar "APACHE2_DIR_"$idx"_ACCESS_CONTROL"   "e.g. 192.168.0.0/24 or 192.168."
            printvar "APACHE2_DIR_"$idx"_CGI"              "!NOT YES! Possibilities are: 'none' '.pl' '.cgi'"
            printvar "APACHE2_DIR_"$idx"_SSI"              "Allow Server Side Includes?"
            printvar "APACHE2_DIR_"$idx"_VIEW_DIR_CONTENT" "View files in dir if no index.html"
            printvar "APACHE2_DIR_"$idx"_WEBDAV"           "Enable WebDav"
            printvar
        fi
        idx=`expr $idx + 1`
    done
        
        
    #------------------------------------------------------------------------------
    printgroup "Virtual Hosts" ""
    #------------------------------------------------------------------------------
    printvar "APACHE2_VHOST_N"           "no. of virtual hosts"

    if [ "$APACHE2_VHOST_1_IP" != "" ]
    then
        idx='1'
        count=`expr $APACHE2_VHOST_N + 0`
    
        while [ $idx -le $count ]
        do
            printvar "APACHE2_VHOST_"$idx"_ACTIVE"                  "Should the VHost be active?"
            printvar "APACHE2_VHOST_"$idx"_IP"                      "'*' or ip address"
            printvar "APACHE2_VHOST_"$idx"_PORT"                    "Port"
            printvar "APACHE2_VHOST_"$idx"_SERVER_NAME"             "server name"
            printvar "APACHE2_VHOST_"$idx"_SERVER_ALIAS"            "server alias, may be empty"
            printvar "APACHE2_VHOST_"$idx"_SERVER_ADMIN"            "email of webmaster"
            printvar "APACHE2_VHOST_"$idx"_DOCUMENT_ROOT"           "document root"
            printvar "APACHE2_VHOST_"$idx"_SCRIPT_ALIAS"            "script alias"
            printvar "APACHE2_VHOST_"$idx"_SCRIPT_DIR"              "directory to use"
            printvar "APACHE2_VHOST_"$idx"_ERROR_LOG"               "error log"
            printvar "APACHE2_VHOST_"$idx"_ACCESS_LOG"              "access log"
            printvar "APACHE2_VHOST_"$idx"_ACCESS_CONTROL"          "controls who get stuff"
            printvar "APACHE2_VHOST_"$idx"_VIEW_DIRECTORY_CONTENT"  ""
            printvar "APACHE2_VHOST_"$idx"_ENABLE_SSI"              ""
            printvar "APACHE2_VHOST_"$idx"_MOD_CACHE"               "Enable mod_cache for current vhost"
            printvar "APACHE2_VHOST_"$idx"_DIR_N"                   ""
            dirIdx='1'
            eval tmpDir='$APACHE2_VHOST_'$idx'_DIR_N'
            countDir=`expr $tmpDir + 1`
    
            while [ $dirIdx -le $countDir ]
            do
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_ACTIVE"           ""
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_ALIAS"            "Create an alias?"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_ALIAS_NAME"       "Name of alias"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_PATH"             "Name of 1. dir"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_AUTH_NAME"        "Name of the area to protect"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_AUTH_TYPE"        "Authentication type: Basic or Digest"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_AUTH_N"           "No. of usernames"
                authIdx='1'
                eval tmpAuth='$APACHE2_VHOST_'$idx'_DIR_'$dirIdx'_AUTH_N'
                countAuth=`expr $tmpAuth + 1`
    
                while [ $authIdx -le $countAuth ]
                do
                    printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_AUTH_"$authIdx"_USER"      ""
                    printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_AUTH_"$authIdx"_PASS"      ""
                    authIdx=`expr $authIdx + 1`
                done
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_ACCESS_CONTROL"   "e.g. 192.168.0.0/24 or 192.168."
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_CGI"              "!NOT YES! Possibilities are: 'none' '.pl' '.cgi'"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_SSI"              "Allow Server Side Includes?"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_VIEW_DIR_CONTENT" "View files in dir if no index.html"
                printvar "APACHE2_VHOST_"$idx"_DIR_"$dirIdx"_WEBDAV"           "Enable WebDav"
                dirIdx=`expr $dirIdx + 1`
            done
            printvar "APACHE2_VHOST_"$idx"_SSL"                  "activate SSL"
            printvar "APACHE2_VHOST_"$idx"_SSL_PORT"             "activate SSL"
            printvar "APACHE2_VHOST_"$idx"_SSL_FORCE"            "redirect to https://"
            printvar "APACHE2_VHOST_"$idx"_SSL_CERT_NAME"        "Name of the cert."

            idx=`expr $idx + 1`
        done
    fi

    # ----------------------------------------------------------------------
    printgroup "Log-file handling"
    # ----------------------------------------------------------------------
    printvar "APACHE2_LOG_LEVEL"              "warning level"
    printvar "APACHE2_LOG_COUNT"              "number of log files to save"
    printvar "APACHE2_LOG_INTERVAL"           "logrotate interval: daily, weekly, monthly"

    #----------------------------------------------------------------------------
    printgroup "Settings for performance tuning"
    #----------------------------------------------------------------------------
    printvar "APACHE2_MAX_KEEP_ALIVE_TIMEOUT"  ""
    printvar "APACHE2_MAX_KEEP_ALIVE_REQUESTS" ""
    printvar "APACHE2_MAX_CLIENTS"             ""
    printvar "APACHE2_MAX_REQUESTS_PER_CHILD"  ""

    #----------------------------------------------------------------------------
    printgroup "Settings for apache modules"
    #----------------------------------------------------------------------------
    printvar "APACHE2_MOD_CACHE"               "Enable mod_cache for localhost"

    #------------------------------------------------------------------------------
    printgroup "End of Apache2 Configuraton"
    #------------------------------------------------------------------------------

    #------------------------------------------------------------------------------
    printend
    #------------------------------------------------------------------------------

    ) > ${internal_conf_file}
    # Set rights
    chmod 0644 ${internal_conf_file}
    chown root ${internal_conf_file}
}

### -------------------------------------------------------------------------
### Create the check.d file
### -------------------------------------------------------------------------
make_check_file()
{
    printgpl -check "$packages_name" "$datum_creation" "schlotze" "2008-2010 Sebastian Scholze <sebastian@eisfair.org>" > /etc/check.d/${packages_name}
    cat >/etc/check.d/${packages_name} <<EOF_INT
# Variable                             OPT_VARIABLE                  VARIABLE_N                   VALUE
START_APACHE2                          -                             -                            YESNO
APACHE2_PORT                           -                             -                            NUMERIC
APACHE2_SERVER_ADMIN                   -                             -                            MAILADDR
APACHE2_SERVER_NAME                    -                             -                            EFQDN
APACHE2_SERVER_SIGNATURE               -                             -                            APACHE2_SERVER_SIGNATURE
APACHE2_DIRECTORY_INDEX                -                             -                            NONE
APACHE2_HOSTNAME_LOOKUPS               -                             -                            YESNO
APACHE2_VIEW_DIRECTORY_CONTENT         -                             -                            YESNO
APACHE2_ACCESS_CONTROL                 -                             -                            NONE
APACHE2_ENABLE_SSI                     -                             -                            YESNO
APACHE2_ENABLE_USERDIR                 -                             -                            YESNO
APACHE2_ERROR_LOG                      -                             -                            ABS_PATH
APACHE2_ACCESS_LOG                     -                             -                            ABS_PATH
APACHE2_SCRIPT_ALIAS                   -                             -                            ABS_PATH
APACHE2_SCRIPT_DIR                     -                             -                            ABS_PATH
APACHE2_ERROR_DOCUMENT_N               -                             -                            NUMERIC
APACHE2_ERROR_DOCUMENT_%_ERROR         -                             APACHE2_ERROR_DOCUMENT_N     NUMERIC
APACHE2_ERROR_DOCUMENT_%_DOCUMENT      -                             APACHE2_ERROR_DOCUMENT_N     NONE
APACHE2_DIR_N                          -                             -                            NUMERIC
APACHE2_DIR_%_ACTIVE                   -                             APACHE2_DIR_N                YESNO
APACHE2_DIR_%_ALIAS                    APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                YESNO
APACHE2_DIR_%_ALIAS_NAME               APACHE2_DIR_%_ALIAS           APACHE2_DIR_N                E_ABS_PATH
APACHE2_DIR_%_PATH                     APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                ABS_PATH
APACHE2_DIR_%_AUTH_NAME                APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                NONE
APACHE2_DIR_%_AUTH_TYPE                APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                APACHE2_DIR_AUTH_TYPE
APACHE2_DIR_%_AUTH_N                   APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                NUMERIC
APACHE2_DIR_%_AUTH_%_USER              APACHE2_DIR_%_ACTIVE          APACHE2_DIR_%_AUTH_N         NONE
APACHE2_DIR_%_AUTH_%_PASS              APACHE2_DIR_%_ACTIVE          APACHE2_DIR_%_AUTH_N         PASSWD
APACHE2_DIR_%_CGI                      APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                NONE
APACHE2_DIR_%_SSI                      APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                YESNO
APACHE2_DIR_%_ACCESS_CONTROL           APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                NONE
APACHE2_DIR_%_VIEW_DIR_CONTENT         APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                YESNO
APACHE2_DIR_%_WEBDAV                   APACHE2_DIR_%_ACTIVE          APACHE2_DIR_N                YESNO
APACHE2_SSL                            -                             -                            YESNO
APACHE2_SSL_PORT                       APACHE2_SSL                   -                            NUMERIC
APACHE2_SSL_LOGDIR                     APACHE2_SSL                   -                            ABS_PATH
APACHE2_VHOST_N                        -                             -                            NUMERIC
APACHE2_VHOST_%_ACTIVE                 -                             APACHE2_VHOST_N              YESNO
APACHE2_VHOST_%_IP                     APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              RE:\*|(RE:IPADDR)
APACHE2_VHOST_%_PORT                   APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              NUMERIC
APACHE2_VHOST_%_SERVER_NAME            APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              FQDN
APACHE2_VHOST_%_SERVER_ALIAS           APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              NONE
APACHE2_VHOST_%_SERVER_ADMIN           APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              MAILADDR
APACHE2_VHOST_%_DOCUMENT_ROOT          APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              ABS_PATH
APACHE2_VHOST_%_SCRIPT_ALIAS           APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              ABS_PATH
APACHE2_VHOST_%_SCRIPT_DIR             APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              ABS_PATH
APACHE2_VHOST_%_ERROR_LOG              APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              ABS_PATH
APACHE2_VHOST_%_ACCESS_LOG             APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              ABS_PATH
APACHE2_VHOST_%_ACCESS_CONTROL         APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              NONE
APACHE2_VHOST_%_VIEW_DIRECTORY_CONTENT APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              YESNO
APACHE2_VHOST_%_ENABLE_SSI             APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              YESNO  
APACHE2_VHOST_%_MOD_CACHE              APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              YESNO
APACHE2_VHOST_%_DIR_N                  APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              NUMERIC
APACHE2_VHOST_%_DIR_%_ACTIVE           APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_%_DIR_N        YESNO
APACHE2_VHOST_%_DIR_%_ALIAS            APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        YESNO
APACHE2_VHOST_%_DIR_%_ALIAS_NAME       APACHE2_VHOST_%_DIR_%_ALIAS   APACHE2_VHOST_%_DIR_N        E_ABS_PATH
APACHE2_VHOST_%_DIR_%_PATH             APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        ABS_PATH
APACHE2_VHOST_%_DIR_%_AUTH_NAME        APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        NONE
APACHE2_VHOST_%_DIR_%_AUTH_TYPE        APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        APACHE2_DIR_AUTH_TYPE
APACHE2_VHOST_%_DIR_%_AUTH_N           APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        NUMERIC
APACHE2_VHOST_%_DIR_%_AUTH_%_USER      APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_%_AUTH_N NONE
APACHE2_VHOST_%_DIR_%_AUTH_%_PASS      APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_%_AUTH_N PASSWD
APACHE2_VHOST_%_DIR_%_ACCESS_CONTROL   APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        NONE
APACHE2_VHOST_%_DIR_%_CGI              APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        NONE
APACHE2_VHOST_%_DIR_%_SSI              APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        YESNO
APACHE2_VHOST_%_DIR_%_VIEW_DIR_CONTENT APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        YESNO
APACHE2_VHOST_%_DIR_%_WEBDAV           APACHE2_VHOST_%_DIR_%_ACTIVE  APACHE2_VHOST_%_DIR_N        YESNO
APACHE2_VHOST_%_SSL                    APACHE2_VHOST_%_ACTIVE        APACHE2_VHOST_N              YESNO
APACHE2_VHOST_%_SSL_PORT               APACHE2_VHOST_%_SSL           APACHE2_VHOST_N              NUMERIC
APACHE2_VHOST_%_SSL_FORCE              APACHE2_VHOST_%_SSL           APACHE2_VHOST_N              YESNO
APACHE2_VHOST_%_SSL_CERT_NAME          APACHE2_VHOST_%_SSL           APACHE2_VHOST_N              NOTEMPTY
APACHE2_LOG_LEVEL                      -                             -                            APACHE2_LOG_LEVEL
APACHE2_LOG_COUNT                      -                             -                            NUMERIC
APACHE2_LOG_INTERVAL                   -                             -                            APACHE2_LOG_INTERVAL
APACHE2_MAX_KEEP_ALIVE_TIMEOUT         -                             -                            NUMERIC
APACHE2_MAX_KEEP_ALIVE_REQUESTS        -                             -                            NUMERIC
APACHE2_MAX_CLIENTS                    -                             -                            NUMERIC
APACHE2_MAX_REQUESTS_PER_CHILD         -                             -                            NUMERIC
APACHE2_MOD_CACHE                      -                             -                            YESNO

EOF_INT

    # Set rights for check.d file
    chmod 0644 /etc/check.d/${packages_name}
    chown root /etc/check.d/${packages_name}

### ---------------------------------------------------------------------------
### Create the EXTENTED check.d file
### ---------------------------------------------------------------------------
    printgpl -check_exp "$packages_name" "${datum_update}" "${my_initial}" "${my_name}" > /etc/check.d/${packages_name}.exp
cat >> /etc/check.d/${packages_name}.exp << EOF
APACHE2_LOG_LEVEL        = 'debug|info|notice|warn|error|crit|alert|emerg'
                          : 'no valid level, should be debug, info, notice, warn, error, crit, alert or emerg'
APACHE2_LOG_INTERVAL     = 'daily|weekly|monthly'
                          : 'no valid interval, should be daily, weekly or monthly'
APACHE2_SERVER_SIGNATURE = 'On|Off|Email'
                          : 'only on, off or email is allowd'
APACHE2_DIR_AUTH_TYPE    = 'Basic|Digest'
                          : 'only Basic or Digest is allowd'
EOF
    # Set rights for check.exp file
    chmod 0644 /etc/check.d/${packages_name}.exp
    chown root /etc/check.d/${packages_name}.exp
}

### ---------------------------------------------------------------------------
### Main
### ---------------------------------------------------------------------------
# write default config file
make_config_file /etc/default.d/${packages_name}

# Der erste Beispiel VHost soll nur waehrend der Installation angelegt werden 
# und dann auch nur, wenn noch keine Konfigurationsdatei existiert. 
# Waere dieser Scriptblock nicht da, koennte man den ersten VHost nie entfernen
if [ ! -f /tmp/apache-install.lock ]
then
    vhost_n_old=$APACHE_VHOST_N

    APACHE2_VHOST_N='1'
    unset_vhost_vars

    APACHE2_VHOST_N=$vhost_n_old
fi

# update from old version
if [ -f /etc/config.d/$packages_name ]
then
    rename_old_variables
fi

# write new config file
make_config_file /etc/config.d/${packages_name}

# write check.d file
make_check_file

### ---------------------------------------------------------------------------
### end
### ---------------------------------------------------------------------------
