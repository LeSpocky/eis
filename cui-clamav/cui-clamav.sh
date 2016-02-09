#!/bin/sh
#-------------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#-------------------------------------------------------------------------------
## user vor debug output
#set -x

# include configuration files:
. /etc/config.d/clamd

#-------------------------------------------------------------------------------
# create or update crontab file for clamav
#-------------------------------------------------------------------------------
#rm -f ${crontab_file}
#[ "$START_CLAMAV" = "yes" ] && echo "30 * * * * /sbin/rc-service --quiet clamd start  2>/dev/null" >> $crontab_file
#[ "$CLAMD_UPDATE_CRON_USE" = "yes" ] && echo "$CLAMD_UPDATE_CRON_TIMES /sbin/rc-service --quiet freshclam reload  1>/dev/null" >> $crontab_file
# update crontab
#/sbin/rc-service --quiet fcron reload


#-------------------------------------------------------------------------------
# set level
#-------------------------------------------------------------------------------
sed -i "s|^CLAMD_NICELEVEL=.*|CLAMD_NICELEVEL=$CLAMD_PRIORITY_LEVEL|" /etc/conf.d/clamd
sed -i "s|^FRESHCLAM_NICELEVEL=.*|FRESHCLAM_NICELEVEL=$CLAMD_PRIORITY_LEVEL|" /etc/conf.d/freshclam


#-------------------------------------------------------------------------------
# create clamav config
#-------------------------------------------------------------------------------
if [ -f /etc/clamav/clamd.conf.sample ]; then
    cp -f /etc/clamav/clamd.conf.sample /etc/clamav/clamd.conf.tmp
else
    cp -f /etc/clamav/clamd.conf /etc/clamav/clamd.conf.tmp
fi

#sed -i -e "s|.*PidFile .*|PidFile /run/clamav/clamd.pid|" /etc/clamav/clamd.conf.tmp
sed -i "s|.*LocalSocket .*|LocalSocket /run/clamav/clamd.sock|" /etc/clamav/clamd.conf.tmp
sed -i "s|.*TCPSocket .*|TCPSocket 3310 |" /etc/clamav/clamd.conf.tmp
sed -i "s|.*TCPAddr .*|TCPAddr 127.0.0.1 |" /etc/clamav/clamd.conf.tmp
if [ "$CLAMD_SELFCHECK" = "no" ]; then
    sed -i "s|.*SelfCheck .*|SelfCheck 0 |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*SelfCheck .*|SelfCheck 1800 |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_ARCHIVE" = "yes" ]; then
    sed -i "s|.*ScanArchive .*|ScanArchive yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ScanArchive .*|ScanArchive no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_OLE2" = "yes" ]; then
    sed -i "s|.*ScanOLE2 .*|ScanOLE2 yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ScanOLE2 .*|ScanOLE2 no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_DETECT_PUA" = "yes" ];then
    sed -i "s|.*DetectPUA .*|DetectPUA yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*DetectPUA .*|DetectPUA no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_ALGORITHMIC_DETECTION" = "yes" ]; then
    sed -i "s|.*AlgorithmicDetection .*|AlgorithmicDetection yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*AlgorithmicDetection .*|AlgorithmicDetection no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_PE" = "yes" ]; then
    sed -i "s|.*ScanPE .*|ScanPE yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ScanPE .*|ScanPE no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_ELF" = "yes" ]; then
    sed -i "s|.*ScanELF .*|ScanELF yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ScanELF .*|ScanELF no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_DETECT_BROKEN_EXECUTABLES" = "yes" ]; then
    sed -i "s|.*DetectBrokenExecutables .*|DetectBrokenExecutables yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*DetectBrokenExecutables .*|DetectBrokenExecutables no |" /etc/clamav/clamd.conf.tmp
fi
 if [ "$CLAMD_SCAN_PDF" = "yes" ]; then
    sed -i "s|.*ScanPDF .*|ScanPDF yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ScanPDF .*|ScanPDF no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_ARCHIVE_BLOCK_ENCRYPTED" = "yes" ]; then
    sed -i "s|.*ArchiveBlockEncrypted .*|ArchiveBlockEncrypted yes |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*ArchiveBlockEncrypted .*|ArchiveBlockEncrypted no |" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_VIRUSEVENT_MAIL" = "yes" ]; then
    sed -i "s|.*VirusEvent .*|VirusEvent /usr/bin/cui-clamav-alertmail |" /etc/clamav/clamd.conf.tmp
else
    sed -i "s|.*VirusEvent .*|#VirusEvent /usr/bin/cui-clamav-alertmail |" /etc/clamav/clamd.conf.tmp
fi
sed -i "s|.*MaxFileSize .*|MaxFileSize ${CLAMD_MAX_FILE_SIZE}M |" /etc/clamav/clamd.conf.tmp
sed -i "s|.*MaxRecursion .*|MaxRecursion $CLAMD_MAX_RECURSIONS |" /etc/clamav/clamd.conf.tmp
sed -i "s|.*MaxFiles .*|MaxFiles $CLAMD_MAX_FILES |" /etc/clamav/clamd.conf.tmp

mv -f /etc/clamav/clamd.conf.tmp /etc/clamav/clamd.conf


#----------------------------------------------------------------------------------------
# create freshclam config
#----------------------------------------------------------------------------------------
if [ -f /etc/clamav/freshclam.conf.sample ]; then
    cp -f /etc/clamav/freshclam.conf.sample  /etc/clamav/freshclam.conf.tmp
else
    cp -f /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.tmp
fi


#sed -i "s|.*PidFile .*|PidFile /run/clamav/freshclam.pid |" /etc/clamav/freshclam.conf.tmp
sed -i "s|.*DatabaseMirror db.*|DatabaseMirror db.${CLAMD_UPDATE_REGION}.clamav.net |" /etc/clamav/freshclam.conf.tmp

# remove second PrivateMirror
sed -i "s|.*PrivateMirror mirror2\..*||" /etc/clamav/freshclam.conf.tmp
# update first mirror only
if [ "$CLAMD_USE_PRIVAT_MIRROR" = "yes" -a -n "$CLAMD_PRIVAT_MIRROR" ]; then
    sed -i "s|.*PrivateMirror .*|PrivateMirror $CLAMD_PRIVAT_MIRROR |" /etc/clamav/freshclam.conf.tmp
else
    sed -i "s|.*PrivateMirror .*|#PrivateMirror clamav.eisfair.home |" /etc/clamav/freshclam.conf.tmp
fi

[ -z "$CLAMD_UPDATE_INTERVAL" ] && CLAMD_UPDATE_INTERVAL="4"
# check per day
CLAMD_UPDATE_INTERVAL=`expr 24 / $CLAMD_UPDATE_INTERVAL`
sed -i "s|.*Checks .*|Checks $CLAMD_UPDATE_INTERVAL |" /etc/clamav/freshclam.conf.tmp

if [ "$CLAMD_USE_HTTP_PROXY_SERVER" = "yes" ]; then
    sed -i "s|.*HTTPProxyServer .*|HTTPProxyServer $CLAMD_HTTP_PROXY_SERVER |" /etc/clamav/freshclam.conf.tmp
    sed -i "s|.*HTTPProxyPort .*|HTTPProxyPort $CLAMD_HTTP_PROXY_PORT |" /etc/clamav/freshclam.conf.tmp
else
    sed -i "s|.*HTTPProxyServer .*|#HTTPProxyServer $CLAMD_HTTP_PROXY_SERVER |" /etc/clamav/freshclam.conf.tmp
    sed -i "s|.*HTTPProxyPort .*|#HTTPProxyPort $CLAMD_HTTP_PROXY_PORT |" /etc/clamav/freshclam.conf.tmp
fi
if [  "$CLAMD_USE_HTTP_PROXY_SERVER" = "yes" -a -n "$CLAMD_HTTP_PROXY_USERNAME" ]; then
    sed -i "s|.*HTTPProxyUsername .*|HTTPProxyUsername $CLAMD_HTTP_PROXY_USERNAME |" /etc/clamav/freshclam.conf.tmp
    sed -i "s|.*HTTPProxyPassword .*|HTTPProxyPassword $CLAMD_HTTP_PROXY_PASSWORD |" /etc/clamav/freshclam.conf.tmp
else
    sed -i "s|.*HTTPProxyUsername .*|#HTTPProxyUsername $CLAMD_HTTP_PROXY_USERNAME |" /etc/clamav/freshclam.conf.tmp
    sed -i "s|.*HTTPProxyPassword .*|#HTTPProxyPassword $CLAMD_HTTP_PROXY_PASSWORD |" /etc/clamav/freshclam.conf.tmp
fi

# error if not set 0600 with HTTPProxyPassword
mv -f /etc/clamav/freshclam.conf.tmp /etc/clamav/freshclam.conf
chmod 0600 /etc/clamav/freshclam.conf
chown clamav /etc/clamav/freshclam.conf


# add system logfile entries
/var/install/bin/add-menu --logfile setup.system.logfileview.menu "/var/log/clamav/clamd.log" "ClamAV"
/var/install/bin/add-menu --logfile setup.system.logfileview.menu "/var/log/clamav/freshclam.log" "ClamAV Updates"

# force stop freshclom (autostart with clamd)
/sbin/rc-service --quiet freshclam stop
killall freshclam >/dev/null 2>&1

# create missing socket path with clamd prepare init script
/sbin/rc-update -q add clamdpre 2>/dev/null
/sbin/rc-service --quiet clamdpre restart

exit 0
