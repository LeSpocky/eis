#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script for open-vm-tools
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/apache2-trace$$.log
#set -x

pgmname=$0

chmod 600 /etc/config.d/open-vm-tools

. /etc/config.d/open-vm-tools

# create error message if packages not installed
errorsyslog()
{
    local tmp="Fail install: $1"
    logger -p error -t open-vm-tools "$tmp"
    echo "$tmp"
}

if [ "VMTOOLS_START" = "yes" ]; then
    if [ "$VMTOOLS_ALL_MODULES" = "yes" ]; then
        rc-update -q add vmware-modules-grsec default
        rc-service -i -q vmware-modules-grsec start
    else
        rc-update -q del vmware-modules-grsec >/dev/null 2>&1
        rc-service -i -q vmware-modules-grsec stop >/dev/null 2>&1
    fi
else
    rc-update -q del vmware-modules-grsec >/dev/null 2>&1
    rc-service -i -q vmware-modules-grsec stop >/dev/null 2>&1
    exit 0
fi

mkdir -p /etc/vmware-tools/scripts/poweroff-vm-default.d

cat > /etc/vmware-tools/scripts/poweroff-vm-default.d/poweroff.sh <<EOF
#!/bin/sh
poweroff
EOF

chmod 0700 /etc/vmware-tools/scripts/poweroff-vm-default.d/poweroff.sh

exit 0
