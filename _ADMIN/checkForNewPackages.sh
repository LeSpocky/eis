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



# -----------------------------
# check if settings file exists
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
# Get all folders on local working copy. In fact every folder represents a
# package (except folder _ADMIN).
#
# Returns the package names on global variable $packageFolders
getPackageFolders ()
{
    packageFolders=''
    for currentFolder in `ls -d */ | grep -v "_ADMIN"` ; do
        packageFolders="$packageFolders ${currentFolder%/*}"
    done
}



# ============================================================================
# Checks if the given job folder exists. If not found, create it. Afterwards
# call the next step to handle the main job config file.
#
# $1 .. Job name prefix as configured in settings.txt
# $2 .. Package name
# $3 .. Job name suffix as configured in settings.txt
#
# Set's the global variable $createdNewJob=true if a new job was created.
handleJobFolder ()
{
    local jobNamePrefix=$1
    local currentCheckedPackage=$2
    local jobNameSuffix=$3
    local givenJobFolder=${jobNamePrefix}${currentCheckedPackage}${jobNameSuffix}

    if [ -d $givenJobFolder ] ; then
        # Directory for job exists, check if there's a config file
        if [ ! -f $givenJobFolder/config.xml ] ; then
            # Config file not found, create it
            echo -n "Job folder for $givenJobFolder found, creating config file... "
            createJobConfig ${jobNamePrefix} ${currentCheckedPackage} ${jobNameSuffix}
            createdNewJob=true
            echo "Done"
        fi
    else
        # Job not configured, create folder and config file
        echo -n "Creating job folder and configuration for $givenJobFolder... "
        mkdir $givenJobFolder
        createJobConfig ${jobNamePrefix} ${currentCheckedPackage} ${jobNameSuffix}
        createdNewJob=true
        echo "Done"
    fi
}



# ============================================================================
# List all known packages out of folder list file by asking the user
# if he wants to see all packages or only packages of one section
checkJobFolders ()
{
    createdNewJob=false
    for currentCheckedPackage in $packageFolders
    do
        echo "Checking jenkins job for package '$currentCheckedPackage'"
        handleJobFolder $jobNamePrefix1 $currentCheckedPackage $jobNameSuffix1
        handleJobFolder $jobNamePrefix2 $currentCheckedPackage $jobNameSuffix2
    done

    if $createdNewJob ; then
        echo "Created at least one new job, initiating jenkins restart."
        restartJenkins
    else
        echo "Every package has it's build job, nothing to do."
    fi
}



# ============================================================================
# Create jenkins config file for package using new pkg build style
#
# $1 .. Job name prefix as configured in settings.txt
# $2 .. Package name
# $3 .. Job name suffix as configured in settings.txt
createJobConfig ()
{
    local jobNamePrefix=$1
    local currentCheckedPackage=$2
    local jobNameSuffix=$3
    local givenJobFolder=${jobNamePrefix}${currentCheckedPackage}${jobNameSuffix}
    if [ -f ${jobNamePrefix}TEMPLATE${jobNameSuffix}/config.xml ] ; then
        sed "s/TEMPLATE/${currentCheckedPackage}/g" ${jobNamePrefix}TEMPLATE${jobNameSuffix}/config.xml > ${jobNamePrefix}${currentCheckedPackage}${jobNameSuffix}/config.xml
    else
        echo "'${jobNamePrefix}TEMPLATE${jobNameSuffix}/config.xml' not found! Unable to create build job for package '$currentCheckedPackage'"
    fi
}



# ============================================================================
# Call api pages to restart jenkins
restartJenkins ()
{
    if [ ! -f "$jenkinsPasswordFile" ] ; then
        echo ""
        echo "File $jenkinsPasswordFile with the password for user $jenkinsUser does not exist!"
        echo ""
    elif [ ! -f "$jenkinsCliJar" ] ; then
        echo ""
        echo "File $jenkinsCliJar not found!"
        echo ""
    else
        java -jar $jenkinsCliJar -s $jenkinsUrl quiet-down   --username $jenkinsUser --password-file $jenkinsPasswordFile
        java -jar $jenkinsCliJar -s $jenkinsUrl safe-restart --username $jenkinsUser --password-file $jenkinsPasswordFile
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
            useRepo=true
            shift
            ;;
    esac
done

if [ ! -d $jobsFolder ] ; then
    echo "Jenkins job folder '$jobsFolder' not existing! Exiting."
    exit 1
fi



# Go into the repo root folder for the next steps
cd $scriptDir/..
pwd



getPackageFolders
cd $jobsFolder
checkJobFolders

# ============================================================================
# End
# ============================================================================
