#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/config.d/postfix-update.sh - postfix parameter update script
#
# Creation:     2005-04-14 Jens Vehlhaber <jens(at)eisfair(dot)org>
# Last Update:  $Id: vmail-update.sh 31284 2012-07-18 09:42:24Z jv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#------------------------------------------------------------------------------

# include configlib
. /var/install/include/configlib

# include config files base
. /etc/config.d/base

packages_name='vmail'

### ---------------------------------------------------------------------------
### Set the default values for configuration
### ---------------------------------------------------------------------------
START_VMAIL="no"

VMAIL_SQL_HOST="localhost"
VMAIL_SQL_USER="vmailprovider"
VMAIL_SQL_PASS="${RANDOM}a${RANDOM}b${RANDOM}"
VMAIL_SQL_DATABASE="vmaildata"
VMAIL_SQL_ENCRYPT_KEY="${RANDOM}c${RANDOM}d${RANDOM}"

VMAIL_LOGIN_WITH_MAILADDR="no"

VMAIL_TLS_CERT='/usr/local/ssl/certs/imapd.pem' # path to default ssl cert

START_POSTFIX="yes"

POSTFIX_SMTP_TLS='no'
POSTFIX_HELO_HOSTNAME="${HOSTNAME}.${DOMAIN_NAME}"

POSTFIX_LIMIT_DESTINATIONS="100"
POSTFIX_LIMIT_MAILSIZE="20"

POSTFIX_REJECT_UNKN_CLIENT='no'
POSTFIX_REJECT_UNKN_SEND_DOM='yes'
POSTFIX_REJECT_NON_FQDN_HOST='no'
POSTFIX_REJECT_DYNADDRESS='no'
POSTFIX_REJECT_BOGUS_MX='yes'
POSTFIX_MIME_HEADER_CHECK='yes'
POSTFIX_POSTSCREEN='yes'

POSTFIX_RBL="yes"
POSTFIX_RBL_N="7"
POSTFIX_RBL_1_SERVER='ix.dnsbl.manitu.net'
POSTFIX_RBL_1_WEIGHT='3'
POSTFIX_RBL_2_SERVER='zen.spamhaus.org'
POSTFIX_RBL_2_WEIGHT='1'
POSTFIX_RBL_3_SERVER='dnsbl.inps.de'
POSTFIX_RBL_3_WEIGHT='1'  
POSTFIX_RBL_4_SERVER='dnsbl-1.uceprotect.net'
POSTFIX_RBL_4_WEIGHT='1'
POSTFIX_RBL_5_SERVER='dnsbl-2.uceprotect.net'
POSTFIX_RBL_5_WEIGHT='1'
POSTFIX_RBL_6_SERVER='dnsbl-3.uceprotect.net'
POSTFIX_RBL_6_WEIGHT='1'
POSTFIX_RBL_7_SERVER='b.barracudacentral.org'
POSTFIX_RBL_7_WEIGHT='1'

POSTFIX_HEADER_N='0'
POSTFIX_HEADER_1_CHECK='^Date:.*[+-](1[4-9]|2\d)\d\d$'
POSTFIX_HEADER_1_HANDL='REJECT invalid timezone'
POSTFIX_HEADER_2_CHECK='^(To|From):\s*$'
POSTFIX_HEADER_2_HANDL='REJECT empty To or From header'

POSTFIX_CLIENT_N='0'
POSTFIX_CLIENT_1_CHECK='host[0-9]{1,3}\..*\.org'
POSTFIX_CLIENT_1_HANDL='550 No HOST. Use an authorized relay'

# if clamd installed?
if [ -f /usr/sbin/clamd ]
then
    POSTFIX_AV_CLAMAV='yes'
else
    POSTFIX_AV_CLAMAV='no'
fi

POSTFIX_AV_FPROTD='no'

POSTFIX_AV_SCRIPT='no'
POSTFIX_AV_SCRIPTFILE='/usr/local/postfix/smc-unzip.sh'

POSTFIX_AV_VIRUS_INFO='root@localhost'
POSTFIX_AV_QUARANTINE='yes'

POSTFIX_DRACD="no"                   # Start dracd Service
#POSTFIX_DRACD_RELAYTIME="30"          # The TTL of per IP open relay in minutes

# ---- get networks from base: ------------------------
count=1
rlcnt=0
while [ ${count} -le $IP_NET_N ]
do
    eval intern_ip='$IP_NET_'${count}'_IPADDR'
    eval intern_msk='$IP_NET_'${count}'_NETMASK'
    intern_netwrk=`netcalc network ${intern_ip}:${intern_msk}`
    intern_netmsk=`netcalc netmaskbits ${intern_ip}:${intern_msk}`
    # exlude localnet used from OpenVZ
    if [ "$intern_ip" != "127.0.0.1" ]
    then
        rlcnt=`expr $rlcnt + 1`
        eval POSTFIX_RELAY_FROM_NET_${rlcnt}="${intern_netwrk}/${intern_netmsk}"
    fi 
    count=`expr $count + 1`
done
POSTFIX_RELAY_FROM_NET_N="$rlcnt"

POSTFIX_AUTOSIGNATURE="no"

POSTFIX_SMARTHOST="no"
POSTFIX_SMARTHOST_TLS="no"

POSTFIX_ALTERNATE_SMTP_PORT="0"
POSTFIX_QUEUE_LIFETIME='5'

# pop3/imap
START_POP3IMAP='yes'
POP3IMAP_TLS='no'

# fetchmail
START_FETCHMAIL="no"
FETCHMAIL_CRON_SCHEDULE='5,35 * * * *'
FETCHMAIL_TIMEOUT='60'
FETCHMAIL_POSTMASTER='postmaster'

POSTFIX_LOGLEVEL="0"
FETCHMAIL_LOG='no'

# not editable
VMAIL_TLS_CERT='/usr/local/ssl/certs/imapd.pem' # path to ssl cert

# set default count variables
postfix_rbl_count="$POSTFIX_RBL_N"
postfix_header_count="$POSTFIX_HEADER_N"
postfix_client_count="$POSTFIX_CLIENT_N"

### ---------------------------------------------------------------------------
### rename old variables
### ---------------------------------------------------------------------------
rename_old_variables ()
{
    # read old values
    if [ -f /etc/config.d/$packages_name ]
    then
        . /etc/config.d/$packages_name
    fi

    # set default count values from config.d file
    postfix_rbl_count="$POSTFIX_RBL_N"
    postfix_header_count="$POSTFIX_HEADER_N"
    postfix_client_count="$POSTFIX_CLIENT_N"

    # found hidden RBL server configurations > POSTFIX_RBL_N
    count=`expr ${POSTFIX_RBL_N} + 1`
    while [ ${count} -le 10 ]
    do
         eval temp='$POSTFIX_RBL_'${count}'_SERVER'
         if [ -n "$temp" ]
         then
             postfix_rbl_count="${count}"
         else
             break
         fi
         count=`expr ${count} + 1`
    done
    # found hidden client access configurations > POSTFIX_HEADER_N
    count=`expr ${POSTFIX_HEADER_N} + 1`
    while [ ${count} -le 30 ]
    do
         eval temp='$POSTFIX_HEADER_'${count}'_CHECK'
         if [ -n "$temp" ]
         then
             postfix_header_count="${count}"
         else
             break
         fi
         count=`expr ${count} + 1`
    done
    # found hidden client access configurations > POSTFIX_CLIENT_N
    count=`expr ${POSTFIX_CLIENT_N} + 1`
    while [ ${count} -le 30 ]
    do
         eval temp='$POSTFIX_CLIENT_'${count}'_CHECK'
         if [ -n "$temp" ]
         then
             postfix_client_count="${count}"
         else
             break
         fi
         count=`expr ${count} + 1`
    done
}


### ---------------------------------------------------------------------------
### Write config and default files
### ---------------------------------------------------------------------------
make_config_file ()
{
    internal_conf_file=$1
    {
    #-----------------------------------------------------------------------
    printgpl -conf "$packages_name" "2005-04-14" "jv" "Jens Vehlhaber"
    #-----------------------------------------------------------------------
    printgroup "VMail settings"
    #-----------------------------------------------------------------------

    printvar "START_VMAIL" "Use VMail service"

    printvar "VMAIL_SQL_HOST" "MySQL host. (localhost or IP)"
    printvar "VMAIL_SQL_USER" "MySQL user name"
    printvar "VMAIL_SQL_PASS" "MySQL connet password"
    printvar "VMAIL_SQL_DATABASE" "MySQL database name"
    printvar "VMAIL_SQL_ENCRYPT_KEY" "Password encryption key"

    printvar "VMAIL_LOGIN_WITH_MAILADDR" "login with completed mail address or username only"


    #-----------------------------------------------------------------------
    printgroup "SMTP Postfix general settings"
    #-----------------------------------------------------------------------

    printvar "START_POSTFIX" "postfix start 'yes' or 'no'"
    printvar "POSTFIX_SMTP_TLS" "use STARTTLS or SMTP over SSL"
    printvar "POSTFIX_HELO_HOSTNAME" "use alternate external host name"
    printvar "POSTFIX_AUTOSIGNATURE" "write automatic signature to all mail"
    printvar "POSTFIX_ALTERNATE_SMTP_PORT" "use additional SMTP port > 25"
    printvar "POSTFIX_QUEUE_LIFETIME" "change default queue lifetime"
    printvar "POSTFIX_DRACD" "Dynamic Relay Authorization (POP before SMTP)"
#    printvar "POSTFIX_DRACD_RELAYTIME" "The Lifetime of per IP open relay in minutes"
    printvar "POSTFIX_RELAY_FROM_NET_N" "Count of internal networks"
    count=1
    while [ ${count} -le ${POSTFIX_RELAY_FROM_NET_N} ]
    do
         printvar "POSTFIX_RELAY_FROM_NET_${count}" "NETWORK/NETMASK 172.16.0.0/16"
         count=`expr ${count} + 1`
    done

    printvar "POSTFIX_SMARTHOST" "send all e-mails to external e-mail server"
#    printvar "POSTFIX_SMARTHOST_TLS" "set TLS"

    printvar "POSTFIX_LIMIT_DESTINATIONS" "Max count of destination recipients"
    printvar "POSTFIX_LIMIT_MAILSIZE"     "Max size of e-mail message (default 20MB)"

    #-----------------------------------------------------------------------
    printgroup "SMTP Postfix antispam settings"
    #-----------------------------------------------------------------------

    printvar "POSTFIX_REJECT_UNKN_CLIENT" "reject not dns based hostnames"
    printvar "POSTFIX_REJECT_UNKN_SEND_DOM" "Reject unknown sender domain"
    printvar "POSTFIX_REJECT_NON_FQDN_HOST" "Reject non full qualif. hostname"
    printvar "POSTFIX_REJECT_DYNADDRESS" "Block all sender with pppoe, dialin etc. names"
    printvar "POSTFIX_REJECT_BOGUS_MX" "Block faked DNS entries"
    printvar "POSTFIX_MIME_HEADER_CHECK" "Block all exe,com,vba... files"
    printvar "POSTFIX_POSTSCREEN" "Use Postscreen antispam preegreeting"

    printvar "POSTFIX_RBL" "Use Realtime Blackhole List"
    printvar "POSTFIX_RBL_N" "Count of Realtime Blackhole List server"
    count=1
    while [ ${count} -le ${postfix_rbl_count} ]
    do
        printvar "POSTFIX_RBL_${count}_SERVER" "Realtime Blackhole List server $count name"
        printvar "POSTFIX_RBL_${count}_WEIGHT" "Blackhole server $count blocking weight"
        count=`expr ${count} + 1`
    done

    printvar "POSTFIX_HEADER_N" "Count of header checks"
    count=1
    while [ ${count} -le ${postfix_header_count} ]
    do
        printvar "POSTFIX_HEADER_${count}_CHECK" "PCRE check string"
        printvar "POSTFIX_HEADER_${count}_HANDL" "handling: REJECT, IGNORE + logstring"
        count=`expr ${count} + 1`
    done
    printvar "POSTFIX_CLIENT_N" "Count of checked email clients"
    count=1
    while [ ${count} -le ${postfix_client_count} ]
    do
        printvar "POSTFIX_CLIENT_${count}_CHECK" "PCRE check string"
        printvar "POSTFIX_CLIENT_${count}_HANDL" "handling: REJECT, IGNORE + logstring"
        count=`expr ${count} + 1`
    done

    #-----------------------------------------------------------------------
    printgroup "Antivirus settings"
    #-----------------------------------------------------------------------

    printvar "POSTFIX_AV_CLAMAV" "Use ClamAV antivirus scanner"
    printvar "POSTFIX_AV_FPROTD" "Use F-Prot daemon antivirus scanner"
    printvar "POSTFIX_AV_SCRIPT" "Use scripfile"
    printvar "POSTFIX_AV_SCRIPTFILE" "Name of scriptfile (/usr/local/postfix/smc-unzip.sh)"
    printvar "POSTFIX_AV_VIRUS_INFO" "Send virus warn message to e-mail recipient"
    printvar "POSTFIX_AV_QUARANTINE" "Store the original virus to the quarantain"


    #-----------------------------------------------------------------------
    printgroup "POP3/IMAP settings"
    #-----------------------------------------------------------------------

    printvar "START_POP3IMAP" "Start POP3 and IMAP"
    printvar "POP3IMAP_TLS" "Activate POP3S and IMAPS (TLS and SSL)"

    #-----------------------------------------------------------------------
    printgroup "Fetchmail settings"
    #-----------------------------------------------------------------------

    printvar "START_FETCHMAIL" "Start fetchmail service"
    printvar "FETCHMAIL_CRON_SCHEDULE" "mail check time"
    printvar "FETCHMAIL_TIMEOUT" "server timeout"
    printvar "FETCHMAIL_POSTMASTER" "store all error messages to"

    #-----------------------------------------------------------------------
    printgroup "Logfile settings"
    #-----------------------------------------------------------------------

    printvar "POSTFIX_LOGLEVEL" "Debug and loglevel 0...3"
    printvar "FETCHMAIL_LOG" "activate fetchmail log entries"

    #-----------------------------------------------------------------------
    printend
    #-----------------------------------------------------------------------
    } > $internal_conf_file
    # Set rights
    chmod 0644 $internal_conf_file
    chown root $internal_conf_file
}

### -------------------------------------------------------------------------
### Create the check.d file
### -------------------------------------------------------------------------
make_check_file ()
{
    printgpl -check "$packages_name" "2005-04-14" "jv" "Jens Vehlhaber" > /etc/check.d/${packages_name}
cat >> /etc/check.d/${packages_name} << EOF
# Variable                   OPT_VARIABLE      VARIABLE_N      VALUE
START_VMAIL                  -                 -               YESNO

VMAIL_SQL_HOST               -                 -               VMAIL_MYSQLHOST
VMAIL_SQL_USER               -                 -               NOTEMPTY
VMAIL_SQL_PASS               -                 -               PASSWD
VMAIL_SQL_PASS               -                 -               VMAIL_PASSWD
VMAIL_SQL_DATABASE           -                 -               NOBLANK
VMAIL_SQL_ENCRYPT_KEY        START_VMAIL       -               PASSWD
VMAIL_SQL_ENCRYPT_KEY        START_VMAIL       -               VMAIL_PASSWD

VMAIL_LOGIN_WITH_MAILADDR    START_VMAIL       -               YESNO


START_POSTFIX                START_VMAIL       -               YESNO

POSTFIX_SMTP_TLS             START_POSTFIX     -               YESNO
POSTFIX_HELO_HOSTNAME        START_POSTFIX     -               FQDN

POSTFIX_RELAY_FROM_NET_N     START_POSTFIX     -               NUMERIC
POSTFIX_RELAY_FROM_NET_%     START_POSTFIX POSTFIX_RELAY_FROM_NET_N NETWORK

POSTFIX_LIMIT_DESTINATIONS   START_POSTFIX     -               NUMERIC
POSTFIX_LIMIT_MAILSIZE       START_POSTFIX     -               NUMERIC

POSTFIX_REJECT_UNKN_CLIENT   START_POSTFIX     -               YESNO
POSTFIX_REJECT_UNKN_SEND_DOM START_POSTFIX     -               YESNO
POSTFIX_REJECT_NON_FQDN_HOST START_POSTFIX     -               YESNO
POSTFIX_REJECT_DYNADDRESS    START_POSTFIX     -               YESNO
POSTFIX_REJECT_BOGUS_MX      START_POSTFIX     -               YESNO
POSTFIX_MIME_HEADER_CHECK    START_POSTFIX     -               YESNO
POSTFIX_POSTSCREEN           START_POSTFIX     -               YESNO

POSTFIX_RBL                  POSTFIX_POSTSCREEN -              YESNO
POSTFIX_RBL_N                POSTFIX_RBL       -               NUMERIC
POSTFIX_RBL_%_SERVER         POSTFIX_RBL   POSTFIX_RBL_N       FQDN
POSTFIX_RBL_%_WEIGHT         POSTFIX_RBL   POSTFIX_RBL_N       VMAIL_THRESHOLD


POSTFIX_HEADER_N             START_POSTFIX     -               NUMERIC
POSTFIX_HEADER_%_CHECK       START_POSTFIX POSTFIX_HEADER_N    NOTEMPTY
POSTFIX_HEADER_%_HANDL       START_POSTFIX POSTFIX_HEADER_N    VMAIL_ACTION

POSTFIX_CLIENT_N             START_POSTFIX     -               NUMERIC
POSTFIX_CLIENT_%_CHECK       START_POSTFIX POSTFIX_CLIENT_N    NOTEMPTY
POSTFIX_CLIENT_%_HANDL       START_POSTFIX POSTFIX_CLIENT_N    VMAIL_ACTION

POSTFIX_AUTOSIGNATURE        START_POSTFIX     -               YESNO

POSTFIX_ALTERNATE_SMTP_PORT  START_POSTFIX     -               PORT
POSTFIX_QUEUE_LIFETIME       START_POSTFIX     -               VMAIL_QLIFETIME
POSTFIX_DRACD                START_POSTFIX     -               YESNO
#POSTFIX_DRACD_RELAYTIME      POSTFIX_DRACD     -               NUMERIC
POSTFIX_SMARTHOST            START_POSTFIX     -               YESNO
#POSTFIX_SMARTHOST_TLS        POSTFIX_SMARTHOST -               YESNO  

POSTFIX_AV_CLAMAV            START_POSTFIX     -               YESNO
POSTFIX_AV_FPROTD            START_POSTFIX     -               YESNO
POSTFIX_AV_SCRIPT            START_POSTFIX     -               YESNO
POSTFIX_AV_SCRIPTFILE        POSTFIX_AV_SCRIPT -               ABS_PATH

POSTFIX_AV_VIRUS_INFO        START_POSTFIX     -               EMAILADDR
POSTFIX_AV_QUARANTINE        START_POSTFIX     -               YESNO

START_POP3IMAP               START_VMAIL       -               YESNO
POP3IMAP_TLS                 START_POP3IMAP    -               YESNO

START_FETCHMAIL              START_VMAIL       -               YESNO
FETCHMAIL_CRON_SCHEDULE      START_FETCHMAIL   -               CRONTAB
FETCHMAIL_TIMEOUT            START_FETCHMAIL   -               NUMERIC
FETCHMAIL_POSTMASTER         START_FETCHMAIL   -               NOBLANK

POSTFIX_LOGLEVEL             START_POSTFIX     -               RE:[0-3]
FETCHMAIL_LOG                START_FETCHMAIL   -               YESNO

EOF
    # Set rights for check.d file
    chmod 0644 /etc/check.d/$packages_name
    chown root /etc/check.d/$packages_name

    printgpl -check_exp "$packages_name" "2006-09-29" "jv" "Jens Vehlhaber" > /etc/check.d/${packages_name}.exp
cat >> /etc/check.d/${packages_name}.exp << EOF
VMAIL_MYSQLHOST  = 'localhost|(RE:IPADDR)'
                 : 'Use localhost or IP-address'
VMAIL_PASSWD     = '([^$& ]{4,})'
                 : 'Only > 3 characters allowed, without char $ and & and blanks'
VMAIL_ACTION     = '^(DISCARD.*|DUNNO|FILTER.*|HOLD.*|IGNORE|OK|PREPEND.*|REDIRECT.*|REPLACE.*|REJECT.*|PREPEND.*|WARN.*|450.*|550.*)'
                 : 'Use only: DISCARD, DUNNO, FILTER, HOLD, IGNORE, OK, PREPEND, REDIRECT, REPLACE, REJECT, PREPEND, WARN, 450, 550'
VMAIL_QLIFETIME  = '30|2[0-9]|1[0-9]|[1-9]'
                 : 'No valid queue lifetime. Use between 1 and 30 (days)'
VMAIL_THRESHOLD  = '1|2|3' 
                 : 'Use numeric value 1 - 3'
EOF
    # Set rights for check.exp file
    chmod 0644 /etc/check.d/${packages_name}.exp
    chown root /etc/check.d/${packages_name}.exp

}

### ---------------------------------------------------------------------------
### Main
### ---------------------------------------------------------------------------
# write default config file
echo -n "."
make_config_file /etc/default.d/$packages_name

# update from old version
echo -n "."
rename_old_variables

# write new config file
echo -n "."
make_config_file /etc/config.d/$packages_name

# write check.d file
make_check_file
echo -n "."

### ---------------------------------------------------------------------------
exit 0
