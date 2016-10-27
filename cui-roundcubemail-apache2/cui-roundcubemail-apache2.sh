#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/roundcubemail-apache2.sh 
# - Configuration generator script for RoundCube client
#
# Copyright (c) 2012-2016 The Eisfair Team, team(at)eisfair(dot)org
# Creation:    2012-12-19 jed
#
# Parameters:
#   roundcube.sh                        - generates all configuration files
#   roundcube.sh --create-sql-db        - initialize sql database
#   roundcube.sh --delete-sql-db [db-type][db-user][db-password]
#                                       - delete sql database
#   roundcube.sh --remove-cron          - remove cronjob
# ----------------------------------------------------------------------------

# read eislib
. /var/install/include/eislib

#exec 2>/tmp/roundcubemail-apache2-trace-$$.log
#set -x
testroot=""

pgmname=$(basename $0)
tty=$(tty)

crontab_path=${testroot}/etc/cron/root
roundcube_path=${testroot}/usr/share/webapps/roundcube
roundcube_apache_user="root"
roundcube_apache_group="root"

# Set path names
roundcube_data_path=${roundcube_path}/data
roundcube_config_path=${roundcube_path}/config
roundcube_log_path=${roundcube_path}/log

# Set file names
apache2file=${testroot}/etc/config.d/apache2
mailfile=${testroot}/etc/config.d/mail
php5file=${testroot}/etc/config.d/php-apache2
vmailfile=${testroot}/etc/config.d/vmail
roundcubefile=${testroot}/etc/config.d/roundcubemail-apache2
mariadbfile=${testroot}/etc/config.d/mariadb
mysqlfile=${testroot}/etc/config.d/mysql
postgresfile=${testroot}/etc/config.d/postgresql
postgrespwfile=/root/.pgpass
configlog_file=${roundcube_log_path}/roundcube-configlog
crontab_file=${crontab_path}/roundcube
services_file=${testroot}/etc/services
version_file=${roundcube_path}/roundcube_version
packagefile=${testroot}/var/install/packages/roundcube

docroot_filelist=${roundcube_path}/rc-filelist.txt
docroot_addlist=${roundcube_path}/rc-docroot.lst
docroot_dellist=${roundcube_path}/rc-docroot.del
docroot_tmplist=/tmp/rc-docroot.$$

DB_NAME='roundcube'
DB_HOST='localhost'

# Other parameters
roundcube_version=$(apk info roundcubemail | head -1 | cut -d '-' -f2)

# Load configuration
. ${roundcubefile}
chmod 600 ${roundcubefile}

if [ "${ROUNDCUBE_DB_TYPE}" = "" ] ; then
    ROUNDCUBE_DB_TYPE='sqlite'
fi

case ${ROUNDCUBE_DB_TYPE} in
    mysql|mysqli)
        # MySQL
        SQL_BIN=/usr/bin/mysql
        ;;
    pgsql)
        # PostgreSQL
        SQL_BIN=/usr/local/pgsql/bin/psql
        ;;
    sqlite)
        # SQLite3
        SQL_BIN=/usr/bin/sqlite3
        ;;
    *)
        # mssql, sqlsrv
        SQL_BIN=/usr/bin/${ROUNDCUBE_DB_TYPE}
        ;;
esac

if [ "${ROUNDCUBE_CRON_SCHEDULE}" = "" ] ; then
    ROUNDCUBE_CRON_SCHEDULE='14 1 * * *'
fi

# ----------------------------------------------------------------------------
# Check if vmail has been enabled
# input:  $1 - '--quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_installed_vmail ()
{
    retval=1

    if [ -f ${vmailfile} ] ; then
        # vmail installed
        . ${vmailfile}

        if [ "${START_VMAIL}" = "yes" ] ; then
            # vmail activated
            if [ "${1}" != "--quiet" ] ; then
                echo "vmail has been enabled ..."
            fi
            retval=0
        else
            # vmail deactivated
            if [ "${1}" != "--quiet" ] ; then
                echo "vmail is currently disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if Apache2 SSL has been enabled
#
# input:  $1 - '--quiet' - suppress screen output
# return:  0 - extension enabled
#          1 - extension disabled
# ----------------------------------------------------------------------------
check_active_apache_ssl ()
{
    retval=1

    if [ -f ${apache2file} ] ; then
        . ${apache2file}

        if [ "$(echo "${APACHE2_SSL}" | tr '[:upper:]' '[:lower:]')" = "yes" ] ; then
            # ssl support activated
            if [ "${1}" != "--quiet" ] ; then
                echo "Apache2 SSL has been enabled ..."
            fi
            retval=0
        else
            # ssl support deactivated
            if [ "${1}" != "--quiet" ] ; then
                echo "Apache2 SSL has been disabled ..."
                echo "set APACHE2_SSL='yes'"
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if php_ldap has been enabled
# input:  $1 - '--quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_active_php_ldap ()
{
    retval=1

    # Check if ldap support is required
    capl_ldap_required=false
    if [ "${START_ROUNDCUBE}" = "yes" ] ; then
        capl_jdx=1
        while [ ${capl_jdx} -le ${ROUNDCUBE_GLOBADDR_LDAP_N} ] ; do
            eval capl_globldap_active='$ROUNDCUBE_GLOBADDR_LDAP_'${capl_jdx}'_ACTIVE'

            if [ "${capl_globldap_active}" = "yes" ] ; then
                capl_ldap_required=true
                break
            fi
            capl_jdx=$(expr ${capl_jdx} + 1)
        done
    fi

    if ${capl_ldap_required} ; then
        # ldap support required check php parameter
        if [ -f ${php5file} ] ; then
            # apache2_php5 installed
            . ${php5file}

            if [ "${PHP_EXT_LDAP}" = "yes" ] ; then
                # ldap support activated
                if [ "${1}" != "--quiet" ] ; then
                    echo "php-ldap has been enabled ..."
                fi
                retval=0
            else
                # ldap support deactivated
                if [ "${1}" != "--quiet" ] ; then
                    echo "php-ldap is currently disabled ..."
                fi
                error "PHP_EXT_LDAP='yes' has not been set!"
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if php_sqlite3 has been enabled
# input:  $1 - '--quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_active_php_sqlite ()
{
    retval=1

    if [ -f ${php5file} ] ; then
        # apache2_php5 installed
        . ${php5file}

        if [ "${PHP_EXT_SQLITE3}" = "yes" ] ; then
            # sqlite support activated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-sqlite3 has been enabled ..."
            fi
            retval=0
        else
            # sqlite support deactivated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-sqlite3 is currently disabled ..."
            fi
            error "PHP_EXT_SQLITE3='yes' has not been set!"
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if php_mysql has been enabled
#
# input:  $1 - '--quiet' - suppress screen output
# return:  0 - extension enabled
#          1 - extension disabled
# ----------------------------------------------------------------------------
check_active_php_mysql ()
{
    retval=1

    if [ -f ${php5file} ] ; then
        # apache2_php5 installed
        . ${php5file}

        mysql_php=1
        if [ "${PHP_EXT_MYSQL}" = "yes" ] ; then
            # mysql support activated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-mysql has been enabled ..."
            fi
            mysql_php=0
        else
            # mysql support deactivated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-mysql has been disabled ..."
                echo "set PHP_EXT_MYSQL='yes'"
            fi
        fi

        mysql_socket=1
        if [ "${PHP_EXT_MYSQL_SOCKET}" = "/var/run/mysql/mysql.sock" ] ; then
            if [ "${1}" != "--quiet" ] ; then
                echo "php-mysql-socket has correctly been set ..."
            fi
            mysql_socket=0
        else
            if [ "${1}" != "--quiet" ] ; then
                echo "php-mysql-socket hasn't been set correctly ..."
                echo "set PHP_EXT_MYSQL_SOCKET='/var/run/mysql/mysql.sock'"
            fi
        fi

        if [ ${mysql_php} -eq 0 -a ${mysql_socket} -eq 0 ] ; then
            retval=0
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if php_pgsql has been enabled
#
# input:  $1 - '--quiet' - suppress screen output
# return:  0 - extension enabled
#          1 - extension disabled
# ----------------------------------------------------------------------------
check_active_php_pgsql ()
{
    retval=1

    if [ -f ${php5file} ] ; then
        # apache2_php5 installed
        . ${php5file}

        if [ "${PHP_EXT_PGSQL}" = "yes" ] ; then
            # pgsql support activated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-pgsql has been enabled ..."
            fi
            retval=0
        else
            # pgsql support deactivated
            if [ "${1}" != "--quiet" ] ; then
                echo "php-pgsql has been disabled ..."
                echo "set PHP_EXT_PGSQL='yes'"
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------
# Check if port is accessible
# input : $1 - server name
#         $2 - port number
# return:  0 - successful
#          1 - unsuccessful
#----------------------------------------------------------------------------------
check_port_availabilty ()
{
    _cpa_sname=$1
    _cpa_sport=$2

    ${roundcube_path}/bin/check_open_port.pl "${_cpa_sname}" "${_cpa_sport}"
    _cpa_ret=$?

    return ${_cpa_ret}
}

# ----------------------------------------------------------------------------
# get smtp port
# input : $1 - smtp port string
# return: smtp tcp-port number
# ----------------------------------------------------------------------------
get_smtp_port ()
{
    smtp_str=$1

    if [ "${smtp_str}" != "" ] ; then
        if is_numeric ${smtp_str} ; then
            # numeric value is ok
            smtp_nbr=${smtp_str}
        else
            # non-numeric value
            smtp_nbr=$(cat ${services_file} | tr -s ' \011\/' ':' | grep -E "^${smtp_str}:[0-9]+:tcp" | cut -d: -f2)

            if ! is_numeric ${smtp_nbr} ; then
                smtp_nbr='25'
            fi
        fi
    fi

    echo ${smtp_nbr}
}

# ----------------------------------------------------------------------------
# Check if mysql has been enabled
# input:  $1 - '--quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_installed_mysql ()
{
    retval=1
    if [ "${ROUNDCUBE_DB_TYPE}" = "mysql" -a \( -f ${mysqlfile} -o -f ${mariadbfile} \) ] ; then
        # mysql installed
        if [ -f ${mysqlfile} ] ; then
            . ${mysqlfile}
        elif [ -f ${mariadbfile} ] ; then
            . ${mariadbfile}
        fi

        mysql_active=1
        if [ "${START_MYSQL}" = 'yes' -o "${START_MARIADB}" = 'yes' ] ; then
            # mysql activated
            if [ "$1" != "--quiet" ] ; then
                echo "MySQL/MariaDB support has been enabled ..."
            fi
            mysql_active=0
        else
            # mysql deactivated
            if [ "$1" != "--quiet" ] ; then
                echo "MySQL/MariaDB support has been disabled ..."
            fi
        fi
    fi

    if [ ${mysql_active} -eq 0 ] ; then
        retval=0
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Check if postgres has been enabled
# input:  $1 - '--quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_installed_postgres ()
{
    retval=1
    if [ "${ROUNDCUBE_DB_TYPE}" = "pgsql" -a -f ${postgresfile} ] ; then
        # postgres installed
        . ${postgresfile}

        if [ "${START_POSTGRESQL}" = "yes" ] ; then
            # postgres activated
            if [ "$1" != "--quiet" ] ; then
                echo "PostgreSQL support has been enabled ..."
            fi
            retval=0
        else
            # postgres deactivated
            if [ "$1" != "--quiet" ] ; then
                echo "PostgreSQL support has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# Ask for sql root password
# ----------------------------------------------------------------------------
get_sql_root_password ()
{
    if [ "${root_pass}" = "" ] ; then
        /var/install/bin/ask "Please enter the SQL root password" "" "*" > /tmp/ask.$$
        rc=$?
        root_pass=$(cat /tmp/ask.$$ | sed 's/ *//g')
        rm -f /tmp/ask.$$

        if [ "${ROUNDCUBE_DB_TYPE}" = "pgsql" ] ; then
            # hostname:port:database:username:password
            echo "${DB_HOST}:\*:\*:postgres:${root_pass}" >> ${postgrespwfile}
        fi

        if [ ${rc} = 255 ] ; then
            rm ${tmpfile}
            exit 1
        fi
    fi
}

# ----------------------------------------------------------------------------
# Create SQL database and table
# $1 - force or ''
# ----------------------------------------------------------------------------
create_sql_db_and_table ()
{
    if [ "${START_ROUNDCUBE}" != "yes" ] ; then
        # no active instance found, exit function
        error "Unable to initialize database because no active Roundcube instance found!"
        return 1
    fi

    db_type="${ROUNDCUBE_DB_TYPE}"
    db_user="${ROUNDCUBE_DB_USER}"
    db_pass="${ROUNDCUBE_DB_PASS}"

    if [ "$1" = "force" ] ; then
        force=1
    else
        force=0
    fi

    if [ "${db_type}" = "" ] ; then
        db_type='sqlite'
    fi

    if [ "${db_type}" != "sqlite" ] ; then
        if [ "${db_user}" = "" ] ; then
            db_user='roundcube'
        fi

        if [ "${db_pass}" = "" ] ; then
            db_pass='pass'
            warn "The parameter ROUNDCUBE_DB_PASS hasn't been set therefore the default password 'pass' will be used!"
        fi
    fi

    # set database specific options
    case ${db_type} in
        mysql|mysqli)
            # MySQL
            sql_init=${roundcube_path}/SQL/mysql.initial.sql
            ;;
        pgsql)
            # PostgreSQL
            sql_init=${roundcube_path}/SQL/postgres.initial.sql
            ;;
        sqlite)
            # SQLite3
            sql_init=${roundcube_path}/SQL/sqlite.initial.sql
            ;;
        *)
            # mssql, sqlsrv
            sql_init=${roundcube_path}/SQL/${db_type}.initial.sql
            ;;
    esac

    case ${db_type} in
        mysql|mysqli|mssql|sqlsrv)
            root_pass=''
            sql_cmd_file=/var/run/roundcube-cmd-$$
            for step in 1 2 3 4 ; do
                # delete sql command file
                rm -f ${sql_cmd_file}

                case ${step} in
                    1)
                        step_name="checking sql database user"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"QUIT" 2>/dev/null

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            # sql user doesn't exist, go on...
                            echo
                            get_sql_root_password

                            {
                                if [ ${force} -eq 1 ] ; then
                                    echo "DROP USER '${db_user}'@'${DB_HOST}';"
                                fi

                                echo "CREATE USER '${db_user}'@'${DB_HOST}' IDENTIFIED BY '${db_pass}';"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;

                    2)
                        step_name="checking sql database"
                        echo -n "${step_name} ..."
                        db_exists=$(${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW DATABASES" | grep -c "${DB_NAME}$")

                        if [ ${db_exists} -eq 0 -o ${force} -eq 1 ] ; then
                            # sql database doesn't exist or no access rights have been granted, go on...
                            echo
                            get_sql_root_password

                            {
                                if [ ${force} -eq 1 ] ; then
                                    echo "DROP DATABASE ${DB_NAME};"
                                fi

                                echo "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;

                    3)
                        step_name="granting sql database access"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW GRANTS FOR '${db_user}'@'${DB_HOST}'" | grep -q -E "GRANT ALL PRIVILEGES ON .*${DB_NAME}.*\.\* TO .*${db_user}.*@.*${DB_HOST}" 2> /dev/null

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            echo
                            get_sql_root_password

                            {
                                echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${db_user}'@'${DB_HOST}' IDENTIFIED BY '${db_pass}';"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;
                    4)
                        step_name="initializing sql database"
                        echo -n "${step_name} ..."
                        table_exists=$(${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -D${DB_NAME} -e"SHOW TABLES" | grep -c "^users$")

                        if [ ${table_exists} -eq 0 -o ${force} -eq 1 ] ; then
                            # sql table doesn't exist or no access rights have been granted, go on...
                            echo
                            get_sql_root_password

                            if [ -f ${sql_init} ] ; then
                                {
                                echo "USE ${DB_NAME};"
                                cat ${sql_init}
                                } > ${sql_cmd_file}
                            fi
                        else
                            echo "done."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -uroot -p${root_pass} < ${sql_cmd_file} 2>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        echo "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        echo "failed."
                        echo  "an error appeared while ${step_name}!"
                        break
                    fi
                fi
            done
            ;;

        pgsql)
            root_pass=''
            sql_cmd_file=/var/run/roundcube-cmd-$$

            # if the environment variable PGPASSWORD is set that password
            # file will be read instead of the default /root/.pgpass
            # hostname:port:database:username:password
            echo "${DB_HOST}:\*:\*:${db_user}:${db_pass}" > ${postgrespwfile}
            chmod 0600 ${postgrespwfile}

            for step in 1 2 3 4 ; do
                # delete sql command file
                rm -f ${sql_cmd_file}

                case ${step} in
                    1)
                        step_name="checking sql database user"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -U${db_user} -l >/dev/null 2>/dev/null

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            # sql user doesn't exist, go on...
                            echo
                          # get_sql_root_password

                            {
                                if [ ${force} -eq 1 ] ; then
                                    echo "DROP USER '${db_user};"
                                fi

                                echo "CREATE USER ${db_user} WITH PASSWORD '${db_pass}';"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;
                    2)
                        step_name="checking sql database"
                        echo -n "${step_name} ..."
                        db_exists=$(${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep -c "^ ${DB_NAME} ")

                        if [ ${db_exists} -eq 0 -o ${force} -eq 1 ] ; then
                            # sql database doesn't exist or no access rights have been granted, go on...
                            echo
                          # get_sql_root_password

                            {
                                if [ ${force} -eq 1 ] ; then
                                    echo "DROP DATABASE ${DB_NAME};"
                                fi

                                echo "CREATE DATABASE ${DB_NAME} TEMPLATE template0 ENCODING 'UNICODE';"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;
                    3)
                        step_name="granting sql database access"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep " ${DB_NAME} " | cut -d'|' -f2 | sed -e 's/^ */:/' -e 's/ *$/:/' | grep -q ":${db_user}:"

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            echo
                          # get_sql_root_password

                            {
                                echo "ALTER DATABASE ${DB_NAME} OWNER TO ${db_user};"
                            } > ${sql_cmd_file}
                        else
                            echo "done."
                        fi
                        ;;
                    4)
                        step_name="initializing sql database"
                        echo -n "${step_name} ..."
                        table_exists=$(${SQL_BIN} --tuples-only -h${DB_HOST} -U${db_user} -d${DB_NAME} -c "SELECT * FROM pg_catalog.pg_tables WHERE tablename = 'users'" | grep -c " users ")

                        if [ ${table_exists} -eq 0 -o ${force} -eq 1 ] ; then
                            # sql table doesn't exist or no access rights have been granted, go on...
                            echo
                          # get_sql_root_password

                            if [ -f ${sql_init} ] ; then
                                {
                                    printf "\c - %s\n" "${db_user}" # switch user to $db_user
                                    printf "\c %s;\n" "${DB_NAME}"  # switch to database $DB_NAME
                                    cat ${sql_init}                 # paste commands for db initialization
                                } > ${sql_cmd_file}
                            fi
                        else
                            echo "done."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -Upostgres < ${sql_cmd_file} >>${roundcube_path}/roundcube-sql-db-results.txt 2>>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        echo "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        echo "failed."
                        echo  "an error appeared while ${step_name}!"
                        break
                    fi
                fi
            done
            ;;

        *|sqlite)
            # Warning: for SQLite use absolute path in DSN:
            if [ ! -f ${roundcube_data_path}/roundcubemail.db ] ; then
                # create initial database
                step_name="initializing sql database"
                echo -n "${step_name} ..."
                ${SQL_BIN} ${roundcube_data_path}/roundcubemail.db < ${sql_init} 2>${roundcube_path}/roundcube-sql-db-results.txt

                if [ $? -eq 0 ] ; then
                    # database created
                    rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                    echo "done."
                else
                    # error
                    echo "failed."
                    echo  "an error appeared while ${step_name}!"
                    break
                fi
            fi
            ;;
    esac
}

# ----------------------------------------------------------------------------
# Remove SQL table and database
# $1 - db_type - optional: sqlite, mysql, pgsql
# $2 - db_user - optional: username for db access, required by mysql and pgsql
# $3 - db_pass - optional: password for db accees, required by mysql
# ----------------------------------------------------------------------------
remove_sql_db_and_table()
{
    if [ "$1" != "" ] ; then
        db_type="$1"
    else
        db_type="${ROUNDCUBE_DB_TYPE}"
    fi

    if [ "$2" != "" ] ; then
        db_user="$2"
    else
        db_user="${ROUNDCUBE_DB_USER}"
    fi

    if [ "$3" != "" ] ; then
        db_pass="$3"
    else
        db_pass="${ROUNDCUBE_DB_PASS}"
    fi

    if [ "${db_type}" = "" ] ; then
        db_type='sqlite'
    fi

    if [ "${db_type}" != "sqlite" ] ; then
        if [ "${db_user}" = "" ] ; then
            db_user='roundcube'
        fi

        if [ "${db_pass}" = "" ] ; then
            db_pass='pass'
        fi
    fi

    case ${db_type} in
        mysql|mysqli|mssql|sqlsrv)
            # create sql command file
            root_pass=''
            sql_cmd_file=/var/run/roundcube-cmd-$$
            for step in 1 2 ; do
                # delete sql command file
                rm -f ${sql_cmd_file}

                case ${step} in
                    1)
                        step_name="removing sql database"
                        echo -n "${step_name} ..."
                        db_exists=$(${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW DATABASES" | grep -c "${DB_NAME}$")

                        if [ ${db_exists} -ne 0 ] ; then
                            echo
                            get_sql_root_password

                            {
                                echo "DROP DATABASE ${DB_NAME};"
                            } > ${sql_cmd_file}
                        else
                            echo "not found."
                        fi
                        ;;
                    2)
                        step_name="removing sql database user"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"QUIT" > /dev/null

                        if [ $? -eq 0 ] ; then
                            # database can be accessed, go on...
                            echo
                            get_sql_root_password

                            {
                                echo "DROP USER '${db_user}'@'${DB_HOST}';"
                            } > ${sql_cmd_file}
                        else
                            echo "not found."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -uroot -p${root_pass} < ${sql_cmd_file} 2>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        echo "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        echo "failed."
                        echo  "an error appeared while ${step_name}!"
                        break
                    fi
                fi
            done
            ;;

        pgsql)
            # create sql command file
            root_pass=''
            sql_cmd_file=/var/run/roundcube-cmd-$$

            # if the environment variable PGPASSWORD is set that password
            # file will be read instead of the default /root/.pgpass
            # hostname:port:database:username:password
            echo "${DB_HOST}:\*:\*:${db_user}:${db_pass}" > ${postgrespwfile}
            chmod 0600 ${postgrespwfile}

            for step in 1 2 ; do
                # delete sql command file
                rm -f ${sql_cmd_file}

                case ${step} in
                    1)
                        step_name="removing sql database"
                        echo -n "${step_name} ..."
                        db_exists=$(${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep -c "^ ${DB_NAME} ")

                        if [ ${db_exists} -ne 0 ] ; then
                            echo
                          # get_sql_root_password

                            {
                                echo "DROP DATABASE ${DB_NAME};"
                            } > ${sql_cmd_file}
                        else
                            echo "not found."
                        fi
                        ;;
                    2)
                        step_name="removing sql database user"
                        echo -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -U${db_user} -l >/dev/null 2>/dev/null

                        if [ $? -eq 0 ] ; then
                            # database can be accessed, go on...
                            echo
                          # get_sql_root_password

                            {
                                echo "DROP USER ${db_user};"
                            } > ${sql_cmd_file}
                        else
                            echo "not found."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -Upostgres < ${sql_cmd_file} >>${roundcube_path}/roundcube-sql-db-results.txt 2>>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        echo "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        echo "failed."
                        echo  "an error appeared while ${step_name}!"
                        break
                    fi
                fi
            done
            ;;

        *|sqlite)
            # Warning: for SQLite use absolute path in DSN:
            if [ ! -f ${roundcube_data_path}/roundcubemail.db ] ; then
                # create initial database
                step_name="removing sql database"
                echo -n "${step_name} ..."
                rm -f ${roundcube_data_path}/roundcubemail.db

                echo "done."
            fi
            ;;
    esac
}

# ----------------------------------------------------------------------------
# Generate roundcube configuration
# $1 - Roundcube instance
# $2 - 'stop' - generate stop configuration
# ----------------------------------------------------------------------------
create_roundcube_conf ()
{
    rc_config_type=$1

    if [ "${START_ROUNDCUBE}" = "yes" ] ; then
		roundcube_dbconf_file=${roundcube_path}/config/db.inc.php
		roundcube_mainconf_file=${roundcube_path}/config/main.inc.php
		roundcube_conf_file=${roundcube_path}/config/config.inc.php
		roundcube_helpconf_file=${roundcube_path}/plugins/help/config.inc.php

		# check directories
		for DNAME in ${roundcube_data_path} ${roundcube_log_path} ; do
			if [ ! -f ${DNAME} ] ; then
				mkdir -p ${DNAME}
			fi

			# create .htaccess file
			{
				echo 'Order allow,deny'
				echo 'Deny from all'
			} > ${DNAME}/.htaccess

			chmod 0444 ${DNAME}/.htaccess
		done

		# remove obsolete configuration files
		rm -f ${roundcube_dbconf_file}   ${roundcube_dbconf_file}.dist
		rm -f ${roundcube_mainconf_file} ${roundcube_mainconf_file}.dist

		echo "- creating roundcube program configuration ..."

		eval rc_db_type='$ROUNDCUBE_DB_TYPE'
		eval rc_db_user='$ROUNDCUBE_DB_USER'
		eval rc_db_pass='$ROUNDCUBE_DB_PASS'

		eval rc_general_des_key='$ROUNDCUBE_GENERAL_DES_KEY'
		eval rc_general_def_charset='$ROUNDCUBE_GENERAL_DEF_CHARSET'
		eval rc_general_allow_receipt='$ROUNDCUBE_GENERAL_ALLOW_RECEIPTS_USE'
		eval rc_general_allow_ident='$ROUNDCUBE_GENERAL_ALLOW_IDENTITY_EDIT'

		eval rc_orga_provider_url='$ROUNDCUBE_ORGA_PROVIDER_URL'
		eval rc_orga_logo='$ROUNDCUBE_ORGA_LOGO'
		eval rc_orga_name='$ROUNDCUBE_ORGA_NAME'
		eval rc_orga_def_language='$ROUNDCUBE_ORGA_DEF_LANGUAGE'

		eval rc_server_domain='$ROUNDCUBE_SERVER_DOMAIN'
		eval rc_server_domain_check='$ROUNDCUBE_SERVER_DOMAIN_CHECK'
		eval rc_imap_hostport='$ROUNDCUBE_SERVER_IMAP_HOST'
		eval rc_imap_type='$ROUNDCUBE_SERVER_IMAP_TYPE'
		eval rc_imap_auth='$ROUNDCUBE_SERVER_IMAP_AUTH'
		eval rc_imap_transport='$ROUNDCUBE_SERVER_IMAP_TRANSPORT'
		eval rc_smtp_hostport='$ROUNDCUBE_SERVER_SMTP_HOST'
		eval rc_smtp_auth='$ROUNDCUBE_SERVER_SMTP_AUTH'
		eval rc_smtp_transport='$ROUNDCUBE_SERVER_SMTP_TRANSPORT'

		eval rc_mv_msgs_to_trash='$ROUNDCUBE_FOLDER_MOVE_MSGS_TO_TRASH'
		eval rc_mv_msgs_to_send='$ROUNDCUBE_FOLDER_MOVE_MSGS_TO_SEND'
		eval rc_mv_msgs_to_draft='$ROUNDCUBE_FOLDER_MOVE_MSGS_TO_DRAFT'
		eval rc_auto_expunge='$ROUNDCUBE_FOLDER_AUTO_EXPUNGE'
		eval rc_force_nsfolder='$ROUNDCUBE_FOLDER_FORCE_NSFOLDER'

		eval rc_plugins_use_all='$ROUNDCUBE_PLUGINS_USE_ALL'
		eval rc_plugins_n='$ROUNDCUBE_PLUGINS_N'

		eval rc_globldap_n='$ROUNDCUBE_GLOBADDR_LDAP_N'

		{
			echo "<?php"
			echo '/*'
			echo '+-----------------------------------------------------------------------+'
			echo '| Local configuration for the Roundcube Webmail installation generated  |'
			echo "| by ${pgmname}                                                       |"
			echo '|                                                                       |'
			echo "| Do not edit this file, edit ${roundcubefile}                   |"
			echo "| Creation date: $(date)                           |"
			echo '|                                                                       |'

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail
					echo '| Configuration type: vmail                                             |'
					;;
				*)
					# none local
					echo '| Configuration type: non-local                                         |'
					;;
			esac

			echo '|                                                                       |'
			echo '| This is the configuration file only containing the minumum setup      |'
			echo '| required for a functional installation. Copy more options from        |'
			echo '| defaults.inc.php to this file to override the defaults.               |'
			echo '|                                                                       |'
			echo '| This file is part of the Roundcube Webmail client                     |'
			echo '| Copyright (C) 2005-2013, The Roundcube Dev Team                       |'
			echo '|                                                                       |'
			echo '| Licensed under the GNU General Public License version 3 or            |'
			echo '| any later version with exceptions for skins & plugins.                |'
			echo '| See the README file for a full license statement.                     |'
			echo '+-----------------------------------------------------------------------+'
			echo '*/'
			echo
			echo "\$config = array();"
			echo
			echo '// ----------------------------------'
			echo '// DATABASE'
			echo '// ----------------------------------'
			echo
			# Database connection string (DSN) for read+write operations
			# Format (compatible with PEAR MDB2): db_provider://user:password@host/database
			# Currently supported db_providers: mysql, pgsql, sqlite, mssql or sqlsrv
			# For examples see http://pear.php.net/manual/en/package.database.mdb2.intro-dsn.php
			# NOTE: for SQLite use absolute path: sqlite:////full/path/to/sqlite.db?mode=0646

			if [ "${rc_db_type}" = "" ] ; then
				rc_db_type='sqlite'
			fi

			if [ "${rc_db_type}" != "sqlite" ] ; then
				if [ "${rc_db_user}" = "" ] ; then
					rc_db_user='roundcube'
				fi

				if [ "${rc_db_pass}" = "" ] ; then
					rc_db_pass='pass'
				fi
			fi

			if [ "${rc_config_type}" = "stop" ] ; then
				# generate stop configuration so that no-one can login to Roundcube
				echo "\$config['db_dsnw'] = '';"
			else
				case ${rc_db_type} in
					mysql|mysqli|mssql|sqlsrv|pgsql)
						echo "\$config['db_dsnw'] = '${rc_db_type}://${rc_db_user}:${rc_db_pass}@localhost/roundcubemail';"
						;;
					*|sqlite)
						# Warning: for SQLite use absolute path in DSN:
						echo "\$config['db_dsnw'] = 'sqlite:///${roundcube_data_path}/roundcubemail.db?mode=0646';"
						;;
				esac
			fi

			echo
			echo '// ----------------------------------'
			echo '// LOGGING/DEBUGGING'
			echo '// ----------------------------------'
			echo
			echo '// system error reporting, sum of: 1 = log; 2 = report (not implemented yet), 4 = show, 8 = trace'
			if [ "${ROUNDCUBE_DO_DEBUG}" = "yes" -a "${ROUNDCUBE_DEBUGLEVEL}" != "" ] ; then
				echo "\$config['debug_level'] = ${ROUNDCUBE_DEBUGLEVEL};"
				rc_debug_answer='true'
			else
				echo "\$config['debug_level'] = 1;"
				rc_debug_answer='false'
			fi

			echo
			echo "// log driver: 'syslog' or 'file'"
			echo "\$config['log_driver'] = 'file';"
			echo
			echo '// Log sent messages'
			echo "\$config['smtp_log'] = ${rc_debug_answer};"
			echo
			echo '// Log successful logins'
			echo "\$config['log_logins'] = ${rc_debug_answer};"
			echo
			echo '// Log session authentication errors'
			echo "\$config['log_session'] = ${rc_debug_answer};"
			echo
			echo '// Log SQL queries'
			echo "\$config['sql_debug'] = ${rc_debug_answer};"
			echo
			echo '// Log IMAP conversation'
			echo "\$config['imap_debug'] = ${rc_debug_answer};"
			echo
			echo '// Log LDAP conversation'
			echo "\$config['ldap_debug'] = ${rc_debug_answer};"
			echo
			echo '// Log SMTP conversation'
			echo "\$config['smtp_debug'] = ${rc_debug_answer};"
			echo
			echo '// ----------------------------------'
			echo '// IMAP'
			echo '// ----------------------------------'
			echo
			echo '// The mail host chosen to perform the log-in'
			# Leave blank to show a textbox at login, give a list of hosts
			# to display a pulldown menu or set one host as string.
			# To use SSL/TLS connection, enter hostname with prefix ssl:// or tls://
			# Supported replacement variables:
			# %h - user's IMAP hostname
			# %n - http hostname ($_SERVER['SERVER_NAME'])
			# %t - hostname without the first part
			# %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)
			# %z - IMAP domain (IMAP hostname without the first part)
			# For example %n = mail.domain.tld, %t = domain.tld

			if [ "${rc_imap_hostport}" = "" ] ; then
				rc_imap_hostport='localhost'
			fi

			echo "${rc_imap_hostport}" | grep -q ":"

			if [ $? -eq 0 ] ; then
				# split hostname and port
				rc_imap_host="$(echo ${rc_imap_hostport} | cut -d: -f1)"
				rc_imap_port="$(echo ${rc_imap_hostport} | cut -d: -f2)"
			else
				# hostname only
				rc_imap_host="${rc_imap_hostport}"
				rc_imap_port='143'
			fi

			if [ "${rc_imap_port}" = "" ] ; then
				# set default port
				rc_imap_port="143"
			fi

			case ${rc_imap_transport} in
				ssl)
					rc_imap_prefix='ssl://'
					;;
				tls)
					rc_imap_prefix='tls://'
					;;
				*)
					rc_imap_prefix=''
					;;
			esac

			echo "\$config['default_host'] = '${rc_imap_prefix}${rc_imap_host}';"
			echo
			echo '// TCP port used for IMAP connections'
			echo "\$config['default_port'] = ${rc_imap_port};"

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail
					;;
				*)
					# none local
					# check port number
					if [ "${rc_imap_port}" != "143" -a "${rc_imap_port}" != "993" ] ; then
						warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_IMAP_HOST='...:${rc_imap_port}' has been set to a non-standard port!"
						warn "This might cause a communication problem!"
					fi
					;;
			esac

			# check IMAP listen port availability
			if ! check_port_availabilty "${rc_imap_host}" "${rc_imap_port}"
			then
				warn "Unable to connect to IMAP server '${rc_imap_host}' on port '${rc_imap_port}/tcp'!"
			fi

			echo
			echo '// IMAP AUTH type (DIGEST-MD5, CRAM-MD5, LOGIN, PLAIN or null to use'
			echo '// best server supported one)'

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail
					echo "\$config['imap_auth_type'] = 'LOGIN';"
					;;
				*)
					# none local
					case ${rc_imap_auth} in
						digest)
							echo "\$config['imap_auth_type'] = 'DIGEST-MD5';"
							;;
						md5)
							echo "\$config['imap_auth_type'] = 'CRAM-MD5';"
							;;
						login)
							echo "\$config['imap_auth_type'] = 'LOGIN';"
							;;
					esac
					;;
			esac

			echo
			echo "// If you know your imap's folder delimiter, you can specify it here."
			echo '// Otherwise it will be determined automatically'
			case ${MAIL_INSTALLED} in
				vmail)
					# vmail (dovecot) - auto detect
					echo "\$config['imap_delimiter'] = NULL;"
					;;
				*)
					# none local
					case ${rc_imap_type} in
						courier)
							echo "\$config['imap_delimiter'] = '.';"
							;;
						dovecot)
							# auto detect
							echo "\$config['imap_delimiter'] = NULL;"
							;;
						uw)
							echo "\$config['imap_delimiter'] = '/';"
							;;
					esac
					;;
			esac

			echo
			echo "// Some server configurations (e.g. Courier) doesn't list folders in all namespaces"
			echo '// Enable this option to force listing of folders in all namespaces'
			case ${MAIL_INSTALLED} in
				vmail)
					if [ "${rc_force_nsfolder}" = "yes" ] ; then
						echo "\$config['imap_force_ns'] = true;"
					else
						echo "\$config['imap_force_ns'] = false;"
					fi
					;;
				*)
					# non-local
					# UW IMAP server
					if [ "${rc_imap_type}" = "uw" ] ; then
						if [ "${rc_force_nsfolder}" = "no" ] ; then
							echo "\$config['imap_force_ns'] = false;"
						else
							echo "\$config['imap_force_ns'] = true;"
						fi
					else
						# other IMAP servers
						if [ "${rc_force_nsfolder}" = "yes" ] ; then
							echo "\$config['imap_force_ns'] = true;"
						else
							echo "\$config['imap_force_ns'] = false;"
						fi
					fi
					;;
			esac

			echo
			echo '// List of disabled imap extensions'
			# Use if your IMAP server has broken implementation of some feature
			# and you can't remove it from CAPABILITY string on server-side.
			#
			# For example UW-IMAP server has broken ESEARCH.
			#
			# Some servers (dovecot 1.x) returns wrong results
			# for shared namespaces in this case. http://trac.roundcube.net/ticket/1486225
			# Set imap_disabled_caps = array('LIST-EXTENDED')
			#
			# Note: Because the list is cached, re-login is required after change.

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail (dovecot)
					echo "\$config['imap_disabled_caps'] = array('LIST-EXTENDED');"
					;;
				*)
					# none local
					case ${rc_imap_type} in
						courier)
							echo "\$config['imap_disabled_caps'] = array();"
							;;
						dovecot)
							# auto detect
							echo "\$config['imap_disabled_caps'] = array('LIST-EXTENDED');"
							;;
						uw)
							echo "\$config['imap_disabled_caps'] = array('ESEARCH');"
							;;
					esac
					;;
			esac

			echo
			echo '// ----------------------------------'
			echo '// SMTP'
			echo '// ----------------------------------'
			echo
			echo '// SMTP server host (for sending mails)'
			# To use SSL/TLS connection, enter hostname with prefix ssl:// or tls://
			# If left blank, the PHP mail() function is used
			# Supported replacement variables:
			# %h - user's IMAP hostname
			# %n - http hostname ($_SERVER['SERVER_NAME'])
			# %d - domain (http hostname without the first part)
			# %z - IMAP domain (IMAP hostname without the first part)
			# For example %n = mail.domain.tld, %d = domain.tld

			if [ "${rc_smtp_hostport}" = "" ] ; then
				rc_smtp_hostport='localhost'
			fi

			echo "${rc_smtp_hostport}" | grep -q ":"

			if [ $? -eq 0 ] ; then
				# split hostname and port
				rc_smtp_host="$(echo ${rc_smtp_hostport} | cut -d: -f1)"
				rc_smtp_port="$(echo ${rc_smtp_hostport} | cut -d: -f2)"
			else
				# hostname only
				rc_smtp_host="${rc_smtp_hostport}"
				rc_smtp_port='25'
			fi

			if [ "${rc_smtp_port}" = "" ] ; then
				# set default value
				rc_smtp_port='25'
			fi

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail - use default port
					# check hostname
				  # if [ "${rc_smtp_host}" != "localhost" -a "${rc_smtp_host}" != "127.0.0.1" ] ; then
				  #     warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='localhost' has not been set although vmail package has been installed!"
				  # fi
					;;
				*)
					# none local
					# check port number
					if [ "${rc_smtp_port}" != "25" -a "${rc_smtp_port}" != "587" ] ; then
						warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='...:${rc_smtp_port}' has been set to a non-standard port!"
						warn "This might cause a communication problem!"
					fi

					# check hostname
				  # if [ "${rc_smtp_host}" = "localhost" -o "${rc_smtp_host}" = "127.0.0.1" ] ; then
				  #     error "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='localhost' has been set although no vmail package has been installed!"
				  # fi
					;;
			esac

			# check SMTP listen port availability
			if ! check_port_availabilty "${rc_smtp_host}" "${rc_smtp_port}"	; then
				warn "Unable to connect to SMTP server '${rc_smtp_host}' on port '${rc_smtp_port}/tcp'!"
			fi

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail
					rc_smtp_prefix=''
					;;
				*)
					# none local
					case ${rc_smtp_transport} in
						ssl)
							rc_smtp_prefix='ssl://'
							;;
						tls)
							rc_smtp_prefix='tls://'
							;;
						*)
							# default
							rc_smtp_prefix=''
							;;
					esac
					;;
			esac

			echo "\$config['smtp_server'] = '${rc_smtp_prefix}${rc_smtp_host}';"
			echo
			echo '// SMTP port (default is 25; use 587 for STARTTLS or 465 for the'
			echo '// deprecated SSL over SMTP (aka SMTPS))'
			echo "\$config['smtp_port'] = ${rc_smtp_port};"

			echo
			echo '// SMTP username (if required)'
			# If you use %u as the username Roundcube will use the current username for login
			echo '//'
			echo '// SMTP password (if required)'
			# If you use %p as the password Roundcube will use the current user's password for login
			echo '//'
			echo '// SMTP AUTH type (DIGEST-MD5, CRAM-MD5, LOGIN, PLAIN or empty to use'
			echo '// best server supported one)'
			case ${MAIL_INSTALLED} in
				vmail)
					# vmail - no authentication
					echo "\$config['smtp_user'] = '%u';"
					echo "\$config['smtp_pass'] = '%p';"
					echo "\$config['smtp_auth_type'] = 'LOGIN';"
					;;
				*)
					# none local
					echo "\$config['smtp_user'] = '%u';"
					echo "\$config['smtp_pass'] = '%p';"

					case ${rc_smtp_auth} in
						digest)
							echo "\$config['smtp_auth_type'] = 'DIGEST-MD5';"
							;;
						md5)
							echo "\$config['smtp_auth_type'] = 'CRAM-MD5';"
							;;
						login)
							echo "\$config['smtp_auth_type'] = 'LOGIN';"
							;;
						*)
							echo "\$config['smtp_auth_type'] = '';"
							;;
					esac
					;;
			esac

			if [ "${rc_smtp_transport}" = "ssl" -o "${rc_smtp_transport}" = "tls" ] ; then
				echo '// SMTP connection timeout, in seconds.'
				# Default: 0 (use default_socket_timeout)'
				# Note: There's a known issue where using ssl connection with
				# timeout > 0 causes connection errors (https://bugs.php.net/bug.php?id=54511)
				echo "\$config['smtp_timeout'] = 1;"
				echo

				echo '// SMTP socket context options'
				# See http://php.net/manual/en/context.ssl.php
				# The example below enables server certificate validation, and
				# requires 'smtp_timeout' to be non zero.
				echo "\$config['smtp_conn_options'] = array("
				echo "  '${rc_smtp_transport}' => array("
				echo "    'verify_peer'       => true,"
				echo "    'allow_self_signed' => true,"
				echo "    'verify_depth'      => 5,"
				echo "    'capath'            => '/usr/local/ssl/certs',"
				echo "  ),"
				echo ");"
			fi

			echo
			echo '// ----------------------------------'
			echo '// SYSTEM'
			echo '// ----------------------------------'
			echo
			echo '// Provide an URL where a user can get support for this Roundcube installation'
			# PLEASE DO NOT LINK TO THE ROUNDCUBE.NET WEBSITE HERE!
			echo "\$config['support_url'] = '${rc_orga_provider_url}';"
			echo

			echo '// Replace Roundcube logo with this image'
			# specify an URL relative to the document root of this Roundcube installation
			# an array can be used to specify different logos for specific template files,
			# '*' for default logo
			# for example array("*" => "/images/roundcube_logo.png",
			#                   "messageprint" => "/images/roundcube_logo_print.png")
			if [ "${rc_orga_logo}" != "" ] ; then
				echo "\$config['skin_logo'] = '${rc_orga_logo}';"
			else
				echo "\$config['skin_logo'] = NULL;"
			fi

			echo
			echo '// Use this folder to store log files (must be writeable for apache user)'
			# This is used by the 'file' log driver.
			echo "\$config['log_dir'] = '${roundcube_log_path}/';"

			echo
#               echo '// enforce connections over https'
#               echo '// with this option enabled, all non-secure connections will be redirected.'
#               echo '// set the port for the ssl connection as value of this option if it differs from the default 443'
#               echo "\$config['force_https'] = false;"
#               echo
#               echo '// tell PHP that it should work as under secure connection'
#               echo "// even if it doesn't recognize it as secure (\$_SERVER['HTTPS'] is not set)"
#               echo "// e.g. when you're running Roundcube behind a https proxy"
#               echo "// this option is mutually exclusive to 'force_https' and only either one of them should be set to true."
#               echo "\$config['use_https'] = false;"
#               echo

			echo '// Forces conversion of logins to lower case'
			# 0 - disabled, 1 - only domain part, 2 - domain and local part.
			# If users authentication is case-insensitive this must be enabled.
			# Note: After enabling it all user records need to be updated, e.g. with query:
			# UPDATE users SET username = LOWER(username);

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail (dovecot)
					echo "\$config['login_lc'] = 2;"
					;;
				*)
					# none local
					case ${rc_imap_type} in
						courier)
							echo "\$config['login_lc'] = 0;"
							;;
						dovecot)
							echo "\$config['login_lc'] = 2;"
							;;
						uw)
							# mail (uw) - changed default to 'true' since v1.5.2
							echo "\$config['login_lc'] = 2;"
							;;
					esac
			esac

			echo
			echo '// Check client IP in session athorization'
			if [ "${MAIL_INSTALLED}" = "none" ] ; then
				# this needs to be set if RoundCube is not running on the same server as the vmail package
				echo "\$config['ip_check'] = false;"
			else
				echo "\$config['ip_check'] = true;"
			fi

			echo
			echo '// Check referer of incoming requests'
			if [ "${rc_server_domain_check}" = "yes" ] ; then
				echo "\$config['referer_check'] = true;"
			else
				echo "\$config['referer_check'] = false;"
			fi

			echo
			echo '// This key is used to encrypt the users imap password'
			# which is stored in the session record (and the client cookie
			# if remember password is enabled). Please provide a string of
			# exactly 24 chars.
			echo "\$config['des_key'] = '${rc_general_des_key}';"
			echo

			echo '// This domain will be used to form e-mail addresses of new users'
			# Specify an array with 'host' => 'domain' values to support multiple hosts
			# Supported replacement variables:
			# %h - user's IMAP hostname
			# %n - http hostname (\$_SERVER['SERVER_NAME'])
			# %d - domain (http hostname without the first part)
			# %z - IMAP domain (IMAP hostname without the first part)
			# For example %n = mail.domain.tld, %d = domain.tld

			echo "\$config['mail_domain'] = '${rc_server_domain}';"
			echo
			echo '// Use this name to compose page titles'
			if [ "${rc_orga_name}" != "" ] ; then
				echo "\$config['product_name'] = '${rc_orga_name}';"
			else
				echo "\$config['product_name'] = 'Roundcube Webmail';"
			fi

			echo
			echo '// Set identities access level'
			# 0 - many identities with possibility to edit all params
			# 1 - many identities with possibility to edit all params but not email address
			# 2 - one identity with possibility to edit all params
			# 3 - one identity with possibility to edit all params but not email address
			# 4 - one identity with possibility to edit only signature
			if [ "${rc_general_allow_ident}" = "yes" ] ; then
				echo "\$config['identities_level'] = 0;"
			else
				echo "\$config['identities_level'] = 3;"
			fi

			echo
		  # echo '// Path to a local mime magic database file for PHPs finfo extension.
		  # echo '// Set to NULL if the default path should be used.
		  # echo "\$config['mime_magic'] = '/usr/share/misc/magic';
		  # echo
			echo '// ----------------------------------'
			echo '// PLUGINS'
			echo '// ----------------------------------'
			echo
			echo '// List of active plugins (in plugins/ directory)'
			rc_plugins_path="${roundcube_path}/plugins"
			rc_plugins_list=''

			if [ "${rc_plugins_use_all}" = "yes" ] ; then
				# activate all existing plugins
				for rc_plugins_dirname in $(find ${rc_plugins_path} -maxdepth 1 | sed "s#^${rc_plugins_path}/##g" | sort) ; do
					if [ "${rc_plugins_list}" = "" ] ; then
						rc_plugins_list="'${rc_plugins_dirname}'"
					else
						rc_plugins_list="${rc_plugins_list},'${rc_plugins_dirname}'"
					fi
				done
			else
				# activate an individual plugin list
				idx=1
				while [ ${idx} -le ${rc_plugins_n} ] ; do
					eval rc_plugins_dirname='$ROUNDCUBE_PLUGINS_'${idx}'_DIRNAME'

					if [ -d ${rc_plugins_path}/${rc_plugins_dirname} ] ; then
						if [ "${rc_plugins_list}" = "" ] ; then
							rc_plugins_list="'${rc_plugins_dirname}'"
						else
							rc_plugins_list="${rc_plugins_list},'${rc_plugins_dirname}'"
						fi
					else
						error "You've set ROUNDCUBE_${rc_nbr}_PLUGINS_${idx}_DIRNAME='${rc_plugins_dirname}' although it doesn't exist. The plugin will be skipped."
					fi

					idx=$(expr ${idx} + 1)
				done

				echo "\$config['plugins'] = array(${rc_plugins_list});"
			fi

			echo
			echo '// ----------------------------------'
			echo '// USER INTERFACE'
			echo '// ----------------------------------'
			echo
			echo '// Default messages sort column'
			# Use empty value for default server's sorting, or 'arrival', 'date',
			# 'subject', 'from', 'to', 'fromto', 'size', 'cc'
			echo "\$config['message_sort_col'] = 'date';"
			echo

			echo '// The default locale setting (leave empty for auto-detection)'
			# RFC1766 formatted language name like en_US, de_DE, de_CH, fr_FR, pt_BR
			echo "\$config['language'] = '${rc_orga_def_language}';"
			echo

			echo '// Use this format for date display'
			# (date or strftime format)
			echo "\$config['date_format'] = 'd.m.Y';"
			echo

			echo '// Use this format for detailed date/time formatting'
			# (derived from date_format and time_format)
			echo "\$config['date_long'] = 'd.m.Y H:i';"
			echo

			case ${MAIL_INSTALLED} in
				vmail)
					# vmail (dovecot)
					rc_folder_prefix=''
					;;
				*)
					# none local
					case ${rc_imap_type} in
						courier)
							rc_folder_prefix='INBOX.'
							;;
						dovecot)
							rc_folder_prefix=''
							;;
						uw)
							rc_folder_prefix=''
							;;
					esac
					;;
			esac

			echo '// Store draft message is this mailbox'
			# leave blank if draft messages should not be stored
			# NOTE: Use folder names with namespace prefix (INBOX. on Courier-IMAP)
			if [ "${rc_mv_msgs_to_draft}" = "yes" ] ; then
				echo "\$config['drafts_mbox'] = '${rc_folder_prefix}Drafts';"
			else
				echo "\$config['drafts_mbox'] = NULL;"
			fi

			echo
			echo '// Store spam messages in this mailbox'
			# NOTE: Use folder names with namespace prefix (INBOX. on Courier-IMAP)
			# echo "\$config['junk_mbox'] = NULL;"
			echo "\$config['junk_mbox'] = '${rc_folder_prefix}Junk';"
			echo

			echo '// Store sent message is this mailbox'
			# leave blank if sent messages should not be stored
			# NOTE: Use folder names with namespace prefix (INBOX. on Courier-IMAP)
			if [ "${rc_mv_msgs_to_send}" = "yes" ] ; then
				echo "\$config['sent_mbox'] = '${rc_folder_prefix}Sent';"
			else
				echo "\$config['sent_mbox'] = NULL;"
			fi

			echo

			echo '// Move messages to this folder when deleting them'
			# leave blank if they should be deleted directly
			# NOTE: Use folder names with namespace prefix (INBOX. on Courier-IMAP)

			if [ "${rc_mv_msgs_to_trash}" = "yes" ] ; then
				echo "\$config['trash_mbox'] = '${rc_folder_prefix}Trash';"
			else
				echo "\$config['trash_mbox'] = NULL;"
			fi

			echo

			echo '// Display these folders separately in the mailbox list'
			# these folders will also be displayed with localized names
			# NOTE: Use folder names with namespace prefix (INBOX. on Courier-IMAP)
			# echo "// \$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', 'Junk', 'Trash');"

			case ${MAIL_INSTALLED} in
				vmail)
					echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', 'Trash');"
					;;
				*)
					# non-local
					if [ "${rc_imap_type}" = "uw" ] ; then
						echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', 'Trash', '#public', '#shared');"
					else
						echo "\$config['default_folders'] = array('INBOX', 'Drafts', 'Sent', 'Trash');"
					fi
					;;
			esac

			echo
			echo '// Automatically create the above listed default folders on first login'
			echo "\$config['create_default_folders'] = true;"
			echo
			echo '// Protect the default folders from renames, deletes, and subscription changes'
			echo "\$config['protect_default_folders'] = true;"
			echo
			echo '// Make use of the built-in spell checker'
		  # echo '// It is based on GoogieSpell. Since Google only accepts connections over https'
		  # echo '// your PHP installatation requires to be compiled with Open SSL support'
		  # echo "\$config['enable_spellcheck'] = false;"
		  # echo
		  # echo '// Enables files upload indicator. Requires APC installed and enabled apc.rfc1867 option.'
		  # echo '// By default refresh time is set to 1 second. You can set this value to true'
		  # echo '// or any integer value indicating number of seconds.'
		  # echo "\$config['upload_progress'] = false;"
		  # echo
			echo '// ----------------------------------'
			echo '// ADDRESSBOOK SETTINGS'
			echo '// ----------------------------------'
			echo
			echo '// This indicates which type of address book to use'
			# Possible choises: 'sql' (default), 'ldap' and ''.
			# If set to 'ldap' then it will look at using the first writable LDAP
			# address book as the primary address book and it will not display the
			# SQL address book in the 'Address Book' view.
			# If set to '' then no address book will be displayed or only the
			# addressbook which is created by a plugin (like CardDAV).
			echo "\$config['address_book_type'] = 'sql';"
			echo

			echo '// In order to enable public ldap search, configure an array'
			# like the Verisign example further below. if you would like to test,
			# simply uncomment the example.
			# Array key must contain only safe characters, ie. a-zA-Z0-9_

			rc_globldap_list=''
			idx=1
			while [ ${idx} -le ${rc_globldap_n} ] ; do
				eval rc_globldap_active='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_ACTIVE'

				if [ "${rc_globldap_active}" = "yes" ] ; then
					if [ "${rc_globldap_list}" = "" ] ; then
						rc_globldap_list="'ldap_${idx}'"
					else
						rc_globldap_list="${rc_globldap_list},'ldap_${idx}'"
					fi

					eval rc_globldap_info='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_INFO'
					eval rc_globldap_hostport='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_HOST'
					eval rc_globldap_basedn='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_BASEDN'
					eval rc_globldap_force_tls='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_FORCE_TLS}'
					eval rc_globldap_auth='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_AUTH'
					eval rc_globldap_binddn='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_BINDDN'
					eval rc_globldap_bindpass='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_BINDPASS'
					eval rc_globldap_writeable='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_WRITEABLE'
					eval rc_globldap_charset='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_CHARSET'       # optional
					eval rc_globldap_maxrows='$ROUNDCUBE_GLOBADDR_LDAP_'${idx}'_MAXROWS'       # optional

					# LDAP directory
					echo "\$config['ldap_public'] = array("
					echo "  'ldap_${idx}' =>"
					echo "  array ("
					echo "    'name'            => '${rc_globldap_info}',"

					# temporarily remove ldap(s):// protocol information
					tmp_globldap_hostport=$(echo "${rc_globldap_hostport}" | sed 's#^ldap.*://##')

					# Check if port number has been given
					echo "${tmp_globldap_hostport}" | grep -q ":"

					if [ $? -eq 0 ] ; then
						# split hostname and port
						rc_globldap_port=$(echo "${tmp_globldap_hostport}" | cut -d: -f2)
						rc_globldap_host=$(echo "${rc_globldap_hostport}" | sed "s#:${rc_globldap_port}##")
					else
						# hostname only
						rc_globldap_host="${rc_globldap_hostport}"

						# set default ldap port
						echo "${rc_globldap_hostport}" | grep -q "^ldaps:"

						if [ $? -eq 0 ] ; then
							# ldaps
							rc_globldap_port='636'
						else
							# ldap
							rc_globldap_port='389'
						fi
					fi

					echo "    'hosts' =>"
					echo "    array("
					echo "      0 => '${rc_globldap_host}',"
					echo "      ),"
					echo "    'port'            => ${rc_globldap_port},"

					if [ "${rc_globldap_force_tls}" = "yes" ] ; then
						echo "    'use_tls'         => true,"
					else
						echo "    'use_tls'         => false,"
					fi

					# using LDAPv3
					echo "    'ldap_version'    => 3,"

					if [ "${rc_globldap_charset}" != "" ] ; then
						echo "    'charset'         => '${rc_globldap_charset}',"   # optional
					else
						# default value
						echo "    'charset'         => '${rc_general_def_charset}',"
					fi

					if [ "${rc_globldap_maxrows}" != "" ] ; then
						echo "    'maxrows'         => ${rc_globldap_maxrows},"     # optional
				  # else
				  #     # default value
				  #     echo "    'maxrows'         => 150,"
					fi

					# If true the base_dn, bind_dn and bind_pass default to the user's IMAP login
					echo "    'user_specific'   => false,"
					echo "    'base_dn'         => '${rc_globldap_basedn}',"

					if [ "${rc_globldap_auth}" = "yes" ] ; then
						echo "    'bind_dn'         => '${rc_globldap_binddn}',"
						echo "    'bind_pass'       => '${rc_globldap_bindpass}',"
					fi

					if [ "${rc_globldap_writeable}" = "yes" ] ; then
						echo "    'writable'        => true,"
					else
						echo "    'writable'        => false,"
					fi

					echo "    'required_fields' =>"
					echo "    array("
					echo "    0 => 'givenName',"
					echo "    1 => 'cn',"
					echo "    2 => 'sn',"
					echo "    3 => 'mail'",
					echo "    ),"
					echo "    'search_base_dn'  => '${rc_globldap_basedn}',"
					# fields to search in
					echo "    'search_fields' =>"
					echo "    array("
					echo "    0 => 'givenName',"
					echo "    1 => 'cn',"
					echo "    2 => 'sn',"
					echo "    3 => 'mail',"
					echo "    ),"
					echo "    'search_filter'   => '(&(objectclass=*)(!(objectclass=alias)))',"
					# Enables you to limit the count of entries fetched. Setting this to 0 means no limit
					echo "    'sizelimit'       => '0',"
					# Sets the number of seconds how long is spend on the search. Setting this to 0 means no limit
					echo "    'timelimit'       => '0',"
					echo "    'sort'            => 'sn',"
					# search mode: sub|base|list
					echo "    'scope'           => 'sub',"
					echo "    'filter'          => '(objectClass=inetOrgPerson)',"
					echo "    'fuzzy_search'    => true,"
					echo "    'fieldmap' =>"
					echo "    array("
					echo "      'name'          => 'cn',"
					echo "      'surname'       => 'sn',"
					echo "      'firstname'     => 'givenName',"
					echo
					echo "      'email:home'    => 'mail',"
					echo "      'email:work'    => 'mozillaSecondEmail',"
					echo "      'phone:home'    => 'homePhone',"
					echo "      'phone:work'    => 'telephoneNumber',"
					echo "      'phone:mobile'  => 'mobile',"
					echo
					echo "      'street'        => 'mozillaHomeStreet',"
					echo "      'zipcode'       => 'mozillaHomePostalCode',"
					echo "      'locality'      => 'mozillaHomeLocalityName',"
					echo "      'country'       => 'mozillaHomeCountryName',"
					echo "      'organization'  => 'o',"
					echo "      'photo'         => 'jpegPhoto',"
					echo "      'birthday'      => 'mozillaCustom1',"
					echo "      ),"
					echo "    ),"
					echo "  );"
				fi

				idx=$(expr ${idx} + 1)
			done

			echo
			echo '// An ordered array of the ids of the addressbooks that should be searched'
			# when populating address autocomplete fields server-side. ex: array('sql','Verisign');
			echo "\$config['autocomplete_addressbooks'] = array('sql',${rc_globldap_list});"
			echo

			echo '// The minimum number of characters required to be typed in an autocomplete field'
			# before address books will be searched. Most useful for LDAP directories that
			# may need to do lengthy results building given overly-broad searches
			echo "\$config['autocomplete_min_length'] = 2;"
			echo

			echo '// Show address fields in this order'
			# available placeholders: {street}, {locality}, {zipcode}, {country}, {region}
		  # echo "\$config['address_template'] = '{street}<br/>{zipcode} {locality}<br/>{country} {region}';"
		  # echo

			echo '// ----------------------------------'
			echo '// USER PREFERENCES'
			echo '// ----------------------------------'
			echo
			echo '// Use this charset as fallback for message decoding'
			echo "\$config['default_charset'] = '${rc_general_def_charset}';"
			echo

			echo '// The way how contact names are displayed in the list'
			# 0: display name
			# 1: (prefix) firstname middlename surname (suffix)
			# 2: (prefix) surname firstname middlename (suffix)
			# 3: (prefix) surname, firstname middlename (suffix)
			echo "\$config['addressbook_name_listing'] = 3;"

			echo
			echo '// Prefer displaying HTML messages'
			echo "\$config['prefer_html'] = false;"
			echo

			echo '// Mark as read when viewed in preview pane (delay in seconds)'
			# Set to -1 if messages in preview pane should not be marked as read
			echo "\$config['preview_pane_mark_read'] = 10;"
			echo

			echo '// Compact INBOX on logout'
			if [ "${rc_auto_expunge}" = "yes" ] ; then
				echo "\$config['logout_expunge'] = true;"
			else
				echo "\$config['logout_expunge'] = false;"
			fi

			echo
			echo '// Set true if deleted messages should not be displayed'
			# This will make the application run slower
			echo "\$config['skip_deleted'] = true;"
			echo

			echo '// If true, after message delete/move, the next message will be displayed'
			echo "\$config['display_next'] = false;"
			echo

			echo '// Choose if threads should be expanded'
			# 0 - Do not expand threads
			# 1 - Expand all threads automatically
			# 2 - Expand only threads with unread messages
			echo "\$config['autoexpand_threads'] = 2;"
			echo

			echo '// Return receipt checkbox default state'
			if [ "${rc_general_allow_receipt}" = "yes" ] ; then
				echo "\$config['mdn_default'] = 1;"
			else
				echo "\$config['mdn_default'] = 0;"
			fi

			echo
			echo '// end of config file'
		  # echo '?>'
		} > ${roundcube_conf_file}

		echo "- creating roundcube help plugin configuration ..."

		{
			echo "<?php"
			echo '/*'
			echo '+-----------------------------------------------------------------------+'
			echo "| Configuration file for help plugin generated by ${pgmname}          |"
			echo '|                                                                       |'
			echo "| Do not edit this file, edit ${roundcubefile}                   |"
			echo "| Creation date: $(date)                           |"
			echo '|                                                                       |'
			echo '| This file is part of the Roundcube Webmail client                     |'
			echo '| Copyright (C) 2005-2009, The Roundcube Dev Team                       |'
			echo '|                                                                       |'
			echo '| Licensed under the GNU General Public License version 3 or            |'
			echo '| any later version with exceptions for skins & plugins.                |'
			echo '| See the README file for a full license statement.                     |'
			echo '|                                                                       |'
			echo '+-----------------------------------------------------------------------+'
			echo '*/'
			echo
			# set protocol based on the used access method http or https,
			# otherwise the help will not be displayed using e.g. Firefox
			echo "\$help_protocol = isset(\$_SERVER[\"HTTPS\"]) ? 'https' : 'http';"
			echo
			echo '// Help content iframe source'
			echo "\$config['help_source'] = \$help_protocol . '://docs.roundcube.net/doc/help/1.1/%l/';"
			echo
			echo '// Map task/action combinations to deep-links'
			echo "// Use '<task>/<action>' or only '<task>' strings as keys"
			echo "// The values will be appended to the 'help_source' URL"
			echo "\$config['help_index_map'] = array("
			echo "  'login'                => 'login.html',"
			echo "  'mail'                 => 'mail/index.html',"
			echo "  'mail/compose'         => 'mail/compose.html',"
			echo "  'addressbook'          => 'addressbook/index.html',"
			echo "  'settings'             => 'settings/index.html',"
			echo "  'settings/preferences' => 'settings/preferences.html',"
			echo "  'settings/folders'     => 'settings/folders.html',"
			echo "  'settings/identities'  => 'settings/identities.html',"
			echo ");"
			echo
			echo '// Map to translate Roundcube language codes into help document languages'
			echo "// The '*' entry will be used as default"
			echo "\$config['help_language_map'] = array('*' => 'en_US');"
			echo
			echo '// Enter an absolute URL to a page displaying information about this webmail'
			echo '// Alternatively, create a HTML file under <this-plugin-dir>/content/about.html'
			echo "\$config['help_about_url'] = null;"
			echo
			echo '// Enter an absolute URL to a page displaying information about this webmail'
			echo '// Alternatively, put your license text to <this-plugin-dir>/content/license.html'
			echo "\$config['help_license_url'] = null;"
			echo
			echo '// Determine whether to open the help in a new window'
			echo "\$config['help_open_extwin'] = false;"
			echo
			echo '// URL to additional information about CSRF protection'
			echo "\$config['help_csrf_info'] = null;"
			echo
		} > ${roundcube_helpconf_file}
    fi
}

# ----------------------------------------------------------------------------
# set access rights
# ----------------------------------------------------------------------------
set_roundcube_access_rights ()
{
    echo "checking directories ..."

    # check directories
    for DNAME in ${roundcube_data_path} ${roundcube_log_path} ; do
        if [ ! -f ${DNAME} ] ; then
            mkdir -p ${DNAME}
        fi
    done

    echo "setting access rights ..."

    idx=1
    while [ ${idx} -le ${ROUNDCUBE_N} ] ; do
        eval roundcube_path='$ROUNDCUBE_'${idx}'_DOCUMENT_ROOT'

#       roundcube_dbconf_file=${roundcube_path}/config/db.inc.php
#       roundcube_mainconf_file=${roundcube_path}/config/main.inc.php
        roundcube_conf_file=${roundcube_path}/config/config.inc.php
        roundcube_helpconf_file=${roundcube_path}/plugins/help/config.inc.php
        roundcube_sqlite_file=${roundcube_data_path}/roundcubemail.db

        if [ -d ${roundcube_path} ] ; then
            chown -R ${roundcube_apache_user}  ${roundcube_path}
            chgrp -R ${roundcube_apache_group} ${roundcube_path}
            chmod -R 0444 ${roundcube_path}

            # set directory access rights
            find ${roundcube_path} -type d -exec chmod 0755 '{}' \;

        fi

        # configuration file
        if [ -f ${roundcube_conf_file} ] ; then
            chown ${roundcube_apache_user}  ${roundcube_conf_file}
            chgrp ${roundcube_apache_group} ${roundcube_conf_file}
            chmod 0440 ${roundcube_conf_file}

            chown ${roundcube_apache_user}  ${roundcube_helpconf_file}
            chgrp ${roundcube_apache_group} ${roundcube_helpconf_file}
            chmod 0440 ${roundcube_helpconf_file}
        fi

        if [ -f ${roundcube_sqlite_file} ] ; then
            chown ${roundcube_apache_user}  ${roundcube_sqlite_file}
            chgrp ${roundcube_apache_group} ${roundcube_sqlite_file}
            chmod 0646 ${roundcube_sqlite_file}
        fi

        idx=$(expr ${idx} + 1)
    done

    # data and log directory
    if [ -d ${roundcube_path} ] ; then
        chown -f -R ${roundcube_apache_user}  ${roundcube_path}
        chgrp -f -R ${roundcube_apache_group} ${roundcube_path}
        chmod -f 0755 ${roundcube_path}
    fi

    if [ -d ${roundcube_data_path} ] ; then
        chmod -f 0750 ${roundcube_data_path}
    fi

    if [ -d ${roundcube_log_path} ] ; then
        chmod -f 0750 ${roundcube_log_path}

        chmod 0640 ${roundcube_log_path}/*
    fi
}

# ----------------------------------------------------------------------------
# check IMAP server
# ----------------------------------------------------------------------------
check_imap_server ()
{
    case ${MAIL_INSTALLED} in
        vmail)
            # vmail package
			if [ "${START_POP3IMAP}" = "yes" ] ; then
				echo "local imap server is active - ok."
			else
				echo "local imap server is inactive!"
				warn "Parameter START_COURIER='yes' has not been set although a vmail package has been installed! Email can't be retrieved!"
			fi
			;;
        *)
            # none local
            echo "no local mail/vmail package found - imap server status cannot be evaluate!"
            warn "no local mail/vmail package found - imap server status cannot be evaluate!"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# add cron job
# ----------------------------------------------------------------------------
add_cron_job ()
{
    echo "Creating cron job ..."

    # check for cron directory
    if [ ! -d ${crontab_path} ] ; then
        mkdir -p ${crontab_path}
    fi

    # write file
    {
        echo "#--------------------------------------------------------------------"
        echo "#  roundcubemail cron file generated by ${pgmname} version: ${roundcube_version}"
        echo "#"
        echo "#  Do not edit this file, edit ${roundcubefile}"
        echo "#  Creation Date: ${EISDATE} Time: ${EISTIME}"
        echo "#--------------------------------------------------------------------"
		# suppress all kind of messages due to php output '/usr/lib/liblber-2.4.so.2: no version information available' etc.
		echo "${ROUNDCUBE_CRON_SCHEDULE} chmod 544 ${roundcube_path}/bin/cleandb.sh; ${roundcube_path}/bin/cleandb.sh >/dev/null 2>/dev/null"
        echo
    } > ${crontab_file}

    # update crontab file
    /var/install/config.d/cron > /dev/null 2> /dev/null
}

# ----------------------------------------------------------------------------
# delete cron job
# ----------------------------------------------------------------------------
delete_cron_job ()
{
    echo "Deleting cron job ..."

    # check for crontab file
    if [ -f ${crontab_file} ] ; then
        # delete existing file
        rm -f ${crontab_file}

        # update crontab file
        /var/install/config.d/cron > /dev/null 2> /dev/null
    fi
}

# ----------------------------------------------------------------------------
# set default charset to UTF-8
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
set_default_charset ()
{
    if [ -f ${roundcube_path}/.htaccess ] ; then
        cp ${roundcube_path}/.htaccess ${roundcube_path}/.htaccess.tmp
        sed 's/^# AddDefaultCharset[ \t]*UTF-8/AddDefaultCharset UTF-8/' ${roundcube_path}/.htaccess.tmp > ${roundcube_path}/.htaccess
        rm -f ${roundcube_path}/.htaccess.tmp
    fi
}

# ----------------------------------------------------------------------------
# show which Roundcube version is currently installed
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
show_installed_version ()
{
    if [ -f ${roundcube_path}/program/include/iniset.php ] ; then
        rc_version=$(grep "RCMAIL_VERSION" ${roundcube_path}/program/include/iniset.php | sed "s/^.*RCMAIL_VERSION' *, *'\(.*\)'.*$/\1/")
        echo "- Roundcube version: ${rc_version}"
    fi
}

######### HELPER-FUNCTIONS #########
_init() {
    if [ -n "${TERM}" -a "${TERM}" != "dumb" ]; then
        GREEN=$(tput setaf 2) RED=$(tput setaf 1) BLUE="$(tput setaf 4)"
        LTGREYBG="$(tput setab 7)"
        NORMAL=$(tput sgr0) BLINK=$(tput blink)
    else
        GREEN="" RED="" BLUE="" LTGREYBG="" NORMAL="" BLINK=""
    fi
}

die() {
    local _error=${1:-1}
    shift
    error "$*" >&2
    exit ${_error}
}

info() {
    printf "${NORMAL}%-7s: %s${NORMAL}\n" "info" "$*"
}

error() {
    printf "${RED}%-7s: %s${NORMAL}\n" "error" "$*"
}

warning() {
    printf "${BLUE}%-7s: %s${NORMAL}\n" "warning" "$*"
}

#========================================================================================
# Main
#========================================================================================
_init
case "$1" in
    --create-sql-db)
        create_sql_db_and_table 'force'
        ;;
    --delete-sql-db)
        remove_sql_db_and_table "$2" "$3" "$4"
        ;;
    --remove-cron)
        delete_cron_job
        ;;
    *)
        echo "version: ${roundcube_version}"

        if [ "${START_ROUNDCUBE}" = "yes" ] ; then
            # generate all configuration files
            if check_installed_vmail ; then
                # vmail
                MAIL_INSTALLED='vmail'

                if [ -f ${vmailfile} ] ; then
                    # vmail package found
                    . ${vmailfile}
                fi
            else
                # vmail package not installed
                MAIL_INSTALLED='none'
            fi

            config_error=0
          # if ! check_active_apache_ssl
          # then
          #     config_error=1
          # fi

            echo "db type: ${ROUNDCUBE_DB_TYPE}"

            case ${ROUNDCUBE_DB_TYPE} in
                mysql)
                    if ! check_active_php_mysql
                    then
                        config_error=1
                    fi
                    if ! check_installed_mysql
                    then
                        config_error=1
                    fi
                    ;;
                pgsql)
                    if ! check_active_php_pgsql
                    then
                        config_error=1
                    fi
                    if ! check_installed_postgres
                    then
                        config_error=1
                    fi
                    ;;
                *|sqlite)
                    if ! check_active_php_sqlite
                    then
                        config_error=1
                    fi
                    ;;
            esac

            if [ ${config_error} -eq 1 ] ; then
                echo "pre-requisites not met, fix it and re-run configuration!"
                exit 1
            fi

            check_active_php_ldap
            check_imap_server

            create_sql_db_and_table ""

			show_installed_version
			set_default_charset
			create_roundcube_conf

            set_roundcube_access_rights
            add_cron_job

            echo "finished."
        else
			create_roundcube_conf 'stop'
            delete_cron_job
        fi

        # restart web server
        /sbin/rc-service --quiet apache2 restart
        ;;
esac

#========================================================================================
# End
#========================================================================================
exit 0
