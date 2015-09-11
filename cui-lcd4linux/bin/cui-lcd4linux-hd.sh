#!/bin/bash
# ----------------------------------------------------------------------------
# /usr/local/bin/cui-lcd4linux-hd.sh - Helper script to show some information
#                                      for requested partition.
# Creation:    2005-01-28 nico
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------

#exec 2> /tmp/cui-lcd4linux-hd-trace$$.log
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
