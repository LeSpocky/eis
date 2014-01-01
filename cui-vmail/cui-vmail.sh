#!/bin/sh
#----------------------------------------------------------------------------
# /etc/config.d/vmail.sh - configuration generator script
#
# Creation:     2006-04-14 Jens Vehlhaber <jens(at)eisfair(dot)org>
# Last Update:  $Id: vmail.sh 32893 2013-02-01 11:34:00Z jv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#set -x

#include eislib
. /var/install/include/eislib
#include eisdate-time
. /var/install/include/eistime


### -------------------------------------------------------------------------
### internal parameter - not editable with ECE:
### -------------------------------------------------------------------------
VMAIL_TLS_CERT='/usr/local/ssl/certs/imapd.pem' # path to ssl cert
VMAIL_TLS_KEY='/usr/local/ssl/private/imapd.key'
VMAIL_TLS_CAPATH='/usr/local/ssl/certs'
POSTFIX_AV_QUARANTINE_DIR="/var/spool/postfix/quarantine"
# default values
POSTFIX_SMARTHOST='no'
POSTFIX_SMARTHOST_TLS='no'


### -------------------------------------------------------------------------
### check the password file and get the passwords
### -------------------------------------------------------------------------
# include config files base and vmail
. /etc/config.d/base
. /etc/config.d/vmail


if [ "$VMAIL_SQL_HOST" = 'localhost' ]
then
    vmail_sql_connect="unix:/var/run/mysql/mysql.sock"
else
    vmail_sql_connect="$VMAIL_SQL_HOST"
fi


# login with completed mail address or username only
if [ "$VMAIL_LOGIN_WITH_MAILADDR" = "yes" ]
then
    dovecot_query="email"
    dovecot_authf="auth_username_format = %Lu"
    dovecot_deliver="\${recipient}"
else
    dovecot_query="loginuser"
    dovecot_authf="auth_username_format = %Ln "
    dovecot_deliver="\${user}"
fi



### ----------------------------------------------------------------------------
### write new postfix config
### ----------------------------------------------------------------------------
write_postfix_config()
{
    local postfix_int_netw=""
    local postfix_whoson=""
    local postfix_cl_access_bl=""
    local postfix_dyn_client_bl=""
    local postfix_un_cl_hostname=""
    local postfix_un_send_dom=""
    local postfix_send_mx=""
    local postfix_fqdn_helo=""
    local postfix_rbl_list=""
    local postfix_mime_header_ch=""
    local postfix_header_ch=""
    local postfix_sasl=""
    local postfix_relayhosts=""
    local postfix_relayhosts_auth=""
    local postfix_pscr_dnsbl_action="ignore"
    local postfix_pscreen="#"
    local postfix_psmtpd=""
    local postfix_prxmynet=""

    [ -z "$POSTFIX_HELO_HOSTNAME" ] && POSTFIX_HELO_HOSTNAME="${HOSTNAME}.${DOMAIN_NAME}"
    count=1
    while [ ${count} -le ${POSTFIX_RELAY_FROM_NET_N} ]
    do
        eval temp1='$POSTFIX_RELAY_FROM_NET_'${count}
        postfix_int_netw="${postfix_int_netw}, ${temp1}"
        count=`expr ${count} + 1`
    done

    [ $POSTFIX_LIMIT_MAILSIZE -gt 10 ] || POSTFIX_LIMIT_MAILSIZE="10" 
    [ $POSTFIX_LIMIT_DESTINATIONS -gt 10 ] || POSTFIX_LIMIT_DESTINATIONS="10"
    [ "$POSTFIX_DRACD" = "yes" ] && postfix_int_netw="${postfix_int_netw}, proxy:btree:/etc/postfix/dracd"
    [ "$POSTFIX_DRACD" = "yes" ] && postfix_prxmynet="\$mynetworks,"

    [ "$POSTFIX_CLIENT_N" -gt 0 ] && postfix_cl_access_bl="check_client_access pcre:/etc/postfix/client_access_blocks.pcre," 
    [ "$POSTFIX_REJECT_UNKN_CLIENT" = "yes" ] && postfix_un_cl_hostname="reject_unknown_client_hostname,"
    [ "$POSTFIX_REJECT_UNKN_SEND_DOM" = "yes" ] && postfix_un_send_dom="reject_non_fqdn_sender, reject_unknown_sender_domain,"
    [ "$POSTFIX_REJECT_DYNADDRESS" = "yes" ] && postfix_dyn_client_bl="check_client_access pcre:/etc/postfix/client_access_dynblocks.pcre,"
    [ "$POSTFIX_REJECT_BOGUS_MX" = "yes" ] && postfix_send_mx="check_sender_mx_access proxy:cidr:/etc/postfix/bogus_mx.cidr,"
    [ "$POSTFIX_REJECT_NON_FQDN_HOST" = "yes" ] && postfix_fqdn_helo="reject_non_fqdn_helo_hostname," # kann Probleme mit Webmailern machen!
    if [ "$POSTFIX_POSTSCREEN" = "yes" ]
    then
        postfix_pscreen=""
        postfix_psmtpd="#"
    fi
    if [ "$POSTFIX_RBL" = "yes" ]
    then
        count=1
        while [ ${count} -le ${POSTFIX_RBL_N} ]
        do
            eval temp1='$POSTFIX_RBL_'${count}'_SERVER'
            eval temp2='$POSTFIX_RBL_'${count}'_WEIGHT'
            postfix_pscr_dnsbl_action="enforce"
            [ -n "$temp2" ] && temp2="*${temp2}" 
            postfix_rbl_list="$postfix_rbl_list ${temp1}${temp2}"
            if [ ${POSTFIX_RBL_N} -gt ${count} ]
            then
                postfix_rbl_list="$postfix_rbl_list,"
            fi
            count=`expr ${count} + 1`
        done
    fi
    [ "$POSTFIX_MIME_HEADER_CHECK" = 'yes' ] && postfix_mime_header_ch="pcre:/etc/postfix/mime_header_checks.pcre"
    [ "$POSTFIX_HEADER_N" -gt 0 ] && postfix_header_ch="pcre:/etc/postfix/header_checks.pcre"
    [ "$START_POP3IMAP" = 'yes' ] && postfix_sasl="permit_sasl_authenticated,"
    [ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts.cf"
    [ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts_auth="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts_auth.cf"

    postconf -e "queue_directory = /var/spool/postfix"
    postconf -e "command_directory = /usr/sbin"
    postconf -e "daemon_directory = /usr/local/postfix"
    postconf -e "data_directory = /var/lib/postfix"
    postconf -e "mail_spool_directory = /var/spool/postfix"
    postconf -e "mail_owner = mail"
    postconf -e "setgid_group = maildrop"
    postconf -e "myhostname = ${POSTFIX_HELO_HOSTNAME}"
    postconf -e "myorigin = \$mydomain"
    postconf -e "inet_interfaces = all"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
    postconf -e "unknown_local_recipient_reject_code = 550"
    postconf -e "unknown_address_reject_code = 554"
    postconf -e "unknown_hostname_reject_code = 554"
    postconf -e "unknown_client_reject_code = 450"
    postconf -e "mynetworks = 127.0.0.0/8${postfix_int_netw}"
    postconf -e "always_add_missing_headers = yes"
    postconf -e "alias_maps = "
    postconf -e "alias_database ="
    postconf -e "local_destination_concurrency_limit = 1"
    postconf -e "fax_destination_recipient_limit = 1"
    postconf -e "pop3imap_destination_recipient_limit = 1"
    postconf -e "default_destination_recipient_limit = $POSTFIX_LIMIT_DESTINATIONS"

    postconf -e "proxy_read_maps = ${postfix_prxmynet}\$local_recipient_maps,\$mydestination,\$virtual_alias_maps,\$virtual_alias_domains,\$virtual_mailbox_maps,\$virtual_mailbox_domains,\$virtual_mailbox_limit_maps,\$relay_recipient_maps,\$relay_domains,\$canonical_maps,\$sender_canonical_maps,\$recipient_canonical_maps,\$relocated_maps,\$transport_maps,\$mynetworks,\$mail_restrict_map,\$smtpd_recipient_restrictions,\$sender_dependent_relayhost_maps,\$smtp_sasl_password_maps,\$postscreen_access_list"
    postconf -e "transport_maps = proxy:mysql:/etc/postfix/mysql-transport.cf"    
    postconf -e "mail_restrict_map = proxy:mysql:/etc/postfix/mysql-virtual_restrictions.cf"
    postconf -e "virtual_alias_maps = proxy:mysql:/etc/postfix/mysql-virtual_aliases.cf,proxy:mysql:/etc/postfix/mysql-virtual_email2email.cf"
    postconf -e "virtual_uid_maps = static:910"
    postconf -e "virtual_gid_maps = static:910"
    postconf -e "virtual_mailbox_domains = proxy:mysql:/etc/postfix/mysql-virtual_domains.cf"
    postconf -e "virtual_mailbox_maps = proxy:mysql:/etc/postfix/mysql-virtual_mailbox_maps.cf"
    postconf -e "virtual_mailbox_base = /var/spool/postfix/virtual"
    postconf -e "virtual_transport = pop3imap"
    echo -n "."
    postconf -e "bounce_queue_lifetime = ${POSTFIX_QUEUE_LIFETIME}d"
    postconf -e "maximal_queue_lifetime = ${POSTFIX_QUEUE_LIFETIME}d"

    postconf -e "message_size_limit = ${POSTFIX_LIMIT_MAILSIZE}000000"
    postconf -e "mailbox_size_limit = 0"
    
    postconf -e "masquerade_exceptions = root"
    postconf -e "masquerade_classes = envelope_sender, header_sender, header_recipient"
    postconf -e "masquerade_domains = \$mydomain"

    postconf -e "smtpd_restriction_classes = restrictions_0,restrictions_1,restrictions_2,restrictions_3,restrictions_4,restrictions_5,restrictions_6,restrictions_7,restrictions_8,restrictions_9"
    postconf -e "restrictions_0 = permit_mynetworks"
# sender (user@domain.tld)/hostname (host.domain.tld) not fqdn; mailservers without reverse DNS entry
    postconf -e "restrictions_1 = reject_unknown_client_hostname,reject_non_fqdn_sender,reject_non_fqdn_hostname"
# use access list
    postconf -e "restrictions_2 = check_client_access pcre:/etc/postfix/client_access_dynblocks.pcre"
    postconf -e "restrictions_3 = reject_non_fqdn_sender,reject_non_fqdn_hostname,reject_unknown_client_hostname,check_client_access pcre:/etc/postfix/client_access_dynblocks.pcre"
    postconf -e "restrictions_4 = permit_mynetworks"
    postconf -e "restrictions_5 = permit_mynetworks"
    postconf -e "restrictions_6 = permit_mynetworks"
    postconf -e "restrictions_7 = permit_mynetworks"
    postconf -e "restrictions_8 = permit_mynetworks"
    postconf -e "restrictions_9 = REJECT"

    postconf -e "smtpd_helo_required = yes"
    postconf -e "smtpd_helo_restrictions ="
    postconf -e "smtpd_sender_restrictions ="
    postconf -e "smtpd_client_restrictions ="
    postconf -e "smtpd_recipient_restrictions = permit_mynetworks,${postfix_sasl} permit_tls_clientcerts,${postfix_whoson}\
 reject_unlisted_recipient, reject_unauth_destination,\
 check_client_access proxy:mysql:/etc/postfix/mysql-client_access.cf,\
 check_recipient_access proxy:mysql:/etc/postfix/mysql-recipient_access.cf,\
 check_sender_access proxy:mysql:/etc/postfix/mysql-sender_access.cf,\
 reject_invalid_helo_hostname,${postfix_cl_access_bl}${postfix_dyn_client_bl}\
 proxy:mysql:/etc/postfix/mysql-virtual_restrictions.cf,\
 ${postfix_un_cl_hostname}${postfix_un_send_dom}${postfix_send_mx}${postfix_fqdn_helo} permit"

    postconf -e "mime_header_checks = $postfix_mime_header_ch"
    postconf -e "header_checks = $postfix_header_ch"

    postconf -e "tls_random_source = dev:/dev/urandom"
    postconf -e "tls_random_prng_update_period = 3600s"
# SASL setup
    if [ "$START_POP3IMAP" = "yes" ]
    then
        postconf -e "smtpd_sasl_auth_enable = yes"
        postconf -e "smtpd_sasl_path = private/auth"
        postconf -e "broken_sasl_auth_clients = yes" 
    else
        postconf -e "smtpd_sasl_auth_enable = no"
        postconf -e "smtpd_sasl_path = smtpd"
        postconf -e "broken_sasl_auth_clients = no" 
    fi

    # relay host
    postconf -e 'smtp_connection_cache_on_demand = no'
    postconf -e "smtp_sender_dependent_authentication = $POSTFIX_SMARTHOST"
    postconf -e "smtp_tls_cert_file = $VMAIL_TLS_CERT"
    postconf -e "smtp_tls_key_file = $VMAIL_TLS_KEY"
    postconf -e "smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache"
    postconf -e "smtp_sasl_auth_enable = $POSTFIX_SMARTHOST"
    postconf -e "smtp_use_tls = $POSTFIX_SMARTHOST_TLS"
    postconf -e "smtp_sasl_password_maps = $postfix_relayhosts_auth"
    postconf -e "smtp_sasl_security_options = noanonymous"
    postconf -e "sender_canonical_maps = proxy:mysql:/etc/postfix/mysql-canonical_maps.cf"
    postconf -e "sender_dependent_relayhost_maps = $postfix_relayhosts"


    postconf -e "smtpd_tls_auth_only = no"
    if [ "$POSTFIX_SMTP_TLS" = 'yes' ]
    then
        if [ -e ${VMAIL_TLS_CAPATH}/cacert.pem ]
        then 
            postconf -e "smtpd_tls_CAfile = ${VMAIL_TLS_CAPATH}/cacert.pem"
        else
            postconf -e "smtpd_tls_CAfile ="
        fi
        postconf -e "smtpd_tls_CApath = $VMAIL_TLS_CAPATH"
        postconf -e "smtpd_tls_cert_file = $VMAIL_TLS_CERT"
        postconf -e "smtpd_tls_key_file = $VMAIL_TLS_KEY"
        postconf -e "smtpd_tls_received_header = yes"
        postconf -e "smtpd_tls_security_level = may"
    else
        postconf -e "smtpd_tls_CAfile ="
        postconf -e "smtpd_tls_CApath ="
        postconf -e "smtpd_tls_cert_file ="
        postconf -e "smtpd_tls_key_file ="
        postconf -e "smtpd_tls_received_header = no"
        postconf -e "smtpd_tls_security_level ="
    fi    
    postconf -e "smtpd_tls_session_cache_database = btree:/var/lib/postfix/smtpd_tls_session_cache"
    postconf -e "smtpd_tls_session_cache_timeout  = 9600s"
    postconf -e "smtpd_tls_req_ccert              = no"
    postconf -e "smtpd_tls_dh1024_param_file      = /etc/postfix/ssl/dh_1024.pem"
    postconf -e "smtpd_tls_dh512_param_file       = /etc/postfix/ssl/dh_512.pem"
    if [ $POSTFIX_LOGLEVEL -gt 1 ]
    then
        postconf -e "smtpd_tls_loglevel = $POSTFIX_LOGLEVEL"  
    else
        postconf -e "smtpd_tls_loglevel = 1" 
    fi

    rm -f /etc/postfix/header_checks.pcre
    touch /etc/postfix/header_checks.pcre
    count=1
    while [ ${count} -le ${POSTFIX_HEADER_N} ]
    do
        eval temp1='$POSTFIX_HEADER_'${count}'_CHECK'
        eval temp2='$POSTFIX_HEADER_'${count}'_HANDL'
        echo "/${temp1}/ ${temp2}" >> /etc/postfix/header_checks.pcre
        count=`expr ${count} + 1`
    done
    rm -f /etc/postfix/client_access_blocks.pcre
    touch /etc/postfix/client_access_blocks.pcre
    count=1
    while [ ${count} -le ${POSTFIX_CLIENT_N} ]
    do
        eval temp1='$POSTFIX_CLIENT_'${count}'_CHECK'
        eval temp2='$POSTFIX_CLIENT_'${count}'_HANDL'
        echo "/${temp1}/ ${temp2}" >> /etc/postfix/client_access_blocks.pcre
        count=`expr ${count} + 1`
    done

    postconf -e "milter_default_action = accept"
    postconf -e "milter_connect_macros = j"
    postconf -e "milter_protocol = 3"
   
    # postscreen antispam setup
    postconf -e "postscreen_greet_action = enforce"
#    postconf -e "postscreen_hangup_action = drop"
    postconf -e "postscreen_dnsbl_action = $postfix_pscr_dnsbl_action"
    postconf -e "postscreen_dnsbl_sites = $postfix_rbl_list"
    postconf -e "postscreen_dnsbl_threshold = 3"
    postconf -e "postscreen_access_list = permit_mynetworks, proxy:mysql:/etc/postfix/mysql-client_access_postscreen.cf"

echo -n "."
cat > /etc/postfix/master.cf <<EOF
# --------------------------------------------------------------------------
# Postfix master process configuration file.
# Creation: $EISDATE $EISTIME by vmail setup
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================
${postfix_psmtpd}smtp      inet  n       -       y       -       -       smtpd
${postfix_pscreen}smtp      inet  n       -       y       -       1       postscreen
${postfix_pscreen}smtpd     pass  -       -       y       -       -       smtpd
${postfix_pscreen}dnsblog   unix  -       -       y       -       0       dnsblog
${postfix_pscreen}tlsproxy  unix  -       -       y       -       0       tlsproxy
#submission inet n       -       n       -       -       smtpd
#  -o smtpd_tls_security_level=encrypt
#  -o smtpd_sasl_auth_enable=yes
#  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
#  -o milter_macro_daemon_name=ORIGINATING
EOF
if [ "$POSTFIX_ALTERNATE_SMTP_PORT" -gt 25 ] 
then 
    echo "${postfix_psmtpd}smtp-alt  inet  n       -       y       -       -       smtpd"  >> /etc/postfix/master.cf
    echo "${postfix_pscreen}smtp-alt  inet  n       -       y       -       -       postscreen"  >> /etc/postfix/master.cf
fi
if [ "$POSTFIX_SMTP_TLS" = 'yes' ]
then
cat >> /etc/postfix/master.cf <<EOF
smtps     inet  n       -       y       -       -       smtpd 
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF
fi
cat >> /etc/postfix/master.cf <<EOF
#628      inet  n       -       n       -       -       qmqpd
pickup    fifo  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      fifo  n       -       y       300     1       qmgr
#qmgr     fifo  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
# When relaying mail as backup MX, disable fallback_relay to avoid MX loops
relay     unix  -       -       y       -       -       smtp
	-o smtp_fallback_relay=
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
# ==========================================================================
# Interfaces to non-Postfix software
# ==========================================================================
pop3imap  unix  -       n       n       -       -       pipe
    flags=DRhu user=vmail:vmail argv=/usr/local/dovecot/deliver -d ${dovecot_deliver}
fax       unix  -       n       n       -       1       pipe
    flags= user=fax argv=/usr/local/bin/mail2fax \${sender} \${recipient}
#    flags= user=fax argv=/usr/bin/faxmail -d -n \${user} \${sender}
uucp      unix  -       n       n       -       -       pipe
    flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)
sms     unix    -       n       n       -       1       pipe
    flags= user=nobody argv=/usr/local/postfix/mail2sms \${user} \${sender}

EOF

    # force permissions
    chown    root:root   /var/spool/postfix/etc
    chown -R root:root   /var/spool/postfix/lib
    chown -R root:root   /var/spool/postfix/usr
    chown    root:root   /var/spool/postfix/var   
    chown    vmail:vmail /var/spool/postfix/virtual
    chmod 0777           /var/spool/postfix/var/lib
#    chown postfix:root /var/spool/postfix
#    chown postfix:root /var/spool/postfix/pid
    /usr/sbin/postfix set-permissions
    echo -n "."
}


### -------------------------------------------------------------------------
### change smc-milter.conf file
### -------------------------------------------------------------------------
write_milter_config()
{
    local connectport=0

    # check if installed clamav
    if [ ! -f /var/install/packages/clamav ]
    then
        if [ "$POSTFIX_AV_CLAMAV" = 'yes' ]
        then
            mecho --error "ClamAV not found. Set POSTFIX_AV_CLAMAV='no'"
            POSTFIX_AV_CLAMAV='no'
        fi
    fi
 
    [ "${VMAIL_SQL_HOST}" = "localhost" ] || connectport=3306
   
    sed -i -e "s|^clamcheck.*|clamcheck		${POSTFIX_AV_CLAMAV}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^fprotcheck.*|fprotcheck		${POSTFIX_AV_FPROTD}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^quarantinedir.*|quarantinedir		${POSTFIX_AV_QUARANTINE_DIR}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^avmail.*|avmail			${POSTFIX_AV_VIRUS_INFO}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^signatureadd.*|signatureadd		${POSTFIX_AUTOSIGNATURE}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^dbhost.*|dbhost			${VMAIL_SQL_HOST}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^dbport.*|dbport			${connectport}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^dbname.*|dbname			${VMAIL_SQL_DATABASE}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^dbuser.*|dbuser			${VMAIL_SQL_USER}|" /etc/postfix/smc-milter.conf
    sed -i -e "s|^dbpass.*|dbpass			${VMAIL_SQL_PASS}|" /etc/postfix/smc-milter.conf
    if [ "$POSTFIX_AV_SCRIPT" = "yes" ]
    then
        sed -i -e "s|.*scriptfile.*|scriptfile		${POSTFIX_AV_SCRIPTFILE}|" /etc/postfix/smc-milter.conf
    else
        sed -i -e "s|^scriptfile.*|#scriptfile|" /etc/postfix/smc-milter.conf
    fi
    [ -e /etc/postfix/smc-milter.hosts ] || touch /etc/postfix/smc-milter.hosts

    mkdir -p   ${POSTFIX_AV_QUARANTINE_DIR}
    chmod 0777 ${POSTFIX_AV_QUARANTINE_DIR}
    echo -n "."
}


### -------------------------------------------------------------------------
### Generate DRACD conf
### -------------------------------------------------------------------------
make_dracd_conf()
{
    if [ "$POSTFIX_DRACD" = "yes" ] 
    then
        echo "255.255.255.255 127.0.0.1" > /etc/postfix/dracd.internal 
        count=1
        while [ ${count} -le ${POSTFIX_RELAY_FROM_NET_N} ]
        do
            eval temp1='$POSTFIX_RELAY_FROM_NET_'${count}
            echo "`netcalc netmask ${temp1}` `netcalc network ${temp1}`" >> /etc/postfix/dracd.internal
            count=`expr ${count} + 1`
        done
        chmod 0644 /etc/postfix/dracd.internal
    else
        rm -f /etc/postfix/dracd.internal
    fi
}


### ----------------------------------------------------------------------------
### update sql query files for postfix and dovecot
### ----------------------------------------------------------------------------
update_sql_files()
{
    # postfix:
    for sqlfile in mysql-canonical_maps.cf mysql-client_access.cf \
                   mysql-client_access_postscreen.cf mysql-recipient_access.cf \
                   mysql-sender_access.cf mysql-transport.cf \
                   mysql-virtual_aliases.cf mysql-virtual_domains.cf \
                   mysql-virtual_email2email.cf mysql-virtual_mailbox_maps.cf \
                   mysql-virtual_relayhosts_auth.cf mysql-virtual_relayhosts.cf \
                   mysql-virtual_restrictions.cf
    do
        sed -i -e "s|^user.*|user = ${VMAIL_SQL_USER}|"         /etc/postfix/$sqlfile
        sed -i -e "s|^password.*|password = ${VMAIL_SQL_PASS}|" /etc/postfix/$sqlfile
        sed -i -e "s|^dbname.*|dbname = ${VMAIL_SQL_DATABASE}|" /etc/postfix/$sqlfile
        sed -i -e "s|^hosts.*|hosts = ${vmail_sql_connect}|"    /etc/postfix/$sqlfile 
        chmod 0640 /etc/postfix/$sqlfile
        chgrp mail /etc/postfix/$sqlfile
    done
    sed -i -e "s|^query.*|query = SELECT CONCAT(username,':',AES_DECRYPT(password, '${VMAIL_SQL_ENCRYPT_KEY}')) FROM view_relaylogin WHERE email like '%s'|" /etc/postfix/mysql-virtual_relayhosts_auth.cf

    # dovecot:
    sed -i -e "s|^connect =.*|connect = host=$VMAIL_SQL_HOST dbname=$VMAIL_SQL_DATABASE user=$VMAIL_SQL_USER password=${VMAIL_SQL_PASS}|" /etc/dovecot/dovecot-sql.conf.ext 
    sed -i -e "s|^connect =.*|connect = host=$VMAIL_SQL_HOST dbname=$VMAIL_SQL_DATABASE user=$VMAIL_SQL_USER password=${VMAIL_SQL_PASS}|" /etc/dovecot/dovecot-dict-sql.conf.ext 
    sed -i -e "s|^password_query =.*|password_query = SELECT email as user, AES_DECRYPT(password, '${VMAIL_SQL_ENCRYPT_KEY}') as password FROM view_users WHERE $dovecot_query = '%u'|" /etc/dovecot/dovecot-sql.conf.ext
    sed -i -e "s|^  username_field =.*|  username_field = ${dovecot_query}|" /etc/dovecot/dovecot-dict-sql.conf.ext 
    if [ "$POP3IMAP_TLS" = "yes" ]
    then
        sed -i -e "s|^protocols =.*|protocols = imap pop3 imaps pop3s managesieve|" /etc/dovecot/dovecot.conf 
    else
        sed -i -e "s|^protocols =.*|protocols = imap pop3 managesieve|" /etc/dovecot/dovecot.conf 
    fi
    sed -i -e "s|^ssl =.*|ssl = ${POP3IMAP_TLS}|" /etc/dovecot/dovecot.conf 
    sed -i -e "s|.*auth_username_format.*|${dovecot_authf} |" /etc/dovecot/dovecot.conf 
    if [ "$POSTFIX_DRACD" = "yes" ] 
    then
        sed -i -e "s|^  mail_plugins = autocreate|  mail_plugins = drac autocreate|" /etc/dovecot/dovecot.conf  
    else
        sed -i -e "s|^  mail_plugins = drac |  mail_plugins = |" /etc/dovecot/dovecot.conf
    fi
    if [ $POSTFIX_LOGLEVEL -gt 2 ]
    then
        sed -i -e "s|^#mail_debug.*|mail_debug = yes|" /etc/dovecot/dovecot.conf
    else
        sed -i -e "s|^mail_debug.*|#mail_debug = yes|" /etc/dovecot/dovecot.conf
    fi


    # secure doevecot sql password include files!
    rm -f /etc/dovecot/dovecot.*.bak
    chown dovecot:vmail /etc/dovecot
    chmod 0770 /etc/dovecot
    chown dovecot:root /etc/dovecot/dovecot-dict-sql.conf.ext
    chmod 0640 /etc/dovecot/dovecot-dict-sql.conf.ext
    chown dovecot:root /etc/dovecot/dovecot-sql.conf.ext
    chmod 0640 /etc/dovecot/dovecot-sql.conf.ext
    chown dovecot:vmail /etc/dovecot/dovecot.conf
    chmod 0640 /etc/dovecot/dovecot.conf
}


### -------------------------------------------------------------------------
### create ssl file
### -------------------------------------------------------------------------
create_ssl_files()
{
# cd /etc/ssl/dovecot
# openssl genrsa -aes256 -out server.key.passwd 2048
# openssl rsa -in server.key.passwd -out server.key
# rm server.key.passwd
# openssl req -new -key server.key -out server.csr
# openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
# cat server.key server.crt>server.pem
# chmod 400 *
# chown dovecot *

mkdir -p /etc/postfix/ssl
cd /etc/postfix/ssl

#   openssl req -new -nodes -keyout server-key.pem -out server-req.pem -days 365
#   openssl ca -out server-crt.pem -infiles server-req.pem
# Diffie-Hellman only for postfix use!
openssl gendh -out /etc/postfix/ssl/dh_512.pem -2 512    
openssl gendh -out /etc/postfix/ssl/dh_1024.pem -2 1024
#  chmod 644 /etc/postfix/ssl/server-crt.pem /etc/postfix/ssl/demoCA/cacert.pem
#  chmod 400 /etc/postfix/ssl/server-key.pem
#c_rehash.sh /etc/postfix/ssl
}

### -------------------------------------------------------------------------
### create aliases file
### -------------------------------------------------------------------------
append_to_stdfile()
{
    filelist=`ls ${fname_std}.* 2>/dev/null | egrep -v ".backup|.std|.db|~"`
    for FN in $filelist
    do
        # read files line by line
        while read line
        do
            # ignore blank or empty lines and comments
            echo "$line" | grep -q '^[[:space:]]*$' && continue
            echo $line | grep "^#" > /dev/null
            if [ $? -ne 0 ]
            then
                usrname=`echo $line | cut -d":" -f1 | sed 's/ //g'`
                if [ ! -z "$usrname" ]
                then
                    entry=`cat ${fname_std} | grep "^${usrname}:"`
                    if [ -z "$entry" ]
                    then
                        cat $FN | grep "^${usrname}:" >> ${fname_std}
                    fi
                fi
            fi
        done < $FN
    done
}


### -------------------------------------------------------------------------
### Generate Service
### -------------------------------------------------------------------------
update_remote_port ()
{
    {
    [ "$POSTFIX_SMTP_TLS" = 'yes' ]           &&                 echo "smtps            465/tcp  # smtp over SSL"
    [ "$POSTFIX_ALTERNATE_SMTP_PORT" -gt 25 ] &&                 echo "smtp-alt         ${POSTFIX_ALTERNATE_SMTP_PORT}/tcp  # smtp with other port"
    [ "$POP3IMAP_TLS" = 'yes' -o "$START_FETCHMAIL" = 'yes' ] && echo "pop3s            995/tcp  # pop3 over SSL"
    [ "$POP3IMAP_TLS" = 'yes' ]       &&                         echo "imaps            993/tcp  # imap over SSL"
    } > /etc/services.vmail
    /var/install/bin/update-services vmail
}



### --------------------------------------------------------------------------
### add cron job
### --------------------------------------------------------------------------
add_cron_job()
{
    mkdir -p /etc/cron/root
cat > /etc/cron/root/postfix <<EOF
# ==============================================================
# Postfix logfile update
# Creation: $EISDATE $EISTIME by vmail setup
# ==============================================================
#59 23 * * * /usr/local/postfix/rejectlogfilter.sh
EOF

    if [ "$START_POP3IMAP" = 'yes' ]
    then
        echo "00,30 * * * * /usr/local/dovecot/mysqlsievefilter.sh " >> /etc/cron/root/postfix
    fi 

    if [ "$START_FETCHMAIL" = "yes" ]
    then
        cat > /etc/cron/root/fetchmail <<EOF
# ==============================================================
# Fetchmail start
# Creation: $EISDATE $EISTIME
# ==============================================================
$FETCHMAIL_CRON_SCHEDULE /usr/local/postfix/fetchmailstart.sh
EOF
    else
        rm -f /etc/cron/root/fetchmail
    fi
    # update crontab file
    /var/install/config.d/cron 
}



### -------------------------------------------------------------------------
### make fetchmail startfile
### -------------------------------------------------------------------------
create_fetchmail_file()
{
    logging="-s"
    if [ "$FETCHMAIL_LOG" = "yes" ]
    then
        logging="--syslog"
    fi
    cat > /usr/local/postfix/fetchmailstart.sh <<EOF
#!/bin/sh
#------------------------------------------------------------------------------
. /etc/config.d/vmail
fetchfile=".fetchmailrc.\$$"
su vmail -c "/usr/local/postfix/fetchmysql -t /var/spool/postfix/virtual/\${fetchfile} \
            -u \$VMAIL_SQL_USER -s \$VMAIL_SQL_HOST -d \$VMAIL_SQL_DATABASE -p \$VMAIL_SQL_PASS -e \$VMAIL_SQL_ENCRYPT_KEY; \\
            /usr/bin/fetchmail -t ${FETCHMAIL_TIMEOUT} -f /var/spool/postfix/virtual/\$fetchfile $logging --nobounce --sslcertpath $VMAIL_TLS_CAPATH --postmaster $FETCHMAIL_POSTMASTER 2>/dev/null ; \\
            rm -f /var/spool/postfix/virtual/\$fetchfile"
exit 0
EOF
    chmod 0700 /usr/local/postfix/fetchmailstart.sh
}


### -------------------------------------------------------------------------
### create new SQL database or change values
### -------------------------------------------------------------------------
sql_database_check()
{
    local count=1
    local npass=0
    local mysql_pass="x"
    local mysql_user='root' 

    # get password for MySQL admin user 'backup' if exists
    if  [ -f /var/lib/mysql/backup.pwd ] 
    then
        mysql_pass=`grep passwd= /var/lib/mysql/backup.pwd | sed "s/passwd=//g"`
        mysql_user='backup'
    fi
    
    # test login with user backup or root
    while [ ${count} -le 3 ]     
    do
        /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -u $mysql_user -p${mysql_pass} -D mysql -e '' >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            npass=1
            break
        else
            mysql_user='root' 
            echo -n "MySQL user root password required:"
            stty -echo
            read mysql_pass
            stty echo
            echo ""
        fi
        count=`expr ${count} + 1`
    done

    if [ $npass -eq 0 ]
    then
        echo ""
        mecho --error "cannot connect MySQL server $VMAIL_SQL_HOST with user $mysql_user"
    else
        # check if database and user exists
        /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -u $mysql_user -p${mysql_pass} -D $VMAIL_SQL_DATABASE -e 'select id from view_users limit 1;' >/dev/null 2>&1
        if [ $? -ne 0 ]
        then
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -u $mysql_user -p${mysql_pass} -e "CREATE DATABASE $VMAIL_SQL_DATABASE DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
            npass=9
        fi
        count=`/usr/local/postfix/mysqlclient -N --silent -h $VMAIL_SQL_HOST -u $mysql_user -p${mysql_pass} -D $VMAIL_SQL_DATABASE -e 'select id from vmail_version limit 1;' 2>/dev/null`
        [ -z "$count" ] && count=0
        if [ $? -ne 0 -o $count -ne 8 ]
        then
            # create all tables, if not exists
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user -p${mysql_pass} < /usr/local/postfix/postfix-install-table.sql       
            
            # create all trigger, if MySQL support this (5.x) and not exists
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user -p${mysql_pass} < /usr/local/postfix/postfix-install-trigger.sql 2>/dev/null      

            # make all updates (alter table...)
            while read sqlcmd
            do
                echo "$sqlcmd" | grep -q '^#' && continue
                /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -u $mysql_user -p${mysql_pass} -D $VMAIL_SQL_DATABASE -e "$sqlcmd" 2>/dev/null
            done < /usr/local/postfix/postfix-install-update.sql
            # create all views
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user -p${mysql_pass} < /usr/local/postfix/postfix-install-view.sql
            # add default data for new database
            [ $npass -eq 9 ] && /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user -p${mysql_pass} < /usr/local/postfix/postfix-install-data.sql
        fi
    
        # force VMAIL_SQL_USER access
        if [ "$VMAIL_SQL_HOST" = "localhost" -o "$VMAIL_SQL_HOST" = "127.0.0.1" ]
        then
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D mysql -u $mysql_user -p${mysql_pass} -e \
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ${VMAIL_SQL_DATABASE}.* TO '${VMAIL_SQL_USER}'@'localhost' identified by '${VMAIL_SQL_PASS}'; flush privileges;"
        fi  
        if [ "$VMAIL_SQL_HOST" != "localhost"  ]
        then
            /usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -D mysql -u $mysql_user -p${mysql_pass} -e \
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ${VMAIL_SQL_DATABASE}.* TO '${VMAIL_SQL_USER}'@'%' identified by '${VMAIL_SQL_PASS}'; flush privileges;"
        fi
    fi
}

### -------------------------------------------------------------------------
### set start symlink
### -------------------------------------------------------------------------
set_init_link()
{
    if [ "$START_VMAIL" = 'yes' ]
    then
        ln -sf /etc/init.d/vmail /etc/rc2.d/S66vmail
    else
        rm -f /etc/rc2.d/S??vmail
    fi
}


### -------------------------------------------------------------------------
### update vmail modules menu for webmail
### -------------------------------------------------------------------------
# check if type ofthe menu is new
is_new_menutype()
{
    menu_name="$1"
    grep -E -q "^ *<package|<title|<\!--" /var/install/menu/$menu_name
}
#update
update_modules_menu()
{
    mail_module_menu_title="VMail Module administration"
    mail_module_menu_file='setup.services.vmail.modules.menu'

    # create new modules menu in >= base-1.1.0 format
    rm -f /var/install/menu/$mail_module_menu_file
    /var/install/bin/create-menu $mail_module_menu_file "$mail_module_menu_title"

    ls /var/install/menu/setup.services.mail.modules.*.menu > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        for FNAME in /var/install/menu/setup.services.mail.modules.*.menu
        do
            if is_new_menutype `basename $FNAME`
            then
                # new format - extract module name
                module_name=`basename $FNAME|cut -d. -f5`
                menu_title=`grep "<title>" $FNAME|sed -e 's/^<title> *//' -e 's/ *<\/title> *$//'`
            else
                # old format - extract module name
                module_name=`basename $FNAME|cut -d. -f4`
                # grep first line from module submenu
                menu_title=`sed -n '1p' $FNAME`
            fi
            echo "- adding menu entry \"$module_name - $menu_title\" ..."
            /var/install/bin/add-menu -menu "$mail_module_menu_file" "`basename $FNAME`" "$menu_title"
        done
    fi
}


### -------------------------------------------------------------------------
### get domain name
### -------------------------------------------------------------------------
get_domain_name()
{
    # read the password include special chars for admin user
    domain_name=`/usr/local/postfix/mysqlclient -h $VMAIL_SQL_HOST -u $VMAIL_SQL_USER -p${VMAIL_SQL_PASS} -D $VMAIL_SQL_DATABASE -s -e \
            "SELECT name FROM virtual_domains WHERE active='1' AND (transport LIKE 'pop3imap:%%') LIMIT 1;"`
    echo "$domain_name"
}


### -------------------------------------------------------------------------
### Main
### -------------------------------------------------------------------------
case "$1" in
    update)
        write_postfix_config
        write_milter_config
        update_sql_files
        if [ -e /var/lib/mysql/backup.pwd ] 
        then 
            sql_database_check
        else
            echo "" 
            echo " ----------------------------------------------------------"
            echo " Please start Vmail configuration for update MySQL tables! "
            echo " ----------------------------------------------------------"
            sleep 3
        fi
        set_init_link
        ;;
    updatemodulesmenu)
        update_modules_menu
        ;;
    getdomain)
        get_domain_name
        ;;
    alias)
        create_alias_file
        newaliases
        /etc/init.d/postfix reload
        ;;
    *)
        # check if exists mail cert
        if [ ! -f ${VMAIL_TLS_CERT} ]
        then
            logger -t 'postfix' "missing mail cert file ${VMAIL_TLS_CERT}"
            if [ "$POSTFIX_SMTP_TLS" = 'yes' ]
            then
                echo ""
                mecho --error "Mail certificate not found! Start without TLS services."
                mecho "Please create email cert with package Certs Service"
                echo ""
                POSTFIX_SMTP_TLS='no'
                POSTFIX_SMARTHOST_TLS='no'
                POP3IMAP_TLS='no'
            fi
        else
            if [ ! -f /etc/postfix/ssl/dh_512.pem ]
            then
                create_ssl_files
            fi
        fi
        sql_database_check
        echo -n "Update postfix "
        write_postfix_config
        write_milter_config
        update_sql_files
        echo "."
       # write_dovecot_config
        make_dracd_conf
        update_remote_port
        # fix permissions:
        create_fetchmail_file
        add_cron_job
        set_init_link
        ;;
esac


### -------------------------------------------------------------------------
exit 0
