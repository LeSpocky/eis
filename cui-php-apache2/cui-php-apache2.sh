#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script for Apache
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

pn=php-apache2
an=apache2
retval=0

. /etc/default.d/${pn}
. /etc/config.d/${pn}
. /etc/config.d/${an}

APACHE_USER="apache"

echo "Creating PHP5 configuration ..."

if [ "$PHP5_INFO" = "yes" ] 
then
    echo
    echo "Writing info.php, gd.php and pdf.php to $APACHE2_DOCUMENT_ROOT"
    echo --info "Set PHP5_INFO to 'no' if you've tested functionallity..."

    echo '<?php phpinfo() ?>'>/var/www/localhost/htdocs/info.php

    echo '<?php

    if(!empty($_GET["text"])) {
        Header( "Content-type: image/png");
        // Header( "Content-type: image/jpeg");

        /* create image */
        $image = imagecreate(200,200);

        /* create color R=100, G=0, R=0 */
        $maroon = ImageColorAllocate($image,100,0,0);

        /*  create color R=255, G=255, R=255 */
        $white = ImageColorAllocate($image,255,255,255);

        /*  create color green */
        $green = ImageColorAllocate($image,0,255,0);

        /*  create color cyan */
        $cyan = ImageColorAllocate($image,132,193,255);

        /*  create white background*/
        ImageFilledRectangle($image,0,0,200,200,$white);

        /*  create frame */
        ImageRectangle($image,10,10,190,190,$maroon);

        /*  create a circle */
        imagearc($image, 100, 150, 150, 50, 0, 360, $green);

        /* display font  jv: fix font dir */
        /*ImageTTFText($image, 45, 10, 30, 100, $cyan, "/usr/local/fonts/john.ttf",$_GET["text"]); */

        /*  render image */
        ImagePNG($image);
        // ImageJPEG($image);

        /* cleanup memory */
        ImageDestroy($image);

    } else {
        function describeGDdyn(){
            echo "<ul>";
            echo "<li>GD support: ";

            if(function_exists("gd_info")){
                echo "<font color=\"#00ff00\">yes</font>";
                $info = gd_info();
                $keys  = array_keys($info);

                for($i=1;$i<count($keys);$i++){
                    echo "</li>\n<li>".$keys[$i] .": " . yesNo($info[$keys[$i]]);
                }

            } else {
                echo "<font color=\"#ff0000\">no</font>";
            }

            echo "</li></ul>";
        }

        function yesNo($bool){
            if($bool){
                return "<font color=\"#00ff00\"> yes</font>";
            }else{
                return "<font color=\"#ff0000\"> no</font>";
            }
        }

        describeGDdyn();

        echo "<p>";

        echo "<form action=gd.php method=GET>";
        echo "<input type=text name=text value=eisfair> <input type=submit value=TestIt!>";
        echo "</form>";
    }

    ?>'>/var/www/localhost/htdocs/gd.php

    echo '<?php

    $RADIUS = 200.0;
    $MARGIN = 20.0;

    $p = PDF_new();

    PDF_open_file($p, "");

    PDF_set_info($p, "Creator", "pdfclock.php");
    PDF_set_info($p, "Author", "Rainer Schaaf");
    PDF_set_info($p, "Title", "PDF clock (PHP)");

    PDF_begin_page($p, 2 * ($RADIUS + $MARGIN), 2 * ($RADIUS + $MARGIN));

    PDF_translate($p, $RADIUS + $MARGIN, $RADIUS + $MARGIN);
    PDF_setcolor($p, "both", "rgb", 0.0, 0.0, 1.0, 0.0);
    PDF_save($p);

    # minute strokes
    PDF_setlinewidth($p, 2.0);
    for ($alpha = 0; $alpha < 360; $alpha += 6) {
        PDF_rotate($p, 6.0);
        PDF_moveto($p, $RADIUS, 0.0);
        PDF_lineto($p, $RADIUS-$MARGIN/3, 0.0);
        PDF_stroke($p);
    }

    PDF_restore($p);
    PDF_save($p);

    # 5 minute strokes
    PDF_setlinewidth($p, 3.0);
    for ($alpha = 0; $alpha < 360; $alpha += 30) {
        PDF_rotate($p, 30.0);
        PDF_moveto($p, $RADIUS, 0.0);
        PDF_lineto($p, $RADIUS-$MARGIN, 0.0);
        PDF_stroke($p);
    }

    $ltime = getdate();

    # draw hour hand
    PDF_save($p);
    PDF_rotate($p, -(($ltime['minutes']/60.0)+$ltime['hours']-3.0)*30.0);
    PDF_moveto($p, -$RADIUS/10, -$RADIUS/20);
    PDF_lineto($p, $RADIUS/2, 0.0);
    PDF_lineto($p, -$RADIUS/10, $RADIUS/20);
    PDF_closepath($p);
    PDF_fill($p);
    PDF_restore($p);

    # draw minute hand
    PDF_save($p);
    PDF_rotate($p, -(($ltime['seconds']/60.0)+$ltime['minutes']-15.0)*6.0);
    PDF_moveto($p, -$RADIUS/10, -$RADIUS/20);
    PDF_lineto($p, $RADIUS * 0.8, 0.0);
    PDF_lineto($p, -$RADIUS/10, $RADIUS/20);
    PDF_closepath($p);
    PDF_fill($p);
    PDF_restore($p);

    # draw second hand
    PDF_setcolor($p, "both", "rgb", 1.0, 0.0, 0.0, 0.0);
    PDF_setlinewidth($p, 2);
    PDF_save($p);
    PDF_rotate($p, -(($ltime['seconds'] - 15.0) * 6.0));
    PDF_moveto($p, -$RADIUS/5, 0.0);
    PDF_lineto($p, $RADIUS, 0.0);
    PDF_stroke($p);
    PDF_restore($p);

    # draw little circle at center
    PDF_circle($p, 0, 0, $RADIUS/30);
    PDF_fill($p);

    PDF_restore($p);
    PDF_end_page($p);

    PDF_close($p);

    $buf = PDF_get_buffer($p);
    $len = strlen($buf);

    header("Content-type: application/pdf");
    header("Content-Length: $len");
    header("Content-Disposition: inline; filename=pdfclock.pdf");
    print $buf;

    PDF_delete($p);
    ?>' >/var/www/localhost/htdocs/pdf.php

    chown $APACHE_USER /var/www/localhost/htdocs/info.php  /var/www/localhost/htdocs/pdf.php /var/www/localhost/htdocs/gd.php
else
    rm -f /var/www/localhost/htdocs/info.php /var/www/localhost/htdocs/gd.php /var/www/localhost/htdocs/pdf.php
fi

# =============================================================================
# Auswerten der Config Parameter
# =============================================================================
rm -f /etc/php/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# start
(
    echo "[php]" 
    echo "default_charset = \"UTF-8\"" 
) >> /etc/php/conf.d/eisfair.ini
# -----------------------------------------------------------------------------
# Log Error
if [ "${PHP5_LOG_ERROR}" = "yes" ] 
then
    (
        echo "; Log errors into a log file (server-specific log, stderr, or error_log (below))"
        echo "; As stated above, you\re strongly advised to use error logging in place of"
        echo "; error displaying on production web sites."
        echo "log_errors = On"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo "; Log errors into a log file (server-specific log, stderr, or error_log (below))"
        echo "; As stated above, you\re strongly advised to use error logging in place of"
        echo "; error displaying on production web sites."
        echo "log_errors = Off"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# Display Errors
if [ "${PHP5_DISPLAY_ERRORS}" = "yes" ] 
then
    (
        echo "; Print out errors (as a part of the output).  For production web sites,"
        echo "; you\re strongly encouraged to turn this feature off, and use error logging"
        echo "; instead (see below).  Keeping display_errors enabled on a production web site"
        echo "; may reveal security information to end users, such as file paths on your Web"
        echo "; server, your database schema or other information."
        echo "display_errors = On"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo "; Print out errors (as a part of the output).  For production web sites,"
        echo "; you\re strongly encouraged to turn this feature off, and use error logging"
        echo "; instead (see below).  Keeping display_errors enabled on a production web site"
        echo "; may reveal security information to end users, such as file paths on your Web"
        echo "; server, your database schema or other information."
        echo "display_errors = Off"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# Register Globals
if [ "${PHP5_REGISTER_GLOBALS}" = "yes" ]
then
    (
        echo "; You should do your best to write your scripts so that they do not require"
        echo "; register_globals to be on;  Using form variables as globals can easily lead"
        echo "; to possible security problems, if the code is not very well thought of."
        echo "register_globals = On"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo "; You should do your best to write your scripts so that they do not require"
        echo "; register_globals to be on;  Using form variables as globals can easily lead"
        echo "; to possible security problems, if the code is not very well thought of."
        echo "register_globals = Off"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# SendMail Path
if [ -n "${PHP5_SENDMAIL_PATH}" -a -f "${PHP5_SENDMAIL_PATH}"  ]
then
    (
        echo '; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").'
        echo "sendmail_path = ${PHP5_SENDMAIL_PATH} ${PHP5_SENDMAIL_APP}"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo '; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").'
        echo "sendmail_path = sendmail -t -i"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# Date Timezone Settings
(
    echo '[Date]'
    echo '; Defines the default timezone used by the date functions'
    echo "date.timezone = \"${PHP5_DATE_TIMEZONE}\""
    echo
    echo ';date.default_latitude = 31.7667'
    echo ';date.default_longitude = 35.2333'
    echo
    echo ';date.sunrise_zenith = 90.583333'
    echo ';date.sunset_zenith = 90.583333'
) >> /etc/php/conf.d/eisfair.ini
# -----------------------------------------------------------------------------
# Include Path
(
    echo '; UNIX: "/path1:/path2"'
    echo "include_path = ${PHP5_INCLUDE_PATH}"
    echo 
) >> /etc/php/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# Extension Directory
if [ -d ${PHP5_EXTENSION_DIR} ] 
then
    (
        echo '; Directory in which the loadable extensions (modules) reside.'
        echo "extension_dir = ${PHP5_EXTENSION_DIR}"
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo '; Directory in which the loadable extensions (modules) reside.'
        echo 'extension_dir = /usr/lib/php5/extensions'
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# Upload directory
if [ -d ${PHP5_UPLOAD_DIR} ] 
then
    (
        echo "; Temporary directory for HTTP uploaded files (will use system default if not"
        echo "; specified)."
        echo "upload_tmp_dir = ${PHP5_UPLOAD_DIR}"
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
else
    (
        echo "; Temporary directory for HTTP uploaded files (will use system default if not"
        echo "; specified)."
        echo 'upload_tmp_dir = "/tmp"'
        echo 
    ) >> /etc/php/conf.d/eisfair.ini
fi
# -----------------------------------------------------------------------------
# file and memory limit
(
    echo "; Maximum allowed size for uploaded files."
    echo "upload_max_filesize = ${PHP5_MAX_UPLOAD_FILESIZE}"
    echo
    echo "; Maximum execution time of each script, in seconds"
    echo "max_execution_time = ${PHP5_MAX_EXECUTION_TIME}"
    echo
    echo "; Maximum amount of memory a script may consume (8MB)"
    echo "memory_limit = ${PHP5_MEMORY_LIMIT}"
    echo 
    echo "; Maximum size of POST data that PHP will accept."
    echo "post_max_size = ${PHP5_MAX_POST_SIZE}"
    echo 
) >> /etc/php/conf.d/eisfair.ini
# -----------------------------------------------------------------------------
# load modules
#(
#    echo "extension = bz2.so"
#    echo "extension = curl.so"
#    echo "extension = gd.so"
#    echo "extension = gettext.so"
#    echo "extension = iconv.so"
#    echo "extension = mcrypt.so"
#    echo "extension = openssl.so"
#    echo "extension = pdf.so"
#    echo "extension = pdo.so"
#    echo "extension = pdo_dblib.so"
#    echo "extension = zlib.so"
#    echo 
#) >> /etc/php/conf.d/eisfair.ini
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# MYSQL
if [ "${PHP5_EXT_MYSQL}" = "yes" ] 
then
    
    apk add php-mysql
    
    if [ -z "$PHP5_EXT_MYSQL_SOCKET" ]
    then
        if [ -z "$PHP5_EXT_MYSQL_HOST" ]
        then
            if [ -e "/var/run/mysql/mysql.sock" ]
            then
                PHP5_EXT_MYSQL_SOCKET="/var/run/mysql/mysql.sock"
            elif [ -e "/var/lib/mysql/mysql.sock" ]
            then
                PHP5_EXT_MYSQL_SOCKET="/var/lib/mysql/mysql.sock"
            fi 
       fi
    fi
    if [ ! -e "$PHP5_EXT_MYSQL_SOCKET" ]
    then
        echo "The MySQL Socket yu configured does not exist. Connecting to MySQL will not be possible."
    fi
    if [ -z "$PHP5_EXT_MYSQL_HOST" ]
    then
        PHP5_EXT_MYSQL_PORT=""
    else
        if [ -z "$PHP5_EXT_MYSQL_PORT" ] 
        then
            PHP5_EXT_MYSQL_PORT="3306"
        fi
    fi
    cat >/etc/php/conf.d/mysql.ini <<EOF
	extension=mysql.so
#	;extension=mysqli.so
#	extension=pdo_mysql.so
	
	[mysql]
	mysql.allow_local_infile=On
	mysql.allow_persistent=On
	mysql.cache_size=2000
	mysql.max_persistent=-1
	mysql.max_links=-1
	mysql.default_port=${PHP5_EXT_MYSQL_PORT}
	mysql.default_socket=${PHP5_EXT_MYSQL_SOCKET}
	mysql.default_host=${PHP5_EXT_MYSQL_HOST}
	mysql.default_user=
	mysql.default_password=
	mysql.connect_timeout=60
	mysql.trace_mode=Off

	[pdo_mysql]
	pdo_mysql.cache_size=2000
	pdo_mysql.default_socket=${PHP5_EXT_MYSQL_SOCKET}

	;[mysqli]
	;mysqli.max_persistent=-1
	;mysqli.allow_local_infile=On
	;mysqli.allow_persistent=On
	;mysqli.max_links=-1
	;mysqli.cache_size=2000
	;mysqli.default_port=${PHP5_EXT_MYSQL_PORT}
	;mysqli.default_socket=${PHP5_EXT_MYSQL_SOCKET}
	;mysqli.default_host=${PHP5_EXT_MYSQL_HOST}
	;mysqli.default_user=
	;mysqli.default_pw=
	;mysqli.reconnect=Off

	[mysqlnd]
	mysqlnd.collect_statistics=On
	mysqlnd.collect_memory_statistics=Off
	;mysqlnd.net_cmd_buffer_size=2048
	;mysqlnd.net_read_buffer_size=32768

EOF
#else
#    rm -f /etc/php/conf.d/mysql.ini
fi

# -----------------------------------------------------------------------------
# INTERBASE
if [ "${PHP5_EXT_INTER}" = "yes" ] 
then
    cat >/etc/php/conf.d/interbase.ini <<EOF
extension=interbase.so
extension=pdo_firebird.so
     
[Interbase]
; Allow or prevent persistent links.
ibase.allow_persistent = 1

; Maximum number of persistent links.  -1 means no limit.
ibase.max_persistent = -1

; Maximum number of links (persistent + non-persistent).  -1 means no limit.
ibase.max_links = -1

; Default database name for ibase_connect().
;ibase.default_db =

; Default username for ibase_connect().
;ibase.default_user =

; Default password for ibase_connect().
;ibase.default_password =

; Default charset for ibase_connect().
;ibase.default_charset =

; Default timestamp format.
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"

; Default date format.
ibase.dateformat = "%Y-%m-%d"

; Default time format.
ibase.timeformat = "%H:%M:%S"
EOF
#else
#    rm -f /etc/php/conf.d/interbase.ini
fi

# -----------------------------------------------------------------------------
# MSSQL
if [ "${PHP5_EXT_MSSQL}" = "yes" ] 
then
    cat >/etc/php/conf.d/mssql.ini <<EOF
extension=mssql.so

[MSSQL]
; Allow or prevent persistent links.
mssql.allow_persistent = On

; Maximum number of persistent links.  -1 means no limit.
mssql.max_persistent = -1

; Maximum number of links (persistent+non persistent).  -1 means no limit.
mssql.max_links = -1

; Minimum error severity to display.
mssql.min_error_severity = 10

; Minimum message severity to display.
mssql.min_message_severity = 10

; Compatibility mode with old versions of PHP 3.0.
mssql.compatability_mode = Off

; Connect timeout
;mssql.connect_timeout = 5

; Query timeout
;mssql.timeout = 60

; Valid range 0 - 2147483647.  Default = 4096.
;mssql.textlimit = 4096

; Valid range 0 - 2147483647.  Default = 4096.
;mssql.textsize = 4096

; Limits the number of records in each batch.  0 = all records in one batch.
;mssql.batchsize = 0

; Specify how datetime and datetim4 columns are returned
; On => Returns data converted to SQL server settings
; Off => Returns values as YYYY-MM-DD hh:mm:ss
;mssql.datetimeconvert = On

; Use NT authentication when connecting to the server
mssql.secure_connection = Off

; Specify max number of processes. -1 = library default
; msdlib defaults to 25
; FreeTDS defaults to 4096
;mssql.max_procs = -1

; Specify client character set.
; If empty or not set the client charset from freetds.comf is used
; This is only used when compiled with FreeTDS
;mssql.charset = "ISO-8859-1"
EOF
#else
#    rm -f /etc/php/conf.d/mssql.ini
fi

# -----------------------------------------------------------------------------
# POSTGRESQL
if [ "${PHP5_EXT_PGSQL}" = "yes" ] 
then
    apk add php-pgsql
    cat >/etc/php/conf.d/pqsql.ini <<EOF
extension=pgsql.so
extension=pdo_pgsql.so
[PostgresSQL]
; Allow or prevent persistent links.
; http://php.net/pgsql.allow-persistent
pgsql.allow_persistent = On

; Detect broken persistent links always with pg_pconnect().
; Auto reset feature requires a little overheads.
; http://php.net/pgsql.auto-reset-persistent
pgsql.auto_reset_persistent = Off

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/pgsql.max-persistent
pgsql.max_persistent = -1

; Maximum number of links (persistent+non persistent).  -1 means no limit.
; http://php.net/pgsql.max-links
pgsql.max_links = -1

; Ignore PostgreSQL backends Notice message or not.
; Notice message logging require a little overheads.
; http://php.net/pgsql.ignore-notice
pgsql.ignore_notice = 0

; Log PostgreSQL backends Notice message or not.
; Unless pgsql.ignore_notice=0, module cannot log notice message.
; http://php.net/pgsql.log-notice
pgsql.log_notice = 0
EOF
#else
#    rm -f /etc/php/conf.d/pqsql.ini
fi
# -----------------------------------------------------------------------------
# SQLite3
if [ "${PHP5_EXT_SQLITE3}" = "yes" ] 
then
    apk add php-sqlite
    cat >/etc/php/conf.d/sqlite3.ini <<EOF
extension=pdo_sqlite.so
extension=sqlite3.so

[sqlite3]
;sqlite3.extension_dir =
EOF
#else
#    rm -f /etc/php/conf.d/sqlite3.ini
fi

# -----------------------------------------------------------------------------
# Advantage
# -----------------------------------------------------------------------------
#if [ "`cat /etc/eisfair-system`" = "eisfair-1" ]
#then
#    if [ "${PHP5_EXT_ADVANTAGE}" = "yes" ] ; then
#        (
#            echo "extension=advantage.so"
#            echo 
#        ) > /etc/php/conf.d/advantage.ini
#    else
#        rm -f /etc/php/conf.d/advantage.ini
#    fi
#fi

# -----------------------------------------------------------------------------
# SOAP
if [ "${PHP5_EXT_SOAP}" = "yes" ] 
then
    apk add php-soap
    cat >/etc/php/conf.d/soap.ini <<EOF
extension=soap.so
[soap]
; Enables or disables WSDL caching feature.
; http://php.net/soap.wsdl-cache-enabled
soap.wsdl_cache_enabled=1

; Sets the directory name where SOAP extension will put cache files.
; http://php.net/soap.wsdl-cache-dir
soap.wsdl_cache_dir="/tmp"

; (time to live) Sets the number of second while cached file will be used
; instead of original one.
; http://php.net/soap.wsdl-cache-ttl
soap.wsdl_cache_ttl=86400

; Sets the size of the cache limit. (Max. number of WSDL files to cache)
soap.wsdl_cache_limit = 5
EOF
#else
#    rm -f /etc/php/conf.d/soap.ini
fi

# -----------------------------------------------------------------------------
# LDAP
if [ "${PHP5_EXT_LDAP}" = "yes" ]
then
    apk add php-ldap
    cat >/etc/php/conf.d/ldap.ini <<EOF
extension=ldap.so
[ldap]
; Sets the maximum number of open links or -1 for unlimited.
ldap.max_links = -1
EOF
#else
#    rm -f /etc/php/conf.d/ldap.ini
fi

# -----------------------------------------------------------------------------
# CACHE
if [ "${PHP5_EXT_CACHE}" = "apc" ]
then
    cat >/etc/php/conf.d/apc.ini <<EOF
extension=apc.so
apc.enabled=1
EOF
    rm -f /etc/php/conf.d/eac.ini
#    if [ -d /var/lib/apache/eaccelerator ] 
#    then
#        rm -r /var/lib/apache/eaccelerator
#    fi
elif [ "${PHP5_EXT_CACHE}" = "eac" ]
then
    cat >/etc/php/conf.d/eac.ini <<EOF
extension=eaccelerator.so
eaccelerator.shm_size="16"
eaccelerator.cache_dir="/var/lib/apache/eaccelerator"
eaccelerator.enable="1"
eaccelerator.optimizer="1"
eaccelerator.check_mtime="1"
eaccelerator.debug="0"
eaccelerator.filter=""
eaccelerator.shm_max="0"
eaccelerator.shm_ttl="0"
eaccelerator.shm_prune_period="0"
eaccelerator.shm_only="0"
eaccelerator.compress="1"
eaccelerator.compress_level="6"
EOF
    rm -f /etc/php/conf.d/apc.ini
    if [ ! -d /var/lib/apache/eaccelerator ] ; then
        mkdir /var/lib/apache/eaccelerator
    fi
    chown -R $APACHE_USER /var/lib/apache/eaccelerator
elif [ "${PHP5_EXT_CACHE}" = "no" ]
then
    echo -n ""
#    rm -f /etc/php/conf.d/eac.ini
#    rm -f /etc/php/conf.d/apc.ini
fi
# =============================================================================


# -----------------------------------------------------------------------------
# Restart apache
if [ "${START_APACHE2}" = "yes" ]
then
    /etc/init.d/apache2 restart
fi