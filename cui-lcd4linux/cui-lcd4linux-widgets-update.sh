#! /bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-lcd4linux-update.sh - paramater update script
#
# Creation:    2010-10-03 Y. Schumann
#
# Copyright (c) 2001-2014 The eisfair Team, <team(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2> `pwd`/cui-lcd4linux-widgets-update-trace$$.log
#set -x

# Include libs, helpers a.s.o.
. /var/install/include/eislib
. /var/install/include/configlib

# Set variables
packageName=cui-lcd4linux-widgets
mainPackageName=cui-lcd4linux
modifiedSomething=false



# ----------------------------------------------------------------------------
# Set the default values for configuration
# ----------------------------------------------------------------------------
START_LCD_WIDGET='no'

# Text widgets
LCD_WIDGET_TEXT_N=23
LCD_WIDGET_TEXT_1_NAME='MemInfo'
LCD_WIDGET_TEXT_1_ACTIVE='yes'
LCD_WIDGET_TEXT_1_PREFIX=''
LCD_WIDGET_TEXT_1_EXP="meminfo('MemTotal')/1024"
LCD_WIDGET_TEXT_1_POSTFIX=' MB RAM'
LCD_WIDGET_TEXT_1_WIDTH='11'
LCD_WIDGET_TEXT_1_PRECISION='0'
LCD_WIDGET_TEXT_1_ALIGN='Right'
LCD_WIDGET_TEXT_1_SPEED='500'
LCD_WIDGET_TEXT_1_UPDATE='500'

LCD_WIDGET_TEXT_2_NAME='Load'
LCD_WIDGET_TEXT_2_ACTIVE='yes'
LCD_WIDGET_TEXT_2_PREFIX='Load'
LCD_WIDGET_TEXT_2_EXP='loadavg(1)'
#LCD_WIDGET_TEXT_2_POSTFIX="loadavg(1)>1.0?'!':' '"
LCD_WIDGET_TEXT_2_POSTFIX="loadavg(1) > 2.0 ? '!' : ' '"
#LCD_WIDGET_TEXT_2_WIDTH='10'
LCD_WIDGET_TEXT_2_WIDTH='8'
LCD_WIDGET_TEXT_2_PRECISION='1'
LCD_WIDGET_TEXT_2_ALIGN='Right'
LCD_WIDGET_TEXT_2_SPEED='500'
LCD_WIDGET_TEXT_2_UPDATE='500'

LCD_WIDGET_TEXT_3_NAME='IO'
LCD_WIDGET_TEXT_3_ACTIVE='yes'
LCD_WIDGET_TEXT_3_PREFIX=''
LCD_WIDGET_TEXT_3_EXP="(proc_stat::disk('.*', 'rblk', 500) + proc_stat::disk('.*', 'wblk', 500))/2"
LCD_WIDGET_TEXT_3_POSTFIX=''
LCD_WIDGET_TEXT_3_WIDTH='7'
LCD_WIDGET_TEXT_3_PRECISION='0'
LCD_WIDGET_TEXT_3_ALIGN='Right'
LCD_WIDGET_TEXT_3_SPEED='500'
LCD_WIDGET_TEXT_3_UPDATE='500'

LCD_WIDGET_TEXT_4_NAME='OS'
LCD_WIDGET_TEXT_4_ACTIVE='yes'
LCD_WIDGET_TEXT_4_PREFIX=''
LCD_WIDGET_TEXT_4_EXP="*** '.uname('sysname').' '.uname('release').' ***"
LCD_WIDGET_TEXT_4_POSTFIX=''
LCD_WIDGET_TEXT_4_WIDTH='20'
LCD_WIDGET_TEXT_4_PRECISION='0'
LCD_WIDGET_TEXT_4_ALIGN='Marquee'
#    style 'bold'
LCD_WIDGET_TEXT_4_SPEED='500'
LCD_WIDGET_TEXT_4_UPDATE='500'

LCD_WIDGET_TEXT_5_NAME='CPU'
LCD_WIDGET_TEXT_5_ACTIVE='yes'
LCD_WIDGET_TEXT_5_PREFIX='CPU '
LCD_WIDGET_TEXT_5_EXP="uname('machine')"
LCD_WIDGET_TEXT_5_POSTFIX=''
LCD_WIDGET_TEXT_5_WIDTH='9'
LCD_WIDGET_TEXT_5_PRECISION='0'
LCD_WIDGET_TEXT_5_ALIGN='Left'
#    style test::onoff(7)>0?'bold':'norm'
LCD_WIDGET_TEXT_5_SPEED='100'
LCD_WIDGET_TEXT_5_UPDATE='500'

LCD_WIDGET_TEXT_6_NAME='CPUinfo'
LCD_WIDGET_TEXT_6_ACTIVE='yes'
LCD_WIDGET_TEXT_6_PREFIX=''
LCD_WIDGET_TEXT_6_EXP="cpuinfo('model name')"
LCD_WIDGET_TEXT_6_POSTFIX=''
LCD_WIDGET_TEXT_6_WIDTH='20'
LCD_WIDGET_TEXT_6_PRECISION='0'
LCD_WIDGET_TEXT_6_ALIGN='Marquee'
LCD_WIDGET_TEXT_6_SPEED='100'
LCD_WIDGET_TEXT_6_UPDATE='500'

LCD_WIDGET_TEXT_7_NAME='Busy'
LCD_WIDGET_TEXT_7_ACTIVE='yes'
LCD_WIDGET_TEXT_7_PREFIX='Busy'
LCD_WIDGET_TEXT_7_EXP="proc_stat::cpu('busy', 500)"
LCD_WIDGET_TEXT_7_POSTFIX='%'
LCD_WIDGET_TEXT_7_WIDTH='9'
LCD_WIDGET_TEXT_7_PRECISION='1'
LCD_WIDGET_TEXT_7_ALIGN='Right'
LCD_WIDGET_TEXT_7_SPEED='100'
LCD_WIDGET_TEXT_7_UPDATE='500'

LCD_WIDGET_TEXT_8_NAME='Disk'
LCD_WIDGET_TEXT_8_ACTIVE='yes'
LCD_WIDGET_TEXT_8_PREFIX='disk'
    # disk.[rw]blk return blocks, we assume a blocksize of 512
    # to get the number in kB/s we would do blk*512/1024, which is blk/2
    # expression (proc_stat::disk('.*', 'rblk', 500)+proc_stat::disk('.*', 'wblk', 500))/2
    # with kernel 2.6, disk_io disappeared from /proc/stat but moved to /proc/diskstat
    # therefore you have to use another function called 'diskstats':
LCD_WIDGET_TEXT_8_EXP="diskstats('hd.', 'read_sectors', 500) + diskstats('hd.', 'write_sectors', 500)"
LCD_WIDGET_TEXT_8_POSTFIX=' '
LCD_WIDGET_TEXT_8_WIDTH='10'
LCD_WIDGET_TEXT_8_PRECISION='0'
LCD_WIDGET_TEXT_8_ALIGN='Right'
LCD_WIDGET_TEXT_8_SPEED='100'
LCD_WIDGET_TEXT_8_UPDATE='500'

LCD_WIDGET_TEXT_9_NAME='Eth0'
LCD_WIDGET_TEXT_9_ACTIVE='yes'
LCD_WIDGET_TEXT_9_PREFIX='eth0'
LCD_WIDGET_TEXT_9_EXP="(netdev('eth0', 'Rx_bytes', 500)+netdev('eth0', 'Tx_bytes', 500))/1024"
LCD_WIDGET_TEXT_9_POSTFIX=' '
LCD_WIDGET_TEXT_9_WIDTH='10'
LCD_WIDGET_TEXT_9_PRECISION='0'
LCD_WIDGET_TEXT_9_ALIGN='Right'
LCD_WIDGET_TEXT_9_SPEED='100'
LCD_WIDGET_TEXT_9_UPDATE='500'

LCD_WIDGET_TEXT_10_NAME='PPP'
LCD_WIDGET_TEXT_10_ACTIVE='yes'
LCD_WIDGET_TEXT_10_PREFIX='PPP'
LCD_WIDGET_TEXT_10_EXP="(ppp('Rx:0', 500)+ppp('Tx:0', 500))"
LCD_WIDGET_TEXT_10_POSTFIX=''
LCD_WIDGET_TEXT_10_WIDTH='9'
LCD_WIDGET_TEXT_10_PRECISION='0'
LCD_WIDGET_TEXT_10_ALIGN='Right'
LCD_WIDGET_TEXT_10_SPEED='100'
LCD_WIDGET_TEXT_10_UPDATE='500'

LCD_WIDGET_TEXT_11_NAME='Temp'
LCD_WIDGET_TEXT_11_ACTIVE='yes'
LCD_WIDGET_TEXT_11_PREFIX='Temp'
LCD_WIDGET_TEXT_11_EXP="i2c_sensors('temp_input3')*1.0324-67"
LCD_WIDGET_TEXT_11_POSTFIX=''
LCD_WIDGET_TEXT_11_WIDTH='9'
LCD_WIDGET_TEXT_11_PRECISION='1'
LCD_WIDGET_TEXT_11_ALIGN='Right'
LCD_WIDGET_TEXT_11_SPEED='100'
LCD_WIDGET_TEXT_11_UPDATE='500'

LCD_WIDGET_TEXT_12_NAME='MySQL1'
LCD_WIDGET_TEXT_12_ACTIVE='no'
LCD_WIDGET_TEXT_12_PREFIX='MySQL test:'
LCD_WIDGET_TEXT_12_EXP="MySQL::query('SELECT id FROM table1')"
LCD_WIDGET_TEXT_12_POSTFIX=''
LCD_WIDGET_TEXT_12_WIDTH='20'
LCD_WIDGET_TEXT_12_PRECISION='0'
LCD_WIDGET_TEXT_12_ALIGN='Right'
LCD_WIDGET_TEXT_12_SPEED='100'
LCD_WIDGET_TEXT_12_UPDATE='60000'

LCD_WIDGET_TEXT_13_NAME='MySQL2'
LCD_WIDGET_TEXT_13_ACTIVE='no'
LCD_WIDGET_TEXT_13_PREFIX='Status: '
LCD_WIDGET_TEXT_13_EXP='MySQL::status()'
LCD_WIDGET_TEXT_13_POSTFIX=''
LCD_WIDGET_TEXT_13_WIDTH='20'
LCD_WIDGET_TEXT_13_PRECISION='0'
LCD_WIDGET_TEXT_13_ALIGN='Marquee'
LCD_WIDGET_TEXT_13_SPEED='100'
LCD_WIDGET_TEXT_13_UPDATE='60000'

LCD_WIDGET_TEXT_14_NAME='Uptime'
LCD_WIDGET_TEXT_14_ACTIVE='yes'
LCD_WIDGET_TEXT_14_PREFIX='Up '
LCD_WIDGET_TEXT_14_EXP="uptime('%d days %H:%M:%S')"
LCD_WIDGET_TEXT_14_POSTFIX=''
LCD_WIDGET_TEXT_14_WIDTH='20'
LCD_WIDGET_TEXT_14_PRECISION='0'
LCD_WIDGET_TEXT_14_ALIGN='Right'
LCD_WIDGET_TEXT_14_SPEED='100'
LCD_WIDGET_TEXT_14_UPDATE='1000'

LCD_WIDGET_TEXT_15_NAME='BarTestVal'
LCD_WIDGET_TEXT_15_ACTIVE='no'
LCD_WIDGET_TEXT_15_PREFIX='Test '
LCD_WIDGET_TEXT_15_EXP='test::bar(0,100,50,0)'
LCD_WIDGET_TEXT_15_POSTFIX=''
LCD_WIDGET_TEXT_15_WIDTH='9'
LCD_WIDGET_TEXT_15_PRECISION='0'
LCD_WIDGET_TEXT_15_ALIGN='Left'
LCD_WIDGET_TEXT_15_SPEED='100'
LCD_WIDGET_TEXT_15_UPDATE='200'

LCD_WIDGET_TEXT_16_NAME='Test'
LCD_WIDGET_TEXT_16_ACTIVE='no'
LCD_WIDGET_TEXT_16_PREFIX=''
LCD_WIDGET_TEXT_16_EXP='1234567890123456789012345678901234567890'
LCD_WIDGET_TEXT_16_POSTFIX=''
LCD_WIDGET_TEXT_16_WIDTH='40'
LCD_WIDGET_TEXT_16_PRECISION='0'
LCD_WIDGET_TEXT_16_ALIGN='Left'
LCD_WIDGET_TEXT_16_SPEED='100'
LCD_WIDGET_TEXT_16_UPDATE='500'
#    foreground 'ff0000ff'

LCD_WIDGET_TEXT_17_NAME='Test1'
LCD_WIDGET_TEXT_17_ACTIVE='no'
LCD_WIDGET_TEXT_17_PREFIX=''
LCD_WIDGET_TEXT_17_EXP='ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
LCD_WIDGET_TEXT_17_POSTFIX=''
LCD_WIDGET_TEXT_17_WIDTH='40'
LCD_WIDGET_TEXT_17_PRECISION='0'
LCD_WIDGET_TEXT_17_ALIGN='Marquee'
LCD_WIDGET_TEXT_17_SPEED='100'
LCD_WIDGET_TEXT_17_UPDATE='500'

LCD_WIDGET_TEXT_18_NAME='Test2'
LCD_WIDGET_TEXT_18_ACTIVE='no'
LCD_WIDGET_TEXT_18_PREFIX=''
LCD_WIDGET_TEXT_18_EXP='1234567890abcdefghijklmnopqrstuvwxyz'
LCD_WIDGET_TEXT_18_POSTFIX=''
LCD_WIDGET_TEXT_18_WIDTH='40'
LCD_WIDGET_TEXT_18_PRECISION='0'
LCD_WIDGET_TEXT_18_ALIGN='Marquee'
LCD_WIDGET_TEXT_18_SPEED='150'
LCD_WIDGET_TEXT_18_UPDATE='500'

LCD_WIDGET_TEXT_19_NAME='GPO_Val1'
LCD_WIDGET_TEXT_19_ACTIVE='no'
LCD_WIDGET_TEXT_19_PREFIX='GPO#1'
LCD_WIDGET_TEXT_19_EXP='LCD::GPO(1)'
LCD_WIDGET_TEXT_19_POSTFIX=''
LCD_WIDGET_TEXT_19_WIDTH='10'
LCD_WIDGET_TEXT_19_PRECISION='0'
LCD_WIDGET_TEXT_19_ALIGN='Right'
LCD_WIDGET_TEXT_19_SPEED='150'
LCD_WIDGET_TEXT_19_UPDATE='500'

LCD_WIDGET_TEXT_20_NAME='GPI_Val1'
LCD_WIDGET_TEXT_20_ACTIVE='no'
LCD_WIDGET_TEXT_20_PREFIX='GPI#1'
LCD_WIDGET_TEXT_20_EXP='LCD::GPI(1)'
LCD_WIDGET_TEXT_20_POSTFIX=''
LCD_WIDGET_TEXT_20_WIDTH='10'
LCD_WIDGET_TEXT_20_PRECISION='0'
LCD_WIDGET_TEXT_20_ALIGN='Right'
LCD_WIDGET_TEXT_20_SPEED='150'
LCD_WIDGET_TEXT_20_UPDATE='500'

LCD_WIDGET_TEXT_21_NAME='GPO_Val4'
LCD_WIDGET_TEXT_21_ACTIVE='no'
LCD_WIDGET_TEXT_21_PREFIX='GPO#4'
LCD_WIDGET_TEXT_21_EXP='LCD::GPO(4)'
LCD_WIDGET_TEXT_21_POSTFIX=''
LCD_WIDGET_TEXT_21_WIDTH='10'
LCD_WIDGET_TEXT_21_PRECISION='0'
LCD_WIDGET_TEXT_21_ALIGN='Right'
LCD_WIDGET_TEXT_21_SPEED='150'
LCD_WIDGET_TEXT_21_UPDATE='500'

LCD_WIDGET_TEXT_22_NAME='KVV'
LCD_WIDGET_TEXT_22_ACTIVE='no'
LCD_WIDGET_TEXT_22_PREFIX=''
LCD_WIDGET_TEXT_22_EXP="kvv::line(0).' '.kvv::station(0)"
LCD_WIDGET_TEXT_22_POSTFIX=''
LCD_WIDGET_TEXT_22_WIDTH='11'
LCD_WIDGET_TEXT_22_PRECISION='0'
LCD_WIDGET_TEXT_22_ALIGN='Left'
LCD_WIDGET_TEXT_22_SPEED='150'
LCD_WIDGET_TEXT_22_UPDATE='500'
#    Foreground 'ffff00'
#    style 'bold'

LCD_WIDGET_TEXT_23_NAME='KVV_TIME'
LCD_WIDGET_TEXT_23_ACTIVE='no'
LCD_WIDGET_TEXT_23_PREFIX=''
LCD_WIDGET_TEXT_23_EXP='kvv::time_str(0)'
LCD_WIDGET_TEXT_23_POSTFIX=''
LCD_WIDGET_TEXT_23_WIDTH='2'
LCD_WIDGET_TEXT_23_PRECISION='0'
LCD_WIDGET_TEXT_23_ALIGN='Right'
LCD_WIDGET_TEXT_23_SPEED='150'
LCD_WIDGET_TEXT_23_UPDATE='500'
#    foreground kvv::time(0) < 2 ? 'FF0000' : ( kvv::time(0) < 5 ? 'FFFF00' : '00FF00' )
#    style 'bold'



# Bar widgets
LCD_WIDGET_BAR_N=5
LCD_WIDGET_BAR_1_NAME='BusyBar'
LCD_WIDGET_BAR_1_ACTIVE='yes'
LCD_WIDGET_BAR_1_EXP="proc_stat::cpu('busy', 500)"
LCD_WIDGET_BAR_1_EXP2="proc_stat::cpu('system', 500)"
LCD_WIDGET_BAR_1_LENGTH='10'
LCD_WIDGET_BAR_1_MIN='0'
LCD_WIDGET_BAR_1_MAX='1'
LCD_WIDGET_BAR_1_DIRECTION='East'
LCD_WIDGET_BAR_1_UPDATE='200'
LCD_WIDGET_BAR_1_STYLE=''

LCD_WIDGET_BAR_2_NAME='LoadBar'
LCD_WIDGET_BAR_2_ACTIVE='yes'
LCD_WIDGET_BAR_2_EXP='loadavg(1)'
LCD_WIDGET_BAR_2_EXP2=''
LCD_WIDGET_BAR_2_LENGTH='10'
LCD_WIDGET_BAR_2_MIN='0'
LCD_WIDGET_BAR_2_MAX='2'
LCD_WIDGET_BAR_2_DIRECTION='East'
LCD_WIDGET_BAR_2_UPDATE='200'
LCD_WIDGET_BAR_2_STYLE=''

LCD_WIDGET_BAR_3_NAME='DiskBar'
LCD_WIDGET_BAR_3_ACTIVE='yes'
    #expression  proc_stat::disk('.*', 'rblk', 500)
    #expression2 proc_stat::disk('.*', 'wblk', 500)
    # for kernel 2.6:
LCD_WIDGET_BAR_3_EXP="diskstats('hd.', 'read_sectors',  500)"
LCD_WIDGET_BAR_3_EXP2="diskstats('hd.', 'write_sectors', 500)"
LCD_WIDGET_BAR_3_LENGTH='14'
LCD_WIDGET_BAR_3_MIN='0'
LCD_WIDGET_BAR_3_MAX='1'
LCD_WIDGET_BAR_3_DIRECTION='East'
LCD_WIDGET_BAR_3_UPDATE='200'
LCD_WIDGET_BAR_3_STYLE=''

LCD_WIDGET_BAR_4_NAME='Eth0Bar'
LCD_WIDGET_BAR_4_ACTIVE='yes'
LCD_WIDGET_BAR_4_EXP="netdev('eth0', 'Rx_bytes', 500)"
LCD_WIDGET_BAR_4_EXP2="netdev('eth0', 'Tx_bytes', 500)"
LCD_WIDGET_BAR_4_LENGTH='14'
LCD_WIDGET_BAR_4_MIN='0'
LCD_WIDGET_BAR_4_MAX='1'
LCD_WIDGET_BAR_4_DIRECTION='East'
LCD_WIDGET_BAR_4_UPDATE='200'
LCD_WIDGET_BAR_4_STYLE=''

LCD_WIDGET_BAR_5_NAME='TempBar'
LCD_WIDGET_BAR_5_ACTIVE='yes'
LCD_WIDGET_BAR_5_EXP="i2c_sensors('temp_input3')*1.0324-67"
LCD_WIDGET_BAR_5_EXP2=''
LCD_WIDGET_BAR_5_LENGTH='10'
LCD_WIDGET_BAR_5_MIN='40'
LCD_WIDGET_BAR_5_MAX='80'
LCD_WIDGET_BAR_5_DIRECTION='East'
LCD_WIDGET_BAR_5_UPDATE='200'
LCD_WIDGET_BAR_5_STYLE=''



# Icon widgets
LCD_WIDGET_ICON_N=13
LCD_WIDGET_ICON_1_NAME='Heart'
LCD_WIDGET_ICON_1_ACTIVE='yes'
LCD_WIDGET_ICON_1_ROW1='.....'
LCD_WIDGET_ICON_1_ROW2='.*.*.'
LCD_WIDGET_ICON_1_ROW3='*****'
LCD_WIDGET_ICON_1_ROW4='*****'
LCD_WIDGET_ICON_1_ROW5='.***.'
LCD_WIDGET_ICON_1_ROW6='.***.'
LCD_WIDGET_ICON_1_ROW7='..*..'
LCD_WIDGET_ICON_1_ROW8='.....'
LCD_WIDGET_ICON_1_VISIBLE=''
LCD_WIDGET_ICON_1_SPEED='500'

LCD_WIDGET_ICON_2_NAME='Heartbeat1'
LCD_WIDGET_ICON_2_ACTIVE='yes'
LCD_WIDGET_ICON_2_ROW1='.....|.....'
LCD_WIDGET_ICON_2_ROW2='.*.*.|.*.*.'
LCD_WIDGET_ICON_2_ROW3='*****|*.*.*'
LCD_WIDGET_ICON_2_ROW4='*****|*...*'
LCD_WIDGET_ICON_2_ROW5='.***.|.*.*.'
LCD_WIDGET_ICON_2_ROW6='.***.|.*.*.'
LCD_WIDGET_ICON_2_ROW7='..*..|..*..'
LCD_WIDGET_ICON_2_ROW8='.....|.....'
LCD_WIDGET_ICON_2_VISIBLE=''
LCD_WIDGET_ICON_2_SPEED='800'

LCD_WIDGET_ICON_3_NAME='Heartbeat2'
LCD_WIDGET_ICON_3_ACTIVE='yes'
LCD_WIDGET_ICON_3_ROW1='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_3_ROW2='.*.*.|.....|.*.*.|.....|.....|.....'
LCD_WIDGET_ICON_3_ROW3='*****|.*.*.|*****|.*.*.|.*.*.|.*.*.'
LCD_WIDGET_ICON_3_ROW4='*****|.***.|*****|.***.|.***.|.***.'
LCD_WIDGET_ICON_3_ROW5='.***.|.***.|.***.|.***.|.***.|.***.'
LCD_WIDGET_ICON_3_ROW6='.***.|..*..|.***.|..*..|..*..|..*..'
LCD_WIDGET_ICON_3_ROW7='..*..|.....|..*..|.....|.....|.....'
LCD_WIDGET_ICON_3_ROW8='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_3_VISIBLE=''
LCD_WIDGET_ICON_3_SPEED='250'

LCD_WIDGET_ICON_4_NAME='LightningTest'
LCD_WIDGET_ICON_4_ACTIVE='yes'
LCD_WIDGET_ICON_4_ROW1='...***'
LCD_WIDGET_ICON_4_ROW2='..***.'
LCD_WIDGET_ICON_4_ROW3='.***..'
LCD_WIDGET_ICON_4_ROW4='.****.'
LCD_WIDGET_ICON_4_ROW5='..**..'
LCD_WIDGET_ICON_4_ROW6='.**...'
LCD_WIDGET_ICON_4_ROW7='**....'
LCD_WIDGET_ICON_4_ROW8='*.....'
LCD_WIDGET_ICON_4_VISIBLE='test::onoff(0)'
LCD_WIDGET_ICON_4_SPEED='500'


LCD_WIDGET_ICON_5_NAME='EKG'
LCD_WIDGET_ICON_5_ACTIVE='yes'
LCD_WIDGET_ICON_5_ROW1='.....|.....|.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_5_ROW2='.....|....*|...*.|..*..|.*...|*....|.....|.....'
LCD_WIDGET_ICON_5_ROW3='.....|....*|...*.|..*..|.*...|*....|.....|.....'
LCD_WIDGET_ICON_5_ROW4='.....|....*|...**|..**.|.**..|**...|*....|.....'
LCD_WIDGET_ICON_5_ROW5='.....|....*|...**|..**.|.**..|**...|*....|.....'
LCD_WIDGET_ICON_5_ROW6='.....|....*|...*.|..*.*|.*.*.|*.*..|.*...|*....'
LCD_WIDGET_ICON_5_ROW7='*****|*****|****.|***..|**..*|*..**|..***|.****'
LCD_WIDGET_ICON_5_ROW8='.....|.....|.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_5_VISIBLE=''
LCD_WIDGET_ICON_5_SPEED='250'

LCD_WIDGET_ICON_6_NAME='Karo'
LCD_WIDGET_ICON_6_ACTIVE='yes'
LCD_WIDGET_ICON_6_ROW1='.....|.....|.....|.....|..*..|.....|.....|.....'
LCD_WIDGET_ICON_6_ROW2='.....|.....|.....|..*..|.*.*.|..*..|.....|.....'
LCD_WIDGET_ICON_6_ROW3='.....|.....|..*..|.*.*.|*...*|.*.*.|..*..|.....'
LCD_WIDGET_ICON_6_ROW4='.....|..*..|.*.*.|*...*|.....|*...*|.*.*.|..*..'
LCD_WIDGET_ICON_6_ROW5='.....|.....|..*..|.*.*.|*...*|.*.*.|..*..|.....'
LCD_WIDGET_ICON_6_ROW6='.....|.....|.....|..*..|.*.*.|..*..|.....|.....'
LCD_WIDGET_ICON_6_ROW7='.....|.....|.....|.....|..*..|.....|.....|.....'
LCD_WIDGET_ICON_6_ROW8='.....|.....|.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_6_VISIBLE=''
LCD_WIDGET_ICON_6_SPEED='200'

LCD_WIDGET_ICON_7_NAME='Arrows'
LCD_WIDGET_ICON_7_ACTIVE='yes'
LCD_WIDGET_ICON_7_ROW1='..*..'
LCD_WIDGET_ICON_7_ROW2='.*...'
LCD_WIDGET_ICON_7_ROW3='*****'
LCD_WIDGET_ICON_7_ROW4='.**..'
LCD_WIDGET_ICON_7_ROW5='..**.'
LCD_WIDGET_ICON_7_ROW6='*****'
LCD_WIDGET_ICON_7_ROW7='...*.'
LCD_WIDGET_ICON_7_ROW8='..*..'
LCD_WIDGET_ICON_7_VISIBLE=''
LCD_WIDGET_ICON_7_SPEED='500'

LCD_WIDGET_ICON_8_NAME='Blob'
LCD_WIDGET_ICON_8_ACTIVE='yes'
LCD_WIDGET_ICON_8_ROW1='.....|.....|.....'
LCD_WIDGET_ICON_8_ROW2='.....|.....|.***.'
LCD_WIDGET_ICON_8_ROW3='.....|.***.|*...*'
LCD_WIDGET_ICON_8_ROW4='..*..|.*.*.|*...*'
LCD_WIDGET_ICON_8_ROW5='.....|.***.|*...*'
LCD_WIDGET_ICON_8_ROW6='.....|.....|.***.'
LCD_WIDGET_ICON_8_ROW7='.....|.....|.....'
LCD_WIDGET_ICON_8_ROW8='.....|.....|.....'
LCD_WIDGET_ICON_8_VISIBLE=''
LCD_WIDGET_ICON_8_SPEED='250'

LCD_WIDGET_ICON_9_NAME='Wave'
LCD_WIDGET_ICON_9_ACTIVE='yes'
LCD_WIDGET_ICON_9_ROW1='..**.|.**..|**...|*....|.....|.....|.....|.....|....*|...**'
LCD_WIDGET_ICON_9_ROW2='.*..*|*..*.|..*..|.*...|*....|.....|.....|....*|...*.|..*..'
LCD_WIDGET_ICON_9_ROW3='*....|....*|...*.|..*..|.*...|*....|....*|...*.|..*..|.*...'
LCD_WIDGET_ICON_9_ROW4='*....|....*|...*.|..*..|.*...|*....|....*|...*.|..*..|.*...'
LCD_WIDGET_ICON_9_ROW5='*....|....*|...*.|..*..|.*...|*....|....*|...*.|..*..|.*...'
LCD_WIDGET_ICON_9_ROW6='.....|.....|....*|...*.|..*..|.*..*|*..*.|..*..|.*...|*....'
LCD_WIDGET_ICON_9_ROW7='.....|.....|.....|....*|...**|..**.|.**..|**...|*....|.....'
LCD_WIDGET_ICON_9_ROW8='.....|.....|.....|.....|.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_9_VISIBLE=''
LCD_WIDGET_ICON_9_SPEED='250'

LCD_WIDGET_ICON_10_NAME='Squirrel'
LCD_WIDGET_ICON_10_ACTIVE='yes'
LCD_WIDGET_ICON_10_ROW1='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_10_ROW2='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_10_ROW3='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_10_ROW4='**...|.**..|..**.|...**|....*|.....'
LCD_WIDGET_ICON_10_ROW5='*****|*****|*****|*****|*****|*****'
LCD_WIDGET_ICON_10_ROW6='...**|..**.|.**..|**...|*....|.....'
LCD_WIDGET_ICON_10_ROW7='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_10_ROW8='.....|.....|.....|.....|.....|.....'
LCD_WIDGET_ICON_10_VISIBLE=''
LCD_WIDGET_ICON_10_SPEED='250'

LCD_WIDGET_ICON_11_NAME='Lightning'
LCD_WIDGET_ICON_11_ACTIVE='yes'
LCD_WIDGET_ICON_11_ROW1='...***'
LCD_WIDGET_ICON_11_ROW2='..***.'
LCD_WIDGET_ICON_11_ROW3='.***..'
LCD_WIDGET_ICON_11_ROW4='.****.'
LCD_WIDGET_ICON_11_ROW5='..**..'
LCD_WIDGET_ICON_11_ROW6='.**...'
LCD_WIDGET_ICON_11_ROW7='**....'
LCD_WIDGET_ICON_11_ROW8='*.....'
LCD_WIDGET_ICON_11_VISIBLE="cpu('busy', 500)-50"
LCD_WIDGET_ICON_11_SPEED='100'

LCD_WIDGET_ICON_12_NAME='Rain'
LCD_WIDGET_ICON_12_ACTIVE='yes'
LCD_WIDGET_ICON_12_ROW1='...*.|.....|.....|.*...|....*|..*..|.....|*....'
LCD_WIDGET_ICON_12_ROW2='*....|...*.|.....|.....|.*...|....*|..*..|.....'
LCD_WIDGET_ICON_12_ROW3='.....|*....|...*.|.....|.....|.*...|....*|..*..'
LCD_WIDGET_ICON_12_ROW4='..*..|.....|*....|...*.|.....|.....|.*...|....*'
LCD_WIDGET_ICON_12_ROW5='....*|..*..|.....|*....|...*.|.....|.....|.*...'
LCD_WIDGET_ICON_12_ROW6='.*...|....*|..*..|.....|*....|...*.|.....|.....'
LCD_WIDGET_ICON_12_ROW7='.....|.*...|....*|..*..|.....|*....|...*.|.....'
LCD_WIDGET_ICON_12_ROW8='.....|.....|.*...|....*|..*..|.....|*....|...*.'
LCD_WIDGET_ICON_12_VISIBLE=''
LCD_WIDGET_ICON_12_SPEED='200'

LCD_WIDGET_ICON_13_NAME='Timer'
LCD_WIDGET_ICON_13_ACTIVE='yes'
LCD_WIDGET_ICON_13_ROW1='.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|'
LCD_WIDGET_ICON_13_ROW2='.***.|.*+*.|.*++.|.*++.|.*++.|.*++.|.*++.|.*++.|.*++.|.*++.|.*++.|.*++.|.+++.|.+*+.|.+**.|.+**.|.+**.|.+**.|.+**.|.+**.|.+**.|.+**.|.+**.|.+**.|'
LCD_WIDGET_ICON_13_ROW3='*****|**+**|**++*|**+++|**++.|**++.|**+++|**+++|**+++|**+++|**+++|+++++|+++++|++*++|++**+|++***|++**.|++**.|++***|++***|++***|++***|++***|*****|'
LCD_WIDGET_ICON_13_ROW4='*****|**+**|**+**|**+**|**+++|**+++|**+++|**+++|**+++|**+++|+++++|+++++|+++++|++*++|++*++|++*++|++***|++***|++***|++***|++***|++***|*****|*****|'
LCD_WIDGET_ICON_13_ROW5='*****|*****|*****|*****|*****|***++|***++|**+++|*++++|+++++|+++++|+++++|+++++|+++++|+++++|+++++|+++++|+++**|+++**|++***|+****|*****|*****|*****|'
LCD_WIDGET_ICON_13_ROW6='.***.|.***.|.***.|.***.|.***.|.***.|.**+.|.*++.|.+++.|.+++.|.+++.|.+++.|.+++.|.+++.|.+++.|.+++.|.+++.|.+++.|.++*.|.+**.|.***.|.***.|.***.|.***.|'
LCD_WIDGET_ICON_13_ROW7='.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|'
LCD_WIDGET_ICON_13_ROW8='.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|.....|'
LCD_WIDGET_ICON_13_VISIBLE=''
LCD_WIDGET_ICON_13_SPEED='100'




# ----------------------------------------------------------------------------
# Read configurations and update variables
# ----------------------------------------------------------------------------
updateVariables()
{
    # ---------------------------------------
    # Read values out of widget configuration
    if [ -f /etc/config.d/$packageName ]
    then
        . /etc/config.d/$packageName

        local align=''
        local direction=''
        local name=''
        local active=''

        if [ -n "$LCD_WIDGET_TEXT_N" ]
        then
            # -----------------
            # Convert alignment
            idx=1
            while [ "$idx" -le "$LCD_WIDGET_TEXT_N" ]
            do
                eval align='${LCD_WIDGET_TEXT_'${idx}'_ALIGN}'
                case $align in
                    'L')
                        eval LCD_WIDGET_TEXT_${idx}_ALIGN='Left'
                        modifiedSomething=true
                        ;;
                    'C')
                        eval LCD_WIDGET_TEXT_${idx}_ALIGN='Center'
                        modifiedSomething=true
                        ;;
                    'R')
                        eval LCD_WIDGET_TEXT_${idx}_ALIGN='Right'
                        modifiedSomething=true
                        ;;
                    'M')
                        eval LCD_WIDGET_TEXT_${idx}_ALIGN='Marquee'
                        modifiedSomething=true
                        ;;
                    * )
                        ;;
                esac

                eval name='${LCD_WIDGET_TEXT_'${idx}'_NAME}'
                eval active='${LCD_WIDGET_TEXT_'${idx}'_ACTIVE}'

                if [ -z "$name" ]
                then
                    eval LCD_WIDGET_TEXT_${idx}_NAME='textwidget'$idx
                    modifiedSomething=true
                fi
                if [ -z "$active" ]
                then
                    eval LCD_WIDGET_TEXT_${idx}_ACTIVE='no'
                    modifiedSomething=true
                fi

                idx=$((idx+1))
            done
        fi

        if [ -n "$LCD_WIDGET_BAR_N" ]
        then
            # -----------------
            # Convert direction
            idx=1
            while [ "$idx" -le "$LCD_WIDGET_BAR_N" ]
            do
                eval direction='${LCD_WIDGET_BAR_'${idx}'_DIRECTION}'
                case $direction in
                    'N')
                        eval LCD_WIDGET_BAR_${idx}_DIRECTION='North'
                        modifiedSomething=true
                        ;;
                    'E')
                        eval LCD_WIDGET_BAR_${idx}_DIRECTION='East'
                        modifiedSomething=true
                        ;;
                    'S')
                        eval LCD_WIDGET_BAR_${idx}_DIRECTION='South'
                        modifiedSomething=true
                        ;;
                    'W')
                        eval LCD_WIDGET_BAR_${idx}_DIRECTION='West'
                        modifiedSomething=true
                        ;;
                    * )
                        ;;
                esac

                eval name='${LCD_WIDGET_BAR_'${idx}'_NAME}'
                eval active='${LCD_WIDGET_BAR_'${idx}'_ACTIVE}'

                if [ -z "$name" ]
                then
                    eval LCD_WIDGET_BAR_${idx}_NAME='barwidget'$idx
                    modifiedSomething=true
                fi
                if [ -z "$active" ]
                then
                    eval LCD_WIDGET_BAR_${idx}_ACTIVE='no'
                    modifiedSomething=true
                fi

                idx=$((idx+1))
            done
        fi

        if [ -n "$LCD_WIDGET_ICON_N" ]
        then
            # ----------------------------------------------
            # Add name and activation state for icon widgets
            # and convert config parameter name
            idx=1
            while [ "$idx" -le "$LCD_WIDGET_ICON_N" ]
            do
                # Fix wrong config value names
                eval row1='${LCD_WIDGET_ICON_'${idx}'_ROW_1}'
                eval row2='${LCD_WIDGET_ICON_'${idx}'_ROW_2}'
                eval row3='${LCD_WIDGET_ICON_'${idx}'_ROW_3}'
                eval row4='${LCD_WIDGET_ICON_'${idx}'_ROW_4}'
                eval row5='${LCD_WIDGET_ICON_'${idx}'_ROW_5}'
                eval row6='${LCD_WIDGET_ICON_'${idx}'_ROW_6}'
                eval row7='${LCD_WIDGET_ICON_'${idx}'_ROW_7}'
                eval row8='${LCD_WIDGET_ICON_'${idx}'_ROW_8}'
                eval name='${LCD_WIDGET_ICON_'${idx}'_NAME}'
                eval active='${LCD_WIDGET_ICON_'${idx}'_ACTIVE}'

                # Possible pipe symbol must be escaped
                row1=${row1/\|/\\|}
                row2=${row2/\|/\\|}
                row3=${row3/\|/\\|}
                row4=${row4/\|/\\|}
                row5=${row5/\|/\\|}
                row6=${row6/\|/\\|}
                row7=${row7/\|/\\|}
                row8=${row8/\|/\\|}

                if [ -n "$row1" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW1="$row1"
                    modifiedSomething=true
                fi
                if [ -n "$row2" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW2="$row2"
                    modifiedSomething=true
                fi
                if [ -n "$row3" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW3="$row3"
                    modifiedSomething=true
                fi
                if [ -n "$row4" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW4="$row4"
                    modifiedSomething=true
                fi
                if [ -n "$row5" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW5="$row5"
                    modifiedSomething=true
                fi
                if [ -n "$row6" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW6="$row6"
                    modifiedSomething=true
                fi
                if [ -n "$row7" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW7="$row7"
                    modifiedSomething=true
                fi
                if [ -n "$row8" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ROW8="$row8"
                    modifiedSomething=true
                fi
                if [ -z "$name" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_NAME='iconwidget'${idx}
                    modifiedSomething=true
                fi
                if [ -z "$active" ]
                then
                    eval LCD_WIDGET_ICON_${idx}_ACTIVE='no'
                    modifiedSomething=true
                fi

                idx=$((idx+1))
            done
        fi
    fi
}



# ----------------------------------------------------------------------------
# Write config and default files
# ----------------------------------------------------------------------------
makeConfigFile()
{
    internal_conf_file=${1}
    {
    # ----------------------------------------------------------------------------
    printgpl -conf $packageName '2010-10-03' 'Yves Schumann'
    # ----------------------------------------------------------------------------

    # ----------------------------------------------------------------------------
    printgroup 'Widget configuration'
    # ----------------------------------------------------------------------------
    printvar 'START_LCD_WIDGET'                      'Use: yes or no'

    # ----------------------------------------------------------------------------
    printgroup 'Text Widgets'
    # ----------------------------------------------------------------------------
    printvar 'LCD_WIDGET_TEXT_N'                     'Number of text elements'
    idx=1
    while [ $idx -le $LCD_WIDGET_TEXT_N ]
    do
        printvar 'LCD_WIDGET_TEXT_'$idx'_NAME'       'Name of this widget'
        printvar 'LCD_WIDGET_TEXT_'$idx'_ACTIVE'     'Is widget active or not'
	    printvar 'LCD_WIDGET_TEXT_'$idx'_PREFIX'     'The result of these expressions will be displayd before the actual value'
        printvar 'LCD_WIDGET_TEXT_'$idx'_EXP'        'This expression will be evaluated and its result will be displayed'
	    printvar 'LCD_WIDGET_TEXT_'$idx'_POSTFIX'    'The result of these expressions will be displayd after the actual value'
        printvar 'LCD_WIDGET_TEXT_'$idx'_WIDTH'      'Length of the whole widget (including prefix and postfix!)'
	    printvar 'LCD_WIDGET_TEXT_'$idx'_PRECISION'  '(maximum) number of decimal places'
        printvar 'LCD_WIDGET_TEXT_'$idx'_ALIGN'      'Left (default), Center, Right or Marquee'
        printvar 'LCD_WIDGET_TEXT_'$idx'_SPEED'      'Marquee scroller interval (msec), default 500msec'
        printvar 'LCD_WIDGET_TEXT_'$idx'_UPDATE'     'Update interval (msec), default 500msec'
        idx=$((idx+1))
    done
  	} > ${internal_conf_file}
    mecho -info -n '.'
	{
    # ----------------------------------------------------------------------------
    printgroup 'Bar Widgets'
    # ----------------------------------------------------------------------------
    printvar 'LCD_WIDGET_BAR_N'                      'Number of bar elements'
    idx=1
    while [ $idx -le $LCD_WIDGET_BAR_N ]
    do
        printvar 'LCD_WIDGET_BAR_'$idx'_NAME'        'Name of this widget'
        printvar 'LCD_WIDGET_BAR_'$idx'_ACTIVE'      'Is widget active or not'
        printvar 'LCD_WIDGET_BAR_'$idx'_EXP'         'its result is used for the length of the (upper half) bar'
	    printvar 'LCD_WIDGET_BAR_'$idx'_EXP2'        'its result is used for the length of the lower half bar'
        printvar 'LCD_WIDGET_BAR_'$idx'_LENGTH'      'size of the whole bar widget'
	    printvar 'LCD_WIDGET_BAR_'$idx'_MIN'         'scale: value where the bar starts'
	    printvar 'LCD_WIDGET_BAR_'$idx'_MAX'         'scale: value where the bar ends'
        printvar 'LCD_WIDGET_BAR_'$idx'_DIRECTION'   "'East' (left to right, default),"
        printvar ''                                  "'West' (right to left),"
        printvar ''                                  "'North' (bottom up) or"
        printvar ''                                  "'South' (top down)"
	    printvar 'LCD_WIDGET_BAR_'$idx'_UPDATE'     'Update interval (msec), default 500msec'
	    printvar 'LCD_WIDGET_BAR_'$idx'_STYLE'       "'H' (hollow: with a frame) default: none"
        idx=$((idx+1))
    done
	} >> ${internal_conf_file}
    mecho -info -n '.'
	{
    # ----------------------------------------------------------------------------
    printgroup 'Icon Widgets'
    # ----------------------------------------------------------------------------
    printvar 'LCD_WIDGET_ICON_N'                    'Number if icons'
    idx=1
    while [ $idx -le $LCD_WIDGET_ICON_N ]
    do
        printvar 'LCD_WIDGET_ICON_'$idx'_NAME'      'Name of this widget'
        printvar 'LCD_WIDGET_ICON_'$idx'_ACTIVE'    'Is widget active or not'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW1'      '1st row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW2'      '2nd row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW3'      '3rd row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW4'      '4th row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW5'      '5th row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW6'      '6th row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW7'      '7th row'
        printvar 'LCD_WIDGET_ICON_'$idx'_ROW8'      '8th row'
	    printvar 'LCD_WIDGET_ICON_'$idx'_VISIBLE'   'expression controlling the visibility (for blinking effects)'
	    printvar 'LCD_WIDGET_ICON_'$idx'_SPEED'     'Update speed'
        idx=$((idx+1))
    done

    # ----------------------------------------------------------------------------
    printend
    # ----------------------------------------------------------------------------
    } >> ${internal_conf_file}

    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Create the check.d file
# ----------------------------------------------------------------------------
makeCheckFile()
{
    printgpl -check ${packageName} '2010-10-03' 'Yves Schumann' >/etc/check.d/${packageName}
    cat >> /etc/check.d/${packageName} <<EOFG
# Variable                      OPT_VARIABLE               VARIABLE_N              VALUE
START_LCD_WIDGET                -                          -                       YESNO

LCD_WIDGET_TEXT_N               START_LCD_WIDGET           -                       NUMERIC
LCD_WIDGET_TEXT_%_NAME          START_LCD_WIDGET           LCD_WIDGET_TEXT_N       NOTEMPTY
LCD_WIDGET_TEXT_%_ACTIVE        START_LCD_WIDGET           LCD_WIDGET_TEXT_N       YESNO
LCD_WIDGET_TEXT_%_PREFIX        LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       NONE
LCD_WIDGET_TEXT_%_EXP           LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       NOTEMPTY
LCD_WIDGET_TEXT_%_POSTFIX       LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       NONE
LCD_WIDGET_TEXT_%_WIDTH         LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       NUMERIC
LCD_WIDGET_TEXT_%_ALIGN         LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       LCD_ALIGN_CUI
LCD_WIDGET_TEXT_%_PRECISION     LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       ENUMERIC
LCD_WIDGET_TEXT_%_SPEED         LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       ENUMERIC
LCD_WIDGET_TEXT_%_UPDATE        LCD_WIDGET_TEXT_%_ACTIVE   LCD_WIDGET_TEXT_N       ENUMERIC

LCD_WIDGET_BAR_N                START_LCD_WIDGET           -                       NUMERIC
LCD_WIDGET_BAR_%_NAME           START_LCD_WIDGET           LCD_WIDGET_BAR_N        NOTEMPTY
LCD_WIDGET_BAR_%_ACTIVE         START_LCD_WIDGET           LCD_WIDGET_BAR_N        YESNO
LCD_WIDGET_BAR_%_EXP            LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        NOTEMPTY
LCD_WIDGET_BAR_%_EXP2           LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        NONE
LCD_WIDGET_BAR_%_LENGTH         LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        NUMERIC
LCD_WIDGET_BAR_%_MIN            LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        ENUMERIC
LCD_WIDGET_BAR_%_MAX            LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        ENUMERIC
LCD_WIDGET_BAR_%_DIRECTION      LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        LCD_DIRECTION_CUI
LCD_WIDGET_BAR_%_STYLE          LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        LCD_STYLE_CUI
LCD_WIDGET_BAR_%_UPDATE         LCD_WIDGET_BAR_%_ACTIVE    LCD_WIDGET_BAR_N        ENUMERIC

LCD_WIDGET_ICON_N               START_LCD_WIDGET           -                       NUMERIC
LCD_WIDGET_ICON_%_NAME          START_LCD_WIDGET           LCD_WIDGET_ICON_N       NOTEMPTY
LCD_WIDGET_ICON_%_ACTIVE        START_LCD_WIDGET           LCD_WIDGET_ICON_N       YESNO
LCD_WIDGET_ICON_%_ROW1          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW2          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW3          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW4          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW5          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW6          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW7          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_ROW8          LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       LCDICON
LCD_WIDGET_ICON_%_VISIBLE       LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       NONE
LCD_WIDGET_ICON_%_SPEED         LCD_WIDGET_ICON_%_ACTIVE   LCD_WIDGET_ICON_N       ENUMERIC

EOFG

    # Set rights for check.d file
    chmod 0600 /etc/check.d/${packageName}
    chown root /etc/check.d/${packageName}

    printgpl -check_exp ${packageName} '2010-10-03' 'Yves Schumann' >/etc/check.d/${packageName}.exp
    cat >> /etc/check.d/${packageName}.exp <<EOFG

LCD_ALIGN_CUI     = 'Left|Center|Right|Marquee'
                  : 'Not a valid alignment, possible values: Left, Center, Right or Marquee'

LCD_DIRECTION_CUI = 'North|East|South|West'
                  : 'Bar direction, possible values: North, East, South or West'

LCD_STYLE_CUI     = '|Hollow'
                  : 'Bar style, possible values are empty or Hollow'

LCDICON           = '(\.|\*|\+|\|)*'
                  : 'Not a valid definition for a row of an icon'

EOFG

    # Set rights for check.exp file
    chmod 0600 /etc/check.d/${packageName}.exp
    chown root /etc/check.d/${packageName}.exp

#    printgpl -check_ext ${packageName} '2010-10-03' 'Yves Schumann' >/etc/check.d/${packageName}.ext
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
if [ -f /etc/config.d/${packageName} ]
then
    mecho --info -n 'Updating widget configuration.'
else
    mecho --info -n 'Creating widget configuration.'
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

if $modifiedSomething
then
    mecho --warn ' -> Read documentation for modified parameter(s)!'
fi

exit 0
# ----------------------------------------------------------------------------
# End
# ----------------------------------------------------------------------------
