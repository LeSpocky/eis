#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/dialog.d/PHP_DATE_TIMEZONE.sh
# Creation:    2010-08-05 the eisfair team, team(at)eisfair(dot)org
# ----------------------------------------------------------------------------
. /var/install/include/cuilib
. /var/install/include/ecelib

# exec_dailog
# ece --> request to create and execute dialog
#         $p2 --> main window handle
#         $p3 --> name of config variable
exec_dialog()
{
    win="$p2"
    sellist="Europe/Amsterdam,Europe/Andorra,"
    sellist="${sellist}Europe/Athens,Europe/Belfast,Europe/Belgrade,Europe/Berlin,Europe/Bratislava,Europe/Brussels,Europe/Bucharest,Europe/Budapest,"
    sellist="${sellist}Europe/Chisinau,Europe/Copenhagen,Europe/Dublin,Europe/Gibraltar,Europe/Guernsey,Europe/Helsinki,Europe/Isle_of_Man,Europe/Istanbul,"
    sellist="${sellist}Europe/Jersey,Europe/Kaliningrad,Europe/Kiev,Europe/Lisbon,Europe/Ljubljana,Europe/London,Europe/Luxembourg,Europe/Madrid,"
    sellist="${sellist}Europe/Malta,Europe/Mariehamn,Europe/Minsk,Europe/Monaco,Europe/Moscow,Europe/Nicosia,Europe/Oslo,Europe/Paris,Europe/Podgorica,"
    sellist="${sellist}Europe/Prague,Europe/Riga,Europe/Rome,Europe/Samara,Europe/San_Marino,Europe/Sarajevo,Europe/Simferopol,Europe/Skopje,Europe/Sofia,"
    sellist="${sellist}Europe/Stockholm,Europe/Tallinn,Europe/Tirane,Europe/Tiraspol,Europe/Uzhgorod,Europe/Vaduz,Europe/Vatican,Europe/Vienna,Europe/Vilnius,"
    sellist="${sellist}Europe/Volgograd,Europe/Warsaw,Europe/Zagreb,Europe/Zaporozhye,Europe/Zurich,Etc/GMT,Etc/GMT+0,Etc/GMT+1,Etc/GMT+10,Etc/GMT+11,"
    sellist="${sellist}Etc/GMT+12,Etc/GMT+2,Etc/GMT+3,Etc/GMT+4,Etc/GMT+5,"
    sellist="${sellist}Etc/GMT+6,Etc/GMT+7,Etc/GMT+8,Etc/GMT+9,Etc/GMT-0,Etc/GMT-1,Etc/GMT-10,Etc/GMT-11,Etc/GMT-12,Etc/GMT-13,Etc/GMT-14,Etc/GMT-2,"
    sellist="${sellist}Etc/GMT-3,Etc/GMT-4,Etc/GMT-5,Etc/GMT-6,Etc/GMT-7,Etc/GMT-8,Etc/GMT-9,Etc/GMT0,Etc/Greenwich,Etc/UCT,Etc/Universal,Etc/UTC,"
    sellist="${sellist}Etc/Zulu"
    ece_select_list_dlg "$win" "PHP DATE/TIMEZONE" "$sellist"
}

# main routine
cui_init
cui_run

# end
exit 0
