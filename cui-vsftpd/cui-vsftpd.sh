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
enlocalroot=/var/lib/vsftpd

[ -n "$FTP_PORT" ] && enbind=""
if [ "$FTP_VIRTUAL_USERS_USE_APACHE" = "yes" ] ; then
    envuap=""
    enlocalroot=/var/www
fi

cat > /etc/vsftpd/vsftpd.conf <<EOF
listen=YES
${enbind}ftp_data_port=${FTP_PORT}
listen_address=${FTP_BIND}
seccomp_sandbox=NO

#-------------------------------------------------------------------------------
anonymous_enable=NO
#anon_upload_enable=YES
#anon_other_write_enable=YES
#anon_mkdir_write_enable=YES
#anon_world_readable_only=NO
#anon_umask=002
dirmessage_enable=YES
local_enable=YES
write_enable=YES
local_umask=022
chmod_enable=YES
${envuap}chown_uploads=YES
${envuap}chown_username=apache
#chroot_local_user=YES
#chroot_list_enable=YES
#chroot_list_file=/etc/vsftpd/chroot.list

pam_service_name=vsftpd
ftpd_banner="Welcome to eisfair-ng vsFTPd"
local_root=${enlocalroot}

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
[ -f /etc/vsftpd/passwd ] || touch /etc/vsftpd/passwd
[ -f /etc/vsftpd/chroot.list ] || touch /etc/vsftpd/chroot.list

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
