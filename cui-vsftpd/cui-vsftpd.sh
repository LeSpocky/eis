#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script for vsftpd
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/vsftpd-trace$$.log
#set -x

pgmname=$0

FTP_LOG_INTERVAL="daily"
FTP_LOG_COUNT="30"

. /etc/config.d/vsftpd


if [ "$START_FTP" = "yes" ] ; then
     rc-update -q add vsftpd 2>/dev/null
else
     rc-update del vsftpd
fi


#----------------------------------------------------------------------------------------
# creating configig file
#----------------------------------------------------------------------------------------
enbind="#"
[ -n "$FTP_PORT" ] && enbind=""

cat > /etc/vsftpd/vsftpd.conf <<EOF
listen=YES
${enbind}ftp_data_port=${FTP_PORT}
listen_address=${FTP_BIND}
seccomp_sandbox=NO
#-------------------------------------------------------------------------------
anonymous_enable=NO
local_enable=YES
#virtual_use_local_privs=YES
write_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/run/vsftpd
guest_enable=YES
pam_service_name=vsftpd
ftpd_banner="Welcome to eisfair-ng vsFTPd"
local_root=/var/lib/vsftpd
#-------------------------------------------------------------------------------
# logging:
dual_log_enable=YES
log_ftp_protocol=YES
syslog_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
xferlog_enable=YES
xferlog_file=/var/log/vsftpd-xfer.log
EOF

mkdir -p /var/lib/vsftpd

#----------------------------------------------------------------------------------------
# create pam.d configuration for virtual user
#----------------------------------------------------------------------------------------
cat > /etc/pam.d/vsftpd <<EOF
# basic PAM configuration for vsftpd.
auth required pam_pwdfile.so debug pwdfile /etc/vsftpd/passwd
account required pam_permit.so

EOF


#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat >> /etc/logrotate.d/vsftpd <<EOF
/var/log/vsftpd*log {
    ${FTP_LOG_INTERVAL}
    missingok
	rotate ${FTP_LOG_COUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet vsftpd reload > /dev/null 2>/dev/null || true
    endscript
}
EOF


exit 0
