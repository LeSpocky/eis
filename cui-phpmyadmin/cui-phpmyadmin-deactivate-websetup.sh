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

    if [ -d ${webConfigFolder} && ! -d ${backupFolder}/setup ] ; then
        mv ${webConfigFolder} ${backupFolder}/
    else
        rm -rf ${webConfigFolder}
    fi
}

activateCreatedConfiguration ()
{
    mv ${installFolder}/config/config.inc.php ${configFolder}/
    rm -rf ${installFolder}/config
}

deactivateWebsetup
activateCreatedConfiguration
