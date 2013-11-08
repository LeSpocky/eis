#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration parameter update script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

# name of the current package
# ---------------------------
packages_name=ssmtp

# include libs for using
# ----------------------
. /var/install/include/configlib     # configlib from eisfair

### -------------------------------------------------------------------------
### read old configuration and rename old variables
### -------------------------------------------------------------------------
# set the defaults from default.d file
. /etc/default.d/${packages_name}

. /etc/config.d/${packages_name}


### -------------------------------------------------------------------------
### Write the new config
### -------------------------------------------------------------------------
(
    #------------------------------------------------------------------------
    printgpl "$packages_name" "2006-07-31" "team" "2008-2013 team <team@eisfair.org>"

    #------------------------------------------------------------------------------
    printgroup "general settings"
    #------------------------------------------------------------------------------

    printvar "START_SSMTP"            "activate configuration: yes or no"

    printvar "SSMTP_FORWARD_TO"       "receiver of all mails send via ssmtp"
    printvar "SSMTP_MAILHUB"          "host to send mail to"
    printsetvar "SSMTP_MAILHUB_PORT"  "port to connect to"
    printsetvar "SSMTP_HOSTNAME"      "a full qualified hostname or empty"

    printvar "SSMTP_USE_AUTH"         "activate authentication: yes or no"
    printvar "SSMTP_AUTH_USER"        "user name used for authentication"
    printvar "SSMTP_AUTH_PASS"        "password used for authentication"
    printvar "SSMTP_AUTH_METHOD"      "athentication method: plain or cram-md5"

    printvar "SSMTP_USE_TLS"          "secure connection: no, tls or starttls"
    printvar "SSMTP_USE_TLS_CERT"     "use cert to authenticate: yes or no"

    printvar "SSMTP_OUTGOING_N"       "number of outgoing alias definitions"

    if [ ${SSMTP_OUTGOING_N} -eq 0 ]
    then
        max_idx=1
    else
        max_idx=${SSMTP_OUTGOING_N}
    fi

    idx=1
    while [ ${idx} -le ${max_idx} ]
    do
        printvar "SSMTP_OUTGOING_${idx}_USER"            "${idx}. local username"
        printvar "SSMTP_OUTGOING_${idx}_EMAIL"           "   outgoing email address"
        printsetvar "SSMTP_OUTGOING_${idx}_MAILHUB"      "   host to send mail to"
        printsetvar "SSMTP_OUTGOING_${idx}_MAILHUB_PORT" "   port to connect to"
        idx=`expr ${idx} + 1`
    done

    if [ "${SSMTP_DO_DEBUG}" = "yes" -o "${SSMTP_DO_DEBUG}" = "no" ]
    then
        # debug active
         printvar "SSMTP_DO_DEBUG" "debug mode: yes or no"
    else
        # debug parameter exists but not active
        [ -n "`grep SSMTP_DO_DEBUG /etc/config.d/${packages_name}`" ] && echo "# SSMTP_DO_DEBUG='yes'                # debug mode: yes or no"
    fi

) > /etc/config.d/${packages_name}
# Set rights
chmod 0644  /etc/config.d/${packages_name}
chown root  /etc/config.d/${packages_name}

exit 0
