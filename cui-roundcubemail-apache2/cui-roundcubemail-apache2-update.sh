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

usage()
{
    cat <<EOF

  Usage:
  ${0} [Options]
      The file $sourceConfiguration} will be read, the configuration will
      be checked and an updated configuration file will be written.

  Optional Parameters:
    --test
      .. The file ${sourceConfiguration} will be read and a test configuration
         will be written to the file ${testroot}/etc/config.d/${generatedConfiguration}.

EOF
}

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

    key_len=24
    if [ "${ROUNDCUBE_GENERAL_DES_KEY}" = "" -o $(echo ${ROUNDCUBE_GENERAL_DES_KEY}|wc -L) -lt ${key_len} ] ; then
        # create random key
        randkey="$(rand_string ${key_len})"

        echo "- ROUNDCUBE_GENERAL_DES_KEY, '${ROUNDCUBE_GENERAL_DES_KEY}' -> '${randkey}'"
        ROUNDCUBE_GENERAL_DES_KEY="${randkey}"
    fi
}

# ----------------------------------------------------------------------------
# Add variables
# ----------------------------------------------------------------------------
add_variables ()
{
    echo "Adding new parameter(s)..."

    if [ -z "`grep ^ROUNDCUBE_CRON_SCHEDULE ${sourceConfiguration}`" ] ; then
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

        printVarIfSet "ROUNDCUBE_DO_DEBUG"              "Debug mode: yes or no"
        printVarIfSet "ROUNDCUBE_DEBUGLEVEL"            "Debug level: 1-8"

        printvar "START_ROUNDCUBE"                      "Start Roundcube client: yes or no"

        if isVariableSet "ROUNDCUBE_DB_TYPE" || isVariableSet "ROUNDCUBE_DB_USER" || isVariableSet "ROUNDCUBE_DB_PASS" ; then
            # ----------------------------------------------------------------
            printgroup "Database settings"
            # ----------------------------------------------------------------

            printVarIfSet "ROUNDCUBE_DB_TYPE"           "Database type: e.g. mysql"
            printVarIfSet "ROUNDCUBE_DB_USER"           "Database access username"
            printVarIfSet "ROUNDCUBE_DB_PASS"           "Database access pasword"
        fi

        # --------------------------------------------------------------------
        printgroup "Client settings"
        # --------------------------------------------------------------------

        printvar "ROUNDCUBE_SERVER_DOMAIN"              "Your mail domain"
        printvar "ROUNDCUBE_SERVER_DOMAIN_CHECK"        "Check domain referal: yes or no"
        echo
        printvar "ROUNDCUBE_SERVER_IMAP_HOST"           "Hostname of imap server"
        printvar "ROUNDCUBE_SERVER_IMAP_TYPE"           "Server type: uw or dovecot"
        printvar "ROUNDCUBE_SERVER_IMAP_AUTH"           "Auth type: digest, md5 or login"
        printvar "ROUNDCUBE_SERVER_IMAP_TRANSPORT"      "Transport to use: default or tls"
        printvar "ROUNDCUBE_SERVER_SMTP_HOST"           "Hostname of smtp server"
        printvar "ROUNDCUBE_SERVER_SMTP_AUTH"           "Auth type: digest, md5, login, none"
        printvar "ROUNDCUBE_SERVER_SMTP_TRANSPORT"      "Transport to use: default or tls"

        # ----------------------------------------------------------------
        printgroup "Organization settings"
        # ----------------------------------------------------------------

        printvar "ROUNDCUBE_ORGA_NAME"                  "Name of organization"
        printvar "ROUNDCUBE_ORGA_LOGO"                  "Logo path"
        printvar "ROUNDCUBE_ORGA_PROVIDER_URL"          "Provider link"
        printvar "ROUNDCUBE_ORGA_DEF_LANGUAGE"          "Default language"

        # ----------------------------------------------------------------
        printgroup "Folder settings"
        # ----------------------------------------------------------------

        printvar "ROUNDCUBE_FOLDER_MOVE_MSGS_TO_TRASH"  "Move deleted messages to trash"
        printvar "ROUNDCUBE_FOLDER_MOVE_MSGS_TO_SEND"   "Move sent messages to send folder"
        printvar "ROUNDCUBE_FOLDER_MOVE_MSGS_TO_DRAFT"  "Show move to draft folder option"
        printvar "ROUNDCUBE_FOLDER_AUTO_EXPUNGE"        "Delete source msg after move"

        if isVariableSet "ROUNDCUBE_FOLDER_FORCE_NSFOLDER" ; then
            printvar "ROUNDCUBE_FOLDER_FORCE_NSFOLDER"  "Force namespace folder display"
        fi

        # ----------------------------------------------------------------
        printgroup "General settings"
        # ----------------------------------------------------------------

        printvar "ROUNDCUBE_GENERAL_DEF_CHARSET"         "Used charset: iso-8859-1, koi8-r"
        printvar "ROUNDCUBE_GENERAL_DES_KEY"             "DES key for cookie encryption"
        printvar "ROUNDCUBE_GENERAL_ALLOW_RECEIPTS_USE"  "Allow request of receipts"
        printvar "ROUNDCUBE_GENERAL_ALLOW_IDENTITY_EDIT" "Allow editing of identity data"

        # ----------------------------------------------------------------
        printgroup "Plugins settings"
        # ----------------------------------------------------------------

        printvar "ROUNDCUBE_PLUGINS_USE_ALL"             "Yes - take all, No - take individual"
        echo
        printvar "ROUNDCUBE_PLUGINS_N"                   "Number of individual plugins"

        if [ "${ROUNDCUBE_PLUGINS_N}" = "" ] ; then
            ROUNDCUBE_PLUGINS_N=0
        fi

        if [ ${ROUNDCUBE_PLUGINS_N} -eq 0 ] ; then
            jmax=7
        else
            jmax=${ROUNDCUBE_PLUGINS_N}
        fi

        jdx=1
        while [ ${jdx} -le ${jmax} ] ; do
            printvar "ROUNDCUBE_PLUGINS_${jdx}_DIRNAME" "${jdx}. plugin"
            jdx=$(expr ${jdx} + 1)
        done

        echo

        # ----------------------------------------------------------------
        printgroup "Global address books"
        # ----------------------------------------------------------------

        printvar "ROUNDCUBE_GLOBADDR_LDAP_N"             "Number of ldap addressbooks"

        if [ ${ROUNDCUBE_GLOBADDR_LDAP_N} -eq 0 ] ; then
            jmax=1
        else
            jmax=${ROUNDCUBE_GLOBADDR_LDAP_N}
        fi

        jdx=1
        while [ ${jdx} -le ${jmax} ] ; do
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_ACTIVE"    "Activate ldap addressbook: yes or no"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_INFO"      "Description of ldap addressbook"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_HOST"      "Hostname of ldap server"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_BASEDN"    "Base-dn of ldap addressbook"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_AUTH"      "Require authentication: yes or no"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_BINDDN"    "Bind-dn for ldap authentication"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_BINDPASS"  "Bind-password for ldap authentication"
            printvar    "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_WRITEABLE" "Writable addressbook: yes or no"

            printVarIfSet "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_CHARSET" "Charset to use"
            printVarIfSet "ROUNDCUBE_GLOBADDR_LDAP_${jdx}_MAXROWS" "Maximum number of rows to read"

            jdx=$(expr ${jdx} + 1)
        done

        if isVariableSet "ROUNDCUBE_CRON_SCHEDULE" ; then
            # ------------------------------------------------------------
            printgroup "Others"
            # ------------------------------------------------------------

            printvar    "ROUNDCUBE_CRON_SCHEDULE"          "Cron configuration string"
        fi

        # ----------------------------------------------------------------
        printend
        # ----------------------------------------------------------------
    } > ${generatedConfiguration}
}

# ============================================================================
# Main
# ============================================================================
testroot=''

roundcube_path=${testroot}/usr/share/webapps/roundcube

# Set file names
vmailfile=${testroot}/etc/config.d/vmail
installfile=${testroot}/var/run/roundcube.install
roundcubefile=${testroot}/etc/config.d/roundcubemail-apache2
conf_tmpdir=${roundcube_path}

# Set defaults
sourceConfiguration=${installfile}
generatedConfiguration=${roundcubefile}

case "$1" in
    --test)
      # sourceConfiguration=${roundcubefile}.new
        sourceConfiguration=${roundcubefile}
        generatedConfiguration=${roundcubefile}.test
        ;;
    -h|--help)
    	usage
        exit 0
        ;;
	*)
		;;
esac

if [ -f ${sourceConfiguration} ] ; then
    # previous configuration file exists
    echo "Previous configuration found..."
    . ${sourceConfiguration}

    modify_variables
    add_variables

    create_config

    echo "Finished."
else
    echo "No configuration ${sourceConfiguration} found - exiting."
fi

# ============================================================================
# End
# ============================================================================
