#!/bin/sh
#------------------------------------------------------------------------------
# eisfair configuration update script
# Copyright 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#------------------------------------------------------------------------------

#set -x

#include eislib
. /var/install/include/eislib

### -------------------------------------------------------------------------
### internal parameter - not editable with ECE:
### -------------------------------------------------------------------------
VMAIL_TLS_CERT='/etc/ssl/certs/imapd.pem' # path to ssl cert
VMAIL_TLS_KEY='/etc/ssl/private/imapd.key'
VMAIL_TLS_CAPATH='/etc/ssl/certs'
# default values
POSTFIX_SMARTHOST='no'
POSTFIX_SMARTHOST_TLS='no'


### -------------------------------------------------------------------------
### check the password file and get the passwords
### -------------------------------------------------------------------------
# include config files base and vmail
. /etc/config.d/base
. /etc/config.d/vmail

### -------------------------------------------------------------------------
### write init.d config for start/stop postfix/dovecot
### -------------------------------------------------------------------------
cat > /etc/conf.d/vmail << EOF
START_VMAIL="$START_VMAIL"
START_POP3IMAP="$START_POP3IMAP"
EOF

### -------------------------------------------------------------------------
### set local values
### -------------------------------------------------------------------------
if [ "$VMAIL_SQL_HOST" = 'localhost' ]; then
    vmail_sql_connect="unix:/run/mysqld/mysqld.sock"
else
    vmail_sql_connect="$VMAIL_SQL_HOST"
fi

# login with completed mail address or username only
if [ "$VMAIL_LOGIN_WITH_MAILADDR" = "yes" ]; then
    dovecot_query="email"
    dovecot_authf="%Lu"
    dovecot_deliver="\${recipient}"
else
    dovecot_query="loginuser"
    dovecot_authf="%Ln"
    dovecot_deliver="\${user}"
fi


# get uid/gid for user vmail
uidvmail=$(id -u mail)
gidvmail=$(id -g mail)


### ----------------------------------------------------------------------------
### write new postfix config
### ----------------------------------------------------------------------------
write_postfix_config()
{
    local postfix_int_netw=""
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
    local postfix_tls="#"
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
    if [ "$POSTFIX_POSTSCREEN" = "yes" ]; then
        postfix_pscreen=""
        postfix_psmtpd="#"
    fi
    if [ "$POSTFIX_RBL" = "yes" ]; then
        count=1
        while [ ${count} -le ${POSTFIX_RBL_N} ]
        do
            eval temp1='$POSTFIX_RBL_'${count}'_SERVER'
            eval temp2='$POSTFIX_RBL_'${count}'_WEIGHT'
            postfix_pscr_dnsbl_action="enforce"
            [ -n "$temp2" ] && temp2="*${temp2}"
            postfix_rbl_list="$postfix_rbl_list ${temp1}${temp2}"
            [ ${POSTFIX_RBL_N} -gt ${count} ] && postfix_rbl_list="$postfix_rbl_list,"
            count=`expr ${count} + 1`
        done
    fi
    [ "$POSTFIX_SMTP_TLS" = 'yes' ] && postfix_tls=""
    [ "$POSTFIX_MIME_HEADER_CHECK" = 'yes' ] && postfix_mime_header_ch="pcre:/etc/postfix/mime_header_checks.pcre"
    [ "$POSTFIX_HEADER_N" -gt 0 ] && postfix_header_ch="pcre:/etc/postfix/header_checks.pcre"
    [ "$START_POP3IMAP" = 'yes' ] && postfix_sasl="permit_sasl_authenticated,"
    [ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts.cf"
    [ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts_auth="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts_auth.cf"

    postconf -e "queue_directory = /var/spool/postfix"
#    postconf -e "command_directory = /usr/sbin"
#    postconf -e "daemon_directory = /usr/sbin"
#    postconf -e "data_directory = /var/lib/postfix"
    postconf -e "mail_spool_directory = /var/spool/postfix"
    postconf -e "mail_owner = postfix"
    postconf -e "setgid_group = postdrop"
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
    postconf -e "pop3imap_destination_recipient_limit = 1"
    postconf -e "default_destination_recipient_limit = $POSTFIX_LIMIT_DESTINATIONS"

    postconf -e "proxy_read_maps = ${postfix_prxmynet}\$local_recipient_maps,\$mydestination,\$virtual_alias_maps,\$virtual_alias_domains,\$virtual_mailbox_maps,\$virtual_mailbox_domains,\$relay_recipient_maps,\$relay_domains,\$canonical_maps,\$sender_canonical_maps,\$recipient_canonical_maps,\$relocated_maps,\$transport_maps,\$mynetworks,\$mail_restrict_map,\$smtpd_recipient_restrictions,\$sender_dependent_relayhost_maps,\$smtp_sasl_password_maps,\$postscreen_access_list"
    postconf -e "transport_maps = proxy:mysql:/etc/postfix/sql/mysql-transport.cf"
    postconf -e "mail_restrict_map = proxy:mysql:/etc/postfix/sql/mysql-virtual_restrictions.cf"
    postconf -e "virtual_alias_maps = proxy:mysql:/etc/postfix/sql/mysql-virtual_aliases.cf,proxy:mysql:/etc/postfix/sql/mysql-virtual_email2email.cf"
    postconf -e "virtual_uid_maps = static:$uidvmail"
    postconf -e "virtual_gid_maps = static:$gidvmail"
    postconf -e "virtual_mailbox_domains = proxy:mysql:/etc/postfix/sql/mysql-virtual_domains.cf"
    postconf -e "virtual_mailbox_maps = proxy:mysql:/etc/postfix/sql/mysql-virtual_mailbox_maps.cf"
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
    postconf -e "smtpd_relay_restrictions = permit_mynetworks, ${postfix_sasl} permit_tls_clientcerts, defer_unauth_destination"
    postconf -e "smtpd_recipient_restrictions = reject_unlisted_recipient, \
 check_client_access proxy:mysql:/etc/postfix/sql/mysql-client_access.cf,\
 check_recipient_access proxy:mysql:/etc/postfix/sql/mysql-recipient_access.cf,\
 check_sender_access proxy:mysql:/etc/postfix/sql/mysql-sender_access.cf,\
 reject_invalid_helo_hostname,${postfix_cl_access_bl}${postfix_dyn_client_bl}\
 proxy:mysql:/etc/postfix/sql/mysql-virtual_restrictions.cf,\
 ${postfix_un_cl_hostname}${postfix_un_send_dom}${postfix_send_mx}${postfix_fqdn_helo} permit"

    postconf -e "mime_header_checks = $postfix_mime_header_ch"
    postconf -e "header_checks = $postfix_header_ch"

    postconf -e "mua_client_restrictions = permit_sasl_authenticated, permit"
    postconf -e "mua_helo_restrictions = permit"
    postconf -e "mua_sender_restrictions = permit"

    postconf -e "tls_random_source = dev:/dev/urandom"
    postconf -e "tls_random_prng_update_period = 3600s"
# SASL setup
    postconf -e "smtpd_sasl_type = dovecot"
    if [ "$START_POP3IMAP" = "yes" ]; then
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
    postconf -e "sender_canonical_maps = proxy:mysql:/etc/postfix/sql/mysql-canonical_maps.cf"
    postconf -e "sender_dependent_relayhost_maps = $postfix_relayhosts"

    postconf -e "smtpd_tls_auth_only = no"
    if [ "$POSTFIX_SMTP_TLS" = 'yes' ]; then
        if [ -e ${VMAIL_TLS_CAPATH}/cacert.pem ]; then
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
    if [ $POSTFIX_LOGLEVEL -gt 1 ]; then
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
    postconf -e "postscreen_access_list = permit_mynetworks, proxy:mysql:/etc/postfix/sql/mysql-client_access_postscreen.cf"

cat > /etc/postfix/master.cf <<EOF
# --------------------------------------------------------------------------
# Postfix master process configuration file by eisfair-ng config
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================
${postfix_psmtpd}smtp      inet  n       -       y       -       -       smtpd
${postfix_pscreen}smtp      inet  n       -       y       -       1       postscreen
${postfix_pscreen}smtpd     pass  -       -       y       -       -       smtpd
${postfix_pscreen}dnsblog   unix  -       -       y       -       0       dnsblog
${postfix_pscreen}tlsproxy  unix  -       -       y       -       0       tlsproxy
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=may
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=\$mua_client_restrictions
  -o smtpd_helo_restrictions=\$mua_helo_restrictions
  -o smtpd_sender_restrictions=\$mua_sender_restrictions
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
${postfix_tls}smtps     inet  n       -       y       -       -       smtpd
${postfix_tls}  -o syslog_name=postfix/smtps
${postfix_tls}  -o smtpd_tls_wrappermode=yes
${postfix_tls}  -o smtpd_sasl_auth_enable=yes
${postfix_tls}  -o smtpd_reject_unlisted_recipient=no
${postfix_tls}  -o smtpd_client_restrictions=\$mua_client_restrictions
${postfix_tls}  -o smtpd_helo_restrictions=\$mua_helo_restrictions
${postfix_tls}  -o smtpd_sender_restrictions=\$mua_sender_restrictions
${postfix_tls}  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
${postfix_tls}  -o milter_macro_daemon_name=ORIGINATING
#628       inet  n       -       n       -       -       qmqpd
pickup    unix  n       -       n       60      1       pickup
cleanup   unix  n       -       n       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
#qmgr     unix  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       n       1000?   1       tlsmgr
rewrite   unix  -       -       n       -       -       trivial-rewrite
bounce    unix  -       -       n       -       0       bounce
defer     unix  -       -       n       -       0       bounce
trace     unix  -       -       n       -       0       bounce
verify    unix  -       -       n       -       1       verify
flush     unix  n       -       n       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       n       -       -       smtp
relay     unix  -       -       n       -       -       smtp
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       n       -       -       showq
error     unix  -       -       n       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       n       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       n       -       -       lmtp
anvil     unix  -       -       n       -       1       anvil
scache    unix  -       -       n       -       1       scache
# ==========================================================================
# Interfaces to non-Postfix software
# ==========================================================================
pop3imap  unix  -       n       n       -       -       pipe
    flags=DRhu user=mail:mail argv=/usr/libexec/dovecot/dovecot-lda -d ${dovecot_deliver}
uucp      unix  -       n       n       -       -       pipe
    flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)

EOF
    # force permissions for chroot
#    chown    root:root   /var/spool/postfix/etc
#    chown -R root:root   /var/spool/postfix/lib
#    chown -R root:root   /var/spool/postfix/usr
#    chown    root:root   /var/spool/postfix/var
    mkdir -p /var/spool/postfix/virtual 
    chown -R ${uidvmail}:${gidvmail} /var/spool/postfix/virtual
#    chmod 0777           /var/spool/postfix/var/lib
#    chown postfix:root /var/spool/postfix
#    chown postfix:root /var/spool/postfix/pid
    /usr/sbin/postfix set-permissions >/dev/null 2>&1
}


### -------------------------------------------------------------------------
### change smc-milter.conf file
### -------------------------------------------------------------------------
write_milter_config()
{
    local connectport=0
    # check if installed clamav
    if [ ! -f /usr/sbin/clamd ]; then
        if [ "$POSTFIX_AV_CLAMAV" = 'yes' ]; then
            mecho --error "ClamAV not found. Set POSTFIX_AV_CLAMAV='no'"
            POSTFIX_AV_CLAMAV='no'
        fi
    fi
    [ "${VMAIL_SQL_HOST}" = "localhost" ] || connectport=3306
    sed -i -e "s|^clamcheck.*|clamcheck		${POSTFIX_AV_CLAMAV}|"               /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^fprotcheck.*|fprotcheck		${POSTFIX_AV_FPROTD}|"           /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^avmail.*|avmail			${POSTFIX_AV_VIRUS_INFO}|"           /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^signatureadd.*|signatureadd		${POSTFIX_AUTOSIGNATURE}|"   /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^dbhost.*|dbhost			${VMAIL_SQL_HOST}|"                  /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^dbport.*|dbport			${connectport}|"                     /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^dbname.*|dbname			${VMAIL_SQL_DATABASE}|"              /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^dbuser.*|dbuser			${VMAIL_SQL_USER}|"                  /etc/smc-milter-new/smc-milter-new.conf
    sed -i -e "s|^dbpass.*|dbpass			${VMAIL_SQL_PASS}|"                  /etc/smc-milter-new/smc-milter-new.conf
    if [ "$POSTFIX_AV_SCRIPT" = "yes" ]; then
        sed -i -e "s|.*scriptfile.*|scriptfile		${POSTFIX_AV_SCRIPTFILE}|"   /etc/smc-milter-new/smc-milter-new.conf
    else
        sed -i -e "s|^scriptfile.*|#scriptfile|"                                 /etc/smc-milter-new/smc-milter-new.conf
    fi
    [ -e /etc/smc-milter-new/smc-milter-new.hosts ] || touch /etc/smc-milter-new/smc-milter-new.hosts
    mkdir -p   /var/spool/postfix/quarantine
    chmod 0777 /var/spool/postfix/quarantine
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
        sed -i -e "s|^user.*|user = ${VMAIL_SQL_USER}|"         /etc/postfix/sql/$sqlfile
        sed -i -e "s|^password.*|password = ${VMAIL_SQL_PASS}|" /etc/postfix/sql/$sqlfile
        sed -i -e "s|^dbname.*|dbname = ${VMAIL_SQL_DATABASE}|" /etc/postfix/sql/$sqlfile
        sed -i -e "s|^hosts.*|hosts = ${vmail_sql_connect}|"    /etc/postfix/sql/$sqlfile
        chmod 0640 /etc/postfix/sql/$sqlfile
        chgrp postfix /etc/postfix/sql/$sqlfile
    done
    sed -i -e "s|^query.*|query = SELECT CONCAT(username,':',AES_DECRYPT(password, '${VMAIL_SQL_ENCRYPT_KEY}')) FROM view_relaylogin WHERE email like '%s'|" /etc/postfix/sql/mysql-virtual_relayhosts_auth.cf
}


### -------------------------------------------------------------------------
### update dovecot
### -------------------------------------------------------------------------
#10-auth
sed -i -r "s|^[#]?disable_plaintext_auth =.*|disable_plaintext_auth = no|" /etc/dovecot/conf.d/10-auth.conf
sed -i -r "s|^[#]?auth_username_format =.*|auth_username_format = ${dovecot_authf}|" /etc/dovecot/conf.d/10-auth.conf
sed -i -r "s|^[#]?auth_failure_delay =.*|auth_failure_delay = 2 secs|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^auth_mechanisms =.*|auth_mechanisms = plain login digest-md5 cram-md5|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-system.conf.ext.*|#!include auth-system.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^#!include auth-sql.conf.ext.*|!include auth-sql.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-ldap.conf.ext.*|#!include auth-ldap.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-passwdfile.conf.ext.*|#!include auth-passwdfile.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-checkpassword.conf.ext.*|#!include auth-checkpassword.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-vpopmail.conf.ext.*|#!include auth-vpopmail.conf.ext|" /etc/dovecot/conf.d/10-auth.conf
sed -i -e "s|^!include auth-static.conf.ext.*|#!include auth-static.conf.ext|" /etc/dovecot/conf.d/10-auth.conf

### -------------------------------------------------------------------------
#10-logging
if [ $POSTFIX_LOGLEVEL -gt 2 ]; then
    sed -i -r "s|^[#]mail_debug =.*|mail_debug = yes|" /etc/dovecot/conf.d/10-logging.conf
else
    sed -i -r "s|^[#]mail_debug =.*|#mail_debug = no|" /etc/dovecot/conf.d/10-logging.conf
fi
sed -i -r 's|^[#]log_timestamp =.*|log_timestamp = "%Y-%m-%d %H:%M:%S "|' /etc/dovecot/conf.d/10-logging.conf

### -------------------------------------------------------------------------
#10-mail
sed -i -r "s|^[#]mail_plugins =.*|mail_plugins = quota|" /etc/dovecot/conf.d/10-mail.conf
sed -i -r "s|^[#]first_valid_uid =.*|first_valid_uid = 8|" /etc/dovecot/conf.d/10-mail.conf
sed -i -r "s|^[#]first_valid_gid =.*|first_valid_gid = 12|" /etc/dovecot/conf.d/10-mail.conf

### -------------------------------------------------------------------------
#15-lda
sed -i -r "s|^[#]quota_full_tempfail =.*|quota_full_tempfail = yes|" /etc/dovecot/conf.d/15-lda.conf
sed -i -r "s|^[#]rejection_reason =.*|rejection_reason = Your message to <%t> was automatically rejected:%n%r|" /etc/dovecot/conf.d/15-lda.conf
sed -i -r "s|^[#]lda_mailbox_autocreate =.*|lda_mailbox_autocreate = yes|" /etc/dovecot/conf.d/15-lda.conf
sed -i -r "s|^[#]lda_mailbox_autosubscribe =.*|lda_mailbox_autosubscribe = yes|" /etc/dovecot/conf.d/15-lda.conf
sed -i -e "s|.*mail_plugins =.*|  mail_plugins = $mail_plugins sieve acl|" /etc/dovecot/conf.d/15-lda.conf

### -------------------------------------------------------------------------
#20-imap
sed -i -r "s|^[#]imap_client_workarounds =.*|imap_client_workarounds = tb-extra-mailbox-sep|" /etc/dovecot/conf.d/20-imap.conf
sed -i -e "s|.*mail_plugins =.*|  mail_plugins = $mail_plugins autocreate acl imap_acl|" /etc/dovecot/conf.d/20-imap.conf

### -------------------------------------------------------------------------
#20-pop3
sed -i -e "s|.*mail_plugins =.*|  mail_plugins = $mail_plugins autocreate acl|" /etc/dovecot/conf.d/20-pop3.conf

### -------------------------------------------------------------------------
# create SQL configuration
cat > /etc/dovecot/dovecot-sql.conf.ext <<EOF
driver = mysql
default_pass_scheme = PLAIN
# CRYPT or PLAIN
connect = host=$VMAIL_SQL_HOST dbname=$VMAIL_SQL_DATABASE user=$VMAIL_SQL_USER password=${VMAIL_SQL_PASS}
password_query = SELECT email as user, AES_DECRYPT(password, '${VMAIL_SQL_ENCRYPT_KEY}') as password FROM view_users WHERE $dovecot_query = '%u'
user_query = SELECT '/var/spool/postfix/virtual/%d/%n' AS home, $uidvmail as uid, $gidvmail as gid, concat('*:bytes=', quota, 'M') AS quota_rule FROM view_quota WHERE email = '%u'
iterate_query = SELECT email AS user FROM view_quota
EOF

chown dovecot:root /etc/dovecot/dovecot-sql.conf.ext
chmod 0640 /etc/dovecot/dovecot-sql.conf.ext

### -------------------------------------------------------------------------
# create dict configuration
cat > /etc/dovecot/dovecot-dict-sql.conf.ext <<EOF
connect = host=$VMAIL_SQL_HOST dbname=$VMAIL_SQL_DATABASE user=$VMAIL_SQL_USER password=${VMAIL_SQL_PASS}
# quota:
map {
  pattern = priv/quota/storage
  table = view_quota
  username_field = loginuser
  value_field = quota
}
# expires:
map {
  pattern = shared/expire/\$user/\$mailbox
  table = view_expire
  value_field = expirestamp

  fields {
    username = \$user
    mailbox = \$mailbox
  }
}
# shared folder:
map {
  pattern = shared/shared-boxes/user/\$to/\$from
  table = virtual_users_shares
  value_field = state

  fields {
    from_user = \$from
    to_user = \$to
  }
}
map {
  pattern = shared/shared-boxes/anyone/\$from
  table = virtual_users_shares
  value_field = state

  fields {
    from_user = \$from
  }
}
EOF

# hide for other
chown dovecot:root /etc/dovecot/dovecot-dict-sql.conf.ext
chmod 0640 /etc/dovecot/dovecot-dict-sql.conf.ext

### -------------------------------------------------------------------------
# write local configuration
cat > /etc/dovecot/local.conf <<EOF
# eisfair-ng config
protocols = imap pop3 sieve

mail_privileged_group = postdrop
mail_uid = mail
mail_gid = mail
mail_location = maildir:/var/spool/postfix/virtual/%d/%n/Maildir

userdb {
  args = uid=$uidvmail gid=$gidvmail home=/var/spool/postfix/virtual/%d/%n mail=maildir:/var/spool/postfix/virtual/%d/%n/Maildir
  driver = static
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    group = postfix
    mode = 0660
    user = postfix
  }
  unix_listener auth-master {
    mode = 0600
    user = vmail
  }
  user = root
}

plugin {
  acl_shared_dict = proxy::acl
  autocreate = Trash
  autocreate2 = Sent
  autocreate3 = Drafts
  autosubscribe = Trash
  autosubscribe2 = Sent
  autosubscribe3 = Drafts
}

dict {
  quota = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
  expire = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
  acl = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
}
EOF

#    sed -i -e "s|^ssl =.*|ssl = ${POP3IMAP_TLS}|" /etc/dovecot/dovecot.conf
#    sed -i -e "s|.*auth_username_format.*|${dovecot_authf} |" /etc/dovecot/dovecot.conf

    # secure doevecot sql password include files!
#    chown dovecot:vmail /etc/dovecot
#    chmod 0770 /etc/dovecot
#    chown dovecot:vmail /etc/dovecot/dovecot.conf
#    chmod 0640 /etc/dovecot/dovecot.conf



### -------------------------------------------------------------------------
### create ssl file
### -------------------------------------------------------------------------
create_ssl_files()
{
    # dovecot
#    mkdir -p /etc/ssl/dovecot
#    if [ ! -f /etc/ssl/dovecot/server.pem ]; then
#        cd /etc/ssl/dovecot
#        openssl genrsa 512/1024 > server.pem
#        openssl req -new -key server.pem -days 3650 -out request.pem  # You will get prompted for various information that is added the the file
#        openssl genrsa 2048 > server.key
#        openssl req -new -x509 -nodes -sha1 -days 3650 -key server.key > server.pem
#    fi


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


### --------------------------------------------------------------------------
### add cron job
### --------------------------------------------------------------------------
add_cron_job()
{
    mkdir -p /etc/cron/root
    echo "#59 23 * * * /var/install/bin/vmail-rejectlogfilter.sh" > /etc/cron/root/postfix
    [ "$START_POP3IMAP" = 'yes' ] && echo "00,30 * * * * /usr/bin/cui-vmail-maildropfilter.sh" >> /etc/cron/root/postfix
    [ "$START_FETCHMAIL" = "yes" ] && echo "$FETCHMAIL_CRON_SCHEDULE /var/install/bin/vmail-fetchmailstart.sh" >> /etc/cron/root/postfix
    # update crontab file
    /sbin/rc-service --quiet fcron reload
}


### -------------------------------------------------------------------------
### make fetchmail startfile
### -------------------------------------------------------------------------
create_fetchmail_file()
{
    logging="-s"
    [ "$FETCHMAIL_LOG" = "yes" ] && logging="--syslog"
    cat > /var/install/bin/vmail-fetchmailstart.sh <<EOF
#!/bin/sh
#------------------------------------------------------------------------------
. /etc/config.d/vmail
fetchfile=".fetchmailrc.\$$"
su mail -c "/usr/bin/mysql2fetchmail -t /var/spool/postfix/virtual/\${fetchfile} \
            -u \$VMAIL_SQL_USER -s \$VMAIL_SQL_HOST -d \$VMAIL_SQL_DATABASE -p \$VMAIL_SQL_PASS -e \$VMAIL_SQL_ENCRYPT_KEY; \\
            /usr/bin/fetchmail -t ${FETCHMAIL_TIMEOUT} -f /var/spool/postfix/virtual/\$fetchfile $logging --nobounce --sslcertpath $VMAIL_TLS_CAPATH --postmaster $FETCHMAIL_POSTMASTER 2>/dev/null ; \\
            rm -f /var/spool/postfix/virtual/\$fetchfile"
exit 0
EOF
    chmod 0700 /var/install/bin/vmail-fetchmailstart.sh
}


### -------------------------------------------------------------------------
### create new SQL database or change values
### -------------------------------------------------------------------------
sql_database_check()
{
    local count=1
    local npass=0
    local mysql_pass="-p"
    local mysql_user='root'

    # check if set password for MySQL admin user 'root' if exists
    if  [ -f /root/.my.cnf ]; then
#        mysql_pass=`grep password= /root/.my.cnf | sed "s/password=//g"`
        mysql_pass=""
        mysql_user='root'
    fi

    # test login with user backup or root
    while [ ${count} -le 3 ]
    do
        /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D mysql -e '' >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            npass=1
            break
        else
            mysql_user='root'
            mysql_pass=""
            echo -n "MySQL user root password required:"
            stty -echo
            read mysql_pass
            stty echo
            echo ""
            mysql_pass="-p$mysql_pass"
        fi
        count=`expr ${count} + 1`
    done

    if [ $npass -eq 0 ]; then
        echo ""
        mecho --error "cannot connect MySQL server $VMAIL_SQL_HOST with user $mysql_user"
    else
        # check if database and user exists
        /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D $VMAIL_SQL_DATABASE -e 'select id from view_users limit 1;' >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -e "CREATE DATABASE $VMAIL_SQL_DATABASE DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
            npass=9
        fi
        count=`/usr/bin/mysql -N --silent -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D $VMAIL_SQL_DATABASE -e 'select id from vmail_version limit 1;' 2>/dev/null`
        [ -z "$count" ] && count=0
        if [ $? -ne 0 -o $count -ne 8 ]; then
            # create all tables, if not exists
            /usr/bin/mysql -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user ${mysql_pass} < /etc/postfix/default/install-sqltable.sql

            # create all trigger, if MySQL support this (5.x) and not exists
            /usr/bin/mysql -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user ${mysql_pass} < /etc/postfix/default/install-sqltrigger.sql 2>/dev/null      

            # make all updates (alter table...)
            #while read sqlcmd
            #do
            #    echo "$sqlcmd" | grep -q '^#' && continue
            #    /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D $VMAIL_SQL_DATABASE -e "$sqlcmd" 2>/dev/null
            #done < /etc/postfix/default/install-sqlupdate.sql
            # create all views
            /usr/bin/mysql -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user ${mysql_pass} < /etc/postfix/default/install-sqlview.sql
            # add default data for new database
            [ $npass -eq 9 ] && /usr/bin/mysql -h $VMAIL_SQL_HOST -D $VMAIL_SQL_DATABASE -u $mysql_user ${mysql_pass} < /etc/postfix/default/install-sqldata.sql
        fi

        # force VMAIL_SQL_USER access
        if [ "$VMAIL_SQL_HOST" = "localhost" -o "$VMAIL_SQL_HOST" = "127.0.0.1" ]; then
            /usr/bin/mysql -h $VMAIL_SQL_HOST -D mysql -u $mysql_user ${mysql_pass} -e \
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ${VMAIL_SQL_DATABASE}.* TO '${VMAIL_SQL_USER}'@'localhost' identified by '${VMAIL_SQL_PASS}'; flush privileges;"
        fi
        if [ "$VMAIL_SQL_HOST" != "localhost"  ]; then
            /usr/bin/mysql -h $VMAIL_SQL_HOST -D mysql -u $mysql_user ${mysql_pass} -e \
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ${VMAIL_SQL_DATABASE}.* TO '${VMAIL_SQL_USER}'@'%' identified by '${VMAIL_SQL_PASS}'; flush privileges;"
        fi
    fi
}



### -------------------------------------------------------------------------
### Main
### -------------------------------------------------------------------------
case "$1" in
    update)
        write_postfix_config
        write_milter_config
        update_sql_files
        if [ -e /root/.my.cnf ]; then
            sql_database_check
        else
            echo ""
            echo " ----------------------------------------------------------"
            echo " Please start Vmail configuration for update MySQL tables! "
            echo " ----------------------------------------------------------"
            sleep 3
        fi
        ;;
    alias)
        create_alias_file
        newaliases
        /etc/init.d/postfix reload
        ;;
    *)
        # check if exists mail cert
        if [ ! -f ${VMAIL_TLS_CERT} ]; then
            logger -t 'postfix' "missing mail cert file ${VMAIL_TLS_CERT}"
            if [ "$POSTFIX_SMTP_TLS" = 'yes' ]; then
                echo ""
                mecho --error "Mail certificate not found! Start without TLS services."
                mecho "Please create email cert with package Certs Service"
                echo ""
                POSTFIX_SMTP_TLS='no'
                POSTFIX_SMARTHOST_TLS='no'
                POP3IMAP_TLS='no'
            fi
        else
            [ ! -f /etc/postfix/ssl/dh_512.pem ] && create_ssl_files
        fi
        sql_database_check
        echo -n "Update postfix "
        write_postfix_config
        write_milter_config
        update_sql_files
        echo "."
       # write_dovecot_config
        # fix permissions:
        create_fetchmail_file
        add_cron_job
        ;;
esac

### -------------------------------------------------------------------------
exit 0
