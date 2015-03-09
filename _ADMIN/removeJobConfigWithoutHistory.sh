#! /bin/bash
# ----------------------------------------------------------------------------
# removeJobConfigWithoutHistory.sh - Remove Jenkins job configuration without
#                                    job history. In fact, only config.xml is
#                                    removed and can be created later on again
#
# Creation   :  2015-01-26  starwarsfan
#
# Copyright (c) 2013-2015 the eisfair team, team(at)eisfair(dot)org>
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

javaMinHeap='256M'
javaMaxHeap='512M'
rtc=0

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



usage ()
{
    cat <<EOF

  Usage:
  ${0} [options] [<package> ]*
        This script removes the Jenkins configuration of a build job without
        its history. In fact only config.xml will be removed. If it is
        recreated afterwards, Jenkins will find the already existing job
        history.

  Options:
  -a|--remove-all
        .. Remove all configurations. If this parameter is used, the list of
           given packages will be ignored.
  --alpine-release
        .. Alpine release for which configurations should be removed. If not given
           cleanup will be done for all releases. Example: 'v2.7'
  --architecture
        .. Architecture for which configurations should be removed. If not given
           cleanup will be done for all architectures. Example: 'x86'

EOF
}



# ============================================================================
# Iterate over all folders on local working copy. In fact every folder
# represents a package (except folder _ADMIN), so for every folder the
# corresponding build jobs must exist or will be created.
iteratePackageFolders ()
{
    cd ${jobsFolder}

	echo "=============================================================================="
	echo "Implement me!"
	echo "=============================================================================="
}



# Set some defaults
removeAll=false
jobFolderList='eisfair-ng/v3.1/testing/x86 eisfair-ng/v3.1/testing/x86_64'
jobTemplateName=_TEMPLATE

while [ $# -ne 0 ] ; do
    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;
        --alpine-release)
            removeAll=true
            ;;
        --alpine-release)
            if [ $# -ge 2 ] ; then
                alpineRelease=$2
                shift
            fi
            ;;
        --architecture)
            if [ $# -ge 2 ] ; then
                architecture=$2
                shift
            fi
            ;;
        * )
            packageList="${packageList} $1"
            ;;
    esac
    shift
done

if [ ! -d ${jobsFolder} ] ; then
    echo "Jenkins job folder '$jobsFolder' not existing! Exiting."
    exit 1
fi



# Go into the repo root folder for the next steps and store it's full path
cd ${scriptDir}/..
workspaceFolder=`pwd`

# Now do the job :-)
iteratePackageFolders

exit ${rtc}

# ============================================================================
# End
# ============================================================================
