#!/bin/bash
# ----------------------------------------------------------------------------
# /var/install/bin/cui-phpmyadmin-tools-pma-db.sh
#
# Creation:     2007-01-22 starwarsfan
#
# Copyright (c) 2007-2013 The eisfair Team, <team(at)eisfair(dot)org>
# Maintained by Y. Schumann <yves(at)eisfair(dot)org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------------

#exec 2>/public/phpmyadmin-trace$$.log
#set -x

. /etc/config.d/phpmyadmin
. /var/install/include/eislib

mysql_data_dir=/var/lib/mysql
mysql_base_dir=/usr/local/mysql

tmpSQLScript=/tmp/tmpScript.sql



# ----------------------------------------------------------------------------
# Create Header for the SQL-Script
createSQLScriptHeader ()
{
    givenHost=$1
    givenDBName=$2
    givenControluser=$3

    cat >${tmpSQLScript} <<EOF
-- --------------------------------------------------------
-- SQL Commands to set up the pmadb as described in Documentation.html.
--
-- Modified for usage in the EisFair package
--
-- This file is meant for use with MySQL 5 and above!
--
-- This script expects the user pma to already be existing. If we would put a
-- line here to create him too many users might just use this script and end
-- up with having the same password for the controluser.
--
-- This user "pma" must be defined in config.inc.php (controluser/controlpass)
--
-- Please don't forget to set up the tablenames in config.inc.php
--
-- Original-Id: create_tables.sql 10684 2007-09-30 12:15:08Z lem9
-- based on:
-- $Id: phpmyadmin-tools-pma-db 30906 2012-05-25 12:19:04Z starwarsfan $

-- --------------------------------------------------------

EOF
}


# ----------------------------------------------------------------------------
# Create scriptpart to drop pmaDB first
createSQLScriptDropDB ()
{
    givenHost=$1
    givenDBName=$2
    givenControluser=$3

    cat >>${tmpSQLScript} <<EOF

--
-- Database : \`${givenDBName}\`
--
DROP DATABASE IF EXISTS \`${givenDBName}\`;
CREATE DATABASE \`${givenDBName}\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
USE ${givenDBName};

-- --------------------------------------------------------

EOF
}


# ----------------------------------------------------------------------------
# Create scriptpart to create pmaDB
createSQLScriptCreateDB ()
{
	givenHost=$1
	givenDBName=$2
	givenControluser=$3

	cat >>${tmpSQLScript} <<EOF

--
-- Database : \`${givenDBName}\`
--
CREATE DATABASE IF NOT EXISTS \`${givenDBName}\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
USE ${givenDBName};

-- --------------------------------------------------------

EOF
}


# ----------------------------------------------------------------------------
# Create scriptpart to grant privileges
createSQLScriptGrantPrivileges ()
{
	givenHost=$1
	givenDBName=$2
	givenControluser=$3

	cat >>${tmpSQLScript} <<EOF
--
-- Privileges
--
GRANT SELECT, INSERT, DELETE, UPDATE ON \`${givenDBName}\`.* TO
   'pma'@localhost;

-- --------------------------------------------------------


EOF
}



# ----------------------------------------------------------------------------
# Create scriptpart to create pmaDB tables
createSQLScriptCreateTables ()
{
	givenHost=$1
	givenDBName=$2
	givenControluser=$3

	cat >>${tmpSQLScript} <<EOF
--
-- Table structure for table \`pma_bookmark\`
--

CREATE TABLE IF NOT EXISTS \`pma_bookmark\` (
  \`id\` int(11) NOT NULL auto_increment,
  \`dbase\` varchar(255) NOT NULL default '',
  \`user\` varchar(255) NOT NULL default '',
  \`label\` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL default '',
  \`query\` text NOT NULL,
  PRIMARY KEY  (\`id\`)
)
  ENGINE=MyISAM COMMENT='Bookmarks'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_column_info\`
--

CREATE TABLE IF NOT EXISTS \`pma_column_info\` (
  \`id\` int(5) unsigned NOT NULL auto_increment,
  \`db_name\` varchar(64) NOT NULL default '',
  \`table_name\` varchar(64) NOT NULL default '',
  \`column_name\` varchar(64) NOT NULL default '',
  \`comment\` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL default '',
  \`mimetype\` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL default '',
  \`transformation\` varchar(255) NOT NULL default '',
  \`transformation_options\` varchar(255) NOT NULL default '',
  PRIMARY KEY  (\`id\`),
  UNIQUE KEY \`db_name\` (\`db_name\`,\`table_name\`,\`column_name\`)
)
  ENGINE=MyISAM COMMENT='Column information for phpMyAdmin'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_history\`
--

CREATE TABLE IF NOT EXISTS \`pma_history\` (
  \`id\` bigint(20) unsigned NOT NULL auto_increment,
  \`username\` varchar(64) NOT NULL default '',
  \`db\` varchar(64) NOT NULL default '',
  \`table\` varchar(64) NOT NULL default '',
  \`timevalue\` timestamp(14) NOT NULL,
  \`sqlquery\` text NOT NULL,
  PRIMARY KEY  (\`id\`),
  KEY \`username\` (\`username\`,\`db\`,\`table\`,\`timevalue\`)
)
  ENGINE=MyISAM COMMENT='SQL history for phpMyAdmin'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_pdf_pages\`
--

CREATE TABLE IF NOT EXISTS \`pma_pdf_pages\` (
  \`db_name\` varchar(64) NOT NULL default '',
  \`page_nr\` int(10) unsigned NOT NULL auto_increment,
  \`page_descr\` varchar(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL default '',
  PRIMARY KEY  (\`page_nr\`),
  KEY \`db_name\` (\`db_name\`)
)
  ENGINE=MyISAM COMMENT='PDF relation pages for phpMyAdmin'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_relation\`
--

CREATE TABLE IF NOT EXISTS \`pma_relation\` (
  \`master_db\` varchar(64) NOT NULL default '',
  \`master_table\` varchar(64) NOT NULL default '',
  \`master_field\` varchar(64) NOT NULL default '',
  \`foreign_db\` varchar(64) NOT NULL default '',
  \`foreign_table\` varchar(64) NOT NULL default '',
  \`foreign_field\` varchar(64) NOT NULL default '',
  PRIMARY KEY  (\`master_db\`,\`master_table\`,\`master_field\`),
  KEY \`foreign_field\` (\`foreign_db\`,\`foreign_table\`)
)
  ENGINE=MyISAM COMMENT='Relation table'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_table_coords\`
--

CREATE TABLE IF NOT EXISTS \`pma_table_coords\` (
  \`db_name\` varchar(64) NOT NULL default '',
  \`table_name\` varchar(64) NOT NULL default '',
  \`pdf_page_number\` int(11) NOT NULL default '0',
  \`x\` float unsigned NOT NULL default '0',
  \`y\` float unsigned NOT NULL default '0',
  PRIMARY KEY  (\`db_name\`,\`table_name\`,\`pdf_page_number\`)
)
  ENGINE=MyISAM COMMENT='Table coordinates for phpMyAdmin PDF output'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_table_info\`
--

CREATE TABLE IF NOT EXISTS \`pma_table_info\` (
  \`db_name\` varchar(64) NOT NULL default '',
  \`table_name\` varchar(64) NOT NULL default '',
  \`display_field\` varchar(64) NOT NULL default '',
  PRIMARY KEY  (\`db_name\`,\`table_name\`)
)
  ENGINE=MyISAM COMMENT='Table information for phpMyAdmin'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

-- --------------------------------------------------------

--
-- Table structure for table `pma_designer_coords`
--

CREATE TABLE IF NOT EXISTS \`pma_designer_coords\` (
  \`db_name\` varchar(64) NOT NULL default '',
  \`table_name\` varchar(64) NOT NULL default '',
  \`x\` INT,
  \`y\` INT,
  \`v\` TINYINT,
  \`h\` TINYINT,
  PRIMARY KEY (\`db_name\`,\`table_name\`)
)
  ENGINE=MyISAM COMMENT='Table coordinates for Designer'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

EOF
}



# ----------------------------------------------------------------------------
# Create Header for the SQL-Script
createSQLScriptAlterDB ()
{
	givenHost=$1
	givenDBName=$2
	givenControluser=$3

	cat >${tmpSQLScript} <<EOF
-- -------------------------------------------------------------
-- SQL Commands to upgrade pmadb for normal phpMyAdmin operation
-- with MySQL 4.1.2 and above.
--
-- Modified for usage in the EisFair package
--
-- This file is meant for use with MySQL 4.1.2 and above!
-- For older MySQL releases, please use create_tables.sql
--
-- If you are running one MySQL 4.1.0 or 4.1.1, please create the tables using
-- create_tables.sql, then use this script.
--
-- Please don't forget to set up the tablenames in config.inc.php
--
-- Original-Id: upgrade_tables_mysql_4_1_2+.sql 10212 2007-03-27 13:53:14Z cybot_tm
-- based on:
-- $Id: phpmyadmin-tools-pma-db 30906 2012-05-25 12:19:04Z starwarsfan $

-- --------------------------------------------------------

--
-- Database : \`${givenDBName}\`
--
ALTER DATABASE \`${givenDBName}\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
USE ${givenDBName};

-- --------------------------------------------------------

--
-- Table structure for table \`pma_bookmark\`
--
ALTER TABLE \`pma_bookmark\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_bookmark\`
  CHANGE \`dbase\` \`dbase\` VARCHAR( 255 ) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_bookmark\`
  CHANGE \`user\` \`user\` VARCHAR( 255 ) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_bookmark\`
  CHANGE \`label\` \`label\` VARCHAR( 255 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '';
ALTER TABLE \`pma_bookmark\`
  CHANGE \`query\` \`query\` TEXT CHARACTER SET utf8 COLLATE utf8_bin NOT NULL;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_column_info\`
--

ALTER TABLE \`pma_column_info\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_column_info\`
  CHANGE \`db_name\` \`db_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`table_name\` \`table_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`column_name\` \`column_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`comment\` \`comment\` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`mimetype\` \`mimetype\` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`transformation\` \`transformation\` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_column_info\`
  CHANGE \`transformation_options\` \`transformation_options\` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';

-- --------------------------------------------------------

--
-- Table structure for table \`pma_history\`
--
ALTER TABLE \`pma_history\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_history\`
  CHANGE \`username\` \`username\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_history\`
  CHANGE \`db\` \`db\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_history\`
  CHANGE \`table\` \`table\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_history\`
  CHANGE \`sqlquery\` \`sqlquery\` TEXT CHARACTER SET utf8 COLLATE utf8_bin NOT NULL;

-- --------------------------------------------------------

--
-- Table structure for table \`pma_pdf_pages\`
--

ALTER TABLE \`pma_pdf_pages\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_pdf_pages\`
  CHANGE \`db_name\` \`db_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_pdf_pages\`
  CHANGE \`page_descr\` \`page_descr\` VARCHAR(50) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL default '';

-- --------------------------------------------------------

--
-- Table structure for table \`pma_relation\`
--
ALTER TABLE \`pma_relation\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_relation\`
  CHANGE \`master_db\` \`master_db\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_relation\`
  CHANGE \`master_table\` \`master_table\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_relation\`
  CHANGE \`master_field\` \`master_field\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_relation\`
  CHANGE \`foreign_db\` \`foreign_db\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_relation\`
  CHANGE \`foreign_table\` \`foreign_table\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_relation\`
  CHANGE \`foreign_field\` \`foreign_field\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';

-- --------------------------------------------------------

--
-- Table structure for table \`pma_table_coords\`
--

ALTER TABLE \`pma_table_coords\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_table_coords\`
  CHANGE \`db_name\` \`db_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_table_coords\`
  CHANGE \`table_name\` \`table_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';

-- --------------------------------------------------------

--
-- Table structure for table \`pma_table_info\`
--

ALTER TABLE \`pma_table_info\`
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;

ALTER TABLE \`pma_table_info\`
  CHANGE \`db_name\` \`db_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_table_info\`
  CHANGE \`table_name\` \`table_name\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';
ALTER TABLE \`pma_table_info\`
  CHANGE \`display_field\` \`display_field\` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '';

-- --------------------------------------------------------

--
-- Table structure for table \`pma_designer_coords\`
--

CREATE TABLE IF NOT EXISTS \`pma_designer_coords\` (
  \`db_name\` varchar(64) NOT NULL default '',
  \`table_name\` varchar(64) NOT NULL default '',
  \`x\` INT,
  \`y\` INT,
  \`v\` TINYINT,
  \`h\` TINYINT,
  PRIMARY KEY (\`db_name\`,\`table_name\`)
)
  ENGINE=MyISAM COMMENT='Table coordinates for Designer'
  DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;


EOF
}



# ----------------------------------------------------------------------------
# create the sql script and execute it
doDBOperation ()
{
	givenServernumber=$1

	# check if $givenServernumber is in range
	if [ "${givenServernumber}" -gt 0 -a "${givenServernumber}" -le "${PHPMYADMIN_SERVER_N}" ] ; then

	    # check if entered server is active
	    eval active='${PHPMYADMIN_SERVER_'${givenServernumber}'_ACTIVE}'
	    if [ "${active}" = "yes" ] ; then

	        # check if advanced features are activated
	        eval advancedFeaturesActive='${PHPMYADMIN_SERVER_'${givenServernumber}'_ADVANCED_FEATURES}'
			if [ "${advancedFeaturesActive}" == "yes" ] ; then
		        eval host='${PHPMYADMIN_SERVER_'${givenServernumber}'_HOST}'
		        eval port='${PHPMYADMIN_SERVER_'${givenServernumber}'_PORT}'
	            eval pmadb='${PHPMYADMIN_SERVER_'${givenServernumber}'_PMADB}'
	            eval controluser='${PHPMYADMIN_SERVER_'${givenServernumber}'_CONTROLUSER}'
	            eval controlpass='${PHPMYADMIN_SERVER_'${givenServernumber}'_CONTROLPASS}'

	            mecho ""
	            dbAdmin=`/var/install/bin/ask "Please enter name of DB admin: " "" "+"`
				mecho -n "Please enter password: "
				stty -echo
				read dbAdminPass
				stty echo
				mecho ""

				foundPMADB=`${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} -e"USE ${pmadb};"`
				foundPMADB=`${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} -e"SHOW DATABASES" | grep -c "^${pmadb}$"`
				mecho "host: '${host}'"
				mecho "port: '${port}'"
				mecho "pmadb: '${pmadb}'"
				mecho "found: '${foundPMADB}'"
				if [ ${foundPMADB} -eq 1 ] ; then
					# pmadb exists, ask for next steps
					mecho ""
					mecho -n "Database '"
					mecho -n --info "${pmadb}"
					mecho "' exists!"
					mecho "Please choose:"
					mecho " - Remove database and create 'N'ew,"
					mecho " - 'A'lter existing database,"
					mecho " - 'D'rop database or"
					nextStep=`/var/install/bin/ask " - 'C'ancel: " "C" "N" "A" "D" "C"`
					if [ "${nextStep}" = "N" ] ; then
						# drop db and create new
						mecho ""
						mecho -n "Creating SQL script for server '"
						mecho -n --info "${host}"
						mecho -n "'... "
						createSQLScriptHeader ${host} ${pmadb} ${controluser}
						createSQLScriptDropDB ${host} ${pmadb} ${controluser}
					#	createSQLScriptGrantPrivileges ${host} ${pmadb} ${controluser}
						createSQLScriptCreateTables ${host} ${pmadb} ${controluser}
						mecho "Done"
						mecho -n "Executing SQL script for server '"
						mecho -n --info "${host}"
						mecho -n "'... "
						${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} < ${tmpSQLScript}
						mecho "Done"
						mecho -n "Removing SQL script... "
						rm ${tmpSQLScript}
						mecho "Done"
					elif [ "${nextStep}" = "A" ] ; then
						# alter existing pma database
						mecho ""
						mecho -n "Creating SQL script for server '"
						mecho -n --info "${host}"
						mecho -n "' to alter pma database... "
						createSQLScriptAlterDB ${host} ${pmadb} ${controluser}
						mecho "Done"
						mecho -n "Executing SQL script for server '"
						mecho -n --info "${host}"
						mecho -n "'... "
						${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} < ${tmpSQLScript}
						mecho "Done"
						mecho -n "Removing SQL script... "
						rm ${tmpSQLScript}
						mecho "Done"
					elif [ "${nextStep}" = "D" ] ; then
						# drop pma database
						mecho ""
						mecho -n "Removing pma database '"
						mecho -n --info "${pmadb}"
						mecho -n "' on server '"
						mecho -n --info "${host}"
						mecho -n "'... "
						${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} -e"DROP DATABASE ${pmadb};"
						mecho "Done"
					fi
				else
					# pmadb not found, create new
					mecho ""
					mecho -n "Creating SQL script for server '"
					mecho -n --info "${host}"
					mecho -n "'... "
					createSQLScriptHeader ${host} ${pmadb} ${controluser}
					createSQLScriptCreateDB ${host} ${pmadb} ${controluser}
				#	createSQLScriptGrantPrivileges ${host} ${pmadb} ${controluser}
					createSQLScriptCreateTables ${host} ${pmadb} ${controluser}
					mecho "Done"
					mecho -n "Executing SQL script for server '"
					mecho -n --info "${host}"
					mecho -n "'... "
					${mysql_base_dir}/bin/mysql -h ${host} -u${dbAdmin} -p${dbAdminPass} < ${tmpSQLScript}
					mecho "Done"
					mecho -n "Removing SQL script... "
					rm ${tmpSQLScript}
					mecho "Done"
				fi

			else	# advanced features not activated
				mecho
				mecho --info "Advanced features on server ${givenServernumber} not active"
				mecho
	        fi		# end of advanced features active check
	    else	# given server number is not active
			mecho
			mecho --info "Server ${givenServernumber} is not active"
			mecho
	    fi		# end of server active check
	else	# given server is out of range
		mecho
		mecho --info "There are only ${PHPMYADMIN_SERVER_N} servers configured,"
		mecho --info "but you entered ${givenServernumber}. Choose another one."
		mecho
	fi		# end of amount of servers check

	/var/install/bin/anykey
}


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
inputValue="0"

if [ ! `apk info | grep "^mysql$" ` ] ; then
    mecho --warn "You need to install package 'mysql' to use this feature!"
    exit 1
fi

until [ "${inputValue}" = "q" ] ; do
  	mecho ""
  	mecho "This script will create, alter or delete the pma database. To do"
  	mecho "this you have to choose one of the available servers and enter name"
  	mecho "and password of a user with admin rights on the choosen server."
  	mecho ""
	/var/install/bin/phpmyadmin-tools-listservers.sh

    inputValue=`/var/install/bin/ask "Please choose a server, 'q' for quit: " "" "*"`
    if [ "${inputValue}" != "q" ] && [ ${inputValue} -gt 0 ] ; then
		doDBOperation ${inputValue}
    fi
  done

exit 0
