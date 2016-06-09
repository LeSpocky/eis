#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/bin/phpmyadmin-activate-websetup.sh
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

configFolder=/etc/phpmyadmin
configPhp=${configFolder}/config.inc.php

installFolder=/usr/share/webapps/phpmyadmin
webConfigFolder=${installFolder}/setup
configFolderForWebConfig=${installFolder}/config

backupFolder=/var/lib/phpmyadmin
ownerToUse='apache:apache'

activateWebsetup ()
{
    if [ -d ${backupFolder}/setup ] ; then
        rm -rf ${webConfigFolder}
        cp -rf ${backupFolder}/setup ${webConfigFolder}
    else
        /var/install/bin/ask.cui --error "Backup folder with phpmyadmin setup not found!"
    fi
}

copyExistingConfigForWebConfiguration ()
{
    if [ ! -d ${configFolderForWebConfig} ] ; then
        mkdir -p ${configFolderForWebConfig}
    fi
    if [ -e ${configPhp} ] ; then
        cp -f ${configPhp} ${configFolderForWebConfig}/
    fi
    chown -R ${ownerToUse} ${configFolderForWebConfig}
}

createWebConfigFolder ()
{
    if [ ! -d ${configFolderForWebConfig} ] ; then
        mkdir -p ${configFolderForWebConfig}
    fi
    chown -R ${ownerToUse} ${configFolderForWebConfig}
}

activateWebsetup
copyExistingConfigForWebConfiguration
createWebConfigFolder

/var/install/bin/ask.cui --info "Webbased setup activated. Access it using URL <yourhost>/phpmyadmin/setup/"
