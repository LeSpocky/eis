#!/bin/sh
#------------------------------------------------------------------------------
# /var/install/dialog.d/ROUNDCUBE_LANGUAGE.sh
#
# Copyright (c) 2012 - 2016 The eisfair team, team(at)eisfair(dot)org>
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

    sellist="ar,bg_BG,ca_ES,cs_CZ,cy_GB,da_DK,de_DE,el_GR,es_ES,et_EE,fi_FI"
    sellist="${sellist},fo_FO,fr_FR,he_IL,hr_HR,hu_HU,id_ID,is_IS,it_IT,ja_JP"
    sellist="${sellist},ko_KR,lt_LT,ms_MY,nl_NL,nn_NO,no_NO,pl_PL,pt_BR,pt_PT"
    sellist="${sellist},ro_RO,ru_RU,sk_SK,sl_SI,sr_YU,sv_SE,th_TH,tr_TR,uk_UA"
    sellist="${sellist},vi_VN,zh_CN,zh_TW"

    ece_select_list_dlg "${win}" "Default language" "${sellist}"
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
