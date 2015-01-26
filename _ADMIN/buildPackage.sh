#! /bin/bash
# ----------------------------------------------------------------------------
# buildPackage.sh - Build the package on the current folder
#
# Jenkins environment variables must be set for proper functionality!
# Build job name must follow the form:
# <something>__<package-name>__<alpine-release>_<arch>
#
# Creation   :  2013-11-09  starwarsfan
#
# Copyright (c) 2013 the eisfair team, team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> /tmp/buildPackage-trace$$.txt
#set -x

branch='main'
rtc=0



usage ()
{
    cat <<EOF

  Usage:
  ${0} [options]
        This script builds the package which is determined out of environment
        variable JOB_NAME and stores the result on the appropriate folder
        given by env var CI_RESULTFOLDER_EISFAIR_NG. These nvironment
        variables might be set using options described below. Otherwise the
        script will fail.
        Script should be executed out of repository root.

  Optional parameters:
    -j|--job-name <job-name>
        Set variable JOB_NAME.

    -r|--result-folder <result-folder>
        Set variable CI_RESULTFOLDER_EISFAIR_NG.

EOF
}



checkEnvironment ()
{
    echo "Checking environment:"
    if [ -z "${JOB_NAME}" ] ; then
        echo "ERROR: Env var 'JOB_NAME' must be set!"
        exit 1
    fi
    if [ -z "${CI_RESULTFOLDER_EISFAIR_NG}" ] ; then
        echo "ERROR: Env var 'CI_RESULTFOLDER_EISFAIR_NG' must be set!"
        exit 1
    fi
    echo "Done"
}



extractVariables ()
{
    # Extract package name from eisfair-ng/<alpine-release>/<stage>/<architecture>/<package>
    # Example:
    # JOB_NAME='eisfair-ng/v3.1/testing/x86_64/bonnie'
    packageName=${JOB_NAME##*\/}
    packageArch=${JOB_NAME%\/*}
    packageArch=${packageArch#*\/}
    stage=${packageArch%\/*}
    alpineRelease=${stage%\/*}
    stage=${stage#*\/}
    packageArch=${packageArch##*\/}
}



buildPackage ()
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
        checkDeploymentDestination
        if ls *.apk >/dev/null 2>&1 ; then
            cp -f *.apk ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/testing/${packageArch}
            rtc=$?
        else
            cp -f ~/packages/${JOB_NAME}/${packageArch}/*.apk ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/testing/${packageArch}
            rtc=$?
        fi
    else
        exit ${rtc}
    fi
}



checkDeploymentDestination ()
{
    if [ ! -d ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/${branch}/${packageArch} ] ; then
        echo "Repository directory not existing, creating it"
        mkdir -p ${CI_RESULTFOLDER_EISFAIR_NG}/${alpineRelease}/${branch}/${packageArch}
    fi
}



while [ $# -ne 0 ] ; do
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

        -r|--result-folder)
            if [ $# -ge 2 ] ; then
                CI_RESULTFOLDER_EISFAIR_NG=$2
                shift
            fi
            ;;

        * )
            ;;
    esac
    shift
done

checkEnvironment
extractVariables
buildPackage

exit ${rtc}

# ============================================================================
# End
# ============================================================================
