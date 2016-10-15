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
    idx=1
    domainsToGetCertFor=''
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
                    domainsToGetCertFor="$domainsToGetCertFor -d $currentDomain -w $currentWebroot"
                fi
                idx2=$((idx2+1))
            done
        fi
        idx=$((idx+1))
    done
    if [ -z "$domainsToGetCertFor" ] ; then
        mecho "No domain as active configured! Nothing to do..."
        anykey
        return
    fi
    mecho "Parameter list: $domainsToGetCertFor"
    anykey
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$START_ACME" = 'yes' ] ; then
    generateNewCert
fi

exit 0
