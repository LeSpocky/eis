#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/ROUNDCUBE_DB_TYPE.sh
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
    win="$p2"

    if [ -z "${value}" ] ; then
        # set default value
        value='sqlite'
    fi

    # sellist="sqlite,mssql,mysql,mysqli,pgsql,sqlsrv"
    sellist="sqlite"
    if [ -f /var/install/packages/mysql -o /var/install/packages/mariadb ] ; then
        sellist="${sellist},mysql"
    fi

    if [ -f /var/install/packages/postgresql ] ; then
        sellist="${sellist},pgsql"
    fi

    ece_select_list_dlg "${win}" "Database type" "${sellist}"
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
