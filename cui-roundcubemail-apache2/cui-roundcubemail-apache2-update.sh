#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/config.d/roundcube-update.sh - update or generate new roundcube configuration
#
# Copyright (c) 2012-2014 The Eisfair Team, team(at)eisfair(dot)org
#
# Creation:    2012-12-20 jed
# Last Update: $Id: roundcube-update.sh 35318 2014-03-27 16:01:25Z jed $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

# read eislib etc.
. /var/install/include/configlib
. /var/install/include/check-eisfair-version
. /var/install/include/eislib
. /var/install/include/jedlib

#exec 2>./roundcube-trace-$$.log
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

#----------------------------------------------------------------------------------------
# check if mail has been enabled
#----------------------------------------------------------------------------------------
check_installed_mail ()
{
    retval=1

    if [ -f ${mailfile} ]
    then
        # mail installed
        . ${mailfile}

        if [ "${START_MAIL}" = "yes" ]
        then
            # mail activated
            if [ "${1}" != "-quiet" ]
            then
                mecho "mail has been enabled ..."
            fi
            retval=0
        else
            # mail deactivated
            if [ "${1}" != "-quiet" ]
            then
                mecho --warn "mail has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------------
# check if vmail has been enabled
#----------------------------------------------------------------------------------------
check_installed_vmail ()
{
    retval=1

    if [ -f ${vmailfile} ]
    then
        # mail installed
        . ${vmailfile}

        if [ "${START_VMAIL}" = "yes" ]
        then
            # vmail activated
            if [ "${1}" != "-quiet" ]
            then
                mecho "vmail has been enabled ..."
            fi
            retval=0
        else
            # vmail deactivated
            if [ "${1}" != "-quiet" ]
            then
                mecho --warn "vmail has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

#------------------------------------------------------------------------------
# rename variables
#------------------------------------------------------------------------------
rename_variables ()
{
    renamed=0
    mecho "renaming parameter(s) ..."

    if [ ${renamed} -eq 1 ]
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
    mecho "modifying parameter(s) ..."

    if [ ${ROUNDCUBE_N} -le 1 ]
    then
        imax=1
    else
        imax=${ROUNDCUBE_N}
    fi

    idx=1
    while [ ${idx} -le ${imax} ]
    do
        eval des_key='$ROUNDCUBE_'${idx}'_GENERAL_DES_KEY'

        key_len=24
        if [ "${des_key}" = "" -o `echo ${des_key}|wc -L` -lt ${key_len} ]
        then
            # create random key
            randkey="`rand_string ${key_len}`"

            mecho "- ROUNDCUBE_${idx}_GENERAL_DES_KEY, '${des_key}' -> '${randkey}'"
            eval "ROUNDCUBE_${idx}_GENERAL_DES_KEY='${randkey}'"
            modified=1
        fi

        idx=`expr ${idx} + 1`
    done

    if [ ${modified} -eq 1 ]
    then
        mecho --info "... read documentation for modified parameter(s)!"
        anykey
    fi
}

#------------------------------------------------------------------------------
# add variables
#------------------------------------------------------------------------------
pre_add_variables ()
{
    added=0
    mecho "pre-adding new parameter(s) ..."

    if [ ${added} -eq 1 ]
    then
        mecho --info "... read documentation for new parameter(s)!"
        anykey
    fi
}

#------------------------------------------------------------------------------
# add variables
#------------------------------------------------------------------------------
add_variables ()
{
    added=0
    mecho "adding new parameter(s) ..."

    # ROUNDCUBE_CRON_SCHEDULE
    # 0.90.3
    if [ -z "`grep ^ROUNDCUBE_CRON_SCHEDULE ${source_conf}`" ]
    then
        mecho "- ROUNDCUBE_CRON_SCHEDULE='14 1 * * *'"
        ROUNDCUBE_CRON_SCHEDULE='14 1 * * *'
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
    mecho "deleting old parameters ..."

    if [ ${deleted} -eq 1 ]
    then
        anykey
    fi
}

#------------------------------------------------------------------------------
# create new configuration
#------------------------------------------------------------------------------
create_config ()
{
    mecho "updating/creating configuration ..."
    {
        #------------------------------------------------------------------------------
        printgpl "roundcube" "2012-12-20" "jed" "Copyright (c) 2001-`date +\"%Y\"` The Eisfair Team, team(at)eisfair(dot)org"
        #------------------------------------------------------------------------------
        printgroup "start settings"
        #------------------------------------------------------------------------------

        printsetvar "ROUNDCUBE_DO_DEBUG"   "debug mode: yes or no"
        printsetvar "ROUNDCUBE_DEBUGLEVEL" "debug level: 1-8"

        printvar    "START_ROUNDCUBE"      "start Roundcube client: yes or no"

        if variable_set "ROUNDCUBE_DB_TYPE" || variable_set "ROUNDCUBE_DB_USER" || variable_set "ROUNDCUBE_DB_PASS"
        then
            #--------------------------------------------------------------------------
            printgroup "database settings"
            #--------------------------------------------------------------------------

            printsetvar "ROUNDCUBE_DB_TYPE"            "database type: e.g. mysql"
            printsetvar "ROUNDCUBE_DB_USER"            "database access username"
            printsetvar "ROUNDCUBE_DB_PASS"            "database access pasword"
        fi

        #------------------------------------------------------------------------------
        printgroup "client settings"
        #------------------------------------------------------------------------------

        printvar "ROUNDCUBE_N"                      "number of webmail instances"
        echo

        if [ ${ROUNDCUBE_N} -eq 0 ]
        then
            imax=1
        else
            imax=${ROUNDCUBE_N}
        fi

        idx=1
        while [ ${idx} -le ${imax} ]
        do
            printvar "ROUNDCUBE_${idx}_ACTIVE"                 "${idx}. activate: yes or no"
            printvar "ROUNDCUBE_${idx}_DOCUMENT_ROOT"          "   document root"
            printvar "ROUNDCUBE_${idx}_SERVER_DOMAIN"          "   your mail domain"
            printvar "ROUNDCUBE_${idx}_SERVER_DOMAIN_CHECK"    "   check domain referal: yes or no"
            echo
            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_HOST"       "   hostname of imap server"

            # set platform specific parameters
            case ${EISFAIR_SYSTEM} in
                eisfair-1)
                    # eisfair-1
                    printvar "ROUNDCUBE_${idx}_SERVER_IMAP_TYPE"       "   server type: uw or courier"
                    ;;
                *)
                    # default to eisfair-2/eisxen-1
                    printvar "ROUNDCUBE_${idx}_SERVER_IMAP_TYPE"       "   server type: uw or dovecot"
                    ;;
            esac

            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_AUTH"       "   auth type: digest, md5 or login"
            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_TRANSPORT"  "   transport to use: default or tls"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_HOST"       "   hostname of smtp server"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_AUTH"       "   auth type: digest, md5, login, none"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_TRANSPORT"  "   transport to use: default or tls"

            #------------------------------------------------------------------------------
            printgroup "organization settings"
            #------------------------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_ORGA_NAME"              "${idx}. name of organization"
            printvar "ROUNDCUBE_${idx}_ORGA_LOGO"              "   logo path"
            printvar "ROUNDCUBE_${idx}_ORGA_PROVIDER_URL"      "   provider link"
            printvar "ROUNDCUBE_${idx}_ORGA_DEF_LANGUAGE"      "   default language"

            #------------------------------------------------------------------------------
            printgroup "folder settings"
            #------------------------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_TRASH" "${idx}. move deleted messages to trash"
            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_SEND"  "   move sent messages to send folder"
            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_DRAFT" "   show move to draft folder option"
            printvar "ROUNDCUBE_${idx}_FOLDER_AUTO_EXPUNGE"       "   delete source msg after move"

            if variable_set "ROUNDCUBE_${idx}_FOLDER_FORCE_NSFOLDER"
            then
                printsetvar "ROUNDCUBE_${idx}_FOLDER_FORCE_NSFOLDER"  "   force namespace folder display"
            fi

            #------------------------------------------------------------------------------
            printgroup "general settings"
            #------------------------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_GENERAL_DEF_CHARSET"         "${idx}. used charset: iso-8859-1, koi8-r"
            printvar "ROUNDCUBE_${idx}_GENERAL_DES_KEY"             "   DES key for cookie encryption"
            printvar "ROUNDCUBE_${idx}_GENERAL_ALLOW_RECEIPTS_USE"  "   allow request of receipts"
            printvar "ROUNDCUBE_${idx}_GENERAL_ALLOW_IDENTITY_EDIT" "   allow editing of identity data"

            #------------------------------------------------------------------------------
            printgroup "plugins settings"
            #------------------------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_PLUGINS_USE_ALL"             "${idx}. yes - take all, no - take individual"
            echo
            printvar "ROUNDCUBE_${idx}_PLUGINS_N"                   "   number of individual plugins"

            eval plugins_n='$ROUNDCUBE_'${idx}'_PLUGINS_N'

            if [ "${plugins_n}" = "" ]
            then
                plugins_n=0
            fi

            if [ ${plugins_n} -eq 0 ]
            then
                jmax=7
            else
                jmax=${plugins_n}
            fi

            jdx=1
            while [ ${jdx} -le ${jmax} ]
            do
                printvar "ROUNDCUBE_${idx}_PLUGINS_${jdx}_DIRNAME" "${jdx}. plugin"
                jdx=`expr ${jdx} + 1`
            done

            echo

            #------------------------------------------------------------------------------
            printgroup "global address books"
            #------------------------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_GLOBADDR_LDAP_N"             "${idx}. number of ldap addressbooks"

            eval globldap_n='$ROUNDCUBE_'${idx}'_GLOBADDR_LDAP_N'

            if [ ${globldap_n} -eq 0 ]
            then
                jmax=1
            else
                jmax=${globldap_n}
            fi

            jdx=1
            while [ ${jdx} -le ${jmax} ]
            do
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_ACTIVE"    "   ${jdx}. activate ldap addressbook: yes or no"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_INFO"      "      description of ldap addressbook"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_HOST"      "      hostname of ldap server"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BASEDN"    "      base-dn of ldap addressbook"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_AUTH"      "      require authentication: yes or no"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BINDDN"    "      bind-dn for ldap authentication"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BINDPASS"  "      bind-password for ldap authentication"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_WRITEABLE" "      writable addressbook: yes or no"

                printsetvar "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_CHARSET"   "      charset to use"
                printsetvar "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_MAXROWS"   "      maximum number of rows to read"

                jdx=`expr $jdx + 1`
            done

            if variable_set "ROUNDCUBE_CRON_SCHEDULE"
            then
                #--------------------------------------------------------------------------
                printgroup "others"
                #--------------------------------------------------------------------------

                printsetvar "ROUNDCUBE_CRON_SCHEDULE"          "cron configuration string"
            fi

            #------------------------------------------------------------------------------
            printend
            #------------------------------------------------------------------------------

            idx=`expr ${idx} + 1`
        done
    } > ${generate_conf}
}

#==============================================================================
# main
#==============================================================================

#testroot=/soft/jedroundcube
 testroot=''

# set platform specific parameters
case ${EISFAIR_SYSTEM} in
    eisfair-1)
        # eisfair-1
        roundcube_path=${testroot}/var/roundcube
        ;;
    *)
        # default to eisfair-2/eisxen-1
        roundcube_path=${testroot}/data/packages/roundcube
        ;;
esac

### set file names ###
mailfile=${testroot}/etc/config.d/mail
vmailfile=${testroot}/etc/config.d/vmail
installfile=${testroot}/var/run/roundcube.install
roundcubefile=${testroot}/etc/config.d/roundcube
conf_tmpdir=${roundcube_path}

# setting defaults
source_conf=${installfile}
generate_conf=${roundcubefile}

goflag=0

if check_installed_mail -quiet
then
    # mail
    MAIL_INSTALLED='mail'
elif check_installed_vmail -quiet
then
    # vmail
    MAIL_INSTALLED='vmail'
else
    # no local mail or vmail package installed
    MAIL_INSTALLED='none'
fi

case "$1"
in
    update)
        goflag=1
        ;;

    test)
      # source_conf=${roundcubefile}.new
        source_conf=${roundcubefile}

        generate_conf=${roundcubefile}.test
        goflag=1
        ;;

    *)
        mecho
        mecho "Use one of the following options:"
        mecho
        mecho "  roundcube-update.sh [test]   - the file ${source_conf} will be read and a test configuration"
        mecho "                                 will be written to the file ${testroot}/etc/config.d/${generate_conf}."
        mecho
        mecho "  roundcube-update.sh [update] - the file $source_conf} will be read, the configuration will"
        mecho "                                 be checked and an updated configuration file will be written."
        mecho
        goflag=0
        ;;
esac

if [ ${goflag} -eq 1 ]
then
    if [ -f ${source_conf} ]
    then
        # previous configuration file exists
        mecho "previous configuration found ..."
        . ${source_conf}

        pre_add_variables
        rename_variables
        modify_variables
        add_variables
        delete_variables

        create_config

        mecho "finished."
    else
        mecho --error "no configuration ${source_conf} found - exiting."
    fi
fi

#==============================================================================
# end
#==============================================================================
