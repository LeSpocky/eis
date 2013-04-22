#!/bin/sh
#------------------------------------------------------------------------------
# Coppy fli4l-files to tftpboot-directory
#
# Last Update:    $Id: mkpxeboot.sh 17656 2009-10-18 18:39:00Z knibo $
#------------------------------------------------------------------------------

my_echo ()
{
    echo "    $*"
}
my_run()
{
    echo "  $2 --> $3"
    $1 "$2" "$3"
}

. unix/scripts/mkopt.sh

show_header "--- Copying your fli4l-files to '$tftpboot_path/$pxe_subdir' ... "
copy_msg="Please copy the files manually by executing the following commands:"
pref=my_run
if [ ! -d "$tftpboot_path/" ]; then
    echo "Directory '$tftpboot_path' doesn't exist."
    pref=my_echo
    echo "$copy_msg"
elif [ ! -d "$tftpboot_path/$pxe_subdir" ]; then
    mkdir -p "$tftpboot_path/$pxe_subdir" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Could not create Directory '$tftpboot_path/$pxe_subdir'."
        pref=my_echo
        echo "$copy_msg"
    fi
elif [ ! -w "$tftpboot_path/$pxe_subdir" ]; then
    echo "Directory '$tftpboot_path/$pxe_subdir' is not writable."
    pref=my_echo
    echo "$copy_msg"
fi
$pref cp "$dir_build/kernel" "$tftpboot_path/$pxe_subdir"
$pref cp "$dir_build/rootfs.img" "$tftpboot_path/$pxe_subdir"
show_end
