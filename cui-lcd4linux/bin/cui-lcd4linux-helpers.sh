#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-lcd4linux-helpers.sh
# Creation:     2009-09-19 starwarsfan
# Copyright (c) 2009-2014 Yves Schumann <yves(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------

#exec 2> /tmp/cui-lcd4linux-helpers-trace$$.log
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
    if [ $# -eq 0 ]
    then
        echo -e "\033[300C\033[$[9]D [ Done ]"
    elif [ $1 == true ]
    then
        echo -e "\033[300C\033[$[7]D [ OK ]"
    else
        echo -e "\033[300C\033[$[11]D [ ${COLOR_RED}Failed${COLOR_NRM} ]"
    fi
}
