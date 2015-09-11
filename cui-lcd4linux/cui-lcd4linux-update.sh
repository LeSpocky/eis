#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-lcd4linux-update.sh - paramater update script
# Creation   : 2010-08-18 Y. Schumann
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------

#exec 2> `pwd`/cui-lcd4linux-update-trace$$.log
#set -x

# Include libs, helpers a.s.o.
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
    [ -f /etc/config.d/${packageName} ] && . /etc/config.d/${packageName}
}


# ----------------------------------------------------------------------------
# Write config and default files
makeConfigFile() {
    internal_conf_file=${1}
    {
    # ----------------------------------------------------------------------------
    printgpl --conf ${packageName}
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
    chmod 0644 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Main

# Update values from old version
updateVariables

# Write new config file
makeConfigFile /etc/config.d/${packageName}

exit 0
