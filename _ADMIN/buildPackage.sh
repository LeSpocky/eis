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

rtc=0



usage ()
{
    cat <<EOF

  Usage:
  ${0} -v <version> -a <architecture> [-b <branch>]
        This script creates the repository index file using the configured
        keypair and stores it on the configured path.

  Parameters:

  Optional parameters:

EOF
}



checkEnvironment ()
{
    if [ -z "$JOB_NAME" ] ; then
        echo "Jenkins env var 'JOB_NAME' must be set to determine resulting package directory!"
        exit 1
    fi
}



extractVariables ()
{
    # Extract package name from <some-text>__<package-name>__<release>_<arch>
    packageName=`echo $JOB_NAME | sed "s/\(.*__\)\(.*\)\(__\)\(.*\)\(_\)\(.*\)/\2/g"`
    alpineRelease=`echo $JOB_NAME | sed "s/\(.*__\)\(.*\)\(__\)\(.*\)\(_\)\(.*\)/\4/g"`
    packageArch=`echo $JOB_NAME | sed "s/\(.*__\)\(.*\)\(__\)\(.*\)\(_\)\(.*\)/\6/g"`
}



buildPackage ()
{
    sudo apk update

    package='eis-install'

    cd $package

    abuild checksum
    abuild -r
    rtc=$?
    if [ "$rtc" = 0 ] ; then
        cp -f ~/packages/$JOB_NAME/x86/*.apk ${CI_RESULTFOLDER_EISFAIR_NG}/v2.7/main/x86
    else
        exit $rtc
    fi
}
version=''
branch='main'
arch=''

while [ $# -ne 0 ]
do
    case $1 in
        -help|--help)
            # print usage
            usage
            exit 1
            ;;

        -v)
            if [ $# -ge 2 ]
            then
                version=$2
                shift
            fi
            ;;

        -b)
            if [ $# -ge 2 ]
            then
                branch=$2
                shift
            fi
            ;;

        -a)
            if [ $# -ge 2 ]
            then
                arch=$2
                shift
            fi
            ;;

        * )
            ;;
    esac
    shift
done

checkEnvironment


repoPath=${apkRepositoryBaseFolder}/${version}/${branch}/${arch}

# Now do the job :-)
createRepoIndex

exit $rtc

# ============================================================================
# End
# ============================================================================
