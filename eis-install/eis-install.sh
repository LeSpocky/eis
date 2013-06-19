#!/bin/bash
#
# Creation:     2013-05-27 jv <jens@eisfair.org>
# Copyright (c) 2000-2013 The Eisfair Team <team@eisfair.org>
#
# ############################################


hw_backtitle() {
    echo "alpine EIS - alpeis - Installation   $PDRIVE"
    return 0
}

IsValidIp() {
    if echo $1 | egrep -qs '\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' ; then
        return 0
    else
        return 1
    fi
}

getNextMenuItem () {
    : $(( n_item++ ))
}

PDRIVE=""
PKEYBLAYOUT=""
PKEYBVARIANT=""
PNETIPSTATIC="1"
PIPADDRESS="192.168.1.2"
PNETMASK="255.255.255.0"
PGATEWAY="192.168.1.1"
PHOSTNAME=""
PDOMAIN=""
PDNSSERVER=""
PTIMEZONE=""

while true ; do
    if [ "$PNETIPSTATIC" = "1" ] ; then
        n_item=$(dialog --stdout --no-shadow --no-cancel --item-help \
            --backtitle "$(hw_backtitle)" \
            --default-item "$n_item" \
            --title " Server configuration "  --clear \
            --menu "Base setup" 20 50 13 \
            0 "Return to Previous Menu" "Return to Previous Menu" \
            1 "Select disc" "Select disc to install Alpeis Server." \
            2 "Keyboard layout" "Setup the keyboard layout." \
            3 "Use DHCP for network" "Automatic IP-address of first network interface." \
            4 "IP-address" "IP-address of first network interface." \
            5 "Netmask" "Netmask of IP interface."\
            6 "Gateway" "Default Gateway for interface." \
            7 "Hostname" "System Hostname."\
            8 "Domain" "DNS Domain name." \
            9 "DNS Server" "DNS Server." \
            10 "Set timezone" "Set timezone" \
            11 "Start installation" "Start installation"  )
    else
        n_item=$(dialog --stdout --no-shadow --no-cancel --item-help \
            --backtitle "$(hw_backtitle)" \
            --default-item "$n_item" \
            --title "Server configuration"  --clear \
            --menu "Base setup" 20 50 13 \
            0 "Return to Previous Menu" "Return to Previous Menu" \
            1 "Select disc" "Select disc to install Alpeis Server." \
            2 "Keyboard layout" "Setup the keyboard layout." \
            3 "Use DHCP for network" "Automatic IP-address of first network interface." \
            7 "Hostname" "System Hostname."\
            8 "Domain" "DNS Domain name." \
            9 "DNS Server" "DNS Server." \
            10 "Set timezone" "Set timezone" \
            11 "Start installation" "Start installation"  )
    fi

    case ${n_item} in
        1)
            ### Select drive ######################################################
            drivelist=$(fdisk -l | sed -n 's/^Disk \(\/dev\/[^:]*\): \([^, ]*\) \([MGTB]*\).*$/\1 \2_\3 /p')
            if [ -z "$drivelist" ] ; then
                dialog --backtitle "$(hw_backtitle)" --title "" \
                    --msgbox " No drive found!\n Please try again." 6 30
            else                    
                new=$(dialog --stdout --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Select drive" \
                    --clear \
                    --menu "Select drive to partition:" 11 40 4 \
                    $drivelist )
                if [ "$?" -eq 0 ] ; then
                    PDRIVE="$new"    
                    getNextMenuItem
                fi
            fi
            ;;
        2)
            ### Keyboard configuration #########################################
            sellist=""
            cd /usr/share/bkeymaps
            for I in * ; do
                sellist="${sellist}${I} . "
            done
            PKEYBLAYOUT=$(dialog --stdout --no-shadow --no-cancel \
                --backtitle "$(hw_backtitle)" \
                --title "Keyboard configuration"  --clear \
                --menu "Select keyboard layout:" 18 40 11 \
                $sellist )
            sellist=""
            cd /usr/share/bkeymaps/$PKEYBLAYOUT
            for I in * ; do
                stemp="$(basename $I .bmap)"
                sellist="${sellist}$stemp . "
            done
            new=$(dialog --stdout --no-shadow --no-cancel \
                --backtitle "$(hw_backtitle)" \
                --title "Keyboard configuration"  --clear \
                --menu "Available variants:" 18 40 11 \
                $sellist )
            if [ "$?" -eq 0 ] ; then
                PKEYBVARIANT="$new"
                cat /usr/share/bkeymaps/$PKEYBLAYOUT/$PKEYBVARIANT.bmap | loadkmap
                getNextMenuItem            
            fi
            ;;
            ### DHCP ###########################################################
        3)
            dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Network interface IP-address"  --clear \
                --yesno "Get automatic IP-address with DHCP?" 5 40
            PNETIPSTATIC="$?"
            if [ "$PNETIPSTATIC" = "1" ] ; then
                getNextMenuItem
            else
                n_item="7"
            fi
            ;;
        4)
            ### IP-address #####################################################
            while true ; do
                new=$(dialog --stdout --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Network interface IP-address"  --clear \
                    --inputbox "Enter the IP-Address (192.168.1.2)" 10 45 "$PIPADDRESS")
                if [ "$?" -eq 0 ] ; then
                    if IsValidIp $new ; then
                        PIPADDRESS="$new"
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "$(hw_backtitle)" --title "" \
                            --msgbox " Wrong IP-address!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        5)
            ### Netmask ########################################################
            while true ; do
                new=$(dialog --stdout --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Network mask"  --clear \
                    --inputbox "Enter the network mask (255.255.255.0)" 10 45 "$PNETMASK")
                if [ "$?" -eq 0 ] ; then
                    if IsValidIp $new ; then
                        PNETMASK="$new"
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "$(hw_backtitle)" --title "" \
                            --msgbox " Wrong network mask!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        6)
            ### Gateway ########################################################
            while true ; do
                new=$(dialog --stdout --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Default gateway"  --clear \
                    --inputbox "Enter the default gateway (192.168.1.1)" 10 45 "$PGATEWAY")
                if [ "$?" -eq 0 ] ; then
                    if IsValidIp $new ; then
                        PGATEWAY="$new"
                        getNextMenuItem
                        break
                    else
                        dialog --backtitle "$(hw_backtitle)" --title "" \
                            --msgbox " Wrong default gateway!\n Please try again." 6 30
                    fi
                else
                    break
                fi
            done
            ;;
        7)
            ### Hostname #######################################################
            while true ; do
                new=$(dialog --stdout --no-shadow --backtitle "$(hw_backtitle)" \
                    --title "Management Hostname"  --clear \
                    --inputbox "Enter the system Hostname (Host only part of FQDN)\n For example, the Hostname of the FQDN \"myhost.some.domain\" is \"myhost\"." 10 55 "${PHOSTNAME}")
                if [ $? -eq 0 ] ; then
                    if [ "x${new}" == "x" ] ; then
                        dialog --stdout --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "$(hw_backtitle)" \
                            --title "Management Hostname"  --clear \
                            --msgbox "\n   Hostname cannot be null." 10 55
                        [ $? -eq 1 ] && break
                    elif [ "$(echo "${new}" | egrep -c "[\.|_]")" -gt 0 ] ; then
                        dialog --stdout --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "$(hw_backtitle)" \
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
        8)
            ### Domain #########################################################
            while true ; do
                new=$(dialog --stdout --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Domain Name"  --clear \
                    --inputbox "Enter the DNS domain if you have one (localhost if not).  The DNS domain will be appended to the Hostname to form the fully qualified domain name (FQDN)." 10 55 "${PDOMAIN}")

                if [ $? -eq 0 ] ; then
                    if [ "x${new}" == "x" ] ; then
                        dialog --stdout --no-shadow --cancel-label "Return to main menu"\
                            --backtitle "$(hw_backtitle)" \
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
        9)
            ### DNS Server #####################################################
            new=$(dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Management DNS Servers"  --clear \
                --inputbox " Enter a space delimited list of DNS Servers to be used by the Managment Interface" 10 45 "${PDNSSERVER}")
            if [ "$?" -eq 0 ] ; then
                PDNSSERVER="${new}"
                getNextMenuItem
            fi
            ;;
        10)
            ### Timezone #######################################################
            new=$(dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Set timezone" \
                --clear \
                --menu "Please select the geographic area in which you live:" 0 0 0 \
                'Africa'    'Africa' \
                'America'   'America' \
                'US'        'US time zones' \
                'Canada'    'Canada time zones' \
                'Asia'      'Asia' \
                'Atlantic'  'Atlantic Ocean'  \
                'Australia' 'Australia' \
                'Europe'    'Europe' \
                'Indian'    'Indian Ocean'  \
                'Pacific'   'Pacific Ocean')
            if [ "$?" -eq 0 ] ; then
                PTIMEZONE="${new}"
                getNextMenuItem
            fi
            ;;
        11)
            ### Start installation #############################################
            if [ -z "$PDRIVE" ] ; then
                # shell or reboot?
                exit 0
            fi   
            dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Start installation"  --clear \
                --yesno "Delete all partitions on ${PDRIVE}\nand start installation?" 6 40
            [ "$?" = "0" ] || exit 0
		    
            tempfile=/tmp/install.$$
            trap "rm -f $tempfile" 0 1 2 5 15
            
            date > /tmp/fdisk.log 
            dialog --no-shadow \
                --title "Start installation"  \
                --backtitle "$(hw_backtitle)" \
                --no-kill \
                --tailboxbg /tmp/fdisk.log 20 70 2>$tempfile
		    #PRINTK=`cat /proc/sys/kernel/printk`
		    #echo "0" >/proc/sys/kernel/printk
            #setup-disk -m sys ${PDRIVE} >>/tmp/fdisk.log
            sleep 2; kill -3 `cat $tempfile` 2>&1 >/dev/null 2>/dev/null
		    #sync; sync
            exit 0    

            if [ -n "$PKEYBVARIANT" ] ; then        
                mkdir -p "$ROOT/etc/keymap"
                mkdir -p "$ROOT/etc/conf.d/"
                if gzip -9 -c "$ROOT/usr/share/bkeymaps/$PKEYBLAYOUT/$PKEYBVARIANT.bmap" > "$ROOT/etc/keymap/$PKEYBVARIANT.bmap.gz" ; then
                    [ -f "$ROOT/etc/conf.d/keymaps" ] && sed -i '/^KEYMAP=/d' "$ROOT/etc/conf.d/keymaps"
                    echo "KEYMAP=/etc/keymap/$PKEYBVARIANT.bmap.gz" >> "$ROOT/etc/conf.d/keymaps"
                    rc-update -q add keymaps boot
                fi        
            fi
            
            ;;
        0)
            exit 0;
            ;;
    esac
done

exit 0
