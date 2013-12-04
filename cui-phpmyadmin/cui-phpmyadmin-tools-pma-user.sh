#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-phpmyadmin-tools-pma-user.sh
#
# Creation:     2007-01-22 starwarsfan
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

mysql_data_dir=/var/lib/mysql
mysql_base_dir=/usr/local/mysql



# ----------------------------------------------------------------------------
# create the sql script and execute it
doDBOperation ()
{
	givenServernumber=$1

	# check if $givenServernumber is in range
	if [ "${givenServernumber}" -gt 0 -a "${givenServernumber}" -le "${PHPMYADMIN_SERVER_N}" ] ; then

	    # check if entered server is active
	    eval active='${PHPMYADMIN_SERVER_'${givenServernumber}'_ACTIVE}'
	    if [ "${active}" = "yes" ] ; then

	        # check if advanced features are activated
	        eval advancedFeaturesActive='${PHPMYADMIN_SERVER_'${givenServernumber}'_ADVANCED_FEATURES}'
			if [ "${advancedFeaturesActive}" == "yes" ] ; then
		        eval host='${PHPMYADMIN_SERVER_'${givenServernumber}'_HOST}'
		        eval port='${PHPMYADMIN_SERVER_'${givenServernumber}'_PORT}'
	            eval pmadb='${PHPMYADMIN_SERVER_'${givenServernumber}'_PMADB}'
	            eval controluser='${PHPMYADMIN_SERVER_'${givenServernumber}'_CONTROLUSER}'
	            eval controlpass='${PHPMYADMIN_SERVER_'${givenServernumber}'_CONTROLPASS}'

	            mecho ""
	            dbAdmin=`/var/install/bin/ask "Please enter name of DB admin for server '${host}': " "" "+"`
				mecho -n "Please enter password: "
				stty -echo
				read dbAdminPass
				stty echo
				mecho ""
				mecho "Please enter host from which the pma user accesses server '${host}'."
				pmaHost=`/var/install/bin/ask "Normally this should be the IP or FQDN of this machine: " "" "+"`

				mecho ""
				mecho -n "Setting rights for pma user '"
				mecho -n -info "${controluser}@${pmaHost}"
				mecho -n "' on server '"
				mecho -n -info "${host}"
				mecho "'."
				mecho "If the pma user is not existing, it will be created."
				executeSQLScript=`/var/install/bin/ask "Continue" "y"`
				if [ "${executeSQLScript}" = "yes" ] ; then
					${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} -e"GRANT SELECT, INSERT, DELETE, UPDATE ON ${pmadb}.* TO ${controluser}@${pmaHost};"
					mecho -info "Done"
				else
					mecho "Creation of pma user canceled"
				fi
				/var/install/bin/anykey
			else	# advanced features not activated
				mecho
				mecho -info "Advanced features on server ${givenServernumber} not active"
				mecho
	        fi		# end of advanced features active check
	    else	# given server number is not active
			mecho
			mecho -info "Server ${givenServernumber} is not active"
			mecho
	    fi		# end of server active check
	else	# given server is out of range
		mecho
		mecho -info "There are only ${PHPMYADMIN_SERVER_N} servers configured,"
		mecho -info "but you entered ${givenServernumber}. Choose another one."
		mecho
	fi		# end of amount of servers check

	/var/install/bin/anykey
}


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

inputValue="0"

if [ ! `apk info | grep "^mysql$" ` ] ; then
    mecho --warn "You need to install package 'mysql' to use this feature!"
    exit 1
fi

until [ "${inputValue}" = "q" ] ; do
  	mecho ""
  	mecho "This script will create the pma controluser or alter his rights"
  	mecho "if the user exists. To do this you have to choose one of the"
  	mecho "available servers and enter name and password of a user with admin"
  	mecho "rights on the choosen server."
  	mecho ""
	/var/install/bin/phpmyadmin-tools-listservers.sh

    inputValue=`/var/install/bin/ask "Please choose a server, 'q' for quit: " "" "*"`
    if [ "${inputValue}" != "q" ] && [ ${inputValue} -gt 0 ] ; then
		doDBOperation ${inputValue}
    fi
  done

exit 0
