#!/bin/sh
# -------------------------------------------------------------------------
# functions to remove not needed files                         3.6.2
#
# Creation:       lanspezi 2004-10-25
# Last Update:    $Id: _lib_cleanup.sh 18967 2010-12-23 14:58:34Z lanspezi $
# -------------------------------------------------------------------------

cleanup ()
{
    if [ -d "$dir_build" ]; then
        for i in opt_full.tmp rootfs.list opt.list; do
            rm -f "$dir_build"/$i
        done
    fi
}


cleanup_fli4lfiles ()
{
    if [ -d "$dir_build" ]; then
        _fli4l_files="kernel rootfs.img rc.cfg opt_tar.bz2 opt.img syslinux.cfg full_rc.cfg fli4l.iso mkfli4l.log mkfli4l_error.log mkfli4l_error.flg BOOT.MSG BOOT_S.MSG BOOT_Z.MSG BOOT_T.MSG"
        for _file in $_fli4l_files; do
            rm -f "$dir_build/$_file"
        done
    fi
    rm -f "${dir_config}/etc/rc.cfg"
}

cleanup_mkfli4l ()
{
    cd unix
    make clean
    cd ..
}
