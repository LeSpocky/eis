#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/skeleton-trace$$.log
#set -x

. /etc/config.d/skeleton

#----------------------------------------------------------------------------------------
# creating/edit config file
#----------------------------------------------------------------------------------------
enbind="#"

[ -n "$FTP_PORT" ] && enbind=""

cat > /etc/skeleton/skeleton.conf <<EOF
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
user_config_dir=/etc/skeleton/users
chroot_list_enable=YES
chroot_list_file=/etc/skeleton/chroot.list
dirmessage_enable=YES
force_dot_files=$FTP_LIST_DOT_FILES
write_enable=YES
local_umask=022
chmod_enable=YES
chown_uploads=YES
chown_username=apache

pam_service_name=skeleton
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

[ -f /etc/skeleton/passwd ] || touch /etc/skeleton/passwd
[ -f /etc/skeleton/chroot.list ] || touch /etc/skeleton/chroot.list

#----------------------------------------------------------------------------------------
# create pam.d configuration for virtual user
#----------------------------------------------------------------------------------------
cat > /etc/pam.d/skeleton <<EOF
# basic PAM configuration for skeleton.
auth required pam_pwdfile.so pwdfile /etc/skeleton/passwd
account required pam_permit.so

EOF


#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat > /etc/logrotate.d/skeleton <<EOF
/var/log/ftp*log {
    ${FTP_LOG_INTERVAL}
    missingok
	rotate ${FTP_LOG_MAXCOUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet skeleton reload > /dev/null 2>/dev/null || true
    endscript
}
EOF

exit 0
