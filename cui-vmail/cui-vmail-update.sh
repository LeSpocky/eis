#!/bin/sh
#------------------------------------------------------------------------------
# eisfair configuration update script
# Copyright 2007 - 2014 the eisfair team, team(at)eisfair(dot)org
#------------------------------------------------------------------------------

# include configlib
. /var/install/include/configlib

packages_name='vmail'

### ---------------------------------------------------------------------------
### read old and default variables
### ---------------------------------------------------------------------------
 . /etc/default.d/$packages_name
 . /etc/config.d/$packages_name


### ---------------------------------------------------------------------------
### Write config and default files
### ---------------------------------------------------------------------------
{
    printgpl -conf "$packages_name" "2005-04-14" "jv" "Jens Vehlhaber"
    #-----------------------------------------------------------------------
    printgroup "Vmail settings"
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

    printvar "POSTFIX_SMTP_TLS" "use STARTTLS or SMTP over SSL"
    printvar "POSTFIX_HELO_HOSTNAME" "use alternate external host name"
    printvar "POSTFIX_AUTOSIGNATURE" "write automatic signature to all mail"
    printvar "POSTFIX_QUEUE_LIFETIME" "change default queue lifetime"
    printvar "POSTFIX_RELAY_FROM_NET_N" "Count of internal networks"
    count=1
    while [ ${count} -le ${POSTFIX_RELAY_FROM_NET_N} ]
    do
        printvar "POSTFIX_RELAY_FROM_NET_${count}" "NETWORK/NETMASK 172.16.0.0/16"
        count=`expr ${count} + 1`
    done

    printvar "POSTFIX_SMARTHOST" "send all e-mails to external e-mail server"
    #printvar "POSTFIX_SMARTHOST_TLS" "set TLS"

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
    while [ ${count} -le ${POSTFIX_RBL_N} ]
    do
        printvar "POSTFIX_RBL_${count}_SERVER" "Realtime Blackhole List server $count name"
        printvar "POSTFIX_RBL_${count}_WEIGHT" "Blackhole server $count blocking weight"
        count=`expr ${count} + 1`
    done

    printvar "POSTFIX_HEADER_N" "Count of header checks"
    count=1
    while [ ${count} -le ${POSTFIX_HEADER_N} ]
    do
        printvar "POSTFIX_HEADER_${count}_CHECK" "PCRE check string"
        printvar "POSTFIX_HEADER_${count}_HANDL" "handling: REJECT, IGNORE + logstring"
        count=`expr ${count} + 1`
    done

    printvar "POSTFIX_CLIENT_N" "Count of checked email clients"
    count=1
    while [ ${count} -le ${POSTFIX_CLIENT_N} ]
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

} /etc/config.d/$packages_name

chmod 0640 /etc/config.d/$packages_name
chown root /etc/config.d/$packages_name

### ---------------------------------------------------------------------------
exit 0
