#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/roundcubemail-apache2-update.sh 
# - Update or generate new roundcube configuration
#
# Copyright (c) 2012-2016 The Eisfair Team, team(at)eisfair(dot)org
# Creation:    2012-12-20 jed
# ----------------------------------------------------------------------------

# read eislib etc.
. /var/install/include/configlib
. /var/install/include/eislib

#exec 2>./roundcubemail-apache2-update-trace-$$.log
#set -x

# ----------------------------------------------------------------------------
# input:  $1 - variable name
# return:  0 - variable set
#          1 - variable not set
# ----------------------------------------------------------------------------
isVariableSet ()
{
    eval _var1=\$"${1}"
    eval _var2=\$"{${1}+EMPTY}"

    if [ -z "${_var1}" ] ; then
        if [ "${_var2}" = "EMPTY" ] ; then
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

# ----------------------------------------------------------------------------
# Print variable only if it has been set
# $1 - variable name
# $2 - comment
# ----------------------------------------------------------------------------
printVarIfSet ()
{
    if isVariableSet "${1}" ; then
        printvar "${1}" "${2}"
    fi
}

# ----------------------------------------------------------------------------
# Modify variables
# ----------------------------------------------------------------------------
modify_variables ()
{
    echo "Modifying parameter(s)..."

    if [ ${ROUNDCUBE_N} -le 1 ] ; then
        imax=1
    else
        imax=${ROUNDCUBE_N}
    fi

    idx=1
    while [ ${idx} -le ${imax} ] ; do
        eval des_key='$ROUNDCUBE_'${idx}'_GENERAL_DES_KEY'

        key_len=24
        if [ "${des_key}" = "" -o $(echo ${des_key}|wc -L) -lt ${key_len} ] ; then
            # create random key
            randkey="`rand_string ${key_len}`"

            echo "- ROUNDCUBE_${idx}_GENERAL_DES_KEY, '${des_key}' -> '${randkey}'"
            eval "ROUNDCUBE_${idx}_GENERAL_DES_KEY='${randkey}'"
        fi

        idx=$(expr ${idx} + 1)
    done
}

# ----------------------------------------------------------------------------
# Add variables
# ----------------------------------------------------------------------------
add_variables ()
{
    echo "Adding new parameter(s)..."

    if [ -z "`grep ^ROUNDCUBE_CRON_SCHEDULE ${source_conf}`" ] ; then
        echo "- ROUNDCUBE_CRON_SCHEDULE='14 1 * * *'"
        ROUNDCUBE_CRON_SCHEDULE='14 1 * * *'
    fi
}

# ----------------------------------------------------------------------------
# Create new configuration
# ----------------------------------------------------------------------------
create_config ()
{
    echo "Updating/creating configuration..."
    {
        # --------------------------------------------------------------------
        printgpl "roundcubemail" "2016-10-26" "starwarsfan" "Copyright (c) 2001-`date +\"%Y\"` The eisfair Team, team(at)eisfair(dot)org"
        # --------------------------------------------------------------------
        printgroup "Start settings"
        # --------------------------------------------------------------------

        printVarIfSet "ROUNDCUBE_DO_DEBUG"   "debug mode: yes or no"
        printVarIfSet "ROUNDCUBE_DEBUGLEVEL" "debug level: 1-8"

        printvar    "START_ROUNDCUBE"      "start Roundcube client: yes or no"

        if isVariableSet "ROUNDCUBE_DB_TYPE" || isVariableSet "ROUNDCUBE_DB_USER" || isVariableSet "ROUNDCUBE_DB_PASS" ; then
            # ----------------------------------------------------------------
            printgroup "Database settings"
            # ----------------------------------------------------------------

            printVarIfSet "ROUNDCUBE_DB_TYPE"            "database type: e.g. mysql"
            printVarIfSet "ROUNDCUBE_DB_USER"            "database access username"
            printVarIfSet "ROUNDCUBE_DB_PASS"            "database access pasword"
        fi

        # --------------------------------------------------------------------
        printgroup "Client settings"
        # --------------------------------------------------------------------

        printvar "ROUNDCUBE_N"                      "number of webmail instances"
        echo

        if [ ${ROUNDCUBE_N} -eq 0 ] ; then
            imax=1
        else
            imax=${ROUNDCUBE_N}
        fi

        idx=1
        while [ ${idx} -le ${imax} ] ; do
            printvar "ROUNDCUBE_${idx}_ACTIVE"                 "${idx}. activate: yes or no"
            printvar "ROUNDCUBE_${idx}_DOCUMENT_ROOT"          "   document root"
            printvar "ROUNDCUBE_${idx}_SERVER_DOMAIN"          "   your mail domain"
            printvar "ROUNDCUBE_${idx}_SERVER_DOMAIN_CHECK"    "   check domain referal: yes or no"
            echo
            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_HOST"       "   hostname of imap server"

            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_TYPE"       "   server type: uw or dovecot"

            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_AUTH"       "   auth type: digest, md5 or login"
            printvar "ROUNDCUBE_${idx}_SERVER_IMAP_TRANSPORT"  "   transport to use: default or tls"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_HOST"       "   hostname of smtp server"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_AUTH"       "   auth type: digest, md5, login, none"
            printvar "ROUNDCUBE_${idx}_SERVER_SMTP_TRANSPORT"  "   transport to use: default or tls"

            # ----------------------------------------------------------------
            printgroup "Organization settings"
            # ----------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_ORGA_NAME"              "${idx}. name of organization"
            printvar "ROUNDCUBE_${idx}_ORGA_LOGO"              "   logo path"
            printvar "ROUNDCUBE_${idx}_ORGA_PROVIDER_URL"      "   provider link"
            printvar "ROUNDCUBE_${idx}_ORGA_DEF_LANGUAGE"      "   default language"

            # ----------------------------------------------------------------
            printgroup "Folder settings"
            # ----------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_TRASH" "${idx}. move deleted messages to trash"
            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_SEND"  "   move sent messages to send folder"
            printvar "ROUNDCUBE_${idx}_FOLDER_MOVE_MSGS_TO_DRAFT" "   show move to draft folder option"
            printvar "ROUNDCUBE_${idx}_FOLDER_AUTO_EXPUNGE"       "   delete source msg after move"

            if isVariableSet "ROUNDCUBE_${idx}_FOLDER_FORCE_NSFOLDER"
            then
                printVarIfSet "ROUNDCUBE_${idx}_FOLDER_FORCE_NSFOLDER"  "   force namespace folder display"
            fi

            # ----------------------------------------------------------------
            printgroup "General settings"
            # ----------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_GENERAL_DEF_CHARSET"         "${idx}. used charset: iso-8859-1, koi8-r"
            printvar "ROUNDCUBE_${idx}_GENERAL_DES_KEY"             "   DES key for cookie encryption"
            printvar "ROUNDCUBE_${idx}_GENERAL_ALLOW_RECEIPTS_USE"  "   allow request of receipts"
            printvar "ROUNDCUBE_${idx}_GENERAL_ALLOW_IDENTITY_EDIT" "   allow editing of identity data"

            # ----------------------------------------------------------------
            printgroup "Plugins settings"
            # ----------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_PLUGINS_USE_ALL"             "${idx}. yes - take all, no - take individual"
            echo
            printvar "ROUNDCUBE_${idx}_PLUGINS_N"                   "   number of individual plugins"

            eval plugins_n='$ROUNDCUBE_'${idx}'_PLUGINS_N'

            if [ "${plugins_n}" = "" ] ; then
                plugins_n=0
            fi

            if [ ${plugins_n} -eq 0 ] ; then
                jmax=7
            else
                jmax=${plugins_n}
            fi

            jdx=1
            while [ ${jdx} -le ${jmax} ] ; do
                printvar "ROUNDCUBE_${idx}_PLUGINS_${jdx}_DIRNAME" "${jdx}. plugin"
                jdx=$(expr ${jdx} + 1)
            done

            echo

            # ----------------------------------------------------------------
            printgroup "Global address books"
            # ----------------------------------------------------------------

            printvar "ROUNDCUBE_${idx}_GLOBADDR_LDAP_N"             "${idx}. number of ldap addressbooks"

            eval globldap_n='$ROUNDCUBE_'${idx}'_GLOBADDR_LDAP_N'

            if [ ${globldap_n} -eq 0 ] ; then
                jmax=1
            else
                jmax=${globldap_n}
            fi

            jdx=1
            while [ ${jdx} -le ${jmax} ] ; do
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_ACTIVE"    "   ${jdx}. activate ldap addressbook: yes or no"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_INFO"      "      description of ldap addressbook"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_HOST"      "      hostname of ldap server"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BASEDN"    "      base-dn of ldap addressbook"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_AUTH"      "      require authentication: yes or no"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BINDDN"    "      bind-dn for ldap authentication"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_BINDPASS"  "      bind-password for ldap authentication"
                printvar    "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_WRITEABLE" "      writable addressbook: yes or no"

                printVarIfSet "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_CHARSET"   "      charset to use"
                printVarIfSet "ROUNDCUBE_${idx}_GLOBADDR_LDAP_${jdx}_MAXROWS"   "      maximum number of rows to read"

                jdx=$(expr ${jdx} + 1)
            done

            if isVariableSet "ROUNDCUBE_CRON_SCHEDULE" ; then
                # ------------------------------------------------------------
                printgroup "Others"
                # ------------------------------------------------------------

                printvar    "ROUNDCUBE_CRON_SCHEDULE"          "cron configuration string"
            fi

            # ----------------------------------------------------------------
            printend
            # ----------------------------------------------------------------

            idx=$(expr ${idx} + 1)
        done
    } > ${generate_conf}
}

# ============================================================================
# Main
# ============================================================================
testroot=''

roundcube_path=${testroot}/usr/.../roundcube

### set file names ###
vmailfile=${testroot}/etc/config.d/vmail
installfile=${testroot}/var/run/roundcube.install
roundcubefile=${testroot}/etc/config.d/roundcubemail-apache2
conf_tmpdir=${roundcube_path}

# setting defaults
source_conf=${installfile}
generate_conf=${roundcubefile}

case "$1" in
    update)
        ;;
    test)
      # source_conf=${roundcubefile}.new
        source_conf=${roundcubefile}

        generate_conf=${roundcubefile}.test
        ;;
    *)
        echo
        echo "Use one of the following options:"
        echo
        echo "  roundcube-update.sh [test]   - the file ${source_conf} will be read and a test configuration"
        echo "                                 will be written to the file ${testroot}/etc/config.d/${generate_conf}."
        echo
        echo "  roundcube-update.sh [update] - the file $source_conf} will be read, the configuration will"
        echo "                                 be checked and an updated configuration file will be written."
        echo
        exit 0
        ;;
esac

if [ -f ${source_conf} ] ; then
    # previous configuration file exists
    echo "Previous configuration found..."
    . ${source_conf}

    modify_variables
    add_variables

    create_config

    echo "Finished."
else
    echo "No configuration ${source_conf} found - exiting."
fi

# ============================================================================
# End
# ============================================================================
