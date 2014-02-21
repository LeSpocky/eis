#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# include configlib
. /var/install/include/configlib

packages_name='clamav'

# include default values
. /etc/default.d/${packages_name}

# convert old eisfair-1/eisfair-2 config files
if [ -f /etc/config.d/bind9 ] ; then
    sed -i -e "s|CLAMAV_|CLAMD_|g" /etc/config.d/clamav
    rm -f /etc/config.d/${packages_name}
    cp -f /etc/config.d/clamav /etc/config.d/${packages_name}
fi

[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}

### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    #------------------------------------------------------------------------
    printgpl --conf "$packages_name"
    #------------------------------------------------------------------------------
    printgroup "general settings"
    #------------------------------------------------------------------------------
    printvar "START_CLAMD"                  "activate ClamAV: yes or no"
    # ----------------------------------------------------------------------
    printgroup "Settings for automatic update"
    # ----------------------------------------------------------------------
    printvar "CLAMD_UPDATE_REGION"          "the region for database mirrors (de, fr, us...)"
    printvar "CLAMD_UPDATE_CRON_USE"        "run scheduled updates (yes/no)"
    printvar "CLAMD_UPDATE_CRON_TIMES"      "schedule (in cron syntax)"
    # ----------------------------------------------------------------------
    printgroup "SelfChecking Options"
    # ----------------------------------------------------------------------
    printvar "CLAMD_SELFCHECK"              "SelfChecking Options"
    # ----------------------------------------------------------------------
    printgroup "Priority Settings"
    # ----------------------------------------------------------------------
    printvar "CLAMD_PRIORITY_LEVEL"         "Nice scheduling priority"
    # ----------------------------------------------------------------------
    printgroup "Proxy Settings"
    # ----------------------------------------------------------------------
    printvar "CLAMD_USE_HTTP_PROXY_SERVER"  "Use proxy"
    printvar "CLAMD_HTTP_PROXY_SERVER"      "Servername"
    printvar "CLAMD_HTTP_PROXY_PORT"        "port of proxy"
    printvar "CLAMD_HTTP_PROXY_USERNAME"    "Username"
    printvar "CLAMD_HTTP_PROXY_PASSWORD"    "Password"
    # ----------------------------------------------------------------------
    printgroup "PUA support"
    # ----------------------------------------------------------------------
	printvar "CLAMD_DETECT_PUA"				 "yes or no"
	printvar "CLAMD_ALGORITHMIC_DETECTION"   "yes or no"
    # ----------------------------------------------------------------------
    printgroup "Executable file support"
    # ----------------------------------------------------------------------
	printvar "CLAMD_SCAN_PE"				 "yes or no"
	printvar "CLAMD_SCAN_ELF"				 "yes or no"
	printvar "CLAMD_DETECT_BROKEN_EXECUTABLES" "yes or no"
    # ----------------------------------------------------------------------
    printgroup "Document support"
    # ----------------------------------------------------------------------
    printvar "CLAMD_SCAN_OLE2"               "enables scanning of MS-Office document macros"
	printvar "CLAMD_SCAN_PDF"				 "yes or no"
    # ----------------------------------------------------------------------
    printgroup "Scann archive support"
    # ----------------------------------------------------------------------
    printvar "CLAMD_SCAN_ARCHIVE"            "yes or no"
    printvar "CLAMD_MAX_FILE_SIZE"           "limit (Megabyte) won't be scanned. 0=no limit"
    printvar "CLAMD_MAX_RECURSIONS"          "Mac count archives are scanned recursively. 0=no limit"
    printvar "CLAMD_MAX_FILES"               "Number of files to be scanned within archive. 0=no limit"
    printvar "CLAMD_ARCHIVE_BLOCK_ENCRYPTED" "Mark encrypted archives as viruses"
    # ----------------------------------------------------------------------
    printgroup "Virus info mail"
    # ----------------------------------------------------------------------
    printvar "CLAMD_VIRUSEVENT_MAIL"         "Send info mail if found virus"
    printvar "CLAMD_VIRUSEVENT_TO"           "Address for info mail"
    # ----------------------------------------------------------------------
    printend
    # ----------------------------------------------------------------------
) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
