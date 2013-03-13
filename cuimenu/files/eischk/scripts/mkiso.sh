#! /bin/sh
#------------------------------------------------------------------------------
# Creates an iso image of a bootable fli4l cd
#
# Last Update:    $Id: mkiso.sh 17656 2009-10-18 18:39:00Z knibo $
#------------------------------------------------------------------------------

# include cleanup-functions
. ./unix/scripts/_lib_cleanup.sh

# include function to check command-line
. ./unix/scripts/parse_cmd.sh

# check parameters from commandline and current env
parse_cmdline $*

_file_iso='fli4l.iso'

if [ "$boot_type" != "cd" ]
then
    abort "- please set BOOT_TYPE='cd' in $dir_config/base.txt"
fi
. unix/scripts/mkopt.sh

show_header "--- creating the iso-image"
if [ "$bool_test" = true ]; then
    isolinux_postfix=3
    postfix=-test
else
    isolinux_postfix=
    postfix=
fi

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
- mkisofs or genisoimage is needed to create iso-image"
  install mkisofs or genisoimage on your system"
EOF
    abort
fi

tmp_dir=/tmp/.mkiso.$$
if ! mkdir $tmp_dir; then
    abort "unable to create temporary directory $tmp_dir"
fi

chmod 700 $tmp_dir
cp img/isolinux.bin             $tmp_dir
cp "$dir_build/syslinux.cfg"    $tmp_dir/isolinux.cfg
cp "$dir_build/kernel"          $tmp_dir/kernel${isolinux_postfix}
cp "$dir_build/rootfs.img"      $tmp_dir/rootfs${isolinux_postfix}.img
cp "$dir_build/rc.cfg"          $tmp_dir/rc${postfix}.cfg
cp "$dir_build/opt.img"         $tmp_dir/opt${postfix}.img
[ -f "$dir_build/BOOT.MSG" ] && cp "$dir_build/BOOT.MSG" $tmp_dir

# -A application id
# -V volume ID
# -J use joliet file names
# -r set owner to useful values

$mkiso -A "fli4l" -V "fli4l" -J -r -o "$dir_build/$_file_iso" -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table $tmp_dir
for i in BOOT.MSG  isolinux.bin  isolinux.cfg  kernel  opt.img  rc.cfg  rootfs.img; do
    rm -f $tmp_dir/$i
done
rmdir $tmp_dir

show_end
echo
echo "finished creation of your fli4l iso-image"
echo "- now you can burn it, and start your fli4l-router with the CD"
