#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-show-jobs - show jobs in all queues
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2002-12-28 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
. /var/install/include/eislib
case $#
in
  0)
    interactive='true'
    ;;
  1)
    if [ "$1" = "noninteractive" ]
    then
        interactive='false'
    fi
    ;;
  *)
    echo "usage: /var/install/bin/`basename $0`" >&2
    echo "   or: /var/install/bin/`basename $0` noninteractive" >&2
    exit 1
    ;;
esac
if [ "$interactive" = "true" ]
then
    clrhome
    mecho --info "Show Jobs in all Queues"
    echo
fi
/usr/bin/lpq -a
if [ "$interactive" = "true" ]
then
    echo
    anykey
fi
