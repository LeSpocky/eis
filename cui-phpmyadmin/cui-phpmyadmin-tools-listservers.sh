#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/phpmyadmin-tools-listservers.sh
#
# Creation:     2007-01-23 starwarsfan
#
# Copyright (c) 2007-2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2>/public/phpmyadmin-trace$$.log
#set -x

. /etc/config.d/phpmyadmin
. /var/install/include/eislib


# ----------------------------------------------------------------------------
# List configured servers
listConfiguredServers ()
{
	mecho ""
	mecho "Konfigured active servers:"
	mecho ""
	techo begin 4 20 30
	techo row -info "No." -info "Host" -info "Advanced features"

	# begin idx -le ${PHPMYADMIN_SERVER_N}
	idx=1

	# count for active
	idx1=1

	while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do

	    eval active='${PHPMYADMIN_SERVER_'${idx}'_ACTIVE}'

	    # begin $active
	    if [ "${active}" = 'yes' ] ; then

	        eval host='${PHPMYADMIN_SERVER_'${idx}'_HOST}'
	        eval port='${PHPMYADMIN_SERVER_'${idx}'_PORT}'

	        eval advancedFeaturesActive='${PHPMYADMIN_SERVER_'${idx}'_ADVANCED_FEATURES}'
			if [ "${advancedFeaturesActive}" = 'yes' ] ; then
	            eval pmadb='${PHPMYADMIN_SERVER_'${idx}'_PMADB}'
	            eval controluser='${PHPMYADMIN_SERVER_'${idx}'_CONTROLUSER}'
	            eval controlpass='${PHPMYADMIN_SERVER_'${idx}'_CONTROLPASS}'

				techo row ${idx} ${host} "active"
			else
				techo row ${idx} ${host} "not active"
	        fi

	        # end count for active
	        idx1=`/usr/bin/expr ${idx1} + 1`

	        # end $active
	    else
	    	techo row ${idx} "not active"
	    fi

	    # end idx -le ${PHPMYADMIN_SERVER_N}
	    idx=`/usr/bin/expr ${idx} + 1`
	done

	techo end
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

listConfiguredServers

exit 0
