#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/lprng-remove-onejob - remove job from one queue
#
# Copyright (c) 2002-2013 Thomas Bork, tom(at)eisfair(dot)net
#
# Creation   : 2008-02-10 tb

#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------
. /var/install/include/eislib

#exec 2>/tmp/lprng-trace$$.log
#set -x
#OLD_LC_COLLATE=`locale | grep '^LC_COLLATE=' | cut -d= -f2`

case $#
in
  0)
    interactive='true'
    ;;
  1)
    if [ "$1" = "noninteractive" ] ; then
        interactive='false'
    fi
    ;;
  *)
    echo "usage: /var/install/bin/`basename $0`" >&2
    echo "   or: /var/install/bin/`basename $0` noninteractive" >&2
    exit 1
    ;;
esac

if [ "$interactive" = "true" ] ; then
  clrhome
  mecho --info "Delete LPRng print jobs from queues"
  echo
  any_job_exists='no'
  TROW=0
  for queue in `grep "^.\+:$" /etc/printcap | cut -d: -f1`
  do
    let TROW+=1
    jobs_in_queue='-warn no'
    eval MYARRAY_${TROW}_1='$queue'
    export MYARRAY_${TROW}_1

    echo -n "checking queue	"
    mecho --info -n "$queue	"
    echo "for deletable jobs ..."
    if `lpq -P${queue} | grep -q 'Rank   Owner/ID               Pr/Class Job Files                 Size Time'`
    then
      jobs_in_queue='yes'
      any_job_exists='yes'
    fi

    eval MYARRAY_${TROW}_2='$jobs_in_queue'
    export MYARRAY_${TROW}_2
  done

  if [ "$any_job_exists" = "no" ] ; then
    clrhome
    mecho --info "Delete LPRng print jobs from queues"
    echo
    mecho --error "No deletable jobs in queues."
    echo
    exit 0
  fi

  MYARRAY_TITLE="Choose LPRng print queue to delete from"
  MYARRAY_SUBTITLE="From which print queue do you want to delete a job?"
  MYARRAY_CAPTION_1='-info "Print Queue" -info "Deletable jobs"'
  MYARRAY_QUESTION="Select"
  MYARRAY_COLS="20 20"
  MYARRAY_ROWS=`grep -c "^.\+:$" /etc/printcap`
  export MYARRAY_TITLE
  export MYARRAY_SUBTITLE
  export MYARRAY_CAPTION_1
  export MYARRAY_QUESTION
  export MYARRAY_COLS
  export MYARRAY_ROWS
  TROW=0

  choose_tmpfile=`/bin/mktemp -t choose.XXXXXXXXXX`
  if [ $? -ne 0 ] ; then
    choose_tmpfile="/tmp/choose.$$"
    >"$choose_tmpfile"
  fi
  /var/install/bin/choose MYARRAY >"$choose_tmpfile"
  rc=$?
  a=`cat "$choose_tmpfile"`
  rm -f "$choose_tmpfile"
  [ ${rc} = 255 ] && exit 255
  [ "$a" = "0" ] && exit 127
  [ "$a" = "" ] && exit 0

  eval printern='$MYARRAY_'${a}'_1'
  eval jobs_in_queue='$MYARRAY_'${a}'_2'
  export printern
  export jobs_in_queue

  if [ "$jobs_in_queue" = "yes" ] ; then
    lprng_remove_onejob_choose_tmpfile=`/bin/mktemp -t lprng_remove_onejob_choose.XXXXXXXXXX`
    if [ $? -ne 0 ] ; then
      lprng_remove_onejob_choose_tmpfile="/tmp/lprng_remove_onejob_choose.$$"
      >"$lprng_remove_onejob_choose_tmpfile"
    fi

    TROW=0
    MYARRAY_ROWS=0
    #LC_COLLATE="C"; export LC_COLLATE
    echo "checking job details in queue $printern ..."
    lpq -P"$printern" | LANG=C grep "^[0-9]\+.*\|^[a-z]\+.*" |
    # lpq -P"$printern" | grep "^[0-9]\+.*\|^[a-z]\+.*" |
    # Leider gehen alle Variablen beim 'while read' verloren, deshalb muss
    # mit einer tempor�ren Datei gearbeitet werden, in die Werte geschrieben und
    # danach exportiert werden m�ssen.
    while read rank owner class jobnr rest
    do
      let TROW+=1
      echo "TROW=\"$TROW\"" >> "$lprng_remove_onejob_choose_tmpfile"
      let MYARRAY_ROWS+=1
      echo "MYARRAY_ROWS=\"$MYARRAY_ROWS\"" >> "$lprng_remove_onejob_choose_tmpfile"
      echo "MYARRAY_${TROW}_1=\"$jobnr\"" >> "$lprng_remove_onejob_choose_tmpfile"
      echo "MYARRAY_${TROW}_2=\"$owner\"" >> "$lprng_remove_onejob_choose_tmpfile"
      premove=`echo "${rest}" | awk '{ print ( $(NF-1),$NF ) }'`
      pfile=`echo "${rest}" | sed "s#${premove}##"`
      echo "MYARRAY_${TROW}_3=\"'$pfile'\"" >> "$lprng_remove_onejob_choose_tmpfile"
      ptime=`echo "${rest}" | awk '{ print ( $NF ) }'`
      echo "MYARRAY_${TROW}_4=\"$ptime\"" >> "$lprng_remove_onejob_choose_tmpfile"
    done
    #LC_COLLATE="$OLD_LC_COLLATE"; export LC_COLLATE

    . "$lprng_remove_onejob_choose_tmpfile"
    #cat "$lprng_remove_onejob_choose_tmpfile"
    for var in `grep '^[A-Za-z].*=' "$lprng_remove_onejob_choose_tmpfile" | sed 's/=.*//g'`
    do
      export "$var"
    done
    rm -f "$lprng_remove_onejob_choose_tmpfile"

    if [ "$TROW" -eq 0 ] ; then
      clrhome
      mecho --info "Delete LPRng print jobs from queues"
      echo
      mecho --error "No more deletable jobs in queue $printern."
      echo
      exit 0
    fi

    MYARRAY_TITLE="Delete LPRng print jobs from queue $printern"
    MYARRAY_SUBTITLE="Which print job from queue $printern do you want to delete?"
    MYARRAY_CAPTION_1='-info "JobNr" -info "Owner" -info "File" -info "Time"'
    MYARRAY_QUESTION="Select"
    MYARRAY_COLS="9r 22 23 18"
    export MYARRAY_TITLE
    export MYARRAY_SUBTITLE
    export MYARRAY_CAPTION_1
    export MYARRAY_QUESTION
    export MYARRAY_COLS
    export MYARRAY_ROWS

    choose_tmpfile=`/bin/mktemp -t choose.XXXXXXXXXX`
    if [ $? -ne 0 ] ; then
      choose_tmpfile="/tmp/choose.$$"
      >"$choose_tmpfile"
    fi
    /var/install/bin/choose MYARRAY >"$choose_tmpfile"
    rc=$?
    a=`cat "$choose_tmpfile"`
    rm -f "$choose_tmpfile"
    [ ${rc} = 255 ] && exit 255
    [ "$a" = "0" ] && exit 127
    [ "$a" = "" ] && exit 0

    eval jobnr='$MYARRAY_'${a}'_1'
    eval owner='$MYARRAY_'${a}'_2'
    eval pfile='$MYARRAY_'${a}'_3'
    eval ptime='$MYARRAY_'${a}'_4'

    clrhome
    mecho --info "Delete LPRng print jobs from queue $printern"
    echo
    if /var/install/bin/ask "Do you really want to delete print job \"$owner $pfile $ptime\" from queue $printern" "y"
    then
      mecho --info "deleting print job \"$owner $pfile $ptime\" from queue $printern ..."
      echo
      lprm -P"$printern" jobid "$jobnr"
    fi
  else
    echo
    mecho --error "No deletable jobs in queue $printern."
  fi
fi

if [ "$interactive" = "true" ] ; then
  echo
  anykey
fi
