#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/config.d/bind-update.sh - BIND config parameter update script
# Creation:     2004-08-20 jv <jens@eisfair.org>
#------------------------------------------------------------------------------
packages_name="named"
DataDir="/var/named"

# include configlib
. /var/install/include/configlib

# include base
. /etc/config.d/base

# include default values
. /etc/default.d/${packages_name}

# convert old eisfair-1/eisfair-2 config files
if [ -f /etc/config.d/bind9 ] ; then
    sed -e -i "s|BIND9_|BIND_|g" /etc/config.d/bind9
    rm -f /etc/config.d/${packages_name}
    mv -f /etc/config.d/bind9 /etc/config.d/${packages_name}
fi

[ -f /etc/config.d/${packages_name} ] && . /etc/config.d/${packages_name}


### ---------------------------------------------------------------------------
### update config file
### ---------------------------------------------------------------------------
{
    printgpl -conf "$packages_name" "2004-08-20" "jv" "Jens Vehlhaber"

    printgroup "General settings"

    printvar "START_BIND" "Namserver start 'yes' or 'no'"

    printvar "BIND_FORWARDER_N" "Number of forwarders"
    printvar "BIND_FORWARDER_1_IP" "IP-Address of forwarder"
    printvar "BIND_FORWARDER_1_EDNS" "Use EDNS for communication"
    in="2"
    while [ $in -le $BIND_FORWARDER_N ]
    do
        printvar "BIND_FORWARDER_${in}_IP" ""
        printvar "BIND_FORWARDER_${in}_EDNS" ""
        in=`expr ${in} + 1`
    done

    printvar "BIND_ALLOW_QUERY" "any, localnets, localhost"

    printgroup "DNS zones"

    printvar "BIND_N" "number of DNS zones (domains)"
    printvar ""        "primary and secondary"
    znr="1"
    while [ ${znr} -le $BIND_N ]
    do
        echo ""
        # eval tempvar='$BIND_'${znr}'_NAME'
        # echo "BIND_${znr}_NAME='$tempvar'"
        printvar "BIND_${znr}_NAME" "Name of zone"
        printvar "BIND_${znr}_MASTER" "Server is master of zone"
        printvar "BIND_${znr}_NETWORK" "Network of zone "
        printvar "BIND_${znr}_NETMASK" "Netmask"
        printvar "BIND_${znr}_MASTER_IP" "IP-Adress of master server"
        printvar "BIND_${znr}_MASTER_NS" "Optional full name of master server"

        echo ""
        # allow transfer to
        printvar "BIND_${znr}_ALLOW_TRANSFER" "any, localnets, nslist, none"

        # ns records
        echo ""
        printvar "BIND_${znr}_NS_N" "Number of secondary name server"
        printvar "BIND_${znr}_NS_1_NAME" "Full name of secondary name server"
        printvar "BIND_${znr}_NS_1_IP" "IP - only for use ALLOW_TRANSFER=nslist"

        in="2"
        eval incount='$BIND_'${znr}'_NS_N'
        while [ $in -le $incount ]
        do
            printvar "BIND_${znr}_NS_${in}_NAME" ""
            printvar "BIND_${znr}_NS_${in}_IP" ""
            in=`expr $in + 1`
        done

        # mx records
        echo ""
        printvar "BIND_${znr}_MX_N" "Number of mail server"
        printvar "BIND_${znr}_MX_1_NAME" "Full name of mail server"
        printvar "BIND_${znr}_MX_1_PRIORITY" "Priority 10=high 90=low"

        in="2"
        eval incount='$BIND_'${znr}'_MX_N'
        while [ $in -le $incount ]
        do
            echo ""
            printvar "BIND_${znr}_MX_${in}_NAME" ""
            printvar "BIND_${znr}_MX_${in}_PRIORITY" ""
            in=`expr ${in} + 1`
        done
        echo ""

        # a records
        printvar "BIND_${znr}_HOST_N" "Number of hosts"

        echo ""
        printvar "BIND_${znr}_HOST_1_NAME" "Hostname"
        printvar "BIND_${znr}_HOST_1_IP" "IP-address of host"
        printvar "BIND_${znr}_HOST_1_ALIAS" "Optional alias names"
        in="2"

        echo ""

        eval incount='$BIND_'${znr}'_HOST_N'
        while [ $in -le $incount ]
        do
            echo ""
            printvar "BIND_${znr}_HOST_${in}_NAME" ""
            printvar "BIND_${znr}_HOST_${in}_IP" ""

            eval temp1='$BIND_'${znr}'_HOST_'${in}'_ALIAS'
            if [ -n "$temp1" ]
            then
                printvar "BIND_${znr}_HOST_${in}_ALIAS" ""
            fi
            in=`expr ${in} + 1`
        done
        znr=`expr ${znr} + 1`
    done

    printgroup "Special settings"

    printvar "BIND_PORT_53_ONLY" "Restrict communication; default no"

    printvar "BIND_BIND_IP_ADDRESS" "Restrict network; default empty"

    printvar "BIND_DEBUG_LOGFILE" "Debug to logfile; default no"

    printend
} > /etc/config.d/${packages_name}
# Set rights
chmod 0644 /etc/config.d/${packages_name}
chown root /etc/config.d/${packages_name}

### ---------------------------------------------------------------------------
exit 0

