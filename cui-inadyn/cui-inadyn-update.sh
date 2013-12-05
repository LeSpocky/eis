#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/inadyn-update.sh - paramater update script
#
# Creation   : 2011-02-12 starwarsfan
#
# Copyright (c) 2011-2013 the eisfair team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> `pwd`/inadyn-update-trace$$.log
#set -x

# Include configlib for using printvar
. /var/install/include/configlib

# Include eislib
. /var/install/include/eislib

# Set package name
packageName=inadyn

# ----------------------------------------------------------------------------
# Set the default values for configuration
START_INADYN='no'

INADYN_ACCOUNT_N=1
INADYN_ACCOUNT_1_NAME='Account 1'
INADYN_ACCOUNT_1_ACTIVE='yes'
INADYN_ACCOUNT_1_SYSTEM='dynamic'
INADYN_ACCOUNT_1_IP_SERVER='checkip.two-dns.de'
INADYN_ACCOUNT_1_USER=''
INADYN_ACCOUNT_1_PASSWORD=''
INADYN_ACCOUNT_1_ALIAS_N=1
INADYN_ACCOUNT_1_ALIAS_1='test.homeip.net'
INADYN_ACCOUNT_1_UPDATE_INTERVAL='600'
INADYN_ACCOUNT_1_MAIL_ON_UPDATE='no'
INADYN_ACCOUNT_1_MAIL_TO='root'
INADYN_ACCOUNT_1_LOGFILE=''
INADYN_ACCOUNT_1_LOG_LEVEL='0'


# ----------------------------------------------------------------------------
# Read old configuration and rename old variables
renameOldVariables()
{
    # read old values
    if [ -f /etc/config.d/${packageName} ] ; then
        . /etc/config.d/${packageName}
    fi
}

# ----------------------------------------------------------------------------
# Write config and default files
makeConfigFile()
{
    internal_conf_file=${1}
    {
    # ------------------------------------------------------------------------
    printgpl -conf ${packageName} '2011-02-12' 'starwarsfan'
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    printgroup "Basic configuration"
    # ------------------------------------------------------------------------
    printvar 'START_INADYN' 'Use: yes or no'

    printvar 'INADYN_ACCOUNT_N' ''

    idx=1
    while [ "${idx}" -le "${INADYN_ACCOUNT_N}" ] ; do
        printvar "INADYN_ACCOUNT_${idx}_NAME"            "Just a name for the account, used on status mail"
        printvar "INADYN_ACCOUNT_${idx}_ACTIVE"          "Is this account active or not"
        printvar "INADYN_ACCOUNT_${idx}_SYSTEM"          "dynamic, static, custom, zoneedit or no-ip"
        printvar "INADYN_ACCOUNT_${idx}_IP_SERVER"       "checkip.two-dns.de, checkip.dyndns.com or something like that"
        printvar "INADYN_ACCOUNT_${idx}_USER"            ""
        printvar "INADYN_ACCOUNT_${idx}_PASSWORD"        ""
        printvar "INADYN_ACCOUNT_${idx}_ALIAS_N"         ""

        eval aliasAmount='${INADYN_ACCOUNT_'${idx}'_ALIAS_N}'
        aliasAmount=${aliasAmount:-0} # Set to 0 if empty

        idx2=1
        while [ "${idx2}" -le "${aliasAmount}" ] ; do
            printvar "INADYN_ACCOUNT_${idx}_ALIAS_${idx2}" "test.homeip.net"
            idx2=$((idx2+1))
        done

        printvar "INADYN_ACCOUNT_${idx}_UPDATE_INTERVAL" "Interval to check for changed IP"
        printvar "INADYN_ACCOUNT_${idx}_MAIL_ON_UPDATE"  "Send mail if IP was updated"
        printvar "INADYN_ACCOUNT_${idx}_MAIL_TO"         "Mail recipient"
        printvar "INADYN_ACCOUNT_${idx}_LOGFILE"         "Path and name of logfile. If empty, log to syslog"
        printvar "INADYN_ACCOUNT_${idx}_LOG_LEVEL"       "0=standard ... 5=debug"

        idx=$((idx+1))
    done

    # ------------------------------------------------------------------------
    printend
    # ------------------------------------------------------------------------

    } > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Create the check.d file
makeCheckFile()
{
    printgpl -check ${packageName} '2011-02-12' 'starwarsfan' >/etc/check.d/${packageName}
    cat >> /etc/check.d/${packageName} <<EOFG
# Variable                         OPT_VARIABLE                      VARIABLE_N                 VALUE
START_INADYN                       -                                 -                          YESNO

INADYN_ACCOUNT_N                   START_INADYN                      -                          NUMERIC
INADYN_ACCOUNT_%_NAME              START_INADYN                      INADYN_ACCOUNT_N           NOTEMPTY
INADYN_ACCOUNT_%_ACTIVE            START_INADYN                      INADYN_ACCOUNT_N           YESNO
INADYN_ACCOUNT_%_SYSTEM            INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           INADYN_SYSTEM_CUI
INADYN_ACCOUNT_%_IP_SERVER         INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           INADYN_IP_SERVER
INADYN_ACCOUNT_%_USER              INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           NOTEMPTY
INADYN_ACCOUNT_%_PASSWORD          INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           PASSWD
INADYN_ACCOUNT_%_ALIAS_N           INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           NUMERIC
INADYN_ACCOUNT_%_ALIAS_%           INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_%_ALIAS_N   INADYN_ALIAS
INADYN_ACCOUNT_%_UPDATE_INTERVAL   INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           NUMERIC
INADYN_ACCOUNT_%_MAIL_ON_UPDATE    INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           YESNO
INADYN_ACCOUNT_%_MAIL_TO           INADYN_ACCOUNT_%_MAIL_ON_UPDATE   INADYN_ACCOUNT_N           NOTEMPTY
INADYN_ACCOUNT_%_LOGFILE           INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           E_ABS_PATH
INADYN_ACCOUNT_%_LOG_LEVEL         INADYN_ACCOUNT_%_ACTIVE           INADYN_ACCOUNT_N           INADYN_DEBUGLEVEL_CUI

EOFG

    # Set rights for check.d file
    chmod 0600 /etc/check.d/${packageName}
    chown root /etc/check.d/${packageName}

    printgpl -check_exp ${packageName} '2011-02-12' 'starwarsfan' >/etc/check.d/${packageName}.exp
    cat >> /etc/check.d/${packageName}.exp <<EOFG

INADYN_SYSTEM_CUI     = 'dynamic|static|custom|zoneedit|no-ip|changeip'
                      : 'One of the values "dynamic", "static", "custom", "zoneedit", "no-ip" or "changeip" must be used'

INADYN_ALIAS          = '(RE:FQDN)|[1-5]'
                      : 'Only a full qualified domain name or numbers from 1-5 are supportet!'

INADYN_IP_SERVER      = '(RE:FQDN)|(RE:IPADDR)'
                      : 'Only a full qualified domain name or an IP is supportet!'

INADYN_DEBUGLEVEL_CUI = '0|1|2|3|4|5'
                      : 'Debug level must be 0..5 where 0 = Std output and 5 = max debug output'

EOFG

    # Set rights for check.exp file
    chmod 0600 /etc/check.d/${packageName}.exp
    chown root /etc/check.d/${packageName}.exp

    printgpl -check_ext ${packageName} '2011-07-13' 'starwarsfan' >/etc/check.d/${packageName}.ext
    cat >> /etc/check.d/${packageName}.ext <<EOFG

set mail_used = "no"

foreach i in inadyn_account_n ; do
    if (inadyn_account_%_active[i] == "yes") ; then
        if (inadyn_account_%_mail_on_update[i] == "yes") ; then
            set mail_used = "yes"
        fi
    fi
done


if ( mail_used == "yes" ) ; then
    stat ("/var/install/packages/mail", test)
    if ("\$test_res" != "OK") ; then
        stat ("/var/install/packages/vmail", test)
        if ("\$test_res" != "OK") ; then
            stat ("/var/install/packages/ssmtp", test)
            if ("\$test_res" != "OK") ; then
                error "A mail package is required to enable sending status mails on update!"
            fi
        fi
    fi
fi
EOFG

    # Set rights for check.ext file
    chmod 0600 /etc/check.d/${packageName}.ext
    chown root /etc/check.d/${packageName}.ext
}



# ----------------------------------------------------------------------------
# Main
mecho ''
if [ -f /etc/config.d/${packageName} ] ; then
    mecho --info -n 'Updating configuration.'
else
    mecho --info -n 'Creating configuration.'
fi

makeConfigFile /etc/default.d/${packageName}

# Update from old version
mecho --info -n '.'
renameOldVariables

# Write new config file
mecho --info -n '.'
makeConfigFile /etc/config.d/${packageName}

# Write check.d file
mecho --info -n '.'
makeCheckFile

mecho ''
mecho --ok

exit 0
