#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script for vsftpd
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/vsftpd-trace$$.log
#set -x

. /etc/config.d/vsftpd

#----------------------------------------------------------------------------------------
# creating/edit config file
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
guest_enable=YES
chroot_local_user=YES
virtual_use_local_privs=YES
hide_ids=YES
allow_writeable_chroot=YES
user_config_dir=/etc/vsftpd/users
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/chroot.list
dirmessage_enable=YES
write_enable=YES
local_umask=022
chmod_enable=YES
chown_uploads=YES
chown_username=apache

pam_service_name=vsftpd
ftpd_banner="Welcome to eisfair-ng vsFTPd"

#-------------------------------------------------------------------------------
# logging:
syslog_enable=YES
log_ftp_protocol=YES
xferlog_enable=YES
xferlog_std_format=YES
xferlog_file=/var/log/ftp-xfer.log
setproctitle_enable=YES

EOF

[ -f /etc/vsftpd/passwd ] || touch /etc/vsftpd/passwd
[ -f /etc/vsftpd/chroot.list ] || touch /etc/vsftpd/chroot.list

#----------------------------------------------------------------------------------------
# create pam.d configuration for virtual user
#----------------------------------------------------------------------------------------
cat > /etc/pam.d/vsftpd <<EOF
# basic PAM configuration for vsftpd.
auth required pam_pwdfile.so pwdfile /etc/vsftpd/passwd
account required pam_permit.so

EOF


#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat > /etc/logrotate.d/vsftpd <<EOF
/var/log/ftp*log {
    ${FTP_LOG_INTERVAL}
    missingok
	rotate ${FTP_LOG_MAXCOUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet vsftpd reload > /dev/null 2>/dev/null || true
    endscript
}
EOF

exit 0
