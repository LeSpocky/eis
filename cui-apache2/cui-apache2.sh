#!/bin/sh
#-------------------------------------------------------------------------------
# Eisfair configuration generator script for Apache
# Copyright (c) 2007 - 2016 the eisfair team, team(at)eisfair(dot)org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#-------------------------------------------------------------------------------

### require packages: ###
# apache2
# apache2-ssl     (install on script)
# apache2-webdav  (install on script)


#echo "Executing $0 ..."
#exec 2> /tmp/apache2-trace$$.log
#set -x

pgmname=$0

chmod 600 /etc/config.d/apache2

. /etc/config.d/apache2
# include base config for get ip setting
. /etc/config.d/base

# ------------------------------------------------------------------------------
# force reinstall default apache config
# ------------------------------------------------------------------------------
rm -f /etc/apache2/httpd.conf
rm -f /etc/apache2/httpd.conf.apk-new
apk fix -r apache2


# ------------------------------------------------------------------------------
# create error message if packages not installed
# ------------------------------------------------------------------------------
errorsyslog()
{
    local tmp="Fail install: $1"
    logger -p error -t cui-apache2 "$tmp"
    echo "$tmp"
}


# ------------------------------------------------------------------------------
# function for dir access (host and vhosts)
# ------------------------------------------------------------------------------
create_dir_access() {
    local vhostnr="$1"
    local vhost=""
    local nmax=0
    local idx=1
    local idx2=1
    local useAlias=""
    local alias=""
    local path=""
    local auth_name=""
    local auth_type=""
    local auth_n=""
    local cgi=""
    local ssi=""
    local access=""
    local content=""
    local webdav=""
    local user=""
    local pass=""

    [ $vhostnr -gt 0 ] && vhost="VHOST_${vhostnr}_"

    eval nmax='$APACHE2_'${vhost}'DIR_N'
    while [ "$idx" -le "$nmax" ]
    do
        eval active='$APACHE2_'$vhost'DIR_'$idx'_ACTIVE'
        if [ "$active" = "no" ] ; then
            idx=$((idx+1))
            continue
        fi
        eval useAlias='$APACHE2_'$vhost'DIR_'$idx'_ALIAS'
        eval alias='$APACHE2_'$vhost'DIR_'$idx'_ALIAS_NAME'
        eval path='$APACHE2_'$vhost'DIR_'$idx'_PATH'
        eval auth_name='$APACHE2_'$vhost'DIR_'$idx'_AUTH_NAME'
        eval auth_type='$APACHE2_'$vhost'DIR_'$idx'_AUTH_TYPE'
        eval auth_n='$APACHE2_'$vhost'DIR_'$idx'_AUTH_N'
        eval cgi='$APACHE2_'$vhost'DIR_'$idx'_CGI'
        eval ssi='$APACHE2_'$vhost'DIR_'$idx'_SSI'
        eval access='$APACHE2_'$vhost'DIR_'$idx'_ACCESS_CONTROL'
        eval content='$APACHE2_'$vhost'DIR_'$idx'_VIEW_DIR_CONTENT'
        eval webdav='$APACHE2_'$vhost'DIR_'$idx'_WEBDAV'

        [ "$access" = "all" ] && access="all granted"
        [ "$useAlias" = "yes" ] && echo "Alias $alias $path"
        echo "<Directory \"$path\">"
        echo -n "    Options FollowSymLinks MultiViews"
        [ "$ssi" = "yes" ]   && echo -n " Includes"
        [ "$cgi" != "none" ] && echo -n " ExecCGI"
        if [ "$content" = "yes" ] ; then
            echo " Indexes"
        else
            echo ""
        fi
        [ "$cgi" != "none" ] && echo "    AddHandler cgi-script $cgi"
        if [ "$ssi" = "yes" ] ; then
            echo "    AddType text/html .shtml"
            echo "    AddHandler server-parsed .shtml"
        fi
        if [ "$auth_n" -gt 0 ] ; then
            echo "    AuthName \"${auth_name}\""
            if [ "$auth_type" = "Basic" ] ; then
                echo "    AuthType Basic"
                echo "    AuthBasicProvider file"
            else
                echo "    AuthType Digest"
                echo "    AuthDigestProvider file"
            fi
            echo "    AuthUserFile /etc/apache2/passwd/passwords.${vhostnr}-${idx}"
            echo "    <RequireAll>"
            echo "        Require valid-user"
            echo "        Require $access"
            echo "    </RequireAll>"

            # create password file
            mkdir -p /etc/apache2/passwd
            echo -n "" > /etc/apache2/passwd/passwords.${vhostnr}-${idx}
            idx2=1
            while [ "$idx2" -le "$auth_n" ]
            do
                eval user='$APACHE2_'$vhost'DIR_'$idx'_AUTH_'$idx2'_USER'
                eval pass='$APACHE2_'$vhost'DIR_'$idx'_AUTH_'$idx2'_PASS'
                if [ "${auth_type}" = "Basic" ] ; then
                    /usr/bin/htpasswd -b /etc/apache2/passwd/passwords.${vhostnr}-${idx} $user $pass 2>/dev/null
                else
                    # hash the username, realm, and password
                    htdigest_hash=`printf "$user:$auth_name:$pass" | md5sum -`
                    # build an htdigest appropriate line, and tack it onto the file
                    echo "${user}:${auth_name}:${htdigest_hash:0:32}" >> /etc/apache2/passwd/passwords.${vhostnr}-${idx}
                fi
                idx2=`expr $idx2 + 1`
            done
            chown -R apache:apache /etc/apache2/passwd
            chmod 700 /etc/apache2/passwd
            chmod 600 /etc/apache2/passwd/*

            if [ ! -d ${path} ] ; then
                mkdir -p ${path}
                echo "<h1>GEHEIM!</h1>" > ${path}/index.html
                chown -R apache:www-data ${path}
            fi
        else
            echo "    Require $access"
        fi
        [ "$webdav" = "yes" ] && echo "    Dav on"
        echo "    AllowOverride All"
        echo "</Directory>"
        idx=$((idx+1))
    done
}



# read dhcp leases
#if [ "$IP_NET_1_STATIC_IP" = "no" ] ; then
#    leasefile=/var/lib/dhcp3/dhclient.eth0.leases
#    if [ -f $leasefile ] ; then
#        IP_NET_1_IPV4_IPADDR=`grep fixed-address $leasefile | awk 'BEGIN { RS=""; FS="\n"} {print $NF}' | sed 's#[^0-9.]##g'`
#    fi
#fi


#if [ ! -f /etc/ssl/certs/apache.pem -a "$APACHE2_SSL" = "yes" ] ; then
#    echo "* Creating CA for SSL ..."
#    /var/install/bin/certs-create-tls-certs ca batch
#    echo "* Creating apache.pem"
#    echo "* Notice: The Common Name (you will type it in a moment) has to be the ServerName!"
#    /var/install/bin/certs-create-tls-certs web batch alternate "apache" "$APACHE2_SERVER_NAME"
#fi


#-------------------------------------------------------------------------------
# activate content of /home/USER/public_html
#-------------------------------------------------------------------------------
enuser="#"
[ "$APACHE2_ENABLE_USERDIR" = "yes" ] && enuser=""


#-------------------------------------------------------------------------------
# activate diskcache and vhosts 
#-------------------------------------------------------------------------------
encache="#"
envhost="#"
uses_vhost_atall="no"
# cache for doc root:
[ "$APACHE2_MOD_CACHE" = "yes" ] && encache=""
idx=0
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval vhostact='$APACHE2_VHOST_'$idx'_ACTIVE'
    if [ "$vhostact" = "yes" ] ; then
        envhost=""
        uses_vhost_atall="yes"
        eval modcache='$APACHE2_VHOST_'$idx'_MOD_CACHE'
        [ "$modcache" = "yes" ] && encache=""
    fi
    idx=$((idx+1))
done


#-------------------------------------------------------------------------------
# activate ssl 
#-------------------------------------------------------------------------------
enssl="#"
if [ "$APACHE2_SSL" = "yes" ]; then
    enssl=""
    apk info -q -e apache2-ssl || apk add -q apache2-ssl
    # move cache from /run to /var
    mkdir -p /var/cache/mod_ssl
    chown -R apache:apache /var/cache/mod_ssl
    # fix buggi ssl.conf (path is modules not lib!)
    cat > /etc/apache2/conf.d/ssl.conf <<EOF
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
LoadModule ssl_module   modules/mod_ssl.so

SSLRandomSeed startup   file:/dev/urandom 512
SSLRandomSeed connect   builtin

SSLCipherSuite          HIGH:MEDIUM:!MD5:!RC4:!ADH
SSLProxyCipherSuite     HIGH:MEDIUM:!MD5:!RC4:!ADH

SSLHonorCipherOrder     on

SSLProtocol             all -SSLv3
SSLProxyProtocol        all -SSLv3

SSLPassPhraseDialog     builtin

SSLSessionCache         shmcb:/var/cache/mod_ssl/scache(512000)
SSLSessionCacheTimeout  300

EOF
else
    rm -f /etc/apache2/conf.d/ssl.conf*
    rm -rf /var/cache/mod_ssl
    apk del -q apache2-ssl
fi


#-------------------------------------------------------------------------------
# activate webdav 
#-------------------------------------------------------------------------------
endav="#"
idx=1
while [ "$idx" -le "$APACHE2_DIR_N" ]
do
    eval webdav='$APACHE2_DIR_'$idx'_WEBDAV'
    if [ "$webdav" = "yes" ] ; then
        endav=""
        break
    fi
    idx=$((idx+1))
done
vidx=1
while [ "$vidx" -le "$APACHE2_VHOST_N" ]
do
    eval activevhost='$APACHE2_VHOST_'$vidx'_ACTIVE'
    if [ "$activevhost" = "yes" ] ; then
        idx=1
        eval tmpidx='$APACHE2_VHOST_'$vidx'_DIR_N'
        while [ "$idx" -le "$tmpidx" ]
        do
            eval webdav='$APACHE2_VHOST_'$vidx'_DIR_'$idx'_WEBDAV'
            if [ "$webdav" = "yes" ] ; then
                endav=""
                break
            fi
            idx=$((idx+1))
        done
    fi
    [ "$webdav" = "yes" ] && break
    vidx=`expr $vidx + 1`
done

if [ -z "$endav" ] ; then
    mkdir -p /var/www/var
    chown apache /var/www/var
    apk info -q -e apache2-webdav || apk add -q apache2-webdav
    [ $? -eq 0 ] || errorsyslog apache2-webdav
    rm -f /etc/apache2/conf.d/http-dav.conf
fi


#-------------------------------------------------------------------------------
# use SSI
#-------------------------------------------------------------------------------
enssi="#"
[ "$APACHE2_ENABLE_SSI" = "yes" ] && enssi=""


#-------------------------------------------------------------------------------
# Enable negotiation
#-------------------------------------------------------------------------------
enneg="#"
[ "$APACHE2_ERROR_DOCUMENT_N" -gt 0 ] && enneg=""


#-------------------------------------------------------------------------------
# change access from (Allow from all) to (Require all granted)
#-------------------------------------------------------------------------------
[ "$APACHE2_ACCESS_CONTROL" = "all" ] && APACHE2_ACCESS_CONTROL="all granted"


#-------------------------------------------------------------------------------
# change directory options
#-------------------------------------------------------------------------------
apache_options="FollowSymLinks MultiViews"
[ "$APACHE2_VIEW_DIRECTORY_CONTENT" = "yes" ] && apache_options="$apache_options Indexes"
[ "$APACHE2_ENABLE_SSI" = "yes" ]             && apache_options="$apache_options Includes"

hnlookup='Off'
[ "$APACHE2_HOSTNAME_LOOKUPS" = "yes" ] && hnlookup='On'


################################################################################
# write eisfair config
################################################################################
rm -f /etc/apache2/conf.d/*eisfair*.conf
cat > /etc/apache2/conf.d/alpine-eisfair.conf <<EOF
#-------------------------------------------------------------------------------
# eisfair-ng apache configuration file, generated by eis CUI script
# load missing modules:
#-------------------------------------------------------------------------------
${encache}LoadModule cache_module modules/mod_cache.so
${encache}LoadModule cache_disk_module modules/mod_cache_disk.so
${enssi}LoadModule include_module modules/mod_include.so
${enneg}LoadModule negotiation_module modules/mod_negotiation.so
LoadModule rewrite_module modules/mod_rewrite.so
${enuser}LoadModule userdir_module modules/mod_userdir.so
${envhost}LoadModule vhost_alias_module modules/mod_vhost_alias.so
${endav}LoadModule dav_module modules/mod_dav.so
${endav}LoadModule dav_fs_module modules/mod_dav_fs.so
${endav}LoadModule dav_lock_module modules/mod_dav_lock.so

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

# Offload old DirectoryIndex for php first!
DirectoryIndex disabled

EOF

cat > /etc/apache2/conf.d/zero-eisfair.conf <<EOF
#-------------------------------------------------------------------------------
# eisfair-ng overwrite apache configuration file, generated by eis CUI script
#-------------------------------------------------------------------------------
# prefork MPM
<IfModule prefork.c>
    ServerLimit      ${APACHE2_MAX_CLIENTS}
    MaxClients       ${APACHE2_MAX_CLIENTS}
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>
 
# itk MPM
<IfModule itk.c>
    AssignUserID apache apache
    ServerLimit      ${APACHE2_MAX_CLIENTS}
    MaxClients       ${APACHE2_MAX_CLIENTS}
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>

# worker MPM
<IfModule worker.c>
    MaxClients          ${APACHE2_MAX_CLIENTS}
    MaxRequestsPerChild ${APACHE2_MAX_REQUESTS_PER_CHILD}
</IfModule>

MaxKeepAliveRequests ${APACHE2_MAX_KEEP_ALIVE_REQUESTS}
KeepAliveTimeout ${APACHE2_MAX_KEEP_ALIVE_TIMEOUT}
ServerAdmin  ${APACHE2_SERVER_ADMIN}
ServerName   ${APACHE2_SERVER_NAME}:${APACHE2_PORT}
UseCanonicalName Off
DirectoryIndex ${APACHE2_DIRECTORY_INDEX}

HostnameLookups ${hnlookup}
#ErrorLog /var/log/apache2/error.log
LogLevel ${APACHE2_LOG_LEVEL}
#LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
#SetEnvIf Remote_Addr "127\.0\.0\.1" dontlog
#CustomLog /var/log/apache2/access.log combined env=!dontlog
ServerTokens Minor
ServerSignature ${APACHE2_SERVER_SIGNATURE}

# overwrite default httpd.conf
DocumentRoot "/var/www/localhost/htdocs"
<Directory "/var/www/localhost/htdocs">
    Options ${apache_options}
    AllowOverride All
    Require ${APACHE2_ACCESS_CONTROL} 
</Directory>

IndexOptions FancyIndexing VersionSort NameWidth=* HTMLTable Charset=UTF-8
IndexIgnore .??* *~ *# HEADER* README* RCS CVS *,v *,t

# SSI
${enssi}AddType text/html .shtml
${enssi}AddHandler server-parsed .shtml

EOF


#-------------------------------------------------------------------------------
# Listen to IP and ports
#-------------------------------------------------------------------------------
nameIpMixture="no"
hasAsterisk="no"
hasIp="no"
idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    if [ "$active" = "no" ] ; then
        idx=$((idx+1))
        continue
    fi
    eval ip='$APACHE2_VHOST_'$idx'_IP'
    eval port='$APACHE2_VHOST_'$idx'_PORT'
    eval ssl='$APACHE2_VHOST_'$idx'_SSL'
    eval sslport='$APACHE2_VHOST_'$idx'_SSL_PORT'

    ports="$port "
    if [ "$ssl" = "yes" -a "$APACHE2_SSL" = "yes" ] ; then
        [ ! "x$sslport" = "x" ] && ports="$port $sslport"
    fi
    for single_port in $ports
    do
        # add if not found
        [ ! "`echo \"$ipports\" | grep \"$ip:$single_port\"`" ] && ipports="$ipports $ip:$single_port "
        # use asterisk
        if [ "$ip" = "*" ] ; then
            hasAsterisk="yes"
        else
            hasIp="yes"
        fi
    done
    idx=$((idx+1))
done

# check whether there is a mixture of name- and ip-based vhosts
[ "$hasAsterisk" = "yes" -a "$hasIp" = "yes" ] && nameIpMixture="yes"
if [ "$nameIpMixture" = "yes" ] ; then
    [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPV4_IPADDR}:${APACHE2_PORT}\"`" ] && ipports="$ipports ${IP_NET_1_IPV4_IPADDR}:${APACHE2_PORT} "
    if [ "$APACHE2_SSL" = "yes" ] ; then
        [ ! "`echo \"$ipports\" | grep \"${IP_NET_1_IPV4_IPADDR}:${APACHE2_SSL_PORT}\"`" ] && ipports="$ipports ${IP_NET_1_IPV4_IPADDR}:${APACHE2_SSL_PORT} "
    fi
else
    [ ! "`echo \"$ipports\" | grep \"*:${APACHE2_PORT}\"`" ] && ipports="$ipports *:${APACHE2_PORT} "
    if [ "$APACHE2_SSL" = "yes" ] ; then
        [ ! "`echo \"$ipports\" | grep \"*:${APACHE2_SSL_PORT}\"`" ] && ipports="$ipports *:${APACHE2_SSL_PORT} "
    fi
fi


################################################################################
# add following output to config file: 
################################################################################
(
# if a vhost active $envhost=""
if [  "$envhost" = "#" ] ; then
    echo "Listen $APACHE2_PORT"
    [ "$APACHE2_SSL" = "yes" ] && echo "Listen $APACHE2_SSL_PORT"
else
    if [ "$nameIpMixture" = "no" ] ; then
        iApacheSslSet=0
        for ipport in $ipports
        do
            echo "Listen $ipport"
            [ ! "$ipport" = "*:${APACHE2_SSL_PORT}" ] && iApacheSslSet=1
        done
        if [ "$APACHE2_SSL" = "yes" -a $iApacheSslSet = 0 ] ; then
            echo "Listen *:$APACHE2_SSL_PORT"
            iApacheSslSet=1
        fi
    else
        echo "Listen $APACHE2_PORT"
        [ "$APACHE2_SSL" = "yes" ] && echo "Listen $APACHE2_SSL_PORT"
    fi
fi
echo ""


#-------------------------------------------------------------------------------
# directory setup
#-------------------------------------------------------------------------------
create_dir_access 0


#-------------------------------------------------------------------------------
# error setup
#-------------------------------------------------------------------------------
if [ "$APACHE2_ERROR_DOCUMENT_N" -gt 0 ] ; then
    idx=1
    echo "Alias /error/ \"/usr/share/apache2/error/\""
    echo "<IfModule mod_negotiation.c>"
    echo "<IfModule mod_include.c>"
    echo "    <Directory \"/usr/share/apache2/error\">"
    echo "        AllowOverride None"
    echo "        Options IncludesNoExec"
    echo "        AddOutputFilter Includes html"
    echo "        AddHandler type-map var"
    echo "        Require all granted"
    echo "        LanguagePriority en de fr"
    echo "        ForceLanguagePriority Prefer Fallback"
    echo "    </Directory>"
    while [ "$idx" -le "$APACHE2_ERROR_DOCUMENT_N" ]
    do
        eval error='$APACHE2_ERROR_DOCUMENT_'$idx'_ERROR'
        eval doc='$APACHE2_ERROR_DOCUMENT_'$idx'_DOCUMENT'
        echo "    ErrorDocument $error $doc"
        idx=$((idx+1))
    done
    echo "</IfModule>"
    echo "</IfModule>"
fi


#-------------------------------------------------------------------------------
# SSL setup
#-------------------------------------------------------------------------------
if [ "$APACHE2_SSL" = "yes" ] ; then
    if [ $APACHE2_VHOST_N -eq 0 -o "$uses_vhost_atall" = "no" ] ; then
        echo "<VirtualHost _default_:${APACHE2_SSL_PORT}>"
        echo "    ServerName ${APACHE2_SERVER_NAME}:${APACHE2_SSL_PORT}"
        echo "    <Directory \"/var/www/localhost/htdocs\">"
        echo "        Options ${apache_options}"
        echo "        AllowOverride All"
        echo "        Require ${APACHE2_ACCESS_CONTROL}"
        echo "    </Directory>"
        echo "    SSLEngine On"
        echo "    SSLCipherSuite ALL:!ADH:!EXP56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP:+eNULL"
        echo "    SSLCertificateFile /etc/ssl/certs/apache.pem"
        echo "    SSLCertificateKeyFile /etc/ssl/private/apache.key"
        echo '    <Files ~ "\.(pl|cgi|shtml|phtml|php?)$">'
        echo "        SSLOptions +StdEnvVars"
        echo "    </Files>"
        echo "    <Directory \"/var/www/cgi-bin\">"
        echo "        SSLOptions +StdEnvVars"
        echo "    </Directory>"
        echo '    SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0'
        echo '    CustomLog /var/log/apache2/ssl_request.log "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"'
        echo "</VirtualHost>"
    fi
fi


#-------------------------------------------------------------------------------
# VHost setup
#-------------------------------------------------------------------------------
idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    if [ "$active" != "yes" ] ; then
        idx=$((idx+1))
        continue
    fi
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
    [ "$accesscontrol" = "all" ] && accesscontrol="all granted"

    echo ""
    echo "<VirtualHost $ip:$port>"
    echo "    ServerName $servername:$port"
    [ "x$serveralias" != "x" ] && echo "    ServerAlias $serveralias"
    echo "    ServerAdmin $mail"
    echo "    DocumentRoot $docroot"
    echo "    ScriptAlias $scriptalias $scriptdir"
    if [ "$modcache" = "yes" ] ; then
        echo "    CacheEnable mem /"
        echo "    <IfModule mod_cache_disk.c>"
        echo "        CacheEnable disk /"
        echo "    </IfModule>"
    else    
        [ "$APACHE2_MOD_CACHE" = "yes" ] && echo "    CacheDisable /"
    fi
    echo "    <Directory \"${scriptdir}\">"
    echo "        AllowOverride All"
    echo "        Options None"
    echo "        Require ${accesscontrol}"
    echo "    </Directory>"

    vhost_options="FollowSymLinks MultiViews"
    [ "$ssi" = "yes" ]     && vhost_options="$vhost_options Includes"
    [ "$content" = "yes" ] && vhost_options="$vhost_options Indexes"

    echo "    <Directory \"${docroot}\">"
    echo "        AllowOverride All"
    echo "        Options ${vhost_options}"
    echo "        Require ${accesscontrol}"
    echo "    </Directory>"

    if [ "$APACHE2_SSL" = "yes" -a "$ssl" = "yes" -a "$forcessl" = "yes" ] ; then
        echo "    Redirect permanent / https://${servername}:${sslport}/"
    fi

    echo "    ErrorLog $errorlog"
    echo "    CustomLog $accesslog combined"

    #################################
    create_dir_access  $idx
    #################################
    echo "</VirtualHost>"

    ### SSL VIRTUALHOST
    [ -z "$sslcertname" ] && sslcertname="apache"

    if [ "$APACHE2_SSL" = "yes" -a "$ssl" = "yes" ] ; then
        echo "<VirtualHost ${ip}:${sslport} >"
        echo "    SSLEngine On"
        echo "    SSLCipherSuite ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP:+eNULL"
        echo "    SSLCertificateFile /etc/ssl/certs/${sslcertname}.pem"
        echo "    SSLCertificateKeyFile /etc/ssl/private/${sslcertname}.key"
        echo '    <Files ~ "\.(pl|cgi|shtml|phtml|php|php?)$">'
        echo "        SSLOptions +StdEnvVars"
        echo "    </Files>"
        echo "    <Directory \"${docroot}\">"
        echo "        AllowOverride All"
        echo "        Options ${vhost_options}"
        echo "        Require ${accesscontrol}"
        echo "    </Directory>"
        echo "    <Directory \"${scriptdir}\">"
        echo "        SSLOptions +StdEnvVars"
        echo "    </Directory>"
        echo '    SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0'
        echo "    ServerName ${servername}:${sslport}"
        [ -n "$serveralias" ] && echo "    ServerAlias ${serveralias}"
        echo "    ServerAdmin ${mail}"
        echo "    DocumentRoot ${docroot}"
        echo "    ScriptAlias ${scriptalias} ${scriptdir}"
        echo "    ErrorLog ${errorlog}.ssl"
        echo "    CustomLog ${accesslog}.ssl combined"
        #################################
        create_dir_access  $idx
        #################################
        echo "</VirtualHost>"

#        (
#        if [ ! -f /etc/ssl/certs/${sslcertname}.pem ] ; then
#            echo "* The certificate $sslcertname doesn't exist" 
#            if /var/install/bin/ask "Do you want to create it now" ; then
#                echo "Creating $sslcertname.pem"
#                echo "Notice: The Common Name (you will type it in a moment) has to be the ServerName!"
#                /var/install/bin/certs-create-tls-certs web batch alternate "$sslcertname" "$servername"
#            fi
#        fi
#        )>`tty`
    fi

    # create default path and index.html file
    if [ ! -d ${docroot} ] ; then
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
        chown apache:www-data -R ${docroot}
    fi
    if [ ! -d ${scriptdir} ] ; then
        mkdir -p ${scriptdir}
        chown apache:www-data ${scriptdir}
    fi

    idx=$((idx+1))
done

if [ -z "$envhost" ] ; then
    # create default vhost
    echo ""
    echo "<VirtualHost _default_:${APACHE2_PORT}>"    
    echo "    DocumentRoot /var/www/localhost/htdocs"
    echo "    Options ${apache_options}"
    echo "</VirtualHost>"
fi

) >>/etc/apache2/conf.d/zero-eisfair.conf


################################################################################
# setup logrotate
################################################################################
rm -f /etc/logrotate.d/apache2.*
cat > /etc/logrotate.d/apache2 <<EOF
/var/log/apache2/*log {
    ${APACHE2_LOG_INTERVAL}
    missingok
    rotate ${APACHE2_LOG_COUNT}
    notifempty
    create 0644
    sharedscripts
    delaycompress
    postrotate
        /sbin/rc-service --quiet apache2 reload > /dev/null 2>/dev/null || true
    endscript
}
EOF


################################################################################
# Add logfile view menu
################################################################################
# remove _all_ apache2 logfile entries
grep -vE ".*>Show apache .*" /var/install/menu/setup.system.logfileview.menu >/tmp/setup.system.logfileview.menu.$$
cp -f /tmp/setup.system.logfileview.menu.$$ /var/install/menu/setup.system.logfileview.menu     # don't mv, keep permissions
rm -f /tmp/setup.system.logfileview.menu.$$

/var/install/bin/add-menu --logfile setup.system.logfileview.menu "/var/log/apache2/access.log" "Show apache access"
/var/install/bin/add-menu --logfile setup.system.logfileview.menu "/var/log/apache2/error.log" "Show apache error"

# fix log-directory for run logrotate!
chmod 0755 /var/log/apache2
chown apache:www-data /var/log/apache2

idx=1
while [ "$idx" -le "$APACHE2_VHOST_N" ]
do
    eval active='$APACHE2_VHOST_'$idx'_ACTIVE'
    if [ "$active" = "yes" ] ; then
        eval servername='$APACHE2_VHOST_'$idx'_SERVER_NAME'
        errorlog="/var/log/apache2/error-${servername}.log"
        accesslog="/var/log/apache2/access-${servername}.log"
        /var/install/bin/add-menu --logfile setup.system.logfileview.menu "$accesslog" "Show apache access $servername"
        /var/install/bin/add-menu --logfile setup.system.logfileview.menu "$errorlog" "Show apache error $servername"
    fi
    idx=$((idx+1))
done

exit 0
