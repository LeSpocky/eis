#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/ROUNDCUBE_PLUGIN.sh
#
# Copyright (c) 2012 - 2016 the eisfair team, team(at)eisfair(dot)org>
# Creation:     2012-12-20  jed
#----------------------------------------------------------------------------

. /var/install/include/cuilib
. /var/install/include/ecelib

#----------------------------------------------------------------------------
# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
#----------------------------------------------------------------------------
exec_dialog()
{
    win_handle="$p2"
    var_name="$p3"
    local rc_docroot=''
    local sellist=''

    # get current parameter set
    idx=$(echo "${var_name}" | sed -e 's/^ROUNDCUBE_//' -e 's/_PLUGINS_.*$//')

    rc_docroot_str="ROUNDCUBE_${idx}_DOCUMENT_ROOT"
    ece_get_value ${win_handle} ${rc_docroot_str} && rc_docroot=${p2}

    # get list of directories
    if [ "${rc_docroot}" != "" ] ; then
        sellist="$(find ${rc_docroot}/plugins/ -maxdepth 1 -type d | sort | \
            sed -e "s#${rc_docroot}/plugins/##g" -e '/^$/d' | tr '\n' ',' | \
            sed 's/,$//')"
    fi

    ece_select_list_dlg "${win_handle}" "Select plugin" "${sellist}"
}

#----------------------------------------------------------------------------
# main routine
#----------------------------------------------------------------------------

cui_init
cui_run

#----------------------------------------------------------------------------
# end
#----------------------------------------------------------------------------

exit 0
