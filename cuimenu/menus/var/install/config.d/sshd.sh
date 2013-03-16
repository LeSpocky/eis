#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/config.d/ssh.sh - configuration generator script for SSH
# Copyright (c) 2001-2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# include config
. /etc/config.d/sshd

# port
sed -i '/^Port /d'              /etc/ssh/sshd_config
echo "Port $SSHD_PORT" >>       /etc/ssh/sshd_config

# use DNS 
sed -i '/^UseDNS /d'            /etc/ssh/sshd_config
echo "UseDNS $SSHD_USEDNS" >>   /etc/ssh/sshd_config

# IP address
sed -i '/^ListenAddress /d'     /etc/ssh/sshd_config
if [ "$SSHD_LISTEN_ADDR_N" -gt 0 ]
then
    idx=1
    echo "ListenAddress 127.0.0.1" >> /etc/ssh/sshd_config
    while [ "$idx" -le "$SSHD_LISTEN_ADDR_N" ]
    do
        eval laddr='$SSHD_LISTEN_ADDR_'$idx
        if [ -n "$laddr" ]
        then
            # check number, substitution has to result in an empty string
            e_laddr=`echo "$laddr" | sed 's|[0-9]*||'`
            if [ -z "$e_laddr" ]
            then
                eval ipaddr=\${IP_NET_${laddr}_IPADDR}
                if [ -n "$ipaddr" ]
                then
                    echo "ListenAddress $ipaddr " >> /etc/ssh/sshd_config
                fi
            fi
        fi
        idx=`expr ${idx} + 1`
    done
fi

# enable sftp
if [ "$SSHD_ENABLE_SFTP" = "yes" ]
then
    sed -i -e 's/^#Subsystem.*sftp.*/Subsystem	sftp	/usr/lib/ssh/sftp-server/' /etc/ssh/sshd_config
else
    sed -i -e 's/^Subsystem.*sftp.*/#Subsystem	sftp	/usr/lib/ssh/sftp-server/' /etc/ssh/sshd_config
fi

# Loglevel
sed -i '/^LogLevel /d'            /etc/ssh/sshd_config
echo "LogLevel $SSHD_LOGLEVEL" >> /etc/ssh/sshd_config

#----------------------------------------------------------------------------
# create authorized_keys file and add public keys
#----------------------------------------------------------------------------
ssh_authorized_keys_file_tmp="/root/.ssh/authorized_keys_tmp.$$"
mkdir -p /root/.ssh
(
    idx=1
    while [ "$idx" -le "$SSHD_PUBLIC_KEY_N" ]
    do
        eval key='$SSHD_PUBLIC_KEY_'${idx}
        if [ -n "$key" ]
        then
            if [ "${key:0:1}" = '/' ]
            then
                if [ -r "$key" ]
                then
                    cat "$key"
                    # add newline
                    echo ""
                fi
            else
                echo "$key"
                # add newline
                echo ""
            fi
        fi
        idx=`expr $idx + 1`
    done
) > $ssh_authorized_keys_file_tmp 

# copy temporary file to final file
# omit empty lines
grep -v '^$' $ssh_authorized_keys_file_tmp > /root/.ssh/authorized_keys
rm -f $ssh_authorized_keys_file_tmp


#----------------------------------------------------------------------------
# start stop update
#----------------------------------------------------------------------------
if [ "$START_SSHD" = "yes" ]
then
	  rc-update -q add sshd 2>/dev/null
else
	  rc-update -q del sshd  2>/dev/null
fi


exit 0
