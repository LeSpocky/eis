#!/bin/bash
# ---------------------------------------------------------------------------
# /var/install/dialog.d/PHPMYADMIN_DEFAULT_CHARSET_CUI.sh - script dialog for ece
#
# Creation:     2008-02-24 starwarsfan
# Last update:  $Id: PHPMYADMIN_DEFAULT_CHARSET_CUI.sh 21582 2009-10-17 09:17:35Z alex $
#
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ---------------------------------------------------------------------------

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

    sellist="big5,cp-866,euc-jp,euc-kr,gb2312,gbk,iso-8859-1,iso-8859-2,iso-8859-7"
    sellist="${sellist},iso-8859-8,iso-8859-8-i,iso-8859-9,iso-8859-13,iso-8859-15"
    sellist="${sellist},koi8-r,shift_jis,tis-620,utf-8,windows-1250,windows-1251"
    sellist="${sellist},windows-1252,windows-1256,windows-1257"

    ece_select_list_dlg "$win" "Default character set" "$sellist"
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
