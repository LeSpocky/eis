#! /bin/sh
#------------------------------------------------------------------------------
# Creates an iso image of a bootable fli4l cd
#
# Last Update:    $Id: mkiso_emul.sh 17656 2009-10-18 18:39:00Z knibo $
#------------------------------------------------------------------------------

# include cleanup-functions
. ./unix/scripts/_lib_cleanup.sh

# include function to check command-line
. ./unix/scripts/parse_cmd.sh

# check parameters from commandline and current env
parse_cmdline $*

_file_iso='fli4l.iso'

if [ "$boot_type" != "cdemul" ]
then
    abort "- please set BOOT_TYPE='cdemul' in $dir_config/base.txt"
fi

. unix/scripts/mkopt.sh

show_header "--- creating the iso-image"
for i in mkisofs genisoimage
do
    if which $i > /dev/null 2>&1
    then
        mkiso=$i
        break
    fi
done

if [ ! "$mkiso" ]; then
    cat <<EOF | log_error
- mkisofs or genisoimage is needed to create iso-image,
  install mkisofs or genisoimage on your system.
EOF
    abort
fi

tmp_dir=/tmp/.mkiso.$$
if ! mkdir $tmp_dir; then
    abort "unable to create tmporary directory $tmp_dir"
fi

fl_rc=$tmp_dir/floppy.rc
fl_img=$tmp_dir/floppy.img

echo "drive a: file=\"$fl_img\"" > $fl_rc
MTOOLSRC="$fl_rc"
export MTOOLSRC

dd if=/dev/zero of=$fl_img bs=1024 count=1440
mformat -t 80 -h 2 -s 18 a:
syslinux -s $fl_img

mcopy -o "$dir_build/syslinux.cfg" a:
mcopy -o "$dir_build/kernel"       a:
mcopy -o "$dir_build/rootfs.img"   a:
mcopy -o "$dir_build/rc.cfg"       a:
[ -f "$dir_build/BOOT.MSG" ] && mcopy -o "$dir_build/BOOT.MSG" a:

cp "$dir_build/opt.img" "$dir_build/rc.cfg" $tmp_dir

# -A application id
# -V volume ID
# -J use joliet file names
# -r set owner to useful values

(
    cd $tmp_dir
    $mkiso -pad -A "fli4l" -V "fli4l" -o ../$_file_iso -J -r -b floppy.img -c boot.catalog .
)
mv /tmp/$_file_iso $dir_build

for i in BOOT.MSG  isolinux.bin  isolinux.cfg  kernel  opt.img  rc.cfg  rootfs.img; do
    rm -f $tmp_dir/$i
done
rm -f $fl_rc $fl_img
rmdir $tmp_dir

show_end
echo
echo "finished creation of your fli4l iso-image"
echo "- now you can burn it, and start your fli4l-router with the CD"
