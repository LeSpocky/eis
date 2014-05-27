#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-phpmyadmin.sh - phpMyAdmin configuration
#
# Creation:     2006-09-15 starwarsfan
#
# Copyright (c) 2006--2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Yves Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2>/tmp/phpmyadmin-trace$$.log
#set -x

. /etc/config.d/phpmyadmin
. /etc/config.d/php-apache2
. /var/install/include/eislib

configFolder=/etc/phpmyadmin
configPhp=${configFolder}/config.inc.php

installFolder=/usr/share/webapps/phpmyadmin
webConfigFolder=${installFolder}/setup
configFolderForWebConfig=${installFolder}/config

sweKeyConfigured=false
ownerToUse='apache:apache'



# ----------------------------------------------------------------------------
# Setup all necessary configuration files and perform necessary steps
activatePhpMyAdmin ()
{
    cp /etc/default.d/*.phpmyadmin.ini /etc/php/conf.d/
}



# ----------------------------------------------------------------------------
# Remove all configuration files and perform further necessary steps
deactivatePhpMyAdmin ()
{
    rm -f /etc/php/conf.d/*.phpmyadmin.ini
}



# ----------------------------------------------------------------------------
# Restart webserver
restartWebserver ()
{
    rc-service apache2 restart
}


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$1" = '--quiet' ] ; then
    quietmode=true
else
    quietmode=false
fi

if [ "${START_PHPMYADMIN}" = 'yes' ] ; then
	activatePhpMyAdmin
else
    deactivatePhpMyAdmin
fi
restartWebserver

exit 0
