#!/bin/sh
#-----------------------------------------------------------------------------
# /var/install/config.d/bind.sh - BIND configuration
# Creation:     2004-08-19 jv jens@eisfair.org
#-----------------------------------------------------------------------------
bind_root='/var/lib/named'

# include bind_run_user
bind_run_user=`grep bind_run_user= /etc/init.d/bind | sed "s/bind_run_user=//g"`
[ -z "$bind_run_user" ] && bind_run_user="bind"

# use unix-time for zone serial
bind9_zoneserial=`date '+%s'`
bind9_zonerefresh='6H'
. /etc/config.d/base

bind9_hostname="$HOSTNAME"

#include eisdate-time
. /var/install/include/eistime
# include name of bind run user for chroot and daemon
. ${bind_root}/etc/bind/binduser.conf

### --------------------------------------------------------------------------
### Write dhcp leases list
### --------------------------------------------------------------------------
function write_DHCP_hostlist
{
    # exists a dhcp leases file (eisfair-1 only)
    if [ -f /var/lib/dhcp/dhcpd.leases -a -x /usr/local/bind9/dhcpread ]
    then
        # extract dhcp zone, ip, hostname ,revers ip
        /usr/local/bind9/dhcpread /var/lib/dhcp/dhcpd.leases > ${bind_root}/etc/bind/master/dhcp.txt
    fi
}

### --------------------------------------------------------------------------
### Append dhcp leases list
### --------------------------------------------------------------------------
function append_DHCP_A_records
{
    dhcp_zone_name=$1

    if [ -f ${bind_root}/etc/bind/master/dhcp.txt ]
    then
        ### Set seperator
        old_ifs=$IFS
        IFS=";"

        while read csv_zone_name csv_client_ip csv_client_name csv_reverse
        do
            if [ "$csv_zone_name" == "$dhcp_zone_name" ]
            then
                if ! grep -q "^${csv_client_name} " ${bind_root}/etc/bind/master/${dhcp_zone_name}.zone
                then
                    echo "${csv_client_name}    IN    A    ${csv_client_ip} " >> ${bind_root}/etc/bind/master/${dhcp_zone_name}.zone
                fi
            fi
        done < ${bind_root}/etc/bind/master/dhcp.txt
        IFS=$old_ifs
    fi
}


### --------------------------------------------------------------------------
### generate a zone file
### --------------------------------------------------------------------------
function write_zone_file
{
    zone_name=$1

    eval dns_master='$BIND_'${znr}'_MASTER_NS'
    if [ -z "$dns_master" ]
    then
        dns_master="${bind9_hostname}.${zone_name}"
    fi

    ### ---------------------------------------------------------------------------------
    ### write header
    ### ---------------------------------------------------------------------------------
cat > ${bind_root}/etc/bind/master/${zone_name}.zone <<EOF
\$TTL 86400              ; 1 day
@              IN   SOA  ${dns_master}.   root.${zone_name}. (
                    ${bind9_zoneserial} ; serial
                    ${bind9_zonerefresh}   ; refresh
                    1H   ; retry after 1 hour
                    1W   ; expire after 1 week
                    1D ) ; minimum TTL of 1 day
@              IN   NS   ${dns_master}.
EOF

    ### ---------------------------------------------------------------------------------
    ### create secondary NS records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_NS_N'
    if [ ! -z "$ncnt" ]
    then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_NS_'$xn'_NAME'
            if ! grep -q "^@              IN   NS   ${tempname}. " ${bind_root}/etc/bind/master/${zone_name}.zone
            then
                echo "@              IN   NS   ${tempname}. " >> ${bind_root}/etc/bind/master/${zone_name}.zone
            fi
            xn=`expr $xn + 1`
        done
    fi

    ### ---------------------------------------------------------------------------------
    ### create all MX records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_MX_N'
    if [ ! -z "$ncnt" ]
    then
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_MX_'${xn}'_NAME'
            eval tempprio='$BIND_'${znr}'_MX_'${xn}'_PRIORITY'
            echo "@              IN   MX   $tempprio   ${tempname}. " >> ${bind_root}/etc/bind/master/${zone_name}.zone
            xn=`expr $xn + 1`
        done
    fi
    ### ---------------------------------------------------------------------------------
    ### check and append the "empty" A record
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_HOST_N'
    if [ ! -z "$ncnt" ]
    then
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
            if [ -z "$tempname" ]
            then 
                eval tempipnr='$BIND_'${znr}'_HOST_'${xn}'_IP'
                if [ -n "$tempipnr" ]
                then
                    echo "@              IN   A    $tempipnr " >> ${bind_root}/etc/bind/master/${zone_name}.zone
                    break
                fi
            fi
            xn=`expr $xn + 1`
        done
        
        # add default localhost
        echo "localhost      IN   A    127.0.0.1 " >> ${bind_root}/etc/bind/master/${zone_name}.zone
    ### ---------------------------------------------------------------------------------
    ### check and append the A records
    ### ---------------------------------------------------------------------------------
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
            eval tempipnr='$BIND_'${znr}'_HOST_'${xn}'_IP'
            if [ -n "$tempname" -a -n "$tempipnr" ]
            then
                if ! grep -q "^$tempname " ${bind_root}/etc/bind/master/${zone_name}.zone
                then
                    echo "$tempname    IN   A    ${tempipnr} " >> ${bind_root}/etc/bind/master/${zone_name}.zone
                fi
            fi
            xn=`expr $xn + 1`
        done

    ### ---------------------------------------------------------------------------------
    ### create all CNAME alias records
    ### ---------------------------------------------------------------------------------
        xn=1
        set -f
        while [ $xn -le $ncnt ]
        do
            eval tempalias='$BIND_'${znr}'_HOST_'${xn}'_ALIAS'
            if [ -n "$tempalias" ]
            then
                eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
                if [ -n "$tempname" ]
                then
                    tempname="${tempname}."
                fi
                for s in $tempalias
                do
                    # exists entry?
                    if ! grep -q  "^$s " ${bind_root}/etc/bind/master/${zone_name}.zone
                    then
                        echo "$s    IN   CNAME ${tempname}${zone_name}. " >> ${bind_root}/etc/bind/master/${zone_name}.zone
                    fi
                done
            fi
            xn=`expr $xn + 1`
        done
        set +f
    fi

    ### ---------------------------------------------------------------------------------
    ### create A record from SOA if not defined
    ### ---------------------------------------------------------------------------------
    eval tempipnr='$BIND_'${znr}'_MASTER_IP'
    if [ -n "$tempipnr" ]
    then
        if ! grep -q "^$bind9_hostname " ${bind_root}/etc/bind/master/${zone_name}.zone
        then
            echo "$bind9_hostname    IN   A    $tempipnr " >> ${bind_root}/etc/bind/master/${zone_name}.zone
        fi
    fi

    ### ---------------------------------------------------------------------------------
    ### append all dhcp A records
    ### ---------------------------------------------------------------------------------
    append_DHCP_A_records $zone_name

    chmod 0640 ${bind_root}/etc/bind/master/${zone_name}.zone
    chown ${bind_run_user}:${bind_run_user} ${bind_root}/etc/bind/master/${zone_name}.zone
}


### --------------------------------------------------------------------------
### generate a reverse ip number
### --------------------------------------------------------------------------
function get_revip
{
    ip_addr=$1
    revip="0"
    case "$zonemask" in
        255.255.255.*)
            revip=`echo $ip_addr | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\4/"`
            ;;
        255.255.*)
            revip=`echo $ip_addr | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\4.\3/"`
            ;;
        255.*)
            revip=`echo $ip_addr | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\4.\3.\2/"`
            ;;
    esac
    echo $revip
}


### --------------------------------------------------------------------------
### Append PTR records from dhcp leases list
### --------------------------------------------------------------------------
function append_DHCP_PTR_records
{
    dhcp_zone_name=$1
    dhcp_rev_zone=$2

    if [ -f ${bind_root}/etc/bind/master/dhcp.txt ]
    then
        ### Set seperator
        old_ifs=$IFS
        IFS=";"

        while read csv_zone_name csv_client_ip csv_client_name csv_reverse
        do
            if [ "$csv_zone_name" == "$dhcp_zone_name" ]
            then
                if ! grep -q "PTR    ${csv_client_name}.${dhcp_zone_name}." ${bind_root}/etc/bind/master/${dhcp_rev_zone}.zone
                then
                    temprvip=`get_revip $csv_client_ip`
                    echo "${temprvip}    IN     PTR    ${csv_client_name}.${csv_zone_name}. " >> ${bind_root}/etc/bind/master/${dhcp_rev_zone}.zone
                fi
            fi
        done < ${bind_root}/etc/bind/master/dhcp.txt
        IFS=$old_ifs
    fi
}


### --------------------------------------------------------------------------
### generate a reverse zone file
### --------------------------------------------------------------------------
function write_reverse_zone_file
{
    local zone_name=$1
    local zone_netw=$2
    local zone_mask=$3
    local tempipnr=""
    local temprvip=""
    local tempname=""
    local write_header="0"

    # check if exists a revers file with the same serial
    if [ -f ${bind_root}/etc/bind/master/${zone_name}.zone  ]
    then
        if ! grep -q "${bind9_zoneserial} ; serial" ${bind_root}/etc/bind/master/${zone_name}.zone
        then
            write_header='1'
        fi
    else
        write_header='1'
    fi

    if [ "$write_header" = '1' ]
    then
        eval dns_master='$BIND_'${znr}'_MASTER_NS'
        if [ -z "$dns_master" ]
        then
            dns_master="${bind9_hostname}.${zone_name}"
        fi
cat > ${bind_root}/etc/bind/master/${zone_name}.zone <<EOF
\$TTL 86400                   ; 1 day
@              IN   SOA  ${dns_master}.    root.${zone_name}. (
                         ${bind9_zoneserial} ; serial
                         ${bind9_zonerefresh}   ; refresh
                         1H   ; retry after 1 hour
                         1W   ; expire after 1 week
                         1D ) ; minimum TTL of 1 day
@              IN   NS   ${dns_master}.
EOF
    fi

    ### ---------------------------------------------------------------------------------
    ### check and append all NS records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_NS_N'
    if [ ! -z "$ncnt" ]
    then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_NS_'$xn'_NAME'
            if ! grep -q "^@              IN   NS   ${tempname}." ${bind_root}/etc/bind/master/${zone_name}.zone
            then
                echo "@              IN   NS   ${tempname}. " >> ${bind_root}/etc/bind/master/${zone_name}.zone
            fi
            xn=`expr $xn + 1`
        done
    fi

    ### ---------------------------------------------------------------------------------
    ### append PTR for SOA
    ### ---------------------------------------------------------------------------------
    if [ "$write_header" = '1' ]
    then
        eval tempipnr='$BIND_'${znr}'_MASTER_IP'
        if [ -n "$tempipnr" ]
        then
            temprvip=`get_revip $tempipnr`
            echo "${temprvip}   IN   PTR  ${bind9_hostname}.${zonename}. " >> ${bind_root}/etc/bind/master/${zone_name}.zone
        fi
    fi

    ### ---------------------------------------------------------------------------------
    ### check and append all PTR records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_HOST_N'
    if [ ! -z "$ncnt" ]
    then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'$xn'_NAME'
            if [ ! "$tempname" = '*' ]
            then
                if [ -z "$tempname" ]
                then
                    tempname="${zonename}."
                else
                    tempname="${tempname}.${zonename}."
                fi
                if ! grep -q "PTR  $tempname" ${bind_root}/etc/bind/master/${zone_name}.zone
                then
                    eval tempipnr='$BIND_'${znr}'_HOST_'$xn'_IP'
                    # if the reverse ip in the network?
                    tmpnetwork=`/usr/local/bin/netcalc dnsnet $tempipnr $zone_mask`
                    if [ "$zone_netw" = "$tmpnetwork" ]
                    then
                        temprvip=`get_revip $tempipnr`
                        echo "$temprvip   IN   PTR  $tempname " >> ${bind_root}/etc/bind/master/${zone_name}.zone
                    fi
                fi
            fi
            xn=`expr $xn + 1`
        done
    fi
    append_DHCP_PTR_records $zonename $zone_name

    chmod 0640 ${bind_root}/etc/bind/master/${zone_name}.zone
    chown ${bind_run_user}:${bind_run_user} ${bind_root}/etc/bind/master/${zone_name}.zone
}


### --------------------------------------------------------------------------
### Write the BIND9 named configuration files
### --------------------------------------------------------------------------
function write_named_file
{
    # remove old zone files:
    rm -f ${bind_root}/etc/bind/master/* >/dev/null
    rm -f ${bind_root}/etc/bind/slave/* >/dev/null
    rm -f ${bind_root}/etc/bind/named.conf.local
    touch ${bind_root}/etc/bind/named.conf.local

    {
    echo "# -----------------------------------------------------------------------------"
    echo "# ${bind_root}/etc/bind/named.conf.options - configuration for BIND 9"
    echo "# Creation: $EISDATE $EISTIME by eisfair BIND9 setup"
    echo "# -----------------------------------------------------------------------------"
    echo ""
    echo "include \"/etc/bind/rndc.key\";"
    echo ""
    echo "acl forwarder {"
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
        echo "  $ipaddr;"
        idx=`expr $idx + 1`
    done
    echo "};"
    echo ""
    echo "acl nslist {"
    znr="1"
    s_found=''
    # echo "BEGIN zone: $idx " >/dev/tty
    while [ ${znr} -le $BIND_N ]
    do
        eval ncnt='$BIND_'${znr}'_NS_N'
        if [ ! -z "$ncnt" ]
        then
            idx="1"
            while [ $idx -le $ncnt ]
            do
                eval ipaddr='$BIND_'${znr}'_NS_'$idx'_IP'
                if [ ! -z "$ipaddr" ]
                then
                    echo "  ${ipaddr}; "
                    s_found='yes'
                fi
                idx=`expr $idx + 1`
             done
        fi
        znr=`expr ${znr} + 1`
    done
    if [ -z "$s_found" ]
    then
        echo "  none; "
    fi
    echo "};"
    echo ""
    echo "acl internals {"
    echo "  127.0.0.0/8;"
    echo "  10.0.0.0/8;"
    echo "  169.254.0.0/16;"
    echo "  172.16.0.0/12;"
    echo "  192.168.0.0/16;"
    echo "};"
    echo ""
    echo "options { "
    echo "  directory \"/var/cache/bind\"; "
    echo "  pid-file \"/var/run/named.pid\"; "
    echo "  dump-file \"/var/log/named_dump.db\"; "
    echo "  statistics-file \"/var/log/named.stats\"; "
    if [ ! -z "$BIND_BIND_IP_ADDRESS" ]
    then
        echo "  listen-on port 53 { "
        for ipaddr in $BIND_BIND_IP_ADDRESS
        do
            echo "    127.0.0.1; "
            echo "    ${ipaddr}; "
        done
        echo "  }; "
    else
        echo "  listen-on { any; }; "
    fi
    echo "  listen-on-v6 { any; }; "
    echo "  auth-nxdomain no;    # conform to RFC1035"
    # use for firewalled external access:
    if [ $BIND_PORT_53_ONLY = 'yes' ]
    then
        echo "  query-source address * port 53; "
        echo "  transfer-source * port 53; "
        echo "  notify-source * port 53; "
    fi
    # query and reverse query: any, localnets, localhost
    if [ $BIND_ALLOW_QUERY = 'localnets' ]
    then
        echo "  allow-query { localhost; localnets; }; "
        echo "  allow-recursion { localhost; localnets; }; "
    else
        echo "  allow-query { ${BIND_ALLOW_QUERY}; }; "
        echo "  allow-recursion { localhost; localnets; internals; }; "
    fi

    # accept notify message
    echo "  allow-notify { forwarder; localnets; }; "
    echo "  sortlist { "
    echo "    { localhost; localnets; }; "
    echo "    { localnets; }; "
    echo "  }; "
    echo "  forwarders { "
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
        echo "    $ipaddr;"
        idx=`expr $idx + 1`
    done
    echo "  };"
    # read forwarders before use root server
    if [ "$BIND_FORWARDER_N" -gt 0 ]
    then
        if [ "$BIND_N" -gt 0 ]
        then
            echo "  forward first; "
        else
            echo "  forward only; "
        fi
    fi
    echo "}; "
    echo ""
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval fwedns='$BIND_FORWARDER_'$idx'_EDNS'
        if [ "$fwedns" = "no" ]
        then
            eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
            echo "server $ipaddr {edns no;}; "
        fi
        idx=`expr $idx + 1`
        echo ""
    done
    echo "logging { "
    echo "  channel default_syslog { "
    echo "          file \"/var/log/named.log\" versions 3 size 2M; "
    echo "          print-time yes;     "
    echo "          print-category yes; "
    if [ $BIND_DEBUG_LOGFILE = 'yes' ]
    then
        echo "          print-severity yes; "
        echo "          severity debug; "
    fi
    echo "  }; "
    echo "  # Log general name server errors to syslog. "
    echo "  channel syslog_errors { "
    echo "          syslog user; "
    echo "          severity error; "
    echo "  }; "
    echo "}; "
    echo ""
    } > ${bind_root}/etc/bind/named.conf.options



    znr="1"
    # echo "BEGIN zone: $idx " >/dev/tty
    while [ ${znr} -le $BIND_N ]
    do
        eval zonename='$BIND_'${znr}'_NAME'
        eval zonemast='$BIND_'${znr}'_MASTER'
        eval zonenetw='$BIND_'${znr}'_NETWORK'
        eval zonemask='$BIND_'${znr}'_NETMASK'
        eval masterip='$BIND_'${znr}'_MASTER_IP'
        if [ "$zonemast" = 'yes' ]
        then
            zonetype='master'
        else
            zonetype='slave'
        fi

        #------------------------------------------------------------------
        # create zone name
        #------------------------------------------------------------------
        {
        echo ""
        echo "zone \"$zonename\" in {"
        echo "  type ${zonetype};"
        echo "  file \"/etc/bind/${zonetype}/${zonename}.zone\";"
        if [  ${zonetype} = 'master' ]
        then
            echo "  allow-update { localhost; key dns_updater; }; "
            # transfer: any, localnets, nslist, none
            eval allow_tr='$BIND_'${znr}'_ALLOW_TRANSFER'
            if [ -z "$allow_tr" ]
            then
                allow_tr='any'
            fi
            echo "  allow-transfer { ${allow_tr}; };"
            echo "  notify yes;"
            # create zone file
            write_DHCP_hostlist
            write_zone_file $zonename
        else
            echo "  masters { ${masterip}; };"
            echo "  notify no;"
        fi
        echo "};"
        } >> ${bind_root}/etc/bind/named.conf.local

        #------------------------------------------------------------------
        # create reverse zone name
        #------------------------------------------------------------------
        reversezone=`/usr/local/bin/netcalc dnsrev $zonenetw $zonemask`
        forwardzone=`/usr/local/bin/netcalc dnsnet $zonenetw $zonemask`
        # check for double reverse zone name
        if ! grep -q "$reversezone"  ${bind_root}/etc/bind/named.conf.local
        then
            {
            echo ""
            echo "zone \"$reversezone\" in {"
            echo "  type ${zonetype};"
            echo "  file \"/etc/bind/${zonetype}/${reversezone}.zone\";"
            if [ ${zonetype} = 'master' ]
            then
                echo "  allow-update { localhost; key dns_updater; }; "
                # transfer: any, localnets, nslist, none
                eval allow_tr='$BIND_'${znr}'_ALLOW_TRANSFER'
                if [ -z "$allow_tr" ]
                then
                    allow_tr='any'
                fi
                echo "  allow-transfer { ${allow_tr}; };"
                echo "  notify yes;"
            else
                echo "  masters { ${masterip}; };"
                echo "  notify no;"
            fi
            echo "};"
            } >> ${bind_root}/etc/bind/named.conf.local
        fi

        # create or append reverse zone file
        if [ ${zonetype} = 'master' ]
        then
            write_reverse_zone_file $reversezone $forwardzone $zonemask
        fi

        znr=`expr ${znr} + 1`
    done

    chmod 0644 ${bind_root}/etc/bind/named.conf.options
    chmod 0644 ${bind_root}/etc/bind/named.conf.local
}


### --------------------------------------------------------------------------
### Main
### --------------------------------------------------------------------------
if [ -f /etc/config.d/bind ]
then
    . /etc/config.d/bind
fi

if [ "$START_BIND" = 'yes' ]; then
    # create chroot if not exists
    for i in ${bind_root} ${bind_root}/etc/bind ${bind_root}/etc/bind/master \
         ${bind_root}/etc/bind/slave ${bind_root}/dev ${bind_root}/var/cache/bind \
         ${bind_root}/var/run ${bind_root}/var/log /etc/bind
    do
        mkdir -p ${i}
    done

    if [ ! -e ${bind_root}/dev/null ]
    then
        mknod -m 666 ${bind_root}/dev/null c 1 3
    fi
    if [ ! -e ${bind_root}/dev/random ]
    then
        mknod -m 666 ${bind_root}/dev/random c 1 8
    fi
    if [ ! -f ${bind_root}/var/log/named.log ]
    then
        touch ${bind_root}/var/log/named.log
    fi
    chmod 0644 ${bind_root}/var/log/named.log

    if [ ! -s ${bind_root}/etc/bind/rndc.key ]
    then
        if [ ! -e /etc/bind/rndc.key ]
        then
            rndc-confgen -r /dev/urandom -a >/dev/null 2>&1
        fi
        chmod 0640 /etc/bind/rndc.key
        chown root:$bind_run_user /etc/bind/rndc.key
        cp -f /etc/bind/rndc.key ${bind_root}/etc/bind/rndc.key >/dev/null 2>&1
    fi

    chown -R ${bind_run_user}:${bind_run_user} ${bind_root}/var
    chown -R ${bind_run_user}:${bind_run_user} ${bind_root}/etc/bind
    chmod 0640 ${bind_root}/etc/bind/rndc.key
    write_named_file
fi

exit 0
###############################################################################
