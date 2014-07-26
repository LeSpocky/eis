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

packageListTmp=packages.tmp.txt
packageList=packages.txt

delimiter=''
echo -n "packages=" > ${packageListTmp}
for currentFile in `ls -d ../*/` ; do
    # Skip _ADMIN folder
    if [ "${currentFile}" != '../_ADMIN/' ] ; then
        packageName=${currentFile#*/}
        packageName=${packageName%/*}
#        echo -n "${delimiter}${packageName}"
        echo -n "${delimiter}${packageName}" >> ${packageListTmp}
        delimiter=','
    fi
done

cat ${packageListTmp}
echo ''

if diff ${packageListTmp} ${packageList} >/dev/null 2>&1 ; then
    echo 'No changes on package list'
else
    echo 'Package list changed, activating new list'
    mv ${packageListTmp} ${packageList}
fi
