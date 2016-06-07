#!/bin/sh
#------------------------------------------------------------------------------
# eisfair-ng configuration generator script
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
#------------------------------------------------------------------------------

pn=php-apache2
an=apache2
retval=0

. /etc/default.d/${pn}
. /etc/config.d/${pn}
. /etc/config.d/${an}

APACHE_USER="apache"
# upgrade php-* to php5-*
PHPv=php5
PHPo=php

# -----------------------------------------------------------------------------
# replace or reinstall php module
load_php_module()
{
    local name="$1"
    apk info -q -e ${PHPo}-$name && apk del -f -q ${PHPo}-$name
    apk info -q -e ${PHPv}-$name || apk add -q ${PHPv}-$name
    if [ $? -eq 0 ]; then
        return 0
    else
        # create error message if packages not installed
        logger -p error -t cui-php-apache2 "Fail install: ${PHPv}-$name"
        echo "Fail install: ${PHPv}-$name"    
        return 1
    fi   
}


mkdir -p /etc/${PHPv}/conf.d
#rm -f /etc/${PHPv}/conf.d/*.apk-new
apk info -q -e ${PHPo}-apache2 && apk del -f -q ${PHPo}-apache2
apk fix  -q -r ${PHPv}-apache2

if [ "$PHP_INFO" = "yes" ] ; then
    mkdir -p /var/www/localhost/htdocs
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
        ImageTTFText($image, 45, 10, 30, 100, $cyan, "/usr/share/fonts/TTF/php-apache2-john.ttf",$_GET["text"]);
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

    chown $APACHE_USER /var/www/localhost/htdocs/info.php /var/www/localhost/htdocs/gd.php
else
    rm -f /var/www/localhost/htdocs/info.php /var/www/localhost/htdocs/gd.php 
fi

# =============================================================================
# Auswerten der Config Parameter
# =============================================================================

# -----------------------------------------------------------------------------
# start
(
    echo "[php]" 
    echo "default_charset = \"UTF-8\"" 
) > /etc/${PHPv}/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# Log Error
if [ "$PHP_LOG_ERROR" = "yes" ] ; then
    (
        echo "; Log errors into a log file (server-specific log, stderr, or error_log (below))"
        echo "; As stated above, you\re strongly advised to use error logging in place of"
        echo "; error displaying on production web sites."
        echo "log_errors = On"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
else
    (
        echo "; Log errors into a log file (server-specific log, stderr, or error_log (below))"
        echo "; As stated above, you\re strongly advised to use error logging in place of"
        echo "; error displaying on production web sites."
        echo "log_errors = Off"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
fi

# -----------------------------------------------------------------------------
# Display Errors
if [ "$PHP_DISPLAY_ERRORS" = "yes" ] ; then
    (
        echo "; Print out errors (as a part of the output).  For production web sites,"
        echo "; you\re strongly encouraged to turn this feature off, and use error logging"
        echo "; instead (see below).  Keeping display_errors enabled on a production web site"
        echo "; may reveal security information to end users, such as file paths on your Web"
        echo "; server, your database schema or other information."
        echo "display_errors = On"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
else
    (
        echo "; Print out errors (as a part of the output).  For production web sites,"
        echo "; you\re strongly encouraged to turn this feature off, and use error logging"
        echo "; instead (see below).  Keeping display_errors enabled on a production web site"
        echo "; may reveal security information to end users, such as file paths on your Web"
        echo "; server, your database schema or other information."
        echo "display_errors = Off"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
fi

# -----------------------------------------------------------------------------
# Register Globals
if [ "$PHP_REGISTER_GLOBALS" = "yes" ] ; then
    (
        echo "; You should do your best to write your scripts so that they do not require"
        echo "; register_globals to be on;  Using form variables as globals can easily lead"
        echo "; to possible security problems, if the code is not very well thought of."
        echo "register_globals = On"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
else
    (
        echo "; You should do your best to write your scripts so that they do not require"
        echo "; register_globals to be on;  Using form variables as globals can easily lead"
        echo "; to possible security problems, if the code is not very well thought of."
        echo "register_globals = Off"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
fi

# -----------------------------------------------------------------------------
# SendMail Path
if [ -n "$PHP_SENDMAIL_PATH" -a -f "$PHP_SENDMAIL_PATH" ] ; then
    (
        echo '; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").'
        echo "sendmail_path = ${PHP_SENDMAIL_PATH} ${PHP_SENDMAIL_APP}"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
else
    (
        echo '; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").'
        echo "sendmail_path = sendmail -t -i"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
fi

# -----------------------------------------------------------------------------
# Date Timezone Settings
(
    echo '[Date]'
    echo '; Defines the default timezone used by the date functions'
    echo "date.timezone = \"${PHP_DATE_TIMEZONE}\""
    echo
    echo ';date.default_latitude = 31.7667'
    echo ';date.default_longitude = 35.2333'
    echo
    echo ';date.sunrise_zenith = 90.583333'
    echo ';date.sunset_zenith = 90.583333'
) >> /etc/${PHPv}/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# Include Path
(
    echo '; UNIX: "/path1:/path2"'
    echo "include_path = ${PHP_INCLUDE_PATH}"
    echo 
) >> /etc/${PHPv}/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# Upload directory
if [ -d "$PHP_UPLOAD_DIR" ] ; then
    (
        echo "; Temporary directory for HTTP uploaded files (will use system default if not"
        echo "; specified)."
        echo "upload_tmp_dir = ${PHP_UPLOAD_DIR}"
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
else
    (
        echo "; Temporary directory for HTTP uploaded files (will use system default if not"
        echo "; specified)."
        echo 'upload_tmp_dir = "/tmp"'
        echo 
    ) >> /etc/${PHPv}/conf.d/eisfair.ini
fi

# -----------------------------------------------------------------------------
# file and memory limit
(
    echo "; Maximum allowed size for uploaded files."
    echo "upload_max_filesize = ${PHP_MAX_UPLOAD_FILESIZE}"
    echo
    echo "; Maximum execution time of each script, in seconds"
    echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}"
    echo
    echo "; Maximum amount of memory a script may consume (8MB)"
    echo "memory_limit = ${PHP_MEMORY_LIMIT}"
    echo 
    echo "; Maximum size of POST data that PHP will accept."
    echo "post_max_size = ${PHP_MAX_POST_SIZE}"
    echo 
) >> /etc/${PHPv}/conf.d/eisfair.ini

# -----------------------------------------------------------------------------
# MYSQL
rm  -f /etc/${PHPv}/conf.d/mysql.ini
rm  -f /etc/${PHPv}/conf.d/mysqli.ini
rm  -f /etc/${PHPv}/conf.d/pdo_mysql.ini
if [ "$PHP_EXT_MYSQL" = "yes" ] ; then
    if [ -z "$PHP_EXT_MYSQL_SOCKET" -a -z "$PHP_EXT_MYSQL_HOST" ] ; then
        [ -e "/run/mysqld/mysqld.sock" ] && PHP_EXT_MYSQL_SOCKET="/run/mysqld/mysqld.sock"
    fi
    if [ -z "$PHP_EXT_MYSQL_HOST" ] ; then
        PHP_EXT_MYSQL_PORT=""
    else
        [ -z "$PHP_EXT_MYSQL_PORT" ] && PHP_EXT_MYSQL_PORT="3306"
    fi

    load_php_module mysql
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/mysql.ini <<EOF
extension=mysql.so
[mysql]
mysql.allow_local_infile=On
mysql.allow_persistent=On
mysql.cache_size=2000
mysql.max_persistent=-1
mysql.max_links=-1
mysql.default_port=${PHP_EXT_MYSQL_PORT}
mysql.default_socket=${PHP_EXT_MYSQL_SOCKET}
mysql.default_host=${PHP_EXT_MYSQL_HOST}
mysql.default_user=
mysql.default_password=
mysql.connect_timeout=60
mysql.trace_mode=Off
EOF
    fi

    load_php_module pdo_mysql
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/pdo_mysql.ini <<EOF
extension=pdo_mysql.so
[pdo_mysql]
pdo_mysql.cache_size=2000
pdo_mysql.default_socket=${PHP_EXT_MYSQL_SOCKET}
EOF
    fi

    load_php_module mysqli
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/mysqli.ini <<EOF
extension=mysqli.so
[mysqli]
mysqli.max_persistent=-1
mysqli.allow_local_infile=On
mysqli.allow_persistent=On
mysqli.max_links=-1
mysqli.cache_size=2000
mysqli.default_port=${PHP_EXT_MYSQL_PORT}
mysqli.default_socket=${PHP_EXT_MYSQL_SOCKET}
mysqli.default_host=${PHP_EXT_MYSQL_HOST}
mysqli.default_user=
mysqli.default_pw=
mysqli.reconnect=Off

[mysqlnd]
mysqlnd.collect_statistics=On
mysqlnd.collect_memory_statistics=Off
;mysqlnd.net_cmd_buffer_size=2048
;mysqlnd.net_read_buffer_size=32768
EOF
    fi
fi

# ------------------------------------------------------------------------------
# INTERBASE
rm -f /etc/${PHPv}/conf.d/interbase.ini
if [ "$PHP_EXT_INTER" = "yes" ] ; then
#    load_php_module interbase
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/interbase.ini <<EOF
;extension=interbase.so
;extension=pdo_firebird.so
[interbase]
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
    fi
fi

# -----------------------------------------------------------------------------
# MSSQL
rm -f /etc/${PHPv}/conf.d/mssql.ini
if [ "$PHP_EXT_MSSQL" = "yes" ] ; then
    load_php_module mssql
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/mssql.ini <<EOF
extension=mssql.so
[mssql]
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
    fi
fi

# -----------------------------------------------------------------------------
# POSTGRESQL
rm -f /etc/${PHPv}/conf.d/pqsql.ini
rm -f /etc/${PHPv}/conf.d/pdo_pgsql.ini
if [ "${PHP_EXT_PGSQL}" = "yes" ] ; then
    load_php_module pgsql
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/pqsql.ini <<EOF
extension=pgsql.so
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
    fi

    load_php_module pdo_pgsql
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/pdo_pgsql.ini <<EOF
extension=pdo_pgsql.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# SQLite3
rm -f /etc/${PHPv}/conf.d/sqlite3.ini
rm -f /etc/${PHPv}/conf.d/pdo_sqlite.ini
if [ "$PHP_EXT_SQLITE3" = "yes" ] ; then
    load_php_module sqlite3
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/sqlite3.ini <<EOF
extension=pdo_sqlite.so
[sqlite3]
;sqlite3.extension_dir =
EOF
    fi
    load_php_module pdo_sqlite
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/pdo_sqlite.ini <<EOF
extension=sqlite3.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# CTYPE
rm -f /etc/${PHPv}/conf.d/ctype.ini
if [ "$PHP_EXT_CTYPE" = "yes" ] ; then
    load_php_module ctype
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/ctype.ini <<EOF
extension=ctype.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# SOAP
rm -f /etc/${PHPv}/conf.d/soap.ini
if [ "$PHP_EXT_SOAP" = "yes" ] ; then
    load_php_module soap
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/soap.ini <<EOF
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
    fi
fi

# -----------------------------------------------------------------------------
# GD
rm -f /etc/${PHPv}/conf.d/gd.ini
if [ "$PHP_EXT_GD" = "yes" ] ; then
    load_php_module gd
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/gd.ini <<EOF
extension=gd.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# LDAP
rm -f /etc/${PHPv}/conf.d/ldap.ini
if [ "$PHP_EXT_LDAP" = "yes" ] ; then
    load_php_module ldap
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/ldap.ini <<EOF
extension=ldap.so
[ldap]
; Sets the maximum number of open links or -1 for unlimited.
ldap.max_links = -1
EOF
    fi
fi

# -----------------------------------------------------------------------------
# CURL
rm -f /etc/${PHPv}/conf.d/curl.ini
if [ "$PHP_EXT_CURL" = "yes" ] ; then
    load_php_module curl
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/curl.ini <<EOF
extension=curl.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# CACHE
rm -f /etc/${PHPv}/conf.d/apc.ini
rm -f /etc/${PHPv}/conf.d/apcu.ini
rm -f /etc/${PHPv}/conf.d/xcache.ini
rm -f /etc/${PHPv}/conf.d/memcache.ini
rm -f /etc/${PHPv}/conf.d/opcache.ini

if [ "$PHP_EXT_CACHE" = "apc" ] ; then
    load_php_module apcu
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/apcu.ini <<EOF
extension=apcu.so
;nur noch User-Cache-Funktionen!
EOF
    fi
elif [ "$PHP_EXT_CACHE" = "xcache" ] ; then
    load_php_module xcache
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/xcache.ini <<EOF
extension=xcache.so
xcache.size=64M
xcache.var_size=64M
EOF
    fi
elif [ "$PHP_EXT_CACHE" = "memcache" ] ; then
    load_php_module memcache
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/memcache.ini <<EOF
extension=memcache.so
;memcache.allow_failover="1"
;memcache.max_failover_attempts="20"
;memcache.chunk_size="8192"
;memcache.default_port="11211"
;memcache.hash_strategy="standard"
;memcache.hash_function="crc32"
;session.save_handler="files"
;session.save_path=""
;memcache.protocol=ascii
;memcache.redundancy=1
;memcache.session_redundancy=2
;memcache.compress_threshold=20000
;memcache.lock_timeout=15
EOF
    fi
elif [ "$PHP_EXT_CACHE" = "opcache" ] ; then
    load_php_module opcache
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/opcache.ini <<EOF
zend_extension=opcache.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# JSON
rm -f /etc/${PHPv}/conf.d/json.ini
if [ "$PHP_EXT_JSON" = "yes" ] ; then
    load_php_module json
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/json.ini <<EOF
extension=json.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# GETTEXT
rm -f /etc/${PHPv}/conf.d/gettext.ini
if [ "$PHP_EXT_GETTEXT" = "yes" ] ; then
    load_php_module gettext
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/gettext.ini <<EOF
extension=gettext.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# ICONV
rm -f /etc/${PHPv}/conf.d/iconv.ini
if [ "$PHP_EXT_ICONV" = "yes" ] ; then
    load_php_module iconv
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/iconv.ini <<EOF
extension=iconv.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# IMAP
rm -f /etc/${PHPv}/conf.d/imap.ini
if [ "$PHP_EXT_IMAP" = "yes" ] ; then
    load_php_module imap
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/imap.ini <<EOF
extension=imap.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# OPENSSL
rm -f /etc/${PHPv}/conf.d/openssl.ini
if [ "$PHP_EXT_SSL" = "yes" ] ; then
    load_php_module openssl
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/openssl.ini <<EOF
extension=openssl.so
EOF
    fi
fi


# -----------------------------------------------------------------------------
# XML
rm -f /etc/${PHPv}/conf.d/xml.ini
if [ "$PHP_EXT_XML" = "yes" ] ; then
    load_php_module xml
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/xml.ini <<EOF
extension=xml.so
EOF
    fi
fi
# -----------------------------------------------------------------------------
# XMLREADER
rm -f /etc/${PHPv}/conf.d/xmlreader.ini
if [ "$PHP_EXT_XML" = "yes" ] ; then
    load_php_module xmlreader
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/xmlreader.ini <<EOF
extension=xmlreader.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# ZIP
rm -f /etc/${PHPv}/conf.d/zip.ini
if [ "$PHP_EXT_ZIP" = "yes" ] ; then
    load_php_module zip
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/zip.ini <<EOF
extension=zip.so
EOF
    fi
fi

# -----------------------------------------------------------------------------
# ZLIB
rm -f /etc/${PHPv}/conf.d/zlib.ini
if [ "$PHP_EXT_ZLIB" = "yes" ] ; then
    load_php_module zlib
    if [ $? -eq 0 ]; then
        cat >/etc/${PHPv}/conf.d/zlib.ini <<EOF
extension=zlib.so
EOF
    fi
fi


# =============================================================================
# Restart apache
[ "${START_APACHE2}" = "yes" ] && rc-service -i -q apache2 restart 

exit 0
