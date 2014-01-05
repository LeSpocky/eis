#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-lcd4linux-cycle-layouts.sh - Cycle through all configured layouts
#
# Creation:     2010-01-09 Y. Schumann
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

exec 2> /tmp/cui-lcd4linux-cycle-layouts-trace$$.log
set -x

# include libs
. /var/install/include/eislib
. /var/install/include/configlib

packageName=lcd
nativeMainConfiguration='/etc/lcd4linux.main.conf'
currentLayoutFile='/etc/lcd4linux.currentlayout'

# Load configurations
. /etc/config.d/$packageName
if [ -f $currentLayoutFile ]
then
    . $currentLayoutFile
else
    currentActiveLayout=1
    echo "$currentActiveLayout" > $currentLayoutFile
fi



# ----------------------------------------------------------------------------
# Update native lcd configuration by cycling through configured layouts
# ----------------------------------------------------------------------------
cycleLayout ()
{
    nextLayout=$((currentActiveLayout+1))

    # At first count active layouts
    idx=1
    activeLayouts=0
    while [ $idx -le $LCD_LAYOUT_N ]
    do
        # Loop over all configured layouts
        eval active='$LCD_LAYOUT_'$idx'_ACTIVE'
        if [ "$active" == 'yes' ]
        then
            activeLayouts=$((activeLayouts+1))
        fi
        idx=$((idx+1))
    done

    # If next layout number is greater than the number of available
    # active layouts, restart cycle on layout 1.
    if [ $nextLayout -gt $activeLayouts ]
    then
        nextLayout=1
    fi

    # Now determine the layout name to activate
    idx=1
    idx2=1
    while [ $idx -le $LCD_LAYOUT_N ]
    do
        # Loop over all configured layouts
        eval active='$LCD_LAYOUT_'$idx'_ACTIVE'
        if [ "$active" == 'yes' ]
        then
            if [ $idx2 -eq $nextLayout ]
            then
                eval layoutName='$LCD_LAYOUT_'$idx2'_NAME'
                sed -e "s#Layout '.*'\$#Layout '$layoutName'#g" $nativeMainConfiguration > ${nativeMainConfiguration}.new
                mv ${nativeMainConfiguration}.new $nativeMainConfiguration
			    chmod 600 $nativeMainConfiguration
			    chown root.root $nativeMainConfiguration
                /etc/init.d/lcd restart
                echo "currentActiveLayout=$nextLayout" > $currentLayoutFile
                return
            fi
            idx2=$((idx2+1))
        fi
        idx=$((idx+1))
    done
}



# ============================================================================
# Main
# ============================================================================
if [ "${START_LCD}" == 'yes' ]
then
    cycleLayout
fi

# ============================================================================
# End
# ============================================================================
