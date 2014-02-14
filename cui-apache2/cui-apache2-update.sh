#!/bin/sh
#----------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

packages_name=apache2

# include libs for using
. /var/install/include/configlib

# set the defaults from default.d file
. /etc/default.d/${packages_name}
# read old values if exists
[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}

### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    #------------------------------------------------------------------------
    printgpl --conf "$packages_name"

    #------------------------------------------------------------------------
    printgroup  "Start Apache2 Webserver during startup"
    #------------------------------------------------------------------------
    printvar "START_APACHE2"            "Start the Apache Webserver"

    #------------------------------------------------------------------------
    printgroup  "General settings"
    #------------------------------------------------------------------------
    printvar "APACHE2_PORT"             "TCP/IP port"
    printvar "APACHE2_SERVER_NAME"      "FQND of the server e.g."
    printvar ""                         "meineis.eisfair.net"
    printvar "APACHE2_SERVER_ADMIN"     "Email address of webmaster "
    printvar "APACHE2_SERVER_SIGNATURE" "On/Off/Email"

    #------------------------------------------------------------------------------
    printgroup "Gerneral SSL Settings"
    #------------------------------------------------------------------------------
    printvar "APACHE2_SSL"        "Start SSL-Engine?"
    printvar "APACHE2_SSL_PORT"   "Port on which SSL should run"

    #------------------------------------------------------------------------
    printgroup  "Special Settings"
    #------------------------------------------------------------------------
    printvar "APACHE2_DIRECTORY_INDEX"        "Default document"
    printvar "APACHE2_HOSTNAME_LOOKUPS"       "Resolve IPs in logfile?"
    printvar "APACHE2_VIEW_DIRECTORY_CONTENT" "If there's no index.html view files in dir"
    printvar "APACHE2_ACCESS_CONTROL"         "Who get access e.g. 192.168.0.0/24"
    printvar "APACHE2_ENABLE_SSI"             "Enable SSI 'yes' or 'no'"
    printvar "APACHE2_ENABLE_USERDIR"         "Show content of /home/USER/public_html"

    #------------------------------------------------------------------------------
    printgroup "Error Documents"
    #------------------------------------------------------------------------------
    printvar "APACHE2_ERROR_DOCUMENT_N"       "no. costum of Error Documents"

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
        fi
        idx=`expr $idx + 1`
    done


    #------------------------------------------------------------------------------
    printgroup "Virtual Hosts" 
    #------------------------------------------------------------------------------
    printvar "APACHE2_VHOST_N"           "no. of virtual hosts"

    if [ -n "$APACHE2_VHOST_1_IP" ]
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
            printvar "APACHE2_VHOST_"$idx"_ACCESS_CONTROL"          "controls who get stuff"
            printvar "APACHE2_VHOST_"$idx"_VIEW_DIRECTORY_CONTENT"  ""
            printvar "APACHE2_VHOST_"$idx"_ENABLE_SSI"              ""
            printvar "APACHE2_VHOST_"$idx"_MOD_CACHE"               "Enable mod_cache for current vhost"
            printvar "APACHE2_VHOST_"$idx"_DIR_N"                   ""
            printvar "APACHE2_VHOST_"$idx"_SSL"                     "activate SSL"
            printvar "APACHE2_VHOST_"$idx"_SSL_PORT"                "activate SSL"
            printvar "APACHE2_VHOST_"$idx"_SSL_FORCE"               "redirect to https://"
            printvar "APACHE2_VHOST_"$idx"_SSL_CERT_NAME"           "Name of the cert."
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
    printend
    #------------------------------------------------------------------------------

) > /etc/config.d/${packages_name}
# Set rights
chmod 0600  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
