#! /bin/bash
# ----------------------------------------------------------------------------
# checkForChanges.sh - Check which package should be build and trigger
#                      the corresponding build job
#
# Creation   :  2013-04-19  starwarsfan
# Last Update:
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



# -----------------------------
# Check if settings file exists
if [ -f "settings.txt" ] ; then
    # ----------------------------------------------------------------
    # This should be the normal case: settings.txt exists, so load it.
    . settings.txt
    echo "Settings loaded."
elif [ -f "settings.default.txt" ] ; then
    echo ""
    echo "Settings file not existing, creating new one out of default file."
    echo "The new one is on .gitignore, so it is secured that personal settings"
    echo "are not commited to the repository."
    cp settings.default.txt settings.txt
    echo "The script will be aborted here, please modify"
    echo "    ${scriptDir}/settings.txt"
    echo "to fit your needs. If the settings are OK, restart the script."
    echo ""
    exit 2
else
    # ---------------------------------------------------------------------
    # Thats odd: Not even 'settings.txt' nor 'settings.default.txt' exists!
    echo ""
    echo "ERROR: No settings file existing!"
    echo "The default file 'settings.default.txt' must exist on the folder"
    echo "'_ADMIN/'. This file is used to create"
    echo "a personal settings file, which you can setup to your needs."
    echo "Please check for that and restart the script again."
    echo ""
    exit 1
fi



# ============================================================================
# Call api pages to trigger given build job
# $1 .. Build job to trigger
triggerBuildJob ()
{
    local buildJobToTrigger=$1
    if [ ! -f "$jenkinsPasswordFile" ] ; then
        echo ""
        echo "File $jenkinsPasswordFile with the password for user $jenkinsUser does not exist!"
        echo ""
    elif [ ! -f "$jenkinsCliJar" ] ; then
        echo ""
        echo "File $jenkinsCliJar not found!"
        echo ""
    else
        java -jar $jenkinsCliJar -s $jenkinsUrl build $buildJobToTrigger --username $jenkinsUser --password-file $jenkinsPasswordFile
    fi
}



for currentFile in `git diff --name-only @{1}..` ; do
    # Check for changes but skip files on repo root and skip folder _ADMIN
    if [ "${currentFile%%/*}" != "${currentFile}" -a "${currentFile%/*}" != '_ADMIN' ] ; then
        echo ${currentFile%/*} >> /tmp/determinedFolders-$$.txt
    fi
done

if [ -e /tmp/determinedFolders-$$.txt ] ; then
    # Wipe out duplicate folder entries
    sort -u /tmp/determinedFolders-$$.txt > /tmp/determinedFoldersUnique-$$.txt

    while read packageToTrigger ; do
        echo -n "Triggering build of package '$packageToTrigger'... "
        triggerBuildJob ${jobNamePrefix1}${packageToTrigger}${jobNameSuffix1}
        triggerBuildJob ${jobNamePrefix2}${packageToTrigger}${jobNameSuffix2}
        echo "Done"
    done < /tmp/determinedFoldersUnique-$$.txt

    rm -f /tmp/determinedFoldersUnique-$$.txt /tmp/determinedFolders-$$.txt
else
    echo "No changes on at least one of the package directories"
fi
