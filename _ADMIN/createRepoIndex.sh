#! /bin/bash
# ----------------------------------------------------------------------------
# createRepoIndex.sh - Create the index for the repository
#
#
# Creation   :  2013-05-05  starwarsfan
#
# Copyright (c) 2013 the alpeis team, team(at)eisfair(dot)org>
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
#
createRepoIndex ()
{
    echo 'Creating repository index'
}



# ============================================================================
# The main part of the menu script
# ============================================================================

usage ()
{
    cat <<EOF

  Usage:
  ${0}
        This script creates the repository index file using the configured
        keypair and stores it on the configured path.

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

# Now do the job :-)
createRepoIndex

exit $rtc

# ============================================================================
# End
# ============================================================================