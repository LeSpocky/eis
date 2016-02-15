#!/bin/sh
#----------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=webalizer

# include libs for using
# ----------------------
. /var/install/include/configlib

# set the defaults from default.d file
. /etc/default.d/${packages_name}

# convert to import old eisfair-1/eisfair-2 config files
if [ -f /etc/config.d/apache2_webalizer ] ; then
    sed -i "s|START_APACHE2_WEBALIZER|START_WEBALIZER|g" /etc/config.d/apache2_webalizer
    rm -f /etc/config.d/${packages_name}
    mv -f /etc/config.d/apache2_webalizer /etc/config.d/${packages_name}
fi

# read old values if exists
[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}
[ -f /etc/config.d/apache2 ] && . /etc/config.d/apache2

# ----------------------------------------------------------------------------
# Write config and default files
# ----------------------------------------------------------------------------
{
    # ------------------------------------------------------------------------
    printgpl --conf "$packages_name"
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
	idx=$((idx+1))
    done

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------
} > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
