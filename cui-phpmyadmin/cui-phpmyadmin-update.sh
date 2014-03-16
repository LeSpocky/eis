#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/config.d/phpmyadmin-update.sh - parameter update script
#
# Creation:     2006-09-15 starwarsfan
#
# Copyright (c) 2006-2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------


#exec 2>/tmp/phpmyadmin-update-trace$$.log
#set -x

package_name=phpmyadmin

# include configlib for using printvar
. /var/install/include/configlib

installFolder=/usr/share/webapps/phpmyadmin
webConfigFolder=${installFolder}/setup
backupFolder=/var/lib/phpmyadmin



# ----------------------------------------------------------------------------
# Set the default values for configuration
START_PHPMYADMIN='no'

#servers
PHPMYADMIN_SERVER_N='1'                       #number of server
PHPMYADMIN_SERVER_1_NAME=''                   #name of server, not used intern
PHPMYADMIN_SERVER_1_ACTIVE='no'               #activate this server
    PHPMYADMIN_SERVER_1_HOST='localhost'          #host where the db runs
    PHPMYADMIN_SERVER_1_PORT=''                   #portnumber to use

# Configuration of socket is not used anymore.
# The value out of the php config is inserted automatically.
#    PHPMYADMIN_SERVER_1_SOCKET=''                 #path to the socket to use

    PHPMYADMIN_SERVER_1_CONNECT_TYPE='tcp'        #connection type: tcp or socket
    PHPMYADMIN_SERVER_1_EXTENSION='mysql'         #extension
    PHPMYADMIN_SERVER_1_COMPRESS='no'             #use compression
    PHPMYADMIN_SERVER_1_AUTH_METHOD='http'        #
    PHPMYADMIN_SERVER_1_AUTH_SWEKEY='no'
    PHPMYADMIN_SERVER_1_AUTH_SWEKEY_N='1'
    PHPMYADMIN_SERVER_1_AUTH_SWEKEY_1_ID='00000000000000000000000000001234'
    PHPMYADMIN_SERVER_1_AUTH_SWEKEY_1_NAME=''

    PHPMYADMIN_SERVER_1_ONLY_DB_N='0'             #amount of db's to show
    PHPMYADMIN_SERVER_1_ONLY_DB_1_NAME=''         #name of db to show
    PHPMYADMIN_SERVER_1_VERBOSE=''                #
    PHPMYADMIN_SERVER_1_ADVANCED_FEATURES='no'    #activate database for advanced features
        PHPMYADMIN_SERVER_1_USE_SSL='yes'             #enable ssl for connection to mysql server
        PHPMYADMIN_SERVER_1_NO_PASSWORD='no'          #try connect without password after failed password connect
        PHPMYADMIN_SERVER_1_PMADB='phpmyadmin'        #database for advanced features
        PHPMYADMIN_SERVER_1_CONTROLUSER=''            #username for advanced features
        PHPMYADMIN_SERVER_1_CONTROLPASS=''            #password for advandes features
#        PHPMYADMIN_SERVER_1_QUERYHISTORYDB='no'       #
#        PHPMYADMIN_SERVER_1_QUERYHISTORYMAX='25'      #
#        PHPMYADMIN_SERVER_1_QUERYHISTORYTAB='history' #


PHPMYADMIN_BLOWFISH_SECRET=`date +%s%N | sha1sum | cut -d" " -f1`

PHPMYADMIN_LAYOUT='no'
    #left frame
    PHPMYADMIN_LEFTFRAME_LIGHT='yes'
    PHPMYADMIN_LEFTFRAME_DB_TREE='yes'
    PHPMYADMIN_LEFTFRAME_DB_SEPARATOR='_'
    PHPMYADMIN_LEFTFRAME_TABLE_SEPARATOR='__'
    PHPMYADMIN_LEFTFRAME_TABLE_LEVEL='1'
    PHPMYADMIN_LEFT_DISPLAY_LOGO='yes'
    PHPMYADMIN_LEFT_DISPLAY_SERVERS='no'
    PHPMYADMIN_LEFT_POINTER_ENABLE='yes'

    #tabs
    PHPMYADMIN_DEFAULT_TAB_SERVER='main.php'
    PHPMYADMIN_DEFAULT_TAB_DATABASE='db_details_structure.php'
    PHPMYADMIN_DEFAULT_TAB_TABLE='tbl_properties_structure.php'
    PHPMYADMIN_LIGHT_TABS='no'

    #icons
    PHPMYADMIN_ERROR_ICONIC='yes'
    PHPMYADMIN_MAINPAGE_ICONIC='yes'
    PHPMYADMIN_REPLACE_HELP_IMG='yes'
    PHPMYADMIN_NAVIGATION_BAR_ICONIC='both'
    PHPMYADMIN_PROPERTIES_ICONIC='both'

    #browsing
    PHPMYADMIN_BROWSE_POINTER_ENABLE='yes'
    PHPMYADMIN_BROWSE_MARKER_ENABLE='yes'
    PHPMYADMIN_MODIFY_DELETE_AT_RIGHT='no'
    PHPMYADMIN_MODIFY_DELETE_AT_LEFT='yes'
    PHPMYADMIN_REPEAT_CELLS='100'
    PHPMYADMIN_DEFAULT_DISPLAY='horizontal'

    #editing
    PHPMYADMIN_TEXTAREA_COLS='40'
    PHPMYADMIN_TEXTAREA_ROWS='7'
    PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA='yes'
    PHPMYADMIN_TEXTAREA_AUTOSELECT='yes'
    PHPMYADMIN_CHAR_EDITING='input'
    PHPMYADMIN_CHAR_TEXTAREA_COLS='40'
    PHPMYADMIN_CHAR_TEXTAREA_ROWS='2'
    PHPMYADMIN_CTRL_ARROWS_MOVING='yes'
    PHPMYADMIN_DEFAULT_PROP_DISPLAY='horizontal'
    PHPMYADMIN_INSERT_ROWS='2'

    #query window
    PHPMYADMIN_EDIT_IN_WINDOW='yes'
    PHPMYADMIN_QUERY_WINDOW_HEIGHT='310'
    PHPMYADMIN_QUERY_WINDOW_WIDTH='550'
    PHPMYADMIN_QUERY_WINDOW_DEFTAB='sql'


PHPMYADMIN_MISC_FEATURES='no'
    #security
    PHPMYADMIN_FORCE_SSL='no'
    PHPMYADMIN_SHOW_PHP_INFO='no'
    PHPMYADMIN_SHOW_CHG_PASSWORD='no'
    PHPMYADMIN_ALLOW_ARBITRARY_SERVER='no'
    PHPMYADMIN_LOGIN_COOKIE_RECALL='yes'   #Define whether the previous login should be recalled or not in cookie authentication mode.
    PHPMYADMIN_LOGIN_COOKIE_VALIDITY='1800'

    PHPMYADMIN_PMA_ABSOLUTE_URI=''
    PHPMYADMIN_PMA_NORELATION_DISABLEWARNING='no'

    PHPMYADMIN_FEATURES_UPDOWNLOAD='no'
    PHPMYADMIN_UPLOADDIR=''
    PHPMYADMIN_SAVEDIR=''
#x    PHPMYADMIN_DOCSQLDIR=''

    # Manuals & Documentation
    PHPMYADMIN_FEATURES_MANUAL='no'
    PHPMYADMIN_MYSQLMANUALBASE='http://dev.mysql.com/doc/refman'
    PHPMYADMIN_MYSQLMANUALTYPE='viewable'

    # Character encoding
    PHPMYADMIN_FEATURES_CHARSETS='no'
    PHPMYADMIN_ALLOWANYWHERERECODING='no'
    PHPMYADMIN_DEFAULTCHARSET='iso-8859-1'
    PHPMYADMIN_RECODINGENGINE='iconv'
    PHPMYADMIN_ICONVEXTRAPARAMS='//TRANSLIT'

    # Usage of extensions
    PHPMYADMIN_FEATURES_EXTENSIONS='no'
    PHPMYADMIN_GD2AVAILABLE='yes'

    PHPMYADMIN_BROWSEMIME='yes'
#x    PHPMYADMIN_PDFDEFAULTPAGESIZE='A4'
    PHPMYADMIN_DEFAULTLANGUAGE='de-iso-8859-1'
    PHPMYADMIN_DISABLE_SUHOSIN_WARNING='no'
    PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING='no'



# ----------------------------------------------------------------------------
# Read old configuration and update old variables
updateOldVariables()
{
    # -------------------
    # Read current values
    if [ -f /etc/config.d/${package_name} ] ; then
        . /etc/config.d/${package_name}

        idx=1
        while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do
            eval authHTTP='${PHPMYADMIN_SERVER_'${idx}'_AUTH_HTTP}'
            eval authCookie='${PHPMYADMIN_SERVER_'${idx}'_AUTH_COOKIE}'
            eval authConfig='${PHPMYADMIN_SERVER_'${idx}'_AUTH_CONFIG}'
            eval authConfigUsername='${PHPMYADMIN_SERVER_'${idx}'_USER}'
            eval authConfigPassword='${PHPMYADMIN_SERVER_'${idx}'_PASSWORD}'
            if [ "${authHTTP}" == "yes" ] ; then
                eval PHPMYADMIN_SERVER_${idx}_AUTH_METHOD='http'
            elif [ "${authCookie}" == "yes" ] ; then
                eval PHPMYADMIN_SERVER_${idx}_AUTH_METHOD='cookie'
            elif [ "${authConfig}" == "yes" ] ; then
                eval PHPMYADMIN_SERVER_${idx}_AUTH_METHOD='config:${authConfigUsername}:${authConfigPassword}'
            fi

            idx=`/usr/bin/expr ${idx} + 1`
        done
    fi
}

# ----------------------------------------------------------------------------
# Write config and default files
createConfigFile()
{
    internal_conf_file=${1}
    (
    #-------------------------------------------------------------------------
    printgpl --conf ${package_name}
    #-------------------------------------------------------------------------

    #-------------------------------------------------------------------------
    printgroup "phpMyAdmin configuration"
    #-------------------------------------------------------------------------

    printvar "START_PHPMYADMIN"              "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Servers"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_SERVER_N"           "Number of Servers"

    # begin PHPMYADMIN_SERVER_N
    idx=1

    while [ "${idx}" -le "${PHPMYADMIN_SERVER_N}" ] ; do
        printvar "PHPMYADMIN_SERVER_${idx}_NAME"                "Use a name what ever you want. The entered value is only for your overview of different servers"
        printvar "PHPMYADMIN_SERVER_${idx}_ACTIVE"              "Is this server active?"
        printcomment                                            "Use: yes or no"
        printvar "PHPMYADMIN_SERVER_${idx}_HOST"                "FQDN or IP of this server"
        printvar "PHPMYADMIN_SERVER_${idx}_PORT"                "Portnumber to use for connection."
        printvar "PHPMYADMIN_SERVER_${idx}_AUTH_METHOD"         "'http', 'cookie' or 'config:<username>:<password>'"
        printvar "PHPMYADMIN_SERVER_${idx}_AUTH_SWEKEY"         "Use swekey file for authentication. Default 'no'"
        printvar "PHPMYADMIN_SERVER_${idx}_AUTH_SWEKEY_N"       "Amount of configured Swekey's"
        idx2=1
        eval sweKeys='${PHPMYADMIN_SERVER_'${idx}'_AUTH_SWEKEY_N}'
        sweKeys=${sweKeys:-0} # Set to 0 if empty
        while [ "${idx2}" -le "${sweKeys}" ] ; do
	        printvar "PHPMYADMIN_SERVER_${idx}_AUTH_SWEKEY_${idx2}_ID"   "Swekey ID"
	        printvar "PHPMYADMIN_SERVER_${idx}_AUTH_SWEKEY_${idx2}_NAME" "Username which should be used with this Swekey"
            idx2=$((idx2+1))
	    done

       # Configuration of socket is not used anymore.
       # The value out of the php config is inserted automatically.
       # printvar "PHPMYADMIN_SERVER_${idx}_SOCKET"              "Path to the socket to use"

        printvar "PHPMYADMIN_SERVER_${idx}_CONNECT_TYPE"        "Type of the connection: 'tcp' or 'socket'"
        printvar "PHPMYADMIN_SERVER_${idx}_EXTENSION"           "mysql or mysqli"
        printvar "PHPMYADMIN_SERVER_${idx}_COMPRESS"            "Use: yes or no"
        printvar "PHPMYADMIN_SERVER_${idx}_ONLY_DB_N"           "If no database selection should be visible, enter the amount of the db's to show here"

        idx2=1
        eval dbsToShow='${PHPMYADMIN_SERVER_'${idx}'_ONLY_DB_N}'
        dbsToShow=${dbsToShow:-0} # Set to 0 if empty
        while [ "${idx2}" -le "${dbsToShow}" ] ; do
            printvar "PHPMYADMIN_SERVER_${idx}_ONLY_DB_${idx2}_NAME" "Name of the db to show"
            idx2=$((idx2+1))
        done

        printvar "PHPMYADMIN_SERVER_${idx}_VERBOSE"             "Name of this server to display in the header"
        printvar "PHPMYADMIN_SERVER_${idx}_ADVANCED_FEATURES"   "Activate database for advanced features. If this is set to 'yes' then the database entered on PHPMYADMIN_SERVER_#_PMADB will be created"
        printcomment                                            "Use: yes or no"
        printvar "PHPMYADMIN_SERVER_${idx}_USE_SSL"             "Use ssl for connection to mysql server"
        printvar "PHPMYADMIN_SERVER_${idx}_NO_PASSWORD"         "Try connect to mysql server without password"
        printvar "PHPMYADMIN_SERVER_${idx}_PMADB"               "Database for advanced features. Normally you do not change this value"
        printvar "PHPMYADMIN_SERVER_${idx}_CONTROLUSER"         "phpMyAdmin control user"
        printvar "PHPMYADMIN_SERVER_${idx}_CONTROLPASS"         "phpMyAdmin control user password"
#        printvar "PHPMYADMIN_SERVER_${idx}_QUERYHISTORYDB"      "Activate this if you want to log your sql statements"
#        printcomment                                            "Use: yes or no"
#        printvar "PHPMYADMIN_SERVER_${idx}_QUERYHISTORYMAX"     "How many statements should be logged"
#        printvar "PHPMYADMIN_SERVER_${idx}_QUERYHISTORYTAB"     "The table to use for logging statements"

        # end PHPMYADMIN_SERVER_N
        idx=`/usr/bin/expr ${idx} + 1`
    done

    #-------------------------------------------------------------------------
    printgroup "Blowfish secret for cookie authentication"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_BLOWFISH_SECRET"                   "String"

    #-------------------------------------------------------------------------
    printgroup "phpMyAdmin look and feel"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_LAYOUT"                            "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Layout settings for left frame"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_LEFTFRAME_LIGHT"                   "Use: yes or no"
    printvar "PHPMYADMIN_LEFTFRAME_DB_TREE"                 "Use: yes or no"
    printvar "PHPMYADMIN_LEFTFRAME_DB_SEPARATOR"            "_"
    printvar "PHPMYADMIN_LEFTFRAME_TABLE_SEPARATOR"         "__"
    printvar "PHPMYADMIN_LEFTFRAME_TABLE_LEVEL"             "1"
    printvar "PHPMYADMIN_LEFT_DISPLAY_LOGO"                 "Use: yes or no"
    printvar "PHPMYADMIN_LEFT_DISPLAY_SERVERS"              "Use: yes or no"
    printvar "PHPMYADMIN_LEFT_POINTER_ENABLE"               "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Settings for tabs"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_DEFAULT_TAB_SERVER"                "e. g. 'main.php'"
    printvar "PHPMYADMIN_DEFAULT_TAB_DATABASE"              "e. g. 'db_details_structure.php'"
    printvar "PHPMYADMIN_DEFAULT_TAB_TABLE"                 "e. g. 'tbl_properties_structure.php'"
    printvar "PHPMYADMIN_LIGHT_TABS"                        "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Settings for icons"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_ERROR_ICONIC"                      "Use: yes or no"
    printvar "PHPMYADMIN_MAINPAGE_ICONIC"                   "Use: yes or no"
    printvar "PHPMYADMIN_REPLACE_HELP_IMG"                  "Use: yes or no"
    printvar "PHPMYADMIN_NAVIGATION_BAR_ICONIC"             "'TRUE', 'FALSE' or 'both'"
    printvar "PHPMYADMIN_PROPERTIES_ICONIC"                 "'TRUE', 'FALSE' or 'both'"

    #-------------------------------------------------------------------------
    printgroup "Settings for browsing"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_BROWSE_POINTER_ENABLE"             "Use: yes or no"
    printvar "PHPMYADMIN_BROWSE_MARKER_ENABLE"              "Use: yes or no"
    printvar "PHPMYADMIN_MODIFY_DELETE_AT_RIGHT"            "Use: yes or no"
    printvar "PHPMYADMIN_MODIFY_DELETE_AT_LEFT"             "Use: yes or no"
    printvar "PHPMYADMIN_REPEAT_CELLS"                      "100"
    printvar "PHPMYADMIN_DEFAULT_DISPLAY"                   "'horizontal', 'vertical' or 'horizontalflipped'"

    #-------------------------------------------------------------------------
    printgroup "Setings for editing"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_TEXTAREA_COLS"                     "40"
    printvar "PHPMYADMIN_TEXTAREA_ROWS"                     "7"
    printvar "PHPMYADMIN_LONGTEXT_DOUBLE_TEXTAREA"          "Use: yes or no"
    printvar "PHPMYADMIN_TEXTAREA_AUTOSELECT"               "Use: yes or no"
    printvar "PHPMYADMIN_CHAR_EDITING"                      "'input' or 'textarea'"
    printvar "PHPMYADMIN_CHAR_TEXTAREA_COLS"                "40"
    printvar "PHPMYADMIN_CHAR_TEXTAREA_ROWS"                "2"
    printvar "PHPMYADMIN_CTRL_ARROWS_MOVING"                "Use: yes or no"
    printvar "PHPMYADMIN_DEFAULT_PROP_DISPLAY"              "'horizontal', 'vertical'"
    printvar "PHPMYADMIN_INSERT_ROWS"                       "2"

    #-------------------------------------------------------------------------
    printgroup "Query window settings"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_EDIT_IN_WINDOW"                    "Use: yes or no"
    printvar "PHPMYADMIN_QUERY_WINDOW_HEIGHT"               "310"
    printvar "PHPMYADMIN_QUERY_WINDOW_WIDTH"                "550"
    printvar "PHPMYADMIN_QUERY_WINDOW_DEFTAB"               "1 - 4"

    #-------------------------------------------------------------------------
    printgroup "Misc settings"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_MISC_FEATURES"                     "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Security settings"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_FORCE_SSL"                         "Use: yes or no"
    printvar "PHPMYADMIN_SHOW_PHP_INFO"                     "Use: yes or no"
    printvar "PHPMYADMIN_SHOW_CHG_PASSWORD"                 "Use: yes or no"
    printvar "PHPMYADMIN_ALLOW_ARBITRARY_SERVER"            "Use: yes or no"
    printvar "PHPMYADMIN_LOGIN_COOKIE_RECALL"               "Define whether the previous login should be recalled or not in cookie authentication mode."
    printvar "PHPMYADMIN_LOGIN_COOKIE_VALIDITY"             "Define how long is login cookie valid. (seconds)"

    printvar "PHPMYADMIN_PMA_ABSOLUTE_URI"                  "Full URI to pMA"
    printvar "PHPMYADMIN_PMA_NORELATION_DISABLEWARNING"     "Use: yes or no"

    #-------------------------------------------------------------------------
    printgroup "Settings for script- and dump-file up- and download"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_UPLOADDIR"                         "Destination directory for uploaded sql scripts"
    printvar "PHPMYADMIN_SAVEDIR"                           "Destination directory for db dump files"
    printvar "PHPMYADMIN_DOCSQLDIR"                         "The name of the directory where docSQL files can be uploaded for import into phpMyAdmin"

    #-------------------------------------------------------------------------
    printgroup "Settings for online help with MySQL manuals"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_MYSQLMANUALBASE"                   "URL which points to the MySQL documentation"
    printvar "PHPMYADMIN_MYSQLMANUALTYPE"                   "Type of MySQL documentation: 'viewable', 'searchable', 'chapters', 'big' or 'none'"

    #-------------------------------------------------------------------------
    printgroup "Settings for character encoding"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_ALLOWANYWHERERECODING"             "Allow character set recoding of MySQL queries"
    printvar "PHPMYADMIN_DEFAULTCHARSET"                    "Default character set to use for recoding of MySQL queries"
    printvar "PHPMYADMIN_RECODINGENGINE"                    "Function which will be used for character set conversion"
    printvar "PHPMYADMIN_ICONVEXTRAPARAMS"                  "Some parameters for iconv used in charset conversion"

    #-------------------------------------------------------------------------
    printgroup "Settings for extensions etc."
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_GD2AVAILABLE"                      "Specifies whether GD >= 2 is available"

    #-------------------------------------------------------------------------
    printgroup "Miscellaneous"
    #-------------------------------------------------------------------------

    printvar "PHPMYADMIN_BROWSEMIME"                        "Enable MIME-transformations"
    printvar "PHPMYADMIN_PDFDEFAULTPAGESIZE"                "Format of generated PDF: 'A3', 'A4', 'A5', 'letter', 'legal'"
    printvar "PHPMYADMIN_DEFAULTLANGUAGE"                   "Number of language to use, check manual for corresponding settings"
    printvar "PHPMYADMIN_DISABLE_SUHOSIN_WARNING"           "Disable display of a warning if Suhosin is detected on a server"
    printvar "PHPMYADMIN_ALLOW_THIRD_PARTY_FRAMING"         "Allow websites on a different domain to call phpMyAdmin inside an own frame. This is a potential security hole!"

    #-------------------------------------------------------------------------
    printend
    #-------------------------------------------------------------------------

    ) > ${internal_conf_file}
    # Set rights
    chmod 0600 ${internal_conf_file}
    chown root ${internal_conf_file}
}

# ----------------------------------------------------------------------------
# Per default phpmyadmin comes with webbased setup pages. These pages should
# be deactivated and could be reactivated if neccessary using eisfair setup
deactivateWebSetup ()
{
    if [ ! -d ${backupFolder} ] ; then
        mkdir -p ${backupFolder}
    else
        rm -rf ${backupFolder}/setup
    fi
    if [ -d ${installFolder}/setup ] ; then
        mv -rf ${installFolder}/setup ${backupFolder}/
    fi
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# write default config file
createConfigFile /etc/default.d/${package_name}

# update from old version
updateOldVariables

# write new config file
createConfigFile /etc/config.d/${package_name}

deactivateWebSetup

exit 0
