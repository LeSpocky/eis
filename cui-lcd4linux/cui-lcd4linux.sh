#!/bin/bash
# ----------------------------------------------------------------------------
# cui-lcd4linux-update.sh - update or generate new lcd configuration
#
# Creation:     12.11.2002  nico
# Copyright (c) 2001-2015 The eisfair Team, <team(at)eisfair(dot)org>
# Distributed under the terms of the GNU General Public License v2
# ----------------------------------------------------------------------------

#exec 2> `pwd`/cui-lcd4linux-trace$$.log
#set -x

# Include libs, helpers a.s.o.
. /var/install/include/eislib
. /var/install/include/configlib

crontabPath=/etc/cron/root

packageName=cui-lcd4linux
widgetPackageName=cui-lcd4linux-widgets
activeConfigurationLink='/etc/lcd4linux/lcd4linux.conf'
nativeMainConfiguration='/etc/lcd4linux/lcd4linux.main.conf'
nativeShutdownConfiguration='/etc/lcd4linux/lcd4linux.shutdown.conf'
crontabFile=${crontabPath}/cui-lcd4linux

# Load configurations
. /etc/config.d/${packageName}
. /etc/config.d/${widgetPackageName}



# ----------------------------------------------------------------------------
# Add variables
addVariables () {
    added=false
    mecho --info 'Adding new parameter(s)...'

    if [ "$LCD_MPD_HOST" = "" ] ; then
        LCD_MPD_HOST="localhost"
        added=true
        mecho " LCD_MPD_HOST"
    fi

    if [ "$LCD_MPD_PORT" = "" ] ; then
        LCD_MPD_PORT=6600
        added=true
        mecho " LCD_MPD_PORT"
    fi

   	mecho --ok
    if ${added} ; then
        mecho --warn ' -> Read documentation for correct parameter usage!'
#    else
#        mecho --info ' nothing to do.'
    fi
}



# ----------------------------------------------------------------------------
# Write config snippet for each widget. These snippets are includet later
# during creation of native lcd4linux configuration.
writeWidgetConfigSnippets () {
    idx=1
    while [ ${idx} -le ${LCD_WIDGET_TEXT_N} ] ; do
        eval name='$LCD_WIDGET_TEXT_'${idx}'_NAME'
        eval active='$LCD_WIDGET_TEXT_'${idx}'_ACTIVE'
        eval prefix='$LCD_WIDGET_TEXT_'${idx}'_PREFIX'
        eval expression='$LCD_WIDGET_TEXT_'${idx}'_EXP'
        eval postfix='$LCD_WIDGET_TEXT_'${idx}'_POSTFIX'
        eval width='$LCD_WIDGET_TEXT_'${idx}'_WIDTH'
        eval precision='$LCD_WIDGET_TEXT_'${idx}'_PRECISION'
        eval align='$LCD_WIDGET_TEXT_'${idx}'_ALIGN'
        eval speed='$LCD_WIDGET_TEXT_'${idx}'_SPEED'
        eval update='$LCD_WIDGET_TEXT_'${idx}'_UPDATE'

        if [ "$active" == 'yes' ] ; then
            (
            echo "Widget $name {"
            echo "  class      'Text'"
            echo "  expression $expression"
            if [ -n "$prefix" ] ; then
                echo "  prefix     '$prefix'"
            fi
            if [ -n "$postfix" ] ; then
                echo "  postfix    '$postfix'"
            fi
            echo "  width      $width"
            if [ -n "$precision" ] ; then
                echo "  precision  $precision"
            fi
            if [ -n "$align" ] ; then
                case ${align} in
                    'Left')
                        echo "  align      'L'"
                        ;;
                    'Center')
                        echo "  align      'C'"
                        ;;
                    'Right')
                        echo "  align      'R'"
                        ;;
                    'Marquee')
                        echo "  align      'M'"
                        ;;
                    * )
                        echo "  align      '$align'"
                        ;;
                esac
            fi
            if [ -n "$speed" ] ; then
                echo "  speed      $speed"
            fi
            echo "  update     $update"
            echo "}"
            ) > /tmp/$$-cui-lcd4linux-widget-$name.txt
        fi
        idx=$((idx+1))
    done

    idx=1
    while [ ${idx} -le ${LCD_WIDGET_BAR_N} ] ; do
        eval name='$LCD_WIDGET_BAR_'${idx}'_NAME'
        eval active='$LCD_WIDGET_BAR_'${idx}'_ACTIVE'
        eval exp='$LCD_WIDGET_BAR_'${idx}'_EXP'
        eval exp2='$LCD_WIDGET_BAR_'${idx}'_EXP2'
        eval length='$LCD_WIDGET_BAR_'${idx}'_LENGTH'
        eval min='$LCD_WIDGET_BAR_'${idx}'_MIN'
        eval max='$LCD_WIDGET_BAR_'${idx}'_MAX'
        eval direction='$LCD_WIDGET_BAR_'${idx}'_DIRECTION'
        eval update='$LCD_WIDGET_BAR_'${idx}'_UPDATE'
        eval style='$LCD_WIDGET_BAR_'${idx}'_STYLE'

        if [ "$active" == 'yes' ] ; then
            (
            echo "Widget $name {"
            echo "  class       'Bar'"
            echo "  expression  $exp"
            if [ -n "$exp2" ] ; then
                echo "  expression2 $exp2"
            fi
            echo "  length      $length"
            if [ -n "$min" ] ; then
                echo "  min         $min"
            fi
            if [ -n "$max" ] ; then
                echo "  max         $max"
            fi

            case $direction in
                'North')
                    echo "  direction   'N'"
                    ;;
                'East')
                    echo "  direction   'E'"
                    ;;
                'South')
                    echo "  direction   'S'"
                    ;;
                'West')
                    echo "  direction   'W'"
                    ;;
                * )
                    echo "  direction   '$direction'"
                    ;;
            esac

            if [ "$style" != '---' ] ; then
                echo "  style       '$style'"
            fi
            echo "  update      $update"
            echo "}"
            ) > /tmp/$$-cui-lcd4linux-widget-$name.txt
        fi
        idx=$((idx+1))
    done

    idx=1
    activeIconWidgets=0
    while [ ${idx} -le $LCD_WIDGET_ICON_N ] ; do
        eval name='$LCD_WIDGET_ICON_'${idx}'_NAME'
        eval active='$LCD_WIDGET_ICON_'${idx}'_ACTIVE'
        eval row1='$LCD_WIDGET_ICON_'${idx}'_ROW1'
        eval row2='$LCD_WIDGET_ICON_'${idx}'_ROW2'
        eval row3='$LCD_WIDGET_ICON_'${idx}'_ROW3'
        eval row4='$LCD_WIDGET_ICON_'${idx}'_ROW4'
        eval row5='$LCD_WIDGET_ICON_'${idx}'_ROW5'
        eval row6='$LCD_WIDGET_ICON_'${idx}'_ROW6'
        eval row7='$LCD_WIDGET_ICON_'${idx}'_ROW7'
        eval row8='$LCD_WIDGET_ICON_'${idx}'_ROW8'
        eval visible='$LCD_WIDGET_ICON_'${idx}'_VISIBLE'
        eval speed='$LCD_WIDGET_ICON_'${idx}'_SPEED'

        if [ "$active" == 'yes' ] ; then
            (
            echo "Widget $name {"
            echo "    class 'icon'"
            echo "    speed $speed"
            if [ -n "$visible" ] ; then
                echo "    visible $visible"
            fi
            echo "    bitmap {"
            echo "      row1 '$row1'"
            echo "      row2 '$row2'"
            echo "      row3 '$row3'"
            echo "      row4 '$row4'"
            echo "      row5 '$row5'"
            echo "      row6 '$row6'"
            echo "      row7 '$row7'"
            echo "      row8 '$row8'"
            echo "    }"
            echo "}"
            ) > /tmp/$$-cui-lcd4linux-widget-$name.txt
            activeIconWidgets=$((activeIconWidgets+1))
        fi
        idx=$((idx+1))
    done
}



# ----------------------------------------------------------------------------
# Only 8 icon widgets can be used at the same time. TODO: Maybe some
# finetuning neccessary if different depending on used controller.
checkIconWidgets () {
    if [ $activeIconWidgets -gt 8 ] ; then
        mecho --warn "You have too many active icon widgets! Limiting them to 8"
        activeIconWidgets=8
    fi
}



# ----------------------------------------------------------------------------
# Write the header for native lcd configuration
writeLCDConfigHeader () {
    local configfileToGenerate=$1

    (
        echo "Display $LCD_DRIVER {"
        echo "  Driver '$LCD_DRIVER'"
        case $LCD_DRIVER in
            Crystalfontz)
                echo "  Model '$LCD_MODEL'"
                echo "  Port '$LCD_PORT'"
                echo "  Speed $LCD_SPEED"
                echo "  Contrast $LCD_CONTRAST"
                echo "  Backlight $LCD_BACKLIGHT"
                ;;
            Curses)
                echo "  Size '${LCD_COLS}x${LCD_ROWS}'"
                ;;
            Cwlinux)
                echo "  Model '$LCD_MODEL'"
                echo "  Port '$LCD_PORT'"
                echo "  Speed $LCD_SPEED"
                echo "  Brightness $LCD_BACKLIGHT"
                ;;
            HD44780)
                echo "  Model '$LCD_MODEL'"
                echo "  Bus 'parport'"
                echo "  Port '$LCD_PORT'"
                if [ `/usr/bin/expr $LCD_COLS '*' $LCD_ROWS` -gt 80 ] ; then
                    echo "  Controllers 2"
                else
                      echo "  Controllers 1"
                fi
                echo "  Bits '8'"
                echo "  UseBusy 0"
                echo "  Backlight 0"
                echo "  Size '${LCD_COLS}x${LCD_ROWS}'"
                echo "  Wire {"
                case $LCD_WIRING in
                    fli4l)
                        echo "    RW         'GND'"
                        echo "    RS         'AUTOFD'"
                        echo "    ENABLE     'STROBE'"
                        ;;
                    winamp)
                        echo "    RW         'AUTOFD'"
                        echo "    RS         'INIT'"
                        echo "    ENABLE     'STROBE'"
                        ;;
                esac
                if [ `/usr/bin/expr $LCD_COLS '*' $LCD_ROWS` -gt 80 ] ; then
                    echo "    ENABLE2    'SELECT'"
                else
                    echo "    ENABLE2    'GND'"
                fi
                echo "    BACKLIGHT  'GND'"
                echo "    GPO        'GND'"
                echo "    POWER      'GND'"
                echo "  }"
                ;;
            MatrixOrbital)
                echo "  Model '$LCD_MODEL'"
                echo "  Port '$LCD_PORT'"
                echo "  Speed $LCD_SPEED"
                echo "  Contrast $LCD_CONTRAST"
                echo "  Backlight $LCD_BACKLIGHT"
                ;;
            MilfordInstruments)
                echo "  Model '$LCD_MODEL'"
                echo "  Port '$LCD_PORT'"
                echo "  Speed $LCD_SPEED"
                ;;
            M50530)
                echo "  Model 'generic'"
                echo "  Port '$LCD_PORT'"
                echo "  Size '${LCD_COLS}x${LCD_ROWS}'"
                echo "  Font '5x7'"
                echo "  GPOs 0"
                echo "  Duty 2"
                echo "  Wire {"
                echo "    EX   'STROBE'"
                echo "    IOC1 'SLCTIN'"
                echo "    IOC2 'AUTOFD'"
                echo "    GPO  'GND'"
                echo "  }"
                ;;
            T6963)
                echo "  Model 'generic'"
                echo "  Port '$LCD_PORT'"
                echo "  Size '${LCD_COLS}x${LCD_ROWS}'"
                echo "  Font '5x8'"
                echo "  Wire {"
                echo "    CE 'STROBE'"
                echo "    CD 'SLCTIN'"
                echo "    RD 'AUTOFD'"
                echo "    WR 'INIT'"
                echo "  }"
                ;;
            WincorNixdorf)
                echo "  Model 'generic'"
                echo "  Port '$LCD_PORT'"
                echo "  Speed 9600"
                echo "  SelfTest 1"
                echo "  BarChar 219"
                ;;
            LCD2USB)
                echo "  Contrast $LCD_CONTRAST"
                echo "  Brightness $LCD_BACKLIGHT"
                echo "  Size '${LCD_COLS}x${LCD_ROWS}'"
                ;;
            serdisplib)
                echo "  Model '$LCD_MODEL'"
                echo "  Port '$LCD_PORT'"
                echo "  Contrast $LCD_CONTRAST"
                echo "  Backlight $LCD_BACKLIGHT"
                ;;
        esac
        echo "  Icons $activeIconWidgets"
        echo "}"
        echo
    ) > ${configfileToGenerate}
}



# ----------------------------------------------------------------------------
# Write native lcd configuration
writeLCDConfig () {
    LCD_DRIVER=`echo ${LCD_TYPE} | cut -d ":" -f 1`
    LCD_MODEL=`echo ${LCD_TYPE} | cut -d ":" -f 2`

    if [ "$LCD_DRIVER" == "$LCD_MODEL" ] ; then
        mecho "Writing configuration for lcd '$LCD_DRIVER'"
    else
        mecho "Writing configuration for lcd '$LCD_DRIVER', type '$LCD_MODEL'"
    fi

    writeLCDConfigHeader ${nativeMainConfiguration}

    (
        # -------------------------------------------------
        # Put all widget definitions into the configuration
        cat /tmp/$$-cui-lcd4linux-widget-*.txt

        # ------------------------------------
        # Create main part of lcd4linux config
        idx=1
        while [ ${idx} -le $LCD_LAYOUT_N ] ; do
            # Loop over all configured layouts
            eval currentLayoutName='$LCD_LAYOUT_'${idx}'_NAME'
            eval active='$LCD_LAYOUT_'${idx}'_ACTIVE'

            if [ "$active" == 'yes' ] ; then
                # -------------------------------------------------------
                # Store name of last active layout. Neccessary in case of
                # deactivated layouts on the end of the list.
                layoutName=$currentLayoutName

                # ----------------------------------
                # Write header lines for row entries
                rowIdx=1
                while [ $rowIdx -le $LCD_ROWS ] ; do
                    echo "  Row${rowIdx} {" > /tmp/$$-cui-lcd4linux-row${rowIdx}.txt
                    rowIdx=$((rowIdx+1))
                done

                eval elements='$LCD_LAYOUT_'${idx}'_ELEMENT_N'
                idx2=1
                while [ ${idx2} -le $elements ] ; do
                    eval fullElemName='$LCD_LAYOUT_'${idx}'_ELEMENT_'${idx2}'_NAME'
                    elemType=${fullElemName/:*}
                    elemName=${fullElemName/*:}
                    eval elemActive='$LCD_LAYOUT_'${idx}'_ELEMENT_'${idx2}'_ACTIVE'
                    if [ "$elemActive" == 'yes' ] ; then
                        eval elemRow='$LCD_LAYOUT_'${idx}'_ELEMENT_'${idx2}'_ROW'
                        eval elemCol='$LCD_LAYOUT_'${idx}'_ELEMENT_'${idx2}'_COL'
                        case $elemRow in
                            1)
                                echo "    Col${elemCol}    '$elemName'" >> /tmp/$$-cui-lcd4linux-row1.txt
                                ;;
                            2)
                                echo "    Col${elemCol}    '$elemName'" >> /tmp/$$-cui-lcd4linux-row2.txt
                                ;;
                            3)
                                echo "    Col${elemCol}    '$elemName'" >> /tmp/$$-cui-lcd4linux-row3.txt
                                ;;
                            4)
                                echo "    Col${elemCol}    '$elemName'" >> /tmp/$$-cui-lcd4linux-row4.txt
                                ;;
                            *)
                                ;;
                        esac
                    fi
                    idx2=$((idx2+1))
                done

                # ------------------------------------------------------
                # Close row entries and put them into the layout section
                for currentRowFile in `ls /tmp/$$-cui-lcd4linux-row*.txt` ; do
                    echo "  }" >> $currentRowFile
                done
                echo "Layout $layoutName {"
                cat /tmp/$$-cui-lcd4linux-row*.txt
                echo "}"
            fi

            idx=$((idx+1))
        done

        if [ "$LCD_TELMOND" == 'yes' ] ; then
            echo
            echo "Plugin Telmon {"
            echo "  Host '$LCD_TELMOND_HOST'"
            echo "  Port $LCD_TELMOND_PORT"
            if [ "$LCD_TELMOND_PHONEBOOK" != "" ] ; then
                echo "  Phonebook '$LCD_TELMOND_PHONEBOOK'"
            fi
            echo "}"
        fi
        if [ "$LCD_IMOND" == 'yes' ] ; then
            echo
            echo "Plugin Imon {"
            echo "  Host '$LCD_IMOND_HOST'"
            echo "  Port $LCD_IMOND_PORT"
            if [ "$LCD_IMOND_PASS" != "" ] ; then
                echo "  Pass '$LCD_IMOND_PASS'"
            fi
            echo "}"
        fi
        if [ "$LCD_MPD" == 'yes' ] ; then
            echo
            echo "Plugin Mpd {"
            echo "  Host '$LCD_MPD_HOST'"
            echo "  Port $LCD_MPD_PORT"
            echo "}"
        fi
        echo

        if [ "$LCD_POP3_N" != "0" ] ; then
            echo "Plugin POP3 {"
            idx=1
            while [ ${idx} -le $LCD_POP3_N ] ; do
                eval server='$LCD_POP3_'${idx}'_SERVER'
                eval user='$LCD_POP3_'${idx}'_USER'
                eval pass='$LCD_POP3_'${idx}'_PASS'
                eval port='$LCD_POP3_'${idx}'_PORT'

                echo "  server${idx} '$server'"
                echo "  user${idx} '$user'"
                echo "  password${idx} '$pass'"
                if [ "$port" != "" ] ; then
                    echo "  port${idx} $port"
                fi
                idx=$((idx+1))
            done
            echo "}"
            echo
        fi

        echo
        echo "Display '$LCD_DRIVER'"
        echo "Layout '$layoutName'"
        echo
        echo "Variables {"
        echo "  tick $LCD_UPDATE_BAR"
        echo "  tack $LCD_UPDATE_TEXT"
        echo "  tock $LCD_UPDATE_ICON"
        echo "}"
        echo ""
    ) >> ${nativeMainConfiguration}

    chmod 600 ${nativeMainConfiguration}
    chown root.root ${nativeMainConfiguration}

    mecho --ok
}



# ----------------------------------------------------------------------------
# Write native lcd configuration for server shutdown
writeShutdownConfig () {
    if [ "$LCD_USE_SHUTDOWN_LAYOUT" == 'yes' ] ; then
        LCD_DRIVER=`echo $LCD_TYPE | cut -d ":" -f 1`
        LCD_MODEL=`echo $LCD_TYPE | cut -d ":" -f 2`

        if [ "$LCD_DRIVER" == "$LCD_MODEL" ] ; then
            mecho "Writing shutdown configuration for lcd '$LCD_DRIVER'"
        else
            mecho "Writing shutdown configuration for lcd '$LCD_DRIVER', type '$LCD_MODEL'"
        fi

        # Set some vars to a fix value
        LCD_CONTRAST=0
        LCD_BACKLIGHT=0
        activeIconWidgets=0

        writeLCDConfigHeader ${nativeShutdownConfiguration}

        (
            echo "Layout shutdown {"
            echo "}"
            echo
            echo "Display '$LCD_DRIVER'"
            echo "Layout 'shutdown'"
            echo
        ) >> ${nativeShutdownConfiguration}

        chmod 600 ${nativeShutdownConfiguration}
        chown root.root ${nativeShutdownConfiguration}

        mecho --ok
    else
        rm -f ${nativeShutdownConfiguration}
    fi
}


# ----------------------------------------------------------------------------
# Add cron job for layout cycling
addCronjob () {
	if [ "$LCD_LAYOUT_CYCLE" == 'yes' ] ; then
	    mecho "Adding cron job..."

	    if [ ! -d ${crontabPath} ] ; then
	        mkdir -p ${crontabPath}
	    fi

	    (
	        echo "# =============================================================="
	        echo "# LCD layout cycle cron job"
	        echo "# Do not edit this file, edit lcd configuraton using"
	        echo "# eisfair configuration tools"
	        echo "# Creation: ${EISDATE}  ${EISTIME}"
	        echo "# =============================================================="
	        echo "*/$LCD_LAYOUT_CYCLE_TIME * * * * /var/install/bin/cui-lcd4linux-cycle-layouts.sh"
	        echo ""
	    ) > ${crontabFile}
	else
	    mecho "Removing cron job if existing..."
		rm -rf ${crontabFile}
	fi

    mecho --ok
}



# ----------------------------------------------------------------------------
# Remove temporary files etc. pp.
cleanup () {
    rm -rf /tmp/$$-cui-lcd4linux-*.txt
}



# ============================================================================
# Main
# ============================================================================
rm -f ${activeConfigurationLink}
rm -f ${nativeMainConfiguration}
rm -f ${nativeShutdownConfiguration}

if [ "${START_LCD}" == 'yes' -a "${START_LCD_WIDGET}" == 'yes' ] ; then
    writeWidgetConfigSnippets
    checkIconWidgets
    writeLCDConfig
    writeShutdownConfig
    ln -s ${nativeMainConfiguration} ${activeConfigurationLink}
    addCronjob
    cleanup
    rc-update --quiet add cui-lcd4linux
    rc-service --quiet fcron reload
else
    rc-update --quiet del cui-lcd4linux
	rm -rf ${crontabFile}
    rc-service --quiet fcron reload
fi
