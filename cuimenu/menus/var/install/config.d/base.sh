#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/config.d/base.sh - apply configuration for base
# Copyright (c) 2001-2015 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------
PATH=/bin:/usr/bin:/sbin:/usr/sbin
# include base-config
. /etc/config.d/base

#----------------------------------------------------------------------------
# create loopback
#----------------------------------------------------------------------------
cat <<EOF >/etc/network/interfaces
# Network config file
auto lo
iface lo inet loopback

EOF

#echo "loopback 127.0.0.0" > /etc/networks
rm -f /etc/networks

#----------------------------------------------------------------------------
# add interface template (openvz venet...)
#----------------------------------------------------------------------------
[ -f /etc/network/interfaces.iface ] && cat /etc/network/interfaces.iface >> /etc/network/interfaces

#----------------------------------------------------------------------------
# add network interface list
#----------------------------------------------------------------------------
for idx in $(seq "0$IP_NET_N")
do
	interface_nr=$(/usr/bin/expr $idx - 1)

	eval name='$IP_NET_'$idx'_NAME'
	[ -z "$name" ] && name="eth$interface_nr"

	eval active4='$IP_NET_'$idx'_IPV4_ACTIVE'
	eval static4='$IP_NET_'$idx'_IPV4_STATIC_IP'
	eval active6='$IP_NET_'$idx'_IPV6_ACTIVE'
	eval static6='$IP_NET_'$idx'_IPV6_STATIC_IP'

	if [ "$active4" = "yes" -o "$active6" = "yes" ] ; then
		echo "auto $name" >>/etc/network/interfaces
	fi

	# IPv4 ------------------------------------------------------------------
	# use dhcp or static address
	if [ "$active4" = "yes" -a "$static4" = "no" ] ; then
		cat <<-EOF >>/etc/network/interfaces
		iface $name inet dhcp

		EOF

	elif [ "$active4" = "yes" ] ; then
		static_ip_use=true
		eval ipaddr='$IP_NET_'$idx'_IPV4_IPADDR'
		eval netmask='$IP_NET_'$idx'_IPV4_NETMASK'
		eval gateway='$IP_NET_'$idx'_IPV4_GATEWAY'
		eval point2p='$IP_NET_'$idx'_IPV4_POINTOPOINT'
		if [ -n "$ipaddr" -a "$ipaddr" != 0.0.0.0 ]
		then
#			network=$(/var/install/bin/netcalc network $ipaddr $netmask)
#			echo "localnet $network" >> /etc/networks
			cat <<-EOF >>/etc/network/interfaces
			iface $name inet static
			  address $ipaddr
			  netmask $netmask
			EOF
			{
			if [ -n "$gateway" ] ; then
				echo "  gateway $gateway"
				[ "$point2p" = "yes" ] && echo "  pointopoint $gateway"
			fi
			echo "  hostname $HOSTNAME"
			echo ""
			} >>/etc/network/interfaces
		fi
	fi

	# IPv6 ------------------------------------------------------------------
	# use dhcp or static address
	if [ "$active6" = "yes" -a "$static6" = "no" ] ; then
		cat <<-EOF >>/etc/network/interfaces
		iface $name inet6 dhcp

		EOF
	elif [ "$active6" = "yes" ] ; then
		static_ip_use=true
		eval ipaddr='$IP_NET_'$idx'_IPV6_IPADDR'
		eval netmask='$IP_NET_'$idx'_IPV6_NETMASKBITS'
		eval gateway='$IP_NET_'$idx'_IPV6_GATEWAY'
		eval point2p='$IP_NET_'$idx'_IPV6_POINTOPOINT'
		if [ -n "$ipaddr" -a "$ipaddr" != :: ] ; then
#			network=$(/var/install/bin/netcalc network $ipaddr $netmask)
#			echo "localnet $network" >> /etc/networks
			cat <<-EOF >>/etc/network/interfaces
		iface $name inet6 static
		  address $ipaddr
		  netmask $netmask
			EOF
			{
			if [ -n "$gateway" ] ; then
				echo "  gateway $gateway"
				[ "$point2p" = "yes" ] && echo "  pointopoint $gateway"
			fi
			echo "  hostname $HOSTNAME"
			echo ""
			} >>/etc/network/interfaces
		fi
	fi
done

#----------------------------------------------------------------------------
# write resolv.config
#----------------------------------------------------------------------------
if ${static_ip_use:-false} && [ -n "$DNS_SERVER$DOMAIN_NAME" ]
then
	/etc/init.d/dhcpcd stop >/dev/null 2>&1
	{
	[ -n "$DOMAIN_NAME"  ] && echo "search $DOMAIN_NAME"
	# include first internal BIND9 or other DNS server
	[ -f /etc/resolv.conf.internal ] && echo "nameserver 127.0.0.1"
	for dns_server in $DNS_SERVER
	do
		echo "nameserver $dns_server"
	done
	} >/etc/resolv.conf
fi

#----------------------------------------------------------------------------
# write hostname config file
#----------------------------------------------------------------------------
hostname $HOSTNAME
echo $HOSTNAME >/etc/hostname
[ "$IP_NET_1_IPV4_ACTIVE" == "yes" -a "$IP_NET_1_IPV4_STATIC_IP" = no ] && IP_NET_1_IPV4_IPADDR="127.0.1.1"
cat <<EOF >/etc/hosts
127.0.0.1 localhost
$IP_NET_1_IPV4_IPADDR $HOSTNAME.$DOMAIN_NAME $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

EOF

#----------------------------------------------------------------------------
# Set time zone
#----------------------------------------------------------------------------
case "$TIME_ZONE" in
	met|cet|CET) TIME_ZONE="CET" ;;
	gmt*|GMT*) TIME_ZONE="CET-1CEST,M3.5.0,M10.5.0/3" ;;
esac
echo "$TIME_ZONE" > /etc/TZ

#----------------------------------------------------------------------------
# write config for modules treatment
#----------------------------------------------------------------------------
if [ -n "$MODULE_N" -a 0$MODULE_N -gt 0 ]
then
    MODPROBE_FILE_EIS='/etc/modprobe.d/modules-eis.conf'
    rm -f $MODPROBE_FILE_EIS
    idx='1'
    while [ $idx -le $MODULE_N ]
    do
        eval mod='$MODULE_'$idx
        eval act='$MODULE_'$idx'_ACTION'
        eval strg='$MODULE_'$idx'_STRING'
        case $act in
            option)
                grep -qs "^options $mod $strg" $MODPROBE_FILE_EIS >/dev/null || echo "options $mod $strg" >>$MODPROBE_FILE_EIS
            ;;
            alias)
                grep -qs "^alias $strg $mod" $MODPROBE_FILE_EIS >/dev/null || echo "alias $strg $mod" >>$MODPROBE_FILE_EIS
            ;;
            blacklist) 
                grep -qs "^blacklist $mod" $MODPROBE_FILE_EIS >/dev/null || echo "blacklist $mod" >>$MODPROBE_FILE_EIS
            ;;
            forcedstart) 
                grep -qs "^$mod" /etc/modules >/dev/null || echo "$mod" >> /etc/modules 
            ;;
        esac
        idx=`expr $idx + 1`
    done
fi

#----------------------------------------------------------------------------
# restart network
#----------------------------------------------------------------------------
if /var/install/bin/ask.cui "Should the network be re-initialized immediately?"
then
    /etc/init.d/networking restart
fi

#----------------------------------------------------------------------------
# create logrotate configuration
#----------------------------------------------------------------------------
if [ "$START_SYSLOG" = yes ]
then
    # remove old additional syslog entries
    for oldentry in source destination log filter
    do
        rm -f /etc/syslog-ng/syslog-ng-$oldentry.base
    done
    cat <<-EOF >/etc/logrotate.d/syslog
	#-----------------------------------------------------------------
	# /etc/logrotate.d/syslog
	# This file has been created automatically by Eisfair system setup
	#-----------------------------------------------------------------
	EOF
    # add logrotate entries without reload syslog-ng command first
    idx=1
    while [ $idx -le 0$SYSLOG_DEST_N ]
    do
        logmsgname="baselog$idx"
        eval logtarget='$SYSLOG_DEST_'$idx'_TARGET'
        eval logfilter='$SYSLOG_DEST_'$idx'_FILTER'
        case "$logtarget" in
            # Syslog to external IP address
            1*|2*|3*|4*|5*|6*|7*|8*|9*)
                logtarget=`echo "$logtarget" | sed 's#@##'`
                echo "  destination df_$logmsgname { udp(\"$logtarget\"); };" >>/etc/syslog-ng/syslog-ng-destination.base
                ;;
            # Syslog to file
            /*)
                echo "  destination df_$logmsgname { file(\"$logtarget\"); };" >>/etc/syslog-ng/syslog-ng-destination.base
                # add logrotate entry
                eval loginterval='$SYSLOG_DEST_'$idx'_INTERVAL'
                eval logmaxcount='$SYSLOG_DEST_'$idx'_MAXCOUNT'
                cat <<-EOF >>/etc/logrotate.d/syslog
				${logtarget} {
				  rotate $logmaxcount
				  $loginterval
				  missingok
				  notifempty
				  compress
				}

				EOF
                ;;
        esac
		[ -n "$logfilter" ] && echo "  filter f_$logmsgname { $logfilter; };" >>/etc/syslog-ng/syslog-ng-filter.base
		{
		echo -e "log {\n        source(s_all);"
		[ -n "$logfilter" ] && echo "        filter(f_$logmsgname);"
		echo -e "        destination(df_$logmsgname);\n};\n"
		} >> /etc/syslog-ng/syslog-ng-log.base
		idx=`expr $idx + 1`
	done

	echo_rotate_entry () {
		local maxcount="$1" interval="$2"
		shift 2
		cat <<-EOF
		$@ {
		  rotate $maxcount
		  $interval
		  missingok
		  notifempty
		  create 0644
		  compress
		EOF
	}

	echo_postrotate_entry () {
		cat <<-EOF
		  postrotate
		    /etc/init.d/syslog-ng reload >/dev/null
		  endscript
		EOF
	}

	echo_rotate_end () {
		echo -e "}\n"
	}
	{
	echo_rotate_entry $SYSLOG_AUTH_MAXCOUNT $SYSLOG_AUTH_INTERVAL /var/log/auth.log
	[ "$SYSLOG_AUTH_RELOAD" = yes ] && echo_postrotate_entry
	echo_rotate_end
	echo_rotate_entry $SYSLOG_MAIL_MAXCOUNT $SYSLOG_MAIL_INTERVAL /var/log/mail.log /var/log/mail.info /var/log/mail.warn /var/log/mail.err
	[ "$SYSLOG_MAIL_RELOAD" = yes ] && echo_postrotate_entry
	echo_rotate_end
	echo_rotate_entry $SYSLOG_KERNEL_MAXCOUNT $SYSLOG_KERNEL_INTERVAL /var/log/kern.log
	[ "$SYSLOG_KERNEL_RELOAD" = yes ] && echo_postrotate_entry
	echo_rotate_end
	echo_rotate_entry $SYSLOG_MESSAGES_MAXCOUNT $SYSLOG_MESSAGES_INTERVAL /var/log/messages /var/log/error.log
	[ "$SYSLOG_MESSAGES_RELOAD" = yes ] && echo_postrotate_entry
	echo_rotate_end
	} >> /etc/logrotate.d/syslog
	[ "$SYSLOG_SOURCE_UDP" = yes ] && echo "  udp( ip(0.0.0.0) port(514) );" >/etc/syslog-ng/syslog-ng-source.base
	/etc/init.d/syslog stop >/dev/null 2>&1
	/sbin/rc-update -q del syslog boot >/dev/null 2>&1
	/sbin/rc-update -q add syslog-ng boot >/dev/null 2>&1
	/etc/init.d/syslog-ng update
	if [ -e /var/run/syslog-ng.pid ]
	then
		/etc/init.d/syslog-ng reload
	else
		/etc/init.d/syslog-ng start
	fi
else
	/etc/init.d/syslog-ng stop
	/sbin/rc-update del syslog-ng boot
	/sbin/rc-update add syslog boot
	/etc/init.d/syslog start
fi

#----------------------------------------------------------------------------
# keyboard and console setup
#----------------------------------------------------------------------------
if [ -e /lib/kbd/keymaps ]
then
    mv -f /etc/keymap/* /lib/kbd/keymaps/
    cp -f /lib/kbd/keymaps/${KEYMAP}.bmap.gz /etc/keymap/
fi
if [ -f /etc/keymap/${KEYMAP}.bmap.gz ]
then
    sed -i '/^KEYMAP=/d' /etc/conf.d/keymaps
    echo "KEYMAP=/etc/keymap/${KEYMAP}.bmap.gz" >> /etc/conf.d/keymaps
    zcat /etc/keymap/${KEYMAP}.bmap.gz | loadkmap
fi

# remove old values
sed -i '/^consolefont=/d' /etc/conf.d/consolefont
#sed -i '/^consoletranslation=/d' /etc/conf.d/consolefont
#sed -i '/^unicodemap=/d' /etc/conf.d/consolefont

{
	echo "consolefont=\"$CONSOLEFONT\""
#	echo 'consoletranslation="8859-1_to_uni"'
#	echo 'unicodemap="iso01"'
} >> /etc/conf.d/consolefont

[ -f /etc/init.d/kbd-mini ] && rc-update kbd-mini start >/dev/null 2>&1
rc-update consolefont restart >/dev/null 2>&1

# Set console blank time ESC 9 and VESA powerdown ESC 14
if [ "0$CONSOLE_BLANK_TIME" -eq 0 ]
then
    echo -n -e '\033[9;0]\033[14;0]' >/dev/console
else
    echo -n -e "\033[9;${CONSOLE_BLANK_TIME}]\033[14;${CONSOLE_BLANK_TIME}]" >/dev/console
fi

# force unicode!
sed -i -e 's/^#unicode=.*/unicode="YES"/' /etc/rc.conf
sed -i -e 's/^unicode=.*/unicode="YES"/'  /etc/rc.conf

exit 0
