#!/bin/sh
#-----------------------------------------------------------------------------
# /var/install/config.d/bind.sh - BIND configuration
# Creation:     2004-08-19 jv jens@eisfair.org
#-----------------------------------------------------------------------------

# define bind_run_user
bind_run_usr="root"
bind_run_grp="named"

# use unix-time for zone serial
bind9_zoneserial=`date '+%s'`
bind9_zonerefresh='6H'
. /etc/config.d/base

bind9_hostname="$HOSTNAME"

#include eisdate-time
. /var/install/include/eistime
# include name of bind run user for chroot and daemon
#. /etc/bind/binduser.conf

bind9_pri="/var/bind/pri" # master zone
bind9_sec="/var/bind/sec" # slave zone

### --------------------------------------------------------------------------
### generate a zone file
### --------------------------------------------------------------------------
write_zone_file()
{
    zone_name=$1

    eval dns_master='$BIND_'${znr}'_MASTER_NS'
    [ -z "$dns_master" ] && dns_master="${bind9_hostname}.${zone_name}"

    ### ---------------------------------------------------------------------------------
    ### write header
    ### ---------------------------------------------------------------------------------
cat > ${bind9_pri}/${zone_name}.zone <<EOF
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
    if [ -n "$ncnt" ] ; then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_NS_'$xn'_NAME'
            if ! grep -q "^@              IN   NS   ${tempname}. " ${bind9_pri}/${zone_name}.zone
            then
                echo "@              IN   NS   ${tempname}. " >> ${bind9_pri}/${zone_name}.zone
            fi
            xn=`expr $xn + 1`
        done
    fi

    ### ---------------------------------------------------------------------------------
    ### create all MX records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_MX_N'
    if [ -n "$ncnt" ] ; then
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_MX_'${xn}'_NAME'
            eval tempprio='$BIND_'${znr}'_MX_'${xn}'_PRIORITY'
            echo "@              IN   MX   $tempprio   ${tempname}. " >> ${bind9_pri}/${zone_name}.zone
            xn=`expr $xn + 1`
        done
    fi
    ### ---------------------------------------------------------------------------------
    ### check and append the "empty" A record
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_HOST_N'
    if [ -n "$ncnt" ] ; then
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
            if [ -z "$tempname" ] ; then
                eval tempipnr='$BIND_'${znr}'_HOST_'${xn}'_IP'
                if [ -n "$tempipnr" ] ; then
                    echo "@              IN   A    $tempipnr " >> ${bind9_pri}/${zone_name}.zone
                    break
                fi
            fi
            xn=`expr $xn + 1`
        done

        # add default localhost
        echo "localhost      IN   A    127.0.0.1 " >> ${bind9_pri}/${zone_name}.zone
    ### ---------------------------------------------------------------------------------
    ### check and append the A records
    ### ---------------------------------------------------------------------------------
        xn=1
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
            eval tempipnr='$BIND_'${znr}'_HOST_'${xn}'_IP'
            if [ -n "$tempname" -a -n "$tempipnr" ] ; then
                if ! grep -q "^$tempname " ${bind9_pri}/${zone_name}.zone
                then
                    echo "$tempname    IN   A    ${tempipnr} " >> ${bind9_pri}/${zone_name}.zone
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
            if [ -n "$tempalias" ] ; then
                eval tempname='$BIND_'${znr}'_HOST_'${xn}'_NAME'
                [ -n "$tempname" ] && tempname="${tempname}."
                for s in $tempalias
                do
                    # exists entry?
                    if ! grep -q  "^$s " ${bind9_pri}/${zone_name}.zone
                    then
                        echo "$s    IN   CNAME ${tempname}${zone_name}. " >> ${bind9_pri}/${zone_name}.zone
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
    if [ -n "$tempipnr" ] ; then
        if ! grep -q "^$bind9_hostname " ${bind9_pri}/${zone_name}.zone
        then
            echo "$bind9_hostname    IN   A    $tempipnr " >> ${bind9_pri}/${zone_name}.zone
        fi
    fi
    chmod 0640 ${bind9_pri}/${zone_name}.zone
    chown ${bind_run_usr}:${bind_run_grp} ${bind9_pri}/${zone_name}.zone
}


### --------------------------------------------------------------------------
### generate a reverse ip number
### --------------------------------------------------------------------------
get_revip()
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
### generate a reverse zone file
### --------------------------------------------------------------------------
write_reverse_zone_file()
{
    local zone_name=$1
    local zone_netw=$2
    local zone_mask=$3
    local tempipnr=""
    local temprvip=""
    local tempname=""
    local write_header="0"

    # check if exists a revers file with the same serial
    if [ -f ${bind9_pri}/${zone_name}.zone  ] ; then
        if ! grep -q "${bind9_zoneserial} ; serial" ${bind9_pri}/${zone_name}.zone
        then
            write_header='1'
        fi
    else
        write_header='1'
    fi

    if [ "$write_header" = '1' ] ; then
        eval dns_master='$BIND_'${znr}'_MASTER_NS'
        [ -z "$dns_master" ] && dns_master="${bind9_hostname}.${zone_name}"
cat > ${bind9_pri}/${zone_name}.zone <<EOF
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
    if [ -n "$ncnt" ] ; then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_NS_'$xn'_NAME'
            if ! grep -q "^@              IN   NS   ${tempname}." ${bind9_pri}/${zone_name}.zone
            then
                echo "@              IN   NS   ${tempname}. " >> ${bind9_pri}/${zone_name}.zone
            fi
            xn=`expr $xn + 1`
        done
    fi

    ### ---------------------------------------------------------------------------------
    ### append PTR for SOA
    ### ---------------------------------------------------------------------------------
    if [ "$write_header" = '1' ] ; then
        eval tempipnr='$BIND_'${znr}'_MASTER_IP'
        if [ -n "$tempipnr" ]
        then
            temprvip=`get_revip $tempipnr`
            echo "${temprvip}   IN   PTR  ${bind9_hostname}.${zonename}. " >> ${bind9_pri}/${zone_name}.zone
        fi
    fi

    ### ---------------------------------------------------------------------------------
    ### check and append all PTR records
    ### ---------------------------------------------------------------------------------
    eval ncnt='$BIND_'${znr}'_HOST_N'
    if [ -n "$ncnt" ] ; then
        xn="1"
        while [ $xn -le $ncnt ]
        do
            eval tempname='$BIND_'${znr}'_HOST_'$xn'_NAME'
            if [ ! "$tempname" = '*' ] ; then
                if [ -z "$tempname" ] ; then
                    tempname="${zonename}."
                else
                    tempname="${tempname}.${zonename}."
                fi
                if ! grep -q "PTR  $tempname" ${bind9_pri}/${zone_name}.zone
                then
                    eval tempipnr='$BIND_'${znr}'_HOST_'$xn'_IP'
                    # if the reverse ip in the network?
                    tmpnetwork=`/usr/local/bin/netcalc dnsnet $tempipnr $zone_mask`
                    if [ "$zone_netw" = "$tmpnetwork" ] ; then
                        temprvip=`get_revip $tempipnr`
                        echo "$temprvip   IN   PTR  $tempname " >> ${bind9_pri}/${zone_name}.zone
                    fi
                fi
            fi
            xn=`expr $xn + 1`
        done
    fi
    chmod 0640 ${bind9_pri}/${zone_name}.zone
    chown ${bind_run_usr}:${bind_run_grp} ${bind9_pri}/${zone_name}.zone
}


### --------------------------------------------------------------------------
### Write the BIND named configuration files
### --------------------------------------------------------------------------
write_named_file()
{
    local ftmp=""
    # remove old zone files:
    for ftmp in ${bind9_pri}/*
    do
        case "$ftmp" in
            */127.zone)
                # don't remove local zone
                ;;
            */localhost.zone)
                # don't remove local zone
                ;;
            *)
                [ -f "$ftmp" ] && rm -f "$ftmp"
                ;;
        esac
    done
    rm -f ${bind9_sec}/* >/dev/null

    {
    echo "options {"
    echo "    directory \"/var/bind\";"
    echo "    pid-file \"/run/named/named.pid\";"
    if [ -n "$BIND_BIND_IP_ADDRESS" ] ; then
        echo "    listen-on {"
        for ipaddr in $BIND_BIND_IP_ADDRESS
        do
            echo "        127.0.0.1; "
            [ "$ipaddr" = "127.0.0.1" ] || echo "        ${ipaddr};"
        done
        echo "    }; "
        echo "    listen-on-v6 { none; };"
    else
        echo "    listen-on { any; }; "
        echo "    listen-on-v6 { any; };"
    fi
    echo "    // to allow only specific hosts to use the DNS server:"
    echo "    //allow-query {"
    echo "    //      127.0.0.1;"
    echo "    //};"
    if [ $BIND_PORT_53_ONLY = 'yes' ] ; then
        echo "    // if you have problems and are behind a firewall:"
        echo "    query-source address * port 53;"
        echo "    transfer-source * port 53;"
        echo "    notify-source * port 53;"
    fi
    # query and reverse query: any, localnets, localhost
    if [ "$BIND_ALLOW_QUERY" = 'localnets' ] ; then
        echo "    allow-query { localhost; localnets; };"
        echo "    allow-recursion { localhost; localnets; };"
    else
        echo "    allow-query { ${BIND_ALLOW_QUERY}; };"
        echo "    allow-recursion { localhost; localnets; internals; };"
    fi
    # accept notify message
    echo "    allow-notify { forwarder; localnets; };"
    echo "    sortlist {"
    echo "        { localhost; localnets; };"
    echo "        { localnets; };"
    echo "    };"
    echo "    forwarders {"
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
        echo "        ${ipaddr};"
        idx=`expr $idx + 1`
    done
    echo "    };"
    # read forwarders before use root server
    if [ "$BIND_FORWARDER_N" -gt 0 ] ; then
        if [ "$BIND_N" -gt 0 ] ; then
            echo "    forward first;"
        else
            echo "    forward only;"
        fi
    fi
    echo "    auth-nxdomain no;    # conform to RFC1035"
    echo "};"
    echo ""
    # edns settings
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval fwedns='$BIND_FORWARDER_'$idx'_EDNS'
        if [ "$fwedns" = "no" ] ; then
            eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
            echo "server $ipaddr {edns no;};"
        fi
        idx=`expr $idx + 1`
    done
    echo ""
    # syslog setup
    echo "logging {"
    echo "    channel default_syslog {"
    echo "        syslog daemon;"
    echo "        print-category yes;"
    if [ $BIND_DEBUG_LOGFILE = 'yes' ] ; then
        echo "        severity debug;"
    else
        echo "        severity error;"
    fi
    echo "    };"
#    echo "   category default { null; };"
#    echo "   category general { null; };"
#    echo "   category database { null; };"
#    echo "   category security { null; };"
#    echo "   category resolver { null; };"
#    echo "   category xfer-in { null; };"
#    echo "   category xfer-out { null; };"
#    echo "   category client { null; };"
#    echo "   category unmatched { null; };"
#    echo "   category network { null; };"
#    echo "   category update { null; };"
#    echo "   category update-security { null; };"
#    echo "   category queries { null; };"
#    echo "   category dispatch { null; };"
#    echo "   category dnssec { null; };"
#    echo "   category lame-servers { null; };"
#    echo "   category delegation-only { null; };"
    echo "};"
    # acl's
    echo ""
    echo "acl forwarder {"
    idx="1"
    while [ $idx -le $BIND_FORWARDER_N ]
    do
        eval ipaddr='$BIND_FORWARDER_'$idx'_IP'
        echo "    ${ipaddr};"
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
        if [ -n "$ncnt" ] ; then
            idx="1"
            while [ $idx -le $ncnt ]
            do
                eval ipaddr='$BIND_'${znr}'_NS_'$idx'_IP'
                if [ -n "$ipaddr" ] ; then
                    echo "    ${ipaddr};"
                    s_found='yes'
                fi
                idx=`expr $idx + 1`
             done
        fi
        znr=`expr ${znr} + 1`
    done
    [ -z "$s_found" ] && echo "    none;"
    echo "};"
    echo ""
    echo "acl internals {"
    echo "    127.0.0.0/8;"
    echo "    10.0.0.0/8;"
    echo "    169.254.0.0/16;"
    echo "    172.16.0.0/12;"
    echo "    192.168.0.0/16;"
    echo "};"
    # zone entries
    echo ""
    echo "//zone \"COM\" { type delegation-only; };"
    echo "//zone \"NET\" { type delegation-only; };"
    echo ""
    echo "zone \".\" IN {"
    echo "    type hint;"
    echo "    file \"named.ca\";"
    echo "};"
    echo "zone \"localhost\" IN {"
    echo "    type master;"
    echo "    file \"pri/localhost.zone\";"
    echo "    allow-update { none; };"
    echo "    notify no;"
    echo "};"
    echo "zone \"127.in-addr.arpa\" IN {"
    echo "    type master;"
    echo "    file \"pri/127.zone\";"
    echo "    allow-update { none; };"
    echo "    notify no;"
    echo "};"
    } > /etc/bind/named.conf

    #------------------------------------------------------------------
    # append alle zone entries to config
    #------------------------------------------------------------------
    znr="1"
    # echo "BEGIN zone: $idx " >/dev/tty
    while [ "$znr" -le "$BIND_N" ]
    do
        eval zonename='$BIND_'${znr}'_NAME'
        eval zonemast='$BIND_'${znr}'_MASTER'
        eval zonenetw='$BIND_'${znr}'_NETWORK'
        eval zonemask='$BIND_'${znr}'_NETMASK'
        eval masterip='$BIND_'${znr}'_MASTER_IP'
        [ "$zonemast" = "yes" ] && zonetype='master' || zonetype='slave'

        #------------------------------------------------------------------
        # create forward zone
        #------------------------------------------------------------------
        {
        echo ""
        echo "zone \"${zonename}\" IN {"
        echo "    type ${zonetype};"
        if [  "$zonetype" = "master" ] ; then
            echo "    file \"pri/${zonename}.zone\";"
            echo "    allow-update { localhost; key dns_updater; };"
            # transfer: any, localnets, nslist, none
            eval allow_tr='$BIND_'${znr}'_ALLOW_TRANSFER'
            [ -z "$allow_tr" ] && allow_tr='any'
            echo "    allow-transfer { ${allow_tr}; };"
            echo "    notify yes;"
            #------------------------------------------------------------------
            # create zone file
            write_zone_file "$zonename"
        else
            echo "    file \"sec/${zonename}.zone\";"
            echo "    masters { ${masterip}; };"
            echo "    notify no;"
        fi
        echo "};"
        } >> /etc/bind/named.conf

        #------------------------------------------------------------------
        # create reverse zone
        #------------------------------------------------------------------
        reversezone=`/var/install/bin/netcalc dnsrev $zonenetw $zonemask`
        forwardzone=`/var/install/bin/netcalc dnsnet $zonenetw $zonemask`
        # check for double reverse zone name
        if ! grep -q "$reversezone"  /etc/bind/named.conf
        then
            {
            echo ""
            echo "zone \"${reversezone}\" in {"
            echo "    type ${zonetype};"
            if [ ${zonetype} = 'master' ] ; then
                echo "    file \"pri/${zonename}.zone\";"
                echo "    allow-update { localhost; key dns_updater; };"
                # transfer: any, localnets, nslist, none
                eval allow_tr='$BIND_'${znr}'_ALLOW_TRANSFER'
                [ -z "$allow_tr" ] && allow_tr='any'
                echo "    allow-transfer { ${allow_tr}; };"
                echo "    notify yes;"
                # create  reverse zone file
                write_reverse_zone_file $reversezone $forwardzone $zonemask
            else
                echo "    file \"sec/${zonename}.zone\";"
                echo "    masters { ${masterip}; };"
                echo "    notify no;"
            fi
            echo "};"
            } >> /etc/bind/named.conf
        fi

        znr=`expr ${znr} + 1`
    done
    chmod 0644 /etc/bind/named.conf
}


### --------------------------------------------------------------------------
### Main
### --------------------------------------------------------------------------
[ -f /etc/config.d/named ] && . /etc/config.d/named

if [ "$START_BIND" = 'yes' ]; then
    if [ ! -f /etc/bind/rndc.key ] ; then
        rndc-confgen -r /dev/urandom -a >/dev/null 2>&1
        chmod 0640 /etc/bind/rndc.key
        chown root:$bind_run_grp /etc/bind/rndc.key
    fi
    write_named_file
fi

exit 0
###############################################################################
