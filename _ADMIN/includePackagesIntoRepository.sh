#! /bin/bash
# ----------------------------------------------------------------------------
# includePackagesIntoRepository.sh - Move manually uploaded apk's into the
#                                    corresponding repository folder and
#                                    update the repository index.
#
#
# Creation   :  2013-11-19  starwarsfan
#
# Copyright (c) 2013 the eisfair team, team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/createRepoIndex-trace$$.txt
#set -x

# Backup where we came from
callDir=`pwd`

# Go into the folder where the script is located and store the path.
# So all other scripts can be used directly
cd `dirname $0`
scriptDir=`pwd`
scriptName=`basename $0`
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
# Activate all uploaded packages for the given alpine version and architecture
# by moving them from the upload folder into the corresponding package
# repository folder.
activateUploadedPackages ()
{
    if [ -d "${sourcePath}" ] ; then
        # ToDo: Cleanup previous package versions

        mv -f ${sourcePath}/* ${repoPath}/
        rtc=$?
        if [ ${rtc} != 0 ] ; then
            echo "ERROR - Unable to move uploaded packages to repository folder!"
            exit ${rtc}
        fi

        ./createRepoIndex.sh -v ${alpineRelease} -b ${branch} -a ${alpineArch}
        rtc=$?
        if [ ${rtc} != 0 ] ; then
            echo "ERROR - Repository index could not be updated!"
            exit ${rtc}
        fi
    else
        echo "Package source folder not existing!"
        exit 1
    fi
}



usage ()
{
    cat <<EOF

  Usage:
  ${0} -v <version> -a <architecture> [-b <branch>]
        Move manually uploaded packages into the corresponding repository
        folder and update the repository index.

  Parameters:
  -v <version>
        .. The version of the system, for which all manually uploaded
           packages should be activated. Example: v2.7
  -a <architecture>
        .. The architecture of the system, for which all manually uploaded
           packages should be activated. Example: x86_64

  Optional parameters:
  -b <branch>
        .. The branch to be used on the repository. Default value: 'main'

EOF
}

alpineRelease=''
branch='main'
alpineArch=''

while [ $# -ne 0 ]
do
    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;

        -v)
            if [ $# -ge 2 ] ; then
                alpineRelease=$2
                shift
            fi
            ;;

        -b)
            if [ $# -ge 2 ] ; then
                branch=$2
                shift
            fi
            ;;

        -a)
            if [ $# -ge 2 ] ; then
                alpineArch=$2
                shift
            fi
            ;;

        * )
            ;;
    esac
    shift
done

if [ -z "$alpineRelease" -o -z "$alpineArch" ] ; then
    echo "Parameters -v and -a must be used!"
    exit 1
fi

sourcePath=${apkManualUploadSourceFolder}/${alpineRelease}/${branch}/${alpineArch}
repoPath=${apkRepositoryBaseFolder}/${alpineRelease}/${branch}/${alpineArch}

# Now do the job :-)
activateUploadedPackages

# ============================================================================
# End
# ============================================================================
