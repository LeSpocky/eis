#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-print - print lprng jobs
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2004-10-09 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
smbinfofile="/var/spool/lprng/$2.smbinfo"
{
 echo "queue=$1"
 echo "jobfile=/var/spool/samba/$2"
 echo "user=$3"
 echo "client=$4"
 echo "printserver=$5"
 echo "ip=$6"
 echo "os=$7"
 echo "jobname=$8"
} > $smbinfofile
chmod 666 $2 $smbinfofile
/usr/bin/lpr -P$1 $2
rm -f $2
exit 0
