#!/bin/sh
#----------------------------------------------------------------------------
# /var/install/config.d/fcron.sh - fcron configuration file
#
# Creation:	2012-11-08  jens@eisfair.org
# Last Update:  $Id: cron.sh24471 2012-11-08 21:14:01Z jv $
#----------------------------------------------------------------------------

# added config file
. /etc/config.d/fcron

# set fcron.conf group cron, read for all!
#chown root:cron /etc/fcron.conf
#chmod 0644 /etc/fcron.conf
chown cron:cron /var/spool/fcron
chmod 0770 /var/spool/fcron

#----------------------------------------------------------------------------
# create menu defined entries
#----------------------------------------------------------------------------
cron_path='/etc/cron'
mkdir -p ${cron_path}/root
# remove old user cron config files
cd ${cron_path}
for user in *
do
	[ -d ${user} ] && rm -f ${cron_path}/${user}/cron.base
done
# write cron configuration to file
idx=1
while [ "${idx}" -le "${CRON_N}" ]
do
	# check for active
	eval active='${CRON_'${idx}'_ACTIVE}'
	if [ "${active}" = "yes" ]
	then
		eval time='$FCRON_'${idx}'_TIMES'
		eval user='$FCRON_'${idx}'_USER'
		eval command='$FCRON_'${idx}'_COMMAND'
		if ! grep -e "^${user}:" /etc/passwd >/dev/null 2>&1
		then
			user="root"
		fi
		mkdir -p ${cron_path}/${user}
		echo "${time} ${command}" >> ${cron_path}/${user}/cron.base
	fi
	: $(( idx++ ))
done

#----------------------------------------------------------------------------
# start stop update
#----------------------------------------------------------------------------
if [ "$START_FCRON" = "yes" ]
then
	/sbin/rc-update add fcron default >/dev/null 2>&1
	if [ -e /var/run/fcron.pid ]
	then
		/etc/init.d/fcron reload
	else
		/etc/init.d/fcron update
		/etc/init.d/fcron start
	fi
else
	/sbin/rc-update del fcron default
fi

#============================================================================
exit 0
