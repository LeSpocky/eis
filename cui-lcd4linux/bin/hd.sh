#!/bin/bash
# ----------------------------------------------------------------------------
# /usr/local/bin/hd.sh - Helper script to show some information for
#                        requested partition.
#
# Creation:    2005-01-28 nico
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/lcd-hd-trace$$.log
#set -x

# ----------------------------------------------------------------------------
# Show usage
showUsage () {
    cat <<EOF

  Show some information for requested partition.

  Usage: `basename $0` <partition> <f|F|u|U|s|S|m|M|p|P>

  Options:
    partition    - The partition as it is found on /dev/
    f, F         - Free space
    u, U         - Used space
    s, S         - Size of partition
    m, M         - Mountpoint
    p, P         - Used space in percent

EOF
}

partition=$1
info=$2

if [ -z $info ] ; then
	showUsage
fi

set -- `df -h | grep "/dev/$partition"`
case $info in
	s|S) echo "$2" ;;
	u|U) echo "$3" ;;
	f|F) echo "$4" ;;
	p|P) echo `echo $5 | sed -e 's/%//g'` ;;
	m|M) echo "$6" ;;
esac
