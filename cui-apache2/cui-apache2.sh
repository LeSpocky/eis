#!/bin/sh
#----------------------------------------------------------------------------
# Eisfair configuration generator script for Apache
# Copyright (c) 2007 - 2013 the eisfair team, team(at)eisfair(dot)org
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#----------------------------------------------------------------------------

#echo "Executing $0 ..."
#exec 2> /tmp/apache2-trace$$.log
#set -x

pgmname=$0

chmod 600 /etc/config.d/apache2

. /etc/config.d/apache2
. /var/install/include/apache2

# -------------------------------------------------------------------------
# get ip setting
# -------------------------------------------------------------------------
. /etc/config.d/base                 # include base config

# read dhcp leases
#if [ "$IP_NET_1_STATIC_IP" = "no" ]
#then
#    leasefile=/var/lib/dhcp3/dhclient.eth0.leases
#    if [ -f $leasefile ]
#    then
#        IP_NET_1_IPADDR=`grep fixed-address $leasefile | awk 'BEGIN { RS=""; FS="\n"} {print $NF}' | sed -e 's#[^0-9.]##g'`
#    fi
#fi

if [ "$START_APACHE2" = "yes" ]
then
     rc-update -q add apache2 2>/dev/null
else
     rc-update del apache2 
fi

#if [ ! -f /etc/ssl/certs/apache.pem -a "$APACHE2_SSL" = "yes" ]
#then
#    echo "* Creating CA for SSL ..."
#    /var/install/bin/certs-create-tls-certs ca batch
#    echo "* Creating apache.pem"
#    echo "* Notice: The Common Name (you will type it in a moment) has to be the ServerName!"
#    /var/install/bin/certs-create-tls-certs web batch alternate "apache" "$APACHE2_SERVER_NAME"
#fi

#----------------------------------------------------------------------------------------
# activate content of /home/USER/public_html
#----------------------------------------------------------------------------------------
enuser="#"
[ "$APACHE2_ENABLE_USERDIR" = "yes" ] && enuser=""

#----------------------------------------------------------------------------------------
# activate diskcache and vhosts 
#----------------------------------------------------------------------------------------
encache="#"
envhost="#"
# cache for doc root:
modcache="$APACHE2_MOD_CACHE"
# cache for any vhost:
if [ "$modcache" = "no" ]
then
    idx=0
    while [ "$idx" -le "$APACHE2_VHOST_N" ]
    do
	    eval vhostact='$APACHE2_VHOST_'$idx'_ACTIVE'
		if [ "$vhostact" = "yes" ]
		then
		    envhost=""
            eval modcache='$APACHE2_VHOST_'$idx'_MOD_CACHE'
            [ "$modcache" = "yes" ] && break
		fi	
        idx=`expr $idx + 1`
    done
fi
[ "$modcache" = "yes" ] && encache=""

#----------------------------------------------------------------------------------------
# activate ssl 
#----------------------------------------------------------------------------------------
enssl="#"
[ "$APACHE2_SSL" = "yes" ] && enssl=""

#----------------------------------------------------------------------------------------
# activate webdav 
#----------------------------------------------------------------------------------------
endav="#"
idx=1
while [ "$idx" -le "$APACHE2_DIR_N" ]
do
    eval webdav='$APACHE2_DIR_'$idx'_WEBDAV'
    if [ "$webdav" = "yes" ] 
    then
	    endav=""
	    break
	fi	
    idx=`expr $idx + 1`
done
vidx=1
while [ "$vidx" -le "$APACHE2_VHOST_N" ]
do
    eval activevhost='$APACHE2_VHOST_'$vidx'_ACTIVE'
    if [ "$activevhost" = "yes" ]
    then
        idx=1
        eval tmpidx='$APACHE2_VHOST_'$vidx'_DIR_N'
        while [ "$idx" -le "$tmpidx" ]
        do
            eval webdav='$APACHE2_VHOST_'$vidx'_DIR_'$idx'_WEBDAV'
            if [ "$webdav" = "yes" ] 
            then
                endav=""
                break
            fi
            idx=`expr $idx + 1`
        done
    fi
    [ "$webdav" = "yes" ] && break
    vidx=`expr $vidx + 1`
done

if [ -z "$endav" ]
then
    mkdir -p /var/lib/dav
	chown apache /var/lib/dav
fi
#----------------------------------------------------------------------------------------
# use SSI
#----------------------------------------------------------------------------------------
enssi="#"
[ "$APACHE2_ENABLE_SSI" = "yes" ] && enssi=""

#----------------------------------------------------------------------------------------
# Enable negotiation
#----------------------------------------------------------------------------------------
enneg="#"
[ "$APACHE2_ERROR_DOCUMENT_N" -gt 0 ] && enneg=""

#----------------------------------------------------------------------------------------
# creating httpd.conf
#----------------------------------------------------------------------------------------
options="FollowSymLinks MultiViews"
[ "$APACHE2_VIEW_DIRECTORY_CONTENT" = "yes" ] && options="$options Indexes"
[ "$APACHE2_ENABLE_SSI" = "yes" ]             && options="$options Includes"

hnlookup='Off'
[ "$APACHE2_HOSTNAME_LOOKUPS" = "yes" ] && hnlookup='On'

cat > /etc/apache2/httpd.conf <<EOF
#-------------------------------------------------------------------------------
# Apache configuration file generated by eis CUI script
#-------------------------------------------------------------------------------
ServerTokens OS
ServerRoot "/var/www"
PidFile run/httpd.pid
Timeout 60
KeepAlive On
MaxKeepAliveRequests ${APACHE2_MAX_KEEP_ALIVE_REQUESTS}
KeepAliveTimeout ${APACHE2_MAX_KEEP_ALIVE_TIMEOUT}

# prefork MPM
# StartServers: number of server processes to start
# MinSpareServers: minimum number of server processes which are kept spare
# MaxSpareServers: maximum number of server processes which are kept spare
# ServerLimit: maximum value for MaxClients for the lifetime of the server
# MaxClients: maximum number of server processes allowed to start
# MaxRequestsPerChild: maximum number of requests a server process serves
# if use: /usr/sbin/httpd
<IfModule prefork.c>
    StartServers       8
    MinSpareServers    5
    MaxSpareServers   20
    ServerLimit      ${APACHE2_MAX_CLIENTS}
    MaxClients       ${APACHE2_MAX_CLIENTS}
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>
 
# itk MPM
# AssignUserID: takes two parameters, uid and gid (or really, user name and
#               group name); specifies what uid and gid the vhost will run as
#               (after parsing the request etc., of course).
# MaxClientsVHost: a separate MaxClients for each vhost.
# NiceValue: lets you nice some requests down, to give them less CPU time.
# AssignUserID and NiceValue can be set wherever you'd like in the Apache
# configuration, except in .htaccess.  MaxClientsVHost can only be set inside
# a VirtualHost directive.
# if use: /usr/sbin/httpd.itk
<IfModule itk.c>
    AssignUserID apache apache
    StartServers       8
    MinSpareServers    5
    MaxSpareServers   20
    ServerLimit      ${APACHE2_MAX_CLIENTS}
    MaxClients       ${APACHE2_MAX_CLIENTS}
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>

# worker MPM
# StartServers: initial number of server processes to start
# MaxClients: maximum number of simultaneous client connections
# MinSpareThreads: minimum number of worker threads which are kept spare
# MaxSpareThreads: maximum number of worker threads which are kept spare
# ThreadsPerChild: constant number of worker threads in each server process
# MaxRequestsPerChild: maximum number of requests a server process serves
# if use: /usr/sbin/httpd.worker
<IfModule worker.c>
    StartServers         4
    MaxClients          ${APACHE2_MAX_CLIENTS}
    MinSpareThreads     25
    MaxSpareThreads     75
    ThreadsPerChild     25
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>

Include /etc/apache2/conf.d/*.conf

User apache
Group apache

LoadModule actions_module modules/mod_actions.so
LoadModule alias_module modules/mod_alias.so
#LoadModule asis_module modules/mod_asis.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule auth_digest_module modules/mod_auth_digest.so
#LoadModule authn_alias_module modules/mod_authn_alias.so
#LoadModule authn_anon_module modules/mod_authn_anon.so
#LoadModule authn_dbd_module modules/mod_authn_dbd.so
#LoadModule authn_dbm_module modules/mod_authn_dbm.so
LoadModule authn_default_module modules/mod_authn_default.so
LoadModule authn_file_module modules/mod_authn_file.so
#LoadModule authz_dbm_module modules/mod_authz_dbm.so
LoadModule authz_default_module modules/mod_authz_default.so
LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
LoadModule authz_host_module modules/mod_authz_host.so
#LoadModule authz_owner_module modules/mod_authz_owner.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule autoindex_module modules/mod_autoindex.so
${encache}LoadModule cache_module modules/mod_cache.so
#LoadModule cern_meta_module modules/mod_cern_meta.so
LoadModule cgi_module modules/mod_cgi.so
#LoadModule cgid_module modules/mod_cgid.so
${endav}LoadModule dav_module modules/mod_dav.so
${endav}LoadModule dav_fs_module modules/mod_dav_fs.so
#LoadModule dav_lock_module modules/mod_dav_lock.so
#LoadModule dbd_module modules/mod_dbd.so
LoadModule deflate_module modules/mod_deflate.so
LoadModule dir_module modules/mod_dir.so
${encache}LoadModule disk_cache_module modules/mod_disk_cache.so
#LoadModule dumpio_module modules/mod_dumpio.so
LoadModule env_module modules/mod_env.so
LoadModule expires_module modules/mod_expires.so
#LoadModule ext_filter_module modules/mod_ext_filter.so
#LoadModule file_cache_module modules/mod_file_cache.so
#LoadModule filter_module modules/mod_filter.so
LoadModule headers_module modules/mod_headers.so
#LoadModule ident_module modules/mod_ident.so
#LoadModule imagemap_module modules/mod_imagemap.so
LoadModule include_module modules/mod_include.so
LoadModule info_module modules/mod_info.so
LoadModule log_config_module modules/mod_log_config.so
#LoadModule log_forensic_module modules/mod_log_forensic.so
#LoadModule logio_module modules/mod_logio.so
${encache}LoadModule mem_cache_module modules/mod_mem_cache.so
LoadModule mime_module modules/mod_mime.so
#LoadModule mime_magic_module modules/mod_mime_magic.so
${enneg}LoadModule negotiation_module modules/mod_negotiation.so
#LoadModule proxy_module modules/mod_proxy.so
#LoadModule proxy_ajp_module modules/mod_proxy_ajp.so
#LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
#LoadModule proxy_connect_module modules/mod_proxy_connect.so
#LoadModule proxy_ftp_module modules/mod_proxy_ftp.so
#LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule setenvif_module modules/mod_setenvif.so
#LoadModule speling_module modules/mod_speling.so
${enssl}LoadModule ssl_module modules/mod_ssl.so
LoadModule status_module modules/mod_status.so
#LoadModule substitute_module modules/mod_substitute.so
LoadModule suexec_module modules/mod_suexec.so
LoadModule unique_id_module modules/mod_unique_id.so
${enuser}LoadModule userdir_module modules/mod_userdir.so
#LoadModule usertrack_module modules/mod_usertrack.so
#LoadModule version_module modules/mod_version.so
${envhost}LoadModule vhost_alias_module modules/mod_vhost_alias.so

<IfModule mod_cache.c>
    # 300 = 5 minutes
    CacheDefaultExpire 300
    CacheIgnoreNoLastMod On
    CacheIgnoreQueryString On
    CacheIgnoreHeaders Set-Cookie
    <IfModule mod_mem_cache.c>
        CacheEnable mem /
        MCacheSize 16384
        MCacheMaxObjectCount 100
        MCacheMinObjectSize 1
        MCacheMaxObjectSize 4096
    </IfModule>
</IfModule>

<IfModule ssl_module>
    SSLRandomSeed startup builtin
    SSLRandomSeed connect builtin
    AddType       application/x-x509-ca-cert .crt
    AddType       application/x-pkcs7-crl    .crl
	  SSLPassPhraseDialog builtin
    SSLSessionCache "shmcb:/var/run/apache2/ssl_scache(512000)"
    SSLSessionCacheTimeout 300
	  SSLMutex "file:/var/run/apache2/ssl_mutex"
</IfModule>

<IfModule mod_mime_magic.c>
    MIMEMagicFile /etc/apache2/magic
</IfModule>

<IfModule mod_dav_fs.c>
    DAVLockDB /var/lib/dav/lockdb
</IfModule>


ServerAdmin  ${APACHE2_SERVER_ADMIN}
ServerName   ${APACHE2_SERVER_NAME}:${APACHE2_PORT}
UseCanonicalName Off
DocumentRoot "/var/www/localhost/htdocs"
${enuser}UserDir public_html
DirectoryIndex ${APACHE2_DIRECTORY_INDEX}
AccessFileName .htaccess
TypesConfig /etc/apache2/mime.types
HostnameLookups ${hnlookup}
ErrorLog /var/log/apache2/error.log
LogLevel ${APACHE2_LOG_LEVEL}
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
SetEnvIf Remote_Addr "127\.0\.0\.1" dontlog
CustomLog /var/log/apache2/access.log combined env=!dontlog
ServerTokens Minor
ServerSignature ${APACHE2_SERVER_SIGNATURE}

<Directory />
    Options FollowSymLinks
    AllowOverride None
    Order deny,allow
    Deny from all    
</Directory>

<Directory "/var/www/localhost/htdocs">
    Options ${options}
    AllowOverride All
    Order allow,deny
    Allow from ${APACHE2_ACCESS_CONTROL} 
</Directory>

<Directory "/home/*/public_html">
    AllowOverride FileInfo AuthConfig Limit Indexes
    Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
    <Limit GET POST OPTIONS>
        Order allow,deny
        Allow from all
    </Limit>
    <LimitExcept GET POST OPTIONS>
        Order deny,allow
        Deny from all
    </LimitExcept>	
    Order allow,deny
    Allow from ${APACHE2_ACCESS_CONTROL} 
</Directory>


<Files ~ "^\.ht">
    Require all denied
</Files>


ScriptAlias /cgi-bin/ "/var/www/cgi-bin/"
<Directory "/var/www/cgi-bin">
    AllowOverride None
    Options None
    Order allow,deny
    Allow from ${APACHE2_ACCESS_CONTROL}
</Directory>

IndexOptions FancyIndexing VersionSort NameWidth=* HTMLTable Charset=UTF-8
IndexIgnore .??* *~ *# HEADER* README* RCS CVS *,v *,t

Alias /icons/ "/usr/share/apache2/icons/"
<Directory "/usr/share/apache2/icons">
    Options Indexes MultiViews FollowSymLinks
    AllowOverride None
    Order allow,deny
    Allow from all
</Directory>

AddIconByEncoding (CMP,/icons/compressed.gif) x-compress x-gzip
AddIconByType (TXT,/icons/text.gif) text/*
AddIconByType (IMG,/icons/image2.gif) image/*
AddIconByType (SND,/icons/sound2.gif) audio/*
AddIconByType (VID,/icons/movie.gif) video/*
AddIcon /icons/binary.gif .bin .exe
AddIcon /icons/binhex.gif .hqx
AddIcon /icons/tar.gif .tar
AddIcon /icons/world2.gif .wrl .wrl.gz .vrml .vrm .iv
AddIcon /icons/compressed.gif .Z .z .tgz .gz .zip
AddIcon /icons/a.gif .ps .ai .eps
AddIcon /icons/layout.gif .html .shtml .htm .pdf
AddIcon /icons/text.gif .txt
AddIcon /icons/c.gif .c
AddIcon /icons/p.gif .pl .py
AddIcon /icons/f.gif .for
AddIcon /icons/dvi.gif .dvi
AddIcon /icons/uuencoded.gif .uu
AddIcon /icons/script.gif .conf .sh .shar .csh .ksh .tcl
AddIcon /icons/tex.gif .tex
AddIcon /icons/bomb.gif core
AddIcon /icons/back.gif ..
AddIcon /icons/hand.right.gif README
AddIcon /icons/folder.gif ^^DIRECTORY^^
AddIcon /icons/blank.gif ^^BLANKICON^^
DefaultIcon /icons/unknown.gif

AddDefaultCharset UTF-8

AddLanguage ca .ca
AddLanguage cs .cz .cs
AddLanguage da .dk
AddLanguage de .de
AddLanguage el .el
AddLanguage en .en
AddLanguage eo .eo
AddLanguage es .es
AddLanguage et .et
AddLanguage fr .fr
AddLanguage he .he
AddLanguage hr .hr
AddLanguage it .it
AddLanguage ja .ja
AddLanguage ko .ko
AddLanguage ltz .ltz
AddLanguage nl .nl
AddLanguage nn .nn
AddLanguage no .no
AddLanguage pl .po
AddLanguage pt .pt
AddLanguage pt-BR .pt-br
AddLanguage ru .ru
AddLanguage sv .sv
AddLanguage zh-CN .zh-cn
AddLanguage zh-TW .zh-tw

<IfModule mod_negotiation.c>
    LanguagePriority en ca cs da de el eo es et fr he hr it ja ko ltz nl nn no pl pt pt-BR ru sv zh-CN zh-TW
    ForceLanguagePriority Prefer Fallback
</IfModule>

AddType application/x-compress .Z
AddType application/x-gzip .gz .tgz


# The following directives modify normal HTTP response behavior to
# handle known problems with browser implementations.
#
BrowserMatch "Mozilla/2" nokeepalive
BrowserMatch "MSIE 4\.0b2;" nokeepalive downgrade-1.0 force-response-1.0
BrowserMatch "RealPlayer 4\.0" force-response-1.0
BrowserMatch "Java/1\.0" force-response-1.0
BrowserMatch "JDK/1\.0" force-response-1.0

# The following directive disables redirects on non-GET requests for
# a directory that does not include the trailing slash.  This fixes a 
# problem with Microsoft WebFolders which does not appropriately handle 
# redirects for folders with DAV methods.
# Same deal with Apple's DAV filesystem and Gnome VFS support for DAV.
#
BrowserMatch "Microsoft Data Access Internet Publishing Provider" redirect-carefully
BrowserMatch "MS FrontPage" redirect-carefully
BrowserMatch "^WebDrive" redirect-carefully
BrowserMatch "^WebDAVFS/1.[0123]" redirect-carefully
BrowserMatch "^gnome-vfs/1.0" redirect-carefully
BrowserMatch "^XML Spy" redirect-carefully
BrowserMatch "^Dreamweaver-WebDAV-SCM1" redirect-carefully

# SSI
${enssi}AddType text/html .shtml
${enssi}AddHandler server-parsed .shtml

EOF


#----------------------------------------------------------------------------------------
# Listen to IP and ports
#----------------------------------------------------------------------------------------
nameIpMixture="no"
hasAsterisk="no"
hasIp="no"
idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    eval ip='$APACHE2_VHOST_'$idx'_IP'
    eval port='$APACHE2_VHOST_'$idx'_PORT'
    eval ssl='$APACHE2_VHOST_'$idx'_SSL'
    eval sslport='$APACHE2_VHOST_'$idx'_SSL_PORT'
    if [ "$active" = "no" ]
    then
        idx=`expr $idx + 1`
        continue
    fi
    ports="$port "
    if [ "$ssl" = "yes" -a "$APACHE2_SSL" = "yes" ]
    then
        if [ ! "x$sslport" = "x" ]
        then
            ports="$port $sslport"
        fi
    fi
    for single_port in $ports
    do
        if [ ! "`echo \"$ipports\" | grep \"$ip:$single_port\"`" ]
        then
            ipports="$ipports $ip:$single_port "
        fi
        if [ "$ip" = "*" ]
        then
            hasAsterisk="yes"
        else
            hasIp="yes"
        fi
    done
    idx=`expr $idx + 1`
done

# check whether there is a mixture of name- and ip-based vhosts
if [ "$hasAsterisk" = "yes" ]
then
    if [ "$hasIp" = "yes" ]
    then
        nameIpMixture="yes"
        if [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPADDR}:${APACHE2_PORT}\"`" ]
        then
            ipports="$ipports ${IP_NET_1_IPADDR}:${APACHE2_PORT} "
        fi
        if [ "$APACHE2_SSL" = "yes" ]
        then
            if [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPADDR}:${APACHE2_SSL_PORT}\"`" ]
            then
                ipports="$ipports ${IP_NET_1_IPADDR}:${APACHE2_SSL_PORT} "
            fi
        fi
    fi
else
    if [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPADDR}:${APACHE2_PORT}\"`" ]
    then
        ipports="$ipports ${IP_NET_1_IPADDR}:${APACHE2_PORT} "
    fi
    if [ "$APACHE2_SSL" = "yes" ]
    then
        if [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPADDR}:${APACHE2_SSL_PORT}\"`" ]
        then
            ipports="$ipports ${IP_NET_1_IPADDR}:${APACHE2_SSL_PORT} "
        fi
    fi
fi

(
# if a vhost active $envhost=""
if [  "$envhost" = "#" ] 
then
    echo "Listen $APACHE2_PORT"
    [ "$APACHE2_SSL" = "yes" ] && echo "Listen $APACHE2_SSL_PORT"
else
    if [ "$nameIpMixture" = "no" ]
    then
        iApacheSslSet=0
        for ipport in $ipports
        do
            echo "Listen $ipport"
            [ ! "$ipport" = "*:${APACHE2_SSL_PORT}" ] && iApacheSslSet=1
        done
        if [ "$APACHE2_SSL" = "yes" -a $iApacheSslSet = 0 ]
        then
            echo "Listen *:$APACHE2_SSL_PORT"
            iApacheSslSet=1
        fi
    else
        echo "Listen $APACHE2_PORT"
        [ "$APACHE2_SSL" = "yes" ] && echo "Listen $APACHE2_SSL_PORT"
    fi
fi

#----------------------------------------------------------------------------------------
# directory setup
#----------------------------------------------------------------------------------------
idx=1
while [ "$idx" -le "$APACHE2_DIR_N" ]
do
    eval active='$APACHE2_DIR_'$idx'_ACTIVE'
    eval useAlias='$APACHE2_DIR_'$idx'_ALIAS'
    eval alias='$APACHE2_DIR_'$idx'_ALIAS_NAME'
    eval path='$APACHE2_DIR_'$idx'_PATH'
    eval auth_name='$APACHE2_DIR_'$idx'_AUTH_NAME'
    eval auth_type='$APACHE2_DIR_'$idx'_AUTH_TYPE'
    eval auth_n='$APACHE2_DIR_'$idx'_AUTH_N'
    eval cgi='$APACHE2_DIR_'$idx'_CGI'
    eval ssi='$APACHE2_DIR_'$idx'_SSI'
    eval access='$APACHE2_DIR_'$idx'_ACCESS_CONTROL'
    eval content='$APACHE2_DIR_'$idx'_VIEW_DIR_CONTENT'
    eval webdav='$APACHE2_DIR_'$idx'_WEBDAV'

    if [ "$active" = "no" ]
    then
        idx=`expr $idx + 1`
        continue
    fi
 
    if [ "$useAlias" = "yes" ]
    then
        echo "Alias $alias $path"
    fi

        #echo "Adding directory $path ..." >`tty`
        echo "<Directory \"${path}\">"
        echo -n '    Options FollowSymLinks MultiViews'
        [ "$ssi" = "yes" ]   && echo -n ' Includes'
        [ "$cgi" != "none" ] && echo -n ' ExecCGI'
        if [ "$content" = "yes" ]
        then
            echo ' Indexes'
        else
            echo
        fi
        [ "$cgi" != "none" ] && echo "    AddHandler cgi-script $cgi"
        if [ "$ssi" = "yes" ]
        then
            echo '    AddType text/html .shtml'
            echo '    AddHandler server-parsed .shtml'
        fi
        if [ "$auth_n" -gt 0 ]
        then
            mkdir -p /etc/apache2/passwd
            if [ "${auth_type}" = "Basic" ]
            then
                echo '    AuthType Basic'
            else
                echo '    AuthType Digest'
                echo "    AuthDigestDomain ${auth_name}"
                echo '    AuthDigestProvider file'
            fi
            echo "    AuthName \"${auth_name}\""
            echo "    AuthUserFile /etc/apache2/passwd/passwords.${idx}"
            echo '    require valid-user'
            rm -f /etc/apache2/passwd/passwords.$idx
            touch /etc/apache2/passwd/passwords.$idx

            idx2=1
            while [ "$idx2" -le "$auth_n" ]
            do
                eval user='$APACHE2_DIR_'$idx'_AUTH_'$idx2'_USER'
                eval pass='$APACHE2_DIR_'$idx'_AUTH_'$idx2'_PASS'

                if [ "${auth_type}" = "Basic" ]
                then
                    /usr/bin/htpasswd -b /etc/apache2/passwd/passwords.${idx} $user $pass 2>/dev/null
                else
                    # hash the username, realm, and password
                    htdigest_hash=`printf "$user:$auth_name:$pass" | md5sum -`
                    # build an htdigest appropriate line, and tack it onto the file
                    echo "${user}:${auth_name}:${htdigest_hash:0:32}" >> /etc/apache2/passwd/passwords.$idx
                fi
                idx2=`expr $idx2 + 1`
            done
            chown -R apache:apache /etc/apache2/passwd
            chmod 700 /etc/apache2/passwd
            chmod 600 /etc/apache2/passwd/*
        fi

        [ "$webdav" = "yes" ] && echo "    Dav on"
        echo '    AllowOverride All'
        echo '    Require all denied'
        echo "    Require $access granted"
        echo '</Directory>'

        if [ ! -d ${path} ]
        then
            mkdir -p ${path}
            echo "<h1>GEHEIM!</h1>" > ${path}/index.html
            chown -R apache:apache ${path}
        fi
    idx=`expr $idx + 1`
done

#----------------------------------------------------------------------------------------
# error setup
#----------------------------------------------------------------------------------------
if [ "$APACHE2_ERROR_DOCUMENT_N" -gt 0 ]
then
    idx=1
    echo "Alias /error/ \"/usr/share/apache2/error/\""
    echo "<IfModule mod_negotiation.c>"
    echo "<IfModule mod_include.c>"
    echo "    <Directory \"/usr/share/apache2/error\">"
    echo "        AllowOverride None"
    echo "        Options IncludesNoExec"
    echo "        AddOutputFilter Includes html"
    echo "        AddHandler type-map var"
    echo "        Order allow,deny"
    echo "        Allow from all"
    echo "        LanguagePriority en de fr"
    echo "        ForceLanguagePriority Prefer Fallback"
    echo "    </Directory>"
    while [ "$idx" -le "$APACHE2_ERROR_DOCUMENT_N" ]
    do
        eval error='$APACHE2_ERROR_DOCUMENT_'$idx'_ERROR'
        eval doc='$APACHE2_ERROR_DOCUMENT_'$idx'_DOCUMENT'
        echo "    ErrorDocument $error $doc"
        idx=`expr $idx + 1`
    done
    echo "</IfModule>"
    echo "</IfModule>"
fi

#----------------------------------------------------------------------------------------
# SSL setup
#----------------------------------------------------------------------------------------
if [ "$APACHE2_SSL" = "yes" ]
then
    if [ $APACHE2_VHOST_N -eq 0 -o "$uses_vhost_atall" = "no" ]
    then
        echo "<VirtualHost _default_:${APACHE2_SSL_PORT}>"
        echo "    ServerName ${APACHE2_SERVER_NAME}:${APACHE2_SSL_PORT}"
        echo '    <Directory \"/var/www/localhost/htdocs\">'
        echo "        Options ${options}"
        echo '        AllowOverride All'
        echo '        Order allow,deny'
        echo "        Allow from ${APACHE2_ACCESS_CONTROL}"
        echo '    </Directory>'
        echo "    SSLEngine On"
        echo "    SSLCipherSuite ALL:!ADH:!EXP56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP:+eNULL"
        echo "    SSLCertificateFile /etc/ssl/certs/apache.pem"
        echo "    SSLCertificateKeyFile /etc/ssl/private/apache.key"
        echo '    <Files ~ \"\.(pl|cgi|shtml|phtml|php?)$\">'
        echo '        SSLOptions +StdEnvVars'
        echo '    </Files>'
        echo '    <Directory \"/var/www/cgi-bin\">'
        echo '        SSLOptions +StdEnvVars'
        echo '    </Directory>'
        echo '    SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0'
        echo '    CustomLog /var/log/apache2/ssl_request.log "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"'
        echo '</VirtualHost>'
    fi
fi


#----------------------------------------------------------------------------------------
# VHost setup
#----------------------------------------------------------------------------------------
if [ "$APACHE2_VHOST_N" -gt 0 ]
then
    echo ""
    idx=1
    anyVHostActive="no"
    anyVHostSSLActive="no"
    while [ "$idx" -le "$APACHE2_VHOST_N" ]
    do
        eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
        eval ssl='$APACHE2_VHOST_'$idx'_SSL'
        [ "$active" = "yes" ] && anyVHostActive="yes"
        [ "$ssl" = "yes" ]    && anyVHostSSLActive="yes"
        idx=`expr $idx + 1`
    done
    if [ "$anyVHostActive" = "yes" ]
    then
        for ipport in $ipports
        do
            echo "NameVirtualHost $ipport"
        done
    fi
fi

idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    eval ip='$APACHE2_VHOST_'$idx'_IP'
    eval port='$APACHE2_VHOST_'$idx'_PORT'
    eval servername='$APACHE2_VHOST_'$idx'_SERVER_NAME'
    eval serveralias='$APACHE2_VHOST_'$idx'_SERVER_ALIAS'
    eval mail='$APACHE2_VHOST_'$idx'_SERVER_ADMIN'
    eval docroot='$APACHE2_VHOST_'$idx'_DOCUMENT_ROOT'
    eval scriptalias='$APACHE2_VHOST_'$idx'_SCRIPT_ALIAS'
    eval scriptdir='$APACHE2_VHOST_'$idx'_SCRIPT_DIR'
    eval accesscontrol='$APACHE2_VHOST_'$idx'_ACCESS_CONTROL'
    eval content='$APACHE2_VHOST_'$idx'_VIEW_DIRECTORY_CONTENT'
    eval ssi='$APACHE2_VHOST_'$idx'_ENABLE_SSI'
    eval modcache='$APACHE2_VHOST_'$idx'_MOD_CACHE'
    eval ssl='$APACHE2_VHOST_'$idx'_SSL'
    eval sslport='$APACHE2_VHOST_'$idx'_SSL_PORT'
    eval forcessl='$APACHE2_VHOST_'$idx'_SSL_FORCE'
    eval sslcertname='$APACHE2_VHOST_'$idx'_SSL_CERT_NAME'
    errorlog="/var/log/apache2/error-${servername}.log"
    accesslog="/var/log/apache2/access-${servername}.log" 

    if [ "$active" != "yes" ]
    then
        idx=`expr $idx + 1`
        continue
    fi

    if [ ! -d ${docroot} ]
    then
        mkdir -p ${docroot}
        {
            echo "<html><body><h1>Der VirtualHost <em>$servername</em> wurde erfolgreich eingerichtet!</h1>"
            echo "HTML-Dateien muessen nach <em>$docroot</em> geladen werden, CGI-Scripts nach <i>$scriptdir</i>.<br>"
            echo "Die Access-Logfile ist <em>$accesslog</em><br>"
            echo "Die Error-Logfile ist <em>$errorlog</em><p>"
            echo "Zugriff auf diesen VirtualHost hat <em>$accesscontrol</em>"
            echo "<h1>The VirtualHost <em>$servername</em> was created succesfully!</h1>"
            echo "HTML files must be loaded into <em>$docroot</em>, the CGI-Scripts into <em>$scriptdir</em>.<br>"
            echo "The access logfile is <em>$accesslog</em><br>"
            echo "The error logfile is <em>$errorlog</em><p>"
            echo "Access to this VirtualHost has <em>$accesscontrol</em></body></html>"
        } > ${docroot}/index.html        
        chown apache:apache -R ${docroot}
    fi
    if [ ! -d ${scriptdir} ]
    then
        mkdir -p ${scriptdir}
        chown apache:apache ${scriptdir}
    fi
    echo ""
    echo "<VirtualHost $ip:$port>"
    echo "    ServerName $servername:$port"
    [ "x$serveralias" != "x" ] && echo "    ServerAlias $serveralias"
    echo "    ServerAdmin $mail"
    echo "    DocumentRoot $docroot"
    echo "    ScriptAlias $scriptalias $scriptdir"
    if [ "$modcache" = "yes" ] 
    then
        echo "    CacheEnable mem /"
        echo "    <IfModule mod_cache_disk.c>"
        echo "        CacheEnable disk /"
        echo "    </IfModule>"
    else    
        [ "$APACHE2_MOD_CACHE" = "yes" ] && echo "    CacheDisable /"
    fi
    echo "    <Directory \"${scriptdir}\">"
    echo '        AllowOverride All'
    echo '        Options None'
    echo '        Order allow,deny'
    echo "        Allow from ${accesscontrol}"
    echo '    </Directory>'

    options="FollowSymLinks MultiViews"
    [ "$ssi" = "yes" ]     && options="$options Includes"
    [ "$content" = "yes" ] && options="$options Indexes"

    echo "    <Directory \"${docroot}\">"
    echo '        AllowOverride All'
    echo "        Options ${options}"
    echo '        Order allow,deny'
    echo "        Allow from ${accesscontrol}"
    echo '    </Directory>'

    if [ "$APACHE2_SSL" = "yes" -a "$ssl" = "yes" -a "$forcessl" = "yes" ]
    then
        echo "    Redirect permanent / https://${servername}:${sslport}/"
    fi

    echo "    ErrorLog $errorlog"
    echo "    CustomLog $accesslog combined"

    #################################
    createVHostDirDirective
    #################################
    echo "</VirtualHost>"

    ### SSL VIRTUALHOST
    [ -z "$sslcertname" ] && sslcertname="apache"

    if [ "$APACHE2_SSL" = "yes" -a "$ssl" = "yes" ]
    then
        echo "<VirtualHost "$ip":"$sslport">"
        echo '    SSLEngine On'
        echo '    SSLCipherSuite ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP:+eNULL'
        echo "    SSLCertificateFile /etc/ssl/certs/${sslcertname}.pem"
        echo "    SSLCertificateKeyFile /etc/ssl/private/${sslcertname}.key"
        echo '    <Files ~ "\.(pl|cgi|shtml|phtml|php|php?)$">'
        echo '        SSLOptions +StdEnvVars'
        echo '    </Files>'
        echo "    <Directory \"${docroot}\">"
        echo "        AllowOverride All"
        echo "        Options ${options}"
        echo '        Order allow,deny'
        echo "        Allow from ${accesscontrol}"
        echo '    </Directory>'
        echo "    <Directory \"${scriptdir}\">"
        echo "        SSLOptions +StdEnvVars"
        echo "    </Directory>"
        echo '    SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0'
        echo "    ServerName ${servername}:${sslport}"
        [ -n "$serveralias" != "" ] && echo "    ServerAlias ${serveralias}"
        echo "    ServerAdmin ${mail}"
        echo "    DocumentRoot ${docroot}"
        echo "    ScriptAlias ${scriptalias} ${scriptdir}"
        echo "    ErrorLog ${errorlog}.ssl"
        echo "    CustomLog ${accesslog}.ssl combined"
        #################################
        createVHostDirDirective
        #################################
        echo '</VirtualHost>'

        (
        if [ ! -f /etc/ssl/certs/${sslcertname}.pem ]
        then
            echo "* The certificate $sslcertname doesn't exist"
            if /var/install/bin/ask "Do you want to create it now"
            then
                echo "Creating $sslcertname.pem"
                echo "Notice: The Common Name (you will type it in a moment) has to be the ServerName!"
                /var/install/bin/certs-create-tls-certs web batch alternate "$sslcertname" "$servername"
            fi
        fi
        )>`tty`
    fi

    idx=`expr $idx + 1`
done
) >>/etc/apache2/httpd.conf

#----------------------------------------------------------------------------------------
# setup logrotate
#----------------------------------------------------------------------------------------
cat >> /etc/logrotate.d/apache2 <<EOF
/var/log/apache2/*log {
    ${APACHE2_LOG_INTERVAL}
    missingok
	rotate ${APACHE2_LOG_COUNT}
    notifempty
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet apache2 reload > /dev/null 2>/dev/null || true
    endscript
}
EOF

# -------------------------------------------------------------------------
# Add logfile view menu
# -------------------------------------------------------------------------
# remove _all_ apache2 logfile entries
grep -vE ".*>Show apache .*" /var/install/menu/setup.system.logfileview.menu >/tmp/setup.system.logfileview.menu.$$
cp -f /tmp/setup.system.logfileview.menu.$$ /var/install/menu/setup.system.logfileview.menu     # don't mv, keep permissions
rm -f /tmp/setup.system.logfileview.menu.$$
    
/var/install/bin/add-menu --script setup.system.logfileview.menu "/var/install/bin/show-doc.cui -f /var/log/apache2/access.log" "Show apache access"
/var/install/bin/add-menu --script setup.system.logfileview.menu "/var/install/bin/show-doc.cui -f /var/log/apache2/error.log" "Show apache error"

idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    if [ "$active" = "yes" ]
    then
        eval servername='$APACHE2_VHOST_'$idx'_SERVER_NAME'
        errorlog="/var/log/apache2/error-${servername}.log"
        accesslog="/var/log/apache2/access-${servername}.log"
        /var/install/bin/add-menu --script setup.system.logfileview.menu "/var/install/bin/show-doc.cui -f $accesslog" "Show apache access $servername"
        /var/install/bin/add-menu --script setup.system.logfileview.menu "/var/install/bin/show-doc.cui -f $errorlog" "Show apache error $servername"
    fi
    idx=`expr $idx + 1`
done

exit 0
