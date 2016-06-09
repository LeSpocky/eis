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

. /etc/config.d/phpmyadmin
. /etc/config.d/apache2

# used php version
PHPv=php5

# -----------------------------------------------------------------------------
# load php module if not installed
# -----------------------------------------------------------------------------
load_php_module()
{
    local name="$1"
    apk info -q -e ${PHPv}-$name || apk add -q ${PHPv}-$name
    if [ $? -eq 0 ]; then
        return 0
    else
        # create error message if packages not installed
        logger -p error -t cui-phpmyadmin "Fail install: ${PHPv}-$name"
        echo "Fail install: ${PHPv}-$name"
        return 1
    fi
}

load_php_module json
load_php_module mysql
load_php_module mysqli
load_php_module pdo_mysql
load_php_module xml

# ----------------------------------------------------------------------------
# Setup all necessary configuration files and perform necessary steps
activatePhpMyAdmin()
{
    cp /etc/default.d/*.phpmyadmin.ini /etc/${PHPv}/conf.d/
    cat >/etc/apache2/conf.d/phpmyadmin.conf <<EOF
Alias /phpmyadmin "/usr/share/webapps/phpmyadmin"
<Directory "/usr/share/webapps/phpmyadmin">
    AllowOverride All
    Options FollowSymlinks
    Order allow,deny
    Require all granted
    Allow from all
</Directory>
EOF
}


# ----------------------------------------------------------------------------
# Remove all configuration files and perform further necessary steps
deactivatePhpMyAdmin()
{
    rm -f /etc/${PHPv}/conf.d/*.phpmyadmin.ini
    cat >/etc/apache2/conf.d/phpmyadmin.conf <<EOF
Alias /phpmyadmin "/usr/share/webapps/phpmyadmin"
<Directory "/usr/share/webapps/phpmyadmin">
    AllowOverride All
    Options FollowSymlinks
    Require all granted
    Deny from all
</Directory>
EOF


}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$START_PHPMYADMIN" = 'yes' ] ; then
    activatePhpMyAdmin
else
    deactivatePhpMyAdmin
fi

# Restart apache
[ "$START_APACHE2" = "yes" ] && rc-service -i apache2 restart

exit 0
