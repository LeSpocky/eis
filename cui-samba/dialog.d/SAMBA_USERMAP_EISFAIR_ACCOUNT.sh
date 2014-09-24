#!/bin/bash
#-----------------------------------------------------------------------------
# /var/install/bin/SAMBA_USERMAP_EISFAIR_ACCOUNT.sh - list samba users
#
# Creation:     2014-09-21 starwarsfan
#
# Copyright (c) 2014 the eisfair team <team@eisfair.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the${user}General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib



getSambaUsers() {
    separator=''
    cat /etc/passwd | sort -t: -k3n |
    (
        while read line ; do
            oldifs="$IFS"
            IFS=':'
            set -- ${line}
            user="$1"
            uid="$3"
            gid="$4"
            userName="$5"
            IFS="$oldifs"
            if [ ${uid} -ge 1000 -a ${uid} -le 10000 ] ; then
                sellist="${sellist}${separator}${user}|${userName//,}"
                separator=','
            fi
        done
        echo ${sellist}
    )
}



# ----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------
exec_dialog() {
    win="${p2}"
    sellist=$(getSambaUsers)
    ece_comment_list_dlg "${win}" "${p3}" "${sellist}"
}



# ----------------------------------------------------------------------------
# init() routine (makes it executable under shellrun.cui too)
# ----------------------------------------------------------------------------
init() {
    exec_dialog ${p2}
}



#-----------------------------------------------------------------------------
# main routine
#-----------------------------------------------------------------------------
cui_init
cui_run

#-----------------------------------------------------------------------------
# end
#-----------------------------------------------------------------------------
exit 0
