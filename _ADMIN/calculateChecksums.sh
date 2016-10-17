#! /bin/bash
# ----------------------------------------------------------------------------
# calculateChecksums.sh - Calculate checksums and update APKBUILD
#
# This is a helper script to calculate checksums and update APKBUILD. It's
# useful for development on non-Alpine environments where abuild is not
# available.
#
# Creation   :  2016-10-16  starwarsfan
#
# Copyright (c) 2013-2016 the eisfair team, team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/calculateChecksums-trace$$.txt
#set -x

rtc=0

usage ()
{
    cat <<EOF

  Usage:
  ${0} [options]
    This script calculates the checksums for all files listed on APKBUILD
    on current directory and updates them on APKBUILD itself. Additionally
    it is possible to commit this change.

    The checksums will be updated only for existing files listed on $source
    on APKBUILD, download-content like referenced source archives will be
    skipped.

  Optional parameters:
    -h|-?
       .. Show this help.
    -n .. Do not commit Change

EOF
}

calculateChecksums(){
    if [ ! -f APKBUILD ] ; then
        echo "APKBUILD not found, exiting"
        exit 1
    fi
    . APKBUILD
    for currentfile in ${source} ; do
        echo "Current file: ${currentfile}"
        md5sum -t ${currentfile} >> /tmp/md5sums.txt
        sha256sum -t ${currentfile} >> /tmp/sha256sums.txt
        sha512sum -t ${currentfile} >> /tmp/sha512sums.txt
    done
    echo -n "md5sums=\"" > /tmp/calculatedChecksums.txt
    sort -k2 /tmp/md5sums.txt >> /tmp/calculatedChecksums.txt
    echo -e -n "\"\nsha256sums=\"" >> /tmp/calculatedChecksums.txt
    sort -k2 /tmp/sha256sums.txt >> /tmp/calculatedChecksums.txt
    echo -e -n "\"\nsha512sums=\"" >> /tmp/calculatedChecksums.txt
    sort -k2 /tmp/sha512sums.txt >> /tmp/calculatedChecksums.txt
    echo "\"" >> /tmp/calculatedChecksums.txt
    cat /tmp/md5sums.txt
    cat /tmp/sha256sums.txt
    cat /tmp/sha512sums.txt
    cat /tmp/calculatedChecksums.txt
    rm -f /tmp/md5sums.txt
    rm -f /tmp/sha256sums.txt
    rm -f /tmp/sha512sums.txt
}

doCommit=true
while getopts "nh?" opt; do
 	case "$opt" in
 	    n) doCommit=false;;
     	h|?) usage && exit;;
 	esac
done

calculateChecksums
