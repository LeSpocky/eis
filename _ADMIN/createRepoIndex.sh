#! /bin/bash
# ----------------------------------------------------------------------------
# createRepoIndex.sh - Create the index for the repository
#
#
# Creation   :  2013-05-05  starwarsfan
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
signingWorkDir=~/repoSigning

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
# Create the repository index based on all determined packages and store it
# on pkg repository folder
createRepoIndex ()
{
    echo 'Creating repository index'

    if [ -d ${signingWorkDir} ] ; then
        rm -rf ${signingWorkDir}
    fi
    mkdir ${signingWorkDir}
    cd ${signingWorkDir}

    # Setup version for the new index file
    CRTIMESTAMP=$(date +"%Y%m%d-%H%M%S")

    # See http://wiki.alpinelinux.org/wiki/Apkindex_format
    apk index -f -o APKINDEX.unsigned.tar.gz -d "v${CRTIMESTAMP}-$apkRepoQualifier" ${repoPath}/*.apk
    openssl dgst -sha1 -sign ~/.abuild/${signingPrivateKey} -out .SIGN.RSA.${signingPublicKey} APKINDEX.unsigned.tar.gz
    tar -c .SIGN.RSA.${signingPublicKey} | abuild-tar --cut | gzip -9 > signature.tar.gz
    cat signature.tar.gz APKINDEX.unsigned.tar.gz > ${repoPath}/APKINDEX.tar.gz

    # Cleanup
#    rm -f $signingWorkDir
}



# ============================================================================
# If the main repo was updated, create repo trigger files
createTriggerFiles ()
{
    if [ "$branch" = 'main' ] ; then
        echo "Creating trigger file"
        touch ${apkRepositoryBaseFolder}/syncTrigger/${version}__${alpineArch}
    else
        echo "Not on branch 'main', no pkg repo sync trigger files will be created"
    fi
}



# ============================================================================
# The main part of the menu script
# ============================================================================

usage ()
{
    cat <<EOF

  Usage:
  ${0} -v <version> -a <architecture> [-b <branch>]
        This script creates the repository index file using the configured
        keypair and stores it on the configured path.

  Parameters:
  -v <version>
        .. The version of the system, for which the repository index should
           be created. Example: v2.4
  -a <architecture>
        .. The architecture of the system, for which the repository index
           should be created. Example: x86_64

  Optional parameters:
  -b <branch>
        .. The branch to be used on the repository. Default value: 'testing'

EOF
}

version=''
branch='testing'
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
                version=$2
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

if [ -z "$version" -o -z "$alpineArch" ] ; then
    echo "Parameters -v and -a must be used!"
    exit 1
fi

repoPath=${apkRepositoryBaseFolder}/${version}/${branch}/${alpineArch}

# Now do the job :-)
createRepoIndex
createTriggerFiles

exit $rtc

# ============================================================================
# End
# ============================================================================
