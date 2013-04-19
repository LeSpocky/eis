#!/bin/sh
# ============================================================================
# /... - Script for ...
#
# Copyright (c) 2012 The eisfair Team, team(at)eisfair(dot)org
#
# Creation:    2013-04-18 starwarsfan
# Last Update:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ============================================================================

# Backup where we came from
callDir=`pwd`

# Go into the folder where the script is located and store the path.
# So all other scripts can be used directly
cd `dirname $0`
scriptDir=`pwd`
scriptName=`basename $0`

for currentFile in `git diff --name-only @{1}..` ; do
    # Check for changes but skip files on repo root and skip folder _ADMIN
    if [ "${currentFile%/*}" != "${currentFile}" -a "${currentFile%/*}" != '_ADMIN' ] ; then
        echo ${currentFile%/*} >> /tmp/determinedFolders-$$.txt
    fi
done

if [ -e /tmp/determinedFolders-$$.txt ] ; then
    # Wipe out duplicate folder entries
    sort -u /tmp/determinedFolders-$$.txt > /tmp/determinedFoldersUnique-$$.txt

    while read packageToTrigger ; do
        echo "Triggering build of package '$packageToTrigger' (TODO)"
    done < /tmp/determinedFoldersUnique-$$.txt

    rm -f /tmp/determinedFoldersUnique-$$.txt /tmp/determinedFolders-$$.txt
else
    echo "No changes on at least one of the package directories"
fi
