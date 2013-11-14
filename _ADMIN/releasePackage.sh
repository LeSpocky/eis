#! /bin/bash
# ----------------------------------------------------------------------------
# releasePackage.sh - Release the package on the current folder
#
# Environment variables must be set for proper functionality!
#
# Creation   :  2013-11-13  starwarsfan
#
# Copyright (c) 2013 the eisfair team, team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/releasePackage-trace$$.txt
#set -x

branch='main'
rtc=0



usage ()
{
    cat <<EOF

  Usage:
  ${0} [options]
        This script releases the package which is given by the environment
        variable PACKAGE_TO_RELEASE. The package could be set using options
        described below. Otherwise the script will fail.
        Script should be executed out of repository root.

  Optional parameters:
    -p|--package-name <package-name>
        The package which should be released.
    -j|--job-name <job-name>
        Set variable JOB_NAME.

EOF
}



checkEnvironment ()
{
    echo "Checking environment:"
    if [ -z "${JOB_NAME}" ] ; then
        echo "ERROR: Env var 'JOB_NAME' must be set!"
        usage
        exit 1
    fi
    if [ -z "${PACKAGE_TO_RELEASE}" ] ; then
        echo "ERROR: Env var 'JOB_NAME' must be set!"
        usage
        exit 1
    fi
    echo "Done"
}



extractVariables ()
{
    # Extract package name from <some-text>__<package-name>__<release>_<arch>
    # Example:
    # eisfair-ng__releasePackage__edge_x86
    # eisfair-ng__releasePackage__edge_x86_64
    # eisfair-ng__releasePackage__v2.7_x86
    # eisfair-ng__releasePackage__v2.7_x86_64
    releaseArch=`echo ${JOB_NAME} | sed "s/\(.*__.*__\)\(.*\)/\2/g"`
    alpineRelease=`echo ${releaseArch%%_*}`
    packageArch=`echo ${releaseArch#*_}`
}



releasePackage ()
{
    echo "Updating pkg repository"
    sudo apk update

    echo "Cd to ${packageName}"
    cd ${packageName}

    echo "Removing previously build apk files"
    rm -f *.apk

#    echo "Updating checksums"
#    abuild checksum

    echo "Building package"
    abuild -r
    rtc=$?
    if [ "${rtc}" = 0 ] ; then
        echo "Copying apk file(s) to repository folder"
        if ls *.apk >/dev/null 2>&1 ; then
            cp -f *.apk ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/main/${packageArch}
            rtc=$?
        else
            cp -f ~/packages/${JOB_NAME}/${packageArch}/*.apk ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/main/${packageArch}
            rtc=$?
        fi
    else
        exit ${rtc}
    fi
}



syncMirror ()
{
    echo "ToDo: Sync with repo mirror"
    # rsync ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/main/ <mirror-location>
}



while [ $# -ne 0 ]
do
    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;

        -j|--job-name)
            if [ $# -ge 2 ] ; then
                JOB_NAME=$2
                shift
            fi
            ;;

        -p|--package-name)
            if [ $# -ge 2 ] ; then
                PACKAGE_TO_RELEASE=$2
                shift
            fi
            ;;

        * )
            ;;
    esac
    shift
done

checkEnvironment
releasePackage
syncMirror

exit ${rtc}

# ============================================================================
# End
# ============================================================================
