#! /bin/bash
# ----------------------------------------------------------------------------
# checkForNewPackages.sh - Check if every package on the repo${${jenkinsCliJar}
# jenkins job and if not, create one.
#
# Creation   :  2013-04-19  starwarsfan
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
# Extract the list of template jobs out of the list of all build jobs
getTemplateJobs ()
{
    local jobsToFind=${templateJobPrefix}${jobNamePrefix}__${templateJobPlaceholder}__
    jobTemplates=$(java -Xms${javaMinHeap} \
                        -Xmx${javaMaxHeap} \
                        -jar ${jenkinsCliJar} \
                        -s ${jenkinsUrl} \
                        list-jobs \
                        --username ${jenkinsUser} \
                        --password-file ${jenkinsPasswordFile} | grep ${jobsToFind} | tr '\n' ' ')
}



# ============================================================================
# Iterate over all folders on local working copy. In fact every folder
# represents a package (except folder _ADMIN), so for every folder the
# corresponding build jobs must exist or will be created.
iteratePackageFolders ()
{
    cd ${jobsFolder}
	echo "=============================================================================="
    for currentFolder in $(ls -d ${workspaceFolder}/*/ | grep -v "_ADMIN") ; do
        # Cut last '/' and everything beyond
        currentCheckedPackage="${currentFolder%/*}"
        # Cut everything before last '/' including the '/' itself
        currentCheckedPackage=${currentCheckedPackage##*/}

        echo "Checking jenkins jobs for package '$currentCheckedPackage'"
        for currentJobTemplate in ${jobTemplateList} ; do
            # $currentJobTemplate is something like 'eisfair-ng/v3.1/testing/x86_64'
            createJob "$currentCheckedPackage" "$currentJobTemplate"
        done
    done
	echo "=============================================================================="
}



# ============================================================================
# Create new jenkins job using the jenkins-cli
#
# $1 .. Package name
# $3 .. Name of the template-job which should be used
#       as the base for the new job
createJob ()
{
    local currentPackage=$1
    local templateJobName=$2
    local currentRtc=0
    local jobName=${currentPackage}
    if [ ! -d ${jobName} -o ! -f ${jobName}/config.xml ] ; then
        # Config file not found, create it
        echo "Calling jenkins api to create job '$jobName'"
        java -Xms${javaMinHeap} \
             -Xmx${javaMaxHeap} \
             -jar ${jenkinsCliJar} \
             -s ${jenkinsUrl} \
             get-job ${templateJobName} \
             --username ${jenkinsUser} \
             --password-file ${jenkinsPasswordFile} | \
            sed "s/TEMPLATE/$currentPackage/g" | \
            java -Xms${javaMinHeap} \
                 -Xmx${javaMaxHeap} \
                 -jar ${jenkinsCliJar} \
                 -s ${jenkinsUrl} \
                 create-job ${jobName} \
                 --username ${jenkinsUser} \
                 --password-file ${jenkinsPasswordFile}
        currentRtc=$?
        if [ ${currentRtc} != 0 ] ; then
            echo "ERROR: Something went wrong during creation of build-job '$jobName'"
            rtc=${currentRtc}
        elif ${buildNewJobs} ; then
            triggerBuild ${jobName}
        fi
    fi
}



# ============================================================================
# Create new jenkins job using the jenkins-cli
#
# $1 .. Package name
# $3 .. Name of the template-job which should be used
#       as the base for the new job
triggerBuild ()
{
    local jobName=$1
    if [ -d ${jobName} -a -f ${jobName}/config.xml ] ; then
        echo "Calling jenkins api to build job '$jobName'"
        java -Xms${javaMinHeap} \
             -Xmx${javaMaxHeap} \
             -jar ${jenkinsCliJar} \
             -s ${jenkinsUrl} \
             build ${jobName} \
             --username ${jenkinsUser} \
             --password-file ${jenkinsPasswordFile}
        currentRtc=$?
        if [ ${currentRtc} != 0 ] ; then
            echo "ERROR: Something went wrong during trigger of build-job '$jobName'"
            rtc=${currentRtc}
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
  ${0} [options]
        This script checks if a jenkins job for every package on this
        repository is existing. If not, jobs based on the templates will
        be created.

  Options:
  -n|--no-build .. Do not build new jobs immediately after their creation.

EOF
}

# Set some defaults
buildNewJobs=true

while [ $# -ne 0 ]
do

    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;
        -n|--no-build)
            # Do not directly build new jobs
            buildNewJobs=false
            ;;
        --jtl|--job-template-list)
            if [ $# -ge 2 ] ; then
                jobTemplateList=$(echo "$2" | sed "s/,/ /g")
                shift
            fi
            ;;
        * )
            shift
            ;;
    esac
done

if [ ! -d ${jobsFolder} ] ; then
    echo "Jenkins job folder '$jobsFolder' not existing! Exiting."
    exit 1
fi



# Go into the repo root folder for the next steps and store it's full path
cd ${scriptDir}/..
workspaceFolder=`pwd`

# Now do the job :-)
#getTemplateJobs
iteratePackageFolders

exit ${rtc}

# ============================================================================
# End
# ============================================================================
