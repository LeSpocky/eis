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
    cleanup

    # Get list of files to handle
    . APKBUILD

    # Calculate chksums for each file and write them to temp file
    for currentfile in ${source} ; do
        echo "Current file: ${currentfile}"
        md5sum -t ${currentfile} >> /tmp/md5sums.txt 2>/dev/null
        if [ $? -ne 0 ] ; then
            handleUnknownFile ${currentfile} /tmp/md5sums.txt "${md5sums}"
        fi
        sha256sum -t ${currentfile} >> /tmp/sha256sums.txt 2>/dev/null
        if [ $? -ne 0 ] ; then
            handleUnknownFile ${currentfile} /tmp/sha256sums.txt "${sha256sums}"
        fi
        sha512sum -t ${currentfile} >> /tmp/sha512sums.txt 2>/dev/null
        if [ $? -ne 0 ] ; then
            handleUnknownFile ${currentfile} /tmp/sha512sums.txt "${sha512sums}"
        fi
    done

    # Sort temp files
    sort -k2 /tmp/md5sums.txt >> /tmp/md5sums-sorted.txt
    sort -k2 /tmp/sha256sums.txt >> /tmp/sha256sums-sorted.txt
    sort -k2 /tmp/sha512sums.txt >> /tmp/sha512sums-sorted.txt

    # Create result
    readAndWriteContent /tmp/md5sums-sorted.txt "md5sums=\""
    readAndWriteContent /tmp/sha256sums-sorted.txt "sha256sums=\""
    readAndWriteContent /tmp/sha512sums-sorted.txt "sha512sums=\""

    # Remove existing checksums and add new list to APKBUILD
    # ToDo
    cat /tmp/calculatedChecksums.txt
    cleanup
}

readAndWriteContent(){
    local fileToRead=$1
    local placeholder=$2
    while read currentEntry ; do
        echo -e -n "${placeholder}${currentEntry}" >> /tmp/calculatedChecksums.txt
        placeholder="\n"
    done < ${fileToRead}
    echo "\"" >> /tmp/calculatedChecksums.txt
}

handleUnknownFile(){
    local currentfile=$1
    local destinationFile=$2
    local chksums=$3
    echo "$chksums" | while read currentChksum currentEntry ; do
        if echo "$currentfile" | grep -q "$currentEntry"; then
            echo "${currentChksum}  ${currentEntry}" >> ${destinationFile}
            return
        fi
    done
}

cleanup(){
    rm -f /tmp/md5sums*
    rm -f /tmp/sha256sums*
    rm -f /tmp/sha512sums*
    rm -f /tmp/calculatedChecksums.txt
}

doCommit=true
while getopts "nh?" opt; do
 	case "$opt" in
 	    n) doCommit=false;;
     	h|?) usage && exit;;
 	esac
done

calculateChecksums
