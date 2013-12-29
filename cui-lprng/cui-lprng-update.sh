#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-lprng-update.sh - creating or updating
#                                             /etc/config.d/cui-lprng
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2002-12-22 tb
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
#set -x

. /var/install/include/eislib
. /var/install/include/configlib
added='no'
removed='no'
changed='no'
targetfile=''

case $# in
1)
    mode="$1"
    if [ "$mode" = "update" -o "$mode" = "generate" -o "$mode" = "sample" ] ; then
        if [ "$mode" = "update" ] ; then
            targetfile="/etc/config.d/lprng"
            mecho --info "Updating your configuration file ${targetfile} ..."
        fi

        if [ "$mode" = "generate" ] ; then
            targetfile="/etc/config.d/lprng"
            mecho --info "Generating configuration file ${targetfile} ..."
        fi

        if [ "$mode" = "sample" ] ; then
            targetfile="/etc/default.d/lprng"
            mecho --info "Generating sample configuration file ${targetfile} ..."
        fi
    else
        echo "usage: /var/install/config.d/lprng-update.sh {update|generate|sample} " >&2
        exit 1
    fi
    ;;
*)
    echo "usage: /var/install/config.d/lprng-update.sh {update|generate|sample} " >&2
    exit 1
    ;;
esac

do_update ()
{
 {
  echo "# ------------------------------------------------------------------------------"
  echo "# /etc/config.d/lprng - configuration for LPRng on eisfair"
  echo "#"
  echo "# Copyright (c) 2002-2012 Thomas Bork, tom(at)eisfair(dot)net"
  echo "#"
  echo "# Creation   : 2002-10-06 tb"

  echo "#"
  echo "# Version    : 2.2.1"
  echo "#"
  echo "# This program is free software; you can redistribute it and/or modify"
  echo "# it under the terms of the GNU General Public License as published by"
  echo "# the Free Software Foundation; either version 2 of the License, or"
  echo "# (at your option) any later version."
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# General Settings"
  echo "#"
  echo "# ------------------------------------------------------------------------------"
  echo
  if [ "$LPRNG_START" != "" ] ; then
    START_LPRNG="$LPRNG_START"
  else
    START_LPRNG="$START_LPRNG"
  fi
  printvar "START_LPRNG" "Start on boot: yes or no"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# Local parallel Printer Configuration"
  echo "#"
  echo "# Set the number of parallel printer to use in LPRNG_LOCAL_PARPORT_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_LOCAL_PARPORT_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  if [ -n "$LPRNG_LOCAL_PRINTER_N" ] ; then
    LPRNG_LOCAL_PARPORT_PRINTER_N="$LPRNG_LOCAL_PRINTER_N"
    count=$LPRNG_LOCAL_PRINTER_N
  else
    LPRNG_LOCAL_PARPORT_PRINTER_N="$LPRNG_LOCAL_PARPORT_PRINTER_N"
    count=$LPRNG_LOCAL_PARPORT_PRINTER_N
  fi
  printvar "LPRNG_LOCAL_PARPORT_PRINTER_N" "How many local parallel printers"
  printvar "" "do you want to use"
  echo
  count=`expr $count + 10`
  idx='1'
  while [ "${idx}" -le "$count" ]
  do
    io=''
    active=''
    if [ -n "$LPRNG_LOCAL_PRINTER_N" ] ; then
      eval io='$LPRNG_LOCAL_PRINTER_'${idx}'_IO'
      eval active='$LPRNG_LOCAL_PRINTER_'${idx}'_ACTIVE'
      eval irq='$LPRNG_LOCAL_PRINTER_'${idx}'_IRQ'
      eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_IO="$LPRNG_LOCAL_PRINTER_${idx}_IO"
      eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_ACTIVE="$LPRNG_LOCAL_PRINTER_${idx}_ACTIVE"
      eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_IRQ="$LPRNG_LOCAL_PRINTER_${idx}_IRQ"
    else
      eval io='$LPRNG_LOCAL_PARPORT_PRINTER_'${idx}'_IO'
      eval active='$LPRNG_LOCAL_PARPORT_PRINTER_'${idx}'_ACTIVE'
      eval irq='$LPRNG_LOCAL_PARPORT_PRINTER_'${idx}'_IRQ'
      eval comment='$LPRNG_LOCAL_PARPORT_PRINTER_'${idx}'_COMMENT'
      eval notify='$LPRNG_LOCAL_PARPORT_PRINTER_'${idx}'_NOTIFY'
    fi
    if [ -n "$io" ] ; then
      if [ -z "$active" ] ; then
        eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_ACTIVE="no"
      fi
      printvar "LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_ACTIVE" "Is this printer active: yes or no"
      printvar "LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_IO" "This is the io-adress of the"
      printvar "" "${idx}. parallel printer port"
      if [ -z "$irq" ] ; then
        eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_IRQ="no"
      fi
      printvar "LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_IRQ" "Use interrupt: yes or no"
      printvar "LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_COMMENT" "Comment, Location for NOTIFY"
      if [ -z "$notify" ] ; then
        eval LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_NOTIFY="no"
      fi
      printvar "LPRNG_LOCAL_PARPORT_PRINTER_"${idx}"_NOTIFY" "Send printer messages: yes or no"
      echo
    fi
    idx=`expr ${idx} + 1`
  done
  echo "# ------------------------------------------------------------------------------"
  echo "# Local USB Printer Configuration"
  echo "#"
  echo "# Set the number of USB printer to use in LPRNG_LOCAL_USBPORT_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_LOCAL_USBPORT_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  if [ -z "$LPRNG_LOCAL_USBPORT_PRINTER_N" ] ; then
    echo "LPRNG_LOCAL_USBPORT_PRINTER_N='3'     # How many local USB printers"
    echo "                                      # do you want to use"
    echo
    echo "LPRNG_LOCAL_USBPORT_PRINTER_1_ACTIVE='no'"
    echo "                                      # Is this printer active: yes or no"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_1_COMMENT='1. USB printer port'"
    echo "                                      # Comment, Location for NOTIFY"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_1_NOTIFY='no'"
    echo "                                      # Send printer messages: yes or no"
    echo
    echo "LPRNG_LOCAL_USBPORT_PRINTER_2_ACTIVE='no'"
    echo "                                      # Is this printer active: yes or no"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_2_COMMENT='2. USB printer port'"
    echo "                                      # Comment, Location for NOTIFY"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_2_NOTIFY='no'"
    echo "                                      # Send printer messages: yes or no"
    echo
    echo "LPRNG_LOCAL_USBPORT_PRINTER_3_ACTIVE='no'"
    echo "                                      # Is this printer active: yes or no"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_3_COMMENT='3. USB printer port'"
    echo "                                      # Comment, Location for NOTIFY"
    echo "LPRNG_LOCAL_USBPORT_PRINTER_3_NOTIFY='no'"
    echo "                                      # Send printer messages: yes or no"
    echo
  else
    printvar "LPRNG_LOCAL_USBPORT_PRINTER_N" "How many local USB printers"
    printvar "" "do you want to use"
    echo
    count=`expr $LPRNG_LOCAL_USBPORT_PRINTER_N + 10`
    idx='1'
    while [ "${idx}" -le "$count" ]
    do
      active=''
      eval active='$LPRNG_LOCAL_USBPORT_PRINTER_'${idx}'_ACTIVE'
      eval comment='$LPRNG_LOCAL_USBPORT_PRINTER_'${idx}'_COMMENT'
      eval notify='$LPRNG_LOCAL_USBPORT_PRINTER_'${idx}'_NOTIFY'
      if [ -n "$active" ] ; then
        printvar "LPRNG_LOCAL_USBPORT_PRINTER_"${idx}"_ACTIVE" "Is this printer active: yes or no"
        printvar "LPRNG_LOCAL_USBPORT_PRINTER_"${idx}"_COMMENT" "Comment, Location for NOTIFY"
        if [ -z "$notify" ] ; then
          eval LPRNG_LOCAL_USBPORT_PRINTER_"${idx}"_NOTIFY="no"
        fi
        printvar "LPRNG_LOCAL_USBPORT_PRINTER_"${idx}"_NOTIFY" "Send printer messages: yes or no"
        echo
      fi
      idx=`expr ${idx} + 1`
    done
  fi
  echo "# ------------------------------------------------------------------------------"
  echo "# Remote Printer Configuration"
  echo "#"
  echo "# Set the number of Printer to use in LPRNG_REMOTE_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_REMOTE_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  printvar "LPRNG_REMOTE_PRINTER_N" "How many remote printers do you"
  printvar "" "want to use"
  echo
  count=`expr $LPRNG_REMOTE_PRINTER_N + 10`
  idx='1'
  while [ "${idx}" -le "$count" ]
  do
    active=''
    ip=''
    queuename=''
    port=''
    eval active='$LPRNG_REMOTE_PRINTER_'${idx}'_ACTIVE'
    eval ip='$LPRNG_REMOTE_PRINTER_'${idx}'_IP'
    eval queuename='$LPRNG_REMOTE_PRINTER_'${idx}'_QUEUENAME'
    eval port='$LPRNG_REMOTE_PRINTER_'${idx}'_PORT'
    eval comment='$LPRNG_REMOTE_PRINTER_'${idx}'_COMMENT'
    eval notify='$LPRNG_REMOTE_PRINTER_'${idx}'_NOTIFY'
    if [ -n "$ip" ] ; then
      if [ -z "$active" ] ; then
        eval LPRNG_REMOTE_PRINTER_"${idx}"_ACTIVE="no"
      fi
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_ACTIVE" "Is this printer active: yes or no"
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_IP" "This is the ip of the ${idx}. remote"
      printvar "" "printer"
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_QUEUENAME" "This is the queuename of the ${idx}."
      printvar "" "remote printer - read documentation!"
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_PORT" "This is the port of the ${idx}. remote"
      printvar "" "printer - read documentation!"
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_COMMENT" "Comment, Location for NOTIFY"
      if [ -z "$notify" ] ; then
        eval LPRNG_REMOTE_PRINTER_"${idx}"_NOTIFY="no"
      fi
      printvar "LPRNG_REMOTE_PRINTER_"${idx}"_NOTIFY" "Send printer messages: yes or no"
      echo
    fi
    idx=`expr ${idx} + 1`
  done
 } >"${targetfile}"
}

do_generate ()
{
 {
  echo "# ------------------------------------------------------------------------------"
  echo "# /etc/config.d/lprng - configuration for LPRng on eisfair"
  echo "#"
  echo "# Copyright (c) 2002-2012 Thomas Bork, tom(at)eisfair(dot)net"
  echo "#"
  echo "# Creation   : 2002-10-06 tb"

  echo "#"
  echo "# Version    : 2.2.1"
  echo "#"
  echo "# This program is free software; you can redistribute it and/or modify"
  echo "# it under the terms of the GNU General Public License as published by"
  echo "# the Free Software Foundation; either version 2 of the License, or"
  echo "# (at your option) any later version."
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# General Settings"
  echo "#"
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "START_LPRNG='no'                      # Start on boot: yes or no"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# Local parallel Printer Configuration"
  echo "#"
  echo "# Set the number of parallel printer to use in LPRNG_LOCAL_PARPORT_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_LOCAL_PARPORT_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "LPRNG_LOCAL_PARPORT_PRINTER_N='3'     # How many local parallel printers"
  echo "                                      # do you want to use"
  echo
  echo "LPRNG_LOCAL_PARPORT_PRINTER_1_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_1_IO='0x378'"
  echo "                                      # This is the io-adress of the"
  echo "                                      # 1. parallel printer port"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_1_IRQ='no'"
  echo "                                      # Use interrupt: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_1_COMMENT='1. parallel printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_1_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "LPRNG_LOCAL_PARPORT_PRINTER_2_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_2_IO='0x278'"
  echo "                                      # This is the io-adress of the"
  echo "                                      # 2. parallel printer port"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_2_IRQ='no'"
  echo "                                      # Use interrupt: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_2_COMMENT='2. parallel printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_2_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "LPRNG_LOCAL_PARPORT_PRINTER_3_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_3_IO='0x3bc'"
  echo "                                      # This is the io-adress of the"
  echo "                                      # 3. parallel printerport"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_3_IRQ='no'"
  echo "                                      # Use interrupt: yes or no"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_3_COMMENT='3. parallel printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_PARPORT_PRINTER_3_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# Local USB Printer Configuration"
  echo "#"
  echo "# Set the number of USB printer to use in LPRNG_LOCAL_USBPORT_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_LOCAL_USBPORT_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "LPRNG_LOCAL_USBPORT_PRINTER_N='3'     # How many local USB printers"
  echo "                                      # do you want to use"
  echo
  echo "LPRNG_LOCAL_USBPORT_PRINTER_1_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_1_COMMENT='1. USB printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_1_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "LPRNG_LOCAL_USBPORT_PRINTER_2_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_2_COMMENT='2. USB printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_2_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "LPRNG_LOCAL_USBPORT_PRINTER_3_ACTIVE='no'"
  echo "                                      # Is this printer active: yes or no"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_3_COMMENT='3. USB printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_LOCAL_USBPORT_PRINTER_3_NOTIFY='no'"
  echo "                                      # Send printer messages: yes or no"
  echo
  echo "# ------------------------------------------------------------------------------"
  echo "# Remote Printer Configuration"
  echo "#"
  echo "# Set the number of Printer to use in LPRNG_REMOTE_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# LPRNG_REMOTE_PRINTER_N is '0'"
  echo "# ------------------------------------------------------------------------------"
  echo
  echo "LPRNG_REMOTE_PRINTER_N='4'            # How many remote printers do you"
  echo "                                      # want to use"
  echo
  echo "LPRNG_REMOTE_PRINTER_1_ACTIVE='no'    # Is this printer active: yes or no"
  echo "LPRNG_REMOTE_PRINTER_1_IP='192.168.6.99'"
  echo "                                      # This is the ip of the 1. remote"
  echo "                                      # printer"
  echo "LPRNG_REMOTE_PRINTER_1_QUEUENAME='pr1'"
  echo "                                      # This is the queuename of the 1."
  echo "                                      # remote printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_1_PORT=''        # This is the port of the 1. remote"
  echo "                                      # printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_1_COMMENT='1. remote printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_REMOTE_PRINTER_1_NOTIFY='no'    # Send printer messages: yes or no"
  echo
  echo "LPRNG_REMOTE_PRINTER_2_ACTIVE='no'    # Is this printer active: yes or no"
  echo "LPRNG_REMOTE_PRINTER_2_IP='192.168.6.99'"
  echo "                                      # This is the ip of the 2. remote"
  echo "                                      # printer"
  echo "LPRNG_REMOTE_PRINTER_2_QUEUENAME='pr2'"
  echo "                                      # This is the queuename of the 2."
  echo "                                      # remote printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_2_PORT=''        # This is the port of the 2. remote"
  echo "                                      # printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_2_COMMENT='2. remote printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_REMOTE_PRINTER_2_NOTIFY='no'    # Send printer messages: yes or no"
  echo
  echo "LPRNG_REMOTE_PRINTER_3_ACTIVE='no'    # Is this printer active: yes or no"
  echo "LPRNG_REMOTE_PRINTER_3_IP='192.168.6.111'"
  echo "                                      # This is the ip of the 3. remote"
  echo "                                      # printer"
  echo "LPRNG_REMOTE_PRINTER_3_QUEUENAME=''   # This is the queuename of the 3."
  echo "                                      # remote printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_3_PORT='9100'    # This is the port of the 3. remote"
  echo "                                      # printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_3_COMMENT='3. remote printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_REMOTE_PRINTER_3_NOTIFY='no'    # Send printer messages: yes or no"
  echo
  echo "LPRNG_REMOTE_PRINTER_4_ACTIVE='no'    # Is this printer active: yes or no"
  echo "LPRNG_REMOTE_PRINTER_4_IP='192.168.6.111'"
  echo "                                      # This is the ip of the 4. remote"
  echo "                                      # printer"
  echo "LPRNG_REMOTE_PRINTER_4_QUEUENAME=''   # This is the queuename of the 4."
  echo "                                      # remote printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_4_PORT='9101'    # This is the port of the 4. remote"
  echo "                                      # printer - read documentation!"
  echo "LPRNG_REMOTE_PRINTER_4_COMMENT='4. remote printer port'"
  echo "                                      # Comment, Location for NOTIFY"
  echo "LPRNG_REMOTE_PRINTER_4_NOTIFY='no'    # Send printer messages: yes or no"
  echo
 } >"${targetfile}"
}

if [ "$mode" = "update" ] ; then
  . "${targetfile}"
  # section 'changed parameters'
  if [ -n "`grep LPRNG_START= ${targetfile}`" ] ; then
    changed='yes'
    mecho --warn "Changed: LPRNG_START to START_LPRNG"
  fi
  if [ -n "`grep LPRNG_LOCAL_PRINTER_N= ${targetfile}`" ] ; then
    changed='yes'
    mecho --warn "Changed: LPRNG_LOCAL_PRINTER_N to LPRNG_LOCAL_PARPORT_PRINTER_N"
  fi
  if [ -n "`grep LPRNG_LOCAL_PRINTER_._ACTIVE= ${targetfile}`" ] ; then
    changed='yes'
    mecho --warn "Changed: LPRNG_LOCAL_PRINTER_x_ACTIVE to LPRNG_LOCAL_PARPORT_PRINTER_x_ACTIVE"
  fi
  if [ -n "`grep LPRNG_LOCAL_PRINTER_._IO= ${targetfile}`" ] ; then
    changed='yes'
    mecho --warn "Changed: LPRNG_LOCAL_PRINTER_x_IO to LPRNG_LOCAL_PARPORT_PRINTER_x_IO"
  fi
  # section 'added parameters'
  if [ -z "`grep LPRNG_REMOTE_PRINTER_._ACTIVE ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_REMOTE_PRINTER_x_ACTIVE"
  fi
  if [ -z "`grep LPRNG_LOCAL_USBPORT_PRINTER_N ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_USBPORT_PRINTER_N"
    anykey
    mecho --warn "Added  : LPRNG_LOCAL_USBPORT_PRINTER_x_ACTIVE"
  fi
  if [ -z "`grep LPRNG_LOCAL_PARPORT_PRINTER_._IRQ ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_PARPORT_PRINTER_x_IRQ"
  fi
  if [ -z "`grep LPRNG_LOCAL_PARPORT_PRINTER_._COMMENT ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_PARPORT_PRINTER_x_COMMENT"
  fi
  if [ -z "`grep LPRNG_LOCAL_PARPORT_PRINTER_._NOTIFY ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_PARPORT_PRINTER_x_NOTIFY"
  fi
  if [ -z "`grep LPRNG_LOCAL_USBPORT_PRINTER_._COMMENT ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_USBPORT_PRINTER_x_COMMENT"
  fi
  if [ -z "`grep LPRNG_LOCAL_USBPORT_PRINTER_._NOTIFY ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_LOCAL_USBPORT_PRINTER_x_NOTIFY"
  fi
  if [ -z "`grep LPRNG_REMOTE_PRINTER_._COMMENT ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_REMOTE_PRINTER_x_COMMENT"
  fi
  if [ -z "`grep LPRNG_REMOTE_PRINTER_._NOTIFY ${targetfile}`" ] ; then
    added='yes'
    mecho --warn "Added  : LPRNG_REMOTE_PRINTER_x_NOTIFY"
  fi
  # show info for removed/added/changed parameters
  if [ "$added" = "yes" -o "$changed" = "yes" -o "$removed" = "yes" ] ; then
    mecho --warn "Read documentation for removed/added/changed parameter(s)!"
    anykey
  fi
  do_update
else
  do_generate
fi

chown root.root "${targetfile}"
chmod 0644 "${targetfile}"
