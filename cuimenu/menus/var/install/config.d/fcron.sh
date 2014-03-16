#!/bin/sh
#-----------------------------------------------------------------------------
# /var/install/config.d/fcron.sh - fcron configuration file
# Copyright (c) 2001-2014 the eisfair team, team(at)eisfair(dot)org
#-----------------------------------------------------------------------------

# added config file
. /etc/config.d/fcron

# ----------------------------------------------------------------------------
# Set fcron.conf group cron, read for all!
#chown root:cron /etc/fcron.conf
#chmod 0644 /etc/fcron.conf
mkdir -p /var/spool/fcron
chown cron:cron /var/spool/fcron
chmod 0770 /var/spool/fcron

# ----------------------------------------------------------------------------
# Create menu defined entries
cron_path='/etc/cron'
mkdir -p ${cron_path}/root

# ----------------------------------------------------------------------------
# Remove old user cron config files
cd ${cron_path}
for user in * ; do
	[ -d ${user} ] && rm -f ${cron_path}/${user}/cron.base
done

# ----------------------------------------------------------------------------
# Write cron configuration to file
idx=1
while [ "${idx}" -le "${FCRON_N}" ] ; do
	# check for active
	eval active='${FCRON_'${idx}'_ACTIVE}'
	if [ "${active}" = "yes" ] ; then
		eval time='$FCRON_'${idx}'_TIMES'
		eval user='$FCRON_'${idx}'_USER'
		eval command='$FCRON_'${idx}'_COMMAND'
		if ! grep -e "^${user}:" /etc/passwd >/dev/null 2>&1 ; then
			user="root"
		fi
		mkdir -p ${cron_path}/${user}
		echo "${time} ${command}" >> ${cron_path}/${user}/cron.base
	fi
	: $(( idx++ ))
done

# ----------------------------------------------------------------------------
# Start stop update
if [ "$START_FCRON" = "yes" ] ; then
    rc-update -q add fcron default 2>/dev/null
    rc-service -q fcron update 2>/dev/null
else
    rc-update -q del fcron default 2>/dev/null
fi

exit 0
