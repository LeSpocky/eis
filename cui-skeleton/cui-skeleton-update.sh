#!/bin/sh
# ----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
# ----------------------------------------------------------------------------

# Name of the current package
# ---------------------------
packageName=skeleton

# Include used libs
# -----------------
. /var/install/include/configlib     # Configlib with helpers etc. pp.

### --------------------------------------------------------------------------
### Read current configuration
### --------------------------------------------------------------------------

# Set the defaults from default.d file...
. /etc/default.d/${packageName}

# ... and replace them with configured ones if existing
. /etc/config.d/${packageName}

### --------------------------------------------------------------------------
### Write the new config
### --------------------------------------------------------------------------
(
    # ------------------------------------------------------------------------
    printgpl --conf "$packageName"

    printgroup "General settings"

    printvar "START_SKELETON"          "Start service yes or no"

    printvar "SKELETON_PORT"           "Listen for an incoming connection. Default 21."

    printvar "SKELETON_BIND"           "If set, then bind the SKELETON port only to ip-address."
    
    printvar "SKELETON_LOG_INTERVAL"   "Logrotate interval"

    printvar "SKELETON_LOG_MAXCOUNT"   "Max count of logfiles"

) > /etc/config.d/${packageName}

# Set proper permissions
chmod 0644  /etc/config.d/${packageName}
chown root  /etc/config.d/${packageName}

exit 0
