#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-status - call /etc/init.d/lprng to show status of  printer services
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2002-10-06 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
. /var/install/include/eislib
/etc/init.d/lprng status
echo
anykey
