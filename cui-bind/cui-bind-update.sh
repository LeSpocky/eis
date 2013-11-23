#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/config.d/bind9-update.sh - BIND9 parameter update script
#
# Copyright (c) 2004 Jens Vehlhaber <jens(at)eisfair(dot)org>
#
# Creation:     2004-08-20 jv
# Last Update:  $Id: bind9-update.sh 23554 2010-03-20 22:42:59Z jv $
#
#------------------------------------------------------------------------------
packages_name="bind"
DataDir="/var/named"

# include configlib
. /var/install/include/configlib

### ---------------------------------------------------------------------------
### Set the default values for configuration
### ---------------------------------------------------------------------------
. /etc/config.d/base

START_BIND="no"

BIND_ALLOW_QUERY="any"

BIND_FORWARDER_N="2"
BIND_FORWARDER_1_IP="8.8.8.8"
BIND_FORWARDER_1_EDNS="yes"
BIND_FORWARDER_2_IP="8.8.4.4"
BIND_FORWARDER_2_EDNS="yes"

BIND_N="2"
BIND_1_NAME="$DOMAIN_NAME"
BIND_1_MASTER="yes"
BIND_1_NETWORK="192.168.2.0"
BIND_1_NETMASK="255.255.255.0"
BIND_1_MASTER_IP="192.168.2.10"
BIND_1_MASTER_NS="${HOSTNAME}.${DOMAIN_NAME}"
BIND_1_ALLOW_TRANSFER="any"

BIND_1_NS_N="1"
BIND_1_NS_1_NAME="dns2.${DOMAIN_NAME}"
BIND_1_NS_1_IP=""

BIND_1_MX_N="2"
BIND_1_MX_1_NAME="mail.${DOMAIN_NAME}"
BIND_1_MX_1_PRIORITY="10"

BIND_1_MX_2_NAME="mail-backup.${DOMAIN_NAME}"
BIND_1_MX_2_PRIORITY="20"

BIND_1_HOST_N="2"

BIND_1_HOST_1_NAME="server1"
BIND_1_HOST_1_IP="192.168.2.10"
BIND_1_HOST_1_ALIAS="www1"

BIND_1_HOST_2_NAME="server2"
BIND_1_HOST_2_IP="192.168.2.11"
BIND_1_HOST_2_ALIAS="www2 ftp"


BIND_2_NAME="foo2.local"
BIND_2_MASTER="no"
BIND_2_NETWORK="172.16.0.0"
BIND_2_NETMASK="255.255.0.0"
BIND_2_MASTER_IP="172.16.0.1"
BIND_2_ALLOW_TRANSFER="any"

BIND_2_NS_N="0"
BIND_2_MX_N="0"
BIND_2_HOST_N="0"

BIND_BIND_IP_ADDRESS=""
BIND_PORT_53_ONLY="no"
BIND_DEBUG_LOGFILE="no"

# include default values
. /etc/default.d/${packages_name}

### ---------------------------------------------------------------------------
### rename old variables
### ---------------------------------------------------------------------------
function rename_old_variables
{
    # read old config
    [ -f /etc/config.d/${packages_name} ] &&  . /etc/config.d/${packages_name}

    # update from DNS package
    [ -f /etc/config.d/bind9 ] || return 0
    . /etc/config.d/bind9
    START_BIND="$START_BIND9"
    if [ -n "$DNS_FORWARDERS" ] ; then
       cnt="1"
            for s in $DNS_FORWARDERS
            do
                eval BIND_FORWARDER_${cnt}_IP=${s}
                BIND_FORWARDER_N=${cnt}
                cnt=`expr $cnt + 1`
            done
    fi
    BIND_DEBUG_LOGFILE="$DNS_VERBOSE"
    BIND_N="1"
    BIND_1_NAME="$DNS_DOMAIN_NAME"
    BIND_1_MASTER="yes"
    # no secondary NS records
    BIND_1_NS_N="0"
    # MX records
    BIND_1_MX_N="$DNS_MX_N"
    cnt="1"
    while [ ${cnt} -le ${BIND_1_MX_N} ]
    do
        eval 'BIND_1_MX_'${cnt}'_NAME'='$DNS_MX_'${cnt}'_HOST'
        eval 'BIND_1_MX_'${cnt}'_PRIORITY'='$DNS_MX_'${cnt}'_PRIORITY'
        cnt=`expr $cnt + 1`
    done
    BIND_1_HOST_N="$DNS_HOST_N"
    cnt="1"
    while [ ${cnt} -le ${BIND_1_HOST_N} ]
    do
        eval 'BIND_1_HOST_'${cnt}'_NAME'='$DNS_HOST_'${cnt}'_NAME'
        eval 'BIND_1_HOST_'${cnt}'_IP'='$DNS_HOST_'${cnt}'_IP'
        eval n_alias='$DNS_HOST_'${cnt}'_ALIAS_N'
        tmpnam1=""
        if [ -n "$n_alias" ] ; then
            n="1"
            while [ ${n} -le ${n_alias} ]
            do
                eval tmpnam2='$DNS_HOST_'${cnt}'_ALIAS_'${n}
                tmpnam3=`echo $tmpnam2 | sed -e 's/^\([^\.]*\)\..*$/\1/'`
                if [ -z "$tmpnam1" ]
                then
                    tmpnam1="$tmpnam3"
                else
                    if [ -z "`echo $tmpnam1 | grep ${tmpnam3}`" ]
                    then
                        tmpnam1="$tmpnam1 $tmpnam3"
                    fi
                fi
                n=`expr $n + 1`
            done
        fi
        eval BIND_1_HOST_${cnt}_ALIAS=\"$tmpnam1\"
        cnt=`expr $cnt + 1`
    done
}


### ---------------------------------------------------------------------------
### Write config and default files
### ---------------------------------------------------------------------------
function make_config_file
{
    internal_conf_file="$1"
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
    } > $internal_conf_file
    # Set rights
    chmod 0644 $internal_conf_file
    chown root $internal_conf_file
}


### ---------------------------------------------------------------------------
### Main
### ---------------------------------------------------------------------------
echo -n "."
rename_old_variables
echo -n "."
# write new config file
make_config_file /etc/config.d/${packages_name}

echo "."

### ---------------------------------------------------------------------------
exit 0

