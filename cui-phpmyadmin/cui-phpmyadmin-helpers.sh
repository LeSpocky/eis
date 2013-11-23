#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/bin/cui-phpmyadmin-helpers.sh
#
# Creation:     2009-10-02 starwarsfan
#
# Copyright (c) 2009-2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/phpmyadmin-helpers-trace$$.log
#set -x

COLOR_RED='\033[1;31m'
COLOR_NRM='\033[0;39m'



# ----------------------------------------------------------------------------
# Write a message on the right border of the console
# Known messages:
# - no parameter:              [ Done ]
# - first parameter 'true':      [ OK ]
# - first parameter 'false': [ Failed ]
# ----------------------------------------------------------------------------
actionFinished ()
{
	if [ $# -eq 0 ] ; then
		echo -e "\033[300C\033[$[9]D [ Done ]"
	elif [ $1 == true ] ; then
		echo -e "\033[300C\033[$[7]D [ OK ]"
	else
	    echo -e "\033[300C\033[$[11]D [ ${COLOR_RED}Failed${COLOR_NRM} ]"
	fi
}
