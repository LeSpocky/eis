#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/cui-phpmyadmin.sh - phpMyAdmin configuration
#
# Creation:     2006-09-15 starwarsfan
#
# Copyright (c) 2006--2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Yves Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2>/tmp/phpmyadmin-trace$$.log
#set -x

. /etc/config.d/phpmyadmin
. /etc/config.d/php-apache2
. /var/install/bin/phpmyadmin-helpers.sh
. /var/install/include/eislib

configFolder=/etc/phpmyadmin
configPhp=${configFolder}/config.inc.php
sweKeyConfigured=false
ownerToUse='apache:apache'


# ----------------------------------------------------------------------------
# Setup boolean values as php they want
createBooleanValues ()
{
    case ${PHPMYADMIN_LAYOUT} in
        yes)
            case ${PHPMYADMIN_LEFTFRAME_LIGHT} in
                yes)
                    PHPMYADMIN_LEFTFRAME_LIGHT=true
                    ;;
                no)
                    PHPMYADMIN_LEFTFRAME_LIGHT=false
                    ;;
            esac

            case ${PHPMYADMIN_LEFTFRAME_DB_TREE} in
                yes)
                    PHPMYADMIN_LEFTFRAME_DB_TREE=true
                    ;;
                no)
                    PHPMYADMIN_LEFTFRAME_DB_TREE=false
                    ;;
            esac

            case ${PHPMYADMIN_LEFT_DISPLAY_LOGO} in
                yes)
                    PHPMYADMIN_LEFT_DISPLAY_LOGO=true
                    ;;
                no)
                    PHPMYADMIN_LEFT_DISPLAY_LOGO=false
                    ;;
            esac

            case ${PHPMYADMIN_LEFT_DISPLAY_SERVERS} in
                yes)
                    PHPMYADMIN_LEFT_DISPLAY_SERVERS=true
                    ;;
                no)
                    PHPMYADMIN_LEFT_DISPLAY_SERVERS=false
                    ;;
            esac

            case ${PHPMYADMIN_LEFT_POINTER_ENABLE} in
                yes)
                    PHPMYADMIN_LEFT_POINTER_ENABLE=true
                    ;;
                no)
                    PHPMYADMIN_LEFT_POINTER_ENABLE=false
                    ;;
            esac

            case ${PHPMYADMIN_LIGHT_TABS} in
                yes)
                    PHPMYADMIN_LIGHT_TABS=true
                    ;;
                no)
                    PHPMYADMIN_LIGHT_TABS=false
                    ;;
            esac

            case ${PHPMYADMIN_ERROR_ICONIC} in
                yes)
                    PHPMYADMIN_ERROR_ICONIC=true
                    ;;
                no)
                    PHPMYADMIN_ERROR_ICONIC=false
                    ;;
            esac

            case ${PHPMYADMIN_MAINPAGE_ICONIC} in
                yes)
                    PHPMYADMIN_MAINPAGE_ICONIC=true
                    ;;
                no)
                    PHPMYADMIN_MAINPAGE_ICONIC=false
                    ;;
            esac

            case ${PHPMYADMIN_REPLACE_HELP_IMG} in
                yes)
                    PHPMYADMIN_REPLACE_HELP_IMG=true
                    ;;
                no)
                    PHPMYADMIN_REPLACE_HELP_IMG=false
                    ;;
            esac

            case ${PHPMYADMIN_BROWSE_POINTER_ENABLE} in
                yes)
                    PHPMYADMIN_BROWSE_POINTER_ENABLE=true
                    ;;
                no)
                    PHPMYADMIN_BROWSE_POINTER_ENABLE=false
                    ;;
            esac

            case ${PHPMYADMIN_BROWSE_MARKER_ENABLE} in
                yes)
                    PHPMYADMIN_BROWSE_MARKER_ENABLE=true
                    ;;
                no)
                    PHPMYADMIN_BROWSE_MARKER_ENABLE=false
                    ;;
            esac

            case ${PHPMYADMIN_MODIFY_DELETE_AT_RIGHT} in
                yes)
                    PHPMYADMIN_MODIFY_DELETE_AT_RIGHT=true
                    ;;
                no)
                    PHPMYADMIN_MODIFY_DELETE_AT_RIGHT=false
                    ;;
            esac

            case ${PHPMYADMIN_MODIFY_DELETE_AT_LEFT} in
                yes)
                    PHPMYADMIN_MODIFY_DELETE_AT_LEFT=true
                    ;;
                no)
                    PHPMYADMIN_MODIFY_DELETE_AT_LEFT=false
                    ;;
            esac

            case ${PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA} in
                yes)
                    PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA=true
                    ;;
                no)
                    PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA=false
                    ;;
            esac

            case ${PHPMYADMIN_TEXTAREA_AUTOSELECT} in
                yes)
                    PHPMYADMIN_TEXTAREA_AUTOSELECT=true
                    ;;
                no)
                    PHPMYADMIN_TEXTAREA_AUTOSELECT=false
                    ;;
            esac

            case ${PHPMYADMIN_CTRL_ARROWS_MOVING} in
                yes)
                    PHPMYADMIN_CTRL_ARROWS_MOVING=true
                    ;;
                no)
                    PHPMYADMIN_CTRL_ARROWS_MOVING=false
                    ;;
            esac

            case ${PHPMYADMIN_EDIT_IN_WINDOW} in
                yes)
                    PHPMYADMIN_EDIT_IN_WINDOW=true
                    ;;
                no)
                    PHPMYADMIN_EDIT_IN_WINDOW=false
                    ;;
            esac
        ;;
    esac

    case ${PHPMYADMIN_MISC_FEATURES} in
        yes)
            case ${PHPMYADMIN_FORCE_SSL} in
                yes)
                    PHPMYADMIN_FORCE_SSL=true
                    ;;
                no)
                    PHPMYADMIN_FORCE_SSL=false
                    ;;
            esac

            case ${PHPMYADMIN_SHOW_PHP_INFO} in
                yes)
                    PHPMYADMIN_SHOW_PHP_INFO=true
                    ;;
                no)
                    PHPMYADMIN_SHOW_PHP_INFO=false
                    ;;
            esac

            case ${PHPMYADMIN_SHOW_CHG_PASSWORD} in
                yes)
                    PHPMYADMIN_SHOW_CHG_PASSWORD=true
                    ;;
                no)
                    PHPMYADMIN_SHOW_CHG_PASSWORD=false
                    ;;
            esac

            case ${PHPMYADMIN_ALLOW_ARBITRARY_SERVER} in
                yes)
                    PHPMYADMIN_ALLOW_ARBITRARY_SERVER=true
                    ;;
                no)
                    PHPMYADMIN_ALLOW_ARBITRARY_SERVER=false
                    ;;
            esac

            case ${PHPMYADMIN_LOGIN_COOKIE_RECALL} in
                yes)
                    PHPMYADMIN_LOGIN_COOKIE_RECALL=true
                    ;;
                no)
                    PHPMYADMIN_LOGIN_COOKIE_RECALL=false
                    ;;
            esac

            case ${PHPMYADMIN_PMA_NORELATION_DISABLEWARNING} in
                yes)
                    PHPMYADMIN_PMA_NORELATION_DISABLEWARNING=true
                    ;;
                no)
                    PHPMYADMIN_PMA_NORELATION_DISABLEWARNING=false
                    ;;
            esac

            case ${PHPMYADMIN_FEATURES_UPDOWNLOAD} in
                yes)
                    # nothing to do at the moment
            esac

            # mysql manual
            case ${PHPMYADMIN_FEATURES_MANUAL} in
                yes)
                    # nothing to do at the moment
            esac

            case ${PHPMYADMIN_ALLOWANYWHERERECODING} in
                yes)
                    PHPMYADMIN_ALLOWANYWHERERECODING=true
                    ;;
                no)
                    PHPMYADMIN_ALLOWANYWHERERECODING=false
                    ;;
            esac

            case ${PHPMYADMIN_GD2AVAILABLE} in
                yes)
                    PHPMYADMIN_GD2AVAILABLE=true
                    ;;
                no)
                    PHPMYADMIN_GD2AVAILABLE=false
                    ;;
            esac

            case ${PHPMYADMIN_BROWSEMIME} in
                yes)
                    PHPMYADMIN_BROWSEMIME=true
                    ;;
                no)
                    PHPMYADMIN_BROWSEMIME=false
                    ;;
            esac

            case ${PHPMYADMIN_DISABLE_SUHOSIN_WARNING} in
                yes)
                    PHPMYADMIN_DISABLE_SUHOSIN_WARNING=true
                    ;;
                no)
                    PHPMYADMIN_DISABLE_SUHOSIN_WARNING=false
                    ;;
            esac

            case ${PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING} in
                yes)
                    PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING=true
                    ;;
                no)
                    PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING=false
                    ;;
            esac
            ;;
    esac

}


# ----------------------------------------------------------------------------
# Create ... (actually nothing to do)
createSelections ()
{
    case ${PHPMYADMIN_LAYOUT} in
        yes)
        ;;
    esac

}


# ----------------------------------------------------------------------------
# Create configuration file config.inc.php
createConfigIncPhp ()
{
    cat > ${configPhp} <<EOF
<?php
// ---------------------------------------------------------------------------
// Config file generated by eisfair-ng package cui-phpmyadmin
//
// ---------------------------------------------------------------------------
//
// Do not edit this file, edit /etc/config.d/phpmyadmin
//
// ---------------------------------------------------------------------------
//

/* Servers configuration */
\$i = 0;

EOF
    # Begin idx -le ${PHPMYADMIN_SERVER_N}
    idx=1

    # Counter for active servers
    idx1=1
    while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do

        eval active='${PHPMYADMIN_SERVER_'${idx}'_ACTIVE}'
        if [ "${active}" = 'yes' ] ; then

            eval host='${PHPMYADMIN_SERVER_'${idx}'_HOST}'
            eval extension='${PHPMYADMIN_SERVER_'${idx}'_EXTENSION}'
            eval port='${PHPMYADMIN_SERVER_'${idx}'_PORT}'

           # eval socket='${PHPMYADMIN_SERVER_'${idx}'_SOCKET}'
            eval connect_type='${PHPMYADMIN_SERVER_'${idx}'_CONNECT_TYPE}'
            eval comp='${PHPMYADMIN_SERVER_'${idx}'_COMPRESS}'

            case ${comp} in
              yes)
                compress='true'
                ;;
              no)
                compress='false'
                ;;
            esac

            # Extract the settings for the type of authentication
            eval authMethod='${PHPMYADMIN_SERVER_'${idx}'_AUTH_METHOD}'
            local authType=`echo ${authMethod} | cut -d ":" -f 1`

            user=''
            password=''
            if [ "${authType}" = 'http' ] ; then
                # Auth via http is requested. No more steps to do.
                fileconf='http'
            elif [ "${authType}" = 'cookie' ] ; then
                # Auth via cookie is requested. No more steps to do.
                fileconf='cookie'
            elif [ "${authType}" = 'config' ] ; then
                # Auth via configuration is requested. Extract the
                # username and password to use.
                user=`echo ${authMethod} | cut -d ":" -f 2`
                password=`echo ${authMethod} | cut -d ":" -f 3`
                fileconf="config:${user}"
            elif [ "${authType}" = 'signon' ] ; then
                # Auth via single sign on is requested. No more steps to do.
                fileconf='signon'
            fi

            # Extract the settings for swekeyfile usage
            eval authSweKey='${PHPMYADMIN_SERVER_'${idx}'_AUTH_SWEKEY}'
            authSweKey=${authSweKey:-no}  # Set to 'no' if empty
            if [ ${authSweKey} = 'yes' ] ; then
	            eval sweKeyNumber='${PHPMYADMIN_SERVER_'${idx}'_AUTH_SWEKEY_N}'
				sweKeyNumber=${sweKeyNumber:-0}  # Set to 0 if empty
	            # Extract swekey ID and name to use
                idx2=1
                while [ "${idx2}" -le "${sweKeyNumber}" ] ; do
		            eval sweKeyID='${PHPMYADMIN_SERVER_'${idx}'_AUTH_SWEKEY_'${idx2}'_ID}'
	                eval sweKeyNameToUse='${PHPMYADMIN_SERVER_'${idx}'_AUTH_SWEKEY_'${idx2}'_NAME}'
	                echo "${sweKeyID}:${sweKeyNameToUse}" >> /tmp/swekey-entries-$$
	                sweKeyConfigured=true
                    idx2=$((idx2+1))
                done
            else
                authSweKeyConfig=''
            fi

            # Create list of DBs to show
            eval onlyDBAmount='${PHPMYADMIN_SERVER_'${idx}'_ONLY_DB_N}'
            onlyDBAmount=${onlyDBAmount:-0}  # Set to 0 if empty
            if [ ${onlyDBAmount} -eq 0 ] ; then
                # Show all DBs
                dbsToShow="'*'"
            else
                idx2=1
                separator=''
                while [ "${idx2}" -le "${onlyDBAmount}" ] ; do
                    eval currentDB='${PHPMYADMIN_SERVER_'${idx}'_ONLY_DB_'${idx2}'_NAME}'
                    dbsToShow="${dbsToShow}${separator}'${currentDB}'"
                    separator=', '
                    idx2=$((idx2+1))
                done
            fi

            eval verbose='${PHPMYADMIN_SERVER_'${idx}'_VERBOSE}'

            cat >> ${configPhp} <<EOF
/* Server ${host} (${fileconf}) [${idx1}] */
\$i++;
\$cfg['Servers'][\$i]['host']               = "${host}";
\$cfg['Servers'][\$i]['port']               = "${port}";
\$cfg['Servers'][\$i]['user']               = "${user}";
\$cfg['Servers'][\$i]['password']           = "${password}";
\$cfg['Servers'][\$i]['auth_type']          = "${authType}";
\$cfg['Servers'][\$i]['auth_swekey_config'] = "/etc/swekey.conf";
\$cfg['Servers'][\$i]['extension']          = "${extension}";
\$cfg['Servers'][\$i]['connect_type']       = "${connect_type}";
EOF
            if [ "${connect_type}" = 'socket' ] ; then
                echo "\$cfg['Servers'][\$i]['socket']             = \"${PHP5_EXT_MYSQL_SOCKET}\";" >> ${configPhp}
            fi
            cat >> ${configPhp} <<EOF
\$cfg['Servers'][\$i]['compress']           = ${compress};
\$cfg['Servers'][\$i]['only_db']            = array( ${dbsToShow} );
\$cfg['Servers'][\$i]['verbose']            = "${verbose}";

EOF

            eval advancedFeaturesActive='${PHPMYADMIN_SERVER_'${idx}'_ADVANCED_FEATURES}'
            if [ "${advancedFeaturesActive}" = 'yes' ] ; then
                eval pmadb='${PHPMYADMIN_SERVER_'${idx}'_PMADB}'
                eval controluser='${PHPMYADMIN_SERVER_'${idx}'_CONTROLUSER}'
                eval controlpass='${PHPMYADMIN_SERVER_'${idx}'_CONTROLPASS}'

                # Extract the setting for ssl usage
                eval useSSL='${PHPMYADMIN_SERVER_'${idx}'_USE_SSL}'
                case ${useSSL} in
                  yes)
                    useSSL='true'
                    ;;
                  no)
                    useSSL='false'
                    ;;
                esac

                # Extract the setting for nopassword usage
                eval noPass='${PHPMYADMIN_SERVER_'${idx}'_NO_PASSWORD}'
                case ${noPass} in
                  yes)
                    noPass='true'
                    ;;
                  no)
                    noPass='false'
                    ;;
                esac

                cat >> ${configPhp} <<EOF

\$cfg['Servers'][\$i]['pmadb']              = "${pmadb}";
\$cfg['Servers'][\$i]['controluser']        = "${controluser}";
\$cfg['Servers'][\$i]['controlpass']        = "${controlpass}";

\$cfg['Servers'][\$i]['bookmarktable']      = "pma_bookmark";
\$cfg['Servers'][\$i]['relation']           = "pma_relation";
\$cfg['Servers'][\$i]['table_info']         = "pma_table_info";
\$cfg['Servers'][\$i]['table_coords']       = "pma_table_coords";
\$cfg['Servers'][\$i]['pdf_pages']          = "pma_pdf_pages";
\$cfg['Servers'][\$i]['column_info']        = "pma_column_info";
\$cfg['Servers'][\$i]['history']            = "pma_history";
\$cfg['Servers'][\$i]['designer_coords']    = "pma_designer_coords";

\$cfg['Servers'][\$i]['ssl']                = ${useSSL};
\$cfg['Servers'][\$i]['nopassword']         = ${noPass};

EOF
            fi

#        eval queryhistorydb='${PHPMYADMIN_SERVER_'${idx}'_QUERYHISTORYDB}'
#        if [ "${queryhistorydb}" = 'yes' ]
#        then
#            eval queryhistorymax='${PHPMYADMIN_SERVER_'${idx}'_QUERYHISTORYMAX}'
#            eval queryhistorytab='${PHPMYADMIN_SERVER_'${idx}'_QUERYHISTORYTAB}'
#
#cat >>${config_php} <<EOF
#
#\$cfg['Servers'][\$i]['queryhistorydb']  = true;
#\$cfg['Servers'][\$i]['queryhistorymax'] = ${queryhistorymax};
#\$cfg['Servers'][\$i]['queryhistorytab'] = "${queryhistorytab}";
#
#EOF
#        else
#cat >>${config_php} <<EOF
#
#\$cfg['Servers'][\$i]['queryhistorydb'] = false;
#
#EOF
#        fi

            # end count for active
            idx1=`/usr/bin/expr ${idx1} + 1`

            # end $active
        fi

        # end idx -le ${PHPMYADMIN_SERVER_N}
        idx=`/usr/bin/expr ${idx} + 1`
    done

    cat >> ${configPhp} <<EOF

/* End of servers configuration */

/* Configuration of secret for cookie encryption */
\$cfg['blowfish_secret']                    = "${PHPMYADMIN_BLOWFISH_SECRET}";

EOF

    if [ "${PHPMYADMIN_LAYOUT}" = 'yes' ] ; then
        cat >> ${configPhp} <<EOF

/* Configuration of left frame */
\$cfg['LeftFrameLight']                     = ${PHPMYADMIN_LEFTFRAME_LIGHT};
\$cfg['LeftFrameDBTree']                    = ${PHPMYADMIN_LEFTFRAME_DB_TREE};
\$cfg['LeftFrameDBSeparator']               = "${PHPMYADMIN_LEFTFRAME_DB_SEPARATOR}";
\$cfg['LeftFrameTableSeparator']            = "${PHPMYADMIN_LEFTFRAME_TABLE_SEPARATOR}";
\$cfg['LeftFrameTableLevel']                = ${PHPMYADMIN_LEFTFRAME_TABLE_LEVEL};
\$cfg['LeftDisplayLogo']                    = ${PHPMYADMIN_LEFT_DISPLAY_LOGO};
\$cfg['LeftDisplayServers']                 = ${PHPMYADMIN_LEFT_DISPLAY_SERVERS};
\$cfg['LeftPointerEnable']                  = ${PHPMYADMIN_LEFT_POINTER_ENABLE};

/* Configuration of tabs */
\$cfg['DefaultTabServer']                   = "${PHPMYADMIN_DEFAULT_TAB_SERVER}";
\$cfg['DefaultTabDatabase']                 = "${PHPMYADMIN_DEFAULT_TAB_DATABASE}";
\$cfg['DefaultTabTable']                    = "${PHPMYADMIN_DEFAULT_TAB_TABLE}";
\$cfg['LightTabs']                          = ${PHPMYADMIN_LIGHT_TABS};

/* Configuration of icons */
\$cfg['ErrorIconic']                        = ${PHPMYADMIN_ERROR_ICONIC};
\$cfg['MainPageIconic']                     = ${PHPMYADMIN_MAINPAGE_ICONIC};
\$cfg['ReplaceHelpImg']                     = ${PHPMYADMIN_REPLACE_HELP_IMG};
\$cfg['NavigationBarIconic']                = "${PHPMYADMIN_NAVIGATION_BAR_ICONIC}";
\$cfg['PropertiesIconic']                   = "${PHPMYADMIN_PROPERTIES_ICONIC}";

/* Configuration of browsing */
\$cfg['BrowsePointerEnable']                = ${PHPMYADMIN_BROWSE_POINTER_ENABLE};
\$cfg['BrowseMarkerEnable']                 = ${PHPMYADMIN_BROWSE_MARKER_ENABLE};
\$cfg['ModifyDeleteAtRight']                = ${PHPMYADMIN_MODIFY_DELETE_AT_RIGHT};
\$cfg['ModifyDeleteAtLeft']                 = ${PHPMYADMIN_MODIFY_DELETE_AT_LEFT};
\$cfg['RepeatCells']                        = ${PHPMYADMIN_REPEAT_CELLS};
\$cfg['DefaultDisplay']                     = "${PHPMYADMIN_DEFAULT_PROP_DISPLAY}";

\$cfg['TextareaCols']                       = ${PHPMYADMIN_TEXTAREA_COLS};
\$cfg['TextareaRows']                       = ${PHPMYADMIN_TEXTAREA_ROWS};
\$cfg['LongtextDoubleTextarea']             = ${PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA};
\$cfg['TextareaAutoSelect']                 = ${PHPMYADMIN_TEXTAREA_AUTOSELECT};
\$cfg['CharEditing']                        = "${PHPMYADMIN_CHAR_EDITING}";
\$cfg['CharTextareaCols']                   = ${PHPMYADMIN_CHAR_TEXTAREA_COLS};
\$cfg['CharTextareaRows']                   = ${PHPMYADMIN_CHAR_TEXTAREA_ROWS};
\$cfg['CtrlArrowsMoving']                   = ${PHPMYADMIN_CTRL_ARROWS_MOVING};
\$cfg['DefaultPropDisplay']                 = "${PHPMYADMIN_DEFAULT_PROP_DISPLAY}";
\$cfg['InsertRows']                         = ${PHPMYADMIN_INSERT_ROWS};

/* Querywindow configuration */
\$cfg['EditInWindow']                       = ${PHPMYADMIN_EDIT_IN_WINDOW};
\$cfg['QueryWindowHeight']                  = ${PHPMYADMIN_QUERY_WINDOW_HEIGHT};
\$cfg['QueryWindowWidth']                   = ${PHPMYADMIN_QUERY_WINDOW_WIDTH};
\$cfg['QueryWindowDefTab']                  = "${PHPMYADMIN_QUERY_WINDOW_DEFTAB}";

EOF

    fi

    if [ "${PHPMYADMIN_MISC_FEATURES}" = 'yes' ] ; then
        cat >> ${configPhp} <<EOF

/* Configuration of security settings */
\$cfg['ForceSSL']                           = ${PHPMYADMIN_FORCE_SSL};
\$cfg['ShowPhpInfo']                        = ${PHPMYADMIN_SHOW_PHP_INFO};
\$cfg['ShowChgPassword']                    = ${PHPMYADMIN_SHOW_CHG_PASSWORD};
\$cfg['AllowArbitraryServer']               = ${PHPMYADMIN_ALLOW_ARBITRARY_SERVER};
\$cfg['LoginCookieRecall']                  = ${PHPMYADMIN_LOGIN_COOKIE_RECALL};
\$cfg['LoginCookieValidity']                = ${PHPMYADMIN_LOGIN_COOKIE_VALIDITY};
\$cfg['PmaAbsoluteUri']                     = "${PHPMYADMIN_PMA_ABSOLUTE_URI}";
\$cfg['PmaNoRelation_DisableWarning']       = ${PHPMYADMIN_PMA_NORELATION_DISABLEWARNING};

/* Configuration of file up- and download */
\$cfg['UploadDir']                          = "${PHPMYADMIN_UPLOADDIR}";
\$cfg['SaveDir']                            = "${PHPMYADMIN_SAVEDIR}";
\$cfg['docSQLDir']                          = "${PHPMYADMIN_DOCSQLDIR}";

/* Configuration of documentation and online help */
\$cfg['MySQLManualBase']                    = "${PHPMYADMIN_MYSQLMANUALBASE}";
\$cfg['MySQLManualType']                    = "${PHPMYADMIN_MYSQLMANUALTYPE}";

/* Configuration of character encoding */
\$cfg['AllowAnywhereRecording']             = ${PHPMYADMIN_ALLOWANYWHERERECODING};
\$cfg['DefaultCharset']                     = "${PHPMYADMIN_DEFAULTCHARSET}";
\$cfg['RecodingEngine']                     = "${PHPMYADMIN_RECODINGENGINE}";
\$cfg['IconvExtraParams']                   = "${PHPMYADMIN_ICONVEXTRAPARAMS}";

/* Configuration of extensions */
\$cfg['GD2Available']                       = ${PHPMYADMIN_GD2AVAILABLE};

/* Misc */
\$cfg['BrowseMIME']                         = ${PHPMYADMIN_BROWSEMIME};
\$cfg['PDFDefaultPageSize']                 = "${PHPMYADMIN_PDFDEFAULTPAGESIZE}";
\$cfg['DefaultLang']                        = "${PHPMYADMIN_DEFAULTLANGUAGE}";
\$cfg['SuhosinDisableWarning']              = ${PHPMYADMIN_DISABLE_SUHOSIN_WARNING};
\$cfg['AllowThirdPartyFraming']             = ${PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING};
EOF

    fi

    cat >> ${configPhp} <<EOF

?>

EOF
    chown -R ${ownerToUse} ${configFolder}
    mecho "phpMyAdmin configuration written."
    echo
}


# ----------------------------------------------------------------------------
# Check the given username because 'root' and 'eis' is not allowed
checkCredentials ()
{
    rtc=0
    idx=1
    while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do
        # Extract the settings for the type of authentication
        eval authMethod='${PHPMYADMIN_SERVER_'${idx}'_AUTH_METHOD}'
        local authType=`echo ${authMethod} | cut -d ":" -f 1`
        local user=''
        if [ "${authType}" = 'config' ] ; then
            # Auth via configuration is requested. Extract the username.
            user=`echo ${authMethod} | cut -d ":" -f 2`
            if [ "${user}" = 'root' ] || [ "${user}" = 'eis' ] ; then
                mecho --error "Username '${user}' is not allowed, please change this!"
                rtc=1
            fi
        fi
        idx=`/usr/bin/expr ${idx} + 1`
    done
    if [ ${rtc} -ne 0 ] ; then
        exit ${rtc}
    fi
    return
}



# ----------------------------------------------------------------------------
# Check if mysql socket is activated on apache2_php5
checkSocketSetup ()
{
    socketShouldBeUsed=false

    # Counter for configured servers
    idx=1
    while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do
        eval active='${PHPMYADMIN_SERVER_'${idx}'_ACTIVE}'
        if [ "${active}" = 'yes' ] ; then
            eval connect_type='${PHPMYADMIN_SERVER_'${idx}'_CONNECT_TYPE}'
            if [ "${connect_type}" = 'socket' ] ; then
                socketShouldBeUsed=true
                break
            fi
        fi
        idx=`/usr/bin/expr ${idx} + 1`
    done

    if ${socketShouldBeUsed} ; then
        # Check the values out of the php configuration
        if [ "${PHP5_EXT_MYSQL}" != 'yes' ] ; then
            mecho --error " If you set PHPMYADMIN_SERVER_%_CONNECT_TYPE='socket', PHP5_EXT_MYSQL "
            mecho --error " must be activated on the php5 configuration together with a valid    "
            mecho --error " socket on PHP5_EXT_MYSQL_SOCKET!                                     "
            exit 1
        fi
        if [ -z "${PHP5_EXT_MYSQL_SOCKET}" ] ; then
            mecho --error " No socket configured on php5 configuration under PHP5_EXT_MYSQL_SOCKET! "
            exit 1
        fi
        if [ ! -S "${PHP5_EXT_MYSQL_SOCKET}" ] ; then
            mecho --error " The configured socket on PHP5_EXT_MYSQL_SOCKET on the php5 configuration "
            mecho --error " does not exist!                                                          "
            exit 1
        fi
    fi
}



# ----------------------------------------------------------------------------
# Create the configuration file to use SweKey authentication
createSweKeyConfig ()
{
	if ${sweKeyConfigured} ; then
		cat /etc/default.d/swekey.sample.conf.part1 >  /etc/swekey.conf
		sort --unique /tmp/swekey-entries-$$        >> /etc/swekey.conf
		echo "" >> /etc/swekey.conf
		cat /etc/default.d/swekey.sample.conf.part1 >> /etc/swekey.conf
		rm -f /tmp/swekey-entries-$$
	else
		rm -f /etc/swekey.conf
	fi
}



# ----------------------------------------------------------------------------
# Setup all necessary configuration files and perform necessary steps
activatePhpMyAdmin ()
{
    cp /etc/default.d/*.phpmyadmin.ini /etc/php/conf.d/
    restartWebserver
}



# ----------------------------------------------------------------------------
# Remove all configuration files and perform further necessary steps
deactivatePhpMyAdmin ()
{
    rm -f /etc/php/conf.d/*.phpmyadmin.ini
    restartWebserver
}



# ----------------------------------------------------------------------------
# Restart webserver
restartWebserver ()
{
    rc-service apache2 restart
}


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if [ "$1" = '--quiet' ] ; then
    quietmode=true
else
    quietmode=false
fi

if [ "${START_PHPMYADMIN}" = 'yes' ] ; then
    checkCredentials
#    checkSocketSetup
    createBooleanValues
#    createSelections
    createConfigIncPhp
	createSweKeyConfig
	activatePhpMyAdmin
else
    deactivatePhpMyAdmin
fi

exit 0
