#!/bin/bash
# Creation:     2013-05-27 jv <jens@eisfair.org>
# Copyright (c) 2000-2015 The eisfair Team <team@eisfair.org>
#-------------------------------------------------------------------------------
# ToDo: LVM option for /data or/and /
#       correct timezone select
#       optional view logfile


isValidIp() {
    if echo "$1" | egrep -qs '\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' ; then
        return 0
    else
        return 1
    fi
}


countDisks() {
    if [ $# -gt 1 ] ; then
        return 0
    else
        return 1
    fi
}


show_disk_info() {
    local disk="$1"
    local size=0
    size=$(awk '{gb = ($1 * 512)/1000000000; printf "%.1f_GB\n", gb}' /sys/block/$disk/size 2>/dev/null)
    echo "/dev/$disk $size on"
}


is_available_disk() {
    local p="$1"
    # skipping cd-rom sr0
    [ "$p" = "sr0" ] && return 1
    # check if its a "root" block device and not a partition
    [ -e /sys/block/$p ] || return 1
    # check so it does not have mounted partitions
    has_mounted_part $p && return 1
    # check so its not an md device
    [ -e /sys/block/$p/md ] && return 1
    return 0
}


has_mounted_part() {
    local p=""
    local sysfsdev="$1"
    # parse /proc/mounts for mounted devices
    for p in $(awk '$1 ~ /^\/dev\// {gsub("/dev/", "", $1); gsub("/", "!", $1); print $1}' /proc/mounts); do
        [ "$p" = "$sysfsdev" ] && return 0
        [ -e /sys/block/$sysfsdev/$p ] && return 0
    done
    return 1
}


find_disks() {
    local p=""
    # filter out ramdisks (major=1)
    for p in $(awk '$1 != 1 && $1 ~ /[0-9]+/ {print $4}' /proc/partitions); do
        is_available_disk $p && show_disk_info "$p"
    done
}


calulate_swap_size() {
    local memtotal_kb=$(awk '$1 == "MemTotal:" {print $2}' /proc/meminfo)
    local size=$(( $memtotal_kb * 2 / 1024 ))
    local disk= disksize=
    for disk in $@; do
        local sysfsdev=$(echo ${disk#/dev/} | sed 's:/:!:g')
        local sysfspath=/sys/block/$sysfsdev/size
        maxsize=$(awk '{ printf "%i", $0 / 8192 }' $sysfspath )
        if [ $size -gt $maxsize ]; then
            size=$maxsize
        fi
    done
    if [ $size -gt 4096 ]; then
        # dont ever use more than 4G
        size=4096
    elif [ $size -lt 64 ]; then
        # dont bother create swap smaller than 64MB
        size=0
    fi
    echo $size
}


getNextMenuItem () {
    : $(( n_item++ ))
}


PDISKMODE="sys"
PDRIVE=""
PRAIDLEVEL=""
PLVM=""
PROOTFS="ext4"
PSWAPSIZE="512"
PKEYBLAYOUT="de"
PKEYBVARIANT="de-latin1"
PNETIPSTATIC="1"
PIPADDRESS="192.168.1.2"
PNETMASK="255.255.255.0"
PGATEWAY="192.168.1.1"
PHOSTNAME="eis"
PDOMAIN="eisfair.home"
PDNSSERVER=""
PTIMEZONE="Europe/Berlin"
PPASSWORD="eis"
POPTIONS=""

n_item="1"

# add packages for install setup and load default keymap and
apk add -q bkeymaps
[ -f "/usr/share/bkeymaps/$PKEYBLAYOUT/$PKEYBVARIANT.bmap" ] && cat "/usr/share/bkeymaps/$PKEYBLAYOUT/$PKEYBVARIANT.bmap" | loadkmap

while true ; do
    if [ "$PNETIPSTATIC" = "1" ] ; then
        n_item=$(dialog --no-shadow --no-cancel --item-help \
            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
            --default-item "$n_item" \
            --title " Server configuration "  --clear \
            --menu "Base setup" 22 50 15 \
             0 "Shell login" "Return to login" \
             1 "Select disc" "Select disc for installation." \
             2 "Partition options" "Set options of swap/root partition." \
             3 "Keyboard layout" "Setup the keyboard layout." \
             4 "Use DHCP for network" "Automatic IP-address of first network interface." \
             5 "IP-address" "IP-address of first network interface." \
             6 "Netmask" "Netmask of IP interface."\
             7 "Gateway" "Default Gateway for interface." \
             8 "DNS Server" "DNS Server." \
             9 "Hostname" "System Hostname."\
            10 "Domain" "DNS Domain name." \
            11 "Root password" "Set password for user root." \
            12 "Start installation" "Start installation." \
            13 "Reboot server" "Reboot server after installation." \
            14 "Show logfile" "Show installation logfile." 3>&1 1>&2 2>&3 3>&-)
    else
        n_item=$(dialog --no-shadow --no-cancel --item-help \
            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
            --default-item "$n_item" \
            --title "Server configuration"  --clear \
            --menu "Base setup" 22 50 15 \
             0 "Shell login" "Return to login" \
             1 "Select disc" "Select disc for installation." \
             2 "Partition options" "Set options of swap/root partition." \
             3 "Keyboard layout" "Setup the keyboard layout." \
             4 "Use DHCP for network" "Automatic IP-address of first network interface." \
             9 "Hostname" "System Hostname."\
            10 "Domain" "DNS Domain name." \
            11 "Root password" "Set password for user root." \
            12 "Start installation" "Start installation." \
            13 "Reboot server" "Reboot server after installation." \
            14 "Show logfile" "Show installation logfile." 3>&1 1>&2 2>&3 3>&-)
    fi

    case ${n_item} in
        1)
            ### Select drive ######################################################
            drivelist=$(find_disks)
            if [ -z "$drivelist" ] ; then
                dialog --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" --title "" \
                    --msgbox " No drive found!\n Please try again." 6 30
            else
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Select drive" \
                    --clear \
                    --checklist "Select drive(s) to partition:" 12 40 6 \
                    $drivelist 3>&1 1>&2 2>&3 3>&-)
                if [ -n "$new" ] ; then
                    if countDisks $new ; then
                        dialog --no-shadow \
                            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                            --title "Software RAID installation"  --clear \
                            --yesno "Use drives for RAID:\n${new}" 7 40
                        if [ "$?" = "0" ] ; then
                            PRAIDLEVEL="1"
                            PDRIVE="$new"
                            getNextMenuItem
                        fi
                    else
                        PRAIDLEVEL=""
                        PDRIVE="$new"
                        getNextMenuItem
                    fi
                fi
            fi
            ;;
        2)
            if [ -z "$PDRIVE" ] ; then
                n_item="1"
            else
                new=$(dialog --no-shadow --no-cancel \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "File system configuration"  --clear \
                    --checklist "Options" 9 61 5 \
                      "BTRFS" "Use BTRFS for root partition." off \
                    3>&1 1>&2 2>&3 3>&-)
                      #"LVM"   "Use LVM for root and swap partition." off \
                PLVM=""    
                case "$new" in
                    *LVM*) PLVM="1" ;;
                esac
                PROOTFS="ext4"
                case "$new" in
                    *BTRFS*) PROOTFS="btrfs" ;;
                esac
                PSWAPSIZE=$(calulate_swap_size ${PDRIVE})
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Adjust size of swap Partition"  --clear \
                    --inputbox "Size in MB:" 10 45 "$PSWAPSIZE" 3>&1 1>&2 2>&3 3>&-)
                if [ "$?" -eq 0 ] ; then
                    PSWAPSIZE="$new"
                    getNextMenuItem
                fi
            fi
            ;;
        3)
            ### Keyboard configuration #########################################
            sellist=""
            cd /usr/share/bkeymaps
            for I in * ; do
                sellist="${sellist}${I} . "
            done
            PKEYBLAYOUT=$(dialog --no-shadow --no-cancel \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --default-item "$PKEYBLAYOUT" \
                --title "Keyboard configuration"  --clear \
                --menu "Select keyboard layout:" 18 40 11 \
                $sellist 3>&1 1>&2 2>&3 3>&-)
            sellist=""
            cd /usr/share/bkeymaps/$PKEYBLAYOUT
            for I in * ; do
                stemp="$(basename $I .bmap)"
                sellist="${sellist}$stemp . "
            done
            new=$(dialog --no-shadow --no-cancel \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --default-item "$PKEYBVARIANT" \
                --title "Keyboard configuration"  --clear \
                --menu "Available variants:" 18 40 11 \
                $sellist 3>&1 1>&2 2>&3 3>&-)
            if [ "$?" -eq 0 ] ; then
                PKEYBVARIANT="$new"
                cat /usr/share/bkeymaps/$PKEYBLAYOUT/$PKEYBVARIANT.bmap | loadkmap
                getNextMenuItem
            fi
            ;;
            ### DHCP ###########################################################
        4)
            dialog --no-shadow \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --title "Network interface IP-address"  --clear \
                --yesno "Get automatic IP-address with DHCP?" 5 40
            PNETIPSTATIC="$?"
            if [ "$PNETIPSTATIC" = "1" ] ; then
                getNextMenuItem
            else
                n_item="9"
            fi
            ;;
        5)
            ### IP-address #####################################################
            while true ; do
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Network interface IP-address"  --clear \
                    --inputbox "Enter the IP-Address (192.168.1.2)" 10 45 "$PIPADDRESS" 3>&1 1>&2 2>&3 3>&-)
                if [ "$?" -eq 0 ] ; then
                    if isValidIp $new ; then
                        PIPADDRESS="$new"
                        case "$PIPADDRESS" in
                            172.*) PNETMASK="255.255.0.0" ;;
                            10.*) PNETMASK="255.0.0.0" ;;
                        esac
                        PGATEWAY=`echo "$PIPADDRESS" | sed -r "s/^([0-9]{1,3}\.)([0-9]{1,3}\.)([0-9]{1,3}\.)([0-9]{1,3})/\1\2\31/"`
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" --title "" \
                            --msgbox " Wrong IP-address!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        6)
            ### Netmask ########################################################
            while true ; do
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Network mask"  --clear \
                    --inputbox "Enter the network mask (255.255.255.0)" 10 45 "$PNETMASK" 3>&1 1>&2 2>&3 3>&-)
                if [ "$?" -eq 0 ] ; then
                    if isValidIp $new ; then
                        PNETMASK="$new"
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" --title "" \
                            --msgbox " Wrong network mask!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        7)
            ### Gateway ########################################################
            while true ; do
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Default gateway"  --clear \
                    --inputbox "Enter the default gateway (192.168.1.1)" 10 45 "$PGATEWAY" 3>&1 1>&2 2>&3 3>&-)
                if [ "$?" -eq 0 ] ; then
                    if isValidIp $new ; then
                        PGATEWAY="$new"
                        [ -z "$PDNSSERVER" ] && PDNSSERVER="$PGATEWAY"
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" --title "" \
                            --msgbox " Wrong default gateway!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        8)
            ### DNS Server #####################################################
            new=$(dialog --no-shadow \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --title "Management DNS Servers"  --clear \
                --inputbox " Enter a space delimited list of DNS Servers to be used by the Managment Interface" 10 45 "${PDNSSERVER}" 3>&1 1>&2 2>&3 3>&-)
            if [ "$?" -eq 0 ] ; then
                PDNSSERVER="${new}"
                getNextMenuItem
            fi
            ;;
        9)
            ### Hostname #######################################################
            while true ; do
                new=$(dialog --no-shadow --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Management Hostname"  --clear \
                    --inputbox "Enter the system Hostname (Host only part of FQDN)\n For example, the Hostname of the FQDN \"myhost.some.domain\" is \"myhost\"." 10 55 "${PHOSTNAME}" 3>&1 1>&2 2>&3 3>&-)
                if [ $? -eq 0 ] ; then
                    if [ "x${new}" == "x" ] ; then
                        dialog --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                            --title "Management Hostname"  --clear \
                            --msgbox "\n   Hostname cannot be null." 10 55
                        [ $? -eq 1 ] && break
                    elif [ "$(echo "${new}" | egrep -c "[\.|_]")" -gt 0 ] ; then
                        dialog --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                            --title "Management Hostname"  --clear \
                            --msgbox "\n   Hostname cannot contian \".\" or \"_\" ." 10 55
                        [ $? -eq 1 ] && break
                    else
                        PHOSTNAME="${new}"
                        getNextMenuItem
                        break
                    fi
                elif [ $? -eq 1 ] ; then
                    break
                fi
            done
            ;;
       10)
            ### Domain #########################################################
            while true ; do
                new=$(dialog --no-shadow \
                    --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                    --title "Domain Name"  --clear \
                    --inputbox "Enter the DNS domain if you have one (localhost if not).  The DNS domain will be appended to the Hostname to form the fully qualified domain name (FQDN)." 12 55 "${PDOMAIN}" 3>&1 1>&2 2>&3 3>&-)

                if [ $? -eq 0 ] ; then
                    if [ "x${new}" == "x" ] ; then
                        dialog --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                            --title "Management Domain Name"  --clear \
                            --msgbox "\n   Domain cannot be null." 10 55
                        [ $? -eq 1 ] && break;
                    else
                        PDOMAIN="${new}"
                        getNextMenuItem
                        break
                    fi
                elif [ $? -eq 1 ] ; then
                    break
                fi
            done
            ;;
        11)
            ### root password ##################################################
            new=$(dialog --no-shadow \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --title "Set root password" \
                --clear --no-cancel --insecure \
                --passwordbox "Enter a password for user root" 10 45 "${free}" 3>&1 1>&2 2>&3 3>&-)
            new2=$(dialog --no-shadow \
                --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                --title "Confirm root password" \
                --clear --no-cancel --insecure \
                --passwordbox "Re enter password for user root" 10 45 "${free}" 3>&1 1>&2 2>&3 3>&-)
            if [ "$?" -eq 0 ] ; then
                if [ "$new" = "$new2" ] ; then
                    PPASSWORD="${new}"
                    getNextMenuItem
                else
                    dialog --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" --title "" \
                      --msgbox " Password not match!\n Please try again." 6 30
                fi
            fi
            ;;
        12)
            ### Start installation #############################################
            if [ -n "$PDRIVE" ] ; then
                dialog --no-shadow \
                  --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                  --title "Start installation"  --clear \
                  --yesno "Delete all partitions on drive(s):\n${PDRIVE}\nand start installation?" 8 40
                if [ "$?" = "0" ] ; then
                    export ROOTFS="$PROOTFS"
                    export PNETIPSTATIC="$PNETIPSTATIC"
                    export PNETMASK="$PNETMASK"
                    export PDOMAIN="$PDOMAIN"
                    export PIPADDRESS="$PIPADDRESS"
                    export PGATEWAY="$PGATEWAY"
                    export PDNSSERVER="$PDNSSERVER"
                    export PKEYBLAYOUT="$PKEYBLAYOUT"
                    export PKEYBVARIANT="$PKEYBVARIANT"                    
                    [ -n "$PLVM" ] && POPTIONS="$POPTIONS -L"
                    if [ -n "$PRAIDLEVEL" ] 
                    then
                        POPTIONS="$POPTIONS -r"
                        # install mdadm for stop old raid disks                    
                        apk add --quiet mdadm
                    fi
                    PRINTK=$(cat /proc/sys/kernel/printk)
                    echo "0" >/proc/sys/kernel/printk
                    tempfile=/tmp/install.$$
                    trap "rm -f $tempfile" 0 1 2 5 15
                    date > /tmp/fdisk.log 
                    dialog --no-shadow \
                      --title "Start installation"  \
                      --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
                      --no-kill \
                      --tailboxbg /tmp/fdisk.log 21 75 2>$tempfile
                    /bin/eis-install.setup-disk -m "$PDISKMODE" -P "$PPASSWORD" -s "$PSWAPSIZE" \
                        ${POPTIONS} $PDRIVE >>/tmp/fdisk.log 2>&1
                    sleep 3; kill -3 `cat $tempfile` 2>&1 >/dev/null 2>/dev/null
                    echo "$PRINTK" > /proc/sys/kernel/printk
                    getNextMenuItem
                fi
            else
                n_item="1"
            fi
            ;;
        13)
            ### Reboot server ##################################################
            echo "1" > /reboot
            clear 
            break
            ;;
        14)
            ### Show installation log file #####################################
            dialog --no-shadow \
              --backtitle "Alpine Linux with eisfair-ng - Installation   $PDRIVE" \
              --textbox /tmp/fdisk.log 22 80
            ;;    
        0)
            ### Switch to console ##############################################
            break
            ;;
    esac
done

exit 0
