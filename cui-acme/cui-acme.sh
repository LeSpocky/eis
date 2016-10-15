#!/bin/sh
# ----------------------------------------------------------------------------
# eisfair-ng configuration generator script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

. /etc/config.d/cui-acme
. /var/install/include/eislib

# ----------------------------------------------------------------------------
# Setup all necessary configuration files and perform necessary steps
generateNewCert()
{
    (
    echo "$(date "+%Y-%m-%d %H:%M:%S") --- START ---"
    acmeCallParameters=''
    separator=''
    idx=1
    while [ ${idx} -le ${ACME_WEBROOT_N} ] ; do
        eval currentWebrootFolderActive='$ACME_WEBROOT_'${idx}'_ACTIVE'
        if [ "$currentWebrootFolderActive" = 'yes' ] ; then
            eval currentWebroot='$ACME_WEBROOT_'${idx}'_PATH'
            eval amountOfDomains='$ACME_WEBROOT_'${idx}'_DOMAIN_N'
            idx2=1
            while [ ${idx2} -le ${amountOfDomains} ] ; do
                eval isDomainActive='$ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_ACTIVE'
                if [ "$isDomainActive" = 'yes' ] ; then
                    eval currentDomain='$ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_NAME'
                    if [ -n "$currentDomain" ] ; then
                        domainsToGetCertFor="-d ${currentDomain}"
                        eval amountOfSubDomains='$ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_SUBDOMAIN_N'
                        idx3=1
                        while [ ${idx3} -le ${amountOfSubDomains} ] ; do
                            eval isSubDomainActive='$ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_SUBDOMAIN_'${idx3}'_ACTIVE'
                            if [ "$isSubDomainActive" = 'yes' ] ; then
                                eval currentSubDomain='$ACME_WEBROOT_'${idx}'_DOMAIN_'${idx2}'_SUBDOMAIN_'${idx3}'_NAME'
                                if [ -n "$currentSubDomain" ] ; then
                                    domainsToGetCertFor="${domainsToGetCertFor} -d ${currentSubDomain}.${currentDomain}"
                                fi
                            fi
                            idx3=$((idx3+1))
                        done
                        command="sh /usr/bin/acme.sh --issue ${domainsToGetCertFor} -w ${currentWebroot} --home /etc/ssl/acme"
                        echo "$(date "+%Y-%m-%d %H:%M:%S") ${command}"
                        ${command} 2>&1
                        rtc=$?
                        if [ ${rtc} -eq 0 ] ; then
                            command="sh /usr/bin/acme.sh --installcert -d ${currentDomain} --home /etc/ssl/acme --certpath /etc/ssl/certs/${currentDomain}.pem --keypath /etc/ssl/private/${currentDomain}.key --capath /etc/ssl/certs/${currentDomain}.ca.pem --reloadcmd 'rc-service apache2 restart'"
                            echo "$(date "+%Y-%m-%d %H:%M:%S") ${command}"
                            ${command} 2>&1
                            if [ ${rtc} -ne 0 ] ; then
                                echo "$(date "+%Y-%m-%d %H:%M:%S") WARN: Installing certs returned with exit code $rtc)!"
                            fi
                        else
                            echo "$(date "+%Y-%m-%d %H:%M:%S") WARN: Issuing certs returned with exit code $rtc)!"
                        fi
                    else
                        echo "$(date "+%Y-%m-%d %H:%M:%S") WARN: No domain for webroot '$currentWebroot' configured"
                    fi
                fi
                idx2=$((idx2+1))
            done
        fi
        idx=$((idx+1))
    done
    checkApacheSslActivation
    echo "$(date "+%Y-%m-%d %H:%M:%S") --- FINISHED ---"
    ) >> /var/log/acme.log &
    /var/install/bin/show-doc.cui -t "Output of acme.sh and further steps" -f /var/log/acme.log
}

createLinks() {
    if [ ! -d /etc/ssl/apache2 ] ; then
        mkdir -p /etc/ssl/apache2
    fi
    cd /etc/ssl/apache2/
    for currentFile in $(ls /etc/ssl/acme/*/*.key) $(ls /etc/ssl/acme/*/*.csr) ; do
        linkname=${currentFile##*/}
        linkname=${linkname/.csr/.pem}
        echo "$(date "+%Y-%m-%d %H:%M:%S") $linkname"
        if [ -h ${linkname} ] ; then
            rm -f ${linkname}
        fi
        ln -s ${currentFile} ${linkname}
    done
    cd - > /dev/null
}

checkApacheSslActivation() {
    . /etc/config.d/apache2
    if [ "$APACHE2_SSL" = 'no' ] ; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") WARN: APACHE2_SSL is set to 'no' in apache2 configuration!"
    fi
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$START_ACME" = 'yes' ] ; then
    generateNewCert
fi

exit 0
