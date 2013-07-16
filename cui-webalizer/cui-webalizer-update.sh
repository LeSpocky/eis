#!/bin/sh
#----------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=webalizer

# include libs for using
# ----------------------
. /var/install/include/configlib


# set the defaults from default.d file
. /etc/default.d/${packages_name}
# read old values if exists
[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}

. /etc/config.d/apache2


# ----------------------------------------------------------------------------
# Write config and default files
# ----------------------------------------------------------------------------
{
    # ------------------------------------------------------------------------
    printgpl "$packages_name" "2013-07-16" "jv" "2005-2013 Jens Vehlhaber <jv@eisfair.org>"
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    printgroup "Basic configuration"
    # ------------------------------------------------------------------------
    printvar "START_WEBALIZER"               "Start webalizer with cronjob"
    printvar "WEBALIZER_CRON"                "Everyday at 23:xx"

    # ------------------------------------------------------------------------
    printgroup "Apache VHOST configuration"
    # ------------------------------------------------------------------------
    printvar "WEBALIZER_VHOSTS_RUN_ALL"      "Use: yes or no for run Webalizer over all apache2 VHosts"
    printvar "WEBALIZER_VHOSTS_OUTPUT_DIR"   "Where to put the analysis possible variables are %SERVER_NAME% and %VHOST_DOCROOT%"
    printvar "WEBALIZER_VHOSTS_TITLE"        "The title at the top of the analysis"
    printvar "WEBALIZER_VHOSTS_BGCOLOR"      "The backgroundcolor"

    # ------------------------------------------------------------------------
    printgroup "Optional logfiles"
    # ------------------------------------------------------------------------
    printvar "WEBALIZER_HOST_N"               "Count of hosts"
    idx="1"
    while [ $idx -le $WEBALIZER_HOST_N ]
    do
        printvar "WEBALIZER_HOST_${idx}_ACCESS_LOG" "Accesslog of Apache"
        printvar "WEBALIZER_HOST_${idx}_OUTPUT_DIR" "Where to put the analysis"
        printvar "WEBALIZER_HOST_${idx}_HOST_NAME"  "Hostname of the (V)Host"
        printvar "WEBALIZER_HOST_${idx}_TITLE"      "The title at the top of the analysis"
        printvar "WEBALIZER_HOST_${idx}_BGCOLOR"    "The backgroundcolor"
        printvar "WEBALIZER_HOST_${idx}_TYPE"       "'clf' for Apache, 'squid' for Squid, 'ftp' for FTP"
        idx=`expr $idx + 1`
    done

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------
) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
