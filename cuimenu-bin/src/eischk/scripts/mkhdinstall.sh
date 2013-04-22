#! /bin/sh
# -------------------------------------------------------------------------
# creates a script to do a direct-hd-install                   3.6.2
#
# Creation:       2008-02-24 jb / LanSpezi
# Last Update:    $Id: mkhdinstall.sh 20065 2011-09-06 20:16:23Z sklein $
# -------------------------------------------------------------------------

scr_mounted=

example()
{
    cat <<EOF
Either add

    <device> <mount point> vfat rw,user,noauto,umask=000 0 0

to /etc/fstab or mount the device before invoking mkfli4l.sh,
for instance  like follows

    [sudo] mount <device> <mount point> -t vfat -o umask=000

or as complete sequence:

    sudo mount <device> <mount point> -t vfat -o umask=000 && \
    sh mkfli4l.sh --hdinstallpath <mount point> ; \
    sudo umount <mount point>

EOF
}
check_mount()
{
    device=
    line=`mount | grep "on $1"`
    if [ "$line" ]; then
        set $line
        real_device=$1
        device=`echo $1 | sed -e 's#.*/##;s#[0-9]*$##'`
        fs=$5
        return 0
    fi
    return 1
}

mkhdinstall ()
{
    if ! check_mount $hdinstall_path; then
        # try to mount it as normal user
        scr_mounted=yes
        echo "-> mounting $hdinstall_path ..."
        if ! mount $hdinstall_path 2> /dev/null || ! check_mount $hdinstall_path; then
            # still not mounted, so no user entry in /etc/fstab
            {
                cat <<EOF
Unable to mount usb device, please either mount it before invoking
mkfli4l.sh or add an entry in /etc/fstab allowing us to mount the device.
EOF
                example
            } | log_error
            abort
        fi
    fi
    if [ "$fs" != vfat ]; then
        abort "Wrong file system on device $real_device, we expect 'vfat', but it is '$fs'."
    fi
	if [ "`cat /sys/block/$device/removable`" != "1" ]; then
	    if [ -z "`ls -l /sys/dev/block/ | grep $device$ | grep usb`" ]; then
            echo "'$device' does not seem to be a removeable device."
		    echo "If you realy know what you're doing type: YES!!!"
		    read answer
		    if [ "$answer" != "YES" ]
			    then abort
		    fi
	    fi
	fi
    if [ ! -d $hdinstall_path -o ! -w  $hdinstall_path -o ! -x  $hdinstall_path ]; then
        {
            echo "$hdinstall_path not writable for us, please specify umask=000 as option to mount"
            example
        } | log_error
        abort
    fi

    # ready to go, device mounted, usb device, correct file system, writable
    cf_errors=0
    if ! echo "hd_boot=hda1" > $hdinstall_path/hd.cfg; then
        cf_errors=1
    else
        if [ -f "$dir_build"/BOOT.MSG ]; then
            echo "   boot.msg"
            if ! cp "$dir_build"/BOOT.MSG $hdinstall_path/boot.msg; then
                cf_errors=1
            fi
        fi
               if [ -f "$dir_build"/BOOT_S.MSG ]; then
            echo "   boot_s.msg"
            if ! cp "$dir_build"/BOOT_S.MSG $hdinstall_path/boot_s.msg; then
                cf_errors=1
            fi
        fi
        if [ -f "$dir_build"/BOOT_Z.MSG ]; then
            echo "   boot_z.msg"
            if ! cp "$dir_build"/BOOT_Z.MSG $hdinstall_path/boot_z.msg; then
                cf_errors=1
            fi
        fi
        for file in rc.cfg opt.img kernel rootfs.img syslinux.cfg; do
            if [ -f "$dir_build"/$file ]; then
                echo "   $file"
                if ! cp "$dir_build"/$file $hdinstall_path; then
                    cf_errors=1
                fi
            fi
        done
    fi

    if [ "$scr_mounted" = yes ]; then
        echo "-> unmounting $hdinstall_path"
        umount $hdinstall_path || abort "failed to unmount $hdinstall_path"
    fi
    [ $cf_errors -eq 0 ] || abort "Something went wrong. Get help."
}

show_header "--- trying to copy files to install medium"
mkhdinstall
show_end

show_header "--- Additional actions for first installations"
cat <<EOF

Files successfully transferred. If this is your first install on this
medium please execute the following commands as root (make sure, you
use the correct device):

    # write a fresh master boot record
    syslinux --mbr /dev/$device

    # make partition bootable using fdisk
    #     p - print partitions
    #     a - toggle bootable flag, specify number of fli4l partition
    #         usually '1'
    #     w - write changes and quit
    fdisk /dev/$device

    # install boot loader
    syslinux -i $real_device
EOF
show_end

if [ "$scr_mounted" != yes ]; then
    echo -e "\nDo not forget to 'umount $hdinstall_path' before removing the medium\n"
fi
echo -e 'Insert "disk" into your router and start.\nGood luck.\n'
