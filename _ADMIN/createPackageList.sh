#! /bin/bash
# ----------------------------------------------------------------------------
# createPackageList.sh - Create a list of all known packages. This list will
#                        be used as the selection for the package release
#                        builds
#
# Creation   :  2013-11-11  starwarsfan
#
# Copyright (c) 2013 the eisfair team, team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/checkForChanges$$.log
#set -x

# Backup where we came from
callDir=`pwd`

# Go into the folder where the script is located and store the path.
# So all other scripts can be used directly
cd `dirname $0`
scriptDir=`pwd`
scriptName=`basename $0`

for currentFile in `ls ../` ; do
    # Skip files on repo root and skip folder _ADMIN
    if [ "${currentFile%%/*}" != "${currentFile}" -a "${currentFile%%/*}" != '_ADMIN' ] ; then
        echo ${currentFile%%/*} >> packages.txt
    fi
done
