#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name="dhcpd"

# include libs for using
# ----------------------
. /var/install/include/configlib     # configlib from eisfair

### -------------------------------------------------------------------------
### read old configuration and rename old variables
### -------------------------------------------------------------------------
# set the defaults from default.d file
. /etc/default.d/${packages_name}

. /etc/config.d/${packages_name}


### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    #------------------------------------------------------------------------
    printgpl --conf "$packages_name"

    #------------------------------------------------------------------------------
    printgroup "Basic configuration"
    #------------------------------------------------------------------------------

    printvar "START_DHCP "                       "activate configuration: yes or no"

    printvar "DHCP_NETWORK_GATE"                 "ip-address of network gateway"

    in="1"
    while [ $in -le 0$DHCP_CLIENT_N ]
    do
        printvar 'DHCP_DYNAMIC_'$in'_ACTIVE'     "use this range to provide dhcp?"
        printvar 'DHCP_DYNAMIC_'$in'_RANGE'      "ip range for dhcp"
        in=$((in+1))
    done
    
    #------------------------------------------------------------------------------
    printgroup "DHCP Clients"
    #------------------------------------------------------------------------------
    
    in="1"
    while [ $in -le 0$DHCP_CLIENT_N ]
    do
        printvar 'DHCP_CLIENT_'$in'_NAME'       "hostname"
        printvar 'DHCP_CLIENT_'$in'_ACTIVE'     "is this client available?"
        printvar 'DHCP_CLIENT_'$in'_MAC'        "mac address"
        printvar 'DHCP_CLIENT_'$in'_IPV4'       "ipv4 address"
        printvar 'DHCP_CLIENT_'$in'_IPV6'       "ipv6 address"
        printvar 'DHCP_CLIENT_'$in'_NETBOOT'    "filename for netboot     (optional)"
        printvar 'DHCP_CLIENT_'$in'_PXE_KERNEL' "kernel for pxelinux boot (optional)" 
        printvar 'DHCP_CLIENT_'$in'_PXE_INITRD' "initrd for pxelinux boot (optional)"
        printvar 'DHCP_CLIENT_'$in'_PXE_ROOTFS' "rootfs for pxelinux boot (optional)"
        printvar 'DHCP_CLIENT_'$in'_PXE_APPEND' "additional parameters    (optional)"
        printvar ""                              "for pxelinux boot"
        echo
        in=$((in+1))
    done    
    

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
