#! /bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/samba-update.sh - creating or updating 
#                                         /etc/config.d/samba
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# usage: /var/install/config.d/samba-update.sh {update|generate|sample}
#
# Creation: 2002-12-03 tb
#
# Version: 2.4.1
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
            targetfile='/etc/config.d/samba'
            mecho --info "Updating your configuration file $targetfile ..."
        fi

        if [ "$mode" = "generate" ] ; then
            targetfile='/etc/config.d/samba'
            mecho --info "Generating configuration file $targetfile ..."
        fi

        if [ "$mode" = "sample" ] ; then
            targetfile='/etc/default.d/samba'
            mecho --info "Generating sample configuration file $targetfile ..."
        fi
    else
        echo "usage: /var/install/config.d/samba-update.sh {update|generate|sample} " >&2
        exit 1
    fi
    ;;
  *)
    echo "usage: /var/install/config.d/samba-update.sh {update|generate|sample} " >&2
    exit 1
    ;;
esac

do_update ()
{
 {
  echo "# ----------------------------------------------------------------------------"
  echo "# /etc/config.d/samba - configuration for Samba on eisfair"
  echo "#"
  echo "# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net"
  echo "#"
  echo "# Creation   : 2002-02-04 tb"
  echo "# Last Update: 2013-12-09 tb"
  echo "#"
  echo "# Version    : 2.4.1"
  echo "#"
  echo "# This program is free software; you can redistribute it and/or modify"
  echo "# it under the terms of the GNU General Public License as published by"
  echo "# the Free Software Foundation; either version 2 of the License, or"
  echo "# (at your option) any later version."
  echo "# ----------------------------------------------------------------------------"
  echo
  echo "# ----------------------------------------------------------------------------"
  echo "# General Settings"
  echo "#"
  echo "# Minimum requirement if SAMBA_MANUAL_CONFIGURATION='no' is to change"
  echo "# SAMBA_WORKGROUP to workgroup name of your windows clients!"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo

  if [ -n "$SAMBA_START" ] ; then
      START_SAMBA="$SAMBA_START"
  fi

  printvar "START_SAMBA" "Start on boot: yes or no"
  echo
  printvar "SAMBA_WORKGROUP" "Workgroup name of windows-client"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Manual or Automatic Configuration"
  echo "#"
  echo "# Manual or Automatic Configuration of Shares and Printers"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *     If you set SAMBA_MANUAL_CONFIGURATION to 'no', the Settings        *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Shares' and      *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Printers' and    *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Mounts'          *"
  echo "#  *                         don't have an Effect!                          *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# If you set SAMBA_MANUAL_CONFIGURATION='no', following Shares automatically"
  echo "# created for you:"
  echo "#"
  echo "# - a share with your eisfair-username and full access only for you"
  echo "# - a share 'public' with full access for all eisfair-users"
  echo "# - an unvisible share 'all' with full access for user root"
  echo "#   for the whole filesystem"
  echo "# - shares for your printers in /etc/printcap, if lprng is installed"
  echo "# - a printer share for eisfax printer, if eisfax is installed"
  echo "# - a printer share for pdf printing, if ghostscript is installed"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo

  if [ -n "$SAMBA_AUTO_CONFIGURATION" ] ; then
      if [ "$SAMBA_AUTO_CONFIGURATION" = "yes" ] ; then
          SAMBA_MANUAL_CONFIGURATION='no'
      else
          SAMBA_MANUAL_CONFIGURATION='yes'
      fi
  fi

  printvar "SAMBA_MANUAL_CONFIGURATION" "Use manual configuration:"
  printvar "" "yes or no"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration"
  echo "#"
  echo "# Please don't use this, if you are not very familar with Samba!"
  echo "# Support for this Section is not available!"
  echo "#"
  echo "# Special General Settings"
  echo "# and"
  echo "# Individual Configuration of Shares and Printers"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Special General Settings"
  echo "# ----------------------------------------------------------------------------" 
  echo
  printvar "SAMBA_INTERFACES" "Userdefined interfaces for Samba"
  printvar "" "Be carefull, use this only, if you"
  printvar "" "don't want to use all interfaces from"
  printvar "" "/etc/config.d/base"
  printvar "" "You have to specify interfaces like"
  printvar "" "this: '192.168.7.1/255.255.255.0'"
  echo
  printvar "SAMBA_TRUSTED_NETS" "If your network is 192.168.6.0/24"
  printvar "" "and you want to grant access also"
  printvar "" "to net 192.168.7.0/24, you have to"
  printvar "" "add this here like this:"
  printvar "" "'192.168.7.0/24'"
  echo
  printvar "SAMBA_DEBUGLEVEL" "For debugging only: 0-10"
  printvar "" "You will find debug messages in"
  printvar "" "/var/log/log.smbd, /var/log/log.nmbd"
  echo ""
  printvar "SAMBA_MASTERBROWSER" "Act as an masterbrowser: yes or no"
  echo
  printvar "SAMBA_WINSSERVER" "Act as an WINS-Server: yes or no"
  printvar "" "If yes, don't set SAMBA_EXTWINSIP!"
  echo

  if [ -z "$SAMBA_WINSHOOK" ] ; then
      SAMBA_WINSHOOK='no'
  fi

  printvar "SAMBA_WINSHOOK" "Trigger extra actions, if act as an"
  printvar "" "WINS-Server: yes or no"
  echo

  if [ -z "$SAMBA_WINSHOOK_MESSAGE_SEND" ] ; then
      SAMBA_WINSHOOK_MESSAGE_SEND='no'
  fi

  printvar "SAMBA_WINSHOOK_MESSAGE_SEND" "Send messages to WINS clients:"
  printvar "" "yes or no"
  echo

  if [ -z "$SAMBA_WINSHOOK_MESSAGE" ] ; then
      SAMBA_WINSHOOK_MESSAGE="Welcome to eisfair server"
  fi

  printvar "SAMBA_WINSHOOK_MESSAGE" ""
  printvar "" "This message will diplayed on"
  printvar "" "registering to eisfair"
  echo

  if [ -z "$SAMBA_WINSHOOK_DNSUPDATE" ] ; then
      SAMBA_WINSHOOK_DNSUPDATE='no'
  fi

  printvar "SAMBA_WINSHOOK_DNSUPDATE" "Updating local bind with WINS"
  printvar "" "clients: yes or no"
  echo
  printvar "SAMBA_EXTWINSIP" "IP address of external WINS-Server,"
  printvar "" "if exist, act as an WINS-Client"
  printvar "" "Don't set SAMBA_WINSSERVER to 'yes'!"
  echo

  if [ -n "$SAMBA_SHOW_START_MESSAGE" ] ; then
      SAMBA_START_MESSAGE_SEND="$SAMBA_SHOW_START_MESSAGE"
  fi

  printvar "SAMBA_START_MESSAGE_SEND" "Send start message on Samba start:"
  printvar "" "yes or no"
  echo
  printvar "SAMBA_START_MESSAGE" ""
  printvar "" "This message will diplayed on start"
  printvar "" "on WIN9x-clients with winpopup and"
  printvar "" "WIN NT, WIN2K, WINXP"
  echo

  if [ -n "$SAMBA_SHOW_SHUTDOWN_MESSAGE" ] ; then
      SAMBA_SHUTDOWN_MESSAGE_SEND="$SAMBA_SHOW_SHUTDOWN_MESSAGE"
  fi

  printvar "SAMBA_SHUTDOWN_MESSAGE_SEND" "Send shutdown message"
  printvar "" "yes or no"
  echo
  printvar "SAMBA_SHUTDOWN_MESSAGE" ""
  printvar "" "This message will diplayed on shut-down"
  printvar "" "on WIN9x-clients with winpopup and"
  printvar "" "WIN NT, WIN2K, WINXP"
  echo

  if [ -z "$SAMBA_SHUTDOWN_MESSAGE_HOSTS" ] ; then
      SAMBA_SHUTDOWN_MESSAGE_HOSTS='all'
  fi

  printvar "SAMBA_SHUTDOWN_MESSAGE_HOSTS" "Target hosts for"
  printvar "" "SAMBA_SHOW_SHUTDOWN_MESSAGE:"
  printvar "" "all or active"
  echo

  SAMBA_LOCALIZATION='UTF-8'

  printvar "SAMBA_LOCALIZATION" "Language adjustment, affected to unix"
  printvar "" "character set and client codepage"
  printvar "" "US        : United States (CP 437)"
  printvar "" "ISO8859-1 : Western Europe (CP 850)"
  printvar "" "ISO8859-2 : Eastern Europe (CP 852)"
  printvar "" "ISO8859-5 : Russian Cyrillic (CP 866)"
  printvar "" "ISO8859-7 : Greek (CP 737)"
  printvar "" "ISO8859-15: Western Europe with EURO"
  printvar "" "     UTF-8: Western Europe with eisfair-2"
  echo
  printvar "SAMBA_PDC" "Should Samba act as an Primary Domain"
  printvar "" "Controller: yes or no"
  printvar "" "Read Documentation!"
  echo

  if [ -n "$SAMBA_PROFILES" ] ; then
      SAMBA_PDC_PROFILES="$SAMBA_PROFILES"
  fi

  if [ -z "$SAMBA_PDC_PROFILES" ] ; then
      SAMBA_PDC_PROFILES='yes'
  fi

  printvar "SAMBA_PDC_PROFILES" "Should Samba store roaming profiles"
  printvar "" "if acting as an Primary Domain"
  printvar "" "Controller: yes or no"
  echo

  if [ -z "$SAMBA_PDC_LOGONSCRIPT" ] ; then
      SAMBA_PDC_LOGONSCRIPT='user'
  fi

  printvar "SAMBA_PDC_LOGONSCRIPT" "PDC logon script:"
  printvar "" "'user', 'group', 'machine' or 'all'"
  echo
  printvar "SAMBA_PASSWORD_SERVER" "NETBIOS name(s) of external password"
  printvar "" "server(s) separated by a comma and"
  printvar "" "a blank. Example:"
  printvar "" "SAMBA_PASSWORD_SERVER='NT-PDC, NT-BDC1'"
  printvar "" "SAMBA_PASSWORD_SERVER='*'"
  printvar "" "Be shure, you have access from Samba to"
  printvar "" "password server(s)!"
  echo

  if [ -z "$SAMBA_RECYCLE_BIN" ] ; then
      SAMBA_RECYCLE_BIN='no'
  fi

  printvar "SAMBA_RECYCLE_BIN" "Activate recycle bin in shares"
  echo

  if [ -z "$SAMBA_RECYCLE_BIN_HOLD_DAYS" ] ; then
      SAMBA_RECYCLE_BIN_HOLD_DAYS='7'
  fi

  printvar "SAMBA_RECYCLE_BIN_HOLD_DAYS" "Hold files for n days in recycle bin"
  echo

  if [ -z "$SAMBA_PDF_TARGET" ] ; then
      SAMBA_PDF_TARGET='homedir'
  fi

  printvar "SAMBA_PDF_TARGET" "Target for created pdf files:"
  printvar "" "'homedir', 'public' or 'mail'"
  echo

  if [ -z "$SAMBA_SERVERSTRING" ] ; then
      SAMBA_SERVERSTRING=''
  fi

  printvar "SAMBA_SERVERSTRING" "Comment in network neighborhood:"
  printvar "" "empty for no string"
  printvar "" "or anything else for your string"
  echo

  if [ -z "$SAMBA_EXPERT_EXEC" ] ; then
      SAMBA_EXPERT_EXEC='no'
  fi

  printvar "SAMBA_EXPERT_EXEC" "Exec sambaexpert: yes or no"
  printvar "" "Don't ask for help, while"
  printvar "" "this is activated!"
  echo

  if [ -z "$SAMBA_SMBWEBCLIENT" ] ; then
      SAMBA_SMBWEBCLIENT='no'
  fi

  printvar "SAMBA_SMBWEBCLIENT" "Install smbwebclient: yes or no"
  echo

  if [ -z "$SAMBA_SMBWEBCLIENT_PATH" ] ; then
      SAMBA_SMBWEBCLIENT_PATH='/var/www/htdocs'
  fi

  printvar "SAMBA_SMBWEBCLIENT_PATH" ""
  printvar "" "Install smbwebclient to this apache"
  printvar "" "document root"
  echo

  if [ -z "$SAMBA_OPLOCKS" ] ; then
      SAMBA_OPLOCKS='no'
  fi

  printvar "SAMBA_OPLOCKS" "activate oplocking (caching): yes or no"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba User Mappings"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# Definition of Samba User Mappings"
  echo "#"
  echo "# Set the number of Samba User Mappings to create in SAMBA_USERMAP_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_USERMAP_N is '0'"
  echo "#-----------------------------------------------------------------------------"
  echo

  if [ -z "$SAMBA_USERMAP_N" ] ; then
      echo "SAMBA_USERMAP_N='2'                   # How many user mappings do you want to"
      echo "                                      # create"
      echo
      echo "SAMBA_USERMAP_1_ACTIVE='yes'          # Is this mapping active: yes or no"
      echo "SAMBA_USERMAP_1_EISNAME='root'        # This is the eisfair user name of the"
      echo "                                      # 1. mapping"
      echo "SAMBA_USERMAP_1_WINNAME_N='1'         # How many windows names should be mapped"
      echo "                                      # to the 1. eisfair user name"
      echo "SAMBA_USERMAP_1_WINNAME_1='Administrator'"
      echo "                                      # This is the 1. windows name which"
      echo "                                      # should be mapped to the 1. eisfair user"
      echo
      echo "SAMBA_USERMAP_2_ACTIVE='no'           # Is this mapping active: yes or no"
      echo "SAMBA_USERMAP_2_EISNAME='jimknopf'    # This is the eisfair user name of the"
      echo "                                      # 2. mapping"
      echo "SAMBA_USERMAP_2_WINNAME_N='2'         # How many windows names should be mapped"
      echo "                                      # to the 2. eisfair user name"
      echo "SAMBA_USERMAP_2_WINNAME_1='Jim Knopf'"
      echo "                                      # This is the 1. windows name which"
      echo "                                      # should be mapped to the 2. eisfair user"
      echo "SAMBA_USERMAP_2_WINNAME_2='Jim Jeremy Knopf'"
      echo "                                      # This is the 2. windows name which"
      echo "                                      # should be mapped to the 2. eisfair user"
      echo
  else
      printvar "SAMBA_USERMAP_N" "How many user mappings do you want to"
      printvar "" "create"
      echo

      count=`/usr/bin/expr $SAMBA_USERMAP_N + 10`
      idx='1'
      eisname=''
      while [ "$idx" -le "$count" ] ; do
          eval active='$SAMBA_USERMAP_'$idx'_ACTIVE'
          eval eisname='$SAMBA_USERMAP_'$idx'_EISNAME'
          eval winname_n='$SAMBA_USERMAP_'$idx'_WINNAME_N'

          if [ -n "$eisname" ] ; then
              if [ -z "$active" ] ; then
                  eval SAMBA_USERMAP_"$idx"_ACTIVE='yes'
              fi

              printvar "SAMBA_USERMAP_"$idx"_ACTIVE" "Is this mapping active: yes or no"
              printvar "SAMBA_USERMAP_"$idx"_EISNAME" "This is the eisfair user name of the"
              printvar "" "$idx. mapping"
              printvar "SAMBA_USERMAP_"$idx"_WINNAME_N" "How many windows name should be mapped"
              printvar "" "to the $idx. eisfair user name"

              count1=`/usr/bin/expr $winname_n + 10`
              idy='1'
              while [ "$idy" -le "$count1" ] ; do
                  eval winname='$SAMBA_USERMAP_'$idx'_WINNAME_'$idy
                  if [ -n "$winname" ] ; then
                      printvar "SAMBA_USERMAP_"$idx"_WINNAME_"$idy"" ""
                      printvar "" "This is the $idy. windows name which"
                      printvar "" "should be mapped to the $idx. eisfair user"
                  fi
                  idy=`/usr/bin/expr $idy + 1`
              done
              echo
          fi
          idx=`/usr/bin/expr $idx + 1`
      done
  fi

  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Shares"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# Definition of Samba Shares"
  echo "#"
  echo "# Set the number of Samba Shares to create in SAMBA_SHARE_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_SHARE_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  printvar "SAMBA_SHARE_N" "How many shares you want to create"
  echo

  count=`/usr/bin/expr $SAMBA_SHARE_N + 10`
  idx='1'
  name=''
  while [ "$idx" -le "$count" ] ; do
      eval active='$SAMBA_SHARE_'$idx'_ACTIVE'
      eval name='$SAMBA_SHARE_'$idx'_NAME'
      eval comment='$SAMBA_SHARE_'$idx'_COMMENT'
      eval rw='$SAMBA_SHARE_'$idx'_RW'
      eval browse='$SAMBA_SHARE_'$idx'_BROWSE'
      eval path='$SAMBA_SHARE_'$idx'_PATH'
      eval user='$SAMBA_SHARE_'$idx'_USER'
      eval public='$SAMBA_SHARE_'$idx'_PUBLIC'
      eval readlist='$SAMBA_SHARE_'$idx'_READ_LIST'
      eval writelist='$SAMBA_SHARE_'$idx'_WRITE_LIST'
      eval create_mask='$SAMBA_SHARE_'$idx'_CREATE_MASK'
      eval directory_mask='$SAMBA_SHARE_'$idx'_DIRECTORY_MASK'
      eval force_cmode='$SAMBA_SHARE_'$idx'_FORCE_CMODE'
      eval force_dirmode='$SAMBA_SHARE_'$idx'_FORCE_DIRMODE'
      eval force_user='$SAMBA_SHARE_'$idx'_FORCE_USER'
      eval force_group='$SAMBA_SHARE_'$idx'_FORCE_GROUP'

      if [ -n "$name" ] ; then
          if [ -z "$active" ] ; then
              eval SAMBA_SHARE_"$idx"_ACTIVE='yes'
          fi

          printvar "SAMBA_SHARE_"$idx"_ACTIVE" "Is this share active: yes or no"
          printvar "SAMBA_SHARE_"$idx"_NAME" "This is the name of the $idx. share"
          printvar "SAMBA_SHARE_"$idx"_COMMENT" ""
          printvar "" "Comment of the $idx. share"
          printvar "SAMBA_SHARE_"$idx"_RW" "Should share writeable: yes or no"
          printvar "SAMBA_SHARE_"$idx"_BROWSE" "Should share browseable: yes or no"
          printvar "SAMBA_SHARE_"$idx"_PATH" "Path of the share in filesystem"

          if [ "$name" = "homes" ] ; then
              eval SAMBA_SHARE_"$idx"_USER='%S'
          fi

          printvar "SAMBA_SHARE_"$idx"_USER" "Allowed user/groups for $idx. share"
          printvar "SAMBA_SHARE_"$idx"_PUBLIC" "Share accessable for all: yes or no"
          printvar "SAMBA_SHARE_"$idx"_READ_LIST" "Share only readable for"
          printvar "SAMBA_SHARE_"$idx"_WRITE_LIST" "Share only writeable for"

          if [ -n "$create_mask" ] ; then
              eval SAMBA_SHARE_"$idx"_FORCE_CMODE='$SAMBA_SHARE_'$idx'_CREATE_MASK'
          fi

          printvar "SAMBA_SHARE_"$idx"_FORCE_CMODE" "Rights for created files"

          if [ -n "$directory_mask" ] ; then
              eval SAMBA_SHARE_"$idx"_FORCE_DIRMODE='$SAMBA_SHARE_'$idx'_DIRECTORY_MASK'
          fi

          printvar "SAMBA_SHARE_"$idx"_FORCE_DIRMODE" "Rights for created directories"
          printvar "SAMBA_SHARE_"$idx"_FORCE_USER" "User for all file operations"
          printvar "SAMBA_SHARE_"$idx"_FORCE_GROUP" "Group for all file operations"
          echo
      fi
      idx=`/usr/bin/expr $idx + 1`
  done

  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba DFS Roots"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba DFS Roots"
  echo "#"
  echo "# Set the number of Samba DFS Roots to create in SAMBA_DFSROOT_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_DFSROOT_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo

  if [ -z "$SAMBA_DFSROOT_N" ] ; then
      echo "SAMBA_DFSROOT_N='1'                   # How many DFS roots do you want"
      echo
      echo "SAMBA_DFSROOT_1_ACTIVE='no'           # Activate this DFS root: yes or no"
      echo "SAMBA_DFSROOT_1_NAME='dfs1'           # This is the name of the $idx. DFS root"
      echo "SAMBA_DFSROOT_1_COMMENT=''            # Comment of the $idx. DFS root"
      echo "SAMBA_DFSROOT_1_RW='yes'              # Should DFS root be writeable: yes or no"
      echo "SAMBA_DFSROOT_1_BROWSE='yes'          # Should DFS root be browseable: yes or no"
      echo "SAMBA_DFSROOT_1_USER=''               # Allowed user/groups for this DFS root"
      echo "SAMBA_DFSROOT_1_PUBLIC='yes'          # DFS root accessable for all: yes or no"
      echo "SAMBA_DFSROOT_1_READ_LIST=''          # DFS root only readable for"
      echo "SAMBA_DFSROOT_1_WRITE_LIST=''         # DFS root only writeable for"
      echo "SAMBA_DFSROOT_1_FORCE_CMODE=''        # Rights for created files"
      echo "SAMBA_DFSROOT_1_FORCE_DIRMODE=''      # Rights for created directories"
      echo "SAMBA_DFSROOT_1_FORCE_USER=''         # User for all file operations"
      echo "SAMBA_DFSROOT_1_FORCE_GROUP=''        # Group for all file operations"
      echo "SAMBA_DFSROOT_1_DFSLNK_N='1'          # How many links should be created"
      echo "SAMBA_DFSROOT_1_DFSLNK_1_ACTIVE='yes' # Should this link active: yes or no"
      echo "SAMBA_DFSROOT_1_DFSLNK_1_SUBPATH=''   # Sub directory for this link"
      echo "SAMBA_DFSROOT_1_DFSLNK_1_NAME='users' # Name of the link"
      echo "SAMBA_DFSROOT_1_DFSLNK_1_UNC_N='1'    # How many unc pathes should be created"
      echo "SAMBA_DFSROOT_1_DFSLNK_1_UNC_1_PATH='\\\\userserver1\\users'"
      echo "                                      # unc path for this link"
      echo
  else
      printvar "SAMBA_DFSROOT_N" "How many DFS roots do you want"
      echo

      count=`/usr/bin/expr $SAMBA_DFSROOT_N + 10`
      idx='1'
      name=''
      while [ "$idx" -le "$count" ] ; do
          eval active='$SAMBA_DFSROOT_'$idx'_ACTIVE'
          eval name='$SAMBA_DFSROOT_'$idx'_NAME'
          eval comment='$SAMBA_DFSROOT_'$idx'_COMMENT'
          eval rw='$SAMBA_DFSROOT_'$idx'_RW'
          eval browse='$SAMBA_DFSROOT_'$idx'_BROWSE'
          eval user='$SAMBA_DFSROOT_'$idx'_USER'
          eval public='$SAMBA_DFSROOT_'$idx'_PUBLIC'
          eval readlist='$SAMBA_DFSROOT_'$idx'_READ_LIST'
          eval writelist='$SAMBA_DFSROOT_'$idx'_WRITE_LIST'
          eval force_cmode='$SAMBA_DFSROOT_'$idx'_FORCE_CMODE'
          eval force_dirmode='$SAMBA_DFSROOT_'$idx'_FORCE_DIRMODE'
          eval force_user='$SAMBA_DFSROOT_'$idx'_FORCE_USER'
          eval force_group='$SAMBA_DFSROOT_'$idx'_FORCE_GROUP'
          eval msdfs_lnkn_count='$SAMBA_DFSROOT_'$idx'_DFSLNK_N'

          if [ -n "$name" ] ; then
              printvar "SAMBA_DFSROOT_"$idx"_ACTIVE" "Activate this DFS root: yes or no"
              printvar "SAMBA_DFSROOT_"$idx"_NAME" "This is the name of the $idx. DFS root"
              printvar "SAMBA_DFSROOT_"$idx"_COMMENT" "Comment of the $idx. DFS root"
              printvar "SAMBA_DFSROOT_"$idx"_RW" "Should DFS root be writeable: yes or no"
              printvar "SAMBA_DFSROOT_"$idx"_BROWSE" "Should DFS root be browseable: yes or no"
              printvar "SAMBA_DFSROOT_"$idx"_USER" "Allowed user/groups for this DFS root"
              printvar "SAMBA_DFSROOT_"$idx"_PUBLIC" "DFS root accessable for all: yes or no"
              printvar "SAMBA_DFSROOT_"$idx"_READ_LIST" "DFS root only readable for"
              printvar "SAMBA_DFSROOT_"$idx"_WRITE_LIST" "DFS root only writeable for"
              printvar "SAMBA_DFSROOT_"$idx"_FORCE_CMODE" "Rights for created files"
              printvar "SAMBA_DFSROOT_"$idx"_FORCE_DIRMODE" "Rights for created directories"
              printvar "SAMBA_DFSROOT_"$idx"_FORCE_USER" "User for all file operations"
              printvar "SAMBA_DFSROOT_"$idx"_FORCE_GROUP" "Group for all file operations"
              printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_N" "How many links should be created"

              msdfs_lnkn_count=`/usr/bin/expr $msdfs_lnkn_count + 10`
              idy='1'
              msdfs_lnkn_name=''
              while [ "$idy" -le "$msdfs_lnkn_count" ] ; do
                  eval msdfs_lnkn_active='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_ACTIVE'
                  eval msdfs_lnkn_subpath='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_SUBPATH'
                  eval msdfs_lnkn_name='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_NAME'
                  eval msdfs_lnkn_uncn='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_UNC_N'

                  if [ -n "$msdfs_lnkn_name" ] ; then
                      printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_"$idy"_ACTIVE" "Should this link active: yes or no"
                      printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_"$idy"_SUBPATH" "Sub directory for this link"
                      printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_"$idy"_NAME" "Name of the link"
                      printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_"$idy"_UNC_N" "How many unc pathes should be created"

                      eval msdfs_lnkn_uncn_count='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_UNC_N'
                      idz='1'
                      msdfs_lnkn_uncn_count=`/usr/bin/expr $msdfs_lnkn_uncn_count + 10`
                      while [ "$idz" -le "$msdfs_lnkn_uncn_count" ] ; do
                          eval msdfs_lnkn_uncn_path='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_UNC_'$idz'_PATH'
                          if [ -n "$msdfs_lnkn_uncn_path" ] ; then
                              printvar "SAMBA_DFSROOT_"$idx"_DFSLNK_"$idy"_UNC_"$idz"_PATH" ""
                              printvar "" "unc path for this link"
                          fi
                          idz=`/usr/bin/expr $idz + 1`
                      done
                  fi
                  idy=`/usr/bin/expr $idy + 1`
              done
          fi
          idx=`/usr/bin/expr $idx + 1`
      done
      echo
  fi

  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Printers"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba Printers"
  echo "#"
  echo "# Set the number of Samba Printers to use in SAMBA_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_PRINTER_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  printvar "SAMBA_PRINTER_N" "How many printers you want to use"
  echo

  count=`/usr/bin/expr $SAMBA_PRINTER_N + 10`
  idx='1'
  name=''
  while [ "$idx" -le "$count" ] ; do
      eval active='$SAMBA_PRINTER_'$idx'_ACTIVE'
      eval name='$SAMBA_PRINTER_'$idx'_NAME'
      eval type='$SAMBA_PRINTER_'$idx'_TYPE'
      eval pdfoption='$SAMBA_PRINTER_'$idx'_PDF_OPTION'
      eval pdfquality='$SAMBA_PRINTER_'$idx'_PDF_QUALITY'
      eval ownerpass='$SAMBA_PRINTER_'$idx'_PDF_OWNERPASS'
      eval userpass='$SAMBA_PRINTER_'$idx'_PDF_USERPASS'
      eval pdfpermissions='$SAMBA_PRINTER_'$idx'_PDF_PERMS'
      eval pdfmessages='$SAMBA_PRINTER_'$idx'_PDF_MESSAGES'
      eval capname='$SAMBA_PRINTER_'$idx'_CAPNAME'
      eval comment='$SAMBA_PRINTER_'$idx'_COMMENT'
      eval browse='$SAMBA_PRINTER_'$idx'_BROWSE'
      eval clientdriver='$SAMBA_PRINTER_'$idx'_CLIENTDRIVER'
      eval user='$SAMBA_PRINTER_'$idx'_USER'
      eval public='$SAMBA_PRINTER_'$idx'_PUBLIC'

      if [ -n "$name" ] ; then
          if [ -z "$active" ] ; then
              eval SAMBA_PRINTER_"$idx"_ACTIVE='yes'
          fi

          printvar "SAMBA_PRINTER_"$idx"_ACTIVE" "Is this printer active: yes or no"
          printvar "SAMBA_PRINTER_"$idx"_NAME" "This is the name of the $idx. printer"

          if [ -z "$type" ] ; then
              if [ -n "$pdfoption" -o -n "$pdfquality" ] ; then
                  eval SAMBA_PRINTER_"$idx"_TYPE='pdf'
                  eval type='$SAMBA_PRINTER_'$idx'_TYPE'
              fi

              if [ -n "$capname" ] ; then
                  eval SAMBA_PRINTER_"$idx"_TYPE='printcap'
              fi

              if [ "$name" = "eisfax" ] ; then
                  eval SAMBA_PRINTER_"$idx"_TYPE='fax'
              fi
          fi

          printvar "SAMBA_PRINTER_"$idx"_TYPE" "Type of the $idx. printer"

          if [ -z "$pdfquality" ] ; then
              if [ -n "$pdfoption" ] ; then
                  eval SAMBA_PRINTER_"$idx"_PDF_QUALITY='$SAMBA_PRINTER_'$idx'_PDF_OPTION'
              else
                  if [ "$name" = "pdf" ] ; then
                      eval SAMBA_PRINTER_"$idx"_PDF_QUALITY='default'
                  fi
              fi
          fi

          if [ -z "$pdfmessages" ] ; then
              eval SAMBA_PRINTER_"$idx"_PDF_MESSAGES='yes'
          fi

          printvar "SAMBA_PRINTER_"$idx"_PDF_QUALITY" "Quality of pdf files"
          printvar "SAMBA_PRINTER_"$idx"_PDF_OWNERPASS" "Password for editing PDF files"
          printvar "SAMBA_PRINTER_"$idx"_PDF_USERPASS" "Password for opening PDF files"
          printvar "SAMBA_PRINTER_"$idx"_PDF_PERMS" "Permissions for PDF files"
          printvar "SAMBA_PRINTER_"$idx"_PDF_MESSAGES" "Messages for PDF files: yes or no"
          printvar "SAMBA_PRINTER_"$idx"_CAPNAME" "The name of the $idx. printer in"
          printvar "" "/etc/printcap"
          printvar "SAMBA_PRINTER_"$idx"_COMMENT" ""
          printvar "" "Comment of the $idx. printer"

          if [ -z "$clientdriver" ] ; then
              eval SAMBA_PRINTER_"$idx"_CLIENTDRIVER='yes'
          fi

          printvar "SAMBA_PRINTER_"$idx"_CLIENTDRIVER" "Use clientdriver for the $idx. printer:"
          printvar "" "yes or no"
          printvar "SAMBA_PRINTER_"$idx"_BROWSE" "Should printer browseable: yes or no"
          printvar "SAMBA_PRINTER_"$idx"_USER" "Allowed user/groups for $idx. printer"
          printvar "SAMBA_PRINTER_"$idx"_PUBLIC" "Printer accessable for all: yes or no"
          echo
      fi
      idx=`/usr/bin/expr $idx + 1`
  done

  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Mounts"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba Mounts"
  echo "#"
  echo "# Set the number of Samba Mounts to use in SAMBA_MOUNT_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_MOUNT_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo

  if [ -z "$SAMBA_MOUNT_N" ] ; then
      echo "SAMBA_MOUNT_N='2'                     # How many remote shares you want to mount"
      echo
      echo "SAMBA_MOUNT_1_ACTIVE='no'             # Is this mount active: yes or no"
      echo "SAMBA_MOUNT_1_VFSTYPE='smbfs'         # The virtual file system type"
      echo "SAMBA_MOUNT_1_SERVER='fli4l'          # The netbios name of the 1. server"
      echo "SAMBA_MOUNT_1_SHARE='share1'          # The name of the 1. share to mount"
      echo "SAMBA_MOUNT_1_POINT='/mountpoint1'    # Where you want to mount the share"
      echo "SAMBA_MOUNT_1_USER=''                 # The user name for share access"
      echo "SAMBA_MOUNT_1_PASS=''                 # The password for share access"
      echo "SAMBA_MOUNT_1_RW='yes'                # Should share writeable: yes or no"
      echo "SAMBA_MOUNT_1_UID=''                  # Mount share with uid/username"
      echo "SAMBA_MOUNT_1_GID=''                  # Mount share with gid/groupname"
      echo "SAMBA_MOUNT_1_FMASK=''                # Mount share with file umask"
      echo "SAMBA_MOUNT_1_DMASK=''                # Mount share with directory umask"
      echo "SAMBA_MOUNT_1_IOCHARSET=''            # Mount share with linux charset"
      echo "SAMBA_MOUNT_1_CODEPAGE=''             # Mount share with server codepage"
      echo
      echo "SAMBA_MOUNT_2_ACTIVE='no'             # Is this mount active: yes or no"
      echo "SAMBA_MOUNT_2_VFSTYPE='smbfs'         # The virtual file system type"
      echo "SAMBA_MOUNT_2_SERVER='ente'           # The netbios name of the 1. server"
      echo "SAMBA_MOUNT_2_SHARE='downloads'       # The name of the 1. share to mount"
      echo "SAMBA_MOUNT_2_POINT='/mountpoint2'    # Where you want to mount the share"
      echo "SAMBA_MOUNT_2_USER='king'             # The user name for share access"
      echo "SAMBA_MOUNT_2_PASS='kong'             # The password for share access"
      echo "SAMBA_MOUNT_2_RW='yes'                # Should share writeable: yes or no"
      echo "SAMBA_MOUNT_2_UID='root'              # Mount share with uid/username"
      echo "SAMBA_MOUNT_2_GID='root'              # Mount share with gid/groupname"
      echo "SAMBA_MOUNT_2_FMASK='0777'            # Mount share with file umask"
      echo "SAMBA_MOUNT_2_DMASK='0777'            # Mount share with directory umask"
      echo "SAMBA_MOUNT_2_IOCHARSET='iso8859-1'   # Mount share with linux charset"
      echo "SAMBA_MOUNT_2_CODEPAGE='cp850'        # Mount share with server codepage"
      echo
  else
      printvar "SAMBA_MOUNT_N" "How many remote shares you want to mount"
      echo

      count=`/usr/bin/expr $SAMBA_MOUNT_N + 10`
      idx='1'
      server=''
      while [ "$idx" -le "$count" ] ; do
          eval active='$SAMBA_MOUNT_'$idx'_ACTIVE'
          eval vfstype='$SAMBA_MOUNT_'$idx'_VFSTYPE'
          eval server='$SAMBA_MOUNT_'$idx'_SERVER'
          eval share='$SAMBA_MOUNT_'$idx'_SHARE'
          eval point='$SAMBA_MOUNT_'$idx'_POINT'
          eval user='$SAMBA_MOUNT_'$idx'_USER'
          eval pass='$SAMBA_MOUNT_'$idx'_PASS'
          eval rw='$SAMBA_MOUNT_'$idx'_RW'
          eval uid='$SAMBA_MOUNT_'$idx'_UID'
          eval gid='$SAMBA_MOUNT_'$idx'_GID'
          eval fmask='$SAMBA_MOUNT_'$idx'_FMASK'
          eval dmask='$SAMBA_MOUNT_'$idx'_DMASK'
          eval iocharset='$SAMBA_MOUNT_'$idx'_IOCHARSET'
          eval codepage='$SAMBA_MOUNT_'$idx'_CODEPAGE'

          if [ -n "$server" ] ; then
              if [ -z "$active" ] ; then
                  eval SAMBA_MOUNT_"$idx"_ACTIVE='yes'
              fi

              printvar "SAMBA_MOUNT_"$idx"_ACTIVE" "Is this mount active: yes or no"

              if [ -z "$vfstype" ] ; then
                  eval SAMBA_MOUNT_"$idx"_VFSTYPE='smbfs'
              fi

              printvar "SAMBA_MOUNT_"$idx"_VFSTYPE" "The virtual file system type"
              printvar "SAMBA_MOUNT_"$idx"_SERVER" "The netbios name of the $idx. server"
              printvar "SAMBA_MOUNT_"$idx"_SHARE" "The name of the $idx. share to mount"
              printvar "SAMBA_MOUNT_"$idx"_POINT" "Where you want to mount the share"
              printvar "SAMBA_MOUNT_"$idx"_USER" "The user name for share access"
              printvar "SAMBA_MOUNT_"$idx"_PASS" "The password for share access"
              printvar "SAMBA_MOUNT_"$idx"_RW" "Should share writeable: yes or no"
              printvar "SAMBA_MOUNT_"$idx"_UID" "Mount share with uid/username"
              printvar "SAMBA_MOUNT_"$idx"_GID" "Mount share with gid/groupname"
              printvar "SAMBA_MOUNT_"$idx"_FMASK" "Mount share with file umask"
              printvar "SAMBA_MOUNT_"$idx"_DMASK" "Mount share with directory umask"
              printvar "SAMBA_MOUNT_"$idx"_IOCHARSET" "Mount share with linux charset"
              printvar "SAMBA_MOUNT_"$idx"_CODEPAGE" "Mount with server codepage (only smbfs)"
              echo
          fi
          idx=`/usr/bin/expr $idx + 1`
      done
  fi
 } >"$targetfile"
}

do_generate ()
{
 {
  echo "# ----------------------------------------------------------------------------" 
  echo "# /etc/config.d/samba - configuration for Samba on eisfair"
  echo "#"
  echo "# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net"
  echo "#"
  echo "# Creation   : 2002-02-04 tb"
  echo "# Last Update: 2013-12-09 tb"
  echo "#"
  echo "# Version    : 2.4.1"
  echo "#"
  echo "# This program is free software; you can redistribute it and/or modify"
  echo "# it under the terms of the GNU General Public License as published by"
  echo "# the Free Software Foundation; either version 2 of the License, or"
  echo "# (at your option) any later version."
  echo "# ----------------------------------------------------------------------------" 
  echo 
  echo "# ----------------------------------------------------------------------------" 
  echo "# General Settings"
  echo "#"
  echo "# Minimum requirement if SAMBA_MANUAL_CONFIGURATION='no' is to change"
  echo "# SAMBA_WORKGROUP to workgroup name of your windows clients!"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "START_SAMBA='no'                      # Start on boot: yes or no"
  echo
  echo "SAMBA_WORKGROUP='workgroup'           # Workgroup name of windows-clients"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Manual or Automatic Configuration"
  echo "#"
  echo "# Manual or Automatic Configuration of Shares and Printers"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *     If you set SAMBA_MANUAL_CONFIGURATION to 'no', the Settings        *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Shares' and      *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Printers' and    *"
  echo "#  *    in the Section 'Samba Advanced Configuration/Samba Mounts'          *"
  echo "#  *                         don't have an Effect!                          *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# If you set SAMBA_MANUAL_CONFIGURATION='no', following Shares automatically"
  echo "# created for you:"
  echo "#"
  echo "# - a share with your eisfair-username and full access only for you"
  echo "# - a share 'public' with full access for all eisfair-users"
  echo "# - an unvisible share 'all' with full access for user root"
  echo "#   for the whole filesystem"
  echo "# - shares for your printers in /etc/printcap, if lprng is installed"
  echo "# - a printer share for eisfax printer, if eisfax is installed"
  echo "# - a printer share for pdf printing, if ghostscript is installed"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_MANUAL_CONFIGURATION='no'       # Use manual configuration:"
  echo "                                      # yes or no"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration"
  echo "#"
  echo "# Please don't use this, if you are not very familar with Samba!"
  echo "# Support for this Section is not available!"
  echo "#"
  echo "# Special General Settings"
  echo "# and"
  echo "# Individual Configuration of Shares, Printers and Mounts"
  echo "#"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Special General Settings"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_INTERFACES=''                   # Userdefined interfaces for Samba"
  echo "                                      # Be carefull, use this only, if you"
  echo "                                      # don't want to use all interfaces from"
  echo "                                      # /etc/config.d/base"
  echo "                                      # You have to specify interfaces like"
  echo "                                      # this: '192.168.7.1/255.255.255.0'"
  echo
  echo "SAMBA_TRUSTED_NETS=''                 # If your network is 192.168.6.0/24"
  echo "                                      # and you want to grant access also"
  echo "                                      # to net 192.168.7.0/24, you have to"
  echo "                                      # add this here like this:"
  echo "                                      # '192.168.7.0/24'"
  echo
  echo "SAMBA_DEBUGLEVEL='0'                  # For debugging only: 0-10"
  echo "                                      # You will find debug messages in"
  echo "                                      # /var/log/log.smbd, /var/log/log.nmbd"
  echo
  echo "SAMBA_MASTERBROWSER='no'              # Act as an masterbrowser: yes or no"
  echo
  echo "SAMBA_WINSSERVER='no'                 # Act as an WINS-Server: yes or no"
  echo "                                      # If yes, don't set SAMBA_EXTWINSIP!"
  echo
  echo "SAMBA_WINSHOOK='no'                   # Trigger extra actions, if act as an"
  echo "                                      # WINS-Server: yes or no"
  echo
  echo "SAMBA_WINSHOOK_MESSAGE_SEND='no'      # Send messages to WINS clients:"
  echo "                                      # yes or no"
  echo
  echo "SAMBA_WINSHOOK_MESSAGE='Welcome to eisfair server'"
  echo "                                      # This message will diplayed on"
  echo "                                      # registering to eisfair"
  echo
  echo "SAMBA_WINSHOOK_DNSUPDATE='no'         # Updating local bind with WINS"
  echo "                                      # clients: yes or no"
  echo
  echo "SAMBA_EXTWINSIP=''                    # IP address of external WINS-Server"
  echo "                                      # if exist, act as an WINS-Client"
  echo "                                      # Don't set SAMBA_WINSSERVER to 'yes'!"
  echo
  echo "SAMBA_START_MESSAGE_SEND='no'         # Send start message on Samba start:"
  echo "                                      # yes or no"
  echo
  echo "SAMBA_START_MESSAGE='eisfair Samba Server is up now ...'"
  echo "                                      # This message will diplayed on start"
  echo "                                      # on WIN9x-clients with winpopup and"
  echo "                                      # WIN NT, WIN2K, WINXP"
  echo
  echo "SAMBA_SHUTDOWN_MESSAGE_SEND='no'      # Send shutdown message on Samba shutdown:"
  echo "                                      # yes or no"
  echo
  echo "SAMBA_SHUTDOWN_MESSAGE='eisfair Samba Server is going down now ...'"
  echo "                                      # This message will diplayed on shut-down"
  echo "                                      # on WIN9x-clients with winpopup and"
  echo "                                      # WIN NT, WIN2K, WINXP"
  echo
  echo "SAMBA_SHUTDOWN_MESSAGE_HOSTS='all'    # Target hosts for"
  echo "                                      # SAMBA_SHOW_SHUTDOWN_MESSAGE:"
  echo "                                      # all or active"
  echo

  echo "SAMBA_LOCALIZATION='UTF-8'            # Language adjustment, affected to unix"

  echo "                                      # character set and client codepage"
  echo "                                      # US        : United States (CP 437)"
  echo "                                      # ISO8859-1 : Western Europe (CP 850)"
  echo "                                      # ISO8859-2 : Eastern Europe (CP 852)"
  echo "                                      # ISO8859-5 : Russian Cyrillic (CP 866)"
  echo "                                      # ISO8859-7 : Greek (CP 737)"
  echo "                                      # ISO8859-15: Western Europe with EURO"
  echo "                                      #      UTF-8: Western Europe eisfair-2"
  echo
  echo "SAMBA_PDC='no'                        # Should Samba act as an Primary Domain"
  echo "                                      # Controller: yes or no"
  echo "                                      # Read Documentation!"
  echo
  echo "SAMBA_PDC_PROFILES='yes'              # Should Samba store roaming profiles"
  echo "                                      # if acting as an Primary Domain"
  echo "                                      # Controller: yes or no"
  echo
  echo "SAMBA_PDC_LOGONSCRIPT='user'          # PDC logon script:"
  echo "                                      # 'user', 'group', 'machines' or 'all'"
  echo
  echo "SAMBA_PASSWORD_SERVER=''              # NETBIOS name(s) of external password"
  echo "                                      # server(s) separated by a comma and"
  echo "                                      # a blank. Example:"
  echo "                                      # SAMBA_PASSWORD_SERVER='NT-PDC, NT-BDC1'"
  echo "                                      # SAMBA_PASSWORD_SERVER='*'"
  echo "                                      # Be shure, you have access from Samba to"
  echo "                                      # password server(s)!"
  echo
  echo "SAMBA_RECYCLE_BIN='no'                # Activate recycle bin in shares"
  echo
  echo "SAMBA_RECYCLE_BIN_HOLD_DAYS='7'       # Hold files for n days in recycle bin"
  echo
  echo "SAMBA_PDF_TARGET='homedir'            # Target for created pdf files:"
  echo "                                      # 'homedir', 'public' or 'mail'"
  echo
  echo "SAMBA_SERVERSTRING=''                 # Comment in network neighborhood:"
  echo "                                      # empty for no string"
  echo "                                      # or anything else for your string"
  echo
  echo "SAMBA_EXPERT_EXEC='no'                # Exec sambaexpert: yes or no"
  echo "                                      # Don't ask for help, while"
  echo "                                      # this is activated!"
  echo
  echo "SAMBA_SMBWEBCLIENT='no'               # Install smbwebclient: yes or no"
  echo
  echo "SAMBA_SMBWEBCLIENT_PATH='/var/www/htdocs'"
  echo "                                      # Install smbwebclient to this apache"
  echo "                                      # document root"
  echo
  echo "SAMBA_OPLOCKS='no'                    # activate oplocking (caching): yes or no"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba User Mappings"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# Definition of Samba User Mappings"
  echo "#"
  echo "# Set the number of Samba User Mappings to create in SAMBA_USERMAP_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_USERMAP_N is '0'"
  echo "#-----------------------------------------------------------------------------"
  echo
  echo "SAMBA_USERMAP_N='2'                   # How many user mappings do you want to"
  echo "                                      # create"
  echo
  echo "SAMBA_USERMAP_1_ACTIVE='yes'          # Is this mapping active: yes or no"
  echo "SAMBA_USERMAP_1_EISNAME='root'        # This is the eisfair user name of the"
  echo "                                      # 1. mapping"
  echo "SAMBA_USERMAP_1_WINNAME_N='1'         # How many windows names should be mapped"
  echo "                                      # to the 1. eisfair user name"
  echo "SAMBA_USERMAP_1_WINNAME_1='Administrator'"
  echo "                                      # This is the 1. windows name which"
  echo "                                      # should be mapped to the 1. eisfair user"
  echo
  echo "SAMBA_USERMAP_2_ACTIVE='no'           # Is this mapping active: yes or no"
  echo "SAMBA_USERMAP_2_EISNAME='jimknopf'    # This is the eisfair user name of the"
  echo "                                      # 2. mapping"
  echo "SAMBA_USERMAP_2_WINNAME_N='2'         # How many windows names should be mapped"
  echo "                                      # to the 2. eisfair user name"
  echo "SAMBA_USERMAP_2_WINNAME_1='Jim Knopf'"
  echo "                                      # This is the 1. windows name which"
  echo "                                      # should be mapped to the 2. eisfair user"
  echo "SAMBA_USERMAP_2_WINNAME_2='Jim Jeremy Knopf'"
  echo "                                      # This is the 2. windows name which"
  echo "                                      # should be mapped to the 2. eisfair user"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Shares"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ******************************** ATTENTION *******************************"
  echo "#"
  echo "# Definition of Samba Shares"
  echo "#"
  echo "# Set the number of Samba Shares to create in SAMBA_SHARE_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_SHARE_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_SHARE_N='4'                     # How many shares you want to create"
  echo
  echo "SAMBA_SHARE_1_ACTIVE='no'             # Is this share active: yes or no"
  echo "SAMBA_SHARE_1_NAME='homes'            # This is the name of the 1. share"
  echo "SAMBA_SHARE_1_COMMENT='home directory on %h'"
  echo "                                      # Comment of the 1. share"
  echo "SAMBA_SHARE_1_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_SHARE_1_BROWSE='no'             # Should share browseable: yes or no"
  echo "SAMBA_SHARE_1_PATH='%H'               # Path of the share in filesystem"
  echo "SAMBA_SHARE_1_USER='%S'               # Allowed user/groups for 1. share"
  echo "SAMBA_SHARE_1_PUBLIC='no'             # Share accessable for all: yes or no"
  echo "SAMBA_SHARE_1_READ_LIST=''            # Share only readable for"
  echo "SAMBA_SHARE_1_WRITE_LIST=''           # Share only writeable for"
  echo "SAMBA_SHARE_1_FORCE_CMODE='0600'      # Rights for created files"
  echo "SAMBA_SHARE_1_FORCE_DIRMODE='0700'    # Rights for created directories"
  echo "SAMBA_SHARE_1_FORCE_USER=''           # User for all file operations"
  echo "SAMBA_SHARE_1_FORCE_GROUP=''          # Group for all file operations"
  echo
  echo "SAMBA_SHARE_2_ACTIVE='no'             # Is this share active: yes or no"
  echo "SAMBA_SHARE_2_NAME='all'              # This is the name of the 2. share"
  echo "SAMBA_SHARE_2_COMMENT='complete filesystem on %h'"
  echo "                                      # Comment of the 2. share"
  echo "SAMBA_SHARE_2_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_SHARE_2_BROWSE='no'             # Should share browseable: yes or no"
  echo "SAMBA_SHARE_2_PATH='/'                # Path of the share in filesystem"
  echo "SAMBA_SHARE_2_USER='root'             # Allowed user/groups for 2. share"
  echo "SAMBA_SHARE_2_PUBLIC='no'             # Share accessable for all: yes or no"
  echo "SAMBA_SHARE_2_READ_LIST=''            # Share only readable for"
  echo "SAMBA_SHARE_2_WRITE_LIST=''           # Share only writeable for"
  echo "SAMBA_SHARE_2_FORCE_CMODE='0700'      # Rights for created files"
  echo "SAMBA_SHARE_2_FORCE_DIRMODE='0700'    # Rights for created directories"
  echo "SAMBA_SHARE_2_FORCE_USER=''           # User for all file operations"
  echo "SAMBA_SHARE_2_FORCE_GROUP=''          # Group for all file operations"
  echo
  echo "SAMBA_SHARE_3_ACTIVE='no'             # Is this share active: yes or no"
  echo "SAMBA_SHARE_3_NAME='public'           # This is the name of the 3. share"
  echo "SAMBA_SHARE_3_COMMENT='public directory on %h'"
  echo "                                      # Comment of the 3. share"
  echo "SAMBA_SHARE_3_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_SHARE_3_BROWSE='yes'            # Should share browseable: yes or no"
  echo "SAMBA_SHARE_3_PATH='/public'          # Path of the share in filesystem"
  echo "SAMBA_SHARE_3_USER=''                 # Allowed user/groups for 3. share"
  echo "SAMBA_SHARE_3_PUBLIC='yes'            # Share accessable for all: yes or no"
  echo "SAMBA_SHARE_3_READ_LIST=''            # Share only readable for"
  echo "SAMBA_SHARE_3_WRITE_LIST=''           # Share only writeable for"
  echo "SAMBA_SHARE_3_FORCE_CMODE='0777'      # Rights for created files"
  echo "SAMBA_SHARE_3_FORCE_DIRMODE='0777'    # Rights for created directories"
  echo "SAMBA_SHARE_3_FORCE_USER=''           # User for all file operations"
  echo "SAMBA_SHARE_3_FORCE_GROUP=''          # Group for all file operations"
  echo
  echo "SAMBA_SHARE_4_ACTIVE='no'             # Is this share active: yes or no"
  echo "SAMBA_SHARE_4_NAME='www'              # This is the name of the 4. share"
  echo "SAMBA_SHARE_4_COMMENT='doc root on %h'"
  echo "                                      # Comment of the 4. share"
  echo "SAMBA_SHARE_4_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_SHARE_4_BROWSE='yes'            # Should share browseable: yes or no"
  echo "SAMBA_SHARE_4_PATH='/var/www/htdocs'  # Path of the share in filesystem"
  echo "SAMBA_SHARE_4_USER='+www wwwrun'      # Allowed user/groups for 4. share"
  echo "SAMBA_SHARE_4_PUBLIC='no'             # Share accessable for all: yes or no"
  echo "SAMBA_SHARE_4_READ_LIST=''            # Share only readable for"
  echo "SAMBA_SHARE_4_WRITE_LIST=''           # Share only writeable for"
  echo "SAMBA_SHARE_4_FORCE_CMODE='0677'      # Rights for created files"
  echo "SAMBA_SHARE_4_FORCE_DIRMODE='0744'    # Rights for created directories"
  echo "SAMBA_SHARE_4_FORCE_USER='wwwrun'     # User for all file operations"
  echo "SAMBA_SHARE_4_FORCE_GROUP='nogroup'   # Group for all file operations"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba DFS Roots"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba DFS Roots"
  echo "#"
  echo "# Set the number of Samba DFS Roots to create in SAMBA_DFSROOT_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_DFSROOT_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_DFSROOT_N='1'                   # How many DFS roots do you want"
  echo
  echo "SAMBA_DFSROOT_1_ACTIVE='no'           # Activate this DFS root: yes or no"
  echo "SAMBA_DFSROOT_1_NAME='dfs1'           # This is the name of the $idx. DFS root"
  echo "SAMBA_DFSROOT_1_COMMENT=''            # Comment of the $idx. DFS root"
  echo "SAMBA_DFSROOT_1_RW='yes'              # Should DFS root be writeable: yes or no"
  echo "SAMBA_DFSROOT_1_BROWSE='yes'          # Should DFS root be browseable: yes or no"
  echo "SAMBA_DFSROOT_1_USER=''               # Allowed user/groups for this DFS root"
  echo "SAMBA_DFSROOT_1_PUBLIC='yes'          # DFS root accessable for all: yes or no"
  echo "SAMBA_DFSROOT_1_READ_LIST=''          # DFS root only readable for"
  echo "SAMBA_DFSROOT_1_WRITE_LIST=''         # DFS root only writeable for"
  echo "SAMBA_DFSROOT_1_FORCE_CMODE=''        # Rights for created files"
  echo "SAMBA_DFSROOT_1_FORCE_DIRMODE=''      # Rights for created directories"
  echo "SAMBA_DFSROOT_1_FORCE_USER=''         # User for all file operations"
  echo "SAMBA_DFSROOT_1_FORCE_GROUP=''        # Group for all file operations"
  echo "SAMBA_DFSROOT_1_DFSLNK_N='1'          # How many links should be created"
  echo "SAMBA_DFSROOT_1_DFSLNK_1_ACTIVE='yes' # Should this link active: yes or no"
  echo "SAMBA_DFSROOT_1_DFSLNK_1_SUBPATH=''   # Sub directory for this link"
  echo "SAMBA_DFSROOT_1_DFSLNK_1_NAME='users' # Name of the link"
  echo "SAMBA_DFSROOT_1_DFSLNK_1_UNC_N='1'    # How many unc pathes should be created"
  echo "SAMBA_DFSROOT_1_DFSLNK_1_UNC_1_PATH='\\\\userserver1\\users'"
  echo "                                      # unc path for this link"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Printers"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba Printers"
  echo "#"
  echo "# Set the number of Samba Printers to use in SAMBA_PRINTER_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_PRINTER_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_PRINTER_N='6'                   # How many printers you want to use"
  echo
  echo "SAMBA_PRINTER_1_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_1_NAME='laserjet'       # This is the name of the 1. printer"
  echo "SAMBA_PRINTER_1_TYPE='printcap'       # Type of the 1. printer"
  echo "SAMBA_PRINTER_1_PDF_QUALITY=''        # Quality of pdf files"
  echo "SAMBA_PRINTER_1_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_1_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_1_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_1_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_1_CAPNAME='pr1'         # The name of the 1. printer in"
  echo "                                      # /etc/printcap"
  echo "SAMBA_PRINTER_1_COMMENT='laserjet on %h'"
  echo "                                      # Comment of the 1. printer"
  echo "SAMBA_PRINTER_1_CLIENTDRIVER='yes'    # Use clientdriver for the 1. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_1_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_1_USER=''               # Allowed user/groups for 1. printer"
  echo "SAMBA_PRINTER_1_PUBLIC='yes'          # Printer accessable for all: yes or no"
  echo
  echo "SAMBA_PRINTER_2_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_2_NAME='epson'          # This is the name of the 2. printer"
  echo "SAMBA_PRINTER_2_TYPE='printcap'       # Type of the 2. printer"
  echo "SAMBA_PRINTER_2_PDF_QUALITY=''        # Quality of pdf files"
  echo "SAMBA_PRINTER_2_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_2_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_2_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_2_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_2_CAPNAME='pr2'         # The name of the 2. printer"
  echo "                                      # in /etc/printcap"
  echo "SAMBA_PRINTER_2_COMMENT='epson on %h'"
  echo "                                      # Comment of the 2. local printer"
  echo "SAMBA_PRINTER_2_CLIENTDRIVER='yes'    # Use clientdriver for the 2. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_2_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_2_USER='user1 user2'    # Allowed user/groups for 2. printer"
  echo "SAMBA_PRINTER_2_PUBLIC='no'           # Printer accessable for all: yes or no"
  echo
  echo "SAMBA_PRINTER_3_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_3_NAME='canon'          # This is the name of the 3. printer"
  echo "SAMBA_PRINTER_3_TYPE='printcap'       # Type of the 3. printer"
  echo "SAMBA_PRINTER_3_PDF_QUALITY=''        # Quality of pdf files"
  echo "SAMBA_PRINTER_3_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_3_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_3_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_3_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_3_CAPNAME='repr1'       # The name of the 3. printer"
  echo "                                      # in /etc/printcap"
  echo "SAMBA_PRINTER_3_COMMENT='canon on %h'"
  echo "                                      # Comment of the 3. printer"
  echo "SAMBA_PRINTER_3_CLIENTDRIVER='yes'    # Use clientdriver for the 3. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_3_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_3_USER='+users'         # Allowed user/groups for 3rd printer"
  echo "SAMBA_PRINTER_3_PUBLIC='no'           # Printer accessable for all: yes or no"
  echo
  echo "SAMBA_PRINTER_4_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_4_NAME='eisfax'         # This is the name of the 4. printer"
  echo "SAMBA_PRINTER_4_TYPE='fax'            # Type of the 4. printer"
  echo "SAMBA_PRINTER_4_PDF_QUALITY=''        # Quality of pdf files"
  echo "SAMBA_PRINTER_4_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_4_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_4_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_4_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_4_CAPNAME=''            # The name of the 4. printer"
  echo "                                      # in /etc/printcap"
  echo "SAMBA_PRINTER_4_COMMENT='eisfax on %h'"
  echo "                                      # Comment of the 4. printer"
  echo "SAMBA_PRINTER_4_CLIENTDRIVER='yes'    # Use clientdriver for the 4. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_4_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_4_USER=''               # Allowed user/groups for 4. printer"
  echo "SAMBA_PRINTER_4_PUBLIC='yes'          # Printer accessable for all: yes or no"
  echo
  echo "SAMBA_PRINTER_5_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_5_NAME='pdf-def'        # This is the name of the 5. printer"
  echo "SAMBA_PRINTER_5_TYPE='pdf'            # Type of the 5. printer"
  echo "SAMBA_PRINTER_5_PDF_QUALITY='default' # Quality of pdf files"
  echo "SAMBA_PRINTER_5_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_5_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_5_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_5_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_5_CAPNAME=''            # The name of the 5. printer"
  echo "                                      # in /etc/printcap"
  echo "SAMBA_PRINTER_5_COMMENT='pdf default on %h'"
  echo "                                      # Comment of the 5. printer"
  echo "SAMBA_PRINTER_5_CLIENTDRIVER='yes'    # Use clientdriver for the 5. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_5_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_5_USER=''               # Allowed user/groups for 5. printer"
  echo "SAMBA_PRINTER_5_PUBLIC='yes'          # Printer accessable for all: yes or no"
  echo
  echo "SAMBA_PRINTER_6_ACTIVE='no'           # Is this printer active: yes or no"
  echo "SAMBA_PRINTER_6_NAME='pdf-pre'        # This is the name of the 6. printer"
  echo "SAMBA_PRINTER_6_TYPE='pdf'            # Type of the 6. printer"
  echo "SAMBA_PRINTER_6_PDF_QUALITY='prepress' # Quality of pdf files"
  echo "SAMBA_PRINTER_6_PDF_OWNERPASS=''      # Password for editing PDF files"
  echo "SAMBA_PRINTER_6_PDF_USERPASS=''       # Password for opening PDF files"
  echo "SAMBA_PRINTER_6_PDF_PERMS=''          # Permissions for PDF files"
  echo "SAMBA_PRINTER_6_PDF_MESSAGES='yes'    # Messages for PDF files: yes or no"
  echo "SAMBA_PRINTER_6_CAPNAME=''            # The name of the 6. printer"
  echo "                                      # in /etc/printcap"
  echo "SAMBA_PRINTER_6_COMMENT='pdf prepress on %h'"
  echo "                                      # Comment of the 6. printer"
  echo "SAMBA_PRINTER_6_CLIENTDRIVER='yes'    # Use clientdriver for the 6. printer:"
  echo "                                      # yes or no"
  echo "SAMBA_PRINTER_6_BROWSE='yes'          # Should printer browseable: yes or no"
  echo "SAMBA_PRINTER_6_USER=''               # Allowed user/groups for 6. printer"
  echo "SAMBA_PRINTER_6_PUBLIC='yes'          # Printer accessable for all: yes or no"
  echo
  echo "# ----------------------------------------------------------------------------" 
  echo "# Samba Advanced Configuration/Samba Mounts"
  echo "#"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#  *                                                                        *"
  echo "#  *                The following Sections only have an Effect,             *"
  echo "#  *                if you set SAMBA_MANUAL_CONFIGURATION='yes'             *"
  echo "#  *                                                                        *"
  echo "#  ********************************* ATTENTION ******************************"
  echo "#"
  echo "# Definition of Samba Mounts"
  echo "#"
  echo "# Set the number of Samba Mounts to use in SAMBA_MOUNT_N."
  echo "#"
  echo "# Values below are only an example and are not used if"
  echo "# SAMBA_MOUNT_N is '0'"
  echo "# ----------------------------------------------------------------------------" 
  echo
  echo "SAMBA_MOUNT_N='2'                     # How many remote shares you want to mount"
  echo
  echo "SAMBA_MOUNT_1_ACTIVE='no'             # Is this mount active: yes or no"
  echo "SAMBA_MOUNT_1_VFSTYPE='smbfs'         # The virtual file system type"
  echo "SAMBA_MOUNT_1_SERVER='fli4l'          # The netbios name of the 1. server"
  echo "SAMBA_MOUNT_1_SHARE='share1'          # The name of the 1. share to mount"
  echo "SAMBA_MOUNT_1_POINT='/mountpoint1'    # Where you want to mount the share"
  echo "SAMBA_MOUNT_1_USER=''                 # The user name for share access"
  echo "SAMBA_MOUNT_1_PASS=''                 # The password for share access"
  echo "SAMBA_MOUNT_1_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_MOUNT_1_UID=''                  # Mount share with uid/username"
  echo "SAMBA_MOUNT_1_GID=''                  # Mount share with gid/groupname"
  echo "SAMBA_MOUNT_1_FMASK=''                # Mount share with file umask"
  echo "SAMBA_MOUNT_1_DMASK=''                # Mount share with directory umask"
  echo "SAMBA_MOUNT_1_IOCHARSET=''            # Mount share with linux charset"
  echo "SAMBA_MOUNT_1_CODEPAGE=''             # Mount with server codepage (only smbfs)"
  echo
  echo "SAMBA_MOUNT_2_ACTIVE='no'             # Is this mount active: yes or no"
  echo "SAMBA_MOUNT_2_VFSTYPE='smbfs'         # The virtual file system type"
  echo "SAMBA_MOUNT_2_SERVER='ente'           # The netbios name of the 1. server"
  echo "SAMBA_MOUNT_2_SHARE='downloads'       # The name of the 1. share to mount"
  echo "SAMBA_MOUNT_2_POINT='/mountpoint2'    # Where you want to mount the share"
  echo "SAMBA_MOUNT_2_USER='king'             # The user name for share access"
  echo "SAMBA_MOUNT_2_PASS='kong'             # The password for share access"
  echo "SAMBA_MOUNT_2_RW='yes'                # Should share writeable: yes or no"
  echo "SAMBA_MOUNT_2_UID='root'              # Mount share with uid/username"
  echo "SAMBA_MOUNT_2_GID='root'              # Mount share with gid/groupname"
  echo "SAMBA_MOUNT_2_FMASK='0777'            # Mount share with file umask"
  echo "SAMBA_MOUNT_2_DMASK='0777'            # Mount share with directory umask"
  echo "SAMBA_MOUNT_2_IOCHARSET='iso8859-1'   # Mount share with linux charset"
  echo "SAMBA_MOUNT_2_CODEPAGE='cp850'        # Mount with server codepage (only smbfs)"
  echo
 } >"$targetfile"
}

if [ "$mode" = "update" ] ; then
    . "$targetfile"

    #
    # section 'removed parameters'
    #

    if [ -n "$SAMBA_ADMIN_USER" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_ADMIN_USER"
    fi

    if [ -n "$SAMBA_ENCRYPT" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_ENCRYPT"
    fi

    if [ -n "$SAMBA_WINSCLIENT" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_WINSCLIENT"
    fi

    if [ -n "$SAMBA_SECURITY" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_SECURITY"
    fi

    if [ -n "`grep SAMBA_DOMAIN_ADMINS $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_DOMAIN_ADMINS"
    fi

    if [ -n "`grep SAMBA_SHARE_._DFSROOT $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_SHARE_x_DFSROOT"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_N"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_y_ACTIVE"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_y_SUBPATH"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_y_NAME"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_y_UNC_N"
        mecho --warn "Removed: SAMBA_SHARE_x_DFSLNK_y_UNC_z_PATH"
    fi

    if [ -n "`grep SAMBA_DFSROOT= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_DFSROOT"
        mecho --warn "Removed: SAMBA_DFSROOT_RW"
        mecho --warn "Removed: SAMBA_DFSROOT_BROWSE"
        mecho --warn "Removed: SAMBA_DFSROOT_USER"
        mecho --warn "Removed: SAMBA_DFSROOT_PUBLIC"
        mecho --warn "Removed: SAMBA_DFSROOT_READ_LIST"
        mecho --warn "Removed: SAMBA_DFSROOT_WRITE_LIST"
        mecho --warn "Removed: SAMBA_DFSROOT_FORCE_CMODE"
        mecho --warn "Removed: SAMBA_DFSROOT_FORCE_DIRMODE"
        mecho --warn "Removed: SAMBA_DFSROOT_FORCE_USER"
        mecho --warn "Removed: SAMBA_DFSROOT_FORCE_GROUP"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_N"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_x_ACTIVE"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_x_SUBPATH"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_x_NAME"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_x_UNC_N"
        mecho --warn "Removed: SAMBA_DFSROOT_DFSLNK_x_UNC_y_PATH"
    fi

    if [ -n "`grep SAMBA_VSCAN= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_VSCAN"
    fi

    if [ -n "`grep SAMBA_VSCAN_TYPE= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_VSCAN_TYPE"
    fi

    if [ -n "`grep SAMBA_VSCAN_TYP= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_VSCAN_TYP"
    fi

    if [ -n "`grep SAMBA_SHARE_._VSCAN $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_SHARE_x_VSCAN"
    fi

    if [ -n "`grep SAMBA_PASSWORT_SERVER_TYP= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_PASSWORT_SERVER_TYP"
        if [ "$SAMBA_PASSWORT_SERVER_TYP" = "server" -a -n "$SAMBA_PASSWORD_SERVER" ] ; then
            echo
            mecho --warn "Please join eisfair into the authenticating domain!"
            mecho --warn "Otherwise no authentification will pe possible!"
            echo
            mecho --warn "Go to:"
            mecho --info "'Samba Domain Handling'"
            mecho --info "'Add eisfair Samba Server into an Windows NT Domain'"
            mecho --warn "in eisfair Samba menue!"
        fi
    fi

    if [ -n "`grep SAMBA_PASSWORD_SERVER_TYPE= $targetfile`" ] ; then
        removed='yes'
        mecho --warn "Removed: SAMBA_PASSWORD_SERVER_TYPE"
        if [ "$SAMBA_PASSWORD_SERVER_TYPE" = "server" -a -n "$SAMBA_PASSWORD_SERVER" ] ; then
            echo
            mecho --warn "Please join eisfair into the authenticating domain!"
            mecho --warn "Otherwise no authentification will pe possible!"
            echo
            mecho --warn "Go to:"
            mecho --info "'Samba Domain Handling'"
            mecho --info "'Add eisfair Samba Server into an Windows NT Domain'"
            mecho --warn "in eisfair Samba menue!"
        fi
    fi

    #
    # section 'added parameters'
    #

    if [ -z "`grep SAMBA_TRUSTED_NETS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_TRUSTED_NETS"
    fi

    if [ -z "`grep SAMBA_PRINTER_._CLIENTDRIVER= $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_CLIENTDRIVER"
    fi

    if [ -z "$SAMBA_SHUTDOWN_MESSAGE_HOSTS" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SHUTDOWN_MESSAGE_HOSTS"
    fi

    if [ -z "`grep SAMBA_INTERFACES $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_INTERFACES"
    fi

    if [ -z "$SAMBA_PDF_TARGET" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PDF_TARGET"
    fi

    if [ -z "`grep SAMBA_SERVERSTRING $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SERVERSTRING"
    fi

    if [ -z "$SAMBA_PDC_PROFILES" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PDC_PROFILES"
    fi

    if [ -z "`grep SAMBA_SHARE_._READ_LIST $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SHARE_x_READ_LIST"
    fi

    if [ -z "`grep SAMBA_SHARE_._WRITE_LIST $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SHARE_x_WRITE_LIST"
    fi

    if [ -z "`grep SAMBA_MOUNT_N $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_N"
    fi

    if [ -z "`grep SAMBA_MOUNT_._SERVER $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_SERVER"
    fi

    if [ -z "`grep SAMBA_MOUNT_._SHARE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_SHARE"
    fi

    if [ -z "`grep SAMBA_MOUNT_._POINT $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_POINT"
    fi

    if [ -z "`grep SAMBA_MOUNT_._USER $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_USER"
    fi

    if [ -z "`grep SAMBA_MOUNT_._PASS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_PASS"
    fi

    if [ -z "`grep SAMBA_MOUNT_._RW $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_RW"
    fi

    if [ -z "`grep SAMBA_MOUNT_._UID $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_UID"
    fi

    if [ -z "`grep SAMBA_MOUNT_._GID $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_GID"
    fi

    if [ -z "`grep SAMBA_MOUNT_._FMASK $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_FMASK"
    fi

    if [ -z "`grep SAMBA_MOUNT_._DMASK $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_DMASK"
    fi

    if [ -z "`grep SAMBA_MOUNT_._IOCHARSET $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_IOCHARSET"
    fi

    if [ -z "`grep SAMBA_MOUNT_._CODEPAGE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_CODEPAGE"
    fi

    if [ -z "`grep SAMBA_EXPERT_EXEC $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_EXPERT_EXEC"
    fi

    if [ -z "`grep SAMBA_SHARE_._ACTIVE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SHARE_x_ACTIVE"
    fi

    if [ -z "`grep SAMBA_PRINTER_._ACTIVE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_ACTIVE"
    fi

    if [ -z "`grep SAMBA_MOUNT_._ACTIVE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_ACTIVE"
    fi

    if [ -z "$SAMBA_USERMAP_N" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_USERMAP_N"
        mecho --warn "Added  : SAMBA_USERMAP_x_EISNAME"
        mecho --warn "Added  : SAMBA_USERMAP_x_WINNAME_N"
        mecho --warn "Added  : SAMBA_USERMAP_x_WINNAME_y"
    fi

    if [ -z "`grep SAMBA_SMBWEBCLIENT $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SMBWEBCLIENT"
    fi

    if [ -z "`grep SAMBA_SMBWEBCLIENT_PATH $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_SMBWEBCLIENT_PATH"
    fi

    if [ -z "`grep SAMBA_WINSHOOK $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_WINSHOOK"
    fi

    if [ -z "`grep SAMBA_WINSHOOK_MESSAGE_SEND $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_WINSHOOK_MESSAGE_SEND"
    fi

    if [ -z "`grep SAMBA_WINSHOOK_MESSAGE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_WINSHOOK_MESSAGE"
    fi

    if [ -z "`grep SAMBA_WINSHOOK_DNSUPDATE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_WINSHOOK_DNSUPDATE"
    fi

    if [ -z "`grep SAMBA_OPLOCKS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_OPLOCKS"
    fi

    if [ -z "`grep SAMBA_PDC_LOGONSCRIPT $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PDC_LOGONSCRIPT"
    fi

    if [ -z "`grep SAMBA_PRINTER_._TYPE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_TYPE"
    fi

    if [ -z "`grep SAMBA_PRINTER_._PDF_OWNERPASS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_PDF_OWNERPASS"
    fi

    if [ -z "`grep SAMBA_PRINTER_._PDF_USERPASS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_PDF_USERPASS"
    fi

    if [ -z "`grep SAMBA_RECYCLE_BIN= $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_RECYCLE_BIN"
    fi

    if [ -z "`grep SAMBA_RECYCLE_BIN_HOLD_DAYS= $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_RECYCLE_BIN_HOLD_DAYS"
    fi

    if [ -z "`grep SAMBA_PRINTER_._PDF_PERMS $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_PDF_PERMS"
    fi

    if [ -z "`grep SAMBA_DFSROOT_N= $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_DFSROOT_N"
        mecho --warn "Added  : SAMBA_DFSROOT_x_ACTIVE"
        mecho --warn "Added  : SAMBA_DFSROOT_x_NAME"
        mecho --warn "Added  : SAMBA_DFSROOT_x_COMMENT"
        mecho --warn "Added  : SAMBA_DFSROOT_x_RW"
        mecho --warn "Added  : SAMBA_DFSROOT_x_BROWSE"
        mecho --warn "Added  : SAMBA_DFSROOT_x_USER"
        mecho --warn "Added  : SAMBA_DFSROOT_x_PUBLIC"
        mecho --warn "Added  : SAMBA_DFSROOT_x_READ_LIST"
        mecho --warn "Added  : SAMBA_DFSROOT_x_WRITE_LIST"
        mecho --warn "Added  : SAMBA_DFSROOT_x_FORCE_CMODE"
        mecho --warn "Added  : SAMBA_DFSROOT_x_FORCE_DIRMODE"
        mecho --warn "Added  : SAMBA_DFSROOT_x_FORCE_USER"
        mecho --warn "Added  : SAMBA_DFSROOT_x_FORCE_GROUP"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_N"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_y_ACTIVE"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_y_SUBPATH"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_y_NAME"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_y_UNC_N"
        mecho --warn "Added  : SAMBA_DFSROOT_x_DFSLNK_y_UNC_z_PATH"
    fi

    if [ -z "`grep SAMBA_MOUNT_._VFSTYPE $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_MOUNT_x_VFSTYPE"
    fi

    if [ -z "`grep SAMBA_PRINTER_._PDF_MESSAGES $targetfile`" ] ; then
        added='yes'
        mecho --warn "Added  : SAMBA_PRINTER_x_PDF_MESSAGES"
    fi

    #
    # section 'changed parameters'
    #

    if [ -n "`grep SAMBA_START= $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_START to START_SAMBA"
    fi

    if [ -n "$SAMBA_SHOW_START_MESSAGE" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_SHOW_START_MESSAGE to SAMBA_START_MESSAGE_SEND"
    fi

    if [ -n "$SAMBA_SHOW_SHUTDOWN_MESSAGE" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_SHOW_SHUTDOWN_MESSAGE to SAMBA_SHUTDOWN_MESSAGE_SEND"
    fi

    if [ -n "`grep SAMBA_AUTO_CONFIGURATION= $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_AUTO_CONFIGURATION to SAMBA_MANUAL_CONFIGURATION"
    fi

    if [ -z "`grep SAMBA_SHARE_._FORCE_CMODE $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_SHARE_x_CREATE_MASK to SAMBA_SHARE_x_FORCE_CMODE"
    fi

    if [ -z "`grep SAMBA_SHARE_._FORCE_DIRMODE $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_SHARE_x_DIRECTORY_MASK to SAMBA_SHARE_x_FORCE_DIRMODE"
    fi

    if [ -n "`grep SAMBA_PROFILES= $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_PROFILES to SAMBA_PDC_PROFILES"
    fi

    if [ -z "`grep SAMBA_PRINTER_._PDF_QUALITY $targetfile`" ] ; then
        changed='yes'
        mecho --warn "Changed: SAMBA_PRINTER_x_PDF_OPTION to SAMBA_PRINTER_x_PDF_QUALITY"
    fi

    #
    # show info for removed/added/changed parameters
    #

    if [ "$added" = "yes" -o "$changed" = "yes" -o "$removed" = "yes" ] ; then
        mecho --warn "Read documentation for removed/added/changed parameter(s)!"
        anykey
    fi

    do_update
else
    do_generate
fi

chown root.root "$targetfile"
chmod 0600 "$targetfile"
