#! /bin/sh
#------------------------------------------------------------------------------
# Creates a fli4l-Floppy
#
# Last Update:    $Id: mkfloppy.sh 17656 2009-10-18 18:39:00Z knibo $
#------------------------------------------------------------------------------

parse_minfo ()
{
    while read _line
    do
        case $_line in
            'small size'*)
                set $_line
                echo "_sector_number=$3"
                ;;
            'sector size'*)
                set $_line
                echo "_sector_size=$3"
                ;;
            filename*)
                echo $_line
                ;;
        esac
    done
}

# include cleanup-functions
. ./unix/scripts/_lib_cleanup.sh

# include function to check command-line
. ./unix/scripts/parse_cmd.sh

# check parameters from commandline and current env
parse_cmdline $*

. unix/scripts/mkopt.sh

# check exist of mtools
if ! which minfo > /dev/null 2>&1
then
    cat <<EOF | log_error
- mtools are needed for boot-floppy creation
  Please install mtools on your system."
EOF
    abort
fi

echo ""
echo "starting to create the boot-floppy(s)"
echo "=============================================================================="
echo ""

if ! minfo ${drive}: > /dev/null 2>&1; then
    res="`minfo ${drive}: 2>&1 || true`"
    if echo $res | grep -i -q "no.*such.*file.*or.*directory"; then
        file=`echo $res | sed -e 's/.*[[:space:]]\([^[:space:]]*\):.*/\1/'`
        read -p "Shall I create $file as floppy device? [y/n] " reply
        case $reply in
            y)
                dir=`dirname $file`
                if [ ! -d  $dir ]; then
                    read -p "Shall I create directory $dir? [y/n] " reply
                    case $reply in
                        y) mkdir -p $dir ;;
                    esac
                fi
                if [ -d  $dir ]; then
                    dd if=/dev/zero of=$file bs=1024 count=1440
                    mformat -t 80 -h 2 -s 18 ${drive}:
                fi
                ;;
        esac
    fi
fi
if ! minfo ${drive}: > /dev/null 2>&1; then
    abort "No floppy device '${drive}:' found"
fi

eval `minfo ${drive}: | parse_minfo`

_bsize=`expr $_sector_size \* $_sector_number`
_size=`expr $_bsize \/ 1024`
_fdevice=$filename

case $boot_type in
    *1680)
        echo "using 1.68MB floppy..."
        _size='1680'
        _datasize=1640
        ;;
    *1440)
        echo "using 1.44MB floppy..."
        _size='1440'
        _datasize=1400
        ;;
    *)
        _msize=`echo $_size | sed -e 's/\(.*\)\([0-9][0-9]\)[0-9]/\1.\2MB/'`
        echo "using auto-detected floppy-size $_msize..."
        _datasize=`expr $_size - 40`
        ;;
esac
set -e

if ! which syslinux > /dev/null 2>&1; then
    cat <<EOF | log_error
- syslinux is needed to create boot-floppy,
  install syslinux on your system.
EOF
    abort
fi

if ! syslinux $suffix $_fdevice; then
    cat <<EOF | log_error
- an error has occurred while executing syslinux"
- check for write access to $_fdevice"
EOF
    abort
fi

echo ""
echo "copying syslinux.cfg..."
error=
mcopy -o "$dir_build/syslinux.cfg" $drive:SYSLINUX.CFG || error=true

echo "copying kernel..."
mcopy -o "$dir_build/kernel" $drive:KERNEL || error=true

echo "copying rootfs.img..."
mcopy -o "$dir_build/rootfs.img" $drive:ROOTFS.IMG || error=true

echo "copying rc.cfg..."
mcopy -o "$dir_build/rc.cfg" $drive:RC.CFG || error=true

case $boot_type in
    dual*|fdx2)
        _blocksize='1k'

        echo "copying opt.img... (BOOT_DISK)"
        dd if="$dir_build/opt.img" bs=$_blocksize skip=$_datasize \
            | mcopy -o - $drive:OPT.IMG || error=true
        cat <<EOF
If everything is ok, remove this Disk, insert a second floppy
and press <ENTER> (this will be the OPT_DISK),
otherwise press a<ENTER> to abort"
EOF
        read _a
        if [ "$_a" != "a" ]; then
            echo "copying opt.img... (OPT_DISK)"
            dd if="$dir_build/opt.img" bs=$_blocksize count=$_datasize \
                | mcopy -o - $drive:OPT.IMG || error=true
        fi
        ;;
    *)
        echo "copying opt.img..."
        mcopy -o "$dir_build/opt.img" $drive:OPT.IMG || error=true
        ;;
esac

if [ "$error" = "true" ]; then
    cat <<EOF

- an error has occurred while copying files to the floppy
- maybe your floppy is full or corrupt
EOF
    abort
else
    echo ""
    echo "finished creation of your fli4l-floppy(s)"
    echo "- You may now start your router with the new floppy."
    echo ""
fi
