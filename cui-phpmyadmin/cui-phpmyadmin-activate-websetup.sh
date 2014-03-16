#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/phpmyadmin-activate-websetup.sh
#
# Creation:     2014-03-16 starwarsfan
#
# Copyright (c) 2009-2014 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/phpmyadmin-activate-websetup-trace$$.log
#set -x

. /var/install/include/eislib

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
        cp -f ${backupFolder}/setup ${webConfigFolder}
    else
        mecho --warn "Backup folder with phpmyadmin setup not found!"
    fi
}

copyExistingConfigForWebConfiguration ()
{
    if [ ! -d ${configFolderForWebConfig} ] ; then
        mkdir -p ${configFolderForWebConfig}
    fi
    chown -R ${ownerToUse} ${configFolderForWebConfig}
    if [ -e ${configPhp} ] ; then
        cp -f ${configPhp} ${configFolderForWebConfig}/
    fi
}

activateWebsetup
copyExistingConfigForWebConfiguration

mecho --info "Webbased setup activated. Access it using URL <yourhost>/phpmyadmin/setup/"
anykey
