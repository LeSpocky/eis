#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-inadyn.sh - INADYN configuration
#
# Creation:    2008-03-03 rh
#
# Copyright (c) 2008-2010 Rene Hanke, hanker(at)rpg-domain(dot)de
# Copyright (c) 2011-2013 the eisfair team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the F$inadyn_activeoundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> `pwd`/inadyn-trace$$.log
#set -x

# ----------------------------------------------------------------------------
# Include eislib
. /var/install/include/eislib

# Include config
. /etc/config.d/inadyn

# Set package name
packageName=inadyn


# ----------------------------------------------------------------------------
# Create inadyn configuration file
createInadynConfiguration()
{
    # Delete old configuration files if existing
    rm -rf /etc/inadyn/inadyn*.conf
    rm -rf /etc/logrotate.d/inadyn*

    idx=1
    while [ ${idx} -le ${INADYN_ACCOUNT_N} ] ; do
        # Naming of config file
        eval inadyn_configfile='/etc/inadyn/inadyn'${idx}'.conf'

        eval inadyn_account_name='$INADYN_ACCOUNT_'${idx}'_NAME'
        eval inadyn_active='$INADYN_ACCOUNT_'${idx}'_ACTIVE'
        # Write config if account is active
        if [ "$inadyn_active" = 'yes' ] ; then
            eval inadyn_update_interval='$INADYN_ACCOUNT_'${idx}'_UPDATE_INTERVAL'
            eval inadyn_user='$INADYN_ACCOUNT_'${idx}'_USER'
            eval inadyn_password='$INADYN_ACCOUNT_'${idx}'_PASSWORD'
            eval inadyn_system_type='$INADYN_ACCOUNT_'${idx}'_SYSTEM'
            eval inadyn_ip_server_name='$INADYN_ACCOUNT_'${idx}'_IP_SERVER'
            eval inadyn_alias_number='$INADYN_ACCOUNT_'${idx}'_ALIAS_N'
            eval inadyn_log_type='$INADYN_ACCOUNT_'${idx}'_LOGFILE'
            eval inadyn_log_level='$INADYN_ACCOUNT_'${idx}'_LOG_LEVEL'
            eval inadyn_mail='$INADYN_ACCOUNT_'${idx}'_MAIL_ON_UPDATE'

            # Setup host type etc. pp
            if [ -z "$inadyn_ip_server_name" ] ; then
                inadyn_ip_server_name='checkip.two-dns.de'
            fi
            case "$inadyn_system_type" in
                dynamic)
                    inadyn_system='dyndns@dyndns.org'
                    ;;
                static)
                    inadyn_system='statdns@dyndns.org'
                    ;;
                custom)
                    inadyn_system='custom@dyndns.org'
                    ;;
                zoneedit)
                    inadyn_system='default@zoneedit.com'
                    ;;
                no-ip)
                    inadyn_system='default@no-ip.com'
                    ;;
                changeip)
                    inadyn_system='custom@http_svr_basic_auth'
                    inadyn_ip_server_name='ip.changeip.com'
                    ;;
            esac

            # Modify logging
            if [ "$inadyn_log_type" = '' ] ; then
                inadyn_log="syslog"
            else
                inadyn_log="log_file $inadyn_log_type"
            fi

            # Write configuration
            cat > ${inadyn_configfile} <<EOF
# Inadyn configuration file

# Update interval
update_period_sec ${inadyn_update_interval}

# Dynamic DNS username and password
username ${inadyn_user}
password ${inadyn_password}

# Update system
dyndns_system ${inadyn_system}

# Dynamic DNS aliases / hosts
EOF
            # Change alias list into separate aliases
            jdx=1
            while [ $jdx -le ${inadyn_alias_number} ] ; do
                eval inadyn_alias='$INADYN_ACCOUNT_'${idx}'_ALIAS_'$jdx
                case ${inadyn_alias} in
                    [1-5])
                        # Set number given, so add '*' in front of it
                        # (Used on changeip.com)
                        echo "alias *$inadyn_alias" >> ${inadyn_configfile}
                        ;;
                    *)
                        echo "alias $inadyn_alias" >> ${inadyn_configfile}
                        ;;
                esac
                jdx=$((jdx+1))
            done

            cat >> ${inadyn_configfile} <<EOF

# Run as daemon / in background
background

# Log to syslog or file
${inadyn_log}

# Debug / log level
verbose ${inadyn_log_level}

# IP check server
ip_server_name ${inadyn_ip_server_name} /

# Inadyn chache directory
cache_dir /tmp/inadyn_cache
EOF

            case "$inadyn_system_type" in
                changeip)
                    cat >> ${inadyn_configfile} <<EOF

dyndns_server_name nic.changeip.com
dyndns_server_url /nic/update?system=dyndns&xml=1&hostname=
EOF
                    ;;
            esac

            if [ "$inadyn_mail" = 'yes' ] ; then
                if checkMailPackage ; then
                    eval inadyn_mail_to='$INADYN_ACCOUNT_'${idx}'_MAIL_TO'
                    cat >> ${inadyn_configfile} <<EOF

# Mail command to execute after successful update
exec "/var/install/bin/inadyn-status-mail.sh ${inadyn_mail_to} ${idx} ${inadyn_system_type} ${inadyn_account_name}"
EOF
                else
                    mecho --error "No mail package found, no mail functionality for INADYN_ACCOUNT_${idx}"
                fi
            fi

            chmod 640 ${inadyn_configfile}

            # Create empty logrotate if not logging to syslog
            if [ -n "$inadyn_log_type" ] ; then
                cat > /etc/logrotate.d/inadyn${idx} <<EOF
# ----------------------------------------------------------------------------
# /etc/logrotate.d/inadyn${idx} file generated by /var/install/config.d/inadyn.sh
#
# Do not edit this file, use eisfair configuration editor!
# Creation Date: `date`
# ----------------------------------------------------------------------------
${inadyn_log_type} {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 644 root root
    }

EOF
            fi
        fi
        idx=$((idx+1))
    done
}



# ----------------------------------------------------------------------------
# Check if a mail package exists
checkMailPackage()
{
    if [ -f /var/install/packages/mail -o -f /var/install/packages/vmail -o -f /var/install/packages/ssmtp ] ; then
        return 0
    fi
    return 1
}


# ----------------------------------------------------------------------------
# Main
if [ "$START_INADYN" = 'yes' ] ; then
    createInadynConfiguration
    rc-update add inadyn
else
    rc-update del inadyn
fi
exit 0
