#!/bin/sh
#----------------------------------------------------------------------------
# eisfair-ng configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

packages_name=open-vm-tools

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
    printgpl "$packages_name" "2013-11-21" "jv" "2008-2013 jv <jens@eisfair.org>"
    #------------------------------------------------------------------------

    printvar "START_VMTOOLS"            "Start the open-vm-tools on boot time"
    printvar "VMTOOLS_ALL_MODULES"      "Load all kernel modules"

    #------------------------------------------------------------------------
    printend
    #------------------------------------------------------------------------
) > /etc/config.d/${packages_name}
# Set rights
chmod 0600  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
