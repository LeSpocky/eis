#!/bin/sh
#-----------------------------------------------------------------------------
# /var/install/config.d/cui.sh - menu configuration script
# Copyright (c) 2001-2015 The Eisfair Team <team@eisfair.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-----------------------------------------------------------------------------

cp -p /etc/config.d/cui /etc/cui.conf
chmod 0644 /etc/cui.conf
chown root /etc/cui.conf

exit 0
