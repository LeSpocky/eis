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


#----------------------------------------------------------------------------------------
# creating configig file
#----------------------------------------------------------------------------------------
enbind="#"
envuap="#"
[ -n "$FTP_PORT" ] && enbind=""
[ "$FTP_VIRTUAL_USERS_USE_APACHE" = "yes" ] && envuap=""

cat > /etc/vsftpd/vsftpd.conf <<EOF
listen=YES
${enbind}ftp_data_port=${FTP_PORT}
listen_address=${FTP_BIND}
seccomp_sandbox=NO
#-------------------------------------------------------------------------------
anonymous_enable=NO
local_enable=YES
write_enable=YES
allow_writeable_chroot=YES
connect_from_port_20=YES
secure_chroot_dir=/run/vsftpd
guest_enable=YES
pam_service_name=vsftpd
ftpd_banner="Welcome to eisfair-ng vsFTPd"
local_root=/var/lib/vsftpd

#local_umask=022
#anon_umask=022
#anon_upload_enable=YES
#anon_mkdir_write_enable=YES
#anon_other_write_enable=YES

#---access to webhome for all virtual users ------------------------------------
${envuap}ftp_username=apache
${envuap}chmod_enable=YES
${envuap}chown_uploads=YES
${envuap}chown_username=apache
${envuap}guest_username=apache
${envuap}local_root=/var/www

#-------------------------------------------------------------------------------
# logging:
dual_log_enable=YES
log_ftp_protocol=YES
syslog_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
xferlog_enable=YES
xferlog_std_format=YES
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
