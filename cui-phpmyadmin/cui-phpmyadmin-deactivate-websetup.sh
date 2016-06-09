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

deactivateWebsetup ()
{
    if [ ! -d ${backupFolder} ] ; then
        mkdir -p ${backupFolder}
    fi

    if [ -d ${webConfigFolder} -a ! -d ${backupFolder}/setup ] ; then
        mv -f ${webConfigFolder} ${backupFolder}/
    else
        rm -rf ${webConfigFolder}
    fi
    mkdir ${webConfigFolder}
    echo "Use eisfair setup to activate webbased phpmyadmin configuration!" > ${webConfigFolder}/index.php
}

activateCreatedConfiguration ()
{
    mv ${installFolder}/config/config.inc.php ${configFolder}/
    rm -rf ${installFolder}/config
}

removeWebConfigFolder ()
{
    if [ ! -d ${configFolderForWebConfig} ] ; then
        rm -rf ${configFolderForWebConfig}
    fi
}

deactivateWebsetup
activateCreatedConfiguration
removeWebConfigFolder

/var/install/bin/ask.cui --info "Created configuration activated and webbased setup disabled."
