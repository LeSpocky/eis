#!/bin/bash
#------------------------------------------------------------------------------
# /var/install/dialog.d/PHPMYADMIN_DEFAULT_LANGUAGE_CUI.sh - script dialog for ece
#
# Creation:     2008-02-24 starwarsfan
# Last update:  $Id: PHPMYADMIN_DEFAULT_LANGUAGE_CUI.sh 21582 2009-10-17 09:17:35Z alex $
#
# Copyright (c) 2001-2009 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
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

    sellist="af-iso-8859-1,af-utf-8,ar-win1256,ar-utf-8,az-iso-8859-9,az-utf-8"
    sellist="${sellist},becyr-win1251,becyr-utf-8,belat-utf-8,bg-win1251,bg-koi8-r"
    sellist="${sellist},bg-utf-8,bs-win1250,bs-utf-8,ca-iso-8859-1,ca-utf-8,cs-iso-8859-2"
    sellist="${sellist},cs-win1250,cs-utf-8,da-iso-8859-1,da-utf-8,de-iso-8859-1"
    sellist="${sellist},de-iso-8859-15,de-utf-8, el-iso-8859-7,el-utf-8,en-iso-8859-1"
    sellist="${sellist},en-iso-8859-15,en-utf-8,es-iso-8859-1,es-iso-8859-15,es-utf-8"
    sellist="${sellist},et-iso-8859-1,et-utf-8,eu-iso-8859-1,eu-utf-8,fa-win1256"
    sellist="${sellist},fa-utf-8,fi-iso-8859-1,fi-iso-8859-15,fi-utf-8,fr-iso-8859-1"
    sellist="${sellist},fr-iso-8859-15fr-utf-8,gl-iso-8859-1,gl-utf-8,he-iso-8859-8-i"
    sellist="${sellist},he-utf-8,hi-utf-8,hr-win1250,hr-iso-8859-2,hr-utf-8,hu-iso-8859-2"
    sellist="${sellist},hu-utf-8,id-iso-8859-1,id-utf-8,it-iso-8859-1,it-iso-8859-15"
    sellist="${sellist},it-utf-8,ja-euc,ja-sjis,ja-utf-8,ko-euc-kr,ko-utf-8,ka-utf-8"
    sellist="${sellist},lt-win1257,lt-utf-8,lv-win1257,lv-utf-8,mn-utf-8,ms-iso-8859-1"
    sellist="${sellist},ms-utf-8,nl-iso-8859-1,nl-iso-8859-15,nl-utf-8,no-iso-8859-1"
    sellist="${sellist},no-utf-8,pl-iso-8859-2,pl-win1250,pl-utf-8,ptbr-iso-8859-1"
    sellist="${sellist},ptbr-utf-8,pt-iso-8859-1,pt-iso-8859-15,pt-utf-8,ro-iso-8859-1"
    sellist="${sellist},ro-utf-8,ru-win1251, ru-cp-866,ru-koi8-r,ru-utf-8,sk-iso-8859-2"
    sellist="${sellist},sk-win1250,sk-utf-8,sl-iso-8859-2,sl-win1250,sl-utf-8,sq-iso-8859-1"
    sellist="${sellist},sq-utf-8,srlat-win1250,srlat-utf-8,srcyr-win1251,srcyr-utf-8"
    sellist="${sellist},sv-iso-8859-1,sv-utf-8,th-tis-620,th-utf-8,tr-iso-8859-9,tr-utf-8"
    sellist="${sellist},tt-iso-8859-9,tt-utf-8,uk-win1251,uk-utf-8,zhtw-big5,zhtw-utf-8"
    sellist="${sellist},zh-gb2312,zh-utf-8"

    ece_select_list_dlg "$win" "Default language" "$sellist"
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
