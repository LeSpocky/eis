#!/bin/sh
#-------------------------------------------------------------------------------
# Eisfair configuration generator script
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
#-------------------------------------------------------------------------------
## user vor debug output
#set -x

# include configuration files:
. /etc/config.d/clamd

# fix default clamav directories
mkdir -p /run/clamav
chmod 0777 /run/clamav
chown clamav /run/clamav

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
sed -i -e "s|^CLAMD_NICELEVEL=.*|CLAMD_NICELEVEL=$CLAMD_PRIORITY_LEVEL|" /etc/conf.d/clamd

#-------------------------------------------------------------------------------
# create clamav config
#-------------------------------------------------------------------------------
if [ -f /etc/clamav/clamd.conf.sample ]; then
    cp -f /etc/clamav/clamd.conf.sample /etc/clamav/clamd.conf.tmp
else
    cp -f /etc/clamav/clamd.conf /etc/clamav/clamd.conf.tmp
fi

sed -i -e "s|.*PidFile .*|PidFile /run/clamav/clamd.pid|" /etc/clamav/clamd.conf.tmp
sed -i -e "s|.*LocalSocket .*|LocalSocket /run/clamav/clamd.sock|" /etc/clamav/clamd.conf.tmp
sed -i -e "s|.*TCPSocket .*|TCPSocket 3310|" /etc/clamav/clamd.conf.tmp
sed -i -e "s|.*TCPAddr .*|TCPAddr 127.0.0.1|" /etc/clamav/clamd.conf.tmp
if [ "$CLAMD_SELFCHECK" = "no" ]; then
    sed -i -e "s|.*SelfCheck .*|SelfCheck 0|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*SelfCheck .*|SelfCheck 1800|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_ARCHIVE" = "yes" ]; then
    sed -i -e "s|.*ScanArchive .*|ScanArchive yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*ScanArchive .*|ScanArchive no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_OLE2" = "yes" ]; then
    sed -i -e "s|.*ScanOLE2 .*|ScanOLE2 yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*ScanOLE2 .*|ScanOLE2 no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_DETECT_PUA" = "yes" ];then
    sed -i -e  "s|.*DetectPUA .*|DetectPUA yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*DetectPUA .*|DetectPUA no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_ALGORITHMIC_DETECTION" = "yes" ]; then
    sed -i -e "s|.*AlgorithmicDetection .*|AlgorithmicDetection yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*AlgorithmicDetection .*|AlgorithmicDetection no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_PE" = "yes" ]; then
    sed -i -e "s|.*ScanPE *|ScanPE yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e  "s|.*ScanPE .*|ScanPE no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_SCAN_ELF" = "yes" ]; then
    sed -i -e "s|.*ScanELF .*|ScanELF yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*ScanELF .*|ScanELF no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_DETECT_BROKEN_EXECUTABLES" = "yes" ]; then
    sed -i -e "s|.*DetectBrokenExecutables .*|DetectBrokenExecutables yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*DetectBrokenExecutables .*|DetectBrokenExecutables no|" /etc/clamav/clamd.conf.tmp
fi
 if [ "$CLAMD_SCAN_PDF" = "yes" ]; then
    sed -i -e "s|.*ScanPDF .*|ScanPDF yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*ScanPDF .*|ScanPDF no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_ARCHIVE_BLOCK_ENCRYPTED" = "yes" ]; then
    sed -i -e "s|.*ArchiveBlockEncrypted .*|ArchiveBlockEncrypted yes|" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*ArchiveBlockEncrypted .*|ArchiveBlockEncrypted no|" /etc/clamav/clamd.conf.tmp
fi
if [ "$CLAMD_VIRUSEVENT_MAIL" = "yes" ]; then
    sed -i -e "s|.*VirusEvent .*|VirusEvent /usr/bin/cui-clamav-alertmail |" /etc/clamav/clamd.conf.tmp
else
    sed -i -e "s|.*VirusEvent .*|#VirusEvent /usr/bin/cui-clamav-alertmail |" /etc/clamav/clamd.conf.tmp
fi
sed -i -e "s|.*MaxFileSize .*|MaxFileSize ${CLAMD_MAX_FILE_SIZE}M|" /etc/clamav/clamd.conf.tmp
sed -i -e "s|.*MaxRecursion .*|MaxRecursion $CLAMD_MAX_RECURSIONS|" /etc/clamav/clamd.conf.tmp
sed -i -e "s|.*MaxFiles .*|MaxFiles $CLAMD_MAX_FILES|" /etc/clamav/clamd.conf.tmp

mv -f /etc/clamav/clamd.conf.tmp /etc/clamav/clamd.conf


#----------------------------------------------------------------------------------------
# create freshclam config
#----------------------------------------------------------------------------------------
if [ -f /etc/clamav/freshclam.conf.sample ]; then
    cp -f /etc/clamav/freshclam.conf.sample  /etc/clamav/freshclam.conf.tmp
else
    cp -f /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.tmp
fi

sed -i -e "s|.*PidFile .*|PidFile /run/clamav/freshclam.pid|" /etc/clamav/freshclam.conf.tmp
sed -i -e "s|.*DatabaseMirror db.*|DatabaseMirror db.${CLAMD_UPDATE_REGION}.clamav.net|" /etc/clamav/freshclam.conf.tmp
if [ "$CLAMD_USE_HTTP_PROXY_SERVER" = "yes" ]; then
    sed -i -e "s|.*HTTPProxyServer .*|HTTPProxyServer $CLAMD_HTTP_PROXY_SERVER|" /etc/clamav/freshclam.conf.tmp
    sed -i -e "s|.*HTTPProxyPort .*|HTTPProxyPort $CLAMD_HTTP_PROXY_PORT|" /etc/clamav/freshclam.conf.tmp
else
    sed -i -e "s|.*HTTPProxyServer .*|#HTTPProxyServer $CLAMD_HTTP_PROXY_SERVER|" /etc/clamav/freshclam.conf.tmp
    sed -i -e "s|.*HTTPProxyPort .*|#HTTPProxyPort $CLAMD_HTTP_PROXY_PORT|" /etc/clamav/freshclam.conf.tmp
fi
if [ -n "$CLAMD_HTTP_PROXY_USERNAME" ]; then
    sed -i -e "s|.*HTTPProxyUsername .*|HTTPProxyUsername $CLAMD_HTTP_PROXY_USERNAME|" /etc/clamav/freshclam.conf.tmp
    sed -i -e "s|.*HTTPProxyPassword .*|HTTPProxyPassword $CLAMD_HTTP_PROXY_PASSWORD|" /etc/clamav/freshclam.conf.tmp
else
    sed -i -e "s|.*HTTPProxyUsername .*|#HTTPProxyUsername $CLAMD_HTTP_PROXY_USERNAME|" /etc/clamav/freshclam.conf.tmp
    sed -i -e "s|.*HTTPProxyPassword .*|#HTTPProxyPassword $CLAMD_HTTP_PROXY_PASSWORD|" /etc/clamav/freshclam.conf.tmp
fi


exit 0
