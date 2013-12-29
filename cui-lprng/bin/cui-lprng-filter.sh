#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-filter - filter lprng jobs
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2004-10-09 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
queue=`echo "$1"|tr -d \"|cut -b3-`
jobgroesse=`expr \`echo "$2"|tr -d \"|cut -b3-\` / 1024`
spoolfile=`echo "$3"|tr -d \"|cut -b3-`
jobnr=`echo "$4"|tr -d \"|cut -b3-`
druckdatum=`echo "$5"|tr -d \"|cut -b3-|cut -d. -f1`
smbinfofile=/var/spool/lprng/`echo "$6"|tr -d \"|cut -b3-`.smbinfo
user=`echo "$7"|tr -d \"|cut -b3-`
client=`echo "$8"|tr -d \"|cut -b3-`
cm=`echo "$9"|tr -d \"|cut -b3-`
full='no'
/bin/cat -
if [ -f ${smbinfofile} ] ; then
    smbinfo=`echo ${PRINTCAP_ENTRY}|sed -e "s/.*:smbinfo=//g"|sed -e "s/:.*//g"|tr -d "[:blank:]"`
    eval `/bin/cat ${smbinfofile}`
    rm -f ${smbinfofile}
    if [ "$smbinfo" = "yes" ] ; then
        message="Druckauftrag entgegengenommen am $druckdatum<newline><newline>"
        message="$message<tab>gedruckt auf<tab>: \\\\$printserver\\$queue<newline>"
        if [ -n "$cm" ] ; then
            message="$message<tab><tab><tab>  $cm<newline>"
        fi
        message="$message<tab>abgeschickt von<tab>: $user@$client<newline>"
        message="$message<tab>Client-IP<tab><tab>: $ip<newline>"
        message="$message<tab>Client-OS<tab><tab>: $os<newline>"
        message="$message<tab>Jobnummer<tab>: $jobnr<newline>"
        if [ -n "$jobname" ] ; then
            message="$message<tab>Jobname<tab>: $jobname<newline>"
        fi
        message="$message<tab>Druckjobgroesse<tab>: $jobgroesse KByte<newline>"
        if [ "$full" = yes ] ; then
            version=`cat /etc/version`
            samba_version=`cat /usr/share/doc/samba/version`
            samba_intversion=`/usr/sbin/smbd -V | cut -d" " -f2`
            samba="$samba_version<tab>($samba_intversion)"
            lprng_version=`cat /usr/share/doc/lprng/version`
            lprng_intversion=`lpstat -V | cut -d, -f1 | cut -d- -f2`
            lprng="$lprng_version<tab>($lprng_intversion)"
            eiskernelversion=`grep "<version>" /var/install/packages/eiskernel 2>/dev/null | sed 's#</*version>##g'`
            eiskerneluname=`uname -r`
            eiskernel="$eiskernelversion<tab>($eiskerneluname)"
            message="$message<tab>Samba-Spoolfile<tab>: $jobfile<newline>"
            message="$message<tab>LPRng-Spoolfile<tab>: /var/spool/lpd/$queue/$spoolfile<newline>"
            message="$message<tab>Samba-Infofile<tab>: $smbinfofile<newline><newline>"
            message="$message<tab><tab>>>>> powered by eisfair <<<<<newline><newline>"
            message="$message<tab>- base<tab><tab>: $version<newline>"
            message="$message<tab>- eiskernel<tab>: $eiskernel<newline>"
            message="$message<tab>- Samba<tab><tab>: $samba<newline>"
            message="$message<tab>- LPRng<tab><tab>: $lprng<newline>"
        fi
        echo "$message"|awk '{print gensub("<tab>","\t","g",gensub("<newline>","\n","g"))}'|/usr/bin/smbclient -U "eisfair Samba Server $printserver" -N -M $client -I $ip 1> /dev/null
    fi
fi
echo "$druckdatum $queue $user@$client $jobgroesse KByte" >> /var/spool/lprng/log.lprng
ls /etc/lprng-filter.* >/dev/null 2>/dev/null
if [ $? -eq 0 ] ; then
    for SCRIPT in `ls /etc/lprng-filter.*`
    do
        . ${SCRIPT}
    done
fi
exit 0
