#!/bin/sh
#------------------------------------------------------------------------------
# eisfair configuration update script
# Copyright 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#------------------------------------------------------------------------------

### -------------------------------------------------------------------------
### internal parameter - not editable with ECE:
### -------------------------------------------------------------------------
VMAIL_TLS_CERT='/etc/ssl/certs/imapd.pem' # path to ssl cert
VMAIL_TLS_KEY='/etc/ssl/private/imapd.key'
VMAIL_TLS_CAPATH='/etc/ssl/certs'
VMAIL_TLS_KEYPATH="/etc/ssl/private"
# default values
POSTFIX_SMARTHOST='no'
POSTFIX_SMARTHOST_TLS='no'
pchr="y"           # use postfix changeroot
mysql_user="root"  # MySQL update user

### -------------------------------------------------------------------------
### check the password file and get the passwords
### -------------------------------------------------------------------------
# include config files base and vmail
. /etc/config.d/base
. /etc/config.d/vmail

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


### -------------------------------------------------------------------------
### create new SQL database or change values
### -------------------------------------------------------------------------
update_mysql_tables()
{
    local count=1
    local npass=1
    local mysql_pass="$1"

    # test login with user backup or root
    if [ "$mysql_pass" = "X" ]; then
        while [ ${count} -le 3 ]
        do
            mysql_pass=""
            echo -n "MySQL user root password required:"
            stty -echo
            read mysql_pass
            stty echo
            echo ""
            [ -n "$mysql_pass" ] && mysql_pass="-p$mysql_pass"
            /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D mysql -e '' >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                break
            else
                mysql_pass="X"
            fi
            count=`expr ${count} + 1`
        done
    fi
    if [ "$mysql_pass" = "X" ]; then
        echo ""
        echo " * cannot connect MySQL server $VMAIL_SQL_HOST with user $mysql_user"
        echo ""
        sleep 1
        return
    fi
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
}

### ----------------------------------------------------------------------------
### write new postfix config
### ----------------------------------------------------------------------------
postfix_int_netw=""
postfix_cl_access_bl=""
postfix_dyn_client_bl=""
postfix_un_cl_hostname=""
postfix_un_send_dom=""
postfix_send_mx=""
postfix_fqdn_helo=""
postfix_rbl_list=""
postfix_mime_header_ch=""
postfix_header_ch=""
postfix_sasl=""
postfix_relayhosts=""
postfix_relayhosts_auth=""
postfix_pscr_dnsbl_action="ignore"
postfix_pscreen="#"
postfix_psmtpd=""
postfix_tls="#"
postfix_prxmynet=""

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
        eval temp2='$POSTFIX_RBL_'${count}'_WEIGHT'
        if [ "$temp2" != "0" ]; then
            eval temp1='$POSTFIX_RBL_'${count}'_SERVER'
            postfix_pscr_dnsbl_action="enforce"
            [ -n "$temp2" ] && temp2="*${temp2}"
            postfix_rbl_list="$postfix_rbl_list ${temp1}${temp2}"
            [ ${POSTFIX_RBL_N} -gt ${count} ] && postfix_rbl_list="$postfix_rbl_list,"
        fi
        count=`expr ${count} + 1`
    done
fi
[ "$POSTFIX_SMTP_TLS" = 'yes' ] && postfix_tls=""
[ "$POSTFIX_MIME_HEADER_CHECK" = 'yes' ] && postfix_mime_header_ch="pcre:/etc/postfix/header_check_mime.pcre"
[ "$POSTFIX_HEADER_N" -gt 0 ] && postfix_header_ch="pcre:/etc/postfix/header_checks.pcre"
[ "$START_POP3IMAP" = 'yes' ] && postfix_sasl="permit_sasl_authenticated,"
[ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts.cf"
[ "$POSTFIX_SMARTHOST" = "yes" ] && postfix_relayhosts_auth="proxy:mysql:/etc/postfix/mysql-virtual_relayhosts_auth.cf"

postconf -e "queue_directory = /var/spool/postfix"
#postconf -e "command_directory = /usr/sbin"
#postconf -e "daemon_directory = /usr/sbin"
#postconf -e "data_directory = /var/lib/postfix"
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
echo -n "Update configuration ."
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
postconf -e "smtpd_recipient_restrictions = permit_mynetworks, ${postfix_sasl} reject_unlisted_recipient, \
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
    if [ -e ${VMAIL_TLS_CAPATH}/ca.pem ]; then
        postconf -e "smtpd_tls_CAfile = ${VMAIL_TLS_CAPATH}/ca.pem"
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
postconf -e "smtpd_tls_dh512_param_file       = /etc/postfix/ssl/dh_512.pem"
postconf -e "smtpd_tls_dh1024_param_file      = /etc/postfix/ssl/dh_2048.pem"

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
postconf -e "smtpd_milters = unix:/run/milter/smc-milter-new.sock"

# postscreen antispam setup
postconf -e "postscreen_greet_action = enforce"
# postconf -e "postscreen_hangup_action = drop"
postconf -e "postscreen_dnsbl_action = $postfix_pscr_dnsbl_action"
postconf -e "postscreen_dnsbl_sites = $postfix_rbl_list"
postconf -e "postscreen_dnsbl_threshold = 3"
postconf -e "postscreen_access_list = permit_mynetworks, proxy:mysql:/etc/postfix/sql/mysql-client_access_postscreen.cf"
echo -n "."
cat > /etc/postfix/master.cf <<EOF
# --------------------------------------------------------------------------
# Postfix master process configuration file by eisfair-ng config
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================
${postfix_psmtpd}smtp      inet  n       -       $pchr       -       -       smtpd
${postfix_pscreen}smtp      inet  n       -       $pchr       -       1       postscreen
${postfix_pscreen}smtpd     pass  -       -       $pchr       -       -       smtpd
${postfix_pscreen}dnsblog   unix  -       -       $pchr       -       0       dnsblog
${postfix_pscreen}tlsproxy  unix  -       -       $pchr       -       0       tlsproxy
submission inet n       -       $pchr       -       -       smtpd
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
pickup    unix  n       -       $pchr       60      1       pickup
cleanup   unix  n       -       $pchr       -       0       cleanup
qmgr      unix  n       -       $pchr       300     1       qmgr
#qmgr     unix  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       $pchr       1000?   1       tlsmgr
rewrite   unix  -       -       $pchr       -       -       trivial-rewrite
bounce    unix  -       -       $pchr       -       0       bounce
defer     unix  -       -       $pchr       -       0       bounce
trace     unix  -       -       $pchr       -       0       bounce
verify    unix  -       -       $pchr       -       1       verify
flush     unix  n       -       $pchr       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       $pchr       -       -       smtp
relay     unix  -       -       $pchr       -       -       smtp
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       $pchr       -       -       showq
error     unix  -       -       $pchr       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       $pchr       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       $pchr       -       -       lmtp
anvil     unix  -       -       $pchr       -       1       anvil
scache    unix  -       -       $pchr       -       1       scache
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
echo -n "."

### -------------------------------------------------------------------------
### change smc-milter.conf file
### -------------------------------------------------------------------------
# check if installed clamav
if [ ! -f /usr/sbin/clamd ]; then
    if [ "$POSTFIX_AV_CLAMAV" = 'yes' ]; then
        echo " * ClamAV not found. Set POSTFIX_AV_CLAMAV='no'"
        POSTFIX_AV_CLAMAV='no'
    fi
fi
connectport=0
[ "${VMAIL_SQL_HOST}" = "localhost" ] || connectport=3306
sed -i -e "s|^clamcheck.*|clamcheck			${POSTFIX_AV_CLAMAV}|"       /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^fprotcheck.*|fprotcheck		${POSTFIX_AV_FPROTD}|"       /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^avmail.*|avmail			${POSTFIX_AV_VIRUS_INFO}|"   /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^signatureadd.*|signatureadd		${POSTFIX_AUTOSIGNATURE}|"   /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^dbhost.*|dbhost			${VMAIL_SQL_HOST}|"          /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^dbport.*|dbport			${connectport}|"             /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^dbname.*|dbname			${VMAIL_SQL_DATABASE}|"      /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^dbuser.*|dbuser			${VMAIL_SQL_USER}|"          /etc/smc-milter-new/smc-milter-new.conf
sed -i -e "s|^dbpass.*|dbpass			${VMAIL_SQL_PASS}|"          /etc/smc-milter-new/smc-milter-new.conf
if [ "$POSTFIX_AV_SCRIPT" = "yes" ]; then
    sed -i -e "s|.*scriptfile.*|scriptfile		${POSTFIX_AV_SCRIPTFILE}|"   /etc/smc-milter-new/smc-milter-new.conf
else
    sed -i -e "s|^scriptfile.*|#scriptfile|"                                     /etc/smc-milter-new/smc-milter-new.conf
fi
[ -e /etc/smc-milter-new/smc-milter-new.hosts ] || touch /etc/smc-milter-new/smc-milter-new.hosts
mkdir -p   /var/spool/postfix/quarantine
chmod 0777 /var/spool/postfix/quarantine


### ----------------------------------------------------------------------------
### update sql query files for postfix and dovecot
### ----------------------------------------------------------------------------
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
chmod 0750 /etc/postfix/sql
chgrp postfix /etc/postfix/sql
sed -i -e "s|^query.*|query = SELECT CONCAT(username,':',AES_DECRYPT(password, '${VMAIL_SQL_ENCRYPT_KEY}')) FROM view_relaylogin WHERE email like '%s'|" /etc/postfix/sql/mysql-virtual_relayhosts_auth.cf

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
sed -i -r "s|^[#]syslog_facility =.*|syslog_facility = auth|" /etc/dovecot/conf.d/10-logging.conf
if [ $POSTFIX_LOGLEVEL -gt 2 ]; then
    sed -i -r "s|^[#]mail_debug =.*|mail_debug = yes|" /etc/dovecot/conf.d/10-logging.conf
else
    sed -i -r "s|^[#]mail_debug =.*|#mail_debug = no|" /etc/dovecot/conf.d/10-logging.conf
fi
sed -i -r 's|^[#]log_timestamp =.*|log_timestamp = "%Y-%m-%d %H:%M:%S "|' /etc/dovecot/conf.d/10-logging.conf

### -------------------------------------------------------------------------
#10-mail
cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
## Mailbox locations and namespaces
mail_location = maildir:/var/spool/postfix/virtual/%d/%n/Maildir
namespace inbox {
  type = private
  separator = /
  #prefix =
  inbox = yes
  hidden = no
  list = yes
  subscriptions = yes
}
namespace {
  type = shared
  separator = /
  prefix = shared/%%u/
  location = maildir:/var/spool/postfix/virtual/%%d/%%n/Maildir:INDEX=~/Maildir/shared/%%u
  subscriptions = no
  list = children
}
#mail_shared_explicit_inbox = no
mail_uid = mail
mail_gid = mail
#mail_access_groups =
#mail_full_filesystem_access = no
#mail_attribute_dict =

## Mail processes
#mmap_disable = no
#dotlock_use_excl = yes
#mail_fsync = optimized
#mail_nfs_storage = no
# Mail index files also exist in NFS. Setting this to yes requires
# mmap_disable=yes and fsync_disable=no.
#mail_nfs_index = no
#lock_method = fcntl
#mail_temp_dir = /tmp
first_valid_uid = 8
#last_valid_uid = 0
first_valid_gid = 12
#last_valid_gid = 0
#mail_max_keyword_length = 50
#valid_chroot_dirs =
#mail_chroot =
#auth_socket_path = /var/run/dovecot/auth-userdb
#mail_plugin_dir = /usr/lib/dovecot
mail_plugins = quota fts fts_squat

## Mailbox handling optimizations
#mailbox_list_index = no
#mail_cache_min_mail_count = 0
#mailbox_idle_check_interval = 30 secs
#mail_save_crlf = no
#mail_prefetch_count = 0
#mail_temp_scan_interval = 1w

## Maildir-specific settings
#maildir_stat_dirs = no
#maildir_copy_with_hardlinks = yes
#maildir_very_dirty_syncs = no
#maildir_broken_filename_sizes = no
EOF

### -------------------------------------------------------------------------
#10-ssl
cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
## SSL settings
ssl = $POSTFIX_SMTP_TLS
ssl_cert = <$VMAIL_TLS_CERT
ssl_key = <$VMAIL_TLS_KEY
#ssl_key_password =
ssl_ca = <${VMAIL_TLS_CAPATH}/ca.pem
#ssl_require_crl = yes
ssl_client_ca_dir = $VMAIL_TLS_CAPATH
#ssl_client_ca_file =
#ssl_verify_client_cert = no
#ssl_cert_username_field = commonName
#ssl_dh_parameters_length = 1024
#ssl_protocols = !SSLv2
#ssl_cipher_list = ALL:!LOW:!SSLv2:!EXP:!aNULL
#ssl_prefer_server_ciphers = no
#ssl_crypto_device =
EOF

### -------------------------------------------------------------------------
#15-lda
cat > /etc/dovecot/conf.d/15-lda.conf <<EOF
## LDA specific settings (also used by LMTP)
#postmaster_address =
#hostname =
quota_full_tempfail = yes
#sendmail_path = /usr/sbin/sendmail
#submission_host =
#rejection_subject = Rejected: %s
rejection_reason = Your message to <%t> was automatically rejected:%n%r
#recipient_delimiter = +
#lda_original_recipient_header =
lda_mailbox_autocreate = yes
lda_mailbox_autosubscribe = yes
protocol lda {
  # Space separated list of plugins to load (default is global mail_plugins).
  mail_plugins =  \$mail_plugins sieve acl
}
EOF

### -------------------------------------------------------------------------
#15-mailboxes
cat > /etc/dovecot/conf.d/15-mailboxes.conf <<EOF
## Mailbox definitions
namespace inbox {
  # These mailboxes are widely used and could perhaps be created automatically:
  mailbox Drafts {
    auto = create
    special_use = \Drafts
  }
  mailbox Trash {
    auto = create
    special_use = \Trash
  }
  mailbox Sent {
    auto = subscribe
    special_use = \Sent
  }
  mailbox "Sent Messages" {
    special_use = \Sent
  }
  mailbox Archives {
    auto = subscribe
  }
}
EOF

### -------------------------------------------------------------------------
#20-imap
sed -i -r "s|^[#]imap_client_workarounds =.*|imap_client_workarounds = tb-extra-mailbox-sep|" /etc/dovecot/conf.d/20-imap.conf
sed -i -e "s|.*mail_plugins =.*|  mail_plugins = \$mail_plugins acl imap_acl|" /etc/dovecot/conf.d/20-imap.conf

### -------------------------------------------------------------------------
#20-pop3
sed -i -e "s|.*mail_plugins =.*|  mail_plugins = \$mail_plugins autocreate acl|" /etc/dovecot/conf.d/20-pop3.conf

### -------------------------------------------------------------------------
#90-acl.conf
cat > /etc/dovecot/conf.d/90-acl.conf <<EOF
## Mailbox access control lists.
plugin {
  acl = vfile
  acl_shared_dict = proxy::acl
}
EOF

### -------------------------------------------------------------------------
#90-plugin.conf
cat > /etc/dovecot/conf.d/90-plugin.conf <<EOF
## Plugin settings
plugin {
  fts = squat
  fts_squat = partial=4 full=10
  fts_autoindex = yes
}
EOF

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
base_dir = /run/dovecot

protocols = imap pop3 sieve

mail_privileged_group = postdrop

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
    user = dovecot
  }
  user = root
}

service dict {
  # For example: mode=0660, group=vmail and global mail_access_groups=vmail
  unix_listener dict {
    mode = 0660
    user = mail
    #group =
  }
}

dict {
  quota = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
  expire = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
  acl = mysql:/etc/dovecot/dovecot-dict-sql.conf.ext
}
EOF

echo "."
#    sed -i -e "s|^ssl =.*|ssl = ${POP3IMAP_TLS}|" /etc/dovecot/dovecot.conf
#    sed -i -e "s|.*auth_username_format.*|${dovecot_authf} |" /etc/dovecot/dovecot.conf

# secure doevecot sql password include files!
#    chown dovecot:vmail /etc/dovecot
#    chmod 0770 /etc/dovecot
#    chown dovecot:vmail /etc/dovecot/dovecot.conf
#    chmod 0640 /etc/dovecot/dovecot.conf


### -------------------------------------------------------------------------
### create ssl cert file
### -------------------------------------------------------------------------
mkdir -p $VMAIL_TLS_CAPATH
mkdir -p $VMAIL_TLS_KEYPATH

# create ca if missing!
if [ ! -f "$VMAIL_TLS_CAPATH/ca.pem" -a "$POSTFIX_SMTP_TLS" = "yes" ]; then
    echo ""
    echo "Create CA"
    echo "----------------------------------------------------------------------"
    openssl genrsa -out $VMAIL_TLS_KEYPATH/ca.key 4096
    chmod 0600 $VMAIL_TLS_KEYPATH/ca.key
    openssl req -new -x509 -days 3650 -key $VMAIL_TLS_KEYPATH/ca.key -out $VMAIL_TLS_CAPATH/ca.pem
fi

# create imap server cert if not exists
if [ ! -f "$VMAIL_TLS_CERT" ]; then
    echo ""
    echo "Create server TLS cert"
    echo "----------------------------------------------------------------------"
    # configuration for current server
    certdn=$(hostname -d)
    certfn=$(hostname -f)
    cat > /etc/dovecot/dovecot-openssl.cnf <<EOF
[ req ]
default_bits = 2048
encrypt_key = yes
distinguished_name = req_dn
x509_extensions = cert_type
prompt = no
[ req_dn ]
# country (2 letter code)
C=DE
# State or Province Name (full name)
#ST=Thueringen
# Locality Name (eg. city)
#L=Weimar
# Organization (eg. company)
O=$certdn
# Organizational Unit Name (eg. section)
OU=mail-server
# Common Name (*.example.com is also possible)
CN=$certfn
# E-mail contact
emailAddress=postmaster@$certdn
[ cert_type ]
nsCertType = server
EOF
    chmod 0644 /etc/dovecot/dovecot-openssl.cnf
    openssl genrsa -out $VMAIL_TLS_KEY 2048
    chmod 0600 $VMAIL_TLS_KEY
    openssl req -new -x509 -nodes -sha1 -days 3650 -config /etc/dovecot/dovecot-openssl.cnf -key $VMAIL_TLS_KEY -out $VMAIL_TLS_CERT
    #openssl x509 -subject -fingerprint -noout -in $VMAIL_TLS_CERT
fi

# EECDH Server support
mkdir -p /etc/postfix/ssl
[ -f /etc/postfix/ssl/dh_512.pem ]  || openssl gendh -out /etc/postfix/ssl/dh_512.pem -2 512
[ -f /etc/postfix/ssl/dh_1024.pem ] || openssl gendh -out /etc/postfix/ssl/dh_1024.pem -2 1024
[ -f /etc/postfix/ssl/dh_2048.pem ] || openssl gendh -out /etc/postfix/ssl/dh_2048.pem -2 2048

### --------------------------------------------------------------------------
### add cron job
### --------------------------------------------------------------------------
mkdir -p /etc/cron/root
echo "#59 23 * * * /var/install/bin/vmail-rejectlogfilter.sh" > /etc/cron/root/postfix
[ "$START_POP3IMAP" = 'yes' ] && echo "00,30 * * * * /usr/bin/cui-vmail-maildropfilter.sh" >> /etc/cron/root/postfix
[ "$START_FETCHMAIL" = "yes" ] && echo "$FETCHMAIL_CRON_SCHEDULE /usr/bin/cui-vmail-fetchmailstart.sh" >> /etc/cron/root/postfix

### --------------------------------------------------------------------------
### run automatic mysql update if password available
### --------------------------------------------------------------------------
if [ -f /root/.my.cnf ]; then
    mysql_pass=$(grep -m1 'password=' /root/.my.cnf | sed "s/password=//")
    [ -n "$mysql_pass" ] && mysql_pass="-p${mysql_pass}"
    /usr/bin/mysql -h $VMAIL_SQL_HOST -u $mysql_user ${mysql_pass} -D mysql -e '' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        update_mysql_tables "$mysql_pass"
    else
        [ "$1" = "update" ] || update_mysql_tables "X"
    fi
else
    [ "$1" = "update" ] || update_mysql_tables "X"
fi


### -------------------------------------------------------------------------
### setup runlevel - not with init.d/vmail!
### -------------------------------------------------------------------------
# update crontab file
/sbin/rc-service --quiet fcron reload
if [ "$START_VMAIL" = "yes" ]; then
    [ "$START_POP3IMAP" = 'yes' ] && /sbin/rc-update -q add dovecot 2>/dev/null || /sbin/rc-update -q del dovecot
    /sbin/rc-update -q add smc-milter-new 2>/dev/null
    [ -x /etc/init.d/greylist ] && /sbin/rc-update -q add greylist 2>/dev/null
    /sbin/rc-update -q add postfix 2>/dev/null
#    [ "$START_FETCHMAIL" = "yes" ] && /sbin/rc-update -q add fetchmail 2>/dev/null || /sbin/rc-update -q del fetchmail
    # add chroot
    if [ "$pchr" = "y" ]; then
        /sbin/rc-update -q add postfixchroot 2>/dev/null
        /sbin/rc-service -q postfixchroot start 2>/dev/null
    fi
else
    /sbin/rc-update -q del dovecot
    /sbin/rc-update -q del smc-milter-new
    [ -x /etc/init.d/greylist ] && /sbin/rc-update -q del greylist
    /sbin/rc-update -q del postfix
#    /sbin/rc-update -q del fetchmail
fi


### -------------------------------------------------------------------------
exit 0
