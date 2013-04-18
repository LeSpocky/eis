#!/bin/sh
# -------------------------------------------------------------------------
# Some compatibility stuff for Darwin (Mac OSX)              3.6.2
#
# Creation:       hh 2008-08-17
# Last Update:    $Id: compatibility.sh 17656 2009-10-18 18:39:00Z knibo $
# -------------------------------------------------------------------------

if uname | grep -q Darwin
then
    # avoid apple-specific files (forks) to be included
    export COPY_EXTENDED_ATTRIBUTES_DISABLE=true

    # don't use builtin echo, which lacks -n support
    echobin=`which echo`
    echo ()
    {
        $echobin $*
    }

fi

if [ "`seq 1 1 2>/dev/null`" != "1" ] && [ "`jot 1 1 1 2>/dev/null`" == "1" ]
then
    seq ()
    {
        jot $2 $1 $2
    }
fi

if [ -z "`which md5sum 2>/dev/null`" ] && [ -n "`which md5 2>/dev/null`" ]
then
    md5sum ()
    {
        # skip options
        while [ "$1" ]
        do
            case "$1" in
                -*) ;;
                *) retval=`md5 $1` ;;
            esac
            shift
        done
        set -- $retval
        echo $4
    }
fi
