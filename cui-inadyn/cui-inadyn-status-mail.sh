#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/bin/inadyn-status-mail.sh - send status mail
#
# Creation:     2011-07-18 starwarsfan
#
# Copyright (c) 2011-2013 The eisfair Team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#exec 2> `pwd`/inadyn-status-mail-trace$$.log
#set -x

# Set package name
packageName=inadyn

# Source files
. /etc/config.d/base
. /var/install/include/eislib

if [ -f "/var/install/packages/mail" -o -f "/var/install/packages/vmail" -o -f "/var/install/packages/ssmtp" ]
then
    inadynMailTo=$1
    shift
    inadynAccountNumber=$1
    shift
    inadynAccountType=$1
    shift
    inadynAccountName=$*
    {
        echo "From: Mailer-Daemon <${HOSTNAME}@${DOMAIN_NAME}>"
        echo "To: ${inadynMailTo}"
        echo "Subject: Inadyn updated account $inadynAccountName"
        echo
        echo "Account $inadynAccountNumber:"
        echo "Name: $inadynAccountName"
        echo "Type: $inadynAccountType"
        echo "Update time: `date +\"%b %d %T %Y %Z\"`"
        if [ -f /tmp/inadyn_cache/inadyn_ip.cache ]
        then
            currentIp=`cut -d " " -f1 /tmp/inadyn_cache/inadyn_ip.cache`
            echo "Current IP: $currentIp"
        fi
        echo
    } > /tmp/inadyn-update-$$.txt

    cat /tmp/inadyn-update-$$.txt | /usr/lib/sendmail ${inadynMailTo}
    rm -f /tmp/inadyn-update-$$.txt
else
    mecho --error "A mail package is required to let inadyn send status mails!"
    exit 1
fi
exit 0
