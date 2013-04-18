#!/bin/sh
#------------------------------------------------------------------------------
# Creates a fli4l-bootimage for use with netboot/etherboot-compiled bootcode
#
# requires installed mknbi-linux!
# Download:  http://netboot.sourceforge.net
#
# Last Update:    $Id: mknetboot.sh 17656 2009-10-18 18:39:00Z knibo $
#------------------------------------------------------------------------------

# configuration parameters:

_imagefile="$tftpboot_path/$tftpboot_image"

# determine which flavour of mknbi-linux is installed (netboot or etherboot?)

_mknbi_binary=`which mknbi-linux`
if [ ! "$_mknbi_binary" ]; then
    abort "mknbi-linux not installed, please read the documentation."
fi

if file -L $_mknbi_binary | grep -q "perl script"; then
    _mknbiversion=etherboot
else
    _mknbiversion=netboot
fi

. unix/scripts/mkopt.sh

echo ""
echo "start of creating bootimage $_imagefile..."
echo "=============================================================================="
echo ""

# generate kernel cmd line
. "$dir_build/rc.cfg"

case $SER_CONSOLE in
    yes) _appendoption="console=ttyS$SER_CONSOLE_IF,${SER_CONSOLE_RATE}n8" ;;
    primary) _appendoption="console=tty0 console=ttyS$SER_CONSOLE_IF,${SER_CONSOLE_RATE}n8" ;;
    secondary) _appendoption="console=ttyS$SER_CONSOLE_IF,${SER_CONSOLE_RATE}n8 console=tty0" ;;
    no) ;;
esac

[ "$DEBUG_STARTUP" = yes ] && {
    _appendoption="$_appendoption fli4ldebug=yes"
}
[ -n "$DEBUG_LOG" -a "$DEBUG_STARTUP" = yes ] && {
    _appendoption="$_appendoption fli4ldeblog=$DEBUG_LOG"
}

_appendoption="$_appendoption $KERNEL_BOOT_OPTION"

(
    # create the network bootable image
    cd "$dir_build"

    if [ $_mknbiversion = "netboot" ]; then
        mknbi-linux -a "$_appendoption" -d /dev/tmpfs -r rootfs.img -k kernel -o "$_imagefile"
    else
        mknbi-linux --append "$_appendoption" --rootdir=/dev/tmpfs kernel rootfs.img > "$_imagefile"
    fi
)

echo ""
echo "finish of creating your bootimage"
echo ""
