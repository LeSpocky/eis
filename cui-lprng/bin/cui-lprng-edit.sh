#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-edit - edit /etc/config.d/lprng
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2002-10-06 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
. /var/install/include/eislib
configfile='/etc/config.d/lprng'
base=''
parport_found=''
modprobebin='/sbin/modprobe'
rmmodbin='/sbin/rmmod'
lsmodbin='/sbin/lsmod'

do_modules_load ()
{
  for modul in parport parport_pc lp
  do
    if [ -z "`${lsmodbin} | grep "^$modul "`" ] ; then
        ${modprobebin} ${modul} >/dev/null 2>&1
    fi
  done
}

do_modules_del ()
{
  for modul in lp parport_pc parport
  do
    if [ -n "`${lsmodbin} | grep "^$modul "`" ] ; then
        ${rmmodbin} ${modul} >/dev/null 2>&1
    fi
  done
}

clrhome
mecho --info "Edit LPRng configuration"
echo
mecho --warn "While configuring printing will be not available."
echo

if /var/install/bin/ask "Continue anyway" "y" ; then
    do_modules_del
    do_modules_load

    if [ -d /proc/sys/dev/parport ] ; then
        for i in $(ls -1 /proc/sys/dev/parport | grep -v default)
        do
            base=$(cat /proc/sys/dev/parport/${i}/base-addr | cut -f1)
            base=`echo "obase=16; $base" | bc`
        done

        if [ -n "$base" ] ; then
            echo
            mecho --info "Found parallel port(s), please write down adress(es):"
            echo

            for i in $(ls -1 /proc/sys/dev/parport | grep -v default)
            do
                base=$(cat /proc/sys/dev/parport/${i}/base-addr | cut -f1)
                base=`echo "obase=16; $base" | bc`
                mecho --info "                        0x$base"
            done
        else
            parport_found="false"
        fi
    else
        parport_found="false"
    fi

    if [ "$parport_found" = "false" ] ; then
        echo
        mecho --warn "No parallel port(s) found."
    fi

    echo
    anykey
    do_modules_del

    clrhome
    if /var/install/bin/edit ${configfile} ; then
        echo
        if /var/install/bin/ask "Activate Lprng configuration now" "y" ; then
            sh /etc/init.d/lprng stop
            if [ -d /var/spool/lpd ] ; then
                echo "Removing /var/spool/lpd ..."
                rm -r -f /var/spool/lpd
            fi
            sh /var/install/config.d/lprng.sh
            sh /etc/init.d/lprng start
        fi
    fi

    echo
    mecho --info "If your configuration changed and you want to print over Samba,"
    mecho --info "you have to create a new Samba Configuration now."
    echo
    anykey
else
    echo
    echo "Nothing changed."
    echo
    anykey
fi
