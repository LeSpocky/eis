#!/bin/bash
#----------------------------------------------------------------------------------------
# /var/install/config.d/mail.sh - configuration generator script for Mail server
# Copyright (c) 2001-2015 The Eisfair Team, team(at)eisfair(dot)org
# Creation:     2002-04-28 fm
#
# Options/Parameters:
#
#        --noconfirm                                 - don't show and confirm configlog screen
#
#        mail.sh [--noconfirm]                       - generates all configuration files
#        mail.sh [--noconfirm][--fetchone][fetchmail account number]
#                                                    - generate fetchmail.conf for a single account
#        mail.sh [--noconfirm][--alias]              - recreate aliases file
#        mail.sh [--noconfirm][--ignorehosts]        - create ignore hosts file
#        mail.sh [--noconfirm][--sendstatistics]     - send mail server statistics to the postmaster
#        mail.sh [--noconfirm][--showcertdates]      - show ssl certification dates
#        mail.sh [--noconfirm][--sendcertwarning]    - send ssl certification warning to the postmaster
#        mail.sh [--noconfirm][--updatemodulesmenu]  - force update of modules menu
#        mail.sh [--noconfirm][--updatemailpw]       - force update of mail password file
#        mail.sh [--getdomain]                       - print smtp domain name
#        mail.sh [--version]                         - print versions
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------------------

# read eislib etc.
. /var/install/include/eislib
. /var/install/include/check-eisfair-version
. /var/install/include/mail

#exec 2>/var/install/config.d/mail-trace-$$.log
#set -x
#testroot=/soft/jedmail                                            # only for testing
 testroot=""

pgmname=`basename $0`

# set platform specific parameters
case ${EISFAIR_SYSTEM} in
    eisfair-1)
        # eisfair-1
        crontab_path=${testroot}/var/cron/etc/root
        mail2print_addresses=${testroot}/var/mail2print/senderaddresses

        exim_uid='42'
        exim_gid='42'
        ;;
    *)
        # default to eisfair-2
        crontab_path=${testroot}/etc/cron/root
        mail2print_addresses=${testroot}/data/packages/mail2print/senderaddresses

        exim_uid='142'
        exim_gid='142'
        ;;
esac

### set path names ###
eximstart_path=${testroot}/etc/init.d
eximmain_path=${testroot}/usr/local/exim
eximbin_path=${eximmain_path}/bin
mailspool_path=${testroot}/var/spool/mail
eximspool_path=${testroot}/var/spool/exim
mailinglists_path=${eximspool_path}/mailinglists
mailmanmain_path=${testroot}/usr/local/mailman
mailmanspool_path=${testroot}/var/mailman
systemlog_path=${testroot}/var/log
sslcert_path=${testroot}/usr/local/ssl/certs
sslcrl_path=${testroot}/usr/local/ssl/crl
install_bin_path=${testroot}/var/install/bin
install_menu_path=${testroot}/var/install/menu

### set file names ###
antispamfile=${testroot}/etc/config.d/antispam
eisfaxfile=${testroot}/etc/config.d/eisfax
mail2printfile=${testroot}/etc/config.d/mail2print
mailmanfile=${testroot}/etc/config.d/mailman
mailquotafile=${testroot}/etc/config.d/mailquota
passwdfile=${testroot}/etc/passwd
groupfile=${testroot}/etc/group
snfile=${testroot}/etc/config.d/sn
uucpfile=${testroot}/etc/config.d/uucp
roundcubefile=${testroot}/etc/config.d/roundcube
webmailfile=${testroot}/etc/config.d/webmail
mailfile=${testroot}/etc/config.d/mail
eisfax_addresses=${testroot}/var/lib/eisfax/senderaddresses
mail_configfile=${testroot}/var/install/config.d/mail.sh
mailquota_configfile=${testroot}/var/install/config.d/mailquota.sh
configlog_file=${eximspool_path}/log/mail-configlog
custom_systemfilter=${eximspool_path}/custom-systemfilter
recipient_okfile=${eximspool_path}/recipients_ok.list
packagefile=${testroot}/var/install/packages/mail
spf_aclfile=${eximspool_path}/exim-spf-acl
spf_aclrcptfile=${eximspool_path}/exim-spf-acl-check-rcpt
exiscan_av_parameters=${testroot}/var/spool/exim/exiscan-av.cnf
toggle_mailaccess=${testroot}/etc/mail-nologin
uucp_compression=${testroot}/etc/uucp-compression
generate_pop3imappwd=${testroot}/etc/cram-md5.pwd
generate_cclientconf=${testroot}/etc/c-client.cf
generate_fetchconf=${testroot}/etc/fetchmail.conf
generate_fetchident=${eximspool_path}/fetchmail-identity
generate_eximconf=${eximspool_path}/configure
generate_aliases=${testroot}/etc/aliases
generate_services=${testroot}/etc/services.mail
generate_pop3conf=${testroot}/etc/xinetd.d/pop3
generate_imapconf=${testroot}/etc/xinetd.d/imap
generate_addresses=${testroot}/etc/exim-addresses
generate_smarthosts=${testroot}/etc/exim-smarthosts
generate_queued=${testroot}/etc/exim-queued
generate_logrotate=${testroot}/etc/logrotate.d/mail
generate_mailrc=${testroot}/etc/mail.rc
generate_crontab=${crontab_path}/mail
generate_localdomains=${testroot}/etc/exim-localdomains
generate_mysenderdomains=${testroot}/etc/exim-mysenderdomains
generate_relaytodomains=${testroot}/etc/exim-relaytodomains
generate_mailmandomains=${testroot}/etc/exim-mailmandomains
generate_relayfromhosts=${testroot}/etc/exim-relayfromhosts
generate_imapshared=${testroot}/etc/exim-imapshared
generate_imappublic=${testroot}/etc/exim-imappublic
generate_systemfilter=${testroot}/etc/exim-systemfilter
generate_ignorehosts=${testroot}/etc/exim-ignorehosts
generate_installedlist=${eximspool_path}/exim-installed.info

zone_file=root.zone.gz
zone_url1="http://internic.net/domain/${zone_file}"
zone_url2="ftp://ftp.internic.net/domain/${zone_file}"

### other parameters ###
mail_version="v`grep "<version>" ${packagefile} | sed 's#<version>\(.*\)</version>#\1#'`"
mail_subdir=".imapmail"

### load configuration ###
. ${mailfile}
chmod 600 ${mailfile}

#----------------------------------------------------------------------------------------
# creating fetchmail mail exchange password
#----------------------------------------------------------------------------------------
create_fetchmail_password ()
{
    if [ ! -f ${generate_fetchident} ]
    then
        # create random account and password
        fetchmail_esmtp_name="fetch-`rand_string 5`"
        fetchmail_esmtp_pass="`rand_string 10`"

        {
            echo "FETCHMAIL_ESMTP_NAME=\"${fetchmail_esmtp_name}\""
            echo "FETCHMAIL_ESMTP_PASS=\"${fetchmail_esmtp_pass}\""
        } > ${generate_fetchident}
    fi

    # set access rights
    chmod 600     ${generate_fetchident}
    chown exim    ${generate_fetchident}
    chgrp trusted ${generate_fetchident}
}

#----------------------------------------------------------------------------------------
# creating/removing fetchmail user
#----------------------------------------------------------------------------------------
create_fetchmail_user ()
{
    if [ "${MAIL_USER_USE_MAILONLY_PASSWORDS}" = "no" ]
    then
        # create system account
        write_to_config_log -warn     "Due to MAIL_USER_USE_MAILONLY_PASSWORDS='no' all passwords will be"
        write_to_config_log -warn -ff "send as clear text. It is recommended to use at least a TLS secured"
        write_to_config_log -warn -ff "connection otherwise this might be a potential security vulnerability!"

        # fetchmail user and group
        case ${SMTP_AUTH_TYPE} in
            server*)
                # server / server_light
                user="${SMTP_AUTH_USER}"
                pass="${SMTP_AUTH_PASS}"
                ;;
            user*)
                # user / user_light
                user="${FETCHMAIL_ESMTP_NAME}"
                pass="${FETCHMAIL_ESMTP_PASS}"
                ;;
            none|*)
                user=''
                ;;
        esac

        if [ "${user}" != "" ]
        then
            # SMTP_TYPE_USER='user*' or SMTP_TYPE_USER='server*' has been set
            uid=''
            group='trusted'
            name='fetchmail esmtp name'
            homedir='/home/fetchmail'
            shell='/bin/false'

            # check group
            grep -q "^${group}:" /etc/group

            if [ $? -ne 0 ]
            then
                mecho "adding group '${group}' ..."
                ${install_bin_path}/add-group ${group} ${exim_gid}
            fi

            # make sure that no previous fetchmail account exists
            for FNAME in `grep ":${name}:" /etc/passwd | cut -d: -f1`
            do
                if [ "${FNAME}" != "${user}" ]
                then
                    # deleting previos account
                    mecho "removing obsolete fetchmail user '${FNAME}' ..."
                    ${install_bin_path}/remove-user -f ${FNAME} 'no' > /dev/null
                fi
            done

            # check user
            grep -q "^${user}:" /etc/passwd

            if [ $? -ne 0 ]
            then
                echo "creating fetchmail user '${user}' ..."
                ${install_bin_path}/add-user ${user} "${pass}" "${uid}" "${exim_gid}" "${name}" "${homedir}" "${shell}" > /dev/null
            else
                # make sure the password has correctly been set
                echo "${user}:${pass}" | /usr/sbin/chpasswd

                # user exists, check if group has properly been set
                gidname=`grep "^${user}:" /etc/passwd | cut -d: -f4`

                if [ "${gidname}" != "${exim_gid}" ]
                then
                    gname=`grep ":${gidname}:" /etc/group | cut -d: -f1`

                    if [ "${gname}" != "${group}" ]
                    then
                        mecho --warn "Attention, the gid of the group '${group}' (${gidname}) has been changed. It should be '${exim_gid}'!"
                    fi

                    mecho "modifying group of user '${user}', '${gname}' -> '${group}' ..."
                    ${install_bin_path}/modify-user -g "${user}" "${group}"
                fi

                # user exists, make sure that the homedir has properly set
                hname=`grep "^${user}:" /etc/passwd | cut -d: -f6`

                if [ "${hname}" != "${homedir}" ]
                then
                    mecho "modifying home directory of user '${user}', '${hname}' -> '${homedir}' ..."
                    ${install_bin_path}/modify-user -d "${user}" "${homedir}"
                fi

                # user exists, make sure that the shell has properly set
                sname=`grep "^${user}:" /etc/passwd|cut -d: -f7`

                if [ "${sname}" != "${shell}" ]
                then
                    mecho "modifying shell of user '${user}', '${sname}' -> '${shell}' ..."
                    ${install_bin_path}/modify-user -s "${user}" "${shell}"
                fi

                # explicitely set ownership of home directory
                chown -R ${user}  ${homedir}
                chgrp -R ${group} ${homedir}
            fi
      # else
            # SMTP_AUTH_TYPE='none' has been set
        fi
    else
        # check if system account exists and remove it when required
        name='fetchmail esmtp name'
        for FNAME in `grep ":${name}:" /etc/passwd | cut -d: -f1`
        do
            if [ "${FNAME}" != "${user}" ]
            then
                # deleting previos account
                mecho "removing fetchmail user '${FNAME}' ..."
                ${install_bin_path}/remove-user -f ${FNAME} 'no' > /dev/null
            fi
        done
    fi
}

#----------------------------------------------------------------------------------------
# creating pop3/imap password file
# input: $1 - nocolor or empty
#----------------------------------------------------------------------------------------
create_pop3imap_passwords ()
{
    nocolor=$1

    user=`whoami`

    if is_root ${user}
    then
        if [ \( "${START_POP3}" = "yes" -o "${START_IMAP}" = "yes" \) -a "${MAIL_USER_USE_MAILONLY_PASSWORDS}" = "yes" ]
        then
            # different passwords are enabled
            if [ ${MAIL_USER_N} -gt 0 ]
            then
                hflag=0

                idx=1
                while [ ${idx} -le ${MAIL_USER_N} ]
                do
                    eval pop3imap_active='$MAIL_USER_'${idx}'_ACTIVE'
                    eval pop3imap_user='$MAIL_USER_'${idx}'_USER'

                    if [ "${pop3imap_active}" = "yes" ]
                    then
                        pwfile="${testroot}/home/${pop3imap_user}/.mailpasswd"

                        if [ -f ${pwfile} ]
                        then
                            # .mailpasswd file exists
                            pop3imap_password="`head -n1 ${pwfile}`"
                            fflag=1
                        else
                            eval pop3imap_password='$MAIL_USER_'${idx}'_PASS'
                            fflag=0
                        fi

                        if [ "${pop3imap_password}" != "" ]
                        then
                            if [ ${hflag} -eq 0 ]
                            then
                                # print header
                                if [ "${nocolor}" = "nocolor" ]
                                then
                                    mecho "creating separate pop3/imap password file ..."
                                else
                                    mecho --info "creating separate pop3/imap password file ..."
                                fi

                                hflag=1

                                {
                                    #-------------------------------------------------------------------------
                                    print_short_header "${generate_pop3imappwd}" "${pgmname}" "mail" "${mail_version}"
                                    #-------------------------------------------------------------------------
                                } > ${generate_pop3imappwd}
                            fi

                            if [ ${fflag} -eq 1 ]
                            then
                                mecho "reading password from '${pwfile}' file ..."
                            fi

                            # write entry
                            printf "${pop3imap_user}\t${pop3imap_password}\n" >> ${generate_pop3imappwd}
                        else
                            # no password given
                            write_to_config_log -warn "No password has been set for user \"${pop3imap_user}\"!"
                        fi
                    else
                        # deactivated
                        write_to_config_log -info "Skipping MAIL_USER_${idx}_USER='${pop3imap_user}' because"
                        write_to_config_log -info -ff "it has been deactivated in the configuration file."
                    fi

                    idx=`expr ${idx} + 1`
                done

                # fetchmail smtp authentication
                case ${SMTP_AUTH_TYPE} in
                    server*)
                        # use global user and password
                        printf "${SMTP_AUTH_USER}\t${SMTP_AUTH_PASS}\n" >> ${generate_pop3imappwd}
                        ;;
                    user*)
                        # use individual user and password
                        printf "${FETCHMAIL_ESMTP_NAME}\t${FETCHMAIL_ESMTP_PASS}\n" >> ${generate_pop3imappwd}
                        ;;
                esac

                chmod 0600 ${generate_pop3imappwd}
            else
                mecho "separate pop3/imap passwords cannot be used because MAIL_USER_N='0' has been set!"
            fi
        else
            # different passwords are disabled
            if [ -f "${generate_pop3imappwd}" ]
            then
                mecho "deleting separate pop3/imap password file ..."
                rm -f ${generate_pop3imappwd}
            fi
        fi
    else
        # error - no root user
        mecho --error "This script can only be run by 'root' equivalent user!"
    fi
}

#----------------------------------------------------------------------------------------
# create c-client.cf file
#----------------------------------------------------------------------------------------
create_cclient ()
{
    if [ "${START_POP3}" = "yes" -o "${START_IMAP}" = "yes" ]
    then
       mecho "creating pop3/imap configuration file ..."

        {
            echo "I accept the risk"

            #----------------------------------------------------------------------------------------
            print_short_header "${generate_cclientconf}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            echo "set mail-subdirectory ${mail_subdir}"

            if [ "${POP3IMAP_CREATE_MBX}" = "yes" ]
            then
                echo 'set new-folder-format mbx'
                echo 'set empty-folder-format mbx'
            fi

            # 18.10.2014 JED - added to fight against Poodle attacks and to force TLS usage
            if [ "${POP3IMAP_TRANSPORT}" = "tls" -o "${POP3IMAP_TRANSPORT}" = "both" ]
            then
                echo 'set ssl-protocols -ALL +TLSv1'
                echo 'set ssl-cipher-list HIGH:!ADH:!EXPORT56:!SSLv2'
            fi

            # set exceptions for plaintext authentication
          # echo 'set plaintext-allowed-clients 192.168.6.55'
        } > ${generate_cclientconf}

        chmod 0644 ${generate_cclientconf}
    fi
}

#----------------------------------------------------------------------------------------
# create imap mailboxes
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
# sub function: create_imap_mailbox
#
# $1 - has to be the user for whom a imap folder should be created
# $2 - group name
# $3 - folder name, if empty INBOX is asumed
# $4 - name of mail sub directory
# $5 - mailbox type
# $6 - set 'nosu' if su shouldn't be used to change to home directory
# $7 - group name for directory in which the mailbox folder is placed
#----------------------------------------------------------------------------------------
create_imap_mailbox ()
{
    user="$1"                            # user account
    group="$2"                           # group name

    if [ "$3" = "" ]                     # folder to create
    then
        folder=INBOX
    else
        folder="$3"
    fi

    if [ "$4" != "" ]                    # mail sub directory
    then
        msubdir="$4"
    else
        msubdir=""
    fi

    if [ "$5" = "" -o "$5" = "unix" ]    # mailbox type
    then
        mtype="unix"
    else
        mtype="$5"
    fi

    if [ "$6" = "nosu" ]                 # su to home directory
    then
        no_su=true
    else
        no_su=false
    fi

    if [ "$7" = "" ]
    then
        dirgroup="${group}"
    else
        dirgroup="$7"
    fi

    grep -q "^${user}:" ${passwdfile}

    if [ $? -eq 0 ]
    then
        # account exists - get home directory
        homedir=`grep "^${user}:" ${passwdfile} | cut -d: -f6` > /dev/null

        # add mail sub directory
        if [ "${msubdir}" != "" ]
        then
            maildir="./${msubdir}"
            homedir="${homedir}/${msubdir}"
        else
            maildir="."
        fi

        # remove trailing slash
        folder=`echo ${folder}|sed 's/^\///'`

        # check for path
        echo "${folder}" | grep -q "\/"

        if [ $? -eq 0 ]
        then
            # path found - get directories
            dname="`dirname ${folder}`"
            OLDIFS=${IFS}
            IFS=\/
            set ${dname}
            IFS=${OLDIFS}

            # check/create all subdirectories
            tpath=''
            until [ $# -eq 0 ]
            do
                if [ "${tpath}" = "" ]
                then
                    tpath="${homedir}/$1"
                else
                    tpath="${tpath}/$1"
                fi

                if [ ! -d "${tpath}" ]
                then
                    # create path
                    mkdir -p ${tpath}
                fi

                set_namespace_dir_access_rights "${user}" "${dirgroup}" "${tpath}"
                shift
            done
        fi

        if [ ! -f ${homedir}/${folder} ]
        then
            # file does not exist
            # create new mailbox
            if [ "${no_su}" = "true" ]
            then
                /usr/bin/mailutil create "#driver.${mtype}:${homedir}/${folder}" > /dev/null
            else
                su - ${user} -c "/usr/bin/mailutil create \"#driver.${mtype}:${homedir}/${folder}\"" -s /bin/sh > /dev/null
            fi
        else
            # file exists
            if [ "`/usr/bin/head -c 5 ${homedir}/${folder}`" = "*mbx*" ]
            then
                # mbx - style file found
                if [ "${mtype}" = "unix" ]
                then
                    # move mbx to unix
                    if [ "${no_su}" = "true" ]
                    then
                        /usr/bin/mailutil move "${homedir}/${folder}" "#driver.unix:${homedir}/${folder}.tmp" > /dev/null
                        mv ${homedir}/${folder}.tmp ${homedir}/${folder} > /dev/null
                    else
                        su - ${user} -c "/usr/bin/mailutil move \"${folder}\" \"#driver.unix:${folder}.tmp\"; mv ${maildir}/${folder}.tmp ${maildir}/${folder}" -s /bin/sh > /dev/null
                    fi
                fi
            else
                # unix - style file found
                if [ "${mtype}" = "mbx" ]
                then
                    # move unix to mbx
                    if [ "${no_su}" = "true" ]
                    then
                        /usr/bin/mailutil move "${homedir}/${folder}" "#driver.mbx:${homedir}/${folder}.tmp" > /dev/null
                        mv ${homedir}/${folder}.tmp ${homedir}/${folder} > /dev/null
                    else
                        su - ${user} -c "/usr/bin/mailutil move \"${folder}\" \"#driver.mbx:${folder}.tmp\"; mv ${maildir}/${folder}.tmp ${maildir}/${folder}" -s /bin/sh > /dev/null
                    fi
                fi
            fi
        fi
    else
        # account doesn't exist
        write_to_config_log -error "User \"${user}\" doesn't exist, unable to create imap folder \"${folder}\"!"
    fi
}

#----------------------------------------------------------------------------------------
# sub function: remove_imap_mailbox
#
# $1 - has to be the user for whom a imap folder should be created
# $2 - optional folder name, if empty INBOX is asumed
# $3 - optional name of mail sub directory
#----------------------------------------------------------------------------------------
remove_imap_mailbox ()
{
    user="$1"               # user account

    if [ "$2" = "" ]        # folder to create
    then
        folder=INBOX
    else
        folder="$2"
    fi

    if [ "$3" != "" ]       # mail sub directory
    then
        msubdir="$3"
    else
        msubdir=""
    fi

    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        # account exists - get home directory
        homedir=`grep "^$user:" $passwdfile | cut -d: -f6` > /dev/null

        # add mail sub directory
        if [ "$msubdir" != "" ]
        then
            homedir="$homedir/$msubdir"
        fi

        if [ -f $homedir/$folder ]
        then
            # mailbox file exists - check if it is empty
            num_msgs=`/usr/bin/mailutil check -verbose $homedir/$folder 2> /dev/null|cut -d, -f2|sed 's/^ //'|cut -d' ' -f1`

            if [ $num_msgs -eq 0 ]
            then
                # mail folder empty - remove mail folder
                rm -f $homedir/$folder > /dev/null
                rmdir $homedir > /dev/null 2> /dev/null
            else
                # mail folder not empty - cannot remove
                write_to_config_log -warn "Imap $folder for user \"$user\" contains messages, couldn't disable"
                write_to_config_log -warn -ff "use of mbx file! Please delete file \"$homedir/INBOX\" manually."
            fi
#       else
#           # file does not exist
        fi
    else
        # account doesn't exist
        write_to_config_log -error "User \"$user\" doesn't exist, unable to remove imap folder \"$folder\"!"
    fi
}

#----------------------------------------------------------------------------------------
# process_imap_mailboxes_all - creating/removing imap mbx mailboxes
#----------------------------------------------------------------------------------------
process_imap_mailboxes_all ()
{
    if [ "$START_POP3" = "yes" -o "$START_IMAP" = "yes" ]
    then
        echo "creating imap unix/mbx mailboxes ..."

        idx=1
        while [ $idx -le $MAIL_USER_N ]
        do
            eval pop3imap_active='$MAIL_USER_'$idx'_ACTIVE'
            eval pop3imap_user='$MAIL_USER_'$idx'_USER'

            if [ "$pop3imap_active" = "yes" ]
            then
                if [ "$pop3imap_user" != "root" ]
                then
                    if [ "$POP3IMAP_CREATE_MBX" = "yes" ]
                    then
                        # mbx format
                        create_imap_mailbox "$pop3imap_user" "" "" "$mail_subdir" "mbx"
                    else
                        # unix format
                        create_imap_mailbox "$pop3imap_user" "" "" "$mail_subdir" "unix"
                    fi
                else
                    # mail user 'root' cannot be created, use alias definition instead
                    write_to_config_log -error "MAIL_USER_${idx}_USER='root' cannot be used and will be ignored."
                    write_to_config_log -error -ff "Use SMTP_ALIASES_x_ALIAS_1 definition instead!"
                fi
            fi

            idx=`expr $idx + 1`
        done
    fi
}

#----------------------------------------------------------------------------------------
# sub function: create imapshared user
#
# $1 - username to create
# $2 - name of usergroup
#----------------------------------------------------------------------------------------
create_namespace_user ()
{
    user="$1"                             # user account
    group="$2"                            # group name

    if [ "$group" = "" ]
    then
        group='users'
    fi

    grep -q "^$group:" $groupfile

    if [ $? -ne 0 ]
    then
        # create group
        ${install_bin_path}/add-group "$group"
    fi

    gid=`grep "^$group:" $groupfile | cut -d: -f3`

    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        # user exists -> modify group, parameter: [user][group]
        ${install_bin_path}/modify-user -g "$user" "$group"
    else
        # user doesn't exist -> create user, parameter: [user][password][uid][gid][name][home][shell]
        ${install_bin_path}/add-user "$user" "*" "" "$gid" "$user folder" "" "/bin/false"
    fi

    # check password to make sure that the account has not been disabled
    # otherwise su won't work after update-1.6.6 has been installed
    grep -q "^${user}:\!" /etc/shadow

    if [ $? -eq 0 ]
    then
        passwd -d ${user}
    fi

    # check if dummy mail-directory exists because it is needed by 'mailutil'
    # since access to other directories has been restricted in mail v1.4.1
    if [ "$user" = "imapshared" -o "$user" = "imappublic" ]
    then
        homedir=`grep "^$user:" $passwdfile | cut -d: -f6`

        if [ ! -d $homedir/.imapmail ]
        then
            cd $homedir
            ln -s . .imapmail
        fi
    fi
}

#----------------------------------------------------------------------------------------
# sub function: remove imapshared user
#
# $1 - username to remove
#----------------------------------------------------------------------------------------
remove_namespace_user ()
{
    user="$1"                                   # user account

    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        # user exists, delete it
        mecho "- deleting user account \"$user\" ..."

        # parameter: -f (force) [user][remove homedir yes/no]
        ${install_bin_path}/remove-user -f "$user" "yes"

        mecho "- done."
    fi
}

#----------------------------------------------------------------------------------------
# set_namespace_dir_access_rights
#
# $1 - username
# $2 - group name
# $3 - directory name (optional)
#----------------------------------------------------------------------------------------
set_namespace_dir_access_rights ()
{
    user="$1"                                   # user account
    group="$2"                                  # group name
    dirname="$3"                                # directory name

    # set rights
    case "$user"
    in
        imapshared)
            rights="0770"
            ;;
        imappublic)
            rights="0777"
            ;;
        ftp)
            rights="0755"
            ;;
    esac

    # check system user
    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        # user exists
        if [ "$dirname" = "" ]
        then
            # get home directory
            dirname=`grep "^$user:" $passwdfile | cut -d: -f6`
        fi

        # user group
        if [ "$group" != "" ]
        then
	    # check if group exists
            group=`grep "^$group:" $groupfile | cut -d: -f3`

            if [ $? -ne 0 ]
            then
                # group doesn't exist
                group=""
            fi
        else
            # group empty - use default
            group=""
        fi

        if [ -d $dirname ]
        then
            chmod $rights $dirname > /dev/null

            # set ownership
            chown $user:$group $dirname > /dev/null
        else
            # directory doesn't exist
            write_to_config_log -error "Directory '$dirname' of user '$user' doesn't exist, cannot set access rights!"
        fi
    else
        # user doesn't exist
        write_to_config_log -error "User '$user' doesn't exist, cannot set directory access rights!"
    fi
}

#----------------------------------------------------------------------------------------
# set_namespace_file_access_rights
#
# $1 - user name
# $2 - group name
# $3 - folder name
#----------------------------------------------------------------------------------------
set_namespace_file_access_rights ()
{
    user="$1"                                   # user account
    group="$2"                                  # group name
    folder="$3"                                 # folder name

    # set rights
    case "$user"
    in
        imapshared)
            rights="0660"
            ;;
        imappublic)
            rights="0666"
            ;;
        ftp)
            rights="0644"
            ;;
    esac

    # check system user
    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        # user exists
        # get home directory
        homedir=`grep "^$user:" $passwdfile | cut -d: -f6`

        # user group
        if [ "$group" != "" ]
        then
            # check if group exists
            group=`grep "^$group:" $groupfile | cut -d: -f3`

            if [ $? -ne 0 ]
            then
                # group doesn't exist
                group=""
            fi
        else
            # group empty - use default
            group=""
        fi

        # check if folder begins with a '/'
        echo "$folder"|grep -q "^/"

        if [ $? -eq 0 ]
        then
            # take it as is
            file_name="$folder"
        else
            # add homedir
            file_name="$homedir/$folder"
        fi

        if [ -f $file_name ]
        then
            chmod $rights $file_name > /dev/null

            # set ownership
            chown $user:$group $file_name > /dev/null
        else
            # file doesn't exist
            write_to_config_log -error "File '$file_name' of user '$user' doesn't exist, cannot set file access rights!"
        fi
    else
        # user doesn't exist
        write_to_config_log -error "User \"$user\" doesn't exist, cannot set file access rights!"
    fi
}

#----------------------------------------------------------------------------------------
# create_namespace_listfiles - create imap namespace lists
#----------------------------------------------------------------------------------------
create_namespace_listfiles ()
{
    ### imapshared ### imapshared ### imapshared ### imapshared ###
    if [ "$IMAP_SHARED_FOLDER_N" -gt 0 ]
    then
        mecho "creating imapshared list file ..."

        {
            #----------------------------------------------------------------------------------------
            print_short_header "${generate_imapshared}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            idx=1
            while [ $idx -le $IMAP_SHARED_FOLDER_N ]
            do
                eval active='$IMAP_SHARED_FOLDER_'$idx'_ACTIVE'
                eval foldername='$IMAP_SHARED_FOLDER_'$idx'_NAME'

                if [ "$active" = "yes" ]
                then
                    eval usergroup='$IMAP_SHARED_FOLDER_'$idx'_USERGROUP'

                    if [ "$usergroup" = "" ]
                    then
                        # custom group not set, use global group
                        usergroup="${IMAP_SHARED_PUBLIC_USERGROUP}"

                        if [ "$usergroup" = "" ]
                        then
                            # global group not set, use default group
                            usergroup=users
                        fi
                    fi

                    # extract name of mailbox folder / path name
                    noadd=0
                    f_name="`basename $foldername`"
                    f_name_lc=`echo "$f_name"|tr 'A-Z' 'a-z'`
                    p_name="`dirname $foldername`"

                    if [ "$p_name" != "." ]                        # dirname returns '.' if empty string is given
                    then
                        # check for absolute path
                        echo "$p_name"|grep -q "^\/"

                        if [ $? -ne 0 ]
                        then
                            # check for relative path
                            echo "$p_name"|grep -q "^\.\/"

                            if [ $? -eq 0 ]
                            then
                                # remove relative path information
                                p_name="`echo \"$p_name\"|sed 's#^\.\/##'`"
                            fi
                        else
                            # leading slash found - deactivated
                            noadd=1
                            eval "IMAP_SHARED_FOLDER_"$idx"_ACTIVE='no'"
                            write_to_config_log -error "Skipping IMAP_SHARED_FOLDER_${idx}_NAME='${foldername}'"
                            write_to_config_log -error -ff "because an absolute path has been used."
                        fi
                    fi

                    # append slash
                    p_name="$p_name/"

                    if [ $noadd -eq 0 ]
                    then
                        # check if folder name does already exist
                        grep -q "^${f_name_lc}:" $generate_imapshared

                        if [ $? -ne 0 ]
                        then
                            # name does not exist - add entry
                            echo "$f_name_lc: path=$p_name folder=$f_name group=$usergroup"
                        else
                            # deactivated
                            eval "IMAP_SHARED_FOLDER_"$idx"_ACTIVE='no'"
                            write_to_config_log -warn "Skipping IMAP_SHARED_FOLDER_${idx}_NAME='${foldername}'"
                            write_to_config_log -warn -ff "because name '${f_name_lc}' has already been defined."
                        fi
                    fi
                else
                    # deactivated
                    eval "IMAP_SHARED_FOLDER_"$idx"_ACTIVE='no'"
                    write_to_config_log -info "Skipping IMAP_SHARED_FOLDER_${idx}_NAME='${foldername}' because"
                    write_to_config_log -info -ff "it has been deactivated in the configuration file."
                fi

                idx=`expr $idx + 1`
            done
        } > $generate_imapshared

        # set access rights
        chmod 0644 $generate_imapshared
        chown exim $generate_imapshared
        chgrp trusted $generate_imapshared
    else
        if [ -f $generate_imapshared ]
        then
            # delete existing file
            mecho "deleting imapshared list file ..."
            rm -f $generate_imapshared
        fi
    fi

    ### imappublic ### imappublic ### imappublic ### imappublic ###
    if [ $IMAP_PUBLIC_FOLDER_N -gt 0 ]
    then
        mecho "creating imappublic list file ..."

        {
            #----------------------------------------------------------------------------------------
            print_short_header "${generate_imappublic}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            idx=1
            while [ $idx -le $IMAP_PUBLIC_FOLDER_N ]
            do
                eval active='$IMAP_PUBLIC_FOLDER_'$idx'_ACTIVE'
                eval foldername='$IMAP_PUBLIC_FOLDER_'$idx'_NAME'

                if [ "$active" = "yes" ]
                then
                    eval usergroup='$IMAP_PUBLIC_FOLDER_'$idx'_USERGROUP'

                    if [ "$usergroup" = "" ]
                    then
                        # custom group not set, use global group
                        usergroup="${IMAP_SHARED_PUBLIC_USERGROUP}"

                        if [ "$usergroup" = "" ]
                        then
                            # global group not set, use default group
                            usergroup=users
                        fi
                    fi

                    # extract name of mailbox folder / path name
                    noadd=0
                    f_name="`basename $foldername`"
                    f_name_lc=`echo "$f_name"|tr 'A-Z' 'a-z'`
                    p_name="`dirname $foldername`"

                    if [ "$p_name" != "." ]                        # dirname returns '.' if empty string is given
                    then
                        # check for absolute path
                        echo "$p_name"|grep -q "^\/"

                        if [ $? -ne 0 ]
                        then
                            # check for relative path
                            echo "$p_name"|grep -q "^\.\/"

                            if [ $? -eq 0 ]
                            then
                                # remove relative path information
                                p_name="`echo \"$p_name\"|sed 's#^\.\/##'`"
                            fi
                        else
                            # leading slash found - deactivated
                            noadd=1
                            eval "IMAP_PUBLIC_FOLDER_"$idx"_ACTIVE='no'"
                            write_to_config_log -error "Skipping IMAP_PUBLIC_FOLDER_${idx}_NAME='${foldername}'"
                            write_to_config_log -error -ff "because an absolute path has been used."
                        fi
                    fi

                    # append slash
                    p_name="$p_name/"

                    if [ $noadd -eq 0 ]
                    then
                        # check if folder name does already exist
                        grep -q "^${f_name_lc}:" $generate_imappublic

                        if [ $? -ne 0 ]
                        then
                            # name does not exist - add entry
                            echo "$f_name_lc: path=$p_name folder=$f_name group=$usergroup"
                        else
                            # deactivated
                            eval "IMAP_PUBLIC_FOLDER_"$idx"_ACTIVE='no'"
                            write_to_config_log -warn "Skipping IMAP_PUBLIC_FOLDER_${idx}_NAME='${foldername}'"
                            write_to_config_log -warn -ff "because name '${f_name_lc}' has already been defined."
                        fi
                    fi
                else
                    # deactivated
                    eval "IMAP_PUBLIC_FOLDER_"$idx"_ACTIVE='no'"
                    write_to_config_log -info "Skipping IMAP_PUBLIC_FOLDER_${idx}_NAME='${foldername}' because"
                    write_to_config_log -info -ff "it has been deactivated in the configuration file."
                fi

                idx=`expr $idx + 1`
            done
        } > $generate_imappublic

        # set access rights
        chmod 0644 $generate_imappublic
        chown exim $generate_imappublic
        chgrp trusted $generate_imappublic
    else
        if [ -f $generate_imappublic ]
        then
            # delete existing file
            mecho "deleting imappublic list file ..."
            rm -f $generate_imappublic
        fi
    fi
}

#----------------------------------------------------------------------------------------
# process_namespace_folders - creating/removing imap namespace folders
#----------------------------------------------------------------------------------------
process_namespace_folders ()
{
    if [ "${START_IMAP}" = "yes" ]
    then
        if [ "${POP3IMAP_CREATE_MBX}" = "yes" ]
        then
            mtype="mbx"
        else
            mytpe="unix"
        fi

        if [ "${IMAP_SHARED_PUBLIC_USERGROUP}" = "" ]
        then
            defgroup='users'
        else
            defgroup="${IMAP_SHARED_PUBLIC_USERGROUP}"
        fi

        ### imap shared ### imap shared ### imap shared ### imap shared ###
        user="imapshared"

        if [ ${IMAP_SHARED_FOLDER_N} -gt 0 ]
        then
            # create account
            mecho "creating imapshared namespace folders ..."

            mecho "- creating user account \"${user}\" ..."
            create_namespace_user "${user}" "${defgroup}"

            idx=1
            while [ ${idx} -le ${IMAP_SHARED_FOLDER_N} ]
            do
                eval active='$IMAP_SHARED_FOLDER_'${idx}'_ACTIVE'

                if [ "${active}" = "yes" ]
                then
                    # create folder
                    eval foldername='$IMAP_SHARED_FOLDER_'${idx}'_NAME'
                    eval foldergroup='$IMAP_SHARED_FOLDER_'${idx}'_USERGROUP'

                    if [ "${foldername}" != "" ]
                    then
                        if [ "${foldergroup}" = "" ]
                        then
                            # custom group not set, use global group
                            foldergroup="${defgroup}"

                            mecho "- creating folder \"${foldername}\" for default group ..."
                        else
                            mecho "- creating folder \"${foldername}\" for group \"${foldergroup}\" ..."
                        fi

                        create_imap_mailbox "${user}" "${foldergroup}" "${foldername}" "" "${mtype}" "" "${defgroup}"
                        set_namespace_file_access_rights "${user}" "${foldergroup}" "${foldername}"
                    fi
                fi

                idx=`expr ${idx} + 1`
            done

            set_namespace_dir_access_rights "${user}" "${defgroup}" ""

            if [ -f ${mailspool_path}/${user} ]
            then
                set_namespace_file_access_rights "${user}" "${foldergroup}" "${mailspool_path}/${user}"
            fi
        else
            # delete folder
            mecho "deleting imapshared namespace folders ..."

            homedir=`grep "^${user}:" ${passwdfile} | cut -d: -f6` > /dev/null

            if [ -f "${homedir}" ]
            then
                for FNAME in `ls -p ${homedir}`
                do
                    mecho "- deleting folder \"${FNAME}\" ..."
                    remove_imap_mailbox "${user}" "${FNAME}" ""
                done
                mecho "- done."
            fi

            remove_namespace_user "${user}"
        fi

        ### imap public ### imap public ### imap public ### imap public ###
        user="imappublic"

        if [ ${IMAP_PUBLIC_FOLDER_N} -gt 0 ]
        then
            # create account
            mecho "creating imappublic namespace folders ..."

            mecho "- creating user account \"${user}\" ..."
            create_namespace_user "${user}" "${defgroup}"

            idx=1
            while [ ${idx} -le ${IMAP_PUBLIC_FOLDER_N} ]
            do
                eval active='$IMAP_PUBLIC_FOLDER_'${idx}'_ACTIVE'

                if [ "${active}" = "yes" ]
                then
                    # create folder
                    eval foldername='$IMAP_PUBLIC_FOLDER_'${idx}'_NAME'
                    eval foldergroup='$IMAP_PUBLIC_FOLDER_'${idx}'_USERGROUP'

                    if [ "${foldername}" != "" ]
                    then
                        if [ "${foldergroup}" = "" ]
                        then
                            # custom group not set, use global group
                            foldergroup="${defgroup}"

                            mecho "- creating folder \"${foldername}\" for default group ..."
                        else
                            mecho "- creating folder \"${foldername}\" for group \"${foldergroup}\" ..."
                        fi

                        create_imap_mailbox "${user}" "${foldergroup}" "${foldername}" "" "${mtype}" "" "${defgroup}"
                        set_namespace_file_access_rights "${user}" "${foldergroup}" "${foldername}"
                    fi
                fi

                idx=`expr ${idx} + 1`
            done

            set_namespace_dir_access_rights "${user}" "${defgroup}" ""

            if [ -f ${mailspool_path}/${user} ]
            then
                set_namespace_file_access_rights "${user}" "${foldergroup}" "${mailspool_path}/${user}"
            fi
        else
            # delete folder
            mecho "deleting imappublic namespace folders ..."

            homedir=`grep "^${user}:" ${passwdfile} | cut -d: -f6` > /dev/null

            if [ -f "${homedir}" ]
            then
                for FNAME in `ls -p ${homedir}`
                do
                    mecho "- deleting folder \"${FNAME}\" ..."
                    remove_imap_mailbox "${user}" "${FNAME}" ""
                done
                mecho "- done."
            fi

            remove_namespace_user "${user}"
        fi
    fi
}

#----------------------------------------------------------------------------------------
# creating fetchmail configuration
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
# sub function: fetchmail header
#
# $1 - nodeamon - if $1 is set to 'nodaemon', daemon mode is disabled
#----------------------------------------------------------------------------------------
process_fetchmail_header ()
{
    #----------------------------------------------------------------------------------------
    print_short_header "${generate_fetchconf}" "${pgmname}" "mail" "${mail_version}"
    #----------------------------------------------------------------------------------------

    echo "set postmaster \"postmaster\""

    if [ "$1" != "nodaemon" ]
    then
        echo "set daemon $FETCHMAIL_DAEMON"
    fi

    echo "set logfile $systemlog_path/fetchmail.log"

    # define bounce parameters
    if [ "${FETCHMAIL_BOUNCE_MAIL}" = "yes" ]
    then
        echo "set bouncemail"
    else
        # default if not set: no
        echo "set no bouncemail"
    fi

    if [ "${FETCHMAIL_BOUNCE_SPAM}" = "yes" ]
    then
        echo "set spambounce"
    else
        # default if not set: no
        echo "set no spambounce"
    fi

    if [ "${FETCHMAIL_BOUNCE_SOFT}" = "no" ]
    then
        echo "set no softbounce"
    else
        # default if not set: yes
        echo "set softbounce"
    fi

    echo
    echo "defaults"

    if [ "$FETCHMAIL_PROTOCOL" = "" ]
    then
        FETCHMAIL_PROTOCOL="pop3"
    else
        FETCHMAIL_PROTOCOL="`echo ${FETCHMAIL_PROTOCOL} | tr 'A-Z' 'a-z'`"
    fi

    # protocol removal warning - for versions greater than fm v6.3.4
    if [ "$FETCHMAIL_PROTOCOL" = "auto" ]
    then
        write_to_config_log -warn "FETCHMAIL_PROTOCOL='auto' has currently been set, which will no longer"
        write_to_config_log -warn -ff "supported in future Fetchmail versions. Please choose an explicit protocol!"
    fi

    echo "  proto ${FETCHMAIL_PROTOCOL}"
    echo "  timeout ${FETCHMAIL_TIMEOUT}"

    if [ "${FETCHMAIL_LIMIT}" != "" ]
    then
        FETCHMAIL_LIMIT="`unit_to_numeric ${FETCHMAIL_LIMIT}`"
    else
        FETCHMAIL_LIMIT="`unit_to_numeric '4m'`"
    fi

    echo "  limit ${FETCHMAIL_LIMIT}"
    echo "  warnings ${FETCHMAIL_WARNINGS}"
    echo "  no fetchall"
    echo
}

#----------------------------------------------------------------------------------------
# sub function: fetchmail account
#
# $1 - account number - has to be set to desired account number
# $2 - first active account
# $3 - last active account
# $4 - manual forced
#----------------------------------------------------------------------------------------
process_fetchmail_account ()
{
    count=$1
    fmfirst=$2
    fmlast=$3
    fmmanual=$4
    eval fetchmail_comment='$FETCHMAIL_'$count'_COMMENT'
    eval fetchmail_server='$FETCHMAIL_'$count'_SERVER'
    eval fetchmail_server_aka_n='$FETCHMAIL_'$count'_SERVER_AKA_N'
    eval fetchmail_user='$FETCHMAIL_'$count'_USER'
    eval fetchmail_password='$FETCHMAIL_'$count'_PASS'
    eval fetchmail_forward='$FETCHMAIL_'$count'_FORWARD'
    eval fetchmail_smtphost='$FETCHMAIL_'$count'_SMTPHOST'
    eval fetchmail_imap_folder='$FETCHMAIL_'$count'_IMAP_FOLDER'
    eval fetchmail_domain='$FETCHMAIL_'$count'_DOMAIN'
    eval fetchmail_envelope='$FETCHMAIL_'$count'_ENVELOPE'
    eval fetchmail_envelope_header='$FETCHMAIL_'$count'_ENVELOPE_HEADER'
    eval fetchmail_localdomain_n='$FETCHMAIL_'$count'_LOCALDOMAIN_N'
    eval fetchmail_protocol='$FETCHMAIL_'$count'_PROTOCOL'
    eval fetchmail_port='$FETCHMAIL_'$count'_PORT'
    eval fetchmail_auth='$FETCHMAIL_'$count'_AUTH_TYPE'
    eval fetchmail_accept_bad_header='$FETCHMAIL_'${count}'_ACCEPT_BAD_HEADER'
    eval fetchmail_dns_lookup='$FETCHMAIL_'${count}'_DNS_LOOKUP'
    eval fetchmail_keep='$FETCHMAIL_'$count'_KEEP'
    eval fetchmail_fetchall='$FETCHMAIL_'$count'_FETCHALL'
    eval fetchmail_msg_limit='$FETCHMAIL_'$count'_MSG_LIMIT'
    eval fetchmail_ssl_protocol='$FETCHMAIL_'$count'_SSL_PROTOCOL'
    eval fetchmail_ssl_transport='$FETCHMAIL_'$count'_SSL_TRANSPORT'
    eval fetchmail_ssl_fingerprint='$FETCHMAIL_'$count'_SSL_FINGERPRINT'

    if [ "$fetchmail_domain" = "yes" -a "$fetchmail_forward" != "" ]
    then
        # cannot use both variables at the same time
        write_to_config_log -warn "FETCHMAIL_${count}_DOMAIN and FETCHMAIL_${count}_FORWARD has both been set."
        write_to_config_log -warn -ff "Value of FETCHMAIL_${count}_FORWARD will be ignored!"
    fi

    if [ "$fetchmail_keep" = "yes" -a "$fetchmail_fetchall" = "yes" ]
    then
        # cannot use both variables at the same time
        # spline.eisfair posting 'fetchmail klappt nicht' of 30.12.2003 09:53h - S.Puschek
        write_to_config_log -warn "FETCHMAIL_${count}_KEEP and FETCHMAIL_${count}_FETCHALL has both been set."
        write_to_config_log -warn -ff "Value of FETCHMAIL_${count}_FETCHALL will be ignored!"
        fetchmail_fetchall='no'
    fi

    if [ "$fetchmail_domain" = "no" -a $fetchmail_localdomain_n -gt 0 ]
    then
        # $fetchmail_domain must be set to 'yes' if you want to use localdomains
        write_to_config_log -error "You must set FETCHMAIL_${count}_DOMAIN="yes" if you want to use FETCHMAIL_${count}_LOCALDOMAIN_N!"
    fi

    if [ "$fetchmail_smtphost" != "" -a "$fetchmail_forward" = "" ]
    then
        # have to set FETCHMAIL_x_FORWARD to a proper value if using FETCHMAIL_x_SMTPHOST
        write_to_config_log -error "FETCHMAIL_${count}_SMTPHOST is being used without setting FETCHMAIL_${count}_FORWARD to a proper value!"
    fi

    if [ "$fetchmail_smtphost" != "" ]
    then
        fetchmail_smtphost="smtphost \"$fetchmail_smtphost\""
    fi

    ### server parameters ### server parameters ### server parameters ### server parameters ###

    # check for CompuServe RPA protocol
    fetchmail_rpa_protcol=0
    echo ${fetchmail_server} | grep -q "\.csi\.com$"

    if [ $? -eq 0 ]
    then
        # enable CompuServe RPA protocol
        echo "# ${fetchmail_comment} - RPA enabled"
        fetchmail_rpa_protcol=1
        write_to_config_log -info "RPA protocol has been enabled automatically for account '${fetchmail_comment}'!"
    else
        # default
        echo "# ${fetchmail_comment}"
    fi

    printf "poll ${fetchmail_server} "

    # covert to lowercase
    fetchmail_protocol="`echo ${fetchmail_protocol} | tr 'A-Z' 'a-z'`"

    # setup default protocol
    if [ "$fetchmail_protocol" = "" ]
    then
        fetchmail_protocol="${FETCHMAIL_PROTOCOL}"
    fi

    # valid protocol used
    printf "proto $fetchmail_protocol "

    # setup different port number
    if [ "$fetchmail_port" != "" ]
    then
        printf "service $fetchmail_port "
    fi

    # setup different authentication than 'any'
    if [ "$fetchmail_auth" != "" ]
    then
        printf "auth $fetchmail_auth "
    fi

    # v6.3.15 - accept/reject bad email headers
    if [ "${fetchmail_accept_bad_header}" = "yes" ]
    then
        printf "bad-header accept "
    else
        printf "bad-header reject "
    fi

    if [ "${fetchmail_dns_lookup}" = "no" ]
    then
        printf "no dns "
    fi

    # activate use of uidl parameter (recommended)
    if [ "${fetchmail_keep}" = "yes" -a "${fetchmail_protocol}" = "pop3" ]
    then
        printf "uidl "
    fi

    # set end of line
    echo

    # fetchmail smtp authentification
    case ${SMTP_AUTH_TYPE} in
        server*)
            # use global user and password
            echo "    esmtpname \"${SMTP_AUTH_USER}\" esmtppassword \"${SMTP_AUTH_PASS}\""
            ;;
        user*)
            # use individual user and password
            echo "    esmtpname \"${FETCHMAIL_ESMTP_NAME}\" esmtppassword \"${FETCHMAIL_ESMTP_PASS}\""
            ;;
    esac


    # setup drop mode
    if [ "$fetchmail_domain" = "yes" ]
    then
        # multi-drop mode - no quotes
        fetchmail_forward='*'

        if [ "$fetchmail_envelope" != "yes" ]
        then
            # don't lookup envelope addresses
            echo "    no envelope"
        elif [ "$fetchmail_envelope_header" != "" -a "$fetchmail_envelope_header" != "X-Envelope-To:" ]
        then
            # look for individual header, e.g. 'Envelope-To:'
            echo "    envelope \"$fetchmail_envelope_header\""
        fi

        # alternate dns names of mailserver
        if [ $fetchmail_server_aka_n -gt 0 ]
        then
            printf "    aka "

            jdx=1
            while [ $jdx -le $fetchmail_server_aka_n ]
            do
                eval fetchmail_server_aka='$FETCHMAIL_'$count'_SERVER_AKA_'$jdx

                printf "$fetchmail_server_aka "

                jdx=`expr $jdx + 1`
            done

            echo
        fi

        # check against localdomains
        if [ $fetchmail_localdomain_n -gt 0 ]
        then
            printf "    localdomains "

            jdx=1
            while [ $jdx -le $fetchmail_localdomain_n ]
            do
                eval fetchmail_localdomain='$FETCHMAIL_'$count'_LOCALDOMAIN_'$jdx

                printf "$fetchmail_localdomain "

                jdx=`expr $jdx + 1`
            done

            echo
        fi
    else
        # single-drop mode - add quotes
        fetchmail_forward="\"$fetchmail_forward\""
    fi

    ### account parameters ### account parameters ### account parameters ### account parameters ###

    # check for CompuServe RPA protocol
    if [ ${fetchmail_rpa_protcol} -eq 1 ]
    then
        # check if user account has been properly configured
        echo "${fetchmail_user}" | grep -q "\@compuserve\.com$"

        if [ $? -ne 0 ]
        then
            # missing domain
            write_to_config_log -info "FETCHMAIL_${count}_USER doesn't contain the domain '@compuserve.com'. Remember"
            write_to_config_log -info -ff "to add if you want to enable support for the ComuServe RPA protocol!"
        fi
    fi

    echo "    user \"$fetchmail_user\" password \"$fetchmail_password\" is $fetchmail_forward $fetchmail_smtphost "

    # request multiple imap folders
    if [ "$fetchmail_protocol" = "imap" ]
    then
        # imap protocol has been choosen
        if [ "$fetchmail_imap_folder" != "" ]
        then
            _oldifs=${IFS}
            IFS=,
            fetchmail_tmp_imap_folder=''

            # process all given imap folders - quote every foldername separately
            for IFOLDER in ${fetchmail_imap_folder}
            do
                if [ "${IFOLDER}" != "" ]
                then
                    if [ "${fetchmail_tmp_imap_folder}" = "" ]
                    then
                        fetchmail_tmp_imap_folder="\"`trim_spaces ${IFOLDER}`\""
                    else
                        fetchmail_tmp_imap_folder="${fetchmail_tmp_imap_folder},\"`trim_spaces ${IFOLDER}`\""
                    fi
                fi
            done

            IFS=${_oldifs}

            # output
            echo "    folder ${fetchmail_tmp_imap_folder}"
        fi
    fi

    # don't delete mail form server
    if [ "${fetchmail_keep}" = "yes" ]
    then
        echo "    keep"

        # activate use of fastuidl parameter
        if [ "${fetchmail_protocol}" = "pop3" ]
        then
            echo "    fastuidl 4"
        fi
    fi

    # fetch all mail from server
    if [ "$fetchmail_fetchall" = "yes" ]
    then
        echo "    fetchall"
    fi

    # limt number of messages per session
    if [ $fetchmail_msg_limit -gt 0 ]
    then
        echo "    fetchlimit $fetchmail_msg_limit"
        echo "    batchlimit $fetchmail_msg_limit"
    fi

    # use a specific ssl protocol
    case ${fetchmail_ssl_protocol} in
        ssl2|ssl3|tls1)
            echo "    sslproto ${fetchmail_ssl_protocol}"
            ;;
        none)
            echo "    sslproto ''"
            ;;
        auto|*)
            ;;
    esac

    # use ssl transport for your mail server
    if [ "$fetchmail_ssl_transport" = "yes" ]
    then
        mkdir -p $sslcert_path > /dev/null

        ls $sslcert_path/*.0 > /dev/null 2> /dev/null

        if [ $? -eq 0 ]
        then
            echo "    ssl"

            if [ "${fetchmail_ssl_fingerprint}" != "" ]
            then
                echo "    sslfingerprint \"$fetchmail_ssl_fingerprint\""
            fi

            echo "    sslcertpath $sslcert_path"
            echo "    sslcertck"
        else
            write_to_config_log -error "Server:  $fetchmail_server"
            write_to_config_log -error -ff "Account: $fetchmail_user"
            write_to_config_log -error -ff "FETCHMAIL_${count}_SSL_TRANSPORT has automatically been set"
            write_to_config_log -error -ff "to 'no' because of missing certificates in $sslcert_path!"
        fi
    fi

    # add timestamp at start and end of a poll as usual for fetchmail versions < 6.3.10
    if [ ${count} -eq ${fmfirst} ]
    then
        if [ "${fmmanual}" = "manual" ]
        then
            echo "    preconnect  \"echo 'fetchmail: forced manually at '\`date +'%a, %d %b %G %H:%M:%S (%Z)'\`\""
        else
            echo "    preconnect  \"echo 'fetchmail: awakened at '\`date +'%a, %d %b %G %H:%M:%S (%Z)'\`\""
        fi
    fi

    if [ ${count} -eq ${fmlast} ]
    then
        # check if custom fingerprint check script exists
        if [ -f ${eximspool_path}/custom-mail-check-fingerprint ]
        then
            fm_checkscript=${eximspool_path}/custom-mail-check-fingerprint
        else
            # use default script
            fm_checkscript=${install_bin_path}/mail-check-fingerprint
        fi

        if [ "${fmmanual}" = "manual" ]
        then
            echo "    postconnect \"echo 'fetchmail: finished at '\`date +'%a, %d %b %G %H:%M:%S (%Z)'\`; ${fm_checkscript}\""
        else
            echo "    postconnect \"echo 'fetchmail: sleeping at '\`date +'%a, %d %b %G %H:%M:%S (%Z)'\` for ${FETCHMAIL_DAEMON} seconds; ${fm_checkscript}\""
        fi
    fi

    echo
}

#----------------------------------------------------------------------------------------
# fetchmail config all
#
# no command line parameters
#----------------------------------------------------------------------------------------
create_fetchmail_config_all ()
{
    if [ "$START_FETCHMAIL" = "yes" ]
    then
        mecho "creating fetchmail configuration file ..."

        # check for active fetchmail accounts
        idx=1
        fetchmail_firstactive=0
        fetchmail_lastactive=0
        while [ ${idx} -le ${FETCHMAIL_N} ]
        do
            eval fetchmail_active='$FETCHMAIL_'$idx'_ACTIVE'

            if [ "${fetchmail_active}" = "yes" ]
            then
                if [ ${fetchmail_firstactive} -eq 0 ]
                then
                    fetchmail_firstactive=${idx}
                fi

                fetchmail_lastactive=${idx}
            fi

            idx=`expr $idx + 1`
        done

        if [ ${fetchmail_firstactive} -gt 0 ]
        then
            # create configuration file only if at least one entry has been activated
            {
                # write header and default parameters
                process_fetchmail_header

                idx=${fetchmail_firstactive}
                while [ ${idx} -le ${fetchmail_lastactive} ]
                do
                    eval fetchmail_active='$FETCHMAIL_'${idx}'_ACTIVE'

                    if [ "${fetchmail_active}" = "yes" ]
                    then
                        # write server/user account parameters
                        process_fetchmail_account $idx ${fetchmail_firstactive} ${fetchmail_lastactive}
                    else
                        # deactivated
                        write_to_config_log -info "Skipping FETCHMAIL_${idx}_... entry because it has"
                        write_to_config_log -info -ff "been deactivated in the configuration file."
                    fi

                    idx=`expr ${idx} + 1`
                done
            } > ${generate_fetchconf}

            chown exim    ${generate_fetchconf}
            chgrp trusted ${generate_fetchconf}
            chmod 600     ${generate_fetchconf}
        fi
    fi
}

#----------------------------------------------------------------------------------------
# fetchmail config single
#
# $1 - account number - has to be set to desired account number
#----------------------------------------------------------------------------------------
create_fetchmail_config_single ()
{
    # get fetchmail account number
    num=$1

    # set temp configuration
    generate_fetchconf=${testroot}/tmp/fetchmail.conf.tmp

    # delete old config file
    if [ -f ${generate_fetchconf} ]
    then
        rm -f ${generate_fetchconf}
    fi

    {
        # write header and default parameters
        process_fetchmail_header nodaemon

        # write server/user account parameters
        process_fetchmail_account ${num} ${num} ${num} 'manual'
    } > ${generate_fetchconf}

    chown exim    ${generate_fetchconf}
    chgrp trusted ${generate_fetchconf}
    chmod 600     ${generate_fetchconf}
}

#----------------------------------------------------------------------------------------
# sub function: create local domains file
#
# no command line parameters
#----------------------------------------------------------------------------------------
create_local_domains ()
{
    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_localdomains}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        # add hostname as default
        echo "`hostname`"

        idx=1
        while [ ${idx} -le ${SMTP_LOCAL_DOMAIN_N} ]
        do
            eval domain='$SMTP_LOCAL_DOMAIN_'${idx}

            grep -q "^${domain}\$" ${generate_localdomains}

            if [ $? -eq 1 ]
            then
                # domain not found, add it
                echo "${domain}"                                                 # v1.2.7
            fi

            idx=`expr ${idx} + 1`
        done

        # local domains - add mailing list domain
        if [ ${SMTP_LIST_N} -gt 0 ]
        then
            grep -q "^${SMTP_LIST_DOMAIN}" ${generate_localdomains}

            if [ $? -eq 1 ]
            then
                # domain not found, add it
                echo "${SMTP_LIST_DOMAIN}"
            fi
        fi
    } > ${generate_localdomains}

    # set access rights
    chmod 0600 ${generate_localdomains}
    chown exim ${generate_localdomains}
    chgrp trusted ${generate_localdomains}
}

#----------------------------------------------------------------------------------------
# sub function: create my sender domains file
#
# no command line parameters
#----------------------------------------------------------------------------------------
create_my_sender_domains ()
{
    if [ "$SMTP_AUTH_TYPE" = "user" -o "$SMTP_AUTH_TYPE" = "server" ]
    then
        {
            #----------------------------------------------------------------------------------------
            print_short_header "${generate_mysenderdomains}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            grep -E -v "^#|^localhost|127.0.0.1" $generate_localdomains
        } > $generate_mysenderdomains

        # set access rights
        chmod 0600 $generate_mysenderdomains
        chown exim $generate_mysenderdomains
        chgrp trusted $generate_mysenderdomains
    else
        rm -f $generate_mysenderdomains
    fi
}

#----------------------------------------------------------------------------------------
# sub function: create relay to domains file
#
# no command line parameters
#----------------------------------------------------------------------------------------
create_relay_to_domains ()
{
    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_relaytodomains}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        idx=1
        while [ $idx -le $SMTP_RELAY_TO_DOMAIN_N ]
        do
            eval domain='$SMTP_RELAY_TO_DOMAIN_'$idx

            grep -q "^${domain}" $generate_relaytodomains

            if [ $? -eq 1 ]
            then
                # domain not found, add it
              # echo "$domain:"
                echo "$domain"                                                 # v1.2.7
            fi

            idx=`expr $idx + 1`
        done
    } > $generate_relaytodomains

    # set access rights
    chmod 0600 $generate_relaytodomains
    chown exim $generate_relaytodomains
    chgrp trusted $generate_relaytodomains
}

#----------------------------------------------------------------------------------------
# sub function: create relay from hosts file
#
# no command line parameters
#----------------------------------------------------------------------------------------
create_relay_from_hosts ()
{
    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_relayfromhosts}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        idx=1
        while [ $idx -le $SMTP_RELAY_FROM_HOST_N ]
        do
            eval host='$SMTP_RELAY_FROM_HOST_'$idx

            grep -q "^${host}" $generate_relayfromhosts

            if [ $? -eq 1 ]
            then
                # host not found, add it
              # echo "$host:"
                echo "$host"                                                   # v1.2.7
            fi

            idx=`expr $idx + 1`
        done
    } > $generate_relayfromhosts

    # set access rights
    chmod 0600 $generate_relayfromhosts
    chown exim $generate_relayfromhosts
    chgrp trusted $generate_relayfromhosts
}

#----------------------------------------------------------------------------------------
# creating exim configuration
#----------------------------------------------------------------------------------------
create_exim_config ()
{
    mecho "creating smtp configuration file ..."

    # read external exiscan av parameter file
    if [ "$EXISCAN_AV_ENABLED" = "yes" -a "$EXISCAN_AV_SCANNER" = "auto" -a -f $exiscan_av_parameters ]
    then
        mecho "- importing av config from file $exiscan_av_parameters ..."
    fi

    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_eximconf}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo '# This file is divided into several parts, all but the first of which are'
        echo "# headed by a line starting with the word \"begin\". Only those parts that"
        echo '# are required need to be present. Blank lines, and lines starting with #'
        echo '# are ignored.'

        #---------- IMPORTANT ---------- IMPORTANT ----------- IMPORTANT ---------------
        #
        # Whenever you change Exim's configuration file, you *must* remember to
        # HUP the Exim daemon, because it will not pick up the new configuration
        # until you do. However, any other Exim processes that are started, for
        # example, a process started by an MUA in order to send a message, will
        # see the new configuration as soon as it is in place.
        #
        # You do not need to HUP the daemon for changes in auxiliary files that
        # are referenced from this file. They are read every time they are used.
        #
        # It is usually a good idea to test a new configuration for syntactic
        # correctness before installing it (for example, by running the command
        # "exim -C /config/file.new -bV").
        #
        #---------- IMPORTANT ---------- IMPORTANT ----------- IMPORTANT ---------------

        echo
        echo '#==============================================================================='
        echo '# MAIN CONFIGURATION SETTINGS'
        echo '#==============================================================================='
        echo

        if [ "${MAIL_DO_DEBUG}" = "yes" ]
        then
            echo "# debug mode - log everything"
            echo "log_selector = +all"
        else
            echo "# normal mode - log only TLS specific information"
            # improved log settings, as recommended in the following document:
            # https://bettercrypto.org/static/applied-crypto-hardening.pdf
            # +tls_certificate_verified - log if peer certificate was verified (CV=yes), or not (CV=no)
            # +tls_peerdn               - log peer domain, preceded by DN=
            # +tls_sni                  - log Server Name Indication if provided, preceded by SNI=
            echo "log_selector = +tls_certificate_verified +tls_peerdn +tls_sni"
        fi

        echo

        if [ "$SMTP_AUTH_TYPE" = "user" -o "$SMTP_AUTH_TYPE" = "user_light" ]
        then
            echo "# We need /etc/shadow or /etc/cram-md5.pwd authentication and read permission:"
            echo "exim_user = root"
        else
            echo "exim_user = exim"
        fi

        echo

        # Specify your host's canonical name here. This should normally be the fully
        # qualified "official" name of your host. If this option is not set, the
        # uname() function is called to obtain the name. In many cases this does
        # the right thing and you need not set anything explicitly.

        echo "primary_hostname = $SMTP_HOSTNAME"
        echo

        # Most straightforward access control requirements can be obtained by
        # appropriate settings of the above options. In more complicated situations, you
        # may need to modify the Access Control List (ACL) which appears later in this
        # file.

        # The first setting specifies your local domains, for example:
        #
        #   domainlist local_domains = my.first.domain : my.second.domain
        #
        # You can use "@" to mean "the name of the local host", as in the default
        # setting above. This is the name that is specified by primary_hostname,
        # as specified above (or defaulted). If you do not want to do any local
        # deliveries, remove the "@" from the setting above. If you want to accept mail
        # addressed to your host's literal IP address, for example, mail addressed to
        # "user@[192.168.23.44]", you can add "@[]" as an item in the local domains
        # list. You also need to uncomment "allow_domain_literals" below. This is not
        # recommended for today's Internet.

        # local domains
        # 11.06.2004 JED - local_domains variable replaced by file lookup function

        echo "domainlist local_domains     = $generate_localdomains"
        create_local_domains

        # This custom domain list shows all domains for which sender
        # verification should be enabled. created by JED ;-)

        # my sender domains
        # 11.06.2004 JED - my_sender_domains variable replaced by file lookup function

        echo "domainlist my_sender_domains = $generate_mysenderdomains"
        create_my_sender_domains

        # The second setting specifies domains for which your host is an incoming relay.
        # If you are not doing any relaying, you should leave the list empty. However,
        # if your host is an MX backup or gateway of some kind for some domains, you
        # must set relay_to_domains to match those domains. For example:
        #
        # domainlist relay_to_domains = *.myco.com : my.friend.org
        #
        # This will allow any host to relay through your host to those domains.
        # See the section of the manual entitled "Control of relaying" for more
        # information.

        # relay to domains
        # 11.06.2004 JED - relay_to_domain variable replaced by file lookup function

        echo "domainlist relay_to_domains  = $generate_relaytodomains"
        create_relay_to_domains

        # mailman

        if [ $MAILMAN_INSTALLED -eq 1 -a -f $generate_mailmandomains ]
        then
            echo "domainlist mailman_domains = $generate_mailmandomains"
        fi

        # The third setting specifies hosts that can use your host as an outgoing relay
        # to any other host on the Internet. Such a setting commonly refers to a
        # complete local network as well as the localhost. For example:
        #
        # hostlist relay_from_hosts = 127.0.0.1 : 192.168.0.0/16
        #
        # The "/16" is a bit mask (CIDR notation), not a number of hosts. Note that you
        # have to include 127.0.0.1 if you want to allow processes on your host to send
        # SMTP mail by using the loopback address. A number of MUAs use this method of
        # sending mail.

        # relay from hosts
        # 11.06.2004 JED - relay_from_hosts variable replaced by file lookup function

        echo "hostlist   relay_from_hosts  = $generate_relayfromhosts"
        create_relay_from_hosts

        echo

        # All three of these lists may contain many different kinds of item, including
        # wildcarded names, regular expressions, and file lookups. See the reference
        # manual for details. The lists above are used in the access control list for
        # incoming messages, e.g. 'acl_check_rcpt'.

        # The following ACL entries are used if you want to do content scanning with
        # the exiscan-acl patch. When you uncomment this line, you must also review
        # the acl_check_data entry in the ACL section further below.

        if [ "${START_EXISCAN}" = "yes" ]
        then
          # echo 'acl_smtp_connect = acl_check_connect'
            echo 'acl_smtp_data    = acl_check_data'
            echo 'acl_smtp_mime    = acl_check_mime'
        fi

        echo 'acl_smtp_rcpt    = acl_check_rcpt'

        echo

        # You should not change that setting until you understand how ACLs work.

        # Specify the domain you want to be added to all unqualified addresses
        # here. An unqualified address is one that does not contain an "@" character
        # followed by a domain. For example, "caesar@rome.ex" is a fully qualified
        # address, but the string "caesar" (i.e. just a login name) is an unqualified
        # email address. Unqualified addresses are accepted only from local callers by
        # default. See the recipient_unqualified_hosts option if you want to permit
        # unqualified addresses from remote sources. If this option is not set, the
        # primary_hostname value is used for qualification.

        echo "qualify_domain = $SMTP_QUALIFY_DOMAIN"

        # No deliveries will ever be run under the uids of these users (a colon-
        # separated list). An attempt to do so causes a panic error to be logged, and
        # the delivery to be deferred. This is a paranoic safety catch. Note that the
        # default setting means you cannot deliver mail addressed to root as if it
        # were a normal user. This isn't usually a problem, as most sites have an alias
        # for root that redirects such mail to a human administrator.

      # echo '# never_users = root'
        echo 'never_users    = '

        # If this option is set, any process that is running as one of the listed
        # users is trusted. See section 5.2 for details of what trusted callers are
        # permitted to do. If neither "trusted_groups" nor "trusted_users" is set,
        # only root and the Exim user are trusted.

        trustuser=''

        # added for sn package support
        if [ $SN_INSTALLED -eq 1 ]
        then
            trustuser="news"
        fi

        # added for uucp package support
        if [ $UUCP_INSTALLED -eq 1 ]
        then
            if [ "${trustuser}" = "" ]
            then
                trustuser="uucp"
            else
                trustuser="${trustuser}:uucp"
            fi
        fi

        if [ "${trustuser}" != "" ]
        then
            echo "trusted_users  = ${trustuser}"
        fi

        # The setting below causes Exim to do a reverse DNS lookup on all incoming
        # IP calls, in order to get the true host name. If you feel this is too
        # expensive, you can specify the networks for which a lookup is done, or
        # remove the setting entirely.

        echo 'host_lookup    = *'

        # The settings below, which are actually the same as the defaults in the
        # code, cause Exim to make RFC 1413 (ident) callbacks for all incoming SMTP
        # calls. You can limit the hosts to which these calls are made, and/or change
        # the timeout that is used. If you set the timeout to zero, all RFC 1413 calls
        # are disabled. RFC 1413 calls are cheap and can provide useful information
        # for tracing problem messages, but some hosts and firewalls have problems
        # with them. This can result in a timeout instead of an immediate refused
        # connection, leading to delays on starting up an SMTP session.

        if [ "${SMTP_IDENT_CALLBACKS}" = "no" ]
        then
            echo "rfc1413_hosts = ! ${generate_relayfromhosts}"
            echo 'rfc1413_query_timeout = 5s'
        else
            echo 'rfc1413_hosts = *'
            echo 'rfc1413_query_timeout = 30s'
        fi

        echo

        # By default, Exim expects all envelope addresses to be fully qualified, that
        # is, they must contain both a local part and a domain. If you want to accept
        # unqualified addresses (just a local part) from certain hosts, you can specify
        # these hosts by setting one or both of

        echo "sender_unqualified_hosts    = localhost : $SMTP_HOSTNAME"
        echo "recipient_unqualified_hosts = localhost"
        echo

        # to control sender and recipient addresses, respectively. When this is done,
        # unqualified addresses are qualified using the settings of qualify_domain
        # and/or qualify_recipient (see above).

        # When Exim can neither deliver a message nor return it to sender, it "freezes"
        # the delivery error message (aka "bounce message"). There are also other
        # circumstances in which messages get frozen. They will stay on the queue for
        # ever unless one of the following options is set.

        # This option unfreezes frozen bounce messages after two days, tries
        # once more to deliver them, and ignores any delivery failures.

        echo 'ignore_bounce_errors_after = 2d'

        # This option cancels (removes) frozen messages that are older than a week.

        echo 'timeout_frozen_after = 7d'

        if [ "${SMTP_QUEUE_OUTBOUND_MAIL}" = "yes" ]
        then
            # queue outbound mail
            #
            # This option limits the number of delivery processes that Exim starts
            # automatically when receiving messages via SMTP, whether via the daemon or
            # by the use of -bs or -bS. If the value of the option is greater than zero,
            # and the number of messages received in a single SMTP session exceeds this
            # number, subsequent messages are placed on the queue, but no delivery
            # processes are started. This helps to limit the number of Exim processes
            # when a server restarts after downtime and there is a lot of mail waiting
            # for it on other systems. On large systems, the default should probably be
            # increased, and on dial-in client systems it should probably be set to zero
            # (that is, disabled). Default: 10

            echo 'smtp_accept_queue_per_connection = 0'

            # This option can be set to a colon-separated list of absolute path names,
            # each one optionally preceded by 'smtp'. When Exim is receiving a message,
            # it tests for the existence of each listed path using a call to "stat()".
            # For each path that exists, the corresponding queuing option is set. For
            # paths with no prefix, "queue_only" is set; for paths prefixed by 'smtp',
            # "queue_smtp_domains" is set to match all domains. So, for example,
            #
            # queue_only_file = smtp/some/file
            #
            # causes Exim to behave as if "queue_smtp_domains" were set to '*' whenever
            # /some/file exists.

            echo "queue_only_file = smtp${generate_queued}"

            echo "# queue file generated by ${pgmname} ${mail_version}" > ${generate_queued}
        else
            # don't queue outbound mail
            if [ "${SMTP_QUEUE_ACCEPT_PER_CONNECTION}" = "" ]
            then
                SMTP_QUEUE_ACCEPT_PER_CONNECTION=10
            fi

            echo "smtp_accept_queue_per_connection = ${SMTP_QUEUE_ACCEPT_PER_CONNECTION}"

            if [ -f ${generate_queued} ]
            then
                rm -f ${generate_queued}
            fi
        fi

        # recipients_max
        #
        # If this option is set greater than zero, it specifies the maximum number
        # of original recipients for any message. Additional recipients that are
        # generated by aliasing or forwarding do not count. SMTP messages get a
        # 452 response for all recipients over the limit; earlier recipients are
        # delivered as normal. Non-SMTP messages with too many recipients are failed,
        # and no deliveries are done.
        # Note that the RFCs specify that an SMTP server should accept at least
        # 100 RCPT commands in a single message.

        if [ "$SMTP_CHECK_RECIPIENTS" != "" ]
        then
            echo "recipients_max = $SMTP_CHECK_RECIPIENTS"
        else
            echo "recipients_max = 100"
        fi

        # On encountering certain errors, or when configured to do so in a system
        # filter, Exim freezes a message. This means that no further delivery
        # attempts take place until an administrator (or the "auto_thaw" feature)
        # thaws the message. If "freeze_tell" is set, Exim generates a warning
        # message whenever it freezes something, unless the message it is freezing
        # is a bounce message. (Without this exception there is the possibility of
        # looping.) The warning message is sent to the addresses supplied as the
        # comma-separated value of this option. If several of the message's
        # addresses cause freezing, only a single message is sent. The reason(s) for
        # freezing can be found in the message log.

        echo 'freeze_tell = postmaster'

        # This option specifies the default SMTP port on which the Exim daemon listens.
        # It can either be given as a number, or as a service name. It can be overridden
        # by giving an explicit port number on an IP address in the local_interfaces
        # option, or by using -oX on the command line. If this option is not set, the
        # service name ``smtp'' is used.

        if [ "${SMTP_LISTEN_PORT}" = "" ]
        then
            echo "daemon_smtp_ports = smtp : submission"
        else
            echo "daemon_smtp_ports = ${SMTP_LISTEN_PORT}"
        fi

        # This option limits the maximum size of message that Exim will process. The
        # value is expanded for each incoming message so, for example, it can be
        # made to depend on the IP address of the remote host for messages arriving
        # via TCP/IP. String expansion failure causes a temporary error. A value of
        # zero means no limit, but its use is not recommended. See also "return_size_limit".
        # Incoming SMTP messages are failed with a 552 error if the limit is exceeded;
        # locally-generated messages either get a stderr message or a delivery failure
        # message to the sender, depending on the -oe setting. Rejection of an oversized
        # message is logged in both the main and the reject logs. See also the generic
        # transport option "message_size_limit", which limits the size of message that
        # an individual transport can process. Default: 50M

        if [ "${SMTP_LIMIT}" != "" ]
        then
            SMTP_LIMIT="`unit_to_numeric ${SMTP_LIMIT}`"
        else
            # set to default of '50m' if not set
            SMTP_LIMIT="`unit_to_numeric '50m'`"
        fi

        echo "message_size_limit = ${SMTP_LIMIT}"

        # spline.eisfair posting 'Bloed angestellt / EMail verloren' of 12.02.2007 18:35h - S.Heidrich
        if [ "${START_FETCHMAIL}" = "yes" ]
        then
            # fetchmail enabled, go on ...
            if [ ${SMTP_LIMIT} -gt 0 ]
            then
                # value less than unlimited
                if [ ${SMTP_LIMIT} -lt ${FETCHMAIL_LIMIT} ]
                then
                    write_to_config_log -warn "Value of SMTP_LIMIT='${SMTP_LIMIT}' is less than value of FETCHMAIL_LIMIT='${FETCHMAIL_LIMIT}'!"
                    write_to_config_log -warn -ff "This may result in rejecting incoming mail from Fetchmail."
                fi
            fi
        fi

        # The four "check_..." options allow for checking of disc resources before
        # a message is accepted: "check_spool_space" and "check_spool_inodes" check
        # the spool partition if either value is greater than zero.
        # The spool partition is the one which contains the directory defined by
        # SPOOL_DIRECTORY in Local/Makefile. It is used for holding messages in
        # transit.
        # "check_log_space" and "check_log_inodes" check the partition in which log
        # files are written if either is greater than zero. These should be set only
        # if "log_file_path" and "spool_directory" refer to different partitions.
        # If there is less space or fewer inodes than requested, Exim refuses to
        # accept incoming mail. In the case of SMTP input this is done by giving a
        # 452 temporary error response to the MAIL command. If ESMTP is in use and
        # there was a SIZE parameter on the MAIL command, its value is added to the
        # "check_spool_space" value, and the check is performed even if
        # "check_spool_space" is zero, unless "no_smtp_check_spool_space" is set.
        #
        # check_spool_inodes = 100
        # check_spool_space  = 10M
        # check_log_inodes = 100
        # check_log_space  = 10M

        if [ "$SMTP_CHECK_SPOOL_INODES" != "" ]
        then
            echo "check_spool_inodes = $SMTP_CHECK_SPOOL_INODES"
        else
            echo 'check_spool_inodes = 100'
        fi

        if [ "$SMTP_CHECK_SPOOL_SPACE" != "" ]
        then
            echo "check_spool_space  = $SMTP_CHECK_SPOOL_SPACE"
        else
            echo 'check_spool_space  = 10M'
        fi

        # OpenSSL options, set as recommended in the following document:
        # https://bettercrypto.org/static/applied-crypto-hardening.pdf
        # +all                      - activates the most common OpenSSL workarounds only
        # +no_conmpression          - do not use TLS compression
        # +cipher_server_preference - use ciphers recommended by the server and not the client
        echo
        case ${EISFAIR_SYSTEM} in
            eisfair-1)
                # eisfair-1
                echo "openssl_options = +all +no_sslv2 +no_compression +cipher_server_preference"
                ;;
            *)
                # default: eisfair-2
                echo "openssl_options = +all +no_sslv2 +cipher_server_preference"
                ;;
        esac

        # SSL/TLS certificate handling
        if [ "$SMTP_SERVER_TRANSPORT" = "tls" -o "$SMTP_SERVER_TRANSPORT" = "both" ]
        then
            echo
            # The value of this option is expanded, and must then be the absolute path
            # to a file which contains the server's certificates. The server's private
            # key is also assumed to be in this file if "tls_privatekey" is unset.

            echo '# enable TLS/SSL server support'
            echo "tls_certificate = $sslcert_path/exim.pem"

            # The value of this option is expanded, and must then be the absolute path
            # to a file which contains the server's private key. If this option is
            # unset, the private key is assumed to be in the same file as the server's
            # certificates.

            echo "tls_privatekey  = $sslcert_path/exim.pem"

            # The value of this option is expanded, and must then be the absolute path
            # to a file which contains the server's DH parameter values.
            # (increases number of available ciphers)

            echo "tls_dhparam     = $sslcert_path/exim.pem"

            # When Exim is built with support for TLS encrypted connections, the
            # availability of the STARTTLS command to set up an encrypted session is
            # advertised in response to EHLO only to those client hosts that match
            # this option.

            if [ "$SMTP_SERVER_TLS_ADVERTISE_HOSTS" != "" ]
            then
                echo "tls_advertise_hosts = $SMTP_SERVER_TLS_ADVERTISE_HOSTS"
            else
                write_to_config_log -warn "Secure SMTP couldn't be used because \"SMTP_SERVER_TLS_ADVERTISE_HOSTS\""
                write_to_config_log -warn -ff "has not been set!"
            fi

            if [ "${SMTP_SERVER_TLS_VERIFY_HOSTS}" != "" -o \
                 "${SMTP_SERVER_TLS_TRY_VERIFY_HOSTS}" != "" -o \
                 "${SMTP_SERVER_TRANSPORT}" = "tls" ]
            then
                # This option specifies a certificate revocation list. The expanded value
                # must be the name of a file that contains a CRL in PEM format.

                echo

                if [ -d ${sslcrl_path} ]
                then
                    echo "tls_crl         = ${sslcrl_path}"
                else
                    write_to_config_log -error "Cannot activiate TLS CRL-handling because the directory"
                    write_to_config_log -error -ff "'${sslcrl_path}' doesn't exist!"
                fi

                # The value of this option is expanded, and must then be the absolute path
                # to a file or a directory containing permitted certificates for clients
                # that match "tls_verify_hosts" or "tls_try_verify_hosts".

                if [ -d ${sslcert_path} ]
                then
                    echo "tls_verify_certificates = ${sslcert_path}"
                else
                    write_to_config_log -error "Cannot activiate TLS verification handling because the"
                    write_to_config_log -error -ff "directory '${sslcert_path}' doesn't exist!"
                fi

                # This option, along with "tls_try_verify_hosts", controls the checking of
                # certificates from clients. Any client that matches "tls_verify_hosts" is
                # constrained by "tls_verify_certificates". The client must present one of
                # the listed certificates. If it does not, the connection is aborted.
                # A weaker form of checking is provided by "tls_try_verify_hosts". If a
                # client matches this option (but not "tls_verify_hosts"), Exim requests
                # a certificate and checks it against "tls_verify_certificates", but does
                # not abort the connection if there is no certificate or if it does not
                # match. This state can be detected in an ACL, which makes it possible to
                # implement policies such as 'accept for relay only if a verified certifi-
                # cate has been received, but accept for local delivery if encrypted, even
                # without a verified certificate'.
                # Client hosts that match neither of these lists are not asked to present
                # certificates.

                if [ "${SMTP_SERVER_TRANSPORT}" = "tls" ]
                then
                    # allow only secure connections
                    echo "tls_verify_hosts = *"
                    echo "tls_try_verify_hosts = *"
                else
                    if [ "${SMTP_SERVER_TLS_VERIFY_HOSTS}" != "" ]
                    then
                        # tls_verify_hosts - verify that no '*' entry exists
                        tlsflag=0
                        tlshosts=`echo "${SMTP_SERVER_TLS_VERIFY_HOSTS}"|sed 's/\*/\\\*/g'`

                        for THOST in ${tlshosts}
                        do
                            if [ "${THOST}" = "\*" ]
                            then
                                # '*' entry found
                                tlsflag=1
                            fi
                        done

                        if [ ${tlsflag} -eq 0 ]
                        then
                            echo "tls_verify_hosts = ${SMTP_SERVER_TLS_VERIFY_HOSTS}"
                        else
                            write_to_config_log -error "Separate '*' entry is not allowed in \"SMTP_SERVER_TLS_VERIFY_HOSTS\"!"
                            write_to_config_log -error "TLS verification will be disabled!"
                        fi
                    fi

                    if [ "${SMTP_SERVER_TLS_TRY_VERIFY_HOSTS}" != "" ]
                    then
                        # tls_try_verify_hosts - verify that no '*' entry exists
                        tlstryflag=0
                        tlstryhosts=`echo "${SMTP_SERVER_TLS_TRY_VERIFY_HOSTS}"|sed 's/\*/\\\*/g'`

                        for TVHOST in ${tlstryhosts}
                        do
                            if [ "${TVHOST}" = "\*" ]
                            then
                                # '*' entry found
                                tlstryflag=1
                            fi
                        done

                        if [ ${tlstryflag} -eq 0 ]
                        then
                            echo "tls_try_verify_hosts = ${SMTP_SERVER_TLS_TRY_VERIFY_HOSTS}"
                        else
                            write_to_config_log -error "Separate '*' entry is not allowed in \"SMTP_SERVER_TLS_TRY_VERIFY_HOSTS\"!"
                            write_to_config_log -error "TLS verification will be disabled!"
                        fi
                    fi
                fi
            fi
        fi

        if [ "${START_EXISCAN}" = "yes" ]
        then
            echo

            if [ "${EXISCAN_AV_ENABLED}" = "yes" ]
            then
                # read external av parameters file
                if [ "${EXISCAN_AV_SCANNER}" = "auto" -a -f ${exiscan_av_parameters} ]
                then
                    echo "# exiscan - av auto config ${param_file}"
                    read_exiscan_av_parameters ${exiscan_av_parameters}
                else
                    echo "# exiscan - manual config"
                fi

                if [ "${EXISCAN_AV_SCANNER}" = "" ]
                then
                    # set default to free clamAV scanner
                    EXISCAN_AV_SCANNER='clamd'
                fi

                if [ "${EXISCAN_AV_ENABLED}" = "yes" ]
                then
                    # EXISCAN_AV_SCANNER parameter valid and hasn't been disabled by
                    # function 'read_exiscan_av_parameters', therefore EXISCAN_AV_ENABLED='yes'
                    #
                    # This configuration variable defines the virus scanner that is used with
                    # the 'malware' ACL condition of the exiscan acl-patch. If you do not use
                    # virus scanning, leave it commented. Please read doc/exiscan-acl-readme.txt
                    # for a list of supported scanners.

                    case "${EXISCAN_AV_SCANNER}" in
                        sophie )
                            echo "av_scanner    = sophie:${EXISCAN_AV_SOCKET}"
                            ;;
                        kavdaemon ) # Kaspersky version 4 (http://www.kaspersky.com)
                            echo "av_scanner    = kavdaemon:${EXISCAN_AV_SOCKET}"
                            ;;
                        aveserver ) # Kaspersky version 5 (http://www.kaspersky.com)
                            echo "av_scanner    = aveserver:${EXISCAN_AV_SOCKET}"
                            ;;
                        clamd ) # Clamd (http://www.clamav.net/)
                            echo "av_scanner    = clamd:${EXISCAN_AV_SOCKET}"
                            ;;
                        drweb ) # DrWeb (http://www.sald.com/)
                            echo "av_scanner    = drweb:${EXISCAN_AV_SOCKET}"
                            ;;
                        fsecure ) # F-Secure (http://www.f-secure.com)
                            echo "av_scanner    = fsecure:${EXISCAN_AV_SOCKET}"
                            ;;
                        mksd ) # Mksd (http://linux.mks.com.pl/)
                            echo "av_scanner    = mksd:2"
                            ;;
                        cmdline )
                            echo "av_scanner    = cmdline:\\"
                            echo "                ${EXISCAN_AV_PATH} ${EXISCAN_AV_OPTIONS}:\\"
                            echo "                ${EXISCAN_AV_TRIGGER}:${EXISCAN_AV_DESCRIPTION}"
                            ;;
                    esac
                fi
            fi

            # The following setting is only needed if you use the 'spam' ACL condition
            # It specifies on which host and port the SpamAssassin "spamd" daemon should
            # listening. If you do not use this condition, or you use the default of
            # "127.0.0.1 783", you can omit this option.

            if [ "${EXISCAN_SPAMD_ENABLED}" = "yes" ]
            then
                echo "spamd_address = ${EXISCAN_SPAMD_ADDRESS}"
            fi

        fi

        # This following option specifies how much of a message's body is to be included
        # in the $message_body and $message_body_end expansion variables. Default: 500

        echo
        echo "message_body_visible = 5000"

        ls ${custom_systemfilter}.* > /dev/null 2> /dev/null

        if [ $? -eq 0 -o "${START_EXISCAN}" = "yes" ]
        then
            # This option specifies a filter file which is applied to all messages at
            # the start of each delivery attempt, before any routing is done. This is
            # called the 'system message filter'.
            #
            # If this option is not set, the system filter is run in the main Exim
            # delivery process, as root. When the option is set, the system filter runs
            # in a separate process, as the given user. Unless the string consists
            # entirely of digits, it is looked up in the password data. Failure to find
            # the named user causes a configuration error. The gid is either taken from
            # the password data, or specified by "system_filter_group". When the uid is
            # specified numerically, "system_filter_group" is required to be set.

            echo
            echo "system_filter      = ${generate_systemfilter}"
            echo 'system_filter_user = exim'

            # This parameter specifies the transport driver that is to be used when a
            # pipe command is used in a system filter. During the delivery, the variable
            # $address_pipe contains the pipe command.

            echo 'system_filter_pipe_transport  = address_pipe'

            # This parameter sets the name of the transport driver that is to be used
            # when the save command in a system message filter specifies a path not
            # ending in ./.. During the delivery, the variable $address_file contains
            # the path name.

            echo 'system_filter_file_transport  = address_file'

            # This parameter specifies the transport driver that is to be used when a
            # mail command is used in a system filter.

            echo 'system_filter_reply_transport = address_reply'
        fi

        echo
        echo '#==============================================================================='
        echo '# ACL CONFIGURATION'
        echo '#==============================================================================='
        echo

        # Specifies access control lists for incoming SMTP mail

        echo 'begin acl'
        echo

        # Include SPF (sender policy framework) ACL if exist
        if [ -f ${spf_aclfile} -a -f ${spf_aclrcptfile} ]
        then
            echo "# spf acl include"
            echo ".include ${spf_aclfile}"
            echo
        fi

        # The ACL test specified by acl_smtp_connect happens at the start of an SMTP
        # session, after the test specified by host_reject_connection (which is now an
        # anomaly) and any TCP Wrappers testing (if configured). If the connection is
        # accepted by an accept verb that has a message modifier, the contents of the
        # message override the banner message that is otherwise specified by the
        # smtp_banner option.

        #= acl_check_connect ============================================================

      # echo 'acl_check_connect:'

      # echo

      # # finally accept all the rest
      # echo "  accept"
      # echo

        # This access control list is used for every RCPT command in an incoming
        # SMTP message. The tests are run in order until the address is either
        # accepted or denied.

        #= acl_check_rcpt ===============================================================

        echo
        echo 'acl_check_rcpt:'

        # Accept if the source is local SMTP (i.e. not over TCP/IP). We do this by
        # testing for an empty sending host field.

        echo '  accept  hosts          = :'

        # Add local part check for fax addresses, e.g. 'faxg3/112233@domain.tld'

        if [ ${EISFAX_INSTALLED} -eq 1 ]
        then
            echo
            echo '  accept  local_parts    = ^faxg3\/'
            echo '          domains        = +local_domains'
            echo '          endpass'
            echo '          message        = Fax access has been restricted'
            echo "          senders        = *@+local_domains : lsearch*@;${eisfax_addresses}"
        else
            echo
            echo '  deny    message        = No mail2fax gateway available'
            echo '          local_parts    = ^faxg3\/'
            echo '          domains        = +local_domains'
        fi

        if [ ${MAIL2PRINT_INSTALLED} -eq 1 ]
        then
            echo
            echo '  accept  local_parts    = ^print\/'
            echo '          domains        = +local_domains'
            echo '          endpass'
            echo '          message        = Print access has been restricted'
            echo "          senders        = *@+local_domains : lsearch*@;${mail2print_addresses}"
        else
            echo
            echo '  deny    message        = No mail2print gateway available'
            echo '          local_parts    = ^print\/'
            echo '          domains        = +local_domains'
        fi

        # Deny if the local part contains @ or % or / or | or !. These are rarely
        # found in genuine local parts, but are often tried by people looking to
        # circumvent relaying restrictions.

        # Also deny if the local part starts with a dot. Empty components aren't
        # strictly legal in RFC 2822, but Exim allows them because this is common.
        # However, actually starting with a dot may cause trouble if the local part
        # is used as a file name (e.g. for a mailing list).

        # Don't allow specific characters in local part of an address, including
        # '/' if mail is addressed to a local domain.

        echo
        echo '  deny    message        = Restricted characters in address'
        echo '          domains        = +local_domains'
        echo '          local_parts    = ^[./|] : ^.*[@%!/|] : ^\\. : ^.*/\\.\\./'

        # Don't allow specific characters in local part of an address, including
        # '/' if mail is addressed to a non local domain - be less restrictive.

        echo
        echo '  deny    message        = Restricted characters in address'
        echo '          domains        = !+local_domains'
        echo '          local_parts    = ^[./|] : ^.*[@%!|] : ^\\. : ^.*/\\.\\./'

        # Accept mail to postmaster in any local domain, regardless of the source,
        # and without verifying the sender.

        echo
        echo '  accept  local_parts    = postmaster'
        echo "          domains        = +local_domains"

        # Deny unless the sender address can be verified.

        echo
        echo '  require verify         = sender'

        #############################################################################
        # There are no checks on DNS "black" lists because the domains that contain
        # these lists are changing all the time. However, here are two examples of
        # how you could get Exim to perform a DNS black list lookup at this point.
        # The first one denies, while the second just warns.
        #
        # deny    message       = rejected because $sender_host_address is in a black
        #                         list at $dnslist_domain\n$dnslist_text
        #         dnslists      = black.list.example
        #
        # warn    message       = X-Warning: $sender_host_address is in a black list
        #                         at $dnslist_domain
        #         log_message   = found in $dnslist_domain
        #         dnslists      = black.list.example
        #############################################################################


        if [ "${SMTP_AUTH_TYPE}" = "user" -o "${SMTP_AUTH_TYPE}" = "server" ]
        then
            # This function has been added to only accept authenticated connection on
            # port 587/tcp as described on http://serverfault.com/questions/58392/how-
            # can-i-configure-exim-to-drop-non-authenticated-connections-on-alternate-smtp

            echo
            echo '  deny    condition      = ${if eq{$interface_port}{587}}'
            echo '          sender_domains = +my_sender_domains'
            echo '         !authenticated  = *'
            echo '          message        = All port 587 connections must be authenticated'

            # This function has been added to make sure that a mail user uses his
            # own email address for sending and not the address of someone else.
            #
            # Reported by: Karl Gatzweiler
            # Date: Thu, 03 Jul 2003 21:28:24 +0200 ??
            # Subject: Re: smtp prueft pw nicht richtig (versuch 2)

            echo
            echo "  accept  sender_domains = +my_sender_domains"
            echo '          endpass'
            echo '          message        = Only authenticated connections are allowed'
            echo '          authenticated  = *'
        fi

        # Accept if the address is in a local domain, but only if the recipient can
        # be verified. Otherwise deny. The "endpass" line is the border between
        # passing on to the next ACL statement (if tests above it fail) or denying
        # access (if tests below it fail).

        echo
        echo "  accept  domains        = +local_domains"
        echo '          endpass'
        echo '          message        = Unknown user'
        echo '          verify         = recipient'

        # Forward mail only to recipients who are listed in the recipients_ok.list file.
        # (S.Heidrich)
        if [ -f ${recipient_okfile} ]
        then
            echo
            echo '  drop    log_message    = recipient not in recipients_ok.list'
            echo '          domains        = +relay_to_domains'
            echo "         !recipients     = ${recipient_okfile}"
        fi

        # Accept if the address is in a domain for which we are relaying, but again,
        # only if the recipient can be verified.

        echo
        echo "  accept  domains        = +relay_to_domains"
        echo '          endpass'
        echo '          message        = Unrouteable address'
        echo '          verify         = recipient'

        # If control reaches this point, the domain is neither in +local_domains
        # nor in +relay_to_domains.

        # Accept if the message comes from one of the hosts for which we are an
        # outgoing relay. Recipient verification is omitted here, because in many
        # cases the clients are dumb MUAs that don't cope well with SMTP error
        # responses. If you are actually relaying out from MTAs, you should probably
        # add recipient verification here.

        echo
        echo "  accept  hosts          = +relay_from_hosts"

        # Include SPF (sender policy framework) ACL check if exist
        if [ -f ${spf_aclfile} -a -f ${spf_aclrcptfile} ]
        then
            echo
            echo "# spf acl include"
            echo ".include ${spf_aclrcptfile}"
        fi

        # Accept if the message arrived over an authenticated connection, from
        # any host. Again, these messages are usually from MUAs, so recipient
        # verification is omitted.

        echo
        echo '  accept  authenticated  = *'

        # Reaching the end of the ACL causes a "deny", but we might as well give
        # an explicit message.

        echo
        echo '  deny    message        = Relaying not permitted'
        echo

        # This access control list is used for content scanning with the exiscan-acl
        # patch. You must also uncomment the entry for acl_smtp_data (scroll up),
        # otherwise the ACL will not be used. IMPORTANT: the default entries here
        # should be treated as EXAMPLES. You MUST read the file doc/exiscan-acl-spec.txt
        # to fully understand what you are doing ...

        exiscan_redirect=0

        if [ "${START_EXISCAN}" = "yes" ]
        then
            exiscan_mime_err_msg="This message contains a MIME error (\$mime_anomaly_text)"
            exiscan_mime_too_many_msg="This message contains too many parts (max 1024)"
            exiscan_mime_max_exceed_msg="This message contains a line which length exceeds 8000 characters"
            exiscan_mime_partial_msg="This message contains an unallowed MIME type (message/partial)"
            exiscan_mime_exceed_msg="This message contains a filename which exceeds 255 characters"
            exiscan_mime_boundary_msg="This message contains a MIME boundary which exceeds 1024 characters"
            exiscan_extension_msg="This message contains an unwanted file extension (\$found_extension) in '\$mime_filename'"
            exiscan_av_msg="This message contains malware (\$malware_name)"
            exiscan_av_auth_msg="Malware scan skipped; message has been sent by an authenticated user (\$authenticated_id)"
            exiscan_av_auth_config_msg="Malware scan will be skipped for authenticated users!"
            exiscan_regex_msg="This message matches a blacklisted regular expression (\$regex_match_string)"
            exiscan_spamd_msg="This message exceeds the spam threshold (\$spam_score points)"
            exiscan_spamd_size_msg="Spam scan skipped; message exceeds size limit (\$message_size of ${EXISCAN_SPAMD_LIMIT})"
            exiscan_spamd_size_config_msg="Spam scan threshold has been set to a maximum of ${EXISCAN_SPAMD_LIMIT} Byte!"
            exiscan_spamd_auth_msg="Spam scan skipped; message has been sent by an authenticated user (\$authenticated_id)"
            exiscan_spamd_auth_config_msg="Spam scan will be skipped for authenticated users!"
            exiscan_av_spamd_auth_msg="Malware and spam scan skipped; message has been sent by an authenticated user (\$authenticated_id)"
            exiscan_av_spamd_auth_config_msg="Malware and spam scan will be skipped for authenticated users!"

            #= acl_check_mime ===========================================================

            echo
            echo 'acl_check_mime:'

            #- mime ---------------------------------------------------------------------

            if [ "${EXISCAN_DEMIME_ENABLED}" = "yes" -o "${EXISCAN_AV_ENABLED}" = "yes" ]
            then
                echo "  # exiscan - mime"

                # Decode MIME parts to disk. This will support virus scanners later.
                echo "  warn    decode      = default"
                echo
            fi

            if [ "${EXISCAN_DEMIME_ENABLED}" = "yes" ]
            then

                # action on virus: pass, reject, discard, freeze, redirect <address>
                echo ${EXISCAN_DEMIME_ACTION} | grep -q '^redirect'

                if [ $? -eq 0 ]
                then
                    # redirect - get address
                    exiscan_action=`echo ${EXISCAN_DEMIME_ACTION} | cut -d' ' -f1`
                    exiscan_addr=`echo ${EXISCAN_DEMIME_ACTION} | cut -d' ' -f2`
                    exiscan_redirect=1
                else
                    exiscan_action=${EXISCAN_DEMIME_ACTION}
                    exiscan_addr=''
                fi

                case ${exiscan_action} in
                    pass ) # let message pass
                        acl1=''
                        aclmsg='passed'
                        ;;
                    reject ) # reject message
                        acl1='deny   '
                        aclmsg='rejected'
                        ;;
                    discard ) # discard message
                        acl1='discard'
                        aclmsg='discarded'
                        ;;
                    freeze ) # freeze message
                        acl1='warn   '
                        aclmsg='froozen'
                        ;;
                    redirect ) # redirect message
                        acl1='warn   '
                        aclmsg="redirected to ${exiscan_addr}"
                        ;;
                esac

                # MIME error
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if >{\$mime_anomaly_level}{2}{true}{false}}"
                echo "          log_message = ${exiscan_mime_err_msg} - ${aclmsg}"
                echo

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if >{\$mime_anomaly_level}{2}{true}{false}}"
                    echo "          message     = ${exiscan_mime_err_msg}"
                    echo
                fi

                # too many MIME parts (max 1024)"
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if >{\$mime_part_count}{1024}{yes}{no}}"
                echo "          log_message = ${exiscan_mime_too_many_msg} - ${aclmsg}"
                echo

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if >{\$mime_part_count}{1024}{yes}{no}}"
                    echo "          message     = ${exiscan_mime_too_many_msg}"
                    echo
                fi

                # line length exceeds 8000 characters
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          regex       = ^.{8000}"
                echo "          log_message = ${exiscan_mime_max_exceed_msg} - passed"
                echo

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          regex       = ^.{8000}"
                    echo "          message     = ${exiscan_mime_max_exceed_msg}"
                    echo
                fi

                # unallowed MIME type (message/partial)
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if eq {\$mime_content_type}{message/partial}{yes}{no}}"
                echo "          log_message = ${exiscan_mime_partial_msg} - ${aclmsg}"
                echo

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if eq {\$mime_content_type}{message/partial}{yes}{no}}"
                    echo "          message     = ${exiscan_mime_partial_msg}"
                    echo
                fi

                # proposed filename exceeds 255 characters
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if >{\${strlen:\$mime_filename}}{255}{yes}{no}}"
                echo "          log_message = ${exiscan_mime_exceed_msg} - ${aclmsg}"
                echo

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if >{\${strlen:\$mime_filename}}{255}{yes}{no}}"
                    echo "          message     = ${exiscan_mime_exceed_msg}"
                    echo
                fi

                # MIME boundary exceeds 1024 characters"
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if >{\${strlen:\$mime_boundary}}{1024}{yes}{no}}"
                echo "          log_message = ${exiscan_mime_boundary_msg} - ${aclmsg}"

                if [ "${acl1}" != "" ]
                then
                    echo
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if >{\${strlen:\$mime_boundary}}{1024}{yes}{no}}"

                    if [ "$exiscan_action" = "redirect" ]
                    then
                        echo "          message     = X-Redirect-To: ${exiscan_addr}"
                    else
                        echo "          message     = ${exiscan_mime_boundary_msg}"
                    fi
                fi

                case ${exiscan_action} in
                    freeze )
                        echo "          control     = freeze"
                        ;;
                    redirect )
                        echo "          set acl_m0  = 1"
                        ;;
                esac

                echo
            fi

            #- extension ----------------------------------------------------------------

            # Decode MIME parts to disk. This will support virus scanners later.

            if [ "${EXISCAN_EXTENSION_ENABLED}" = "yes" ]
            then
                echo "  # exiscan - extension"

                # action on virus: pass, reject, discard, freeze, redirect <address>
                echo ${EXISCAN_EXTENSION_ACTION} | grep -q '^redirect'

                if [ $? -eq 0 ]
                then
                    # redirect - get address
                    exiscan_action=`echo ${EXISCAN_EXTENSION_ACTION}|cut -d' ' -f1`
                    exiscan_addr=`echo ${EXISCAN_EXTENSION_ACTION}|cut -d' ' -f2`
                    exiscan_redirect=1
                else
                    exiscan_action=${EXISCAN_EXTENSION_ACTION}
                    exiscan_addr=''
                fi

                # convert extension list, 'exe:vbs:reg' -> 'exe|vbs|reg'
                exiscan_extension_list="`echo \"${EXISCAN_EXTENSION_DATA}\" | tr ':' '|'`"

                case ${exiscan_action} in
                    pass ) # let message pass
                        acl1=''
                        aclmsg='passed'
                        ;;
                    reject ) # reject message
                        acl1='deny   '
                        aclmsg='rejected'
                        ;;
                    discard ) # discard message
                        acl1='discard'
                        aclmsg='discarded'
                        ;;
                    freeze ) # freeze message
                        acl1='warn   '
                        aclmsg='froozen'
                        ;;
                    redirect ) # redirect message
                        acl1='warn   '
                        aclmsg="redirected to ${exiscan_addr}"
                        ;;
                esac

                # block extension(s)
                echo "  warn    condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                echo "          condition   = \${if match {\${lc:\$mime_filename}} \\"
                echo "                          {[.] *(${exiscan_extension_list})\\\$}{1}{0}}"
                # alternative condition syntax - added for testing purposes
              # echo "                          {\\N\\.\\s\*(${exiscan_extension_list})\\s\*\$\\N}{1}{0}}"
                echo "          log_message = ${exiscan_extension_msg} - ${aclmsg}"

                if [ "${acl1}" != "" ]
                then
                    echo "  ${acl1} condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                    echo "          condition   = \${if match {\${lc:\$mime_filename}} \\"
                    echo "                          {[.] *(${exiscan_extension_list})\\\$}{1}{0}}"
                    # alternative condition syntax - added for testing purposes
                  # echo "                          {\\N\\.\\s\*(${exiscan_extension_list})\\s\*\$\\N}{1}{0}}"

                    if [ "$exiscan_action" = "redirect" ]
                    then
                        echo "          message     = X-Redirect-To: ${exiscan_addr}"
                    else
                        echo "          message     = ${exiscan_extension_msg}"
                    fi
                fi

                case ${exiscan_action} in
                    freeze )
                        echo "          control     = freeze"
                        ;;
                    redirect )
                        echo "          set acl_m0  = 1"
                        ;;
                esac
            fi

            # finally accept all the rest
            echo "  accept"
            echo

            #= acl_check_data ===========================================================

            echo
            echo 'acl_check_data:'

# JED/04.05.2008 - experimental - needs to be checked because problems with mailing lists
#                  have been reported
      #     # allow only authenticated connections if From:-address-domain is in +local_domains
      #     if [ "${SMTP_AUTH_TYPE}" = "user" -o "${SMTP_AUTH_TYPE}" = "server" ]
      #     then
      #         # header: From: <local@domain.de>
      #         echo "  deny    message        = Only authenticated connections are allowed!"
      #         echo "          condition      = \${if match_domain{\${domain:\${address:\$h_from:}}}{+local_domains}{1}{0}}"
      #         echo '         !authenticated  = *'
      #         echo
      #     fi

            # make sure that each message is only checked once, to save processing time.
            echo "  # exiscan - check cryptographic header"
            echo "  accept  condition   = \${if eq {\${hmac{md5}{${EXISCAN_CRYPT_SALT}}\\"
            echo "                        {\$body_linecount}}}{\$h_X-Scan-Signature:} {1}{0}}"
            echo

            # keep all files in the scan/<msgid> directory for debugging purposes
            if [ "${EXISCAN_DO_DEBUG}" = "yes" ]
            then
                echo "# exiscan - don't delete files in scan directory"
                echo "          control     = no_mbox_unspool"
                echo
            fi

            # initialize flag
            echo "  # exiscan - initialize flag"
            echo "  warn    set acl_m0  = 0"     # indicates if message should redirected     - default: 0 - no redirection
            echo "  warn    set acl_m1  = 0"     # indicates if sender has been authenticated - default: 0 - not authenticated
            echo "  warn    set acl_m2  = 0"     # indicates if malware scanner is available  - default: 0 - available
            echo "  warn    set acl_m3  = 1"     # indicates if spam scanner is available     - default: 1 - not available
            echo


            # check for authenticated connection
            if [ "${EXISCAN_AV_ENABLED}" = "yes" -o "${EXISCAN_SPAMD_ENABLED}" = "yes" ]
            then
                if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" -o "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                then
                    # check if sender has been authenticated
                    echo "  # exiscan - check authentication"
                    echo '  warn    authenticated = *'
                    echo "          set acl_m1    = 1"
                    echo

                    # debug helper
                    echo "  warn    logwrite      = authenticated (\$acl_m1) / authenticated_id (\$authenticated_id)"
                    echo
                fi
            fi

            #- antivirus ----------------------------------------------------------------

            if [ "${EXISCAN_AV_ENABLED}" = "yes" ]
            then
                echo "  # exiscan - malware"

                # check for running scanner
                if [ "${EXISCAN_ACTION_ON_FAILURE}" != "pass" ]
                then
                    echo "  # exiscan - check malware scanner availability"
                    acl2='warn'
                    if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "  warn    condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        acl2='    '
                    fi

                    echo "  ${acl2}   !malware       = *"
                    echo "          set acl_m2    = 1"
                    echo
                fi

                # modify subject line
                if [ "${EXISCAN_AV_SUBJECT_TAG}" != "" ]
                then
                    av_tag="`insert_virus_name \"${EXISCAN_AV_SUBJECT_TAG}\"`"
                    av_tag="`insert_hostname \"${av_tag}\"`"
                    av_tag="`insert_date \"${av_tag}\"`"
                    av_subject="${av_tag} \$h_subject:"

                    echo "  warn    message       = X-New-Virus-Subject: ${av_subject}"
                    if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    echo "          malware       = *"
                    echo
                fi

                # action on virus: pass, reject, discard, freeze, redirect <address>
                echo ${EXISCAN_AV_ACTION} | grep -q '^redirect'

                if [ $? -eq 0 ]
                then
                    # redirect - get address
                    exiscan_action=`echo ${EXISCAN_AV_ACTION}|cut -d' ' -f1`
                    exiscan_addr=`echo ${EXISCAN_AV_ACTION}|cut -d' ' -f2`
                    exiscan_redirect=1
                else
                    exiscan_action=${EXISCAN_AV_ACTION}
                    exiscan_addr=''
                fi

                case ${exiscan_action} in
                    pass ) # let message pass
                        echo "  warn    log_message   = ${exiscan_av_msg} - passed"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus-Flag: YES"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus: \$malware_name"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        ;;
                    reject ) # reject message
                        echo "  warn    log_message   = ${exiscan_av_msg} - rejected"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  deny    message       = ${exiscan_av_msg}"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        ;;
                    discard ) # discard message
                        echo "  warn    log_message   = ${exiscan_av_msg} - discarded"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  discard message       = ${exiscan_av_msg}"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        ;;
                    freeze ) # freeze message
                        echo "  warn    log_message   = ${exiscan_av_msg} - froozen"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus-Flag: YES"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus: \$malware_name"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = ${exiscan_av_msg}"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo "          control       = freeze"
                        ;;
                    redirect ) # redirect message to address
                        echo "  warn    log_message   = ${exiscan_av_msg} - redirected to ${exiscan_addr}"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus-Flag: YES"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-New-Virus: \$malware_name"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo
                        echo "  warn    message       = X-Redirect-To: ${exiscan_addr}"
                        if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        echo "          malware       = *"
                        echo "          set acl_m0    = 1"
                        ;;
                esac

                echo

                if [ "${EXISCAN_ACTION_ON_FAILURE}" != "pass" ]
                then
                    case ${EXISCAN_ACTION_ON_FAILURE} in
                        defer ) # temporary error, 4xx response
                            echo "  defer   log_message   = The message has been defered because a malware scanner is unavailable"
                            ;;
                        drop )  # permanent error, 5xx response
                            echo "  drop    log_message   = The message has been dropped because a malware scanner is unavailable"
                            ;;
                    esac

                    if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    echo "          condition     = \${if ={\$acl_m2}{0}{1}{0}}"
                    echo
                fi
            fi

            #- spam ---------------------------------------------------------------------

            if [ "${EXISCAN_SPAMD_ENABLED}" = "yes" ]
            then
                echo "  # exiscan - spam - header style: ${EXISCAN_SPAMD_HEADER_STYLE}"

                # check for running scanner
                if [ "${EXISCAN_ACTION_ON_FAILURE}" != "pass" ]
                then
                    echo "  # exiscan - check spam scanner availability"
                    acl2='warn'
                    if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "  ${acl2}    condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        acl2='    '
                    fi

                    if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                    then
                        echo "  ${acl2}    condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        acl2='    '
                    fi

                    # the acl_m3 variable won't be set to '0' if spamd isn't available
                    # because the ACL will be skipped in that case. Therefore the default
                    # assumtion is that no spam scanner is available (acl_m3 = 1)
                    echo "  ${acl2}    spam          = nobody:true"
                    echo "          set acl_m3    = 0"
                    echo
                fi

                # extract spam threshold
                echo "${EXISCAN_SPAMD_THRESHOLD}" | grep -q \.

                if [ $? -eq 0 ]
                then
                    # decimal point found - remove it
                    exiscan_int=`echo "${EXISCAN_SPAMD_THRESHOLD}"|cut -d\. -f1`
                    exiscan_rest=`echo "${EXISCAN_SPAMD_THRESHOLD}"|cut -d\. -f2|cut -c1`
                    exiscan_threshold="${exiscan_int}${exiscan_rest}"
                else
                    exiscan_threshold=`expr ${EXISCAN_SPAMD_THRESHOLD} \* 10`
                fi

                # This setting defines how much information the spamd facility will add to
                # the headers of the message. The following settings are available:
                #
                # none   - This will not add any spam info header to the message. When not using
                #          exiscan_spamd_threshold, this is quite useless.
                # single - This will add the X-Spam-Score header (see the HEADERS section below)
                # flag   - This will add the X-Spam-Score header and, if the messages' score is
                #          over the threshold, the X-Spam-Flag header. (see the HEADERS section below)
                # full   - This will add the X-Spam-Score header and, if the messages' score is
                #          over the threshold, the X-Spam-Flag header and the FULL spamassassin
                #          report in clear text as a multiline header called "X-Spam-Report".

                case ${EXISCAN_SPAMD_HEADER_STYLE} in
                    none ) # no header at all
                        acl2='warn'
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "  ${acl2}    condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                            acl2='    '
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "  ${acl2}    condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                            echo "          condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        else
                            echo "  warn    condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        fi

                        echo "          spam          = nobody:true"
                        ;;

                    single )
                        #-------------------------------------------------------------------------------
                        # always add X-Spam-Score
                        echo "  warn    message       = X-New-Spam-Score: \$spam_score (\$spam_bar)"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi
                        echo "          condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        echo "          spam          = nobody:true"
                        ;;
                    flag )
                        #-------------------------------------------------------------------------------
                        # always add X-Spam-Score
                        echo "  warn    message       = X-New-Spam-Score: \$spam_score (\$spam_bar)"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
#                           echo "          condition     = \${if eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}{1}{0}}"
#                           echo "          condition     = \${if !={\$acl_m1}{1}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi

                        echo "          condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        echo "          spam          = nobody:true"
                        echo

                        echo "  warn    message       = X-New-Spam-Flag: YES"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi

                        echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"
                        echo "          spam          = nobody:true"
                        ;;
                    full|alwaysfull )
                        #-------------------------------------------------------------------------------
                        # always add X-Spam-Score
                        echo "  warn    message       = X-New-Spam-Score: \$spam_score (\$spam_bar)"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi

                        echo "          condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        echo "          spam          = nobody:true"
                        echo

                        # add X-Spam-Flag and X-Spam-Report headers if spam is over system-wide threshold
                        echo "  warn    message       = X-New-Spam-Flag: YES"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi

                        echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"

                        echo "          spam          = nobody:true"
                        echo
                        echo "  warn    message       = X-New-Spam-Report: \$spam_report"
                        if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                        then
                            echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                        then
                            echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                        fi

                        if [ "${EXISCAN_SPAMD_HEADER_STYLE}" = "alwaysfull" ]
                        then
                            echo "          condition     = \${if ={\$acl_m0}{0}{1}{0}}"
                        else
                            echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"
                        fi

                        echo "          spam          = nobody:true"
                        ;;
                esac

                echo

                # modify subject line
                if [ "${EXISCAN_SPAMD_SUBJECT_TAG}" != "" ]
                then
                    spam_tag="`insert_spam_score \"${EXISCAN_SPAMD_SUBJECT_TAG}\"`"
                    spam_tag="`insert_hostname \"${spam_tag}\"`"
                    spam_tag="`insert_date \"${spam_tag}\"`"
                    spam_subject="${spam_tag} \$h_subject:"

                    echo "  warn    message       = X-New-Spam-Subject: ${spam_subject}"
                    if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                    then
                        echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                    fi

                    echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"
                    echo "          spam          = nobody:true"
                    echo
                fi

                # action on spam: pass, reject, discard, freeze, redirect <address>
                echo ${EXISCAN_SPAMD_ACTION} | grep -q '^redirect'

                if [ $? -eq 0 ]
                then
                    # redirect - get address
                    exiscan_action=`echo ${EXISCAN_SPAMD_ACTION}|cut -d' ' -f1`
                    exiscan_addr=`echo ${EXISCAN_SPAMD_ACTION}|cut -d' ' -f2`
                    exiscan_redirect=1
                else
                    exiscan_action=${EXISCAN_SPAMD_ACTION}
                    exiscan_addr=''
                fi

                case ${exiscan_action}
                in
                    pass ) # let message pass
                        acl1=''
                        aclmsg='passed'
                        ;;

                    reject ) # reject message
                        acl1='deny   '
                        aclmsg='rejected'
                        ;;

                    discard ) # discard message
                        acl1='discard'
                        aclmsg='discarded'
                        ;;

                    freeze ) # freeze message
                        acl1='warn   '
                        aclmsg='froozen'
                        ;;
                    redirect ) # redirect message
                        acl1='warn   '
                        aclmsg="redirected to ${exiscan_addr}"
                        ;;
                esac

                echo "  warn    log_message   = ${exiscan_spamd_msg} - ${aclmsg}"
                if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                then
                    echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                fi

                if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                then
                    echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                fi

                echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"
                echo "          spam          = nobody:true"

                if [ "${acl1}" != "" ]
                then
                    echo

                    if [ "${exiscan_action}" = "redirect" ]
                    then
                        echo "  ${acl1} message       = X-Redirect-To: ${exiscan_addr}"
                    else
                        echo "  ${acl1} message       = ${exiscan_spamd_msg}"
                    fi

                    if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                    then
                        echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                    fi

                    echo "          condition     = \${if and{{={\$acl_m0}{0}}{>{\$spam_score_int}{${exiscan_threshold}}}}{1}{0}}"
                    echo "          spam          = nobody:true"
                fi

                case ${exiscan_action} in
                    freeze )
                        echo "          control       = freeze"
                        ;;
                    redirect )
                        echo "          set acl_m0    = 1"
                        ;;
                esac

                echo

                # write log file entry
                if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                then
                    # message size exceeds scan threshold, no scan done
                    echo "  warn    log_message   = ${exiscan_spamd_size_msg}"
                    if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    echo "          condition     = \${if >{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                    echo

                    write_to_config_log -info "${exiscan_spamd_size_config_msg}"
                fi

                if [ "${EXISCAN_ACTION_ON_FAILURE}" != "pass" ]
                then
                    case ${EXISCAN_ACTION_ON_FAILURE} in
                        defer ) # temporary error, 4xx response
                            echo "  defer   log_message   = The message has been defered because a spam scanner is unavailable"
                            ;;
                        drop )  # permanent error, 5xx response
                            echo "  drop    log_message   = The message has been dropped because a spam scanner is unavailable"
                            ;;
                    esac

                    if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                    then
                        echo "          condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    fi

                    if [ "${EXISCAN_SPAMD_LIMIT}" != "0" -a "${EXISCAN_SPAMD_LIMIT}" != "" ]
                    then
                        echo "          condition     = \${if <{\$message_size}{${EXISCAN_SPAMD_LIMIT}}{1}{0}}"
                    fi

                    echo "          condition     = \${if ={\$acl_m3}{1}{1}{0}}"
                    echo
                fi
            fi

            #- malware and spam ---------------------------------------------------------

            # log if scans have been skipped
            if [ "${EXISCAN_AV_ENABLED}" = "yes" -o "${EXISCAN_SPAMD_ENABLED}" = "yes" ]
            then
                skip_flag=0

                if [ "${EXISCAN_AV_SKIP_AUTHENTICATED}" = "yes" ]
                then
                    skip_flag=1
                fi

                if [ "${EXISCAN_SPAMD_SKIP_AUTHENTICATED}" = "yes" ]
                then
                    skip_flag=`expr ${skip_flag} + 2`
                fi

                if [ ${skip_flag} -gt 0 ]
                then
                    case ${skip_flag} in
                        1 )
                            exiscan_auth_msg="${exiscan_av_auth_msg}"
                            exiscan_auth_config_msg="${exiscan_av_auth_config_msg}"
                            ;;
                        2 )
                            exiscan_auth_msg="${exiscan_spamd_auth_msg}"
                            exiscan_auth_config_msg="${exiscan_spamd_auth_config_msg}"
                            ;;
                        3)
                            exiscan_auth_msg="${exiscan_av_spamd_auth_msg}"
                            exiscan_auth_config_msg="${exiscan_av_spamd_auth_config_msg}"
                            ;;
                    esac

                    echo "  # exiscan - malware and/or spam scan skipped"
                    echo "  warn    log_message   = ${exiscan_auth_msg}"
                    echo "         !condition     = \${if or{{eq{\$authenticated_id}{${FETCHMAIL_ESMTP_NAME}}}{={\$acl_m1}{0}}}{1}{0}}"
                    echo

                    write_to_config_log -info "${exiscan_auth_config_msg}"
                fi
            fi

            #- regexp -------------------------------------------------------------------

            if [ "${EXISCAN_REGEX_ENABLED}" = "yes" ]
            then
                echo "  # exiscan - regex"

                # action on virus: pass, reject, discard, freeze, redirect <address>
                echo ${EXISCAN_REGEX_ACTION} | grep -q '^redirect'

                if [ $? -eq 0 ]
                then
                    # redirect - get address
                    exiscan_action=`echo ${EXISCAN_REGEX_ACTION}|cut -d' ' -f1`
                    exiscan_addr=`echo ${EXISCAN_REGEX_ACTION}|cut -d' ' -f2`
                    exiscan_redirect=1
                else
                    exiscan_action=${EXISCAN_REGEX_ACTION}
                    exiscan_addr=''
                fi

                case ${exiscan_action} in
                    pass ) # let message pass
                        acl1=''
                        aclmsg='passed'
                        ;;
                    reject ) # reject message
                        acl1='deny   '
                        aclmsg='rejected'
                        ;;
                    discard ) # discard message
                        acl1='discard'
                        aclmsg='discarded'
                        ;;
                    freeze ) # freeze message
                        acl1='warn   '
                        aclmsg='froozen'
                        ;;
                    redirect ) # redirect message
                        acl1='warn   '
                        aclmsg="redirected to ${exiscan_addr}"
                        ;;
                esac

                echo "  warn    log_message = ${exiscan_regex_msg} - ${aclmsg}"
                echo "          regex       = ${EXISCAN_REGEX_DATA}"
                echo "          condition   = \${if ={\$acl_m0}{0}{1}{0}}"

                if [ "${acl1}" != "" ]
                then
                    echo

                    if [ "${exiscan_action}" = "redirect" ]
                    then
                        echo "  ${acl1} message     = X-Redirect-To: ${exiscan_addr}"
                    else
                        echo "  ${acl1} message     = ${exiscan_regex_msg}"
                    fi

                    echo "          regex       = ${EXISCAN_REGEX_DATA}"
                    echo "          condition   = \${if ={\$acl_m0}{0}{1}{0}}"
                fi

                case ${exiscan_action} in
                    freeze )
                        echo "          control     = freeze"
                        ;;
                    redirect )
                        echo "          set acl_m0  = 1"
                        ;;
                esac

                echo
            fi

            # new scan data has been added
            echo "  # exiscan - set done flag"
            echo "  warn    message     = X-New-Scan-Done: YES"
            echo

            # Add the cryptographic header.
            echo "  # exiscan - add cryptographic header"
            echo "  warn    message     = X-New-Scan-Signature: \${hmac{md5}{$EXISCAN_CRYPT_SALT}{\$body_linecount}}"
            echo

            # finally accept all the rest
            echo "  accept"
            echo
        fi

        echo
        echo '#==============================================================================='
        echo '# ROUTERS CONFIGURATION'
        echo '#==============================================================================='
        echo

        # Specifies how addresses are handled
        # THE ORDER IN WHICH THE ROUTERS ARE DEFINED IS IMPORTANT
        # An address is passed to each router in turn until it is accepted.

        echo 'begin routers'
        echo

        # This router redirects a message if it has been requested by an exiscan
        # acl rule.

        if [ $exiscan_redirect -eq 1 ]
        then
            echo "exiscan_redirect:"
            echo "  driver          = redirect"
            echo "  condition       = \${if def:h_X-Redirect-To: {1}{0}}"
            echo "  headers_add     = X-Original-Recipient: \$local_part@\$domain"
            echo "  data            = \$h_X-Redirect-To:"
            echo "  headers_remove  = X-Redirect-To"

            if [ $SMTP_SMARTHOST_N -gt 0 ]
            then
                echo "  redirect_router = smart_route"
            else
                echo "  redirect_router = dnslookup"
            fi

            echo
        fi

        # This router hands over an incoming mail to an eisfax server, when
        # the email address has been formated as followed.
        #
        # Example: faxg3/0211334455@domain.tld
        #          faxg3/fax-privat/0211334455@domain.tld

        if [ ${EISFAX_INSTALLED} -eq 1 ]
        then
            echo 'fax_route:'
            echo '  driver     = manualroute'
            echo '  local_part_prefix = faxg3/'
            echo "  route_list = ${SMTP_QUALIFY_DOMAIN}"
            echo "  senders    = *@+local_domains : lsearch*@;${eisfax_addresses}"
            echo '  transport  = fax_transport'
            echo
        fi

        # This router hands over an incoming mail to a printer, when the
        # email address has been formated as followed.
        #
        # Example: print/repr1@domain.tld

        if [ ${MAIL2PRINT_INSTALLED} -eq 1 ]
        then
            echo 'print_route:'
            echo '  driver     = manualroute'
            echo '  local_part_prefix = print/'
            echo "  route_list = ${SMTP_QUALIFY_DOMAIN}"
            echo "  senders    = *@+local_domains : lsearch*@;${mail2print_addresses}"
            echo '  transport  = print_transport'
            echo
        fi

        # This router routes to remote hosts over SMTP by explicit IP address,
        # when an email address is given in "domain literal" form, for example,
        # <user@[192.168.35.64]>. The RFCs require this facility. However, it is
        # little-known these days, and has been exploited by evil people seeking
        # to abuse SMTP relays. Consequently it is commented out in the default
        # configuration. If you uncomment this router, you also need to uncomment
        # allow_domain_literals above, so that Exim can recognize the syntax of
        # domain literal addresses.

        # domain_literal:
        #   driver = ipliteral
        #   transport = remote_smtp

        # This router routes all outgoing traffic via a ISP mail host.

        if [ ${SMTP_SMARTHOST_N} -gt 0 ]
        then
            echo 'smart_route:'
            echo '  driver     = manualroute'

            if [ "${SMTP_SMARTHOST_ONE_FOR_ALL}" = "yes" ]
            then
                if [ "${SMTP_SMARTHOST_DOMAINS}" != "" ]
                then
                    # use smarthost only for these domains
                    echo "  domains    = ! +local_domains : ${SMTP_SMARTHOST_DOMAINS}"
                else
                    echo "  domains    = ! +local_domains"
                fi

                if [ \( "${SMTP_SMARTHOST_1_HOST}" = "localhost" -o "${SMTP_SMARTHOST_1_HOST}" = "127.0.0.1" \) -a \
                        "${SMTP_SMARTHOST_1_PORT}" != "smtp" -a "${SMTP_SMARTHOST_1_PORT}" != "25" ]
                then
                    # to be able to send email via a stunnel connection which is
                    # listening on a different local port than 'smtp' and to stop
                    # running into an 'remote host address is the local host' error
                    # this parameter needs to be set.
                    write_to_config_log -warn "Loop check has been disabled because SMTP_SMARTHOST_1_HOST='localhost' has been set."
                    echo "  self       = send"
                fi

                echo '  transport  = remote_smtp'
                echo "  route_list = * ${SMTP_SMARTHOST_1_HOST}"
            else
                if [ "$SMTP_SMARTHOST_DOMAINS" != "" ]
                then
                    # use smarthost only for these domains
                    echo "  domains    = ! +local_domains : $SMTP_SMARTHOST_DOMAINS"
                else
                    echo "  domains    = ! +local_domains"
                fi

                case ${SMTP_SMARTHOST_ROUTE_TYPE} in
                    addr )
                        # lookup user
                        echo "  debug_print = sender_address=\$sender_address"
                        lookupstr="sender_address"
                        ;;
                    sdomain )
                        # lookup sender domain
                        echo "  debug_print = sender_address=\$sender_address sender_address_domain=\$sender_address_domain"
                        lookupstr="sender_address_domain"
                        ;;
                    tdomain|* )
                        # lookup target domain
                        echo "  debug_print = recipient_address_domain=\$domain"
                        lookupstr="domain"
                        ;;
                esac

                echo "  transport  = remote_\${extract{port} \\"
                echo "               {\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}{\$value}{smtp}}"

                echo "  route_list = * \${extract{server}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}"
            fi

            echo
        fi

        # This router routes addresses that are not in local domains by doing a DNS
        # lookup on the domain name. Any domain that resolves to a loopback interface
        # address (127.0.0.0/8) is treated as if it had no DNS entry. If the DNS
        # lookup fails, no further routers are tried because of the no_more setting,
        # and consequently the address is unrouteable.
        #
        # 16.09.2003 - The 'ignore_target_hosts' parameter has been modified to prevent
        # problems with name resolution because Verisign has set wildcard A records for
        # .com and .net domains

        echo 'dnslookup:'
        echo '  driver    = dnslookup'
        echo "  domains   = ! +local_domains"
        echo '  transport = remote_smtp'

        if [ "$SMTP_UPDATE_IGNORE_HOSTS" = "yes" -a "$SMTP_SMARTHOST_ONE_FOR_ALL" = "no" ]
        then
            # added because of wildcard DNS-A-records for some TLDs
            if [ ! -f $generate_ignorehosts ]
            then
                # create dummy file
                echo "# first time dummy file" > $generate_ignorehosts

                 # set access rights
                 chmod 0600 $generate_ignorehosts
                 chown exim $generate_ignorehosts
                 chgrp trusted $generate_ignorehosts
            fi

            echo "  ignore_target_hosts = 0.0.0.0 : 127.0.0.0/8 : net-lsearch;$generate_ignorehosts"
        else
            if [ -f $generate_ignorehosts ]
            then
                # remove obsolete file
                rm -f $generate_ignorehosts
            fi

            echo "  ignore_target_hosts = 0.0.0.0 : 127.0.0.0/8"
        fi

        echo '  no_more'

        # The remaining routers handle addresses in the local domain(s).

        # If more the one virtual domains has been defined in the aliases section
        # this router will be used

        if [ $SMTP_ALIASES_N -gt 1 ]
        then
            echo
            echo 'virtual_domains:'
            echo '  driver = redirect'
            echo '  allow_fail'
            echo '  allow_defer'
            echo "  require_files = $generate_aliases-\$domain"
            echo "  data = \${lookup{\$local_part}lsearch*{$generate_aliases-\$domain}}"   # enable joker function
            echo '  file_transport = address_file'
            echo '  pipe_transport = address_pipe'
        fi

        # This router handles aliasing using a traditional /etc/aliases file.
        #
        ##### NB  You must ensure that /etc/aliases exists. It used to be the case
        ##### NB  that every Unix had that file, because it was the Sendmail default.
        ##### NB  These days, there are systems that don't have it. Your aliases
        ##### NB  file should at least contain an alias for "postmaster".
        #
        # If any of your aliases expand to pipes or files, you will need to set
        # up a user and a group for these deliveries to run under. You can do
        # this by uncommenting the "user" option below (changing the user name
        # as appropriate) and adding a "group" option if necessary. Alternatively, you
        # can specify "user" on the transports that are used. Note that the transports
        # listed below are the same as are used for .forward files; you might want
        # to set up different ones for pipe and file deliveries from aliases.

        echo
        echo 'system_aliases:'
        echo '  driver = redirect'
        echo '  allow_fail'
        echo '  allow_defer'
        echo "  data = \${lookup{\$local_part}lsearch{$generate_aliases}}"
        echo '  file_transport = address_file'
        echo '  pipe_transport = address_pipe'

        # mailman

        if [ $MAILMAN_INSTALLED -eq 1 ]
        then
            echo
            echo 'mailman_router:'
            echo '  driver    = accept'
            echo '  domains   = +mailman_domains'
            echo '  transport = mailman_transport'
            echo "  require_files = $mailmanspool_path/lists/\${lc::\$domain}/config.pck"
            echo '  local_part_suffix_optional'
            echo '  local_part_suffix = -admin     : \'
            echo '                      -bounces   : -bounces+* : \'
            echo '                      -confirm   : -confirm+* : \'
            echo '                      -join      : -leave     : \'
            echo '                      -owner     : -request   : \'
            echo '                      -subscribe : -unsubscribe'
        fi

        # This router handles special mail addresses to be delivered directly into
        # imap shared folders. It is after system_aliases so that the aliases file
        # can group things to fewer folders here.

        if [ $IMAP_SHARED_FOLDER_N -gt 0 ]
        then
            echo
            echo 'shared_folders:'
            echo '  driver    = accept'
            echo "  senders   = *@+local_domains"
            echo '  transport = shared_folder_delivery'
            echo "  local_parts = \${extract{folder} \\"
            echo "                {\${lookup{\$local_part}lsearch{$generate_imapshared}}}{\$value}}"
        fi

        # This router handles special mail addresses to be delivered directly into
        # imap public folders. It is after system_aliases so that the aliases file
        # can group things to fewer folders here.

        if [ $IMAP_PUBLIC_FOLDER_N -gt 0 ]
        then
            echo
            echo 'public_folders:'
            echo '  driver    = accept'
            echo '# senders   = *@+local_domains'
            echo '  transport = public_folder_delivery'
            echo "  local_parts = \${extract{folder} \\"
            echo "                {\${lookup{\$local_part}lsearch{$generate_imappublic}}}{\$value}}"
        fi

        # This router handles forwarding using traditional .forward files in users'
        # home directories. If you want it also to allow mail filtering when a forward
        # file starts with the string "# Exim filter", uncomment the "allow_filter"
        # option.'

        # The no_verify setting means that this router is skipped when Exim is
        # verifying addresses. Similarly, no_expn means that this router is skipped if
        # Exim is processing an EXPN command.

        # The check_ancestor option means that if the forward file generates an
        # address that is an ancestor of the current one, the current one gets
        # passed on instead. This covers the case where A is aliased to B and B
        # has a .forward file pointing to A.

        # The three transports specified at the end are those that are used when
        # forwarding generates a direct delivery to a file, or to a pipe, or sets
        # up an auto-reply, respectively.

        echo
        echo 'userforward:'
        echo '  driver = redirect'
        echo '  check_local_user'
        echo '  file = $home/.forward'
        echo '  no_verify'
        echo '  no_expn'
        echo '  check_ancestor'

        # added for sn package support

        if [ $SN_INSTALLED -eq 1 -o "$SMTP_ALLOW_EXIM_FILTERS" = "yes" ]
        then
            echo '  allow_filter = true'
        else
            echo '# allow_filter'
        fi

        echo '  file_transport  = address_file'
        echo '  pipe_transport  = address_pipe'
        echo '  reply_transport = address_reply'

        # This router matches local user mailboxes.

        if [ "$SMTP_REMOVE_RECEIPT_REQUEST" = "yes" ]
        then
            echo
            echo 'localuser_filtered:'
            echo '  driver  = accept'
            echo "  senders = ! *@+local_domains"
            echo '  check_local_user'
            echo '  transport = local_delivery_filtered'
        fi

        echo
        echo 'localuser:'
        echo '  driver = accept'
        echo '  check_local_user'
        echo '  transport = local_delivery'

        # Mailinglists

        if [ $SMTP_LIST_N -gt 0 ]
        then
            echo
            echo 'lists:'
            echo '  driver  = redirect'
            echo "  domains = $SMTP_LIST_DOMAIN"
          # echo '  senders = *@+local_domains'               # allow only local senders
          # echo '  no_more'
            echo '  file    = '"$mailinglists_path"'/${local_part}'
            echo '  no_check_local_user'
            echo '  forbid_pipe'
            echo '  forbid_file'
            echo '  skip_syntax_errors'
            echo '  errors_to = ${local_part}-request@'"$SMTP_LIST_DOMAIN"
            echo '  syntax_errors_to = ${local_part}-request@'"$SMTP_LIST_DOMAIN"
            echo '  headers_remove   = Reply-To:: .*'
            echo '  headers_add      = "Reply-To: ${local_part}@'"$SMTP_LIST_DOMAIN"'\n\'
            echo '                     Precedence: bulk"'
        fi

        # bounce or bounce/copy router

        case "$SMTP_MAIL_TO_UNKNOWN_USERS"
        in
            copy)
                # bounce and copy to the postmaster
                echo
                echo 'unknown_user:'
                echo '  driver    = accept'
                echo '  transport = unknown_user_reply'
                ;;
            forward)
                # forward to the postmaster
                echo
                echo 'unknown_user:'
                echo '  driver = redirect'
                echo '  data   = postmaster'
                ;;
        esac

        echo
        echo '#==============================================================================='
        echo '# TRANSPORTS CONFIGURATION'
        echo '#==============================================================================='
        echo

        # ORDER DOES NOT MATTER
        # Only one appropriate transport is called for each delivery.
        #
        # A transport is used only when referenced from a router that successfully
        # handles an address.

        echo 'begin transports'

        # This transport is used for delivering messages over SMTP connections.

        # driver = smtp                     - creates a smtp transport driver instance
        # hosts_require_auth = <smtp hosts> - list of hosts for which authentication is required,
        #                                     if it fails Exim tries an unauthenticated connection
        # hosts_try_auth = <smtp hosts>     - list of hosts which Exim tries to build up an
        #                                     authenticated connection, if they privide this feature
        #                                     if it fails Exim tries an unauthenticated connection
        # hosts_require_tls                 - will insist on using a TLS session when delivering to
        #                                     any host that matches this list
        # tls_verify_certificates           - absolute path to a file or a directory containing permitted
        #                                     server certificates
        # headers_remove = message-id       - an own message-ID will be deleted and deligated to the
        #                                     IDPs smtp server
        # max_rcpt = 1                      - limits the number of RCPT commands that are sent in a single
        #                                     SMTP message transaction
        # return_path = ...                 - modifies the return path in the email header of an outgoing
        #                                     mail. the information is take form a file
        # transport_filter = ...            - runs a transport filter before the message is being
        #                                     delivered. In this case a perl script is used to modify
        #                                     outgoing email addresses

        # get list of smtp ports
        sh_portlist="smtp"
        idx=1
        if [ $SMTP_SMARTHOST_N -gt 0 ]
        then
            while  [ $idx -le $SMTP_SMARTHOST_N ]
            do
                eval sh_port='$SMTP_SMARTHOST_'$idx'_PORT'

                # check if empty
                if [ "$sh_port" != "" ]
                then
                    # check if port has already been added to sh_portlist
                    if [ "${sh_port}" = "uucp" -a ${UUCP_INSTALLED} -eq 0 ]
                    then
                        # uucp package has not been installed or activated
                        write_to_config_log -error "You've set SMTP_SMARTHOST_${idx}_PORT='uucp' although no uucp package"
                        write_to_config_log -error -ff "has been installed or activated! Please check the configuration!"
                    else
                        # normal procedure
                        echo $sh_portlist | grep -q $sh_port

                        if [ $? -ne 0 ]
                        then
                            # port not found and not 'smtp' port!
                            if [ "$sh_port" != "smtp" -a "$sh_port" != "25" ]
                            then
                                # add port to sh_portlist
                                sh_portlist="$sh_portlist $sh_port"
                            fi
                        fi
                    fi    # if [ "${sh_port}" = "uucp" -a ${UUCP_INSTALLED} -eq 0 ]
                fi

                idx=`expr $idx + 1`
            done
        fi

        for PNAME in $sh_portlist
        do
            echo
            echo "remote_${PNAME}:"

            if [ "${PNAME}" = "uucp" ]
            then
                # port 'uucp' has been chosen
                echo '  driver = pipe'
            else
                # default value
                echo '  driver = smtp'
            fi

            if [ ${SMTP_SMARTHOST_N} -gt 0 ]
            then
                if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
                then
                    # one smarthost should be used for all outbound traffic
                    sh_nbr=1
                else
                    # user specific smarthosts should be used
                    sh_nbr="$SMTP_SMARTHOST_N"
                fi

                # set different outgoing smtp port
                if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
                then
                    if [ "$SMTP_SMARTHOST_1_PORT" != "" -a "$SMTP_SMARTHOST_1_PORT" != "smtp" ]
                    then
                        echo "  port = $SMTP_SMARTHOST_1_PORT"
                    fi
                else
                    # set individual port
                    if [ "${PNAME}" != "uucp" ]
                    then
                        # default
                        echo "  port = ${PNAME}"
                    fi
                fi

                idx=1
                sh_require_auth=""
                sh_try_auth=""
                sh_require_tls=""
                sh_ignore_tls=""

                while [ $idx -le $sh_nbr ]
                do
                    eval sh_auth='$SMTP_SMARTHOST_'$idx'_AUTH_TYPE'
                    eval sh_forceauth='$SMTP_SMARTHOST_'$idx'_FORCE_AUTH'
                    eval sh_forcetls='$SMTP_SMARTHOST_'$idx'_FORCE_TLS'
                    eval sh_hostname='$SMTP_SMARTHOST_'$idx'_HOST'

                    if [ "$sh_auth" != "none" ]
                    then
                        if [ "$sh_forceauth" = "yes" ]
                        then
                            # check all hosts given in 'sh_hostname' - multiple names are possible
                            # e.g. if a backup smarthost is given
                            OLDIFS=$IFS
                            IFS=:
                            for HNAME in $sh_hostname
                            do
                                # check if hostname has already been added to sh_try_auth
                                echo $sh_try_auth | grep -q $sh_hostname

                                if [ $? -ne 0 ]
                                then
                                    # hostname not found - check if hostname has already been added to sh_require_auth
                                    echo $sh_require_auth | grep -q $sh_hostname

                                    if [ $? -ne 0 ]
                                    then
                                        # hostname not found - add hostname to sh_require_auth
                                        if [ "$sh_require_auth" = "" ]
                                        then
                                            sh_require_auth="$sh_hostname"
                                        else
                                            sh_require_auth="$sh_require_auth : $sh_hostname"
                                        fi
                                    fi
                                fi
                            done

                            IFS=$OLDIFS
                        else
                            # check if hostname has already been added to sh_require_auth
                            echo $sh_require_auth | grep -q $sh_hostname

                            if [ $? -ne 0 ]
                            then
                                # hostname not found - check if hostname has already been added to sh_try_auth
                                echo $sh_try_auth | grep -q $sh_hostname

                                if [ $? -ne 0 ]
                                then
                                # hostname not found - add hostname to sh_try_auth
                                    if [ "$sh_try_auth" = "" ]
                                    then
                                        sh_try_auth="$sh_hostname"
                                    else
                                        sh_try_auth="$sh_try_auth : $sh_hostname"
                                    fi
                                fi
                            fi
                        fi    # if [ "$sh_forceauth" = "yes" ]
                    fi    # if [ "$sh_auth" != "none" ]

                    if [ "$sh_forcetls" = "yes" ]
                    then
                        # check if hostname has already been added to sh_require_tls
                        echo $sh_require_tls | grep -q $sh_hostname

                        if [ $? -ne 0 ]
                        then
                            # hostname not found - add hostname to sh_require_tls
                            if [ "$sh_require_tls" = "" ]
                            then
                                sh_require_tls="$sh_hostname"
                            else
                                sh_require_tls="$sh_require_tls : $sh_hostname"
                            fi
                        fi
                    elif [ "$sh_forcetls" = "ignore" ]
                    then
                        # check if hostname has already been added to sh_ignore_tls
                        echo $sh_ignore_tls | grep -q $sh_hostname

                        if [ $? -ne 0 ]
                        then
                            # hostname not found - add hostname to sh_require_tls
                            if [ "$sh_ignore_tls" = "" ]
                            then
                                sh_ignore_tls="$sh_hostname"
                            else
                                sh_ignore_tls="$sh_ignore_tls : $sh_hostname"
                            fi
                        fi
                    fi

                    idx=`expr $idx + 1`
                done    # while [ "$idx" -le "$sh_nbr" ]

                if [ "${PNAME}" != "uucp" ]
                then
                    # add parameter if not empty
                    if [ "$sh_require_auth" != "" ]
                    then
                        echo "  hosts_require_auth = $sh_require_auth"
                    fi

                    # add parameter if not empty
                    if [ "$sh_try_auth" != "" ]
                    then
                        echo "  hosts_try_auth = $sh_try_auth"
                    fi

                    # enable TLS/SSL client support
                    # add parameter if not empty
                    if [ "$sh_require_tls" != "" ]
                    then
                        # create cert directory
                        if [ ! -d $sslcert_path ]
                        then
                            mkdir -p $sslcert_path > /dev/null
                        fi

                        # The value of this option is expanded, and must then be the absolute path
                        # to a file which contains the server's certificates. The server's private
                        # key is also assumed to be in this file if "tls_privatekey" is unset.

                        echo '  # enable TLS/SSL client support'
                        echo "  tls_certificate   = ${sslcert_path}/exim.pem"

                        # The value of this option is expanded, and must then be the absolute path
                        # to a file which contains the server's private key. If this option is
                        # unset, the private key is assumed to be in the same file as the server's
                        # certificates.

                        echo "  tls_privatekey    = ${sslcert_path}/exim.pem"

                        echo "  hosts_require_tls = ${sh_require_tls}"
                        echo "  tls_crl           = ${sslcrl_path}"
                        echo "  tls_verify_certificates = ${sslcert_path}"
                    fi

                    # add parameter if not empty
                    if [ "$sh_ignore_tls" != "" ]
                    then
                        # Ignore STARTTLS capability of the remote server although it has been advertised
                        # This may be necessary if the remote server advertises STARTTLS and then returns
                        # e.g. a '454 TLS not available due to temporary reason' error.

                        echo "  hosts_avoid_tls = $sh_ignore_tls"
                    fi

                    # outgoing address translation
                    if [ ${SMTP_SMARTHOST_N} -gt 0 -a ${SMTP_OUTGOING_ADDRESSES_N} -gt 0 ]
                    then
                        # modify outgoing address(es) and optionally add a disclaimer
                        echo '  max_rcpt = 1'
# JED/12.05.2008 - vvv - experimental
                      # echo '  headers_remove = message-id'
                        echo "  headers_remove = \${if match_domain{\${domain::\$h_Message-ID::}}{+local_domains} \\"
                        echo "                    {}{message-id}}"
# JED/12.05.2008 - ^^^ - experimental
                        echo "  return_path    = \"\${if match {\$return_path}{\^(.+?)\@${SMTP_QUALIFY_DOMAIN}} \\ "
                        echo "                    {\${lookup{\${lc:\$1}}lsearch{${generate_addresses}}{\$value}fail}}fail}\""
                        echo "  size_addition    = -1"
                        # e.g. SMTP_QUALIFY_DOMAIN=vmware.lan lookup result: my-official-domain.de
                        echo "  transport_filter = ${eximmain_path}/exim_transport_filter.sh both \\ "
                        echo "                     \"${SMTP_QUALIFY_DOMAIN}\" \\ "
                        echo "                     \"\${domain:\${lookup{\${lc:\$sender_address_local_part}}lsearch{${generate_addresses}}{\$value}}}\""
                    else
                        # optionally add a disclaimer
                        echo "  size_addition    = -1"
                        # e.g. SMTP_QUALIFY_DOMAIN=vmware.lan lookup result: my-official-domain.de
                        echo "  transport_filter = ${eximmain_path}/exim_transport_filter.sh disclaimer \\ "
                        echo "                     \"${SMTP_QUALIFY_DOMAIN}\" \\ "
                        echo "                     \"\${domain:\${lookup{\${lc:\$sender_address_local_part}}lsearch{${generate_addresses}}{\$value}}}\""
                    fi
                else
                    # uucp specific parameters
                    echo "  user = uucp"
                    # example: /usr/sbin/uucp-send uucp-host uucp-compression (bzip, gzip, compress, none)
                    echo "  command = /usr/sbin/uucp-send \\"
                    echo "            \${extract{host}{\${lookup{\${lc:\$host}}lsearch{$uucp_compression}}}{\$value}fail} \\"
                    echo "            \${extract{compression}{\${lookup{\${lc:\$host}}lsearch{$uucp_compression}}}{\$value}{none}} \\"
                    echo "            \${pipe_addresses}"
                    echo "  log_fail_output = true"
                    echo "  batch_max = 25"
                    echo "  timeout   = 10m"
                fi     # if [ "${PNAME}" != "uucp" ]
            else
                # $SMTP_SMARTHOST_N -eq 0 - don't use any smarthost
                if [ -d ${eximspool_path}/disclaimer ]
                then
                    # disclaimer directory exists, check for disclaimer files
                    ls ${eximspool_path}/disclaimer/*-disclaimer.txt >/dev/null 2>/dev/null

                    if [ $? -eq 0 ]
                    then
                        # disclaimer files exist - optionally add a disclaimer
                        echo "  size_addition    = -1"
                        # e.g. SMTP_QUALIFY_DOMAIN=vmware.lan lookup result: my-official-domain.de
                        echo "  transport_filter = ${eximmain_path}/exim_transport_filter.sh disclaimer \\ "
                        echo "                     \"${SMTP_QUALIFY_DOMAIN}\" \"\""
                    fi
                fi
            fi     # if [ $SMTP_SMARTHOST_N -gt 0 ]
        done    # for PLIST in $sh_portlist

        # eisfax

        if [ ${EISFAX_INSTALLED} -eq 1 ]
        then
            echo
            echo 'fax_transport:'
            echo '  driver  = pipe'
            echo '  command = /usr/local/bin/mail2fax -sender "$sender_address" -receiver "$local_part" -subject "$h_subject:"'
            echo '  home_directory = /tmp'
            echo '  user    = fax'
        fi

        # mail2print

        if [ ${MAIL2PRINT_INSTALLED} -eq 1 ]
        then
            echo
            echo 'print_transport:'
            echo '  driver  = pipe'
            echo '  command = /usr/local/bin/mail2print -sender "$sender_address" -queue "$local_part"'
            echo '  home_directory = /tmp'
            echo '  user    = exim'
        fi

        # mailman

        if [ $MAILMAN_INSTALLED -eq 1 ]
        then
            echo
            echo 'mailman_transport:'
            echo '  driver  = pipe'
            echo "  command = $mailmanmain_path/mail/mailman \\"
            echo '            ${if def:local_part_suffix \'
            echo '            {${sg{$local_part_suffix}{-(\\w+)(\\+.*)?}{\$1}}} \'
            echo '            {post}} $local_part'
            echo "  current_directory = $mailmanspool_path"
            echo "  home_directory    = $mailmanspool_path"
            echo '  user  = mailman'
            echo '  group = mailman'
        fi

        # This transport saves messages in imap shared folders for special mail
        # addresses defined in the 'shared_folders' router - to allow workgroup
        # style mail handling with IMAP server (and clients which support shared folders)

        if [ $IMAP_SHARED_FOLDER_N -gt 0 ]
        then
            echo
            echo 'shared_folder_delivery:'
            echo '  driver = appendfile'
            echo "  file   = /home/imapshared/\${extract{path} \\"
            echo "           {\${lookup{\$local_part}lsearch{$generate_imapshared}}}{\$value}}\${extract{folder} \\"
            echo "           {\${lookup{\$local_part}lsearch{$generate_imapshared}}}{\$value}}"

            if [ "$POP3IMAP_CREATE_MBX" = "yes" ]
            then
                # use mbx format
                echo '  mbx_format    = true'
            else
                # use unix format
                echo '  mbx_format    = false'
            fi

            echo '  check_string  = ""'
            echo '  escape_string = ""'
            echo '  delivery_date_add'
            echo '  envelope_to_add'
            echo '  return_path_add'
            echo '  user  = imapshared'
            echo "  group = \${extract{group} \\"
            echo "          {\${lookup{\$local_part}lsearch{$generate_imapshared}}}{\$value}}"
            echo '  mode  = 0660'
        fi

        # This transport saves messages in imap public folders for special mail
        # addresses defined in the 'public_folders' router - to allow workgroup
        # style mail handling with IMAP server (and clients which support shared folders)

        if [ $IMAP_PUBLIC_FOLDER_N -gt 0 ]
        then
            echo
            echo 'public_folder_delivery:'
            echo '  driver = appendfile'
            echo "  file   = /home/imappublic/\${extract{path} \\"
            echo "           {\${lookup{\$local_part}lsearch{$generate_imappublic}}}{\$value}}\${extract{folder} \\"
            echo "           {\${lookup{\$local_part}lsearch{$generate_imappublic}}}{\$value}}"

            if [ "$POP3IMAP_CREATE_MBX" = "yes" ]
            then
                # use mbx format
                echo '  mbx_format    = true'
            else
                # use unix format
                echo '  mbx_format    = false'
            fi

            echo '  check_string  = ""'
            echo '  escape_string = ""'
            echo '  delivery_date_add'
            echo '  envelope_to_add'
            echo '  return_path_add'
            echo '  user  = imappublic'
            echo "  group = \${extract{group} \\"
            echo "          {\${lookup{\$local_part}lsearch{$generate_imappublic}}}{\$value}}"

            echo '  mode  = 0666'
        fi

        # This transport is used for local delivery to user mailboxes in traditional
        # BSD mailbox format. By default it will be run under the uid and gid of the
        # local user, and requires the sticky bit to be set on the /var/spool/mail directory.
        # Some systems use the alternative approach of running mail deliveries under a
        # particular group instead of using the sticky bit. The commented options below
        # show how this can be done.

        if [ "$SMTP_REMOVE_RECEIPT_REQUEST" = "yes" ]
        then
            echo
            echo 'local_delivery_filtered:'
            echo '  driver = appendfile'
            echo "  transport_filter = $eximmain_path/delete_rreq.pl"
            echo "  file = $mailspool_path/\$local_part"
            echo '  delivery_date_add'
            echo '  envelope_to_add'
            echo '  return_path_add'

            # add mail quota information
            if [ $MAILQUOTA_INSTALLED -eq 1 ]
            then
                $mailquota_configfile processquota
            fi
        fi

        echo
        echo 'local_delivery:'
        echo '  driver = appendfile'
        echo "  file = $mailspool_path/\$local_part"
        echo '  delivery_date_add'
        echo '  envelope_to_add'
        echo '  return_path_add'

        # add mail quota information
        if [ $MAILQUOTA_INSTALLED -eq 1 ]
        then
            $mailquota_configfile processquota
        fi

        # This transport is used for handling pipe deliveries generated by alias or
        # .forward files. If the pipe generates any standard output, it is returned
        # to the sender of the message as a delivery error. Set return_fail_output
        # instead of return_output if you want this to happen only when the pipe fails
        # to complete normally. You can set different transports for aliases and
        # forwards if you want to - see the references to address_pipe in the routers
        # section above.

        echo
        echo 'address_pipe:'
        echo '  driver = pipe'
        echo '  return_output'

        # This transport is used for handling deliveries directly to files that are
        # generated by aliasing or forwarding.

        echo
        echo 'address_file:'
        echo '  driver = appendfile'

        if [ "$POP3IMAP_CREATE_MBX" = "yes" ]
        then
            # use mbx format
            echo '  mbx_format = true'
        else
            # use unix format
            echo '  mbx_format = false'
        fi

        echo '  delivery_date_add'
        echo '  envelope_to_add'
        echo '  return_path_add'

        # This transport is used for handling autoreplies generated by the filtering
        # option of the userforward router.

        echo
        echo 'address_reply:'
        echo '  driver = autoreply'

        # This transport is used to bounce an copy mail to unkonwn users

        if [ "$SMTP_MAIL_TO_UNKNOWN_USERS" = "copy" ]
        then
            # JED-Bounce with copy send to postmaster
            echo
            echo 'unknown_user_reply:'
            echo '  driver = autoreply'
            echo "  to = \$sender_address"
            echo '  bcc = postmaster'
            echo "  from = \"\\\"Mail Delivery System\\\" <Mailer-Daemon>\""
            echo "  subject = \"Mail delivery failed\""
            echo "  headers = \"X-Failed-Recipients: \$local_part@\$domain\n\""
            echo "  text = \"This message was created automatically by mail delivery software (Exim).\n\nA message that you sent could not be delivered to all of its recipients.\nThe following address(es) failed:\n\n\$local_part@\$domain\""
            echo '  return_message'
        fi

        echo
        echo '#==============================================================================='
        echo '# RETRY CONFIGURATION'
        echo '#==============================================================================='
        echo

        echo 'begin retry'

        # This single retry rule applies to all domains and all errors. It specifies
        # retries every 15 minutes for 2 hours, then increasing retry intervals,
        # starting at 1 hour and increasing each time by a factor of 1.5, up to 16
        # hours, then retries every 6 hours until 4 days have passed since the first
        # failed delivery.

        # Domain               Error       Retries
        # ------               -----       -------

        # add mail quota retry information
        if [ $MAILQUOTA_INSTALLED -eq 1 ]
        then
            $mailquota_configfile processretry
        fi

        echo '  *                *           F,2h,15m; G,16h,1h,1.5; F,4d,6h'

        echo
        echo '#==============================================================================='
        echo '# REWRITE CONFIGURATION'
        echo '#==============================================================================='
        echo

        # There are no rewriting specifications in this default configuration file.

        echo 'begin rewrite'

        idx=1
        while [ $idx -le $SMTP_HEADER_REWRITE_N ]
        do
            eval header_source='$SMTP_HEADER_REWRITE_'$idx'_SOURCE'
            eval header_destination='$SMTP_HEADER_REWRITE_'$idx'_DESTINATION'
            eval header_flags='$SMTP_HEADER_REWRITE_'$idx'_FLAGS'

            echo "  $header_source $header_destination $header_flags"

            idx=`expr $idx + 1`
        done

        echo
        echo '#==============================================================================='
        echo '# AUTHENTICATION CONFIGURATION'
        echo '#==============================================================================='
        echo

        # There are no authenticator specifications in this default configuration file.

        echo 'begin authenticators'
        echo
        echo '# server side authentication'
        echo

        case "${SMTP_AUTH_TYPE}"
        in
            user*)
                echo 'plain_pam:'
                echo '  driver = plaintext'
                echo '  public_name = PLAIN'
                echo '  server_prompts = :'            # Exim Q0723: enable pine support for plain authentication

                # advertise plain/login authentication only on TLS secured connections
                echo '  server_advertise_condition = ${if def:tls_in_cipher }'
              # echo "  server_advertise_condition = \${if or{{match_ip{\$sender_host_address}{iplsearch;$generate_relayfromhosts}}\
              #                                               {!eq{\$tls_cipher}{}}}{1}{0}}"

                if [ "${MAIL_USER_USE_MAILONLY_PASSWORDS}" = "yes" ]
                then
                    # use seperate mail passwords
                    echo '  server_condition = "\'
                    echo '    # $auth2 = username | $auth3 = password'
                    echo "    \${if and{ {!eq{\$auth2}{}} {!eq{\$auth3}{}} {eq{\$auth3}{\${lookup{\$auth2}lsearch{${generate_pop3imappwd}}}}} }{yes}{no}}\""
                else
                    # use system passwords
                    echo '  # $auth2 = username | $auth3 = password - root not allowed'
                    echo '  server_condition = ${if eq{$auth2}{root}{0}{${if pam{$auth2:$auth3}{1}{0}}}}'
                fi

                echo '  server_set_id = $auth2'
                echo

                echo 'login_pam:'
                echo '  driver = plaintext'
                echo '  public_name = LOGIN'
                echo '  server_prompts = "Username:: : Password::"'

                # advertise plain/login authentication only on TLS secured connections
                echo '  server_advertise_condition = ${if def:tls_in_cipher }'
              # echo "  server_advertise_condition = \${if or{{match_ip{\$sender_host_address}{iplsearch;$generate_relayfromhosts}}\
              #                                               {!eq{\$tls_cipher}{}}}{1}{0}}"

                if [ "${MAIL_USER_USE_MAILONLY_PASSWORDS}" = "yes" ]
                then
                    # use seperate mail passwords
                    echo '  server_condition = "\'
                    echo '    # $auth1 = username | $auth2 = password'
                    echo "    \${if and{ {!eq{\$auth1}{}} {!eq{\$auth2}{}} {eq{\$auth2}{\${lookup{\$auth1}lsearch{${generate_pop3imappwd}}}}} }{yes}{no}}\""
                else
                    # use system passwords
                    echo '  # $auth2 = username | $auth3 = password - root not allowed'
                    echo '  server_condition = ${if eq{$auth1}{root}{0}{${if pam{$auth1:$auth2}{1}{0}}}}'
                fi

                echo '  server_set_id = $auth1'
                echo

                if [ "${MAIL_USER_USE_MAILONLY_PASSWORDS}" = "yes" ]
                then
                    # use seperate mail passwords
                    echo 'fixed_cram:'
                    echo '  driver = cram_md5'
                    echo '  public_name = CRAM-MD5'
                    echo '  server_secret = "\'
                    echo '    # $auth1 = username'
                    echo "    \${if !eq{\$auth1}{}{\${lookup{\$auth1}lsearch{${generate_pop3imappwd}}{\$value}fail}}fail}\""
                    echo '  server_set_id = $auth1'
                    echo
                else
                    # use system passwords
                    # CRAM-MD5 cannot be used when you want to compare the password with the
                    # encrypted copy in /etc/shadow because the client doesn't send the secret
                    # - it sends an MD5 hash of the challenge string plus the secret.
                    # It can only be used if the password has been safed as clear text password
                    # on the server. See MAIL_USER_USE_MAILONLY_PASSWORDS='yes' condition!
                    # JED / 17.03.2003
                    echo '# CRAM-MD5 cannot be used to check password against /etc/shadow'
                    echo '# MAIL_USER_USE_MAILONLY_PASSWORDS='no' has been set'
                    echo
                fi
                ;;

            server*)
                # verify username and password
                if [ "${SMTP_AUTH_USER}" = "" ]
                then
                    write_to_config_log -error "You've set SMTP_AUTH_TYPE='server' or 'server_light' but"
                    write_to_config_log -error -ff "haven't set SMTP_AUTH_USER!"
                fi

                if [ "${SMTP_AUTH_PASS}" = "" ]
                then
                    write_to_config_log -error "You've set SMTP_AUTH_TYPE='server'  or 'server_light' but"
                    write_to_config_log -error -ff "haven't set SMTP_AUTH_PASS!"
                fi

                echo 'fixed_plain:'
                echo '  driver = plaintext'
                echo '  public_name = PLAIN'
                echo '  server_condition = "\'
                echo '  # $auth2 = Username | $auth3 = password'
                echo '  ${if and {{eq{$auth2}{'"${SMTP_AUTH_USER}"'}}{eq{$auth3}{'"${SMTP_AUTH_PASS}"'}}}{yes}{no}}"'
                echo '  server_set_id = $auth2'
                echo
                echo 'login_plain:'
                echo '  driver = plaintext'
                echo '  public_name = LOGIN'
                echo '  server_prompts = "Username:: : Password::"'
                echo '        server_condition = "\'
                echo '        # $auth1 = Username | $auth2 = password'
                echo '        ${if and {{eq{$auth1}{'"${SMTP_AUTH_USER}"'}}{eq{$auth2}{'"${SMTP_AUTH_PASS}"'}}}{yes}{no}}"'
                echo '  server_set_id = $auth1'
                echo
                echo 'fixed_cram:'
                echo '  driver = cram_md5'
                echo '  public_name = CRAM-MD5'
                echo '  server_secret = "${if eq{$auth1}{'"${SMTP_AUTH_USER}"'}{'"${SMTP_AUTH_PASS}"'}fail}"'
                echo '  server_set_id = $auth1'
                echo
                ;;

            *)
                # 'none' currently disabled / not used
                echo '# - currently disabled / not used'
                echo
                ;;
        esac

        if [ $SMTP_SMARTHOST_N -gt 0 ]
        then
            echo '# client side authentication'
            echo

            # spa client authentication
            echo 'spa:'
            echo '  driver = spa'
            echo '  public_name = MSN'

            if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
            then
                echo '  client_username = "msn/'"${SMTP_SMARTHOST_1_USER}"'"'
                echo '  client_password = "'"${SMTP_SMARTHOST_1_PASS}"'"'
            else
                case $SMTP_SMARTHOST_ROUTE_TYPE
                in
                    addr )
                        # lookup user
                        lookupstr="sender_address"
                        ;;
                    sdomain )
                        # lookup sender domain
                        lookupstr="sender_address_domain"
                        ;;
                    tdomain|* )
                        # lookup target domain
                        lookupstr="domain"
                        ;;
                esac

                echo "  client_username = \"msn/\${extract{user}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
                echo "  client_password = \"\${extract{pass}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
            fi

            echo '  client_domain ='

            echo

            # cram-md5 client authentication
            echo 'cram_md5:'
            echo '  driver = cram_md5'
            echo '  public_name = CRAM-MD5'

            if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
            then
                echo '  client_name = "'"${SMTP_SMARTHOST_1_USER}"'"'
                echo '  client_secret = "'"${SMTP_SMARTHOST_1_PASS}"'"'
            else
                case $SMTP_SMARTHOST_ROUTE_TYPE
                in
                    addr )
                        # lookup user
                        lookupstr="sender_address"
                        ;;
                    sdomain )
                        # lookup sender domain
                        lookupstr="sender_address_domain"
                        ;;
                    tdomain|* )
                        # lookup target domain
                        lookupstr="domain"
                        ;;
                esac

                echo "  client_name   = \"\${extract{user}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
                echo "  client_secret = \"\${extract{pass}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
            fi

            echo

            # login client authentication
            echo 'login:'
            echo '  driver = plaintext'
            echo '  public_name = LOGIN'

            if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
            then
                echo '  client_send = ": '"${SMTP_SMARTHOST_1_USER}"' : '"${SMTP_SMARTHOST_1_PASS}"'"'
            else
                case $SMTP_SMARTHOST_ROUTE_TYPE
                in
                    addr )
                        # lookup user
                        lookupstr="sender_address"
                        ;;
                    sdomain )
                        # lookup sender domain
                        lookupstr="sender_address_domain"
                        ;;
                    tdomain|* )
                        # lookup target domain
                        lookupstr="domain"
                        ;;
                esac

                echo "  client_send = \": \${extract{user}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}} : \${extract{pass}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
            fi

            echo

            # plain text client authentication
            echo 'plain:'
            echo '  driver = plaintext'
            echo '  public_name = PLAIN'

            if [ "$SMTP_SMARTHOST_ONE_FOR_ALL" = "yes" ]
            then
                echo '  client_send = "^'"${SMTP_SMARTHOST_1_USER}"'^'"${SMTP_SMARTHOST_1_PASS}"'"'
            else
                case $SMTP_SMARTHOST_ROUTE_TYPE
                in
                    addr )
                        # lookup user
                        lookupstr="sender_address"
                        ;;
                    sdomain )
                        # lookup sender domain
                        lookupstr="sender_address_domain"
                        ;;
                    tdomain|* )
                        # lookup target domain
                        lookupstr="domain"
                        ;;
                esac

                echo "  client_send = \"^\${extract{user}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}^\${extract{pass}{\${lookup{\$$lookupstr}lsearch*{$generate_smarthosts}}}}\""
            fi

            echo
        fi

        echo '#==============================================================================='
        echo '# END'
        echo '#==============================================================================='

    } > ${generate_eximconf}

    # readable for all to allow e.g. archimap to run properly
    chmod 0644 ${generate_eximconf}
    chown root ${generate_eximconf}
    chgrp trusted ${generate_eximconf}
}

#----------------------------------------------------------------------------------------
# modify aliases file
#----------------------------------------------------------------------------------------
create_aliases ()
{
    mecho "creating aliases file ..."

    # added for sn package support
    if [ ${SN_INSTALLED} -eq 1 ]
    then
        pattern="^news:"
    else
        pattern=""
    fi

    # added for antispam package support
    if [ ${ANTISPAM_INSTALLED} -eq 1 ]
    then
        if [ "${pattern}" = "" ]
        then
            pattern="^spam:"
        else
            pattern="${pattern}|^spam:"
        fi
    fi

    # delete old domain specific aliases files
    rm -f ${generate_aliases}-*

    # check if number of entries has been set correctly
    if [ ${SMTP_ALIASES_N} -le 1 ]
    then
        aliases_nbr=1
    else
        aliases_nbr=${SMTP_ALIASES_N}
    fi

    idx=1
    while [ ${idx} -le ${aliases_nbr} ]
    do
        if [ ${idx} -gt 1 ]
        then
            # add to domain specific aliases file
            eval aliases_domain='$SMTP_ALIASES_'${idx}'_DOMAIN'
            eval aliases_entry_nbr='$SMTP_ALIASES_'${idx}'_ALIAS_N'

            {
                #----------------------------------------------------------------------------------------
                print_short_header "${generate_aliases}-${aliases_domain}" "${pgmname}" "mail" "${mail_version}"
                #----------------------------------------------------------------------------------------

                idy=1
                while [ ${idy} -le ${aliases_entry_nbr} ]
                do
                    eval aliases_entry='$SMTP_ALIASES_'${idx}'_ALIAS_'${idy}
                    echo "${aliases_entry}"

                    idy=`expr ${idy} + 1`
                done
            } > ${generate_aliases}-${aliases_domain}
        else
            # add to default domain aliases file
            {
                #----------------------------------------------------------------------------------------
                print_short_header "${generate_aliases}" "${pgmname}" "mail" "${mail_version}"
                #----------------------------------------------------------------------------------------

                # use alias template file as base and exclude pattern entries
                if [ "${pattern}" = "" ]
                then
                    cat -s ${generate_aliases}.std
                else
                    egrep -v "${pattern}" ${generate_aliases}.std
                fi

                echo
                echo "# added aliases for default mail domain"
                echo "FETCHMAIL-DAEMON:postmaster"

                idy=1
                while [ ${idy} -le ${SMTP_ALIASES_1_ALIAS_N} ]
                do
                    eval aliases_entry='$SMTP_ALIASES_1_ALIAS_'${idy}
                    echo "${aliases_entry}"

                    if [ "`echo "${aliases_entry}" | cut -d: -f1 | sed 's/ //g'`" = '*' ]
                    then
                        write_to_config_log -warn "SMTP_ALIASES_1_ALIAS_${idy}='${aliases_entry}' - The '*' character"
                        write_to_config_log -warn -ff "shouldn't be used in an alias definition of the primary mail domain!"
                        write_to_config_log -warn -ff "Strange mail delivery errors could appear!"
                    fi

                    idy=`expr ${idy} + 1`
                done

                # add other aliases files
                for AFILE in `ls ${generate_aliases}.* | grep -v aliases.std`
                do
                    echo
                    cat ${AFILE}
                done
            } > ${generate_aliases}
        fi

        idx=`expr ${idx} + 1`
    done

    /usr/bin/newaliases
}

#----------------------------------------------------------------------------------------
# check system user settings
# input: $1 - username
#        $2 - uid
#        $3 - gid
#        $4 - shell
#        $5 - password status -> '' - no check, '!' - check
#----------------------------------------------------------------------------------------
check_system_user ()
{
    # exim:x:42:42:exim:/usr/local/exim:/bin/false
    # trusted:x:42:
    # exim:*:8902:0:10000::::
    user="$1"
    uid="$2"
    gid="$3"
    shell="$4"
    pass="$5"

    grep -q "^$user:" $passwdfile

    if [ $? -eq 0 ]
    then
        mecho "checking settings of user '$user' ..."

        if [ "$uid" != "" ]
        then
            # user exists, check if group has properly been set
            uidname=`grep "^$user:" $passwdfile | cut -d: -f3`

            if [ "$uidname" != "$uid" ]
            then
                write_to_config_log -warn "Attention, user-id of user '$user' is not '$uid' anymore!"
                write_to_config_log -warn -ff "This might be a security leak!"
            fi
        fi

        if [ "$gid" != "" ]
        then
            # user exists, check if group has properly been set
            gidname=`grep "^$user:" $passwdfile | cut -d: -f4`

            if [ "$gidname" != "$gid" ]
            then
                group=`grep ":$gid:" $groupfile | cut -d: -f1`

                write_to_config_log -warn "Attention, group of user '$user' is not '$group' anymore!"
                write_to_config_log -warn -ff "This might be a security leak!"
            fi
        fi

        if [ "$shell" != "" ]
        then
            # user exists, check if shell has properly been set
            sname=`grep "^$user:" $passwdfile |cut -d: -f7`

            if [ "$sname" != "$shell" ]
            then
                write_to_config_log -warn "Attention, shell of user 'spam' is not '$shell' anymore!"
                write_to_config_log -warn -ff "This might be a security leak!"
            fi
        fi

        if [ "${pass}" = "!" ]
        then
            # user exists, check if password has been invalidated
            pword=`grep "^${user}:" /etc/shadow|cut -d: -f2`

            case ${EISFAIR_SYSTEM} in
                eisfair-1)
                    # eisfair-1
                    [ "${pword}" != "*" ] && ! echo "${pword}"|grep -q "^!"

                    if [ $? -eq 0 ]
                    then
                        write_to_config_log -warn "Attention, password of user '${user}' is not invalidated anymore!"
                        write_to_config_log -warn -ff "This might be a security leak!"
                    fi
                    ;;
                *)
                    # default to eisfair-2
                    pstat=`chage -l ${user} | grep "^Password expires" | sed 's/^Password.*: *//'`
                    astat=`chage -l ${user} | grep "^Account expires" | sed 's/^Account.*: *//'`

                    if [ ":${pword}:" != "::" -o ":${pword}:" != ":!:" -o "${pstat}" != "never" -o "${astat}" != "never" ]
                    then
                        write_to_config_log -warn "Attention, password of user '${user}' is not invalidated anymore!"
                        write_to_config_log -warn -ff "This might be a security leak!"
                    fi
                    ;;
            esac

        fi
    else
        write_to_config_log -error "System user '${user}' doesn't exist!"
    fi
}

#----------------------------------------------------------------------------------------
# check for pop3/imap certificates
#----------------------------------------------------------------------------------------
check_pop3imap_certs ()
{
    if [ "$POP3IMAP_TRANSPORT" = "tls" -o "$POP3IMAP_TRANSPORT" = "both" ]
    then
        if [ "$START_POP3" = "yes" ]
        then
            mecho "checking pop3 tls certificates ..."

            if [ -f $sslcert_path/ipop3d*.pem ]
            then
                # cert(s) found
                for FNAME in $sslcert_path/ipop3d*.pem
                do
                    mecho "- found: $FNAME"
                done
            else
                # no cert(s) found
                write_to_config_log -warn "Warning: Secure POP3 couldn't be used because no POP3 certificate"
                write_to_config_log -warn "found in \"$sslcert_path\"!"
            fi
        fi

        if [ "$START_IMAP" = "yes" ]
        then
            mecho "checking imap tls certificates ..."

            if [ -f $sslcert_path/imapd*.pem ]
            then
                # cert(s) found
                for FNAME in $sslcert_path/imapd*.pem
                do
                    mecho "- found: $FNAME"
                done
            else
                # no cert(s) found
                write_to_config_log -warn "Secure IMAP couldn't be used because no POP3 certificate"
                write_to_config_log -warn -ff "found in \"$sslcert_path\"!"
            fi
        fi
    fi
}

#----------------------------------------------------------------------------------------
# check for exim certificate
#----------------------------------------------------------------------------------------
check_exim_certs ()
{
    if [ "$SMTP_SERVER_TRANSPORT" = "tls" -o "$SMTP_SERVER_TRANSPORT" = "both" ]
    then
        if [ "$START_SMTP" = "yes" ]
        then
            mecho "checking exim tls certificates ..."

            if [ -f $sslcert_path/exim.pem ]
            then
                # cert(s) found
                mecho "- found: $sslcert_path/exim.pem"
            else
                # no cert(s) found
                write_to_config_log -warn "Secure SMTP couldn't be used because no SMTP certificate"
                write_to_config_log -warn -ff "found in \"$sslcert_path\"!"
            fi
        fi
    fi
}

#----------------------------------------------------------------------------------------
# read external exiscan av parameter file
# $1 - name of external parameters file
#----------------------------------------------------------------------------------------
read_exiscan_av_parameters ()
{
    param_file=$1

    if [ -f $param_file ]
    then
        # convert to unix format
        dtou ${param_file}

        tmp_file=$param_file.$$

        # delete temporary file(s)
        ls ${param_file}.* > /dev/null 2> /dev/null

        if [ $? -eq 0 ]
        then
            chmod 700 ${param_file}.*
            rm -f ${param_file}.*
        fi

        if [ ! -f $tmp_file ]
        then
            # use only allowed parameters
            grep "^AV_" $param_file > $tmp_file

            . $tmp_file

            case "$AV_SCANNER"
            in
                sophie|kavdaemon|clamd|drweb )
                    EXISCAN_AV_ENABLED='yes'
                    EXISCAN_AV_SCANNER="$AV_SCANNER"
                    EXISCAN_AV_SOCKET="$AV_SOCKET"
                    ;;
                mksd )
                    EXISCAN_AV_ENABLED='yes'
                    EXISCAN_AV_SCANNER="$AV_SCANNER"
                    ;;
                cmdline )
                    EXISCAN_AV_ENABLED='yes'
                    EXISCAN_AV_SCANNER="$AV_SCANNER"
                    EXISCAN_AV_PATH="$AV_PATH"
                    EXISCAN_AV_OPTIONS="$AV_OPTIONS"
                    EXISCAN_AV_TRIGGER="$AV_TRIGGER"
                    EXISCAN_AV_DESCRIPTION="$AV_DESCRIPTION"
                    ;;
                * )
                    # error
                    write_to_config_log -warn "Invalid AV_SCANNER parameter in av config file \"$param_file\"."
                    write_to_config_log -warn "Virus scanning will be disabled!"

                    EXISCAN_AV_ENABLED='no'
                    ;;
            esac

            rm -f $tmp_file
        fi
    fi
}

#----------------------------------------------------------------------------------------
# check if pop3/imap mail access has been enabled/disabled
#----------------------------------------------------------------------------------------
check_pop3imap_mail_access ()
{
    if [ -f $toggle_mailaccess ]
    then
        # access has been disabled manually via menu
        write_to_config_log -info "POP3/IMAP mail access has been manually disabled. You can enable it via"
        write_to_config_log -info -ff "the 'Toggle POP3/IMAP access' command from the 'Mail services' menu."
    fi
}

#----------------------------------------------------------------------------------------
# creating pop3 configuration
# $1 - no-init of xinet after reconfigure
#----------------------------------------------------------------------------------------
create_xinet_pop3 ()
{
    noinit=$1

    mecho "creating xinet/pop3 configuration file ..."

    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_pop3conf}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo "service pop3"
        echo "{"
        echo "  socket_type = stream"
        echo "  protocol = tcp"
        echo "  wait = no"
        echo "  user = root"
        echo "  server = /usr/sbin/ipop3d"

        if [ "$POP3IMAP_IDENT_CALLBACKS" != "no" ]
        then
            echo "  log_on_success += USERID"
            echo "  log_on_failure += USERID"
        fi

        if [ "$START_POP3" = "yes" -a \( "$POP3IMAP_TRANSPORT" = "default" -o "$POP3IMAP_TRANSPORT" = "both" \) ]
        then
            if [ -f $toggle_mailaccess ]
            then
                # access has been disabled manually via menu
                echo "  disable = yes"
            else
                echo "  disable = no"
            fi
        else
            echo "  disable = yes"
        fi

        echo "}"
        echo

        # secure POP3
        echo "service pop3s"
        echo "{"
        echo "  socket_type = stream"
        echo "  protocol = tcp"
        echo "  wait = no"
        echo "  user = root"
        echo "  server = /usr/sbin/ipop3d"

        if [ "$POP3IMAP_IDENT_CALLBACKS" != "no" ]
        then
            echo "  log_on_success += USERID"
            echo "  log_on_failure += USERID"
        fi

        if [ "$START_POP3" = "yes" -a \( "$POP3IMAP_TRANSPORT" = "tls" -o "$POP3IMAP_TRANSPORT" = "both" \) ]
        then
            if [ -f $toggle_mailaccess ]
            then
                # access has been disabled manually via menu
                echo "  disable = yes"
            else
                echo "  disable = no"
            fi
        else
            echo "  disable = yes"
        fi

        echo "}"
    } > $generate_pop3conf

    if [ "$noinit" != "noinit" ]
    then
        if [ "$START_POP3" = "yes" ]
        then
            killall -1 xinetd

            if [ $? -ne 0 ]
            then
                mecho --error "pop3 server needs xinetd which is not running."
            fi
        else
            killall -1 inetd 2> /dev/null
        fi
    fi
}

#----------------------------------------------------------------------------------------
# creating imap configuration
# $1 - no-init of xinet after reconfigure
#----------------------------------------------------------------------------------------
create_xinet_imap ()
{
    noinit=$1

    mecho "creating xinet/imap configuration file ..."

    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_imapconf}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo "service imap4"
        echo "{"
        echo "  socket_type = stream"
        echo "  protocol = tcp"
        echo "  wait = no"
        echo "  user = root"
        echo "  server = /usr/sbin/imapd"

        if [ "$POP3IMAP_IDENT_CALLBACKS" != "no" ]
        then
            echo "  log_on_success += USERID"
            echo "  log_on_failure += USERID"
        fi

        if [ "$START_IMAP" = "yes" -a \( "$POP3IMAP_TRANSPORT" = "default" -o "$POP3IMAP_TRANSPORT" = "both" \) ]
        then
            if [ -f $toggle_mailaccess ]
            then
                # access has been disabled manually via menu
                echo "  disable = yes"
            else
                echo "  disable = no"
            fi
        else
            echo "  disable = yes"
        fi

        echo "}"
        echo

        # secure IMAP
        echo "service imap4s"
        echo "{"
        echo "  socket_type = stream"
        echo "  protocol = tcp"
        echo "  wait = no"
        echo "  user = root"
        echo "  server = /usr/sbin/imapd"

        if [ "$POP3IMAP_IDENT_CALLBACKS" != "no" ]
        then
            echo "  log_on_success += USERID"
            echo "  log_on_failure += USERID"
        fi

        if [ "$START_IMAP" = "yes" -a \( "$POP3IMAP_TRANSPORT" = "tls" -o "$POP3IMAP_TRANSPORT" = "both" \) ]
        then
            if [ -f $toggle_mailaccess ]
            then
                # access has been disabled manually via menu
                echo "  disable = yes"
            else
                echo "  disable = no"
            fi
        else
            echo "  disable = yes"
        fi

        echo "}"
    } > $generate_imapconf

    if [ "$noinit" != "noinit" ]
    then
        if [ "$START_IMAP" = "yes" ]
        then
            killall -1 xinetd

            if [ $? -ne 0 ]
            then
                mecho --error "imap server needs xinetd which is not running."
            fi
        else
            killall -1 inetd 2> /dev/null
        fi
    fi
}

#----------------------------------------------------------------------------------------
# create mailinglists
#----------------------------------------------------------------------------------------
create_mailinglists ()
{
    if [ $SMTP_LIST_N -gt 0 ]
    then
        mecho "creating mailinglist files ..."

        mkdir -p $mailinglists_path

        # delete old files
        ls $mailinglists_path/*-request > /dev/null 2> /dev/null

        if [ $? -eq 0 ]
        then
            for mname in `ls $mailinglists_path/*-request|sed -e 's/.*\///' -e 's/-request//'`
            do
                rm -f $mailinglists_path/$mname
                rm -f $mailinglists_path/$mname-request
            done
        fi

        # create new files
        idx=1
        while [ $idx -le $SMTP_LIST_N ]
        do
            eval list_active='$SMTP_LIST_'$idx'_ACTIVE'
            eval list_name='$SMTP_LIST_'$idx'_NAME'

            if [ "$list_active" = "yes" ]
            then
                eval list_user_n='$SMTP_LIST_'$idx'_USER_N'

                {
                    jdx=1
                    while [ $jdx -le $list_user_n ]
                    do
                        eval user='$SMTP_LIST_'$idx'_USER_'$jdx
                        echo $user
                        jdx=`expr $jdx + 1`
                    done

                    # creating mailinglist admin file
                    echo "$SMTP_LIST_ERRORS" > $mailinglists_path/$list_name-request
                } > $mailinglists_path/$list_name
            else
                # deactivated
                write_to_config_log -info "Skipping SMTP_LIST_${idx}_NAME='${list_name}' because"
                write_to_config_log -info -ff "it has been deactivated in the configuration file."
            fi

            idx=`expr $idx + 1`
        done
    fi
}

#----------------------------------------------------------------------------------------
# create outgoing addresses file
#----------------------------------------------------------------------------------------
create_outgoing_addresses ()
{
    if [ ${SMTP_SMARTHOST_N} -gt 0 ]
    then
        if [ ${SMTP_OUTGOING_ADDRESSES_N} -gt 0 ]
        then
            mecho "creating outgoing addresses file ..."

            {
                #----------------------------------------------------------------------------------------
                print_short_header "${generate_addresses}" "${pgmname}" "mail" "${mail_version}"
                #----------------------------------------------------------------------------------------

                idx=1
                while [ ${idx} -le ${SMTP_OUTGOING_ADDRESSES_N} ]
                do
                    # user:   mail address
                    eval address='$SMTP_OUTGOING_ADDRESSES_'${idx}
                    echo "${address}"

                    idx=`expr ${idx} + 1`
                done
            } > ${generate_addresses}
        else
            # creating empty file
            mecho "deleting outgoing addresses file ..."
            {
                #----------------------------------------------------------------------------------------
                print_short_header "${generate_addresses}" "${pgmname}" "mail" "${mail_version}"
                #----------------------------------------------------------------------------------------
            } > ${generate_addresses}
        fi

        # set access rights
        chmod 0600 ${generate_addresses}
        chown exim ${generate_addresses}
        chgrp trusted ${generate_addresses}
    fi
}

#----------------------------------------------------------------------------------------
# create smarthost file
#----------------------------------------------------------------------------------------
create_smarthosts ()
{
    if [ $SMTP_SMARTHOST_N -gt 0 -a "$SMTP_SMARTHOST_ONE_FOR_ALL" != "yes" ]
    then
        mecho "creating smarthosts authentication file ..."

        {
            #----------------------------------------------------------------------------------------
            print_short_header "${generate_smarthosts}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            idx=1
            while  [ $idx -le $SMTP_SMARTHOST_N ]
            do
                eval sh_auth='$SMTP_SMARTHOST_'$idx'_AUTH_TYPE'
                eval sh_addr='$SMTP_SMARTHOST_'$idx'_ADDR'
                eval sh_domain='$SMTP_SMARTHOST_'$idx'_DOMAIN'
                eval sh_host='$SMTP_SMARTHOST_'$idx'_HOST'
                eval sh_user='$SMTP_SMARTHOST_'$idx'_USER'
                eval sh_pass='$SMTP_SMARTHOST_'$idx'_PASS'
                eval sh_port='$SMTP_SMARTHOST_'$idx'_PORT'

                if [ "$sh_port" = "" -o "$sh_port" = "25" ]
                then
                    # set default port
                    sh_port="smtp"
                fi

                # print a warning if authentication hasn't been enabled although username and password has been set
                if [ "$sh_user" != "" -a "$sh_pass" != "" -a "$sh_auth" = "none" ]
                then
                    write_to_config_log -warn "Warning: You have set a username and password for the smarthost"
                    write_to_config_log -warn -ff "\"$sh_host\" but have set SMTP_SMARTHOST_x_AUTH_TYPE='none'."
                    write_to_config_log -warn -ff "Authentication will be disabled!"
                fi

                if [ "$SMTP_SMARTHOST_ROUTE_TYPE" = "addr" ]
                then
                    # lookup sender address
                    # convert address to lowercase
                    sh_addr=`echo "$sh_addr"|tr '[:upper:]' '[:lower:]'`

                    # mail address:  server=smtp_server  auth=authentication  port=smtp_port  user=login_name  pass=password
                    echo "${sh_addr}: server=${sh_host} auth=${sh_auth} port=${sh_port} user=${sh_user} pass=${sh_pass}"
                    #printf "%-35s%-35s%-30s%-30s%-30s\n" "$sh_addr:" "server=$sh_host" "port=$sh_port" "user=$sh_user" "pass=$sh_pass"
                else
                    # lookup domain
                    # convert domain to lowercase
                    sh_domain=`echo "$sh_domain"|tr '[:upper:]' '[:lower:]'`

                    # domain:  server=smtp_server  auth=authentication  port=smtp_port  user=login_name  pass=password
                    echo "${sh_domain}: server=${sh_host} auth=${sh_auth} port=${sh_port} user=${sh_user} pass=${sh_pass}"
                fi

                idx=`expr $idx + 1`
            done
        } > $generate_smarthosts

        # set access rights
        chmod 0600 $generate_smarthosts
        chown exim $generate_smarthosts
        chgrp trusted $generate_smarthosts
    else
        # delete existing file
        if [ -f $generate_smarthosts ]
        then
            mecho "deleting smarthosts authentication file ..."
            rm -f $generate_smarthosts
        fi
    fi

}

#----------------------------------------------------------------------------------------
# create system filter file
#----------------------------------------------------------------------------------------
create_system_filter ()
{
    ls ${custom_systemfilter}.* > /dev/null 2> /dev/null

    if [ $? -eq 0 -o "${START_EXISCAN}" = "yes" ]
    then
        # remove existing system filter file
        rm -f ${generate_systemfilter}

        mecho "creating system-filter file ..."

        {
            echo "# Exim filter"

            #----------------------------------------------------------------------------------------
            print_short_header "${generate_systemfilter}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            echo "# catch script errors"
            echo "if error_message"
            echo "then"
            echo "    finish"
            echo "endif"

            if [ "${START_EXISCAN}" = "yes" ]
            then
                echo
                echo "if \"\${if def:h_X-New-Scan-Done: {def}{undef}}\" is def"
                echo "then"
                echo "    # exiscan has been run - remove indicator"
                echo "    headers remove X-New-Scan-Done"
                echo
                echo "    # remove non-exiscan scan headers"
                echo "    headers remove X-Scanned-By"
                echo
                echo "    # remove non-exiscan scan headers"
                echo "    headers remove X-Spam-Status"
                echo
                echo "    # remove non-exiscan scan headers"
                echo "    headers remove X-Virus-Scanned"
                echo
                echo "    # remove non-exiscan scan headers"
                echo "    headers remove X-Antivirus"
                echo
                echo "    # remove non-exiscan scan headers"
                echo "    headers remove X-Antivirus-Status"
                echo
                echo "    # exiscan - replace scan signature"
                echo "    headers remove X-Scan-Signature"
                echo
                echo "    if \"\${if def:h_X-New-Scan-Signature: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Scan-Signature: \$h_X-New-Scan-Signature:\""
                echo "        headers remove X-New-Scan-Signature"
                echo "    endif"
                echo
              # echo "    # exiscan - remove scanner"
              # echo "    if \"\${if def:h_X-Scanner: {def}{undef}}\" is def"
              # echo "    then"
              # echo "        headers remove X-Scanner"
              # echo "    endif"
              # echo
                echo "    # exiscan - replace virus flag"
                echo "    headers remove X-Virus-Flag"
                echo
                echo "    if \"\${if def:h_X-New-Virus-Flag: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Virus-Flag: \$h_X-New-Virus-Flag:\""
                echo "        headers remove X-New-Virus-Flag"
                echo "    endif"
                echo
                echo "    # exiscan - replace virus name"
                echo "    headers remove X-Virus"
                echo
                echo "    if \"\${if def:h_X-New-Virus: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Virus: \$h_X-New-Virus:\""
                echo "        headers remove X-New-Virus"
                echo "    endif"
                echo
                echo "    # exiscan - insert virus subject"
                echo "    if \"\${if def:h_X-New-Virus-Subject: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers remove subject"
                echo "        headers add \"Subject: \$h_X-New-Virus-Subject:\""
                echo "        headers remove X-New-Virus-Subject"
                echo "    endif"
                echo
                echo "    # exiscan - replace spam flag"
                echo "    headers remove X-Spam-Flag"
                echo
                echo "    if \"\${if def:h_X-New-Spam-Flag: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Spam-Flag: \$h_X-New-Spam-Flag:\""
                echo "        headers remove X-New-Spam-Flag"
                echo "    endif"
                echo
                echo "    # exiscan - replace spam score"
                echo "    headers remove X-Spam-Score"
                echo
                echo "    if \"\${if def:h_X-New-Spam-Score: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Spam-Score: \$h_X-New-Spam-Score:\""
                echo "        headers remove X-New-Spam-Score"
                echo "    endif"
                echo
                echo "    # exiscan - replace spam report"
                echo "    headers remove X-Spam-Report"
                echo
                echo "    if \"\${if def:h_X-New-Spam-Report: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers add \"X-Spam-Report: \$h_X-New-Spam-Report:\""
                echo "        headers remove X-New-Spam-Report"
                echo "    endif"
                echo
                echo "    # exiscan - insert spam subject"
                echo "    if \"\${if def:h_X-New-Spam-Subject: {def}{undef}}\" is def"
                echo "    then"
                echo "        headers remove subject"
                echo "        headers add \"Subject: \$h_X-New-Spam-Subject:\""
                echo "        headers remove X-New-Spam-Subject"
                echo "    endif"
                echo "endif"
            fi

        } > ${generate_systemfilter}

        # custom system filter
        ls ${custom_systemfilter}.* > /dev/null 2> /dev/null

        if [ $? -eq 0 ]
        then
            for SFILE in ${custom_systemfilter}.*
            do
                if [ "`/usr/bin/head -c 20 "${SFILE}"`" = "# Exim custom filter" ]
                then
                    mecho "adding custom system filter ${SFILE} ..."

                    {
                        echo
                        cat "${SFILE}"
                    } >> ${generate_systemfilter}
                else
                    write_to_config_log -warn "Ignoring custom filter ${SFILE} because no \"# Exim custom filter\" header found!"
                fi
            done
        fi

        # set access rights
        chmod 0600 ${generate_systemfilter}
        chown exim ${generate_systemfilter}
        chgrp trusted ${generate_systemfilter}
    else
        # delete existing file
        if [ -f ${generate_systemfilter} ]
        then
            mecho "deleting system-filter file ..."
            rm -f ${generate_systemfilter}
        fi
    fi
}

#----------------------------------------------------------------------------------------
# create ignored hosts file
#----------------------------------------------------------------------------------------
create_ignore_hosts ()
{
    if [ "$SMTP_UPDATE_IGNORE_HOSTS" = "yes" -a "$SMTP_SMARTHOST_ONE_FOR_ALL" = "no" ]
    then
        {
            #----------------------------------------------------------------------------------------
            print_short_header "${generate_ignorehosts}" "${pgmname}" "mail" "${mail_version}"
            #----------------------------------------------------------------------------------------

            echo "# Wildcard IPs: tgTLD"

            curr_dir=`pwd`
            cd /tmp

            # remove any obsolete file
            if [ -f /tmp/${zone_file} ]
            then
                rm -f /tmp/${zone_file}
            fi

            # check which wget version has been installed
            wget --help  | grep -q "\-C"

            if  [ $? -eq 0 ]
            then
                # wget <> v1.10.x
                /usr/local/bin/wget.sh -C off -T 90 -P /tmp -q ${zone_url1}

                if [ ! -f /tmp/${zone_file} ]
                then
                    /usr/local/bin/wget.sh -C off -T 90 -P /tmp -q ${zone_url2}
                fi
            else
                # wget >= v1.10.x
                /usr/local/bin/wget.sh --no-cache -T 90 -P /tmp -q ${zone_url1}

                if [ ! -f /tmp/${zone_file} ]
                then
                    /usr/local/bin/wget.sh --no-cache -T 90 -P /tmp -q ${zone_url2}
                fi
            fi

            cd ${curr_dir}

            for DNAME in `gunzip -c /tmp/$zone_file| grep NS | awk '{print $1}' | uniq | egrep "^[^\.]*\.$"`
            do
                ip_addr=`/usr/local/bin/dnsip "*.${DNAME}" 2> /dev/null`
                ret_code="$?"

                if [ $ret_code -eq 0 ]
                then
                    if [ "$ip_addr" != "" ]
                    then
                        echo "$ip_addr: # $DNAME"
                    fi
                else
                    echo "# $DNAME could not be resolved"
                fi
            done
        } > $generate_ignorehosts.tmp

        # replace existing file
        mv $generate_ignorehosts.tmp $generate_ignorehosts

        # set access rights
        chmod 0600 $generate_ignorehosts
        chown exim $generate_ignorehosts
        chgrp trusted $generate_ignorehosts

        # remove zone file
        if [ -f /tmp/$zone_file ]
        then
            rm -f /tmp/$zone_file
        fi
    else
        # delete existing file
        if [ -f $generate_ignorehosts ]
        then
            rm -f $generate_ignorehosts
        fi
    fi
}

#----------------------------------------------------------------------------------------
# create logrotate file
#----------------------------------------------------------------------------------------
create_logrotate ()
{
    mecho "creating logrotate configuration file ..."

    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_logrotate}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo "$eximspool_path/log/mainlog $eximspool_path/log/paniclog $eximspool_path/log/rejectlog {"
        echo "    rotate $MAIL_LOG_COUNT"
        echo "    $MAIL_LOG_INTERVAL"
        echo "    compress"
        echo "    missingok"
        echo "    notifempty"
        echo "    sharedscripts"
        echo "    create 640 exim trusted"

        if [ "$START_SMTP" = "yes" ]
        then
            echo "    postrotate"
            echo "        $eximstart_path/mail -quiet reload exim"
            echo "    endscript"
        fi

        echo "}"
        echo

        if [ "$START_FETCHMAIL" = "yes" ]
        then
            echo "$systemlog_path/fetchmail.log {"
            echo "    rotate $MAIL_LOG_COUNT"
            echo "    $MAIL_LOG_INTERVAL"
            echo "    compress"
            echo "    notifempty"
            echo "    create 640 exim trusted"
            echo "    postrotate"
            echo "        $eximstart_path/mail -quiet reload fetch"
            echo "    endscript"
            echo "    }"
        else
            echo "# Fetchmail disabled!"
        fi
    } >$generate_logrotate
}

#----------------------------------------------------------------------------------------
# create mail.rc file
#----------------------------------------------------------------------------------------
create_mailrc ()
{
    mecho "creating mail configuration file ..."

    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_mailrc}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo 'set ask'                                 # ask for a subject
        echo 'set askcc'                               # ask for carbon copy recipients
        echo 'set askbcc'                              # ask for blind carbon copy recipients
        echo 'set dot'                                 # enable period as end of message sign
        echo 'set hold'                                # hold messages in system mailbox
        echo 'set metoo'                               # mail to groups will also send to me
    } >$generate_mailrc
}

#----------------------------------------------------------------------------------------
# set access rights
#----------------------------------------------------------------------------------------
set_exim_access_rights ()
{
    mecho "setting access rights ..."

    if [ -f $eximbin_path/exim ]
    then
        chmod -f 4755 $eximbin_path/exim            # exim binary with uid=root
    fi

    if [ -d $eximspool_path ]
    then
        chmod -f 750 $eximspool_path
    fi
    if [ -d $eximspool_path/scan ]
    then
        chmod -f 770 $eximspool_path/scan
    fi

    for dname in db input log mailinglists msglog scan
    do
        if [ -d $eximspool_path/$dname ]
        then
            chmod -f 750 $eximspool_path/$dname
        fi
    done

    if [ -d $eximspool_path ]
    then
        chown -f -R exim $eximspool_path
        chgrp -f -R trusted $eximspool_path
    fi

    if [ -f ${generate_eximconf} ]
    then
        chown -f root ${generate_eximconf}
        chgrp -f trusted ${generate_eximconf}
    fi

    # change ownership of fetchmail files
    if [ -f ${generate_fetchconf} ]
    then
        chown exim    ${generate_fetchconf}
        chgrp trusted ${generate_fetchconf}
    fi

    if [ -f ${systemlog_path}/fetchmail.log ]
    then
        chown exim    ${systemlog_path}/fetchmail.log
        chgrp trusted ${systemlog_path}/fetchmail.log
    fi
}

#----------------------------------------------------------------------------------------
# adding mail service
#----------------------------------------------------------------------------------------
add_mail_services ()
{
    mecho "checking pop3/imap/smtp services ..."

    {
        echo "#"
        echo "# $generate_services list file generated by $pgmname $mail_version"
        echo "#"

        # POP3
        echo "pop3          110/tcp            # POP version 3"
        echo "pop3          110/udp            # POP version 3"

        # IMAP
        echo "imap4         143/tcp imap imap2 # IMAP version 4"
        echo "imap4         143/udp imap imap2 # IMAP version 4"

        # SMTP
        echo "smtp           25/tcp mail       # Simple Mail Transport Protocol"
        echo "smtp           25/udp mail       # Simple Mail Transport Protocol"

        # ESMTP with authentication
        echo "submission    587/tcp            # Extended Simple Mail Transport Protocol"
        echo "submission    587/udp            # Extended Simple Mail Transport Protocol"


        # secure IMAP
        echo "imap4s        993/tcp imaps      # IMAP version 4 over TLS/SSL"
        echo "imap4s        993/udp imaps      # IMAP version 4 over TLS/SSL"

        # secure POP3
        echo "pop3s         995/tcp spop3      # POP version 3 over TLS/SSL"
        echo "pop3s         995/udp spop3      # POP version 3 over TLS/SSL"

        # SMTPS
        echo "smtps         465/tcp ssmtp      # SMTP over SSL"
        echo "smtps         465/udp ssmtp      # SMTP over SSL"
    } > $generate_services

    ${install_bin_path}/update-services mail
}

#----------------------------------------------------------------------------------------
# check if antispam has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_antispam ()
{
    if [ -f ${antispamfile} ]
    then
        # antispam installed
        . ${antispamfile}

        if [ "${START_ANTISPAM}" = "yes" ]
        then
            # antispam activated
            if [ "$1" != "-quiet" ]
            then
                mecho "antispam support has been enabled ..."
            fi
            retval=1
        else
            # antispam deactivated
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "antispam support has been disabled ..."
            fi
            retval=0
        fi
    else
        # antispam not installed
        retval=0
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if eisfax has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_eisfax ()
{
    if [ -f ${eisfaxfile} ]
    then
        # eisfax installed
        . ${eisfaxfile}

        if [ "${START_EISFAX}" = "yes" -a "${EISFAX_MAIL_TO_FAX_USE}" = "yes" ]
        then
            # eisfax activated
            if [ "$1" != "-quiet" ]
            then
                mecho "eisfax support has been enabled ..."
            fi
            retval=1
        else
            # eisfax deactivated
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "eisfax support has been disabled ..."
            fi
            retval=0
        fi
    else
        # eisfax not installed
        retval=0
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if mail2print has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_mail2print ()
{
    retval=0

    if [ -f ${mail2printfile} ]
    then
        # mail2print installed
        . ${mail2printfile}

        if [ "${START_MAIL2PRINT}" = "yes" ]
        then
            m2p_flag=1

            # search for active entry
            idx=1
            while [ ${idx} -le ${MAIL2PRINT_N} ]
            do
                eval active='$MAIL2PRINT_'${idx}'_ACTIVE'

                if [ "${active}" = "yes" ]
                then
                    m2p_flag=0
                    break
                fi

                idx=`expr ${idx} + 1`
            done

            if [ ${m2p_flag} -eq 0 ]
            then
                # mail2print activated
                if [ "$1" != "-quiet" ]
                then
                    mecho "mail2print support has been enabled ..."
                fi
                retval=1
            fi
        else
            # mail2print deactivated
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "mail2print support has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if mailman has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_mailman ()
{
    if [ -f ${mailmanfile} ]
    then
        # mailman installed
        . ${mailmanfile}

        if [ "${START_MAILMAN}" = "yes" ]
        then
            # mailman activated
            if [ "$1" != "-quiet" ]
            then
                mecho "mailman support has been enabled ..."
            fi
            retval=1
        else
            # mailman deactivated
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "mailman support has been disabled ..."
            fi
            retval=0
        fi
    else
        # mailman not installed
        retval=0
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if mailquota has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_mailquota ()
{
    retval=0

    if [ -f ${mailquotafile} ]
    then
        # mailquota installed
        . ${mailquotafile}

        if [ "${START_MAILQUOTA}" = "yes" ]
        then
            # mailquota activated
            if [ "$1" != "quiet" ]
            then
                mecho "mailquota support has been enabled ..."
            fi

            retval=1
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if uucp has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_uucp ()
{
    retval=0

    if [ -f ${uucpfile} ]
    then
        # uucp installed
        . ${uucpfile}

        if [ "${START_UUCP}" = "yes" -a \( "${UUCP_CLIENT_ENABLED}" = "yes" -o "${UUCP_SERVER_ENABLED}" = "yes" \) ]
        then
            # uucp activated
            if [ "$1" != "-quiet" ]
            then
                mecho "uucp support has been enabled ..."
            fi

            retval=1
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if perl has been installed
# input:  $1 - '-quiet' means no output
# return:  0 - perl not installed
#          1 - perl installed
#----------------------------------------------------------------------------------------
check_installed_perl ()
{
    retval=0

    if [ \( "${SMTP_SMARTHOST_N}" -gt 0 -a "${SMTP_OUTGOING_ADDRESSES_N}" -gt 0 \) -o \
            "${SMTP_REMOVE_RECEIPT_REQUEST}" = "yes" ]
    then
        if [ ! -f /usr/bin/perl ]
        then
            # perl not installed
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "perl package not installed ..."
            fi

            write_to_config_log -warn "You have set SMTP_SMARTHOST_N > 0 and SMTP_OUTGOING_ADDRESSES_N > 0 or"
            write_to_config_log -warn -ff "have set SMTP_REMOVE_RECEIPT_REQUEST='yes' but the required perl"
            write_to_config_log -warn -ff "interpreter hasn't been installed!"
        else
            # perl installed
            if [ "$1" != "-quiet" ]
            then
                mecho "perl package has been installed ..."

                retval=1
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if sn has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - not installed and activated
#          1 - installed and activated
#----------------------------------------------------------------------------------------
check_installed_sn ()
{
    retval=0

    if [ -f ${snfile} ]
    then
        # sn installed
        . ${snfile}

        if [ "${START_SN}" = "yes" ]
        then
            # sn activated
            if [ "$1" != "-quiet" ]
            then
                mecho "sn support has been enabled ..."
            fi
            retval=1
        else
            # sn deactivated
            if [ "$1" != "-quiet" ]
            then
                mecho --warn "sn support has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if webmail has been installed
# input:  $1 - '-quiet' means no output
# return:  0 - webmail not installed and activated
#          1 - webmail installed and activated
#----------------------------------------------------------------------------------------
check_installed_webmail ()
{
    retval=0

    if [ -f ${roundcubefile} ]
    then
        # webmail installed
        . ${roundcubefile}

        if [ "${START_ROUNDCUBE}" = "yes" ]
        then
            # Roundcube webmail activated
            if [ "$1" != "-quiet" ]
            then
                write_to_config_log -info "Roundcube has been installed, please remember to update its configuration!"
            fi
            retval=1
        fi
    fi

    if [ -f ${webmailfile} ]
    then
        # webmail installed
        . ${webmailfile}

        if [ "${START_WEBMAIL}" = "yes" ]
        then
            # webmail activated
            if [ "$1" != "-quiet" ]
            then
                write_to_config_log -info "Webmail has been installed, please remember to update its configuration!"
            fi
            retval=1
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# create list of installed sub packages
#----------------------------------------------------------------------------------------
create_installed_list ()
{

    # generate list of installed packages
    {
        #----------------------------------------------------------------------------------------
        print_short_header "${generate_installedlist}" "${pgmname}" "mail" "${mail_version}"
        #----------------------------------------------------------------------------------------

        echo "ANTISPAM_INSTALLED=${ANTISPAM_INSTALLED}"
        echo "EISFAX_INSTALLED=${EISFAX_INSTALLED}"
        echo "MAIL2PRINT_INSTALLED=${MAIL2PRINT_INSTALLED}"
        echo "MAILMAN_INSTALLED=${MAILMAN_INSTALLED}"
        echo "MAILQUOTA_INSTALLED=${MAILQUOTA_INSTALLED}"
        echo "SN_INSTALLED=${SN_INSTALLED}"
        echo "PERL_INSTALLED=${PERL_INSTALLED}"
        echo "UUCP_INSTALLED=${UUCP_INSTALLED}"
        echo "WEBMAIL_INSTALLED=${WEBMAIL_INSTALLED}"
    } > ${generate_installedlist}

    # set access rights
    chmod 0644 ${generate_installedlist}
    chown exim ${generate_installedlist}
    chgrp trusted ${generate_installedlist}
}

#----------------------------------------------------------------------------------------
# check if root alias has been defined
#----------------------------------------------------------------------------------------
check_root_alias ()
{
    if [ "$START_SMTP" = "yes" ]
    then
        mecho "checking root alias ..."
        cat $generate_aliases | tr -s '\t ' '  ' | sed 's/ //g' | grep -q "^root:"

        if [ $? -ne 0 -o $SMTP_ALIASES_N -eq 0 -o $SMTP_ALIASES_1_ALIAS_N -eq 0 ]
        then
            # no alias has been defined at all
            write_to_config_log -error "No root alias has been defined. Set SMTP_ALIASES_1_ALIAS_1='root: <username>'"
            write_to_config_log -error -ff "as minimum!"
        fi
    fi
}

#----------------------------------------------------------------------------------------
# insert virus name into string
# $1 - text string
#
# Ret: modified text string
#----------------------------------------------------------------------------------------
insert_virus_name ()
{
    work_str="$1"

    RSTR="VN"
    echo "$work_str"|grep -q "%$RSTR[][\(\)\$\%\/ .,_0-9-]*"

    if [ $? -eq 0 ]
    then
        tmp_str1=`expr "$work_str" : "\(.*\)\%$RSTR"`
        tmp_str2=`expr "$work_str" : ".*\%$RSTR\(.*\)"`
        work_str="${tmp_str1}\$malware_name${tmp_str2}"
    fi

    echo "$work_str"
}

#----------------------------------------------------------------------------------------
# insert spam score into string
# $1 - text string
#
# Ret: modified text string
#----------------------------------------------------------------------------------------
insert_spam_score ()
{
    work_str="$1"

    RSTR="SC"
    echo "$work_str"|grep -q "%$RSTR[][\(\)\$\%\/ .,_0-9-]*"

    if [ $? -eq 0 ]
    then
        tmp_str1=`expr "$work_str" : "\(.*\)\%$RSTR"`
        tmp_str2=`expr "$work_str" : ".*\%$RSTR\(.*\)"`
        work_str="${tmp_str1}\$spam_score_int${tmp_str2}"
    fi

    echo "$work_str"
}

#----------------------------------------------------------------------------------------
# send spam mailbox status message
#----------------------------------------------------------------------------------------
send_exim_statistics ()
{
    if [ "${MAIL_STATISTICS_INFOMAIL}" = "yes" ]
    then
        if [ -f /usr/bin/perl ]
        then
            # perl has been installed
            if [ -f ${eximspool_path}/log/mainlog ]
            then
                # mainlog found
                subject=`insert_hostname "${MAIL_STATISTICS_INFOMAIL_SUBJECT}"`
                subject="`insert_date \"${subject}\"`"

                options=''
                if [ "${MAIL_STATISTICS_INFOMAIL_OPTIONS}" != "" ]
                then
                    options="${MAIL_STATISTICS_INFOMAIL_OPTIONS}"
                fi

                # send infomail
                {
                    echo "From: Mailer-Daemon <mailer-daemon@${SMTP_QUALIFY_DOMAIN}>"
                    echo "To: Postmaster <postmaster@${SMTP_QUALIFY_DOMAIN}>"
                    echo "Subject: ${subject}"
                    echo
                    ${eximbin_path}/eximstats ${options} ${eximspool_path}/log/mainlog

                } | /usr/lib/sendmail postmaster@${SMTP_QUALIFY_DOMAIN}
            fi
        fi
    fi
}

#----------------------------------------------------------------------------------------
# add cron job for statistic notification
#----------------------------------------------------------------------------------------
add_cron_job ()
{
    if [ "${MAIL_STATISTICS_INFOMAIL}" = "yes" -o "${MAIL_CERTS_WARNING}" = "yes" ]
    then
        # check for cron directory
        if [ ! -d ${crontab_path} ]
        then
            mkdir -p ${crontab_path}
        fi

        {
            echo "#--------------------------------------------------------------------"
            echo "#  cron mail file generated by ${pgmname} version: ${mail_version}"
            echo "#"
            echo "#  Do not edit this file, edit ${mailfile}"
            echo "#  Creation Date: ${EISDATE} Time: ${EISTIME}"
            echo "#--------------------------------------------------------------------"
        } > ${generate_crontab}

        if [ "${MAIL_STATISTICS_INFOMAIL}" = "yes" ]
        then
            # should send infomail
            mecho "adding statistics notification ..."

            # write cronjob file
            echo "${MAIL_STATISTICS_INFOMAIL_CRON_SCHEDULE} ${mail_configfile} sendstatistics" >> ${generate_crontab}
        fi

        if [ "${MAIL_CERTS_WARNING}" = "yes" ]
        then
            # should send certs warning
            mecho "adding certification notification ..."

            # write cronjob file
            echo "${MAIL_CERTS_WARNING_CRON_SCHEDULE} ${mail_configfile} sendcertwarning" >> ${generate_crontab}
        fi

        if [ "${SMTP_UPDATE_IGNORE_HOSTS}" = "yes" -a "${SMTP_SMARTHOST_ONE_FOR_ALL}" = "no" ]
        then
            # should update ignore hosts list
            mecho "adding ignore hosts update ..."

            # write cronjob file
            echo "${SMTP_UPDATE_IGNORE_HOSTS_CRON_SCHEDULE} ${mail_configfile} ignorehosts" >> ${generate_crontab}
        fi

        echo >> ${generate_crontab}

        # update crontab file
        /var/install/config.d/cron.sh -quiet
    fi
}

#----------------------------------------------------------------------------------------
# delete cron job for spam mailbox verification
#----------------------------------------------------------------------------------------
delete_cron_job ()
{
    mecho "deleting statistics notification ..."

    # check for crontab file
    if [ -f ${generate_crontab} ]
    then
        # delete existing file
        rm -f ${generate_crontab}

        # update crontab file
        /var/install/config.d/cron.sh -quiet
    fi
}

#----------------------------------------------------------------------------------------
# check if type ofthe menu is new
# input : $1 - menu-name
# return:  0 - new
#          1 - old
#----------------------------------------------------------------------------------------
is_new_menutype ()
{
    menu_name="$1"

    grep -E -q "^ *<package|<title|<\!--" $install_menu_path/$menu_name
}

#----------------------------------------------------------------------------------------
# update mail modules menu
#----------------------------------------------------------------------------------------
update_modules_menu ()
{
    mail_module_menu_title="Mail Module administration"
    mail_module_menu_file=setup.services.mail.modules.menu

    mecho "updating modules menu ..."

    # create new modules menu in >= base-1.1.0 format
    rm -f $install_menu_path/$mail_module_menu_file
    ${install_bin_path}/create-menu $mail_module_menu_file "$mail_module_menu_title"

    ls $install_menu_path/setup.module*.mail.*.menu > /dev/null 2> /dev/null

    if [ $? -eq 0 ]
    then
        for FNAME in $install_menu_path/setup.module*.mail.*.menu
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

            mecho "- adding entry \"$module_name - $menu_title\" ..."
            ${install_bin_path}/add-menu -menu "$mail_module_menu_file" "`basename $FNAME`" "$menu_title"
        done
    fi

    ls $install_menu_path/setup.services.mail.modules.*.menu > /dev/null 2> /dev/null

    if [ $? -eq 0 ]
    then
        for FNAME in $install_menu_path/setup.services.mail.modules.*.menu
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

            mecho "- adding entry \"$module_name - $menu_title\" ..."
            ${install_bin_path}/add-menu -menu "$mail_module_menu_file" "`basename $FNAME`" "$menu_title"
        done
    fi
}

#----------------------------------------------------------------------------------------
# print version
#----------------------------------------------------------------------------------------
print_version ()
{
    mecho "mail version: $mail_version"
    $eximbin_path/exim -bV
}

#========================================================================================
# Main
#========================================================================================

noconfirm=''

case "$1" in
    *-noconfirm )
        noconfirm=noconfirm
        shift
        ;;

    *-getdomain|getdomain )
        # return smtp domain
        echo "${SMTP_QUALIFY_DOMAIN}"
        ;;

    *-fetchone|fetchone )
        # generate fetchmail.conf for a single account
        # function is used by "mail-tools-fetch-mail" script

        . ${generate_fetchident}

        eval 'FETCHMAIL_'$2'_FETCHALL'='yes'
        create_fetchmail_config_single "$2"
        ;;

    *-alias|alias )
        # recreate aliases file

        # check for installed and activated sn
        check_installed_sn -quiet

        SN_INSTALLED=$?

        # check for installed and activated antispam
        check_installed_antispam -quiet

        ANTISPAM_INSTALLED=$?

        create_aliases
        ;;

    *-ignorehosts|ignorehosts )
        # create ignore hosts file
        create_ignore_hosts
        ;;

    *-removecron|removecron )
        # delete cronjob
        delete_cron_job
        ;;

    *-sendstatistics|sendstatistics )
        send_exim_statistics
        ;;

    *-sendcertwarning|sendcertwarning )
        if [ "${MAIL_CERTS_WARNING}" = "yes" ]
        then
            /var/install/bin/certs-send-invalid-certs-warning --quiet \
                --emailaddr "Postmaster <postmaster@${SMTP_QUALIFY_DOMAIN}>" \
                --subject "${MAIL_CERTS_WARNING_SUBJECT}" \
                --days 20
        fi
        ;;

    *-stopmailaccess|stopmailaccess )
        if [ -f $toggle_mailaccess ]
        then
            # lock file exists
            create_xinet_pop3 noinit
            create_xinet_imap
        else
            # create new lock file
            echo "# file generated by $pgmname (`whoami`) on `date`" > $toggle_mailaccess

            create_xinet_pop3 noinit
            create_xinet_imap

            rm -f $toggle_mailaccess
        fi
        ;;

    *-togglemailaccess|togglemailaccess )
        create_xinet_pop3 noinit
        create_xinet_imap
        ;;

    *-updatemodulesmenu|updatemodulesmenu )
        update_modules_menu
        ;;

    *-updatemailpw|updatemailpw )
        create_pop3imap_passwords
        ;;

    *-version|version )
        print_version
        ;;

    * )
        # generate all configuration files
        mecho
        mecho "version: ${mail_version}"

        write_to_config_log -header

        # check for installed and activated antispam
        check_installed_antispam

        ANTISPAM_INSTALLED=$?

        # check for installed and activated eisfax
        check_installed_eisfax

        EISFAX_INSTALLED=$?

        # check for installed and activated mail2print
        check_installed_mail2print

        MAIL2PRINT_INSTALLED=$?

        # check for installed and activated mailman
        check_installed_mailman

        MAILMAN_INSTALLED=$?

        # check for installed and activated sn
        check_installed_sn

        SN_INSTALLED=$?

        # check for installed and activated mailquota
        check_installed_mailquota

        MAILQUOTA_INSTALLED=$?

        # check for installed and activated uucp
        check_installed_uucp

        UUCP_INSTALLED=$?

        # check for installed perl binary
        check_installed_perl

        PERL_INSTALLED=$?

        # check for installed and activated webmail
        check_installed_webmail

        WEBMAIL_INSTALLED=$?

        create_installed_list

        check_system_user 'exim' "${exim_uid}" "${exim_gid}" '/bin/false' '!'

        add_mail_services
        check_pop3imap_certs

        check_pop3imap_mail_access
        create_xinet_pop3 noinit
        create_xinet_imap

        create_cclient

        create_fetchmail_password
        . ${generate_fetchident}
        create_fetchmail_user

        create_pop3imap_passwords nocolor
        process_imap_mailboxes_all
        create_namespace_listfiles
        process_namespace_folders

        create_fetchmail_config_all

        check_exim_certs
        create_exim_config
        create_aliases
        create_outgoing_addresses
        create_smarthosts
        create_system_filter
        create_mailinglists

        # send statistics infomail
        if [ "$START_SMTP" = "yes" -o "$MAIL_STATISTICS_INFOMAIL" = "yes" -o "$MAIL_CERTS_WARNING" = "yes" ]
        then
            add_cron_job
        else
            delete_cron_job
        fi

        # create mailquota configuration
        if [ -f $mailquota_configfile ]
        then
            $mailquota_configfile createquota
        fi

        # check if root alias has been created
        check_root_alias

        create_logrotate
        create_mailrc
        update_modules_menu

        set_exim_access_rights

        compress_config_log

        if [ "${noconfirm}" != "noconfirm" ]
        then
            display_config_log
        fi

        mecho "finished."
        ;;
esac

#========================================================================================
# End
#========================================================================================
exit 0
