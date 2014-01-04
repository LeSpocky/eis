#! /bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-lcd4linux-update.sh - paramater update script
#
# Creation   : 2010-08-18 Y. Schumann
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> `pwd`/cui-lcd4linux-update-trace$$.log
#set -x

# Include libs, helpers a.s.o.
. /var/install/include/eislib
. /var/install/include/configlib

# set packages name
packageName=cui-lcd4linux
modifiedSomething=false



# ----------------------------------------------------------------------------
# Set the default values for configuration
# ----------------------------------------------------------------------------
START_LCD='no'

LCD_TYPE='LCD2USB'

LCD_PORT='/dev/parport0'
LCD_SPEED='---'
LCD_CONTRAST=230
LCD_BACKLIGHT=80
LCD_COLS=20
LCD_ROWS=4
LCD_WIRING='fli4l'

LCD_LAYOUT_N=1
LCD_LAYOUT_1_NAME=''
LCD_LAYOUT_1_ACTIVE='no'
LCD_LAYOUT_1_ELEMENT_N=2
LCD_LAYOUT_1_ELEMENT_1_NAME=''
LCD_LAYOUT_1_ELEMENT_1_ACTIVE='no'
LCD_LAYOUT_1_ELEMENT_1_ROW=''
LCD_LAYOUT_1_ELEMENT_1_COL=''

LCD_LAYOUT_CYCLE='no'
LCD_LAYOUT_CYCLE_TIME=1

LCD_USE_SHUTDOWN_LAYOUT='yes'
#LCD_DEFAULT_SHUTDOWN_LAYOUT='yes'

LCD_UPDATE_TEXT=500
LCD_UPDATE_BAR=100
LCD_UPDATE_ICON=500

LCD_IMOND='no'
LCD_IMOND_HOST='localhost'
LCD_IMOND_PORT=5000
LCD_IMOND_PASS=''

LCD_TELMOND='no'
LCD_TELMOND_HOST='localhost'
LCD_TELMOND_PORT=5001
LCD_TELMOND_PHONEBOOK='/etc/phonebook'

LCD_MPD='no'
LCD_MPD_HOST='localhost'
LCD_MPD_PORT=6600

LCD_POP3_N=0
LCD_POP3_1_SERVER=''
LCD_POP3_1_USER=''
LCD_POP3_1_PASS=''
LCD_POP3_1_PORT=''

LCD_UPDATE_TEXT='1000'
LCD_UPDATE_BAR='1000'
LCD_UPDATE_ICON='1000'



# ----------------------------------------------------------------------------
# Read old configuration and update old variables
updateVariables() {
    # -------------------
    # Read current values
    if [ -f /etc/config.d/${packageName} ]
    then
        . /etc/config.d/${packageName}
    fi
}



# ----------------------------------------------------------------------------
# Write config and default files
makeConfigFile() {
    internal_conf_file=${1}
    {
    # ----------------------------------------------------------------------------
    printgpl -conf ${packageName} '2002-11-12' 'Nico Wallmeier'
    # ----------------------------------------------------------------------------

    # ----------------------------------------------------------------------------
    printgroup 'LCD configuration'
    # ----------------------------------------------------------------------------
    printvar 'START_LCD' 'Use: yes or no'

    # ----------------------------------------------------------------------------
    printgroup 'Display'
    # ----------------------------------------------------------------------------
    printvar 'LCD_TYPE'       '<type>:<model>'
    printvar 'LCD_WIRING'     'HD44780 compatible: fli4l or winamp'
    printvar 'LCD_PORT'       'LCD Device (e.g. /dev/parport0)'
    printvar 'LCD_SPEED'      'Serial port speed: 1200, 2400, 9600 or 19200'
    printvar 'LCD_CONTRAST'   'Display contrast'
    printvar ''               '- Matrix Orbital: 0 to 255       dftl: 160'
    printvar ''               '- CrystalFontz: 0 to 255'
    printvar 'LCD_BACKLIGHT'  'Backlight CrystalFontz display: 0 to 100'
    printvar ''               ' Cwlinux display: 0 to 8'
    printvar 'LCD_COLS'       'no. of lcd columns (16,20,32,40) dflt:  20'
    printvar 'LCD_ROWS'       'no. of lcd physical rows (1,2,4) dflt:   4'

    # ----------------------------------------------------------------------------
    printgroup 'Layout'
    # ----------------------------------------------------------------------------
    printvar 'LCD_LAYOUT_N'                    'Amount of layouts to configure'
    idx=1
    while [ ${idx} -le $LCD_LAYOUT_N ]
    do
        printvar 'LCD_LAYOUT_'${idx}'_NAME'               'Name of current layout'
        printvar 'LCD_LAYOUT_'${idx}'_ACTIVE'             'Is current layout active or not'
        printvar 'LCD_LAYOUT_'${idx}'_ELEMENT_N'          'Amount of elements (widgets) on this layout'

        eval layoutElems='$LCD_LAYOUT_'${idx}'_ELEMENT_N'
        idx2=1
        while [ ${idx2} -le $layoutElems ]
        do
            printvar 'LCD_LAYOUT_'$idx'_ELEMENT_'${idx2}'_NAME'     'Type and name of widget to use like Text:Foo'
            printvar 'LCD_LAYOUT_'$idx'_ELEMENT_'${idx2}'_ACTIVE'   'Is current widget active on this layout or not'
            printvar 'LCD_LAYOUT_'$idx'_ELEMENT_'${idx2}'_ROW'      'Row where current widget should be displayed'
            printvar 'LCD_LAYOUT_'$idx'_ELEMENT_'${idx2}'_COL'      'Column where current widget should be displayed'
            idx2=$((idx2+1))
        done
        idx=$((idx+1))
    done

    printvar 'LCD_LAYOUT_CYCLE'        'Cycle through configured and active layouts'
    printvar 'LCD_LAYOUT_CYCLE_TIME'   'How long should a layout been displayed before switching to the next one'

    # ----------------------------------------------------------------------------
    printgroup 'Server shutdown handling'
    # ----------------------------------------------------------------------------
    printvar 'LCD_USE_SHUTDOWN_LAYOUT'       'Activate special layout for server shutdown'
#    printvar 'LCD_DEFAULT_SHUTDOWN_LAYOUT'   'Configure shutdown layout'

    # ----------------------------------------------------------------------------
    printgroup 'Imond/Telmond/Mpd-Plugin'
    # ----------------------------------------------------------------------------
    printvar 'LCD_IMOND'             'Monitor imond'
    printvar 'LCD_IMOND_HOST'        'Host, where imond is running'
    printvar 'LCD_IMOND_PORT'        'Port, on which imond is running'
    printvar 'LCD_IMOND_PASS'        'If IMOND_PASS is set and imond is not'
    printvar ''                      'running on local machine, you need to'
    printvar ''                      'specify the password here'

    printvar 'LCD_TELMOND'           'Monitor telmond'
    printvar 'LCD_TELMOND_HOST'      'Host, where telmond is running'
    printvar 'LCD_TELMOND_PORT'      'Port, on which telmond is running'
    printvar 'LCD_TELMOND_PHONEBOOK' 'Phonebook to show names instead'
    printvar ''                      'of numbers'

    printvar 'LCD_MPD'               'Monitor mpd'
    printvar 'LCD_MPD_HOST'          'Host on which mpd is running'
    printvar 'LCD_MPD_PORT'          'Port, on which mpd is runnig'

    # ----------------------------------------------------------------------------
    printgroup 'POP3-Plugin'
    # ----------------------------------------------------------------------------
    printvar 'LCD_POP3_N'            'Number of pop3-accounts to poll'
    idx=1
    while [ ${idx} -le ${LCD_POP3_N} ]
    do
        printvar 'LCD_POP3_'${idx}'_SERVER' 'Pop3-Server'
        printvar 'LCD_POP3_'${idx}'_USER'   'Username'
        printvar 'LCD_POP3_'${idx}'_PASS'   'Password'
        eval port='$LCD_POP3_'${idx}'_PORT'
        if [ "$port" != "" ]
        then
            printvar 'LCD_POP3_'${idx}'_PORT' 'Pop3-Port'
        fi
        idx=$((idx+1))
    done

    # ----------------------------------------------------------------------------
    printgroup 'Variables'
    # ----------------------------------------------------------------------------
    printvar 'LCD_UPDATE_TEXT'       'time in milliseconds between text updates'
    printvar 'LCD_UPDATE_BAR'        'time in milliseconds between bar updates'
    printvar 'LCD_UPDATE_ICON'       'animation interval (msec)'

    # ----------------------------------------------------------------------------
    printend
    # ----------------------------------------------------------------------------

    } > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Create the check.d file
makeCheckFile() {
    printgpl -check ${packageName} '2010-08-18' 'Y. Schumann' >/etc/check.d/${packageName}
    cat >> /etc/check.d/${packageName} <<EOFG
# Variable                      OPT_VARIABLE       VARIABLE_N              VALUE
START_LCD                       -                  -                       YESNO
LCD_TYPE                        START_LCD          -                       LCD_DRIVER_CUI
LCD_PORT                        START_LCD          -                       LCDPORT
LCD_WIRING                      START_LCD          -                       LCD_WIRING_CUI
LCD_SPEED                       START_LCD          -                       LCD_SPEED_CUI
LCD_CONTRAST                    START_LCD          -                       LCD_CONTRAST_CUI
LCD_BACKLIGHT                   START_LCD          -                       LCD_BACKLIGHT_CUI
LCD_COLS                        START_LCD          -                       LCD_COLS_CUI
LCD_ROWS                        START_LCD          -                       LCD_ROWS_CUI

LCD_LAYOUT_N                    START_LCD                       -                        NUMERIC
LCD_LAYOUT_%_NAME               START_LCD                       LCD_LAYOUT_N             NOTEMPTY
LCD_LAYOUT_%_ACTIVE             START_LCD                       LCD_LAYOUT_N             YESNO
LCD_LAYOUT_%_ELEMENT_N          LCD_LAYOUT_%_ACTIVE             LCD_LAYOUT_N             NUMERIC
LCD_LAYOUT_%_ELEMENT_%_NAME     LCD_LAYOUT_%_ACTIVE             LCD_LAYOUT_%_ELEMENT_N   LCD_WIDGET_CUI
LCD_LAYOUT_%_ELEMENT_%_ACTIVE   LCD_LAYOUT_%_ACTIVE             LCD_LAYOUT_%_ELEMENT_N   YESNO
LCD_LAYOUT_%_ELEMENT_%_ROW      LCD_LAYOUT_%_ELEMENT_%_ACTIVE   LCD_LAYOUT_%_ELEMENT_N   NUMERIC
LCD_LAYOUT_%_ELEMENT_%_COL      LCD_LAYOUT_%_ELEMENT_%_ACTIVE   LCD_LAYOUT_%_ELEMENT_N   NUMERIC

LCD_LAYOUT_CYCLE                START_LCD                       -                        YESNO
LCD_LAYOUT_CYCLE_TIME           LCD_LAYOUT_CYCLE                -                        NOTEMPTY

LCD_USE_SHUTDOWN_LAYOUT         START_LCD                       -                        YESNO
#LCD_DEFAULT_SHUTDOWN_LAYOUT     LCD_USE_SHUTDOWN_LAYOUT         -                        YESNO

LCD_UPDATE_TEXT                 START_LCD          -                       NUMERIC
LCD_UPDATE_BAR                  START_LCD          -                       NUMERIC
LCD_UPDATE_ICON                 START_LCD          -                       NUMERIC

LCD_IMOND                       START_LCD          -                       YESNO
LCD_IMOND_HOST                  LCD_IMOND          -                       LCDFQDN
LCD_IMOND_PORT                  LCD_IMOND          -                       PORT
LCD_IMOND_PASS                  LCD_IMOND          -                       NONE

LCD_TELMOND                     START_LCD          -                       YESNO
LCD_TELMOND_HOST                LCD_IMOND          -                       LCDFQDN
LCD_TELMOND_PORT                LCD_IMOND          -                       PORT
LCD_TELMOND_PHONEBOOK           LCD_IMOND          -                       E_ABS_PATH

LCD_MPD                         START_LCD          -                       YESNO
LCD_MPD_HOST                    LCD_MPD            -                       LCDFQDN
LCD_MPD_PORT                    LCD_MPD            -                       PORT

LCD_POP3_N                      START_LCD          -                       NUMERIC
LCD_POP3_%_SERVER               START_LCD          LCD_POP3_N              FQDN
LCD_POP3_%_USER                 START_LCD          LCD_POP3_N              NOTEMPTY
LCD_POP3_%_PASS                 START_LCD          LCD_POP3_N              NOTEMPTY
LCD_POP3_%_PORT                 START_LCD          LCD_POP3_N              PORT

EOFG

    # Set rights for check.d file
    chmod 0600 /etc/check.d/${packageName}
    chown root /etc/check.d/${packageName}

    printgpl -check_exp ${packageName} '2010-08-18' 'Y. Schumann' >/etc/check.d/${packageName}.exp
    cat >> /etc/check.d/${packageName}.exp <<EOFG

LCDDRIVER                  = 'Crystalfontz|Curses|HD44780|MatrixOrbital|MilfordInstruments|M50530|Cwlinux|T6963|WincorNixdorf|LCD2USB|serdisplib'
                           : 'not a valid lcd driver'

LCDMODELCRYSTALFONTZ       = '626|631|632|633|634|636'
                           : 'not a valid Crystalfontz display'

LCDMODELHD44780            = 'generic|Noritake|Soekris|HD66712|LCM-162'
                           : 'not a valid HD44780 model'

LCDMODELMATRIXORBITAL      = 'LCD0821|LCD2021|LCD1641|LCD2041|LCD4021|LCD4041|LK202-25|LK204-25|LK404-55|VFD2021|VFD2041|VFD4021|VK202-25|VK204-25|GLC12232|GLC24064|GLK24064-25|GLK12232-25|LK404-AT|VFD1621|LK402-12|LK162-12|LK204-25PC|LK202-24-USB|LK204-24-USB'
                           : 'not a valid MatrixOrbital model'

LCDMODELMILFORDINSTRUMENTS = 'MI216|MI220|MI240|MI420'
                           : 'not a valid MilfordInstruments model'

LCDMODELCWLINUX            = 'CW1602|CW12232'
                           : 'not a valid Cwlinux model'

LCDMODELWINCORNIXDORF      = 'BA63|BA66'
                           : 'not a valid WincorNixdorf model'

LCDMODELSERDISPLIB         = 'OPTREX323|PCD8544|LPH7366|LPH7690|NOKIA7110|ERICSSONT2X|LSU7S1011A|T6963|TLX1391|SED133X|NEC21A|LPH7508|HP12542R|N3510I|ERICSSONR520|KS0108|CTINCLUD'
                           : 'not a valid serdisplib model'

LCDMODEL          = '(RE:LCDMODELCRYSTALFONTZ)|(RE:LCDMODELHD44780)|(RE:LCDMODELMATRIXORBITAL)|(RE:LCDMODELMILFORDINSTRUMENTS)|(RE:LCDMODELCWLINUX)|(RE:LCDMODELWINCORNIXDORF)|(RE:LCDMODELSERDISPLIB)'
                  : 'Not a valid lcd model'

LCD_DRIVER_CUI    = 'Crystalfontz:(RE:LCDMODELCRYSTALFONTZ)|Curses|HD44780:(RE:LCDMODELHD44780)|MatrixOrbital:(RE:LCDMODELMATRIXORBITAL)|MilfordInstruments:(RE:LCDMODELMILFORDINSTRUMENTS)|M50530|Cwlinux:(RE:LCDMODELCWLINUX)|T6963|WincorNixdorf:(RE:LCDMODELWINCORNIXDORF)|LCD2USB|serdisplib:(RE:LCDMODELSERDISPLIB)'
                  : 'Not a valid lcd model and type selection'

LCD_CONTRAST_CUI  = '(RE:NUMERIC)'
                  : 'Not a numeric value'

LCD_BACKLIGHT_CUI = '(RE:NUMERIC)'
                  : 'Not a numeric value'

LCD_COLS_CUI      = '(RE:NUMERIC)'
                  : 'Not a numeric value'

LCD_ROWS_CUI      = '(RE:NUMERIC)'
                  : 'Not a numeric value'

LCDSERPORT        = '/dev/ttyS[0-9]'
                  : 'Not a valid serial port, e.g. /dev/ttyS0'

LCDPARPORT        = '/dev/parport[0-9]'
                  : 'Not a valid parport, e.g. /dev/parport0'

LCDTTYPORT        = '/dev/tty[0-9]'
                  : 'Not a valid terminal, e.g. /dev/tty3'

LCDPORT           ='(RE:LCDSERPORT)|(RE:LCDPARPORT)|(RE:LCDTTYPORT)|/dev/usb|'
                  : 'Not a valid port'

LCD_WIRING_CUI    = 'fli4l|winamp'
                  : 'Not a valid wiring schema - must be fli4l or winamp'

LCD_SPEED_CUI     = '---|1200|2400|4800|9600|19200|38400|115200'
                  : 'Not a valid speed, possible values are 1200, 2400, 4800, 9600, 19200, 38400 or 115200'

LCD_WIDGET_CUI    = '(RE:NOTEMPTY)'
                  : 'One of the configured widgets must be choosen!'

LCDFQDN           = '(RE:FQDN)|localhost'
                  : 'Fully qualified domain name'

EOFG

    # Set rights for check.exp file
    chmod 0600 /etc/check.d/${packageName}.exp
    chown root /etc/check.d/${packageName}.exp

#    printgpl -check_ext ${packageName} '2010-08-18' 'Y. Schumann' >/etc/check.d/${packageName}.ext
#    cat >> /etc/check.d/${packageName}.ext <<EOFG


#EOFG

    # Set rights for check.ext file
#    chmod 0600 /etc/check.d/${packageName}.ext
#    chown root /etc/check.d/${packageName}.ext
}



# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
# Write default config file
if [ -f /etc/config.d/${packageName} ] ; then
    mecho --info -n 'Updating configuration (This may take a while): .'
else
    mecho --info -n 'Creating configuration (This may take a while): .'
fi

makeConfigFile /etc/default.d/${packageName}

# Update values from old version
mecho --info -n '.'
updateVariables

# Write new config file
mecho --info -n '.'
makeConfigFile /etc/config.d/${packageName}

# Write check.d file
mecho --info -n '.'
makeCheckFile

mecho ''
mecho --ok

if ${modifiedSomething} ; then
    mecho --warn ' -> Read documentation for modified parameter(s)!'
fi

exit 0
