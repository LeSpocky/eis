#! /bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/samba.sh - configuration generator script for Samba
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation: 2002-02-04 tb
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
. /etc/config.d/base
. /etc/config.d/cui-samba

if [ -f /etc/config.d/lprng ] ; then
    . /etc/config.d/lprng
fi

if [ -f /etc/config.d/cups ] ; then
    . /etc/config.d/cups
fi

interface=''
sambahosts=''
domainlogons='no'
domainmaster='no'
oslevel='0'
localmaster='no'
preferredmaster='no'
adminuser='root'
manual="$SAMBA_MANUAL_CONFIGURATION"
serverstring="$SAMBA_SERVERSTRING"
generate='/etc/smb.conf'
printcap='/etc/printcap'
version=`cat /usr/share/doc/samba/version`
add_user_script="/usr/sbin/useradd -m '%u' -c '%u'"
#delete_user_script="/var/install/bin/remove-user '%u' y"
delete_user_script=''
#add_group_script="/usr/sbin/groupadd '%g'"
add_group_script="/var/install/bin/add-group '%g'"
#delete_group_script="/usr/sbin/groupdel '%g'"
delete_group_script="/var/install/bin/remove-group '%g'"
add_user_to_group_script="/usr/sbin/usermod -G '%g' '%u'"
delete_user_from_group_script="/usr/sbin/userdel '%g' '%u'"
#set_primary_group_script="/usr/sbin/usermod -g '%g' '%u'"
set_primary_group_script="/var/install/bin/modify-user -g '%u' '%g'"
doit=''
vfs_objects=''
eisfax_exists='false'
hylafax_exists='false'
gs_exists='false'
sambaexpert_exists='false'
security='user'
nameresolveorder='lmhosts host wins bcast'
sambaspoolpath='/var/spool/samba'
pdbeditbin='/usr/bin/pdbedit'
tdbsamfile='/etc/passdb.tdb'
usermapfile='/etc/user.map'
fstabsmbfsfile='/etc/fstab-smbfs'
wins_hook=''
wins_support='no'
wins_server=''
wins_proxy='no'
password_server=''
mountbin='/bin/mount'
umountbin='/bin/umount'
pdfmessages='yes'

crontab_file='/etc/cron/root/samba'
crontab_update='/var/install/bin/update-cron'

if [ "$SAMBA_PDF_TARGET" = "public" ] ; then
    pdflinuxdir='/public'
    pdfwindir='//%L/public'
else
    pdflinuxdir='%H'
    pdfwindir='//%L/%u'
fi

if [ -f /etc/mgetty+sendfax/new_fax ] ; then
    eisfax_exists='true'
fi

if [ -d /var/spool/hylafax ] ; then
    hylafax_exists='true'
fi

if [ "$eisfax_exists" = "true" -o "$hylafax_exists" = "true" ] ; then
    if [ -f /usr/bin/printfax.pl ] ; then
        printfaxfile='/usr/bin/printfax.pl'
    fi

    if [ -f /usr/bin/printfax.sh ] ; then
        printfaxfile='/usr/bin/printfax.sh'
    fi

    faxcommand="( $printfaxfile '%I' '%s' '%u' '%m' '%H' '%S'; rm %s ) &"
fi

if [ -f /usr/local/bin/gs ] ; then
    gs_version=`/usr/local/bin/gs --version`
    case "$gs_version" in
    8.*|9.*)
        gs_exists='true'
        ;;
    7.*)
        gs_exists='false'
        mecho --warn "There is ghostscript $gs_version installed,"
        mecho --warn "you need eisfair ghostscript 1.2.0 (8.15.1)"
        mecho --warn "or higher for creation of pdf files!"
        ;;
    *)
        gs_exists='false'
        ;;
    esac
fi

if [ -f /var/install/packages/sambaexpert ] ; then
    sambaexpert_exists='true'
fi

if [ $SAMBA_DEBUGLEVEL -gt 0 ] ; then
    debuglevel="$SAMBA_DEBUGLEVEL"

    if [ $debuglevel -gt 2 ] ; then
        smbinfo='yes'
    else
        smbinfo='no'
    fi
else
    debuglevel='0'
    smbinfo='no'
fi

do_check_vfs_recycle ()
{
  if [ "$SAMBA_RECYCLE_BIN" = "yes" ] ; then
      if [ -z "$vfs_objects" ] ; then
          vfs_objects='recycle'
      else
          vfs_objects="recycle, $vfs_objects"
      fi
  fi
}

do_check_vfs_fullaudit ()
{
  if [ "$SAMBA_FULL_AUDIT" = "yes" ] ; then
      if [ -z "$vfs_objects" ] ; then
          vfs_objects='full_audit'
      else
          vfs_objects="full_audit, $vfs_objects"
      fi
  fi
}

do_check_vfs_dirsort ()
{
  #if [ -f /usr/lib/samba/vfs/dirsort.so ]
  if [ "$SAMBA_DIRSORT" = "yes" ] ; then
      if [ -z "$vfs_objects" ] ; then
          vfs_objects='dirsort'
      else
          vfs_objects="dirsort, $vfs_objects"
      fi
  fi
}

do_write_vfs_objects ()
{
  if [ -n "$vfs_objects" ] ; then
      echo " vfs objects = $vfs_objects"
  fi
}

do_write_vfs_fullaudit ()
{
  if [ "$SAMBA_FULL_AUDIT" = "yes" ] ; then
     {
      echo " full_audit:prefix = %S|%u|%I"
      echo " full_audit:success = open mkdir read write rmdir unlink"
      echo " full_audit:failure = none"
      echo " full_audit:facility = LOCAL7"
      echo " full_audit:priority = ALERT"
     }
  fi
}

do_write_vfs_recycle ()
{
  if [ "$SAMBA_RECYCLE_BIN" = "yes" ] ; then
     {
      echo " recycle:repository = samba_recycle_bin/%u"
      echo " recycle:versions = yes"
      echo " recycle:keeptree = yes"
      echo " recycle:touch = yes"
      echo " recycle:maxsize = 0"
      echo " recycle:directory_mode = 0777"
      echo " recycle:subdir_mode = 0700"
     }
  fi
}

do_remove_recycle_cron ()
{
  if [ -f /var/install/bin/samba-recycle-cron ] ; then
      rm -f /var/install/bin/samba-recycle-cron
  fi

  if [ -f "$crontab_file" ] ; then
      mecho --info "Removing cron job for SAMBA_RECYCLE_BIN ..."
      rm -f "$crontab_file"
      "$crontab_update"
  fi
}

do_add_recycle_cron ()
{
  if [ "$SAMBA_RECYCLE_BIN" = "yes" ] ; then
      mecho --info "Adding cron job for SAMBA_RECYCLE_BIN ..."
     {
      echo "/usr/bin/find / -path '/proc' -prune -o -name samba_recycle_bin -type d -print |"
      echo "while read samba_recycle_bin_dir"
      echo "do"
      echo "  /usr/bin/find \"\$samba_recycle_bin_dir\" -type f -atime +$SAMBA_RECYCLE_BIN_HOLD_DAYS -exec /bin/rm {} \\; 2>/dev/null"
      echo "  cd \"\$samba_recycle_bin_dir\""
      echo "  #echo \"------------------------------------------------------------------------------\""
      echo "  #echo \"searching samba_recycle_bin_dir \$samba_recycle_bin_dir ...\""
      echo "  /usr/bin/find \"\$samba_recycle_bin_dir\" -type d -empty |"
      echo "  while read samba_recycle_bin_subdir"
      echo "  do"

      echo "    samba_recycle_bin_rmdir=\`echo \"\$samba_recycle_bin_subdir\" | /bin/sed \"s#^\$samba_recycle_bin_dir/##\"\`"

      echo "    if [ \"\$samba_recycle_bin_dir\" != \"\$samba_recycle_bin_rmdir\" ]"
      echo "    then"
      echo "        #echo \"Found empty directory samba_recycle_bin_subdir \$samba_recycle_bin_subdir\""
      echo "        #echo \"Empty directory samba_recycle_bin_rmdir is \$samba_recycle_bin_rmdir\""
      echo "        #echo \"Deleting empty dir '\"\$samba_recycle_bin_rmdir\"' and empty dirs up to \"\$samba_recycle_bin_dir\" ...\""
      echo "        /bin/rmdir -p --ignore-fail-on-non-empty \"\$samba_recycle_bin_rmdir\""
      echo "    fi"
      echo "  done"
      echo "done"
     } >/var/install/bin/samba-recycle-cron

      chmod 0744 /var/install/bin/samba-recycle-cron
      chown root.root /var/install/bin/samba-recycle-cron

     {
      echo "# Do not edit this file, edit /etc/config.d/samba"
      echo "# Creation date: `date`"
      echo "15 3 * * * /var/install/bin/samba-recycle-cron 1>/dev/null"
     } >"$crontab_file"

      "$crontab_update"
  fi
}

do_mkdir_recycle ()
{
  if [ "$SAMBA_RECYCLE_BIN" = "yes" ] ; then
      recycle_path="$path/samba_recycle_bin"
      mkdir -p "$recycle_path"
      chmod 0777 "$recycle_path"
      chown nobody.nogroup "$recycle_path"
  fi
}

do_smbinfo ()
{
  if [ "$smbinfo" = "yes" ] ; then
      x='T=%T|d=%d|v=%v|h=%h|L=%L|N=%N|p=%p|R=%R|S=%S|P=%P|U=%U|G=%G|u=%u|g=%g|H=%H|I=%I|M=%M|m=%m|a=%a'
      echo " root preexec = /var/install/bin/samba-smbinfo \"$x\" &"
  fi
}

do_lprngprinting ()
{
  if grep -q ':smbinfo=yes' "$printcap"
  then
      lprng_print_command='chmod 666 "%s"; jobname=`echo "%J" | sed "s/^.*- //"`; if [ -z "$jobname" ]; then jobname="%s"; fi; /var/install/bin/lprng-print "%p" "%s" "%U" "%m" "%L" "%I" "%a" "$jobname"'
  else
      lprng_print_command='chmod 666 "%s"; jobname=`echo "%J" | sed "s/^.*- //"`; if [ -z "$jobname" ]; then jobname="%s"; fi; /usr/bin/lpr -P%p -J"$jobname" "%s"; rm "%s"'
  fi

 {
  echo " printing = lprng"
  echo " print command = $lprng_print_command"
  echo " lpq command = /usr/bin/lpq -P%p -L"
  echo " lprm command = /usr/bin/lprm -P%p %j"
  echo " lppause command = /usr/sbin/lpc hold %p %j"
  echo " lpresume command = /usr/sbin/lpc release %p %j"
  echo " queuepause command = /usr/sbin/lpc stop %p"
  echo " queueresume command = /usr/sbin/lpc start %p"
  echo " printable = yes"
 }
}

do_macro ()
{
  is_macro='false'
  for macro in %T %d %v %h %L %N %p %R %S %P %U %G %u %g %H %I %M %m %a
  do
      if [ "$a" = "$macro" ] ; then
          is_macro='true'
      fi
  done
}

do_valid_users ()
{
  found_adminuser='no'
  for u in $user
  do
      if [ "$u" = "$adminuser" ] ; then
          found_adminuser='yes'
      fi
  done

  if [ "$found_adminuser" = "no" ] ; then
      user="$user $adminuser"
  fi

  echo " valid users = $user"
}

do_check_user_group ()
{
  usergroup="$1"
  type_idx="$2"
  type_n="$3"
  checkfor="$4"

  for a in $usergroup
  do
      exists='yes'
      do_macro
      if [ "$is_macro" = "false" ] ; then
          case $checkfor in
          both)
              if [ `echo $a | cut -c1` = "+" ] ; then
                  what='group'
                  a=`echo $a | cut -c2-`
                  if ! grep -q ^$a: /etc/group
                  then
                      exists='no'
                  fi
              else
                  what='user'
                  if ! grep -q ^$a: /etc/passwd
                  then
                      exists='no'
                  fi
              fi
              ;;
          group)
              what='group'
              if ! grep -q ^$a: /etc/group
              then
                  exists='no'
              fi
              ;;
          user)
              what='user'
              if ! grep -q ^$a: /etc/passwd
              then
                  exists='no'
              fi
              ;;
          esac

          if [ "$exists" = "no" ] ; then
              mecho --error "$what $a from $type_idx doesn't"
              mecho --error "  exists - skipping $type_n ..."
              create_share='false'
          fi
      fi
  done
}

do_usermapheader ()
{
 {
  echo "#----------------------------------------------------------------------------"
  echo "# /etc/user.map - windows to unix user name mappings"
  echo "# generated by /var/install/config.d/samba.sh"
  echo "#"
  echo "# unixuser1 = \"Windows-User-Name mit Leerzeichen\""
  echo "# unixuser2 = \"Windows-User-Name mit Leerzeichen\" \"2. Name\" \"3. Name\""
  echo "#"
  echo "# Version of Samba for eisfair is $version."
  echo "# SAMBA_MANUAL_CONFIGURATION is $manual."
  echo "#"
  echo "# Do not edit this file, use 'Edit Samba Configuration'"
  echo "# in Samba Services Menu!"
  echo "#"
  echo "# Creation date: ${EISDATE} ${EISTIME}"
  echo "#----------------------------------------------------------------------------"
 } >"$usermapfile"
}

mountpoint='/samba_dfs'
imgdir='/usr/local/share/samba'
dfsimage="$imgdir/dfs_root.img"

do_make_dfs_image ()
{
  mkdir -p -m 755 "$imgdir"
  dd if=/dev/zero of="$dfsimage" bs=1M seek=1 count=1 >/dev/null 2>&1
  echo "y" | mke2fs -j -m 0 "$dfsimage" >/dev/null 2>&1
}

do_mount_dfs_image ()
{
  if [ "$1" = "--u" ] ; then
      if [ -n "`"$mountbin" -t ext3 | grep "/dev/loop" | grep " $mountpoint "`" ] ; then
          mecho --std "Umounting and removing $mountpoint ..."
          cd /
          "$mountbin" -t ext3 | grep "/dev/loop" | grep " $mountpoint " |
          while read mounted
          do
              "$umountbin" "$mountpoint"
          done
      fi

      rm -rf "$mountpoint"
  else
      mountoption="$1"
      if [ -z "$mountoption" ] ; then
          mountoption='--rw'
      fi
      if [ ! "`"$mountbin" -t ext3 | grep "/dev/loop" | grep " $mountpoint "`" ] ; then
          mecho --std "Creating $mountpoint and mounting ..."
          modprobe loop 2>/dev/null
          mkdir "$mountpoint"
          "$mountbin" -o loop $mountoption "$dfsimage" "$mountpoint"
          if [ $? -ne 0 ] ; then
              mecho --error "Cannot mount $dfsimage $mountoption!"
              rmdir "$mountpoint"
          else
              mecho --std "Mounted $dfsimage $mountoption."
          fi
      fi
  fi
}

if [ "$SAMBA_MASTERBROWSER" = "yes" ] ; then
    oslevel='255'
    localmaster='yes'
    preferredmaster='yes'
fi

if [ -z "$SAMBA_PASSWORD_SERVER" ] ; then
    if [ "$SAMBA_PDC" = "yes" ] ; then
        oslevel='255'
        localmaster='yes'
        preferredmaster='yes'
        domainlogons='yes'
        domainmaster='yes'
        #add_machine_script="/var/install/bin/samba-add-workstation '%u'"
        add_machine_script="/var/install/bin/add-user '%u' '*' '' '777' 'machine_account' '/dev/null' '/bin/false'"
        #add_machine_script="/usr/sbin/useradd -d /dev/null -g 777 -s /bin/false -M '%u'"

        case "$SAMBA_PDC_LOGONSCRIPT" in
        user)
            logonscript="%U.bat %G %m"
            ;;
        group)
            logonscript="%G.bat %U %m"
            ;;
        machine)
            logonscript="%m.bat %U %G"
            ;;
        all)
            logonscript="logon.bat %U %G %m"
            ;;
        esac

        mkdir -p /netlogon
        # mkdir -p /profile
        chown root.root /netlogon
        # chown nobody.users /profile
        chmod 0775 /netlogon
        # chmod 0777 /profile

        if [ ! -f /netlogon/logon.bat ] ; then
            echo "Copying example /usr/share/doc/samba/tools/logon.bat to /netlogon ..."
            cp -f /usr/share/doc/samba/tools/logon.bat /netlogon
            chmod 0755 /netlogon/logon.bat
            chown nobody.nogroup /netlogon/logon.bat
        fi
    fi
else
    security='domain'
    password_server="$SAMBA_PASSWORD_SERVER"
    add_user_script="/var/install/bin/samba-add-domain-auto-user '%u'"
fi

#----------------------------------------------------------------------------
# create wins options:
#----------------------------------------------------------------------------
if [ "$SAMBA_WINSSERVER" = "yes" ] ; then
    wins_support='yes'
    nameresolveorder='wins lmhosts host bcast'
    if [ "$SAMBA_WINSHOOK" = "yes" ] ; then
        wins_hook='/var/install/bin/samba-winshook'
    fi
else
    if [ -n "$SAMBA_EXTWINSIP" ] ; then
        wins_server="$SAMBA_EXTWINSIP"
        wins_proxy='yes'
        nameresolveorder='wins lmhosts host bcast'
    fi
fi

#----------------------------------------------------------------------------
# configuring interfaces for samba:
#----------------------------------------------------------------------------
idx='1'
if grep -q 'IP_ETH_N=' /etc/config.d/base
then
    while [ "$idx" -le "$IP_ETH_N" ] ; do
        eval ipaddr='$IP_ETH_'$idx'_IPADDR'
        if [ "$ipaddr" != "0.0.0.0" -a -n "$ipaddr" ] ; then
            eval netmask='$IP_ETH_'$idx'_NETMASK'
            network=`/usr/local/bin/netcalc network $ipaddr $netmask`
            if [ -z "$interface_from_base" ] ; then
                interface_from_base="$ipaddr/$netmask"
                sambahosts_from_base="$network/$netmask"
            else
                interface_from_base="$interface_from_base $ipaddr/$netmask"
                sambahosts_from_base="$sambahosts_from_base $network/$netmask"
            fi
        fi
        idx=`/usr/bin/expr $idx + 1`
    done
else
    while [ "$idx" -le "$IP_NET_N" ] ; do
        eval ipaddr='$IP_NET_'$idx'_IPADDR'
        if [ "$ipaddr" != "0.0.0.0" -a -n "$ipaddr" ] ; then
            eval netmask='$IP_NET_'$idx'_NETMASK'
            network=`/usr/local/bin/netcalc network $ipaddr $netmask`
            if [ -z "$interface_from_base" ] ; then
                interface_from_base="$ipaddr/$netmask"
                sambahosts_from_base="$network/$netmask"
            else
                interface_from_base="$interface_from_base $ipaddr/$netmask"
                sambahosts_from_base="$sambahosts_from_base $network/$netmask"
            fi
        fi
        idx=`/usr/bin/expr $idx + 1`
    done
fi

if [ -n "$SAMBA_INTERFACES" ] ; then
    use_interface_from_base='false'
    for i in $SAMBA_INTERFACES
    do
        ipaddr=`echo "$i" | cut -d"/" -f1`
        netmask=`echo "$i" | cut -d"/" -f2`
        network=`/usr/local/bin/netcalc network $ipaddr $netmask`
        new_interface="$ipaddr/$netmask"
        interface_found='false'

        for i in $interface_from_base
        do
            if [ "$i" = "$new_interface" ] ; then
                interface_found='true'
            fi
        done

        if [ "$interface_found" = "true" ] ; then
            if [ -z "$interface" ] ; then
                interface="$ipaddr/$netmask"
                sambahosts="$network/$netmask"
            else
                interface="$interface $ipaddr/$netmask"
                sambahosts="$sambahosts $network/$netmask"
            fi
        else
            mecho --error "Cannot find interface $ipaddr/$netmask in base config!"
            mecho --error "Please read the docs for syntax in SAMBA_INTERFACES!"
            echo "Setting interfaces and sambahosts from base ..."
            use_interface_from_base='true'
            break
        fi
    done

    if [ "$use_interface_from_base" = "true" ] ; then
        interface="$interface_from_base"
        sambahosts="$sambahosts_from_base"
    fi
else
    interface="$interface_from_base"
    sambahosts="$sambahosts_from_base"
fi

if [ -n "$SAMBA_TRUSTED_NETS" ] ; then
    for i in $SAMBA_TRUSTED_NETS
    do
        network=`/usr/local/bin/netcalc network $i`
        netmask=`/usr/local/bin/netcalc netmask $i`
        var=$network/$netmask
        if [ -z "$sambahosts" ] ; then
            sambahosts="$var"
        else
            if [ -z "`echo $sambahosts | grep $var`" ] ; then
                sambahosts="$sambahosts $var"
            fi
        fi
    done
fi

if [ -z "$interface" ] ; then
    mecho --error "No network interfaces available - cannot configure samba!"
    sleep 5
    exit 1
fi


if [ "`echo "$hostname" | wc -L`" -gt "15" ] ; then
    mecho --error "Your hostname is too long. Use 1 - 15 characters!"
fi

if [ "$hostname" = "`echo "$SAMBA_WORKGROUP" | tr 'a-z' 'A-Z'`" ] ; then
    mecho --error "Your hostname and SAMBA_WORKGROUP are the same!"
fi

# this is for updates
if [ "$SAMBA_PDF_TARGET" = "mail" ] ; then
    base64='no'
    if [ -e /var/install/packages/perl_mime_base64 ] ; then
        base64='yes'
    fi

    if [ -e /usr/bin/corelist ] ; then
        base64='yes'
    fi

    if [ "$base64" = "no" ] ; then
        mecho --error "You configured SAMBA_PDF_TARGET='mail' but there"
        mecho --error "is no perl module perl_mime_base64 installed!"
        mecho --error "This is an additional module for perl package 1.0.0"
        mecho --error "or part of later perl packages."
        mecho --error "Setting SAMBA_PDF_TARGET to 'homedir' ..."
        SAMBA_PDF_TARGET='homedir'
    fi
fi

#----------------------------------------------------------------------------
# create global config (manual or automatic)
#----------------------------------------------------------------------------
if [ -f "$generate" ] ; then
    /var/install/bin/backup-file $generate sic
fi
>"$generate"

{
echo "#----------------------------------------------------------------------------"
echo "# Samba configuration file generated by /var/install/config.d/cui-samba.sh"
echo "#"
echo "# Version of Samba for eisfair is $version."
echo "# SAMBA_MANUAL_CONFIGURATION is $manual."
echo "#" 
echo "# Do not edit this file, use 'Edit Samba Configuration'"
echo "# in Samba Services Menu!"
echo "#"
echo "# Creation date: ${EISDATE} ${EISTIME}"
echo "#----------------------------------------------------------------------------"
echo "[global]"
echo " workgroup = $SAMBA_WORKGROUP"
echo " serverstring = $serverstring"
echo " interfaces = 127.0.0.1/8 $interface"
echo " bind interfaces only = yes"
echo " security = $security"
echo " password server = $password_server"
#echo " pam password change = yes"
echo " passwd program = /usr/bin/passwd %u"
#echo " passwd chat = *New*password:* %n\n *new*password:* %n\n *changed*"
echo " passwd chat = *New*Password:* %n\n *Reenter*New*Password:* %n\n *Password*changed*"
echo " username map = $usermapfile"
echo " username level = 2"
echo " unix password sync = yes"
echo " debug level = $debuglevel"
echo " max log size = 10000"
echo " nameresolveorder = $nameresolveorder"
echo " time server = yes"
echo " deadtime = 60"
echo " printing = lprng"
echo " printcap name = $printcap"
echo " printcap cache time = 0"
echo " load printers = no"
echo " mangling method = hash2"

if [ "$SAMBA_PDC" = "yes" ] ; then
    echo " logon script = $logonscript"
    # xp is buggy
    echo " logon drive = x:"
    # echo " logon home = \\\%N\%U\profile_9x_me" # bug with same user on 9x
    # echo " logon path = \\\%N\%U\profile_nt_xp" # and xp with logon drive
    # no chance to setup different profile directories in home for 9x/xp
    # using defaults:
    # echo " logon home = \\\%N\%U"               # 9x/me
    # echo " logon path = \\\%N\%U\profile"       # nt/w2k/xp
    # echo " logon path = \\\%N\%U\profiles\%a    # for different profile dirs for w2k and xp
    if [ "$SAMBA_PDC_PROFILES" = "no" ] ; then
        echo " logon path ="
    fi
fi

echo " domain logons = $domainlogons"
echo " add user script = $add_user_script"
echo " add machine script = $add_machine_script"
echo " delete user script = $delete_user_script"
echo " add group script = $add_group_script"
echo " delete group script = $delete_group_script"
echo " add user to group script = $add_user_to_group_script"
echo " delete user from group script = $delete_user_from_group_script"
echo " set primary group script = $set_primary_group_script"
echo " os level = $oslevel"
echo " preferred master = $preferredmaster"
echo " local master = $localmaster"
echo " domain master = $domainmaster"
echo " wins support = $wins_support"
echo " wins hook = $wins_hook"
echo " wins server = $wins_server"
echo " wins proxy = $wins_proxy"
echo " kernel oplocks = $SAMBA_OPLOCKS"
echo " utmp = yes"
#echo " message command = /bin/mail -s 'message from %f' root < %s; rm %s"
echo " message command = /var/install/bin/samba-netbios-mail '%f' '%s'"
echo " admin users = $adminuser"
echo " hosts allow = 127.0.0. $sambahosts"
echo " dos filetime resolution = yes"
echo " use sendfile = yes"
echo " unix extensions = no"
echo " wide links = yes"
#echo " debug pid = yes"
#echo " debug hires timestamp = yes"
#echo " enable privileges = no"
echo " enable core files = no"
echo " max mux = 10000"
echo " dos filemode = yes"
echo " acl group control = yes"

for pseudofile in /proc/{ksyms,kallsyms}
do
    if [ -e "$pseudofile" ] ; then
        if grep -q 'posix_acl_' "$pseudofile"
        then
            if grep ' / ext' /etc/mtab | grep 'acl,user_xattr' >/dev/null 2>&1
            then
                echo " acl compatibility = auto"
                echo " force unknown acl user = yes"
                echo " inherit acls = yes"
                echo " map acl inherit = yes"
                echo " map hidden = no"
                echo " map system = no"
                echo " map archive = no"
                echo " map read only = no"
                echo " store dos attributes = yes"
                echo " ea support = yes"
            fi
        fi
    fi
done

echo " oplocks = $SAMBA_OPLOCKS"
echo " level2 oplocks = $SAMBA_OPLOCKS"
echo " blocking locks = $SAMBA_OPLOCKS"

if [ "$SAMBA_OPLOCKS" = "yes" ] ; then
    echo " veto oplock files = /*.bak/*.cd*/*.cur/*.*db/*.db*/*.*dx/*.dxf/*.dwg/*.doc/*.fpt/*.igs/*.ia*/*.id*/*.in*/*.ip*/*.log/*.mpp/*.ndx/*.ntx/*.opt/*.ord/*.ppt/*.pst/*.qb*/*.sjb/*.sbs/*.slp/*.st*/*.vsd/*.xl*/"
    #echo " write cache size = 262144"
    #echo " veto oplock files = /*.b*/*.c*/*.*db/*.d*/*.f*/*.i*/*.l*/*.m*/*.n*/*.o*/*.p*/*.q*/*.s*/*.v*/*.x*/"
fi

echo " hide files = /desktop.ini/Thumbs.db/"
echo " dos filemode = yes"
#echo " dfree command = /var/install/bin/samba-dfree"
#echo " dfree cache time = 3"
echo " passdb backend = tdbsam"
echo " lanman auth = yes"
echo " client lanman auth = yes"
echo " client plaintext auth = yes"

if `smbd -V | grep -q '3.6.'`
then
    echo " max protocol = SMB2"
    echo " min receivefile size = 16384"
    echo " aio read size = 16384"
    echo " aio write size = 16384"
    echo " client ntlmv2 auth = no"
fi

echo " socket options = TCP_NODELAY IPTOS_LOWDELAY SO_KEEPALIVE"
#echo " kernel change notify = no"
echo
} >>"$generate"

#----------------------------------------------------------------------------
# create netlogon (manual or automatic)
#----------------------------------------------------------------------------
if [ "$SAMBA_PDC" = "yes" ] ; then
   {
    echo "[netlogon]"
    echo " comment = netlogon-service on $HOSTNAME"
    echo " path = /netlogon"
    echo " writeable = no"
    echo " write list = $adminuser"
    echo " locking = no"
    echo " browseable = no"
    echo " acl check permissions = no"
    # echo
    # echo "[profile]"
    # echo " comment = profiles on $HOSTNAME"
    # echo " path = /profile"
    # echo " writeable = yes"
    # echo " browseable = yes"
    # echo " create mode = 0600"
    # echo " directory mode = 0700"
    # echo " locking = no"
    echo
   } >>"$generate"
fi

#----------------------------------------------------------------------------
# begin automatic configuration (SAMBA_MANUAL_CONFIGURATION='no')
#----------------------------------------------------------------------------
if [ "$manual" = "no" ] ; then
    #----------------------------------------------------------------------------
    # create share for eis homes directory, if SAMBA_MANUAL_CONFIGURATION='no'
    #----------------------------------------------------------------------------
   {
    echo "[homes]"
    echo " comment = home directory on $HOSTNAME"
    echo " writeable = yes"
    echo " create mode = 0600"
    echo " force create mode = 0600"
    echo " directory mode= 0700"
    echo " force directory mode= 0700"
    echo " browseable = no"
    echo " valid users = %S $adminuser"

    if [ "$SAMBA_PDC" = "yes" -a "$SAMBA_PDC_PROFILES" = "yes" ] ; then
        echo " csc policy = disable"
        #echo " profile acls = yes"
    fi

    do_smbinfo
    vfs_objects=''
    do_check_vfs_recycle
    do_check_vfs_fullaudit
    do_check_vfs_dirsort
    do_write_vfs_objects
    do_write_vfs_fullaudit
    do_write_vfs_recycle
    echo
   } >>"$generate"

    #----------------------------------------------------------------------------
    # create share for eis root directory, if SAMBA_MANUAL_CONFIGURATION='no'
    #----------------------------------------------------------------------------
    path='/'
    do_mkdir_recycle
   {
    echo "[all]"
    echo " comment = root directory on $HOSTNAME"
    echo " read only = no"
    echo " browseable = no"
    echo " path = $path"
    echo " dont descend = proc"
    echo " valid users = $adminuser"
    echo " create mode = 0700"
    echo " force create mode = 0700"
    echo " directory mode= 0700"
    echo " force directory mode= 0700"
    do_smbinfo
    vfs_objects=''
    do_check_vfs_recycle
    do_check_vfs_fullaudit
    do_check_vfs_dirsort
    do_write_vfs_objects
    do_write_vfs_fullaudit
    do_write_vfs_recycle
    echo
   } >>"$generate"

    #----------------------------------------------------------------------------
    # create public share, if SAMBA_MANUAL_CONFIGURATION='no'
    #----------------------------------------------------------------------------
    path='/public'
    if [ ! -d "$path" ] ; then
        mkdir -p "$path"
        if [ $? -eq 0 ] ; then
            echo "Directory $path for share public on $HOSTNAME created."
        else
            mecho --error "Cannot create directory $path for share public on $HOSTNAME!"
        fi
    fi

    chmod 0777 "$path"
    chown nobody.nogroup "$path"
    do_mkdir_recycle

   {
    echo "[public]"
    echo " comment = public directory on $HOSTNAME"
    echo " path = $path"
    echo " force create mode = 0777"
    echo " force directory mode= 0777"
    echo " browseable = yes"
    echo " writeable = yes"
    do_smbinfo
    vfs_objects=''
    do_check_vfs_recycle
    do_check_vfs_fullaudit
    do_check_vfs_dirsort
    do_write_vfs_objects
    do_write_vfs_fullaudit
    do_write_vfs_recycle
    echo
   } >>"$generate"

    #----------------------------------------------------------------------------
    # create share(s) for printer(s), if SAMBA_MANUAL_CONFIGURATION='no'
    #----------------------------------------------------------------------------
    if [ -f $printcap ] ; then
        if [ -n "$CUPS_PRINTER_N" ] ; then
            idx=1
            while [ "$idx" -le "$CUPS_PRINTER_N" ] ; do
                eval name='$CUPS_PRINTER_'$idx'_NAME'
                eval comment='$CUPS_PRINTER_'$idx'_LOCATION'
                if grep -q $name $printcap
                then
                   {
                    echo "[$name]"
                    echo " comment = $comment"
                    do_lprngprinting
                    echo " use client driver = yes"
                    echo " browseable = yes"
                    echo " create mode = 0700"
                    echo " path = $sambaspoolpath"
                    echo
                   } >>"$generate"
                fi
                idx=`/usr/bin/expr $idx + 1`
            done
        fi

        if [ -n "$LPRNG_LOCAL_PARPORT_PRINTER_N" ] ; then
            idx=1
            while [ "$idx" -le "$LPRNG_LOCAL_PARPORT_PRINTER_N" ] ; do
                if grep -q :sd=/var/spool/lpd/pr$idx $printcap
                then
                   {
                    echo "[pr$idx]"
                    echo " comment = local parallel printer pr$idx on %h"
                    do_lprngprinting
                    echo " use client driver = yes"
                    echo " browseable = yes"
                    echo " create mode = 0700"
                    echo " path = $sambaspoolpath"
                    echo
                   } >>"$generate"
                fi
                idx=`/usr/bin/expr $idx + 1`
            done
        fi

        if [ -n "$LPRNG_LOCAL_USBPORT_PRINTER_N" ] ; then
            idx=1
            while [ "$idx" -le "$LPRNG_LOCAL_USBPORT_PRINTER_N" ] ; do
                if grep -q :sd=/var/spool/lpd/usbpr$idx $printcap
                then
                   {
                    echo "[usbpr$idx]"
                    echo " comment = local usb printer usbpr$idx on %h"
                    do_lprngprinting
                    echo " use client driver = yes"
                    echo " browseable = yes"
                    echo " create mode = 0700"
                    echo " path = $sambaspoolpath"
                    echo
                   } >>"$generate"
                fi
                idx=`/usr/bin/expr $idx + 1`
            done
        fi

        if [ -n "$LPRNG_REMOTE_PRINTER_N" ] ; then
            idx=1
            while [ "$idx" -le "$LPRNG_REMOTE_PRINTER_N" ] ; do
                if grep -q :sd=/var/spool/lpd/repr$idx $printcap
                then
                   {
                    echo "[repr$idx]"
                    echo " comment = remote printer repr$idx on %h"
                    do_lprngprinting
                    echo " use client driver = yes"
                    echo " browseable = yes"
                    echo " create mode = 0700"
                    echo " path = $sambaspoolpath"
                    echo
                   } >>"$generate"
                fi
                idx=`/usr/bin/expr $idx + 1`
            done
        fi
    fi

    if [ "$eisfax_exists" = "true" -o "$hylafax_exists" = "true" ] ; then
       {
        echo "[eisfax]"
        echo " comment = eisfax on %h"
        echo " printing = bsd"
        echo " use client driver = yes"
        echo " browseable = yes"
        echo " printable = yes"
        echo " path = $sambaspoolpath"
        echo " print command = $faxcommand"

        if [ "$eisfax_exists" = "true" ] ; then
            echo " lpq command = /usr/bin/faxlpq %u"
            echo " lprm command = /usr/bin/faxlprm %j %u"
        else
            echo " lpq command = /var/install/bin/samba-print-pdf status"
        fi

        echo " create mode = 0700"
        echo
       } >>"$generate"
    fi

    if [ "$gs_exists" = "true" ] ; then
       {
        echo "[pdf]"
        echo " comment = pdf-service on %h"
        echo " printing = bsd"
        echo " use client driver = yes"
        echo " browseable = yes"
        echo " printable = yes"
        echo " path = $sambaspoolpath"
        echo " lpq command = /var/install/bin/samba-print-pdf status"
        echo " print command = ( /var/install/bin/samba-print-pdf '%s' '%J' '$pdflinuxdir' '$pdfwindir' '%m' '%I' '%u' '-dPDFSETTINGS=/default' '-sOwnerPassword=' '-sUserPassword=' '-dPermissions=' '$SAMBA_PDF_TARGET' '$smbinfo' '$pdfmessages' ) &"
        echo " create mode = 0700"
        echo
       } >>"$generate"
    fi

    #----------------------------------------------------------------------------
    # delete /etc/fstab-smbfs, if SAMBA_MANUAL_CONFIGURATION='no':
    #----------------------------------------------------------------------------
    rm -f "$fstabsmbfsfile"

    #----------------------------------------------------------------------------
    # create static /etc/user.map, if SAMBA_MANUAL_CONFIGURATION='no':
    #----------------------------------------------------------------------------
    do_usermapheader
    winnameprefix=''
    administrator='Administrator'
    if [ "$security" = "domain" ] ; then
        winnameprefix="$SAMBA_WORKGROUP\\"
        administrator="$winnameprefix"Administrator
    fi

    echo "root = \"$administrator\"" >>"$usermapfile"

    #----------------------------------------------------------------------------
    # remove dfs image, if SAMBA_MANUAL_CONFIGURATION='no':
    #----------------------------------------------------------------------------
    do_mount_dfs_image --u
    rm -f "$dfsimage"

    #----------------------------------------------------------------------------
    # end of automatic configuration (SAMBA_MANUAL_CONFIGURATION='no')
    #----------------------------------------------------------------------------
else
    #----------------------------------------------------------------------------
    # begin of manual configuration (SAMBA_MANUAL_CONFIGURATION='yes')
    #----------------------------------------------------------------------------

    #----------------------------------------------------------------------------
    # create /etc/user.map, if SAMBA_MANUAL_CONFIGURATION='yes':
    #----------------------------------------------------------------------------
    do_usermapheader
    >"/tmp/user.map.tmp"

    idx=1
    winnameprefix=''
    if [ "$security" = "domain" ] ; then
        winnameprefix="$SAMBA_WORKGROUP\\"
    fi

    while [ "$idx" -le "$SAMBA_USERMAP_N" ] ; do
        eval active='$SAMBA_USERMAP_'$idx'_ACTIVE'
        eval eisname='$SAMBA_USERMAP_'$idx'_EISNAME'
        eval winname_n='$SAMBA_USERMAP_'$idx'_WINNAME_N'
        create_mapping='true'

        if [ "$active" != "yes" ] ; then
            mecho --std "SAMBA_USERMAP_$idx is not active - skipping SAMBA_USERMAP_$idx ..."
            create_mapping='false'
        else
            if [ -z "`$pdbeditbin -Lw | grep "^$eisname:"`" ] ; then
                mecho --error "Samba user $eisname from SAMBA_USERMAP_"$idx"_EISNAME"
                mecho --error "  doesn't exist - skipping SAMBA_USERMAP_$idx ..."
                create_mapping='false'
            fi
        fi

        if [ "$create_mapping" = "true" ] ; then
            idy=1
            winmap=''
            while [ "$idy" -le "$winname_n" ] ; do
                eval winname='$SAMBA_USERMAP_'$idx'_WINNAME_'$idy
                if [ -z "$winmap" ] ; then
                    winmap=":$winnameprefix$winname:"
                else
                    winmap="$winmap :$winnameprefix$winname:"
                fi
                idy=`/usr/bin/expr $idy + 1`
            done

            echo "$eisname = $winmap" >>/tmp/user.map.tmp
        fi
        idx=`/usr/bin/expr $idx + 1`
    done

    sed 's/:/"/g' /tmp/user.map.tmp >>"$usermapfile"
    rm -f /tmp/user.map.tmp

    #----------------------------------------------------------------------------
    # create share(s), if SAMBA_MANUAL_CONFIGURATION='yes'
    #----------------------------------------------------------------------------
    idx='1'
    while [ "$idx" -le "$SAMBA_SHARE_N" ] ; do
        eval active='$SAMBA_SHARE_'$idx'_ACTIVE'
        eval name='$SAMBA_SHARE_'$idx'_NAME'
        eval comment='$SAMBA_SHARE_'$idx'_COMMENT'
        eval write='$SAMBA_SHARE_'$idx'_RW'
        eval browse='$SAMBA_SHARE_'$idx'_BROWSE'
        eval path='$SAMBA_SHARE_'$idx'_PATH'
        eval user='$SAMBA_SHARE_'$idx'_USER'
        eval public='$SAMBA_SHARE_'$idx'_PUBLIC'
        eval readlist='$SAMBA_SHARE_'$idx'_READ_LIST'
        eval writelist='$SAMBA_SHARE_'$idx'_WRITE_LIST'
        eval create='$SAMBA_SHARE_'$idx'_FORCE_CMODE'
        eval directory='$SAMBA_SHARE_'$idx'_FORCE_DIRMODE'
        eval force_user='$SAMBA_SHARE_'$idx'_FORCE_USER'
        eval force_group='$SAMBA_SHARE_'$idx'_FORCE_GROUP'
        a="$path"
        do_macro
        create_share='true'

        if [ "$active" != "yes" ] ; then
             mecho --std "SAMBA_SHARE_$idx is not active - skipping SAMBA_SHARE_$idx ..."
             create_share='false'
        fi

        if [ "$create_share" = "true" ] ; then
            if [ -z "$name" ] ; then
                mecho --error "SAMBA_SHARE_"$idx"_NAME is not defined - skipping SAMBA_SHARE_$idx ..."
                create_share='false'
            fi

            if [ -z "$path" ] ; then
                mecho --error "SAMBA_SHARE_"$idx"_PATH is not defined - skipping SAMBA_SHARE_$idx ..."
                create_share='false'
            fi

            if [ -n "$user" ] ; then
                do_check_user_group "$user" "SAMBA_SHARE_"$idx"_USER" "SAMBA_SHARE_$idx" "both"
            fi

            if [ -n "$readlist" ] ; then
                do_check_user_group "$readlist" "SAMBA_SHARE_"$idx"_READ_LIST" "SAMBA_SHARE_$idx" "both"
            fi

            if [ -n "$writelist" ] ; then
                do_check_user_group "$writelist" "SAMBA_SHARE_"$idx"_WRITE_LIST" "SAMBA_SHARE_$idx" "both"
            fi

            if [ -n "$force_user" ] ; then
                do_check_user_group "$force_user" "SAMBA_SHARE_"$idx"_FORCE_USER" "SAMBA_SHARE_$idx" "user"
            fi

            if [ -n "$force_group" ] ; then
                do_check_user_group "$force_group" "SAMBA_SHARE_"$idx"_FORCE_GROUP" "SAMBA_SHARE_$idx" "group"
            fi

            if [ ! -d "$path" ] ; then
                if [ "$is_macro" = "false" ] ; then
                    mkdir -p "$path"
                    if [ $? -ne 0 ] ; then
                        mecho --error "Cannot create directory $path for share $name on $HOSTNAME,"
                        mecho --error "check SAMBA_SHARE_"$idx"_PATH!"
                        create_share='false'
                    else
                        chmod 0777 "$path"
                    fi
                fi
            fi
        fi

        if [ "$create_share" = "true" ] ; then
           {
            echo "[$name]"
            echo " comment = $comment"
            echo " writeable = $write"

            if [ "`echo $name | tr [:upper:] [:lower:]`" = "homes" ] ; then
                echo " browseable = no"
                if [ "$SAMBA_PDC" = "yes" -a "$SAMBA_PDC_PROFILES" = "yes" ] ; then
                    echo " csc policy = disable"
                    #echo " profile acls = yes"
                fi
            else
                echo " browseable = $browse"
                echo " path = $path"

                if [ "$is_macro" = "false" ] ; then
                    do_mkdir_recycle
                fi
            fi

            if [ "$public" = "no" ] ; then
                if [ -n "$user" ] ; then
                    do_valid_users
                fi
            fi

            if [ -n "$readlist" ] ; then
                echo " read list = $readlist"
            fi

            if [ -n "$writelist" ] ; then
                echo " write list = $writelist"
            fi

            if [ "$path" = "/" ] ; then
                echo " dont descend = proc"
            fi

            if [ -n "$create" ] ; then
                echo " create mode = $create"
                echo " force create mode = $create"
            fi

            if [ -n "$directory" ] ; then
                echo " directory mode = $directory"
                echo " force directory mode = $directory"
            fi

            if [ -n "$force_user" ] ; then
                echo " force user = $force_user"
            fi

            if [ -n "$force_group" ] ; then
                echo " force group = $force_group"
            fi

            do_smbinfo
            vfs_objects=''
            do_check_vfs_recycle
            do_check_vfs_fullaudit
            do_check_vfs_dirsort
            do_write_vfs_objects
            do_write_vfs_fullaudit
            do_write_vfs_recycle
            echo
           } >>"$generate"
        fi
        idx=`/usr/bin/expr $idx + 1`
    done

    #----------------------------------------------------------------------------
    # create dfs root, if SAMBA_MANUAL_CONFIGURATION='yes'
    #----------------------------------------------------------------------------
    do_mount_dfs_image --u
    rm -f "$dfsimage"

    if [ "$SAMBA_DFSROOT_N" -gt 0 ] ; then
        do_make_dfs_image
        do_mount_dfs_image
        if "$mountbin" -t ext3 | grep "/dev/loop" | grep " $mountpoint " | grep -q '(rw'
        then
            idx='1'
            while [ "$idx" -le "$SAMBA_DFSROOT_N" ] ; do
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
                eval msdfs_lnkn='$SAMBA_DFSROOT_'$idx'_DFSLNK_N'
                path="$mountpoint/$name"
                create_share='true'

                if [ "$active" != "yes" ] ; then
                    mecho --std "SAMBA_DFSROOT_$idx is not active - skipping SAMBA_DFSROOT_$idx ..."
                    create_share='false'
                fi

                if [ "$create_share" = "true" ] ; then
                    if [ -z "$name" ] ; then
                        mecho --error "SAMBA_DFSROOT_"$idx"_NAME is not defined - skipping SAMBA_DFSROOT_$idx ..."
                        create_share='false'
                    fi

                    if [ -n "$user" ] ; then
                        do_check_user_group "$user" "SAMBA_DFSROOT_"$idx"_USER" "SAMBA_DFSROOT_$idx" "both"
                    fi

                    if [ -n "$readlist" ] ; then
                        do_check_user_group "$readlist" "SAMBA_DFSROOT_"$idx"_READ_LIST" "SAMBA_DFSROOT_$idx" "both"
                    fi

                    if [ -n "$writelist" ] ; then
                        do_check_user_group "$writelist" "SAMBA_DFSROOT_"$idx"_WRITE_LIST" "SAMBA_DFSROOT_$idx" "both"
                    fi

                    if [ -n "$force_user" ] ; then
                        do_check_user_group "$force_user" "SAMBA_DFSROOT_"$idx"_FORCE_USER" "SAMBA_DFSROOT_$idx" "user"
                    fi

                    if [ -n "$force_group" ] ; then
                        do_check_user_group "$force_group" "SAMBA_DFSROOT_"$idx"_FORCE_GROUP" "SAMBA_DFSROOT_$idx" "group"
                    fi

                    if [ ! -d "$path" ] ; then
                        mkdir -p -m 755 "$path"
                        if [ $? -ne 0 ] ; then
                            mecho --error "Cannot create directory $path for dfsroot $name on $HOSTNAME,"
                            mecho --error "skipping SAMBA_DFSROOT_$idx ..."
                            create_share='false'
                        fi
                    fi
                fi

                if [ "$create_share" = "true" ] ; then
                    idy='1'
                    while [ "$idy" -le "$msdfs_lnkn" ] ; do
                        msdfs_lnk_path=''
                        eval msdfs_lnkn_active='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_ACTIVE'
                        eval msdfs_lnkn_subpath='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_SUBPATH'
                        eval msdfs_lnkn_name='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_NAME'
                        eval msdfs_lnkn_uncn='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_UNC_N'
                        if [ "$msdfs_lnkn_active" = "yes" -a "$msdfs_lnkn_uncn" -gt 0 ] ; then
                            # remove trailing /
                            msdfs_lnkn_subpath=`echo "$msdfs_lnkn_subpath" | sed 's#/$##'`

                            if [ -z "$msdfs_lnkn_subpath" ] ; then
                                msdfs_lnk_path="${path}/${msdfs_lnkn_name}"
                            else
                                mkdir -p "${path}/${msdfs_lnkn_subpath}"
                                msdfs_lnk_path="${path}/$msdfs_lnkn_subpath/$msdfs_lnkn_name"
                            fi

                            # check for files or dirs with ${path}/$msdfssubpath/$msdfslnkname
                            if [ -e "$msdfs_lnk_path" -o -h "$msdfs_lnk_path" ] ; then
                                mecho --error "Cannot create msdfs link $msdfs_lnk_path,"
                                mecho --error "file, directory or symlink already exists!"
                                create_share='false'
                            else
                                idz='1'
                                msdfs_link=''
                                while [ "$idz" -le "$msdfs_lnkn_uncn" ] ; do
                                    eval msdfs_lnkn_uncn_path='$SAMBA_DFSROOT_'$idx'_DFSLNK_'$idy'_UNC_'$idz'_PATH'
                                    # remove leading and trailing \
                                    msdfs_lnkn_uncn_path=`echo "$msdfs_lnkn_uncn_path" | sed 's#^[\]*##; s#[\]*$##'`
                                    if [ -z "$msdfs_link" ] ; then
                                        msdfs_link="$msdfs_lnkn_uncn_path"
                                    else
                                        msdfs_link="$msdfs_link,$msdfs_lnkn_uncn_path"
                                    fi
                                    idz=`/usr/bin/expr $idz + 1`
                                done

                                ln -s msdfs:"$msdfs_link" "$msdfs_lnk_path"
                                if [ $? -ne 0 ] ; then
                                    mecho --error "Cannot create $msdfs_link!"
                                    create_share='false'
                                fi
                            fi
                        fi
                        idy=`/usr/bin/expr $idy + 1`
                    done
                fi

                if [ "$create_share" = "true" -a -n "`ls -lR "$path" 2>/dev/null | grep ' -> msdfs:'`" ] ; then
                   {
                    echo "[$name]"
                    echo " comment = $comment"
                    echo " msdfs root = yes"
                    echo " writeable = $rw"
                    echo " browseable = $browse"
                    echo " path = $path"

                    if [ "$public" = "no" ] ; then
                        if [ -n "$user" ] ; then
                            do_valid_users
                        fi
                    fi

                    if [ -n "$readlist" ] ; then
                        echo " read list = $readlist"
                    fi

                    if [ -n "$writelist" ] ; then
                        echo " write list = $writelist"
                    fi

                    if [ -n "$force_cmode" ] ; then
                        echo " create mode = $force_cmode"
                        echo " force create mode = $force_cmode"
                    fi

                    if [ -n "$force_dirmode" ] ; then
                        echo " directory mode = $force_dirmode"
                        echo " force directory mode = $force_dirmode"
                    fi

                    if [ -n "$force_user" ] ; then
                        echo " force user = $force_user"
                    fi

                    if [ -n "$force_group" ] ; then
                        echo " force group = $force_group"
                    fi

                    do_smbinfo
                    echo
                   } >>"$generate"
                fi
                idx=`/usr/bin/expr $idx + 1`
            done

            if [ -f "$dfsimage" -a -n "`ls -lR "$mountpoint" | grep ' -> msdfs:'`" ] ; then
                do_mount_dfs_image --u
                do_mount_dfs_image --ro
            else
                do_mount_dfs_image --u
                mecho --std "No msdfs link found, removing $dfsimage ..."
                rm -f "$dfsimage"
            fi
        else
            mecho --error "Cannot create $dfsimage or mount it --rw!"
        fi
    fi

    #----------------------------------------------------------------------------
    # create share(s) for printer(s), if SAMBA_MANUAL_CONFIGURATION='yes'
    #----------------------------------------------------------------------------
    idx=1
    while [ "$idx" -le "$SAMBA_PRINTER_N" ] ; do
        eval active='$SAMBA_PRINTER_'$idx'_ACTIVE'
        eval name='$SAMBA_PRINTER_'$idx'_NAME'
        eval type='$SAMBA_PRINTER_'$idx'_TYPE'
        eval pdfquality='$SAMBA_PRINTER_'$idx'_PDF_QUALITY'
        eval pdfuserpass='$SAMBA_PRINTER_'$idx'_PDF_USERPASS'
        eval pdfownerpass='$SAMBA_PRINTER_'$idx'_PDF_OWNERPASS'
        eval pdfpermissions='$SAMBA_PRINTER_'$idx'_PDF_PERMS'
        eval pdfmessages='$SAMBA_PRINTER_'$idx'_PDF_MESSAGES'
        eval printer='$SAMBA_PRINTER_'$idx'_CAPNAME'
        eval comment='$SAMBA_PRINTER_'$idx'_COMMENT'
        eval clientdriver='$SAMBA_PRINTER_'$idx'_CLIENTDRIVER'
        eval browse='$SAMBA_PRINTER_'$idx'_BROWSE'
        eval user='$SAMBA_PRINTER_'$idx'_USER'   
        eval public='$SAMBA_PRINTER_'$idx'_PUBLIC'   
        create_printer='true'

        if [ "$active" != "yes" ] ; then
            mecho --std "SAMBA_PRINTER_$idx is not active - skipping SAMBA_PRINTER_$idx ..."
            create_printer='false'
        fi

        if [ -z "$name" -a "$create_printer" = "true" ] ; then
            mecho --error "SAMBA_PRINTER_"$idx"_NAME is not defined - skipping SAMBA_PRINTER_$idx ..."
            create_printer='false'
        fi

        if [ "$create_printer" = "true" ] ; then
            faxprinter=''
            pdfprinter=''
            doit='true'

            case "$type" in
            fax)
                if [ "$eisfax_exists" = "true" -o "$hylafax_exists" = "true" ] ; then
                    faxprinter='true'
                    doit='true'
                else
                    faxprinter='false'
                    doit='false'
                    mecho --error "Skipping SAMBA_PRINTER_$idx for eisfax,"
                    mecho --error "because there is no faxserver installed!"
                fi
                ;;
            pdf)
                if [ "$gs_exists" = "true" ] ; then
                    pdfprinter='true'
                    doit='true'
                else
                    pdfprinter='false'
                    doit='false'
                    mecho --error "Skipping SAMBA_PRINTER_$idx for pdf-service,"
                    mecho --error "because there is no Ghostscript 1.2.0 or higher installed!"
                fi
                ;;
            printcap)
                if [ -z "$printer" ] ; then
                    mecho --error "Skipping SAMBA_PRINTER_$idx because this is no pdf-printer"
                    mecho --error "and no faxprinter and SAMBA_PRINTER_"$idx"_CAPNAME"
                    mecho --error "is not defined - read documentation!"
                    doit='false'
                else
                    if [ -z "`grep ^$printer: $printcap`" ] ; then
                        mecho --error "Skipping SAMBA_PRINTER_$idx because there is no entry"
                        mecho --error "$printer in $printcap. Check SAMBA_PRINTER_"$idx"_CAPNAME"
                        mecho --error "and read documentation!"
                        doit='false'
                    fi
                fi
                ;;
            esac

            if [ "$doit" = "true" ] ; then
               {
                echo "[$name]"
                echo " comment = $comment"

                if [ "$faxprinter" = "true" -o "$pdfprinter" = "true" ] ; then
                    echo " printing = bsd"
                    if [ "$faxprinter" = "true" ] ; then
                        echo " print command = $faxcommand"
                        if [ "$eisfax_exists" = "true" ] ; then
                            echo " lpq command = /usr/bin/faxlpq '%u'"
                            echo " lprm command = /usr/bin/faxlprm %j '%u'"
                        else
                            echo " lpq command = /var/install/bin/samba-print-pdf status"
                        fi
                    else
                        echo " print command = ( /var/install/bin/samba-print-pdf '%s' '%J' '$pdflinuxdir' '$pdfwindir' '%m' '%I' '%u' '-dPDFSETTINGS=/$pdfquality' '-sOwnerPassword=$pdfownerpass' '-sUserPassword=$pdfuserpass' '-dPermissions=$pdfpermissions' '$SAMBA_PDF_TARGET' '$smbinfo' '$pdfmessages' ) &"
                        echo " lpq command = /var/install/bin/samba-print-pdf status"
                    fi

                    echo " printable = yes"
                else
                    do_lprngprinting
                fi

                echo " use client driver = $clientdriver"
                echo " browseable = $browse"
                echo " path = $sambaspoolpath"

                if [ -n "$printer" ] ; then
                    echo " printer = $printer"
                fi

                if [ "$public" = "no" ] ; then
                    if [ -n "$user" ] ; then
                        do_valid_users
                    fi
                fi

                echo " create mode = 0700"
                echo
               } >>"$generate"
            fi
        fi
        idx=`/usr/bin/expr $idx + 1`
    done

    #----------------------------------------------------------------------------
    # create /etc/fstab-smbfs, if SAMBA_MANUAL_CONFIGURATION='yes'
    #----------------------------------------------------------------------------
    >"$fstabsmbfsfile"
    idx=1
    while [ "$idx" -le "$SAMBA_MOUNT_N" ] ; do
        eval active='$SAMBA_MOUNT_'$idx'_ACTIVE'
        eval vfstype='$SAMBA_MOUNT_'$idx'_VFSTYPE'
        eval server='$SAMBA_MOUNT_'$idx'_SERVER'
        eval share='$SAMBA_MOUNT_'$idx'_SHARE'
        eval point='$SAMBA_MOUNT_'$idx'_POINT'
        eval username='$SAMBA_MOUNT_'$idx'_USER'
        eval password='$SAMBA_MOUNT_'$idx'_PASS'
        eval rw='$SAMBA_MOUNT_'$idx'_RW'
        eval uid='$SAMBA_MOUNT_'$idx'_UID'
        eval gid='$SAMBA_MOUNT_'$idx'_GID'
        eval fmask='$SAMBA_MOUNT_'$idx'_FMASK'
        eval dmask='$SAMBA_MOUNT_'$idx'_DMASK'
        eval iocharset='$SAMBA_MOUNT_'$idx'_IOCHARSET'
        eval codepage='$SAMBA_MOUNT_'$idx'_CODEPAGE'
        create_mount='true'

        if [ "$active" != "yes" ] ; then
            mecho --std "SAMBA_MOUNT_$idx is not active - skipping SAMBA_MOUNT_$idx ..."
        fi

        if [ "$create_mount" = "true" ] ; then
            if [ "`echo $point | cut -c1`" != "/" ] ; then
                mecho --error "You must specify an absolut path with a leading '/',"
                mecho --error "skipping SAMBA_MOUNT_$idx ..."
                create_mount="false"
            else
                if [ ! -d $point ] ; then
                    mkdir -p "$point"
                    if [ $? -ne 0 ] ; then
                        mecho --error "Cannot create mountpoint - skipping SAMBA_MOUNT_$idx ..."
                        create_mount="false"
                    else
                        chown root.root "$point"
                        chmod 0777 "$point"
                    fi
                fi
            fi
        fi

        if [ "$create_mount" = "true" ] ; then
            if [ -z $vfstype ] ; then
                vfstype='smbfs'
            fi

            options="-o"
            if [ -z "$username" -a -z "$password" ] ; then
                options="$options guest"
            else
                if [ -n "$username" ] ; then
                    options="$options username=$username"
                fi

                if [ "$options" = "-o" ] ; then
                    options="$options password=$password"
                else
                    options="$options,password=$password"
                fi
            fi

            if [ "$rw" = "yes" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options rw"
                else
                    options="$options,rw"
                fi
            else
                if [ "$options" = "-o" ] ; then
                    options="$options ro"
                else
                    options="$options,ro"
                fi
            fi

            if [ -n "$uid" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options uid=$uid"
                else
                    options="$options,uid=$uid"
                fi
            fi

            if [ -n "$gid" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options gid=$gid"
                else
                    options="$options,gid=$gid"
                fi
            fi

            if [ -n "$fmask" ] ; then
                if [ "$vfstype" = "smbfs" ] ; then
                    if [ "$options" = "-o" ] ; then
                        options="$options fmask=$fmask"
                    else
                        options="$options,fmask=$fmask"
                    fi
                else
                    if [ "$options" = "-o" ] ; then
                        options="$options file_mode=$fmask"
                    else
                        options="$options,file_mode=$fmask"
                    fi
                fi
            fi

            if [ -n "$dmask" ] ; then
                if [ "$vfstype" = "smbfs" ] ; then
                    if [ "$options" = "-o" ] ; then
                        options="$options dmask=$dmask"
                    else
                        options="$options,dmask=$dmask"
                    fi
                else
                    if [ "$options" = "-o" ] ; then
                        options="$options dir_mode=$dmask"
                    else
                        options="$options,dir_mode=$dmask"
                    fi
                fi
            fi

            if [ -n "$iocharset" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options iocharset=$iocharset"
                else
                    options="$options,iocharset=$iocharset"
                fi
            fi

            if [ -n "$codepage" -a "$vfstype" = "smbfs" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options codepage=$codepage"
                else
                    options="$options,codepage=$codepage"
                fi
            fi

            if [ "$vfstype" = "smbfs" ] ; then
                if [ "$options" = "-o" ] ; then
                    options="$options lfs,debug=$debuglevel"
                else
                    options="$options,lfs,debug=$debuglevel"
                fi
            fi

            echo "//$server/$share:$point:$options:$active:$vfstype" >>"$fstabsmbfsfile"
        fi
        idx=`/usr/bin/expr $idx + 1`
    done

    #----------------------------------------------------------------------------
    # end of manual configuration (SAMBA_MANUAL_CONFIGURATION='yes')
    #----------------------------------------------------------------------------
fi

#----------------------------------------------------------------------------
# SAMBA_MANUAL_CONFIGURATION='no' _and_ SAMBA_MANUAL_CONFIGURATION='yes'
#
# create share for printer drivers, if /etc/printcap exists:
#----------------------------------------------------------------------------
if [ -f $printcap ] ; then
    driverpath='/samba_printer_drivers'
    for dir in COLOR IA64 W32ALPHA W32MIPS W32PPC W32X86 WIN40 x64
    do 
        mkdir -p "$driverpath/$dir"
    done

    chown -R root.root "$driverpath"
    chmod -R 0755 "$driverpath"

   {
    echo "[print$]"
    echo " comment = samba printer drivers on %h"
    echo " browseable = yes"
    echo " writeable = no"
    echo " path = $driverpath"
    echo " write list = root"
    echo
   } >>"$generate"
fi

#----------------------------------------------------------------------------
# include definitions of sambaexpert, if exists and SAMBA_EXPERT_EXEC=yes
#----------------------------------------------------------------------------
if [ "$sambaexpert_exists" = "true" -a "$SAMBA_EXPERT_EXEC" = "yes" ] ; then
    mecho --warn "SAMBA_EXPERT_EXEC is activated,"
    mecho --warn "don't ask for help, while this option is set!"
    echo "Merging sambaexpert definitions ..."
    /usr/sbin/mergeinifiles -u -t $generate -m /etc/config.d/sambaexpert
fi

#----------------------------------------------------------------------------
# costumizing and installing smbwebclient.php
#----------------------------------------------------------------------------
hostname=`echo $HOSTNAME | tr 'a-z' 'A-Z'`
smbwebclientwwwpath="/usr/share/doc/samba/tools/smbwebclient.www"
smbwebclientpath="/usr/share/doc/samba/tools/smbwebclient.php"
smbwebclientnewpath="$SAMBA_SMBWEBCLIENT_PATH/smbwebclient.php"
smbwebclientconfpath="/etc/smbwebclient.conf"
smbwebclientcharset="ISO-8859-1"
smbwebclientlang="en"

if [ "$SAMBA_SMBWEBCLIENT" = "yes" ] ; then
    case "$SAMBA_LOCALIZATION" in
    ISO8859-1|ISO8859-15)
        smbwebclientcharset="ISO-8859-15"
        smbwebclientlang="de"
        ;;
    UTF-8)
        smbwebclientcharset="UTF-8"
        smbwebclientlang="de"
        ;;
    esac

   {
    echo "<?php"
    echo "     class smbwebclient_config extends smbwebclient {"
    echo "     var \$cfgSambaRoot = '$SAMBA_WORKGROUP/$hostname';"
    echo "     var \$cfgDefaultLanguage = '$smbwebclientlang';"
    echo "     var \$cfgSmbClient = '/usr/bin/smbclient';"
    echo "     var \$cfgHideDotFiles = false;"
    echo "     var \$cfgHidePrinterShares = true;"
    echo "     var \$cfgDefaultCharset = '$smbwebclientcharset';"
    echo "     }"
    echo "?>"
   } >"$smbwebclientconfpath"

    chmod 0644 $smbwebclientconfpath
    chown root.root $smbwebclientconfpath

    if [ -d "$SAMBA_SMBWEBCLIENT_PATH" ] ; then
        cp -f $smbwebclientwwwpath $smbwebclientnewpath
        chmod 0755 $smbwebclientnewpath
        chmod 0755 $smbwebclientpath

        chown www-data.www-data $smbwebclientnewpath
        chown www-data.www-data $smbwebclientpath
    else
        mecho --error "SAMBA_SMBWEBCLIENT_PATH $SAMBA_SMBWEBCLIENT_PATH doesn't exist,"
        mecho --error "smbwebclient is not properly installed!"
    fi
else
    rm -f $smbwebclientnewpath
    rm -f $smbwebclientconfpath
fi

mkdir -p $sambaspoolpath
chown root.root $sambaspoolpath
chmod 1777 $sambaspoolpath
touch $tdbsamfile
chown root.root $tdbsamfile
chmod 0600 $tdbsamfile

if [ -f "$fstabsmbfsfile" ] ; then
    chown root.root $fstabsmbfsfile
    chmod 0600 $fstabsmbfsfile
fi

chown root.root $usermapfile
chmod 0644 $usermapfile
chown root.root $generate
chmod 0644 $generate

if ! grep -q "^tty:" /etc/group ; then
    /var/install/bin/add-group tty 5
fi

if [ -f /usr/share/doc/samba/tools/justpop.exe ] ; then
    chown nobody.nogroup /usr/share/doc/samba/tools/justpop.exe
    chmod 0755 /usr/share/doc/samba/tools/justpop.exe
fi

/usr/bin/pdbedit -P "min password length" -C 1 >/dev/null

if [ "`$pdbeditbin -Lw | wc -l`" -eq 0 ] ; then
    mecho --error "There are no samba users configured!"
else
    if ! "$pdbeditbin" -Lw | grep -q "^root:"
    then
        mecho --error "You have to add root as samba user!"
    fi
fi

do_remove_recycle_cron
do_add_recycle_cron

# set +x
