#!/bin/bash
#----------------------------------------------------------------------------
# /var/install/bin/mail-update.sh - update or generate new mail configuration
#
# Copyright (c) 2001-2014 The Eisfair Team, team(at)eisfair(dot)org
#
# Creation:     2003-02-15  jed
# Last Update:  $Id: mail-update.sh 36467 2014-12-22 14:59:55Z jed $
#
# Parameters:
#
#     mail-update.sh [import]   - import pop3/imap users from csv file $read_pop3imap_users
#     mail-update.sh [export]   - export pop3/imap users to csv file $read_pop3imap_users
#     mail-update.sh [test]     - read $mailfile.new create test configuration file mk_mail.test
#     mail-update.sh [update]   - read $mailfile.import and check/update configuration file
#
#     mail-update.sh [basic]    - create basic configuration file
#     mail-update.sh [advanced] - create advanced configuration file
#     mail-update.sh [merge]    - merge $fullile and $basicfile configuration
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

# read eislib
. /var/install/include/eislib
. /var/install/include/configlib
. /var/install/include/mail

#exec 2>/tmp/mailup-trace-$$.log
#set -x

#------------------------------------------------------------------------------
# function: variable is set
#
# input:  $1 - variable name
# return:  0 - variable set
#          1 - variable not set
#------------------------------------------------------------------------------
variable_set ()
{
    eval _var1=\$"${1}"
    eval _var2=\$"{${1}+EMPTY}"

    if [ -z "${_var1}" ]
    then
        if [ "${_var2}" = "EMPTY" ]
        then
            # variable is empty, but set
            ret=0
        else
            # variable is not set
            ret=1
        fi
    else
        # variable has a value
        ret=0
    fi

    return ${ret}
}

#------------------------------------------------------------------------------
# print variable only if it has been set
# $1 - variable name
# $2 - comment
#------------------------------------------------------------------------------
printsetvar ()
{
    if variable_set "${1}"
    then
        printvar "${1}" "${2}"
    fi
}

#------------------------------------------------------------------------------
# rename variables
#------------------------------------------------------------------------------
rename_variables ()
{
    renamed=0
    mecho --info "renaming parameter(s) ..."

    # v1.1.2
    if [ ! -z "`grep ^SMTP_SMART_HOST $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST -> SMTP_SMARTHOST_1_HOST"
        SMTP_SMARTHOST_1_HOST="$SMTP_SMART_HOST"
        renamed=1
    fi

    if [ ! -z "`grep ^SMTP_SMART_HOST_AUTH $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST_AUTH -> SMTP_SMARTHOST_1_AUTH_TYPE"
        SMTP_SMARTHOST_1_AUTH_TYPE="$SMTP_SMART_HOST_AUTH"
        renamed=1
    fi

    if [ ! -z "`grep ^SMTP_SMART_HOST_USER $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST_USER -> SMTP_SMARTHOST_1_USER"
        SMTP_SMARTHOST_1_USER="$SMTP_SMART_HOST_USER"
        renamed=1
    fi

    if [ ! -z "`grep ^SMTP_SMART_HOST_PASS $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST_PASS -> SMTP_SMARTHOST_1_PASS"
        SMTP_SMARTHOST_1_PASS="$SMTP_SMART_HOST_PASS"
        renamed=1
    fi

    if [ ! -z "`grep ^SMTP_SMART_HOST_FORCE_AUTH $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST_FORCE_AUTH -> SMTP_SMARTHOST_1_FORCE_AUTH"
        SMTP_SMARTHOST_1_FORCE_AUTH="$SMTP_SMART_HOST_FORCE_AUTH"
        renamed=1
    fi

    if [ ! -z "`grep ^SMTP_SMART_HOST_FORCE_TLS $source_conf`" ]
    then
        mecho "- SMTP_SMART_HOST_FORCE_TLS -> SMTP_SMARTHOST_1_FORCE_TLS"
        SMTP_SMARTHOST_1_FORCE_TLS="$SMTP_SMART_HOST_FORCE_TLS"
        renamed=1
    fi

    # v.1.1.4
    if [ ! -z "`grep ^SMTP_ALIAS_N $source_conf`" ]
    then
        mecho "- SMTP_ALIAS_N -> SMTP_ALIASES_1_ALIAS_N"
        SMTP_ALIASES_1_ALIAS_N="$SMTP_ALIAS_N"
        renamed=1
    fi

    if [ $SMTP_ALIASES_1_ALIAS_N -eq 0 ]
    then
        imax=2
    else
        imax=$SMTP_ALIASES_1_ALIAS_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        if [ ! -z "`grep ^SMTP_ALIAS_$idx $source_conf`" ]
        then
            eval alias_old='$SMTP_ALIAS_'$idx
            eval alias_new="SMTP_ALIASES_1_ALIAS_$idx"

            mecho "- SMTP_ALIAS_$idx -> SMTP_ALIASES_1_ALIAS_$idx"
            eval "$alias_new=\"$alias_old\""
            renamed=1
        fi
        idx=`expr $idx + 1`
    done

    if [ ! -z "`grep ^EXISCAN_UNPACK_MIME $source_conf`" ]
    then
        mecho "- EXISCAN_UNPACK_MIME -> EXISCAN_DEMIME_ENABLED"
        EXISCAN_DEMIME_ENABLED="$EXISCAN_UNPACK_MIME"
        renamed=1
    fi

    if [ ! -z "`grep ^EXISCAN_SPAMD_TRESHOLD $source_conf`" ]
    then
        mecho "- EXISCAN_SPAMD_TRESHOLD -> EXISCAN_SPAMD_THRESHOLD"
        EXISCAN_SPAMD_THRESHOLD="$EXISCAN_SPAMD_TRESHOLD"
        renamed=1
    fi

    # v.1.5.1
    if [ ! -z "`grep ^POP3IMAP_USE_MAILONLY_PASSWORDS $source_conf`" ]
    then
        mecho "- POP3IMAP_USE_MAILONLY_PASSWORDS -> MAIL_USER_USE_MAILONLY_PASSWORDS"
        MAIL_USER_USE_MAILONLY_PASSWORDS="$POP3IMAP_USE_MAILONLY_PASSWORDS"
        renamed=1
    fi

    # v.1.5.1 - POP3IMAP_x_... -> MAIL_USER_x_...
    if [ ! -z "`grep ^POP3IMAP_N $source_conf`" ]
    then
        mecho "- POP3IMAP_N -> MAIL_USER_N"
        MAIL_USER_N="$POP3IMAP_N"
        renamed=1
    fi

    if [ $MAIL_USER_N -eq 0 ]
    then
        imax=1
    else
        imax=$MAIL_USER_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        if [ ! -z "`grep ^POP3IMAP_${idx}_ACTIVE $source_conf`" ]
        then
            eval active_old='$POP3IMAP_'$idx'_ACTIVE'
            eval active_new="MAIL_USER_${idx}_ACTIVE"

            mecho "- POP3IMAP_${idx}_ACTIVE -> MAIL_USER_${idx}_ACTIVE"
            eval "$active_new=\"$active_old\""
            renamed=1
        fi

        if [ ! -z "`grep ^POP3IMAP_${idx}_USER $source_conf`" ]
        then
            eval user_old='$POP3IMAP_'$idx'_USER'
            eval user_new="MAIL_USER_${idx}_USER"

            mecho "- POP3IMAP_${idx}_USER -> MAIL_USER_${idx}_USER"
            eval "$user_new=\"$user_old\""
            renamed=1
        fi

        if [ ! -z "`grep ^POP3IMAP_${idx}_PASS $source_conf`" ]
        then
            eval pass_old='$POP3IMAP_'$idx'_PASS'
            eval pass_new="MAIL_USER_${idx}_PASS"

            mecho "- POP3IMAP_${idx}_PASS -> MAIL_USER_${idx}_PASS"
            eval "$pass_new='$pass_old'"
            renamed=1
        fi

        idx=`expr $idx + 1`
    done

    if [ $renamed -eq 1 ]
    then
        mecho --info "... read documentation for renamed parameter(s)!"
        anykey
    fi
}

#------------------------------------------------------------------------------
# modify variables
#------------------------------------------------------------------------------
modify_variables ()
{
    modified=0
    mecho --info "modifying parameter(s) ..."

    if [ "$FETCHMAIL_LIMIT" = "" ]
    then
        mecho "- FETCHMAIL_LIMIT, '' -> will now be interpreted as 4096000 bytes!"
        modified=1
    fi

    salt_len=16
    if [ "${EXISCAN_CRYPT_SALT}" = "" -o `echo ${EXISCAN_CRYPT_SALT}|wc -L` -lt ${salt_len} ]
    then
        # create random crypt salt and add mail hostname
        randsalt="`rand_string ${salt_len}`"

        mecho "- EXISCAN_CRYPT_SALT, '${EXISCAN_CRYPT_SALT}' -> '${randsalt}'"
        EXISCAN_CRYPT_SALT="${randsalt}"
        modified=1
    fi

    if [ "$EXISCAN_SPAMD_ACTION" = "redirect spam" ]
    then
        mecho "- EXISCAN_SPAMD_ACTION, 'redirect spam' -> 'redirect spam@$SMTP_QUALIFY_DOMAIN'"
        EXISCAN_SPAMD_ACTION="redirect spam@$SMTP_QUALIFY_DOMAIN"
        modified=1
    fi

    if [ -f /tmp/mail-prev-ver-1.1.6 -a "$SMTP_AUTH_TYPE" = "user" -a "$POP3IMAP_USE_MAILONLY_PASSWORDS" = "yes" ]
    then
        # display message if previous version is older than v1.1.6
        rm -f /tmp/mail-prev-ver-1.1.6

        mecho "- SMTP_AUTH_TYPE='user' and POP3IMAP_USE_MAILONLY_PASSWORDS='yes' have been set,"
        mecho "  therefor the mail only passwords will now be taken instead of the system passwords"
        mecho "  for SMTP authentication. Please make sure that you modify the mail client settings!"
        modified=1
    fi

    # v1.1.8
    exi_str1=`grep ^EXISCAN_AV_DESCRIPTION $source_conf|cut -d'=' -f2|cut -d'#' -f1`
    exi_str1="`echo $exi_str1`"
    exi_str2="\'\(\.\*\)\'"

    if [ "$exi_str1" = "$exi_str2" ]
    then
        mecho "- EXISCAN_AV_DESCRIPTION, \'\(\.\*\)\' -> \"'(.*)'\""
        EXISCAN_AV_DESCRIPTION="'(.*)'"
        modified=1
    fi

    # v1.1.10
    # rename exiscan parameter
    if [ "$EXISCAN_AV_SCANNER" = "clamav" ]
    then
        mecho "- EXISCAN_AV_SCANNER, 'clamav' -> 'clamd'"
        EXISCAN_AV_SCANNER="clamd"
        modified=1
    fi

    # check variables for value 'blackhole' and replace it
    for exi_var in EXISCAN_DEMIME_ACTION EXISCAN_AV_ACTION EXISCAN_EXTENSION_ACTION EXISCAN_REGEX_ACTION EXISCAN_SPAMD_ACTION
    do
        eval exi_val=\$$exi_var

        if [ "$exi_val" = "blackhole" ]
        then
            # replace 'blackhole' by 'discard'
            mecho "- $exi_val, 'blackhole' -> 'discard'"
            eval ${exi_var}="discard"
            modified=1
        fi
    done

    # check variables for '|' sign and replace it
    echo "$EXISCAN_AV_OPTIONS"|grep \| > /dev/null

    if [ $? -eq 0 ]
    then
        exi_new="`echo "$EXISCAN_AV_OPTIONS"|sed -e 's/|/%%s/'`"
        mecho "- EXISCAN_AV_OPTIONS, '$EXISCAN_AV_OPTIONS' -> '$exi_new'"
        EXISCAN_AV_OPTIONS="$exi_new"
        modified=1
    fi

    # check variables for '.' sign and replace it
    echo "$EXISCAN_SPAMD_THRESHOLD"|grep "\." > /dev/null

    if [ $? -ne 0 ]
    then
        exi_new="$EXISCAN_SPAMD_THRESHOLD.0"
        mecho "- EXISCAN_SPAMD_THRESHOLD, '$EXISCAN_SPAMD_THRESHOLD' -> '$exi_new'"
        EXISCAN_SPAMD_THRESHOLD="$exi_new"
        modified=1
    fi

    # v1.6.14
    # convert to lowercase
    FETCHMAIL_PROTOCOL="`echo ${FETCHMAIL_PROTOCOL} | tr 'A-Z' 'a-z'`"

    # v1.4.4
    echo "${FETCHMAIL_PROTOCOL}" | grep -q "pop2"

    if [ $? -eq 0 ]
    then
        mecho --error "- FETCHMAIL_PROTOCOL - Option 'pop2' no longer supported! -> ''"
        FETCHMAIL_PROTOCOL=''
        modified=1
    fi

    if [ $FETCHMAIL_N -eq 0 ]
    then
        imax=1
    else
        imax=$FETCHMAIL_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        eval proto='$FETCHMAIL_'${idx}'_PROTOCOL'

        proto="`echo ${proto} |  tr 'A-Z' 'a-z'`"

        echo "$proto" | grep -q "pop2"

        if [ $? -eq 0 ]
        then
            # pop2 no longer allowed
            mecho --error "- FETCHMAIL_${idx}_PROTOCOL - Option 'pop2' no longer supported! -> ''"
            eval "FETCHMAIL_${idx}_PROTOCOL=''"
            modified=1
        else
            # v1.6.14
            # rewrite due to lowercase conversation
            eval "FETCHMAIL_${idx}_PROTOCOL='${proto}'"
        fi

        idx=`expr $idx + 1`
    done

    if [ $modified -eq 1 ]
    then
        mecho --info "... read documentation for modified parameter(s)!"
        anykey
    fi
}

#------------------------------------------------------------------------------
# add variables
#------------------------------------------------------------------------------
add_variables ()
{
    added=0
    mecho --info "adding new parameter(s) ..."

    # v1.4.5
    if [ -z "`grep ^START_MAIL $source_conf`" ]
    then
        if [ "$START_POP3" = "yes" -o "$START_IMAP" = "yes" -o "$START_FETCHMAIL" = "yes" -o "$START_SMTP" = "yes" -o "$START_EXISCAN" = "yes" ]
        then
            mecho "- START_MAIL='yes'"
            START_MAIL='yes'
        else
            mecho "- START_MAIL='no'"
            START_MAIL='no'
        fi
        added=1
    fi

    # v1.1.2
    if [ -z "`grep ^SMTP_ALLOW_EXIM_FILTERS $source_conf`" ]
    then
        mecho "- SMTP_ALLOW_EXIM_FILTERS='no'"
        SMTP_ALLOW_EXIM_FILTERS='no'
        added=1
    fi

    if [ -z "`grep ^SMTP_SMARTHOST_ONE_FOR_ALL $source_conf`" ]
    then
        mecho "- SMTP_SMARTHOST_ONE_FOR_ALL='yes'"
        SMTP_SMARTHOST_ONE_FOR_ALL='yes'
        added=1
    fi

    if [ -z "`grep ^SMTP_SMARTHOST_DOMAINS $source_conf`" ]
    then
        mecho "- SMTP_SMARTHOST_DOMAINS=''"
        SMTP_SMARTHOST_DOMAINS=''
        added=1
    fi

    if [ -z "`grep ^SMTP_SMARTHOST_N $source_conf`" ]
    then
        if [ "$SMTP_SMARTHOST_1_HOST" != "" ]
        then
            mecho "- SMTP_SMARTHOST_N='1'"
            SMTP_SMARTHOST_N='1'
        else
            mecho "- SMTP_SMARTHOST_N='0'"
            SMTP_SMARTHOST_N='0'
        fi
        added=1
    fi

    if [ -z "`grep ^SMTP_SMARTHOST_1_ADDR $source_conf`" ]
    then
        mecho "- SMTP_SMARTHOST_1_ADDR='user@local.lan'"
        SMTP_SMARTHOST_1_ADDR='user@local.lan'
        added=1
    fi

    if [ -z "`grep ^MAIL_CERTS_WARNING $source_conf`" ]
    then
        mecho "- MAIL_CERTS_WARNING='yes'"
        MAIL_CERTS_WARNING='yes'
        added=1
    fi

    if [ -z "`grep ^MAIL_CERTS_WARNING_SUBJECT $source_conf`" ]
    then
        mecho "- MAIL_CERTS_WARNING_SUBJECT='TLS certificates warning'"
        MAIL_CERTS_WARNING_SUBJECT='TLS certificates warning'
        added=1
    fi

    if [ -z "`grep ^MAIL_CERTS_WARNING_CRON_SCHEDULE $source_conf`" ]
    then
        mecho "- MAIL_CERTS_WARNING_CRON_SCHEDULE='3 1 1,16 * *'"
        MAIL_CERTS_WARNING_CRON_SCHEDULE='3 1 1,16 * *'
        added=1
    fi

    if [ -z "`grep ^MAIL_STATISTICS_INFOMAIL $source_conf`" ]
    then
        mecho "- MAIL_STATISTICS_INFOMAIL='no'"
        MAIL_STATISTICS_INFOMAIL='no'
        added=1
    fi

    if [ -z "`grep ^MAIL_STATISTICS_INFOMAIL_SUBJECT $source_conf`" ]
    then
        mecho "- MAIL_STATISTICS_INFOMAIL_SUBJECT='Mail server statistics'"
        MAIL_STATISTICS_INFOMAIL_SUBJECT='Mail server statistics'
        added=1
    else
        MAIL_STATISTICS_INFOMAIL_SUBJECT="$MAIL_STATISTICS_INFOMAIL_SUBJECT"
    fi

    if [ -z "`grep ^MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE $source_conf`" ]
    then
        mecho "- MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE='6 7 * * *'"
        MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE='6 7 * * *'
        added=1
    else
        MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE="$MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE"
    fi

    # v1.1.3
    if [ -z "`grep ^SMTP_CHECK_SPOOL_SPACE $source_conf`" ]
    then
        mecho "- SMTP_CHECK_SPOOL_SPACE=''"
        SMTP_CHECK_SPOOL_SPACE=''
        added=1
    else
        SMTP_CHECK_SPOOL_SPACE="$SMTP_CHECK_SPOOL_SPACE"
    fi

    if [ -z "`grep ^SMTP_CHECK_SPOOL_INODES $source_conf`" ]
    then
        mecho "- SMTP_CHECK_SPOOL_INODES=''"
        SMTP_CHECK_SPOOL_INODES=''
        added=1
    else
        SMTP_CHECK_SPOOL_INODES="$SMTP_CHECK_SPOOL_INODES"
    fi

    # v1.1.4
    if [ -z "`grep ^SMTP_LIMIT $source_conf`" ]
    then
        mecho "- SMTP_LIMIT=''"
        SMTP_LIMIT=''
        added=1
    fi

    if [ -z "`grep ^EXISCAN_CRYPT_SALT ${source_conf}`" ]
    then
        if [ "${EXISCAN_CRYPT_SALT}" = "" ]
        then
            salt_len=16
            # create random crypt salt and add mail hostname
            randsalt="`rand_string ${salt_len}`"
            randsalt="${randsalt}-${SMTP_HOSTNAME}"

            mecho "- EXISCAN_CRYPT_SALT='${randsalt}'"
            EXISCAN_CRYPT_SALT="${randsalt}"
        fi
        added=1
    fi

    if [ -z "`grep ^EXISCAN_DEMIME_ACTION $source_conf`" ]
    then
        mecho "- EXISCAN_DEMIME_ACTION='pass'"
        EXISCAN_DEMIME_ACTION='pass'
        added=1
    fi

    if [ -z "`grep ^SMTP_ALIASES_N $source_conf`" ]
    then
        mecho "- SMTP_ALIASES_N='1'"
        SMTP_ALIASES_N='1'
        added=1
    fi

    if [ -z "`grep ^SMTP_ALIASES_1_DOMAIN $source_conf`" ]
    then
        mecho "- SMTP_ALIASES_1_DOMAIN=''"
        SMTP_ALIASES_1_DOMAIN=''
        added=1
    fi

    # v1.1.6
    if [ -z "`grep ^SMTP_REMOVE_RECEIPT_REQUEST $source_conf`" ]
    then
        mecho "- SMTP_REMOVE_RECEIPT_REQUEST='no'"
        SMTP_REMOVE_RECEIPT_REQUEST='no'
        added=1
    fi

    if [ -z "`grep ^SMTP_SMARTHOST_ROUTE_TYPE $source_conf`" ]
    then
        mecho "- SMTP_SMARTHOST_ROUTE_TYPE='addr'"
        SMTP_SMARTHOST_ROUTE_TYPE='addr'
        added=1
    fi

    #----------------------------------------------------------------

    if [ $SMTP_SMARTHOST_N -eq 0 ]
    then
        imax=1
    else
        imax=$SMTP_SMARTHOST_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        # v1.1.6
        if [ -z "`grep '^SMTP_SMARTHOST_'$idx'_DOMAIN' $source_conf`" ]
        then
            mecho "- SMTP_SMARTHOST_"$idx"_DOMAIN=''"
            eval "SMTP_SMARTHOST_"$idx"_DOMAIN=''"
            added=1
        fi

        # v1.1.7
        if [ -z "`grep '^SMTP_SMARTHOST_'$idx'_PORT' $source_conf`" ]
        then
            mecho "- SMTP_SMARTHOST_"$idx"_PORT=''"
            eval "SMTP_SMARTHOST_"$idx"_PORT=''"
            added=1
        fi
        idx=`expr $idx + 1`
    done

    #----------------------------------------------------------------

    if [ $FETCHMAIL_N -eq 0 ]
    then
        imax=1
    else
        imax=$FETCHMAIL_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        eval ftest='$FETCHMAIL_'${idx}'_ENVELOPE'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_ENVELOPE' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_ENVELOPE='no'"
            eval "FETCHMAIL_${idx}_ENVELOPE='no'"
            added=1
        fi

        #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        eval ftest='$FETCHMAIL_'${idx}'_SERVER_AKA_N'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_SERVER_AKA_N' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_SERVER_AKA_N='0'"
            eval "FETCHMAIL_${idx}_SERVER_AKA_N='0'"
            added=1
        fi

        # v1.2.2
        eval ftest='$FETCHMAIL_'${idx}'_MSG_LIMIT'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_MSG_LIMIT' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_MSG_LIMIT='0'"
            eval "FETCHMAIL_${idx}_MSG_LIMIT='0'"
            added=1
        fi

        # v1.1.7
        eval fm_server_aka_n='$FETCHMAIL_'${idx}'_SERVER_AKA_N'

        if [ ${fm_server_aka_n} -eq 0 ]
        then
            jmax=1
        else
            jmax=${fm_server_aka_n}
        fi

        jdx=1
        while [ ${jdx} -le ${jmax} ]
        do
            eval ftest='$FETCHMAIL_'${idx}'_SERVER_AKA_'${jdx}

            if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_SERVER_AKA_'${jdx} ${source_conf}`" ]
            then
                mecho "- FETCHMAIL_${idx}_SERVER_AKA_${jdx}=''"
                eval "FETCHMAIL_${idx}_SERVER_AKA_${jdx}=''"
                added=1
            fi

            jdx=`expr ${jdx} + 1`
        done

        # v1.2.6
        eval ftest='$FETCHMAIL_'${idx}'_ACTIVE'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_ACTIVE' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_ACTIVE='yes'"
            eval "FETCHMAIL_${idx}_ACTIVE='yes'"
            added=1
        fi

        # v1.3.1
        eval ftest='$FETCHMAIL_'${idx}'_IMAP_FOLDER'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_IMAP_FOLDER' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_IMAP_FOLDER=''"
            eval "FETCHMAIL_${idx}_IMAP_FOLDER=''"
            added=1
        fi

        # v1.4.1
        eval ftest='$FETCHMAIL_'${idx}'_COMMENT'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_COMMENT' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_COMMENT=''"
            eval "FETCHMAIL_${idx}_COMMENT=''"
            added=1
        fi

        # v1.4.4
        eval ftest='$FETCHMAIL_'${idx}'_ENVELOPE_HEADER'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_ENVELOPE_HEADER' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_${idx}_ENVELOPE_HEADER=''"
            eval "FETCHMAIL_${idx}_ENVELOPE_HEADER=''"
            added=1
        fi

        # v1.9.11
        eval ftest='$FETCHMAIL_'${idx}'_ACCEPT_BAD_HEADER'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_ACCEPT_BAD_HEADER' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_"${idx}"_ACCEPT_BAD_HEADER='no'"
            eval "FETCHMAIL_"${idx}"_ACCEPT_BAD_HEADER='no'"
            added=1
        fi

        # v1.7.12
        eval ftest='$FETCHMAIL_'${idx}'_DNS_LOOKUP'

        if [ "${ftest}" = "" -a -z "`grep '^FETCHMAIL_'${idx}'_DNS_LOOKUP' ${source_conf}`" ]
        then
            mecho "- FETCHMAIL_"${idx}"_DNS_LOOKUP='yes'"
            eval "FETCHMAIL_"${idx}"_DNS_LOOKUP='yes'"
            added=1
        fi

        idx=`expr ${idx} + 1`
    done

    #----------------------------------------------------------------

    # v1.1.7
    if [ -z "`grep ^POP3IMAP_TRANSPORT $source_conf`" ]
    then
        mecho "- POP3IMAP_TRANSPORT='default'"
        POP3IMAP_TRANSPORT='default'
        added=1
    fi

    # v1.5.11
    # check if package is not newer than v.5.10
    if [ -z "`grep ^MAIL_USER_N $source_conf`" ]           # v1.5.11
    then                                                   # v1.5.11
        # v1.2.6
        if [ "$POP3IMAP_N" != "" ]
        then
            if [ $POP3IMAP_N -eq 0 ]
            then
                imax=1
            else
                imax=$POP3IMAP_N
            fi
        else
            imax=1
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            eval pop3imap_active='$POP3IMAP_'$idx'_ACTIVE'

            if [ "$pop3imap_active" = "" -a -z "`grep '^POP3IMAP_'$idx'_ACTIVE' $source_conf`" ]
            then
                mecho "- POP3IMAP_"$idx"_ACTIVE='yes'"
                eval "POP3IMAP_"$idx"_ACTIVE='yes'"
                added=1
            fi

            idx=`expr $idx + 1`
        done
    fi                                                     # v1.5.11

    #----------------------------------------------------------------

    # v1.1.7
    if [ -z "`grep ^SMTP_SERVER_TRANSPORT $source_conf`" ]
    then
        mecho "- SMTP_SERVER_TRANSPORT='default'"
        SMTP_SERVER_TRANSPORT='default'
        added=1
    fi

    if [ -z "`grep ^SMTP_SERVER_TLS_ADVERTISE_HOSTS $source_conf`" ]
    then
        mecho "- SMTP_SERVER_TLS_ADVERTISE_HOSTS=''"
        SMTP_SERVER_TLS_ADVERTISE_HOSTS=''
        added=1
    fi

    if [ -z "`grep ^SMTP_SERVER_TLS_VERIFY_HOSTS $source_conf`" ]
    then
        mecho "- SMTP_SERVER_TLS_VERIFY_HOSTS=''"
        SMTP_SERVER_TLS_VERIFY_HOSTS=''
        added=1
    fi

    #----------------------------------------------------------------

    # v1.1.7
    if [ $IMAP_SHARED_FOLDER_N -eq 0 ]
    then
        imax=1
    else
        imax=$IMAP_SHARED_FOLDER_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        # v1.1.7
        if [ -z "`grep '^IMAP_SHARED_FOLDER_'$idx'_USERGROUP' $source_conf`" ]
        then
            mecho "- IMAP_SHARED_FOLDER_"$idx"_USERGROUP=''"
            eval "IMAP_SHARED_FOLDER_"$idx"_USERGROUP=''"
            added=1
        fi

        # v1.2.6
        if [ -z "`grep '^IMAP_SHARED_FOLDER_'$idx'_ACTIVE' $source_conf`" ]
        then
            mecho "- IMAP_SHARED_FOLDER_"$idx"_ACTIVE='no'"
            eval "IMAP_SHARED_FOLDER_"$idx"_ACTIVE='no'"
            added=1
        fi

        idx=`expr $idx + 1`
    done

    #----------------------------------------------------------------

    # v1.1.7
    if [ $IMAP_PUBLIC_FOLDER_N -eq 0 ]
    then
        imax=1
    else
        imax=$IMAP_PUBLIC_FOLDER_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        # v1.1.7
        if [ -z "`grep '^IMAP_PUBLIC_FOLDER_'$idx'_USERGROUP' $source_conf`" ]
        then
            mecho "- IMAP_PUBLIC_FOLDER_"$idx"_USERGROUP=''"
            eval "IMAP_PUBLIC_FOLDER_"$idx"_USERGROUP=''"
            added=1
        fi

        # v1.2.6
        if [ -z "`grep '^IMAP_PUBLIC_FOLDER_'$idx'_ACTIVE' $source_conf`" ]
        then
            mecho "- IMAP_PUBLIC_FOLDER_"$idx"_ACTIVE='no'"
            eval "IMAP_PUBLIC_FOLDER_"$idx"_ACTIVE='no'"
            added=1
        fi

        idx=`expr $idx + 1`
    done

    #----------------------------------------------------------------

    # v1.1.10
    # replace multiple variables by only one
    if [ -z "`grep ^EXISCAN_AV_SOCKET $source_conf`" ]
    then
        case $EXISCAN_AV_SCANNER
        in
             sophie )
                if [ ! -z "`grep ^EXISCAN_AV_SOPHIE_SOCKET $source_conf`" ]
                then
                    EXISCAN_AV_SOCKET="$EXISCAN_AV_SOPHIE_SOCKET"
                fi
                ;;
             kavdaemon )
                if [ ! -z "`grep ^EXISCAN_AV_KAVDAEMON_SOCKET $source_conf`" ]
                then
                    EXISCAN_AV_SOCKET="$EXISCAN_AV_KAVDAEMON_SOCKET"
                fi
                ;;
             clamav|clamd )
                if [ ! -z "`grep ^EXISCAN_AV_CLAMAV_SOCKET $source_conf`" ]
                then
                    EXISCAN_AV_SOCKET="$EXISCAN_AV_CLAMAV_SOCKET"
                elif [ ! -z "`grep ^EXISCAN_AV_CLAMAV_HOST $source_conf`" ]
                then
                    EXISCAN_AV_SOCKET="$EXISCAN_AV_CLAMAV_HOST $EXISCAN_AV_CLAMAV_PORT"
                fi
                ;;
        esac

        mecho "- EXISCAN_AV_SOCKET='$EXISCAN_AV_SOCKET'"
        added=1
    fi

    if [ -z "`grep ^SMTP_UPDATE_IGNORE_HOSTS $source_conf`" ]
    then
        mecho "- SMTP_UPDATE_IGNORE_HOSTS='no'"
        SMTP_UPDATE_IGNORE_HOSTS='no'
        added=1
    fi

    if [ -z "`grep ^SMTP_UPDATE_IGNORE_HOSTS_CRON_SCHEDULE $source_conf`" ]
    then
        mecho "- SMTP_UPDATE_IGNORE_HOSTS_CRON_SCHEDULE='5 1 * * 0'"
        SMTP_UPDATE_IGNORE_HOSTS_CRON_SCHEDULE='5 1 * * 0'
        added=1
    fi

    # v1.2.3
    if [ -z "`grep ^EXISCAN_AV_SUBJECT_TAG $source_conf`" ]
    then
        mecho "- EXISCAN_AV_SUBJECT_TAG=''"
        EXISCAN_AV_SUBJECT_TAG=''
        added=1
    fi

    if [ -z "`grep ^SMTP_SERVER_SSMTP $source_conf`" ]
    then
        mecho "- SMTP_SERVER_SSMTP='no'"
        SMTP_SERVER_SSMTP='no'
        added=1
    fi

    if [ -z "`grep ^SMTP_SERVER_SSMTP_LISTEN_PORT $source_conf`" ]
    then
        mecho "- SMTP_SERVER_SSMTP_LISTEN_PORT='ssmtp'"
        SMTP_SERVER_SSMTP_LISTEN_PORT='ssmtp'
        added=1
    fi

    # v1.3.1
    if [ -z "`grep ^POP3IMAP_IDENT_CALLBACKS $source_conf`" ]
    then
        mecho "- POP3IMAP_IDENT_CALLBACKS='yes'"
        POP3IMAP_IDENT_CALLBACKS='yes'
        added=1
    fi

    # v1.4.4
    if [ -z "`grep ^SMTP_IDENT_CALLBACKS $source_conf`" ]
    then
        mecho "- SMTP_IDENT_CALLBACKS='yes'"
        SMTP_IDENT_CALLBACKS='yes'
        added=1
    fi

    if [ -z "`grep ^SMTP_CHECK_RECIPIENTS $source_conf`" ]
    then
        mecho "- SMTP_CHECK_RECIPIENTS=''"
        SMTP_CHECK_RECIPIENTS=''
        added=1
    fi

    if [ -z "`grep ^EXISCAN_SPAMD_LIMIT $source_conf`" ]
    then
        mecho "- EXISCAN_SPAMD_LIMIT='0'"
        EXISCAN_SPAMD_LIMIT='0'
        added=1
    fi

    # v1.6.15
    if [ -z "`grep ^SMTP_SERVER_TLS_TRY_VERIFY_HOSTS ${source_conf}`" ]
    then
        mecho "- SMTP_SERVER_TLS_TRY_VERIFY_HOSTS=''"
        SMTP_SERVER_TLS_TRY_VERIFY_HOSTS=''
        added=1
    fi

    if [ $SMTP_LIST_N -eq 0 ]
    then
        imax=2
    else
        imax=$SMTP_LIST_N
    fi

    idx=1
    while [ $idx -le $imax ]
    do
        eval list_active='$SMTP_LIST_'$idx'_ACTIVE'

        if [ "$list_active" = "" -a -z "`grep '^SMTP_LIST_'$idx'_ACTIVE' $source_conf`" ]
        then
            mecho "- SMTP_LIST_"$idx"_ACTIVE='yes'"
            eval "SMTP_LIST_"$idx"_ACTIVE='yes'"
            added=1
        fi

        idx=`expr $idx + 1`
    done

    # v1.7.0
    if [ -z "`grep ^SMTP_QUEUE_ACCEPT_PER_CONNECTION ${source_conf}`" ]
    then
        mecho "- SMTP_QUEUE_ACCEPT_PER_CONNECTION='10'"
        SMTP_QUEUE_ACCEPT_PER_CONNECTION='10'
        added=1
    fi

    # v1.7.10
    if [ -z "`grep ^EXISCAN_SPAMD_SKIP_AUTHENTICATED ${source_conf}`" ]
    then
        mecho "- EXISCAN_SPAMD_SKIP_AUTHENTICATED='no'"
        EXISCAN_SPAMD_SKIP_AUTHENTICATED='no'
        added=1
    fi

    # v1.7.12
    if [ -z "`grep ^EXISCAN_AV_SKIP_AUTHENTICATED ${source_conf}`" ]
    then
        mecho "- EXISCAN_AV_SKIP_AUTHENTICATED='no'"
        EXISCAN_AV_SKIP_AUTHENTICATED='no'
        added=1
    fi

    # v1.9.2
    if [ -z "`grep ^EXISCAN_ACTION_ON_FAILURE ${source_conf}`" ]
    then
        mecho "- EXISCAN_ACTION_ON_FAILURE='pass'"
        EXISCAN_ACTION_ON_FAILURE='pass'
        added=1
    fi

    if [ ${added} -eq 1 ]
    then
        mecho --info "... read documentation for new parameter(s)!"
        anykey
    fi
}

#------------------------------------------------------------------------------
# delete variables
#------------------------------------------------------------------------------
delete_variables ()
{
    deleted=0
    mecho --info "deleting old parameters ..."

    # v1.1.2
    for varname in "EXISCAN_AV_CLAMAV_HOST EXISCAN_AV_CLAMAV_PORT"
    do
        if [ ! -z "`grep \"^$varname\" $source_conf`" ]
        then
            mecho "- $varname"
            deleted=1
        fi
    done

    # v1.1.4
    for varname in "EXISCAN_AV_BUFFER_INIT_CHUNK EXISCAN_AV_BUFFER_MAX_CHUNKS EXISCAN_SPAMD_BUFFER_INIT_CHUNK EXISCAN_SPAMD_BUFFER_MAX_CHUNKS"
    do
        if [ ! -z "`grep \"^$varname\" $source_conf`" ]
        then
            mecho "- $varname"
            deleted=1
        fi
    done

    # v1.1.10
    if [ ! -z "`grep ^EXISCAN_AV_OPENAV_HOST $source_conf`" ]
    then
        mecho --info "- Attention: OpenAV scanner is no longer supported by exiscan!"
        mecho
    fi

    for varname in "EXISCAN_AV_SOPHIE_SOCKET EXISCAN_AV_KAVDAEMON_SOCKET EXISCAN_AV_CLAMAV_SOCKET EXISCAN_AV_OPENAV_HOST EXISCAN_AV_OPENAV_PORT EXISCAN_TIMEOUT"
    do
        if [ ! -z "`grep \"^$varname\" $source_conf`" ]
        then
            mecho "- $varname"
            deleted=1
        fi
    done

    if [ $deleted -eq 1 ]
    then
        anykey
    fi
}

#------------------------------------------------------------------------------
# import pop3imap user and password list
#------------------------------------------------------------------------------
import_pop3imap_users ()
{
    if [ -f $read_pop3imap_users ]
    then
        mecho --info "importing $read_pop3imap_users file ..."

        # convert to unix file format
        dtou $read_pop3imap_users

        # set offset
        idx=$POP3IMAP_N
        while read line
        do
            # delete leading spaces
            line=`trim_spaces "${line}"`

            if [ "$line" != "" ]
            then
                # line not empty
                echo $line|grep -q "^#"

                if [ $? -eq 1 ]
                then
                    # no comment found - process line
                    # extract information and remove leading/trailing spaces
                    OLDIFS=$IFS
                    IFS=,

                    set $line

                    username=`trim_spaces "$1"`
                    password=`trim_spaces "$2"`
                    active=`trim_spaces "$3"`

                    IFS=$OLDIFS

                    # deactivate user by default if value not given
                    if [ "$active" = "" ]
                    then
                        active='no'
                    fi

                    # check if nick name already exists
                    jdx=1
                    foundflag=0
                    testuser1=`echo $username|tr 'A-Z' 'a-z'`

                    while [ $jdx -le $POP3IMAP_N ]
                    do
                        eval testuser2='$POP3IMAP_'$jdx'_USER'
                        testuser2=`trim_spaces "${testuser2}"|tr 'A-Z' 'a-z'`

                        if [ "$testuser1" = "$testuser2" ]
                        then
                            foundflag=1
                            break
                        fi

                        jdx=`expr $jdx + 1`
                    done

                    if [ $foundflag -eq 0 ]
                    then
                        # add entry
                        idx=`expr $idx + 1`

                        eval 'POP3IMAP_'$idx'_USER'="$username"
                        eval 'POP3IMAP_'$idx'_PASS'="$password"
                        eval 'POP3IMAP_'$idx'_ACTIVE'="$active"

                        mecho "- importing '$username' ..."

                        # increment counter
                        POP3IMAP_N=$idx
                    else
                        # skip entry
                        mecho "- skipping '$username' - entry already exists ..."
                    fi
                fi
            fi
        done < $read_pop3imap_users
    fi
}

#------------------------------------------------------------------------------
# import mail user and password list
#------------------------------------------------------------------------------
import_mail_users ()
{
    if [ -f $read_pop3imap_users ]
    then
        mecho --info "importing $read_pop3imap_users file ..."

        # convert to unix file format
        dtou $read_pop3imap_users

        # set offset
        idx=$MAIL_USER_N
        while read line
        do
            # delete leading spaces
            line=`trim_spaces "${line}"`

            if [ "$line" != "" ]
            then
                # line not empty
                echo $line|grep -q "^#"

                if [ $? -eq 1 ]
                then
                    # no comment found - process line
                    # extract information and remove leading/trailing spaces
                    OLDIFS=$IFS
                    IFS=,

                    set $line
                    username=`trim_spaces "$1"`
                    password=`trim_spaces "$2"`
                    active=`trim_spaces "$3"`

                    IFS=$OLDIFS

                    # deactivate user by default if value not given
                    if [ "$active" = "" ]
                    then
                        active='no'
                    fi

                    # check if nick name already exists
                    jdx=1
                    foundflag=0
                    testuser1=`echo $username|tr 'A-Z' 'a-z'`
                    while [ $jdx -le $MAIL_USER_N ]
                    do
                        eval testuser2='$MAIL_USER_'$jdx'_USER'

                        testuser2=`trim_spaces "${testuser2}"|tr 'A-Z' 'a-z'`

                        if [ "$testuser1" = "$testuser2" ]
                        then
                            foundflag=1
                            break
                        fi

                        jdx=`expr $jdx + 1`
                    done

                    if [ $foundflag -eq 0 ]
                    then
                        # add entry
                        idx=`expr $idx + 1`

                        eval 'MAIL_USER_'$idx'_USER'="$username"
                        eval 'MAIL_USER_'$idx'_PASS'="$password"
                        eval 'MAIL_USER_'$idx'_ACTIVE'="$active"

                        mecho "- importing '$username' ..."

                        # increment counter
                        MAIL_USER_N=$idx
                    else
                        # skip entry
                        mecho "- skipping '$username' - entry already exists ..."
                    fi
                fi
            fi
        done < $read_pop3imap_users
    fi
}

#------------------------------------------------------------------------------
# export mail user and password list
#------------------------------------------------------------------------------
export_mail_users ()
{
    if [ $MAIL_USER_N -gt 0 ]
    then
        {
            # target file does not exist - export data
            echo "#"
            echo "# file created by $0 on `date`"
            echo "#"
            echo "#username,password,active"
        } > $read_pop3imap_users

        idx=1
        while [ $idx -le $MAIL_USER_N ]
        do
            eval active='$MAIL_USER_'$idx'_ACTIVE'
            eval username='$MAIL_USER_'$idx'_USER'
            eval password='$MAIL_USER_'$idx'_PASS'

            echo "$username,$password,$active" >> $read_pop3imap_users
            mecho "- exporting '$username' ..."

            idx=`expr $idx + 1`
        done

        mecho --info "Mail users and passwords exported to $read_pop3imap_users."
    else
        mecho --warn "Error: Nothing to export because MAIL_USER_N='0' has been set, export aborted!"
    fi
}

#------------------------------------------------------------------------------
# import fetchmail users and parameters
#------------------------------------------------------------------------------
import_fetchmail_users ()
{
#exec 2>./mailup-trace-$$.log
#set -x

    if [ -f ${read_fetchmail_users} ]
    then
        mecho --info "importing ${read_fetchmail_users} file ..."

        # convert to unix file format
        dtou ${read_fetchmail_users}

        # read first line / #v2
        fversion=`head -n1 ${read_fetchmail_users}|sed -e 's/^# *//' -e 's/ *$//'`

        # set offset
        idx=${FETCHMAIL_N}
        while read line
        do
            # delete leading spaces
            line=`trim_spaces "${line}"`

            if [ "${line}" != "" ]
            then
                # line not empty
                echo ${line}|grep -q "^#"

                if [ $? -eq 1 ]
                then
                    # no comment found - process line
                    # extract information and remove leading/trailing spaces
                    OLDIFS=${IFS}
                    IFS=,

                    set ${line}

                    fetchmail_server=`trim_spaces "$1"`
                    fetchmail_active=`trim_spaces "$2"`
                    fetchmail_user=`trim_spaces "$3"`
                    fetchmail_password=`trim_spaces "$4"`
                    fetchmail_forward=`trim_spaces "$5"`
                    fetchmail_smtphost=`trim_spaces "$6"`

                    # concatenate quoted string, separated by commata
                    eflag=0
                    sflag=0
                    fetchmail_imap_folder=''
                    while [ ${eflag} -eq 0 ]
                    do
                        # read folder name
                        ifolder=`trim_spaces "$7"`

                        # check for quote character
                        echo "${ifolder}" | grep -q \"

                        if [ $? -eq 0 ]
                        then
                            # quote character found, go on...
                            if [ ${sflag} -eq 0 ]
                            then
                                # start of quoted string - remove leading quote
                                sflag=1

                                ifolder=`echo "${ifolder}" | sed 's/^ *\" *//'`
                            fi

                            # check for quote character
                            echo "${ifolder}" | grep -q \"

                            if [ $? -eq 0 ]
                            then
                                # end of quoted string - remove trailing quote
                                ifolder=`echo "${ifolder}" | sed 's/ *\" *$//'`
                                eflag=1
                            else
                                # jump to next parameter
                                shift
                            fi
                        else
                            # no quote character found
                            if [ ${sflag} -eq 0 ]
                            then
                                # end of quoted string - remove trailing quote
                                eflag=1
                            else
                                # jump to next parameter
                                shift
                            fi
                        fi

                        # concatenate string
                        if [ "${fetchmail_imap_folder}" = "" ]
                        then
                            fetchmail_imap_folder="${ifolder}"
                        else
                            fetchmail_imap_folder="${fetchmail_imap_folder}:${ifolder}"
                        fi
                    done

                    fetchmail_domain=`trim_spaces "$8"`
                    fetchmail_envelope=`trim_spaces "$9"`
                    shift 9
                    fetchmail_server_aka_str=`trim_spaces "$1"`
                    fetchmail_localdomain_str=`trim_spaces "$2"`
                    fetchmail_protocol=`trim_spaces "$3"`
                    fetchmail_port=`trim_spaces "$4"`
                    fetchmail_auth=`trim_spaces "$5"`

                    if [ "${fversion}" = "v2" ]
                    then
                        # fetchmail export file version 2
                        fetchmail_dns_lookup=`trim_spaces "$6"`
                        shift
                    fi

                    fetchmail_keep=`trim_spaces "$6"`
                    fetchmail_fetchall=`trim_spaces "$7"`
                    fetchmail_msg_limit=`trim_spaces "$8"`
                    fetchmail_ssl_protocol=`trim_spaces "$9"`
                    shift 9
                    fetchmail_ssl_transport=`trim_spaces "$1"`
                    fetchmail_ssl_fingerprint=`trim_spaces "$2"`
                    fetchmail_comment=`trim_spaces "$3"`

                    IFS=${OLDIFS}

                    # check if nick name already exists
                    jdx=1
                    foundflag=0
                    testserver1=`echo ${fetchmail_server}|tr 'A-Z' 'a-z'`
                    testuser1=`echo ${fetchmail_user}|tr 'A-Z' 'a-z'`
                    while [ ${jdx} -le ${FETCHMAIL_N} ]
                    do
                        eval testserver2='$FETCHMAIL_'${jdx}'_SERVER'
                        eval testuser2='$FETCHMAIL_'${jdx}'_USER'

                        testserver2=`trim_spaces "${testserver2}"|tr 'A-Z' 'a-z'`
                        testuser2=`trim_spaces "${testuser2}"|tr 'A-Z' 'a-z'`

                        if [ "${testserver1}" = "${testserver2}" -a "${testuser1}" = "${testuser2}" ]
                        then
                            foundflag=1
                            break
                        fi

                        jdx=`expr ${jdx} + 1`
                    done

                    if [ $foundflag -eq 0 ]
                    then
                        # add entry
                        idx=`expr $idx + 1`

                        # deactivate user by default if value not given
                        if [ "$fetchmail_active" = "" ]
                        then
                            fetchmail_active='no'
                        fi

                        # read server aka(s)
                        echo "${fetchmail_server_aka_str}"|grep -q ":"

                        if [ $? -eq 0 ]
                        then
                            fetchmail_server_aka_n=`echo "${fetchmail_server_aka_str}"|cut -d: -f1`
                            # removed first entry
                            fetchmail_server_aka_str=`echo "${fetchmail_server_aka_str}"|cut -d: -f2-`

                            jdx=1
                            while [ $jdx -le $fetchmail_server_aka_n ]
                            do
                                echo "$fetchmail_server_aka_str"|grep -q ":"

                                if [ $? -eq 0 ]
                                then
                                    eval 'FETCHMAIL_'$idx'_SERVER_AKA_'$jdx=`echo "$fetchmail_server_aka_str"|cut -d: -f1`

                                    # removed first entry
                                    fetchmail_server_aka_str=`cut -d: -f2-`
                                else
                                    eval 'FETCHMAIL_'$idx'_SERVER_AKA_'$jdx="$fetchmail_server_aka_str"
                                fi

                                jdx=`expr $jdx + 1`
                            done
                        else
                            fetchmail_server_aka_n=0
                        fi

                        # read local domain(s)
                        echo "${fetchmail_localdomain_str}"|grep -q ":"

                        if [ $? -eq 0 ]
                        then
                            fetchmail_localdomain_n=`echo "${fetchmail_localdomain_str}"|cut -d: -f1`
                            # removed first entry
                            fetchmail_localdomain_str=`echo "${fetchmail_localdomain_str}"|cut -d: -f2-`

                            jdx=1
                            while [ ${jdx} -le ${fetchmail_localdomain_n} ]
                            do
                                echo "${fetchmail_localdomain_str}"|grep -q ":"

                                if [ $? -eq 0 ]
                                then
                                    eval 'FETCHMAIL_'${idx}'_LOCALDOMAIN_'${jdx}=`echo "${fetchmail_localdomain_str}"|cut -d: -f1`

                                    # removed first entry
                                    fetchmail_localdomain_str=`echo "${fetchmail_localdomain_str}"|cut -d: -f2-`
                                else
                                    eval 'FETCHMAIL_'${idx}'_LOCALDOMAIN_'${jdx}="${fetchmail_localdomain_str}"
                                fi

                                jdx=`expr ${jdx} + 1`
                            done
                        else
                            fetchmail_localdomain_n=0
                        fi

                        if [ "$fetchmail_domain" = "" ]
                        then
                            fetchmail_domain='no'
                        fi

                        if [ "$fetchmail_envelope" = "" ]
                        then
                            fetchmail_envelope='no'
                        fi

                        if [ "${fetchmail_dns_lookup}" = "" ]
                        then
                            fetchmail_dns_lookup='yes'
                        fi

                        if [ "$fetchmail_keep" = "" ]
                        then
                            fetchmail_keep='no'
                        fi

                        if [ "$fetchmail_fetchall" = "" ]
                        then
                            fetchmail_fetchall='no'
                        fi

                        if [ "$fetchmail_ssl_protocol" = "" ]
                        then
                            fetchmail_ssl_protocol='none'
                        fi

                        if [ "$fetchmail_ssl_transport" = "" ]
                        then
                            fetchmail_ssl_transport='no'
                        fi

                        fetchmail_imap_folder="`echo \"${fetchmail_imap_folder}\" | sed -e 's/ //g' -e 's/:/,/g'`"

                        mecho "- importing '$fetchmail_server/$fetchmail_user' ..."

                        eval 'FETCHMAIL_'${idx}'_SERVER'="$fetchmail_server"
                        eval 'FETCHMAIL_'${idx}'_ACTIVE'="$fetchmail_active"

                        # handle password differently due to possible strange characters in it
                        eval "FETCHMAIL_${idx}_COMMENT='"${fetchmail_comment}"'"
                        eval 'FETCHMAIL_'${idx}'_USER'="$fetchmail_user"

                        # handle password differently due to possible strange characters in it
                        eval "FETCHMAIL_${idx}_PASS='"${fetchmail_password}"'"
                        eval 'FETCHMAIL_'${idx}'_FORWARD'="$fetchmail_forward"
                        eval 'FETCHMAIL_'${idx}'_SMTPHOST'="$fetchmail_smtphost"
                        eval 'FETCHMAIL_'${idx}'_IMAP_FOLDER'="$fetchmail_imap_folder"
                        eval 'FETCHMAIL_'${idx}'_DOMAIN'="$fetchmail_domain"
                        eval 'FETCHMAIL_'${idx}'_ENVELOPE'="$fetchmail_envelope"
                        eval 'FETCHMAIL_'${idx}'_SERVER_AKA_N'="$fetchmail_server_aka_n"
                        eval 'FETCHMAIL_'${idx}'_LOCALDOMAIN_N'="$fetchmail_localdomain_n"
                        eval 'FETCHMAIL_'${idx}'_PROTOCOL'="$fetchmail_protocol"
                        eval 'FETCHMAIL_'${idx}'_PORT'="$fetchmail_port"
                        eval 'FETCHMAIL_'${idx}'_AUTH_TYPE'="$fetchmail_auth"
                        eval 'FETCHMAIL_'${idx}'_DNS_LOOKUP'="${fetchmail_dns_lookup}"
                        eval 'FETCHMAIL_'${idx}'_KEEP'="$fetchmail_keep"
                        eval 'FETCHMAIL_'${idx}'_FETCHALL'="$fetchmail_fetchall"
                        eval 'FETCHMAIL_'${idx}'_MSG_LIMIT'="$fetchmail_msg_limit"
                        eval 'FETCHMAIL_'${idx}'_SSL_PROTOCOL'="$fetchmail_ssl_protocol"
                        eval 'FETCHMAIL_'${idx}'_SSL_TRANSPORT'="$fetchmail_ssl_transport"
                        eval 'FETCHMAIL_'${idx}'_SSL_FINGERPRINT'="$fetchmail_ssl_fingerprint"

                        # increment counter
                        FETCHMAIL_N=${idx}
                    else
                        # skip entry
                        mecho "- skipping '${fetchmail_server}/${fetchmail_user}' - entry already exists ..."
                    fi
                fi
            fi
        done < ${read_fetchmail_users}
    fi
#set +x
}

#------------------------------------------------------------------------------
# export fetchmail users and parameters
#------------------------------------------------------------------------------
export_fetchmail_users ()
{
    if [ $FETCHMAIL_N -gt 0 ]
    then
        {
            # target file does not exist - export data
            echo "# v2"
            echo "# file created by $0 on `date`"
            echo "#"
            printf "#server,active,username,password,forward,smtphost,imap_folder,domain,envelope,"
            printf "server_aka(s),local_domain(s),protocol,port,auth,dns,keep,fetchall,msg_limit,"
            echo "ssl_protocol,ssl_transport,ssl_fingerprint,comment"
        } > $read_fetchmail_users

        idx=1
        while [ $idx -le $FETCHMAIL_N ]
        do
            eval fetchmail_active='$FETCHMAIL_'$idx'_ACTIVE'
            eval fetchmail_comment='$FETCHMAIL_'$idx'_COMMENT'
            eval fetchmail_server='$FETCHMAIL_'$idx'_SERVER'
            eval fetchmail_user='$FETCHMAIL_'$idx'_USER'
            eval fetchmail_password='$FETCHMAIL_'$idx'_PASS'
            eval fetchmail_forward='$FETCHMAIL_'$idx'_FORWARD'
            eval fetchmail_smtphost='$FETCHMAIL_'$idx'_SMTPHOST'
            eval fetchmail_imap_folder='$FETCHMAIL_'$idx'_IMAP_FOLDER'
            eval fetchmail_domain='$FETCHMAIL_'$idx'_DOMAIN'
            eval fetchmail_envelope='$FETCHMAIL_'$idx'_ENVELOPE'
            eval fetchmail_server_aka_n='$FETCHMAIL_'$idx'_SERVER_AKA_N'
            eval fetchmail_localdomain_n='$FETCHMAIL_'$idx'_LOCALDOMAIN_N'
            eval fetchmail_protocol='$FETCHMAIL_'$idx'_PROTOCOL'
            eval fetchmail_port='$FETCHMAIL_'$idx'_PORT'
            eval fetchmail_auth='$FETCHMAIL_'$idx'_AUTH_TYPE'
            eval fetchmail_dns_lookup='$FETCHMAIL_'${idx}'_DNS_LOOKUP'
            eval fetchmail_keep='$FETCHMAIL_'$idx'_KEEP'
            eval fetchmail_fetchall='$FETCHMAIL_'$idx'_FETCHALL'
            eval fetchmail_msg_limit='$FETCHMAIL_'$idx'_MSG_LIMIT'
            eval fetchmail_ssl_protocol='$FETCHMAIL_'$idx'_SSL_PROTOCOL'
            eval fetchmail_ssl_transport='$FETCHMAIL_'$idx'_SSL_TRANSPORT'
            eval fetchmail_ssl_fingerprint='$FETCHMAIL_'$idx'_SSL_FINGERPRINT'

            fetchmail_imap_folder="`echo \"${fetchmail_imap_folder}\" | sed -e 's/ //g' -e 's/,/:/g'`"

            mecho "- exporting '$fetchmail_server' ..."

            outstr="$fetchmail_server,$fetchmail_active,$fetchmail_user,$fetchmail_password,$fetchmail_forward"
            outstr="$outstr,$fetchmail_smtphost,$fetchmail_imap_folder,$fetchmail_domain,$fetchmail_envelope"
            outstr="$outstr,$fetchmail_server_aka_n"

            # alternate dns names of mailserver
            if [ $fetchmail_server_aka_n -gt 0 ]
            then
                jdx=1
                while [ $jdx -le $fetchmail_server_aka_n ]
                do
                    eval fetchmail_server_aka='$FETCHMAIL_'$idx'_SERVER_AKA_'$jdx

                    if [ "$fetchmail_server_aka" != "" ]
                    then
                        outstr="$outstr:$fetchmail_server_aka"
                    fi

                    jdx=`/usr/bin/expr $jdx + 1`
                done
            fi

            outstr="$outstr,$fetchmail_localdomain_n"

            # check against localdomains
            if [ $fetchmail_localdomain_n -gt 0 ]
            then
                jdx=1
                while [ $jdx -le $fetchmail_localdomain_n ]
                do
                    eval fetchmail_localdomain='$FETCHMAIL_'$idx'_LOCALDOMAIN_'$jdx

                    if [ "$fetchmail_localdomain" != "" ]
                    then
                        outstr="$outstr:$fetchmail_localdomain"
                    fi

                    jdx=`/usr/bin/expr $jdx + 1`
                done
            fi

            outstr="$outstr,$fetchmail_protocol,$fetchmail_port,$fetchmail_auth,${fetchmail_dns_lookup},$fetchmail_keep"
            outstr="$outstr,$fetchmail_fetchall,$fetchmail_msg_limit,$fetchmail_ssl_protocol,$fetchmail_ssl_transport"
            outstr="$outstr,$fetchmail_ssl_fingerprint,$fetchmail_comment"

            echo "$outstr" >> $read_fetchmail_users

            idx=`expr $idx + 1`
        done

        mecho --info "Fetchmail users and parameters exported to $read_fetchmail_users."
    else
        mecho --warn "Error: Nothing to export because FETCHMAIL_N='0' has been set, export aborted!"
    fi
}

#------------------------------------------------------------------------------
# create new configuration
#------------------------------------------------------------------------------
create_config ()
{
    if [ "$1" = "basic" ]
    then
        config_level="basic"
        mecho --info "preparing basic configuration ..."
    elif [ "$1" = "merge" ]
    then
        config_level="merge"
        mecho --info "merging configuration ..."
    elif [ "$1" = "advanced" ]
    then
        config_level="advanced"
        mecho --info "preparing advanced configuration ..."
    else
        config_level="advanced"
        mecho --info "updating/creating configuration ..."
    fi

    {
        echo '#------------------------------------------------------------------------------'
        echo '# /etc/config.d/mail - configuration for mail services on EIS/FAIR'
        echo '#'
        echo '# Copyright (c) 2002 Frank Meyer <frank(at)eisfair(dot)org>'
        echo '#'
        echo '# Creation:     28.04.2002  fm'
        echo "# Last Update:  `date '+%d.%m.%Y'`  jed"
        echo '#'

        if [ "$config_level" = "basic" -o "$config_level" = "merge" ]
        then
            echo "# Config Level: basic"
        else
            echo "# Config Level: advanced"
        fi

        echo '#'
        echo '# This program is free software; you can redistribute it and/or modify'
        echo '# it under the terms of the GNU General Public License as published by'
        echo '# the Free Software Foundation; either version 2 of the License, or'
        echo '# (at your option) any later version.'
        echo '#------------------------------------------------------------------------------'
        echo

        dodebug=0
        if [ "$MAIL_DO_DEBUG" = "yes" ]
        then
            # debug active
            printvar "MAIL_DO_DEBUG" "debug mode: yes or no"
            dodebug=1
        else
            # debug parameter exists but not active
            if [ -n "`grep MAIL_DO_DEBUG $source_conf`" ]
            then
                echo "# MAIL_DO_DEBUG='yes'                   # debug mode: yes or no"
                dodebug=1
            fi
        fi

        if [ "$EXISCAN_DO_DEBUG" = "yes" ]
        then
            # debug active
            printvar "EXISCAN_DO_DEBUG" "debug mode: yes or no"
            dodebug=1
        else
            # debug parameter exists but not active
            if [ -n "`grep EXISCAN_DO_DEBUG $source_conf`" ]
            then
                echo "# EXISCAN_DO_DEBUG='yes'                # debug mode: yes or no"
                dodebug=1
            fi
        fi

        if [ $dodebug -eq 1 ]
        then
            # add empty line
            echo
        fi

        printvar "START_MAIL" "activate mail package: yes or no"

        #------------------------------------------------------------------------------
        printgroup "pop3: general settings"
        #------------------------------------------------------------------------------

        printvar "START_POP3" "start POP3 server: yes or no"
        printvar "START_IMAP" "start IMAP server: yes or no"

        if [ "$config_level" != "basic" ]
        then
            echo
            printvar "POP3IMAP_CREATE_MBX"      "create mbx mailbox for imap"
            printvar "POP3IMAP_TRANSPORT"       "transport to use: default, tls or both"
            printvar "POP3IMAP_IDENT_CALLBACKS" "enable ident callbacks: yes or no"

            #------------------------------------------------------------------------------
            printgroup "mail users: names and optional passwords"
            #------------------------------------------------------------------------------

            printvar "MAIL_USER_USE_MAILONLY_PASSWORDS" "use seperate mail passwords: yes or no"
            echo
            printvar "MAIL_USER_N"                      "number of mail-accounts"

            if [ $MAIL_USER_N -eq 0 ]
            then
                imax=1
            else
                imax=$MAIL_USER_N
            fi

            idx=1
            while [ $idx -le $imax ]
            do
                eval active='$MAIL_USER_'$idx'_ACTIVE'

                # set defaults
                if [ "$active" = "" ]
                then
                    active='no'
                fi

                eval "MAIL_USER_${idx}_ACTIVE='$active'"

                # write parameters
                printvar "MAIL_USER_${idx}_ACTIVE" "$idx. activate account: yes or no"
                printvar "MAIL_USER_${idx}_USER"   "   username"
                printvar "MAIL_USER_${idx}_PASS"   "   optional mail only password"

                idx=`expr $idx + 1`
            done

            echo
            echo '#------------------------------------------------------------------------------'
            echo '# imap: shared and public folders'
            echo '#'
            echo '# Optional:'
            echo '#   Setup public or shared imap folders. This feature is not supported by'
            echo '#   some mail clients, but has succesfully tested with netscape messenger.'
            echo '#------------------------------------------------------------------------------'
            echo
            printvar "IMAP_SHARED_PUBLIC_USERGROUP" "name of usergroup for shared and"
            printvar ""                             "public folders - default: users"
            printvar "IMAP_SHARED_FOLDER_N"         "number of shared folders to create"

            if [ $IMAP_SHARED_FOLDER_N -eq 0 ]
            then
                imax=1
            else
                imax=$IMAP_SHARED_FOLDER_N
            fi

            idx=1
            while [ $idx -le $imax ]
            do
                eval active='$IMAP_SHARED_FOLDER_'$idx'_ACTIVE'

                # set defaults
                if [ "$active" = "" ]
                then
                    active='no'
                fi

                eval "IMAP_SHARED_FOLDER_${idx}_ACTIVE='$active'"

                # write parameters
                printvar "IMAP_SHARED_FOLDER_${idx}_ACTIVE"    "$idx. activate folder: yes or no"
                printvar "IMAP_SHARED_FOLDER_${idx}_NAME"      "   folder to create"
                printvar "IMAP_SHARED_FOLDER_${idx}_USERGROUP" "   individual usergroup for folder"

                idx=`expr $idx + 1`
            done

            echo
            printvar "IMAP_PUBLIC_FOLDER_N" "number of public folders to create"

            if [ $IMAP_PUBLIC_FOLDER_N -eq 0 ]
            then
                imax=1
            else
                imax=$IMAP_PUBLIC_FOLDER_N
            fi

            idx=1
            while [ $idx -le $imax ]
            do
                eval active='$IMAP_PUBLIC_FOLDER_'$idx'_ACTIVE'

                # set defaults
                if [ "$active" = "" ]
                then
                    active='no'
                fi

                eval "IMAP_PUBLIC_FOLDER_${idx}_ACTIVE='$active'"

                # write parameters
                printvar "IMAP_PUBLIC_FOLDER_${idx}_ACTIVE"    "$idx. activate folder: yes or no"
                printvar "IMAP_PUBLIC_FOLDER_${idx}_NAME"      "   folder to create"
                printvar "IMAP_PUBLIC_FOLDER_${idx}_USERGROUP" "   individual usergroup for folder"

                idx=`expr $idx + 1`
            done
        fi

        #------------------------------------------------------------------------------
        printgroup "fetchmail: general settings"
        #------------------------------------------------------------------------------

        printvar "START_FETCHMAIL"    "start FETCHMAIL client: yes or no"
        echo
        printvar "FETCHMAIL_PROTOCOL" "protocol to use, normally pop3"
        printvar "FETCHMAIL_LIMIT"    "mail size limit. Default: 4 megabytes"
        printvar "FETCHMAIL_WARNINGS" "send warnings once a day (in seconds)"
        printvar "FETCHMAIL_DAEMON"   "check every 30 minutes (in seconds)"
        printvar "FETCHMAIL_TIMEOUT"  "wait for server reply (in seconds)"

        printsetvar "FETCHMAIL_BOUNCE_MAIL" "send error mail to sender: yes or no"
        printsetvar "FETCHMAIL_BOUNCE_SPAM" "bounce spam mail to sender: yes or no"
        printsetvar "FETCHMAIL_BOUNCE_SOFT" "soft bounce mail: yes or no"

        #------------------------------------------------------------------------------
        printgroup "fetchmail: accounts"
        #------------------------------------------------------------------------------

        printvar "FETCHMAIL_N" "number of accounts to fetch"

        if [ $FETCHMAIL_N -eq 0 ]
        then
            imax=1
        else
            imax=$FETCHMAIL_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            eval fetchmail_active='$FETCHMAIL_'$idx'_ACTIVE'
            eval fetchmail_domain='$FETCHMAIL_'$idx'_DOMAIN'
            eval fetchmail_envelope='$FETCHMAIL_'$idx'_ENVELOPE'
            eval fetchmail_server_aka_n='$FETCHMAIL_'$idx'_SERVER_AKA_N'
            eval fetchmail_localdomain_n='$FETCHMAIL_'$idx'_LOCALDOMAIN_N'
            eval fetchmail_dns_lookup='$FETCHMAIL_'${idx}'_DNS_LOOKUP'
            eval fetchmail_msg_limit='$FETCHMAIL_'$idx'_MSG_LIMIT'
            eval fetchmail_ssl_protocol='$FETCHMAIL_'$idx'_SSL_PROTOCOL'
            eval fetchmail_ssl_transport='$FETCHMAIL_'$idx'_SSL_TRANSPORT'

            # set defaults
            if [ "$fetchmail_active" = "" ]
            then
                fetchmail_active='no'
                eval "FETCHMAIL_${idx}_ACTIVE='$fetchmail_active'"
            fi

            if [ "$fetchmail_domain" = "" ]
            then
                fetchmail_domain='no'
                eval "FETCHMAIL_${idx}_DOMAIN='$fetchmail_domain'"
            fi

            if [ "$fetchmail_envelope" = "" ]
            then
                fetchmail_envelope='no'
                eval "FETCHMAIL_${idx}_ENVELOPE='$fetchmail_envelope'"
            fi

            if [ "$fetchmail_server_aka_n" = "" ]
            then
                fetchmail_server_aka_n='0'
                eval "FETCHMAIL_${idx}_SERVER_AKA_N='$fetchmail_server_aka_n'"
            fi

            if [ "$fetchmail_localdomain_n" = "" ]
            then
                fetchmail_localdomain_n='0'
                eval "FETCHMAIL_${idx}_LOCALDOMAIN_N='$fetchmail_localdomain_n'"
            fi

            if [ "${fetchmail_dns_lookup}" = "" ]
            then
                fetchmail_dns_lookup='yes'
                eval "FETCHMAIL_${idx}_DNS_LOOKUP='${fetchmail_dns_lookup}'"
            fi

            if [ "$fetchmail_msg_limit" = "" ]
            then
                fetchmail_msg_limit='0'
                eval "FETCHMAIL_${idx}_MSG_LIMIT='$fetchmail_msg_limit'"
            fi

            if [ "$fetchmail_ssl_protocol" = "" ]
            then
                fetchmail_ssl_protocol='none'
                eval "FETCHMAIL_${idx}_SSL_PROTOCOL='$fetchmail_ssl_protocol'"
            fi

            if [ "$fetchmail_ssl_transport" = "" ]
            then
                fetchmail_ssl_transport='no'
                eval "FETCHMAIL_${idx}_SSL_TRANSPORT='$fetchmail_ssl_transport'"
            fi

            # write parameters
            printvar "FETCHMAIL_${idx}_ACTIVE"  "${idx}. activate fetchmail entry: yes or no"
            printvar "FETCHMAIL_${idx}_COMMENT" "   optional comment"
            printvar "FETCHMAIL_${idx}_SERVER"  "   mail server to poll"
            printvar "FETCHMAIL_${idx}_USER"    "   username and"
            printvar "FETCHMAIL_${idx}_PASS"    "   password for this server"
            printvar "FETCHMAIL_${idx}_FORWARD" "   local account to forwad to"

            if [ "$config_level" != "basic" ]
            then
                printvar "FETCHMAIL_${idx}_SMTPHOST"        "   smtp host to forward to"
                printvar "FETCHMAIL_${idx}_IMAP_FOLDER"     "   imap folders to request"
                printvar "FETCHMAIL_${idx}_DOMAIN"          "   get mail for a whole domain: yes or no"
                printvar "FETCHMAIL_${idx}_ENVELOPE"        "   if yes, lookup envelope addresses"
                printvar "FETCHMAIL_${idx}_ENVELOPE_HEADER" "   look for individual address header"
                printvar "FETCHMAIL_${idx}_SERVER_AKA_N"    "   number of dns aliases"

                if [ $fetchmail_server_aka_n -eq 0 ]
                then
                    jmax=1
                else
                    jmax=$fetchmail_server_aka_n
                fi

                jdx=1
                while [ $jdx -le $jmax ]
                do
                    printvar "FETCHMAIL_${idx}_SERVER_AKA_${jdx}" "   $jdx. dns alias"

                    jdx=`expr $jdx + 1`
                done

                printvar "FETCHMAIL_${idx}_LOCALDOMAIN_N" "   number of local domains"

                if [ $fetchmail_localdomain_n -eq 0 ]
                then
                    jmax=2
                else
                    jmax=$fetchmail_localdomain_n
                fi

                jdx=1
                while [ $jdx -le $jmax ]
                do
                    printvar "FETCHMAIL_${idx}_LOCALDOMAIN_${jdx}" "   $jdx. local domain"

                    jdx=`expr $jdx + 1`
                done

                printvar "FETCHMAIL_${idx}_PROTOCOL"          "   set a different protocol"
                printvar "FETCHMAIL_${idx}_PORT"              "   set a different ip port"
                printvar "FETCHMAIL_${idx}_AUTH_TYPE"         "   set a different authentication type"
                printvar "FETCHMAIL_${idx}_ACCEPT_BAD_HEADER" "   accept bad email headers: yes or no"
                printvar "FETCHMAIL_${idx}_DNS_LOOKUP"        "   if yes dns lookups are performed"
            fi

            printvar "FETCHMAIL_${idx}_KEEP"     "   if yes mail is left on the server"
            printvar "FETCHMAIL_${idx}_FETCHALL" "   if yes all mail is fetched from the server"

            if [ "$config_level" != "basic" ]
            then
                printvar "FETCHMAIL_${idx}_MSG_LIMIT"       "   number of messages per session"
                printvar "FETCHMAIL_${idx}_SSL_PROTOCOL"    "   ssl protocol: none, ssl3 or tls1"
                printvar "FETCHMAIL_${idx}_SSL_TRANSPORT"   "   enable ssl transport"
                printvar "FETCHMAIL_${idx}_SSL_FINGERPRINT" "   ssl fingerprint"
            fi

            if [  $idx -le `expr $imax - 1` ]
            then
                echo "#------------------------------------------------------------------------------"
            fi
            idx=`expr $idx + 1`
        done

        #------------------------------------------------------------------------------
        printgroup "smtp: general settings"
        #------------------------------------------------------------------------------

        printvar "START_SMTP"                       "start SMTP server: yes or no"
        echo
        printvar "SMTP_QUALIFY_DOMAIN"              "domain to be added to all unqualified addresses"
        printvar "SMTP_HOSTNAME"                    "canonical hostname of eisfair server"
        printvar "SMTP_QUEUE_INTERVAL"              "queueing interval in minutes, usually 30"
        printvar "SMTP_QUEUE_OUTBOUND_MAIL"         "set to yes if you are using a dialup ISP"
        printvar ""                                 "and you want to queue outbound mail until"
        printvar ""                                 "next queue run which must be initiated"
        printvar ""                                 "manually or by a cron-job"
        printvar "SMTP_QUEUE_ACCEPT_PER_CONNECTION" "msg number to accept in one smtp session"
        printvar "SMTP_LISTEN_PORT"                 "port(s) on which Exim is listening for inbound"
        printvar ""                                 "traffic, default is 'smtp' and 'submission'"

        if [ "$config_level" != "basic" ]
        then
            printvar "SMTP_MAIL_TO_UNKNOWN_USERS" "how to handle mail to unknown mail users:"
            printvar ""                           "bounce, copy or forward, default is 'bounce'"
            printvar "SMTP_ALLOW_EXIM_FILTERS"    "allow exim filters in .forward file: yes or no"
            echo
            printvar "SMTP_CHECK_RECIPIENTS"      "check that not more than the given number of"
            printvar ""                           "recipients per mail are addressed at once."
            printvar ""                           "Default is being set to 100"
            printvar "SMTP_CHECK_SPOOL_SPACE"     " check if enough disk space for spool directory"
            printvar ""                           "is available. Default is being set to 10Mb"
            printvar "SMTP_CHECK_SPOOL_INODES"    "check if enough inodes for spool directory"
            printvar ""                           "are available. Default is being set to 100"
            echo
            printvar "SMTP_LIMIT"                 "mail size limit. Default is being set to 50Mb"
            echo
            printvar "SMTP_REMOVE_RECEIPT_REQUEST"      "remove external receipt request: yes or no"
            echo
            printvar "SMTP_SERVER_TRANSPORT"            "transport to use: default, tls or both"
            printvar "SMTP_IDENT_CALLBACKS"             "enable ident callbacks: yes or no"
            printvar "SMTP_SERVER_TLS_ADVERTISE_HOSTS"  "advertise STARTLS to these hosts, to disable"
            printvar ""                                 "this feature set to '' (required for tls!)"
            printvar "SMTP_SERVER_TLS_VERIFY_HOSTS"     "verify tls certs of these hosts, to diasble"
            printvar ""                                 " this feature set to ''"
            printvar "SMTP_SERVER_TLS_TRY_VERIFY_HOSTS" "try to verify tls certs of these hosts, to"
            printvar ""                                 "disable this feature set to ''"

            echo
            printvar "SMTP_SERVER_SSMTP"               "start SSMTP server: yes or no"
            printvar "SMTP_SERVER_SSMTP_LISTEN_PORT"   "port on which Exim is listening for"
            printvar ""                                "inbound traffic, default is 'ssmtp'"
        fi

        #------------------------------------------------------------------------------
        printgroup "smtp: local domains"
        #------------------------------------------------------------------------------

        printvar "SMTP_LOCAL_DOMAIN_N" "number of local domains"

        if [ $SMTP_LOCAL_DOMAIN_N -eq 0 ]
        then
            imax=3
        else
            imax=$SMTP_LOCAL_DOMAIN_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            if [ $idx -eq 1 ]
            then
                comment="$idx. local domain, @ means SMTP_HOSTNAME"
            else
                comment="$idx. local domain"
            fi

            printvar "SMTP_LOCAL_DOMAIN_${idx}" "$comment"

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: relay to domains'
        echo '#'
        echo '# Optional:'
        echo '#   The folllowing setting specify domains for which your host is an incoming'
        echo '#   relay. If you are not doing any relaying, you should leave the list empty.'
        echo '#   However, if your host is an MX backup or gateway of some kind for some'
        echo '#   domains, you must set SMTP_RELAY_TO_DOMAIN_x to match those domains.'
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_RELAY_TO_DOMAIN_N" "domains for which we are incoming relay"

        if [ $SMTP_RELAY_TO_DOMAIN_N -eq 0 ]
        then
            imax=1
        else
            imax=$SMTP_RELAY_TO_DOMAIN_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "SMTP_RELAY_TO_DOMAIN_${idx}"

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: relay from hosts'
        echo '#'
        echo '# The following settings specify hosts that can use your host as an'
        echo '# outgoing relay to any other host on the Internet. Such a setting'
        echo '# commonly refers to a complete local network as well as the localhost.'
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_RELAY_FROM_HOST_N" "hosts/nets from we accept outgoing mails"

        if [ $SMTP_RELAY_FROM_HOST_N -eq 0 ]
        then
            imax=2
        else
            imax=$SMTP_RELAY_FROM_HOST_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "SMTP_RELAY_FROM_HOST_${idx}"

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: server authentication'
        echo '#'
        echo '# Optional:'
        echo '#   Set the type of server authentication.'
        echo '#   none   - no authentication'
        echo '#   user   - each user authenticates himself by his username/password'
        echo '#   server - all users authenticate themself by sending a global user/pass'
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_AUTH_TYPE" "authentication: none, user, server,"
        printvar ""               "user_light or server_light"
        printvar "SMTP_AUTH_USER" "if server: global username, else empty"
        printvar "SMTP_AUTH_PASS" "if server: global password, else empty"
        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: smarthosts'
        echo '#'
        echo '# Optional:'
        echo '#   Send all outgoing messages to a smarthost (e.g. mail server of your isp).'
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_SMARTHOST_ONE_FOR_ALL" "use one smarthost for all accounts:"
        printvar ""                           "if 'yes', the first entry will be read"
        printvar ""                           "if 'no', user specific entries will be used"

        if [ "$config_level" != "basic" ]
        then
            printvar "SMTP_SMARTHOST_DOMAINS"    "if SMTP_SMARTHOST_ONE_FOR_ALL='yes' then"
            printvar ""                          "use it only for these domains (separated by ':')"
            printvar "SMTP_SMARTHOST_ROUTE_TYPE" "if SMTP_SMARTHOST_ONE_FOR_ALL='no' then how"
            printvar ""                          "to select smarthost:  by sender mail 'addr'essi"
            printvar ""                          "or destination 'domain'"
        fi

        echo
        printvar "SMTP_SMARTHOST_N" "number of smarthost entries"

        if [ $SMTP_SMARTHOST_N -eq 0 ]
        then
            imax=1
        else
            imax=$SMTP_SMARTHOST_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            eval sh_auth='$SMTP_SMARTHOST_'$idx'_AUTH_TYPE'
            eval sh_fauth='$SMTP_SMARTHOST_'$idx'_FORCE_AUTH'
            eval sh_ftls='$SMTP_SMARTHOST_'$idx'_FORCE_TLS'

            # set defaults
            if [ "$sh_auth" = "" ]
            then
                sh_auth='none'
                eval "SMTP_SMARTHOST_${idx}_AUTH_TYPE='$sh_auth'"
            fi

            if [ "$sh_fauth" = "" ]
            then
                sh_fauth='no'
                eval "SMTP_SMARTHOST_${idx}_FORCE_AUTH='$sh_fauth'"
            fi

            if [ "$sh_ftls" = "" ]
            then
                sh_ftls='no'
                eval "SMTP_SMARTHOST_${idx}_FORCE_TLS='$sh_ftls'"
            fi

            # write parameters
            printvar "SMTP_SMARTHOST_${idx}_HOST"      "${idx}. smart host to send mail to, e.g. mail.gmx.net"
            printvar "SMTP_SMARTHOST_${idx}_AUTH_TYPE" "   'none', 'plain', 'login', 'md5' or 'msn'"

            if [ "$config_level" != "basic" ]
            then
                printvar "SMTP_SMARTHOST_${idx}_ADDR"   "   if SMTP_SMARTHOST_ROUTE_TYPE='addr': sender mail address"
                printvar "SMTP_SMARTHOST_${idx}_DOMAIN" "   if SMTP_SMARTHOST_ROUTE_TYPE='domain': destination domain"
            fi

            printvar "SMTP_SMARTHOST_${idx}_USER" "   if authentication required: username"
            printvar "SMTP_SMARTHOST_${idx}_PASS" "   if authentication required: password"

            if [ "$config_level" != "basic" ]
            then
                printvar "SMTP_SMARTHOST_${idx}_FORCE_AUTH" "   set to 'yes' to allow only authenticated connections"
                printvar "SMTP_SMARTHOST_${idx}_FORCE_TLS"  "   set to 'yes' to allow only secure connections"
                printvar "SMTP_SMARTHOST_${idx}_PORT"       "   port to use for outgoing connections, default is 'smtp'"
            fi

            if [  $idx -le `expr $imax - 1` ]
            then
                echo "#------------------------------------------------------------------------------"
            fi

            idx=`expr $idx + 1`
        done

        if [ "$config_level" != "basic" ]
        then
            #------------------------------------------------------------------------------
            printgroup "smtp: update ignore hosts file"
            #------------------------------------------------------------------------------

            printvar "SMTP_UPDATE_IGNORE_HOSTS"               "update ignore hosts: yes or no"
            printvar "SMTP_UPDATE_IGNORE_HOSTS_CRON_SCHEDULE" "cron configuration string"
        fi

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: aliases'
        echo '#'
        echo '# Here you can specify aliases'
        echo '#'
        echo '# General format:'
        echo "#   SMTP_ALIASES_x_ALIAS_y='name: user1[,user2,...]"
        echo '#'
        echo '# Example:'
        echo "#   SMTP_ALIASES_N='2'"
        echo '#   ...'
        echo "#   SMTP_ALIASES_2_DOMAIN='2nd.local.lan'"
        echo "#   SMTP_ALIASES_2_ALIAS_N='1'"
        echo "#   SMTP_ALIASES_2_ALIAS_1='frank: fm,foo@otherwhere.com'"
        echo '#'
        echo '# Mails to frank@domain.de will be delivered to local user fm and to'
        echo '# user foo@otherwhere.com.'
        echo '#------------------------------------------------------------------------------'
        echo

        if [ "$config_level" != "basic" ]
        then
            printvar "SMTP_ALIASES_N" "number of domains: default: 1"
        fi

        if [ $SMTP_ALIASES_N -eq 0 ]
        then
            imax=1
        else
            imax=$SMTP_ALIASES_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            eval aliases_entry_nbr='$SMTP_ALIASES_'$idx'_ALIAS_N'

            # set defaults
            if [ "$aliases_entry_nbr" = "" ]
            then
                aliases_entry_nbr='0'
                eval "SMTP_ALIASES_${idx}_ALIAS_N='$aliases_entry_nbr'"
            fi

            # write parameters
            if [ "$config_level" != "basic" ]
            then
                printvar "SMTP_ALIASES_${idx}_DOMAIN" "${idx}. domain name: will only be read if SMTP_ALIASES_N > 1"
                printvar ""                           "   and not SMTP_ALIASES_1_DOMAIN"
            fi

            printvar "SMTP_ALIASES_${idx}_ALIAS_N" "   number of aliases"

            if [ $aliases_entry_nbr -eq 0 ]
            then
                jmax=2
            else
                jmax=$aliases_entry_nbr
            fi

            jdx=1
            while [ $jdx -le $jmax ]
            do
                if [ $jdx -eq 1 ]
                then
                    comment="${jdx}. alias must be for user 'root'!"
                else
                    comment="${jdx}. alias"
                fi

                printvar "SMTP_ALIASES_${idx}_ALIAS_${jdx}" "   $comment"

                jdx=`expr $jdx + 1`
            done

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: outgoing addresses'
        echo '#'
        echo '# Here you can specify an address translation table which is only available'
        echo '# if SMTP_SMARTHOST_N has been set to a value greater than 0.'
        echo '#'
        echo '# General format:'
        echo "#   SMTP_OUTGOING_ADDRESSES_x='name: email address'"
        echo '#'
        echo '# Example:'
        echo "#   SMTP_OUTGOING_ADDRESSES_1='fm: frank@domain.de'"
        echo '#'
        echo "#   Mail from local user 'fm' will be delivered by using sender address"
        echo "#   'frank@domain.de'."
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_OUTGOING_ADDRESSES_N" ""

        if [ $SMTP_OUTGOING_ADDRESSES_N -eq 0 ]
        then
            imax=1
        else
            imax=$SMTP_OUTGOING_ADDRESSES_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "SMTP_OUTGOING_ADDRESSES_${idx}" ""

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: incoming addresses'
        echo '#'
        echo '# Example:'
        echo "#   SMTP_HEADER_REWRITE_1_SOURCE='*@home.lan'"
        echo "#   SMTP_HEADER_REWRITE_1_DESTINATION='\$1@domain.de'"
        echo "#   SMTP_HEADER_REWRITE_1_FLAGS='sF'"
        echo '#'
        echo '#   The envelope from address and the sender of an incoming smtp mail from'
        echo "#   user 'frank@home.lan' will be rewritten to 'frank@domain.de'"
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_HEADER_REWRITE_N" "number of rewrite rules"

        if [ $SMTP_HEADER_REWRITE_N -eq 0 ]
        then
            imax=1
        else
            imax=$SMTP_HEADER_REWRITE_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            printvar "SMTP_HEADER_REWRITE_${idx}_SOURCE"      "${idx}. search mask"
            printvar "SMTP_HEADER_REWRITE_${idx}_DESTINATION" "   replace string"
            printvar "SMTP_HEADER_REWRITE_${idx}_FLAGS"       "   what to rewrite"

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# smtp: mailing lists'
        echo '#'
        echo '# Here you can specify simple mailing lists'
        echo '#'
        echo '# Explanation of example below:'
        echo '#'
        echo "# A mail to 'eisfair@domain.de' will be delivered to all members in the list."
        echo "# The reply address will be changed to 'eisfair@domain.de'!"
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "SMTP_LIST_DOMAIN" "domain part of mailing list addrs"
        printvar "SMTP_LIST_ERRORS" "send error messages to this address"
        echo
        printvar "SMTP_LIST_N"      "number of mailing lists"

        if [ $SMTP_LIST_N -eq 0 ]
        then
            imax=2
        else
            imax=$SMTP_LIST_N
        fi

        idx=1
        while [ $idx -le $imax ]
        do
            eval list_user_n='$SMTP_LIST_'$idx'_USER_N'

            # set defaults
            if [ "$list_user_n" = "" ]
            then
                list_user_n=0
                eval "SMTP_LIST_${idx}_USER_N='$list_user_n'"
            fi

            # write parameters
            printvar "SMTP_LIST_${idx}_ACTIVE" "${idx}. activate list: yes or no"
            printvar "SMTP_LIST_${idx}_NAME"   "   name of list"
            printvar "SMTP_LIST_${idx}_USER_N" "   number of list members"

            if [ $list_user_n -eq 0 ]
            then
                jmax=2
            else
                jmax=$list_user_n
            fi

            jdx=1
            while [ $jdx -le $jmax ]
            do
                printvar "SMTP_LIST_${idx}_USER_${jdx}" "   ${jdx}. member"

                jdx=`expr $jdx + 1`
            done

            if [  $idx -le `expr $imax - 1` ]
            then
                echo "#------------------------------------------------------------------------------"
            fi

            idx=`expr $idx + 1`
        done

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# exiscan: virus scanning'
        echo '#'
        echo '# Here you can specify an additinal antivirus scanner Please make sure'
        echo '# that you have installed a antivirus software prior you enable these feature.'
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "START_EXISCAN" "start EXISCAN: yes or no"
        echo
        printvar "EXISCAN_ACTION_ON_FAILURE" "action on scanner failure: defer, drop, pass"
        printvar "EXISCAN_CRYPT_SALT"        "crypt salt - \`must' be set to a character string!"
        printvar "EXISCAN_DEMIME_ENABLED"    "unpack mime containers: yes or no"
        printvar "EXISCAN_DEMIME_ACTION"     "action on mime exploiis: pass, reject, discard,"
        printvar ""                          "freeze, redirect <address>"
        echo
        printvar "EXISCAN_AV_ENABLED"            "use viruscanner: yes or no"
        printvar "EXISCAN_AV_ACTION"             "action on virus: pass, reject, discard, freeze,"
        printvar ""                              "redirect <address>"
        printvar "EXISCAN_AV_SUBJECT_TAG"        "mark subject with tag, only usefull if"
        printvar ""                              "EXISCAN_AV_ACTION has been set to 'pass'"
        printvar "EXISCAN_AV_SCANNER"            "scanner: auto, cmdline, sophie, kavdaemon, clamd,"
        printvar ""                              "drweb, mksd"
        printvar "EXISCAN_AV_PATH"               "path to antivirus scanner"
        printvar "EXISCAN_AV_OPTIONS"            "cmdline option for scanner incl. '%s'"
        printvar "EXISCAN_AV_TRIGGER"            "regexp string if virus has been found"
        printvar "EXISCAN_AV_DESCRIPTION"        "grep virus name from regexp description"
        printvar "EXISCAN_AV_SOCKET"             "socket for sophie, kavdaemon, clamav ..."
        printvar "EXISCAN_AV_SKIP_AUTHENTICATED" "skip scan for authenticated users"
        echo
        printvar "EXISCAN_EXTENSION_ENABLED" "use extension checking: yes or no"
        printvar "EXISCAN_EXTENSION_ACTION"  "action on extension: pass, reject, discard,"
        printvar ""                          "freeze, redirect <address>"
        printvar "EXISCAN_EXTENSION_DATA"    "filter 'exe', 'com' and 'vbs' extensions"
        echo
        printvar "EXISCAN_REGEX_ENABLED"  "use regex checking: yes or no"
        printvar "EXISCAN_REGEX_ACTION"   "action on regex: pass, reject, discard, freeze,"
        printvar ""                       "redirect <address>"
        printvar "EXISCAN_REGEX_DATA"     "filter '[Mm]ortage' and 'make money' strings"
        echo
        printvar "EXISCAN_SPAMD_ENABLED"            "use spamd checking: yes or no"
        printvar "EXISCAN_SPAMD_ACTION"             "action on spamd: pass, reject, discard, freeze,"
        printvar ""                                 "redirect <address>"
        printvar "EXISCAN_SPAMD_HEADER_STYLE"       "type of X-header: none, single, flag, full"
        printvar ""                                 "alwaysfull"
        printvar "EXISCAN_SPAMD_SUBJECT_TAG"        "mark subject with tag, only usefull if"
        printvar ""                                 "EXISCAN_SPAMD_ACTION has been set to 'pass'"
        printvar "EXISCAN_SPAMD_THRESHOLD"          "spamd score threshold"
        printvar "EXISCAN_SPAMD_ADDRESS"            "address on which spamd is listening"
        printvar "EXISCAN_SPAMD_LIMIT"              "mail size limit, default: no limit"
        printvar "EXISCAN_SPAMD_SKIP_AUTHENTICATED" "skip scan for authenticated users"

        if [ "$config_level" != "basic" ]
        then
            #------------------------------------------------------------------------------
            printgroup "mail: send warning if TLS certificates will become invalid"
            #------------------------------------------------------------------------------

            printvar "MAIL_CERTS_WARNING"               "send certs warning: yes or no"
            printvar "MAIL_CERTS_WARNING_SUBJECT"       "subject of warning mail"
            printvar "MAIL_CERTS_WARNING_CRON_SCHEDULE" "cron configuration string"

            #------------------------------------------------------------------------------
            printgroup "mail: send exim statistics"
            #------------------------------------------------------------------------------

            printvar "MAIL_STATISTICS_INFOMAIL"               "send statistics infomail: yes or no"
            printvar "MAIL_STATISTICS_INFOMAIL_SUBJECT"       "subject of infomail"
            printvar "MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE" "cron configuration string"

            if [ "${MAIL_STATISTICS_INFOMAIL_OPTIONS}" != "" ]
            then
                printvar "MAIL_STATISTICS_INFOMAIL_OPTIONS"   "set individual eximstats parameters"
            fi
        fi

        echo
        echo '#------------------------------------------------------------------------------'
        echo '# mail: log handling'
        echo '#'
        echo '# Here you can specify how many logs should be saved and in with interval.'
        echo '#'
        echo '# Example:'
        echo "#   MAIL_LOG_COUNT='10' - save the last 10 log files"
        echo "#   MAIL_LOG_INTERVAL='daily' - save one log file per day"
        echo '#------------------------------------------------------------------------------'
        echo
        printvar "MAIL_LOG_COUNT"    "number of log files to save"
        printvar "MAIL_LOG_INTERVAL" "interval: daily, weekly, monthly"

        #------------------------------------------------------------------------------
        printend
        #------------------------------------------------------------------------------
    } > $generate_conf
}

#==============================================================================
# main
#==============================================================================

# set variables
#testroot=/soft/jedmail
 testroot=''

basefile=$testroot/etc/config.d/base
mailfile=$testroot/etc/config.d/mail
installfile=$testroot/var/run/mail.install
basicfile=$mailfile.basic
advancedfile=$mailfile.advanced
fullfile=$mailfile.full
conf_tmpdir=/var/spool/exim
read_pop3imap_users=$testroot/var/spool/exim/pop3imap.csv
read_fetchmail_users=$testroot/var/spool/exim/fetchmail.csv
host_name="`hostname -s`"                      # use of $HOSTNAME is a bashism!

# setting defaults
source_conf=$installfile
generate_conf=$mailfile

cmd="$1"
goflag=0
case "${cmd}" in
    init|update)
        # update configuration
        goflag=1
        ;;

    import)
        # import pop3imap user list
        if [ -f $read_pop3imap_users -o -f $read_fetchmail_users ]
        then
            /var/install/bin/backup-file --quiet $mailfile

            source_conf=$conf_tmpdir/`basename $mailfile`.tmp
            mv $mailfile $source_conf

            generate_conf=$testroot/etc/config.d/mk_mail.test        # test
            goflag=1
        fi
        ;;

    export)
        # export pop3imap user list
        if [ -f $read_pop3imap_users ]
        then
            /var/install/bin/backup-file --quiet $read_pop3imap_users backup
        fi

        if [ -f $read_fetchmail_users ]
        then
            /var/install/bin/backup-file --quiet $read_fetchmail_users backup
        fi

        source_conf=$mailfile
        . $source_conf

        export_mail_users
        export_fetchmail_users
        goflag=0
        ;;

    basic)
        # create basic configuration
        source_conf=$mailfile
        generate_conf=$basicfile
        goflag=2
        ;;

    advanced)
        # create advanced configuration
        source_conf=$mailfile
        generate_conf=$advancedfile
        goflag=3
        ;;

    merge)
        # merge basic configuration
        cp $mailfile $fullfile

        source_conf=$mailfile                                     # .full will be added later
        generate_conf=$mailfile
        goflag=4
        ;;

    test)
        source_conf=$mailfile
        generate_conf=$conf_tmpdir/mk_mail.test
        goflag=1
        ;;

    *)
        mecho
        mecho "Use one of the following options:"
        mecho
        mecho "  mail-update.sh [import] - the pop3/imap users from the file $read_pop3imap_users"
        mecho "                            will be imported in the mail configuration file."
        mecho
        mecho "  mail-update.sh [export] - the pop3/imap users from  mail configuration file will"
        mecho "                            will be exported to the file $read_pop3imap_users"
        mecho
        mecho "  mail-update.sh [update] - the file $mailfile.import will be read, the configuration will"
        mecho "                            be checked and an updated mail configuration file will be written."
        mecho
        goflag=0
esac

case $goflag
in
    1)
        # update configuration
        if [ -f ${source_conf} ]
        then
            # previous configuration file exists
            . ${source_conf}

            if [ "${cmd}" = "init" ]
            then
                # update initial parameters
                . ${basefile}

                SMTP_QUALIFY_DOMAIN="${DOMAIN_NAME}"
                SMTP_HOSTNAME="${host_name}.${DOMAIN_NAME}"
                SMTP_LOCAL_DOMAIN_3="${DOMAIN_NAME}"
            fi

            if [ "${POP3IMAP_N}" != "" ]
            then
                # old parameter naming - POP3IMAP_..
                import_pop3imap_users
            else
                # new parameter naming - MAIL_USER_..
                import_mail_users
            fi

            import_fetchmail_users

            rename_variables
            modify_variables
            add_variables
            delete_variables

            create_config

            anykey

            # remove tmp file
            rm -f $conf_tmpdir/`basename $mailfile`.tmp
        else
            mecho --error "no configuration $source_conf found - exiting."
        fi
        ;;

    2)
        # create basic configuration
        if [ -f $source_conf ]
        then
            # previous configuration file exists
            . $source_conf

            create_config basic
        fi
        ;;

    3)
        # create advanced configuration
        if [ -f $source_conf ]
        then
            # previous configuration file exists
            . $source_conf

            create_config advanced
        fi
        ;;

    4)
        # merge basic configuration
        if [ -f $fullfile ]
        then
            # full  configuration file exists
            . $fullfile

            if [ -f $basicfile ]
            then
                # basic configuration file exists
                . $basicfile
            fi

            create_config merge

            # remove temporary file
            rm -f $fullfile
            rm -f $basicfile
        fi
        ;;
esac

#==============================================================================
# end
#==============================================================================
