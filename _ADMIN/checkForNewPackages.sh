#! /bin/bash
# ----------------------------------------------------------------------------
# checkForNewPackages.sh - Check if every package on the repository has a
#                          jenkins job and if not, create one.
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

#exec 2> /tmp/checkForNewPackages$$.log
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



# ============================================================================
# Iterate over all folders on local working copy. In fact every folder
# represents a package (except folder _ADMIN), so for every folder the
# corresponding build jobs must exist or will be created.
iteratePackageFolders ()
{
    cd $jobsFolder
	echo "=============================================================================="
    for currentFolder in `ls -d $workspaceFolder/*/ | grep -v "_ADMIN"` ; do
        # Cut last '/' and everything beyond
        currentCheckedPackage="${currentFolder%/*}"
        # Cut everything before last '/' including the '/' itself
        currentCheckedPackage=${currentCheckedPackage##*/}

        echo "Checking jenkins jobs for package '$currentCheckedPackage'"
        createJob "$jobNamePrefix1" "$currentCheckedPackage" "$jobNameSuffix1" "$templateJobName1"
        createJob "$jobNamePrefix2" "$currentCheckedPackage" "$jobNameSuffix2" "$templateJobName2"
    done
	echo "=============================================================================="
}



# ============================================================================
# Create new jenkins job using the jenkins-cli
#
# $1 .. Job name prefix as configured in settings.txt
# $2 .. Package name
# $3 .. Job name suffix as configured in settings.txt
# $4 .. Name of the template-job which should be used
#       as the base for the new job
createJob ()
{
    local jobNamePrefix=$1
    local currentPackage=$2
    local jobNameSuffix=$3
    local templateJobName=$4
    local currentRtc=0
    local jobName=${jobNamePrefix}${currentPackage}${jobNameSuffix}
    if [ ! -d $jobName -o ! -f $jobName/config.xml ] ; then
        # Config file not found, create it
        echo "Calling jenkins api to create job '$jobName'"
        java -Xms$javaMinHeap -Xmx$javaMaxHeap -jar $jenkinsCliJar -s $jenkinsUrl get-job $templateJobName --username $jenkinsUser --password-file $jenkinsPasswordFile | \
            sed "s/TEMPLATE/$currentPackage/g" | \
            java -Xms$javaMinHeap -Xmx$javaMaxHeap -jar $jenkinsCliJar -s $jenkinsUrl create-job $jobName --username $jenkinsUser --password-file $jenkinsPasswordFile
        currentRtc=$?
        if [ $currentRtc != 0 ] ; then
            echo "ERROR: Something went wrong during creation of build-job '$jobName'"
            rtc=$currentRtc
        fi
    fi
}



# ============================================================================
# The main part of the menu script
# ============================================================================

usage ()
{
    cat <<EOF

  Usage:
  ${0}
        This script checks if a jenkins job for every package on this
        repository is existing. If not, jobs based on the templates will
        be created.

EOF
}


while [ $# -ne 0 ]
do

    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;
        * )
            shift
            ;;
    esac
done

if [ ! -d $jobsFolder ] ; then
    echo "Jenkins job folder '$jobsFolder' not existing! Exiting."
    exit 1
fi



# Go into the repo root folder for the next steps and store it's full path
cd $scriptDir/..
workspaceFolder=`pwd`

# Now do the job :-)
iteratePackageFolders

exit $rtc

# ============================================================================
# End
# ============================================================================
