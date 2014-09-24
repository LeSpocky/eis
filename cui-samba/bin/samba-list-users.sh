#!/bin/bash
#-----------------------------------------------------------------------------
# /var/install/bin/samba-list-users.sh - list samba users
#
# Creation:     2014-09-20 starwarsfan
#
# Copyright (c) 2014 the eisfair team <team@eisfair.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

pdbeditbin='/usr/bin/pdbedit'

# ----------------------------------------------------------------------------
# Control constants
# ----------------------------------------------------------------------------
IDC_LABEL__HEADLINE='10'
IDC_LISTBOX__USERS='11'
IDC_BUTOK='100'

getSambaUsers() {
    ${pdbeditbin} -Lw | grep -v "^.*$:" | sort -t: -k2n |
    (
        while read line ; do
            oldifs="$IFS"
            IFS=':'
            set -- ${line}
            user="$1"
            uid="$2"
            passwordHash="$4"
            flags="$5"
            IFS="$oldifs"

            # Account flags (see http://www.samba.org/samba/docs/man/manpages/smbpasswd.5.html)
            # U - This means this is a "User" account, i.e. an ordinary user.
            # N - This means the account has no password (the passwords in
            #     the fields LANMAN Password Hash and NT Password Hash are
            #     ignored). Note that this will only allow users to log on
            #     with no password if the null passwords parameter is set in
            #     the smb.conf(5) config file.
            # D - This means the account is disabled and no SMB/CIFS logins
            #     will be allowed for this user.
            # X - This means the password does not expire.
            # W - This means this account is a "Workstation Trust" account.
            #     This kind of account is used in the Samba PDC code stream
            #     to allow Windows NT Workstations and Servers to join a
            #     Domain hosted by a Samba PDC.

            if [ -n "$(echo "${flags}" | grep "N")" -o "$passwordHash" = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ] ; then
                pass='Not set'
            else
                pass='Set'
            fi

            if [ -n "$(echo "${flags}" | grep "D")" ] ; then
                active='No'
            else
                active='Yes'
            fi

            currentUser=$(printf "%-23s   %5s   %-7s   %3s\n" "${user}" "${uid}" "${pass}" "${active}")
            cui_listbox_add   "$ctrl" "${currentUser}"
        done
    )
}



# ----------------------------------------------------------------------------
#  ok_button_clicked
#         $p2 --> dialog window handle
#         $p3 --> control's window handle
# ----------------------------------------------------------------------------
ok_button_clicked() {
    local dlg="$p2"
    local ctrl="$p3"

    cui_window_close "$dlg" "$IDOK"
    cui_return 1
}



# ----------------------------------------------------------------------------
# dlg_setup_hook
#         $p2 --> dialog window handle
# ----------------------------------------------------------------------------
dlg_setup_hook() {
    local dlg="$p2"
    local ctrl

    if cui_label_new "$dlg" "Username"  2 1 8 1 ${IDC_LABEL__HEADLINE} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Uid"      29 1 3 1 ${IDC_LABEL__HEADLINE} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Password" 35 1 8 1 ${IDC_LABEL__HEADLINE} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_label_new "$dlg" "Active"   45 1 6 1 ${IDC_LABEL__HEADLINE} ${CWS_NONE} ${CWS_NONE} ; then
        cui_window_create     "$p2"
    fi

    if cui_listbox_new "$dlg" "" 1 3 55 5 ${IDC_LISTBOX__USERS} ${CWS_NONE} ${CWS_BORDER} ; then
        ctrl="$p2"
        cui_window_setcolors  "$ctrl" "MENU"
        cui_window_create     "$ctrl"
        getSambaUsers
    fi

    if cui_button_new "$dlg" "&OK" 24 9 10 1 ${IDC_BUTOK} ${CWS_DEFOK} ${CWS_NONE} ; then
        ctrl="$p2"
        cui_button_callback   "$ctrl" "$BUTTON_CLICKED" "$dlg" ok_button_clicked
        cui_window_create     "$ctrl"
    fi

    cui_return 1
}



# ----------------------------------------------------------------------------
# exec_dialog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
# ----------------------------------------------------------------------------
exec_dialog() {
    local win="$p2"
    local res="$IDCANCEL"

    if cui_window_new "$p2" 0 0 59 13 $[$CWS_POPUP + $CWS_CENTERED + $CWS_BORDER] ; then
        local dlgwin="$p2"
        cui_window_setcolors      "$dlgwin" "DIALOG"
        cui_window_settext        "$dlgwin" "Samba users"
        cui_window_sethook        "$dlgwin" "$HOOK_CREATE"  dlg_setup_hook
        cui_window_create         "$dlgwin"

        cui_window_modal          "$dlgwin"
        res="$p2"
        cui_window_destroy        "$dlgwin"
    fi

    cui_return "$res"
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
