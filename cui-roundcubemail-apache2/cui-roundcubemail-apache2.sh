#!/bin/sh
# ----------------------------------------------------------------------------
# /var/install/config.d/roundcubemail-apache2.sh 
# - Configuration generator script for RoundCube client
#
# Copyright (c) 2012-2016 The Eisfair Team, team(at)eisfair(dot)org
# Creation:    2012-12-19 jed
#
# Parameters:
#   roundcube.sh                                     - generates all configuration files
#   roundcube.sh create-sql-db                                 - initialize sql database
#   roundcube.sh delete-sql-db [db-type][db-user][db-password] - delete sql database
#   roundcube.sh removecron                                    - remove cronjob
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
php5file=${testroot}/etc/config.d/apache2_php5
vmailfile=${testroot}/etc/config.d/vmail
roundcubefile=${testroot}/etc/config.d/roundcube
mariadbfile=${testroot}/etc/config.d/mariadb
mysqlfile=${testroot}/etc/config.d/mysql
owncloudfile=${testroot}/etc/config.d/owncloud
postgresfile=${testroot}/etc/config.d/postgresql
postgrespwfile=/root/.pgpass
configlog_file=$roundcube_log_path/roundcube-configlog
crontab_file=${crontab_path}/roundcube
services_file=$testroot/etc/services
version_file=${roundcube_path}/roundcube_version
packagefile=${testroot}/var/install/packages/roundcube

docroot_filelist=${roundcube_path}/rc-filelist.txt
docroot_addlist=${roundcube_path}/rc-docroot.lst
docroot_dellist=${roundcube_path}/rc-docroot.del
docroot_tmplist=/tmp/rc-docroot.$$

DB_NAME='roundcube'
DB_HOST='localhost'

# Other parameters
roundcube_version="v`grep "<version>" ${packagefile} | sed 's#<version>\(.*\)</version>#\1#'`"

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
# check if mail has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_installed_mail ()
{
    retval=1

    if [ -f ${mailfile} ] ; then
        # mail installed
        . ${mailfile}

        if [ "${START_MAIL}" = "yes" ] ; then
            # mail activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "mail has been enabled ..."
            fi
            retval=0
        else
            # mail deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "mail is currently disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if vmail has been enabled
# input:  $1 - '-quiet' means no output
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
            if [ "${1}" != "-quiet" ] ; then
                mecho "vmail has been enabled ..."
            fi
            retval=0
        else
            # vmail deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "vmail is currently disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if owncloud has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_installed_owncloud ()
{
    retval=1

    if [ -f ${owncloudfile} ] ; then
        # mail installed
        . ${owncloudfile}

        if [ "${START_OWNCLOUD}" = "yes" ] ; then
            # ownCloud activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "ownCloud has been enabled ..."
            fi
            retval=0
        else
            # ownCloud deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "ownCloud is currently disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if Apache2 SSL has been enabled
# ----------------------------------------------------------------------------
# check if Apache2 SSL has been enabled
#
# input:  $1 - '-quiet' - suppress screen output
# return:  0 - extension enabled
#          1 - extension disabled
# ----------------------------------------------------------------------------
check_active_apache_ssl ()
{
    retval=1

    if [ -f ${apache2file} ] ; then
        . ${apache2file}

        if [ "`echo "${APACHE2_SSL}" | tr '[:upper:]' '[:lower:]'`" = "yes" ] ; then
            # ssl support activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "Apache2 SSL has been enabled ..."
            fi
            retval=0
        else
            # ssl support deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "Apache2 SSL has been disabled ..."
                mecho --warn "set APACHE2_SSL='yes'"
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if php_ldap has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_active_php_ldap ()
{
    retval=1

    # check if ldap support is required
    capl_ldap_required=0
    capl_idx=1
    while [ ${capl_idx} -le ${ROUNDCUBE_N} ] ; do
        eval capl_active='$ROUNDCUBE_'${capl_idx}'_ACTIVE'

        if [ "${capl_active}" = "yes" ] ; then
            eval capl_globldap_n='$ROUNDCUBE_'${capl_idx}'_GLOBADDR_LDAP_N'

            capl_jdx=1
            while [ ${capl_jdx} -le ${capl_globldap_n} ] ; do
                eval capl_globldap_active='$ROUNDCUBE_'${capl_idx}'_GLOBADDR_LDAP_'${capl_jdx}'_ACTIVE'

                if [ "${capl_globldap_active}" = "yes" ] ; then
                    capl_ldap_required=1
                    break
                fi

                capl_jdx=`expr ${capl_jdx} + 1`
            done
        fi

        if [ ${capl_ldap_required} -eq 1 ] ; then
            break
        fi

        capl_idx=`expr ${capl_idx} + 1`
    done

    if [ ${capl_ldap_required} -eq 1 ] ; then
        # ldap support required check php parameter
        if [ -f ${php5file} ] ; then
            # apache2_php5 installed
            . ${php5file}

            if [ "${PHP5_EXT_LDAP}" = "yes" ] ; then
                # ldap support activated
                if [ "${1}" != "-quiet" ] ; then
                    mecho "php-ldap has been enabled ..."
                fi
                retval=0
            else
                # ldap support deactivated
                if [ "${1}" != "-quiet" ] ; then
                    mecho --error "php-ldap is currently disabled ..."
                fi
                write_to_config_log -error "PHP5_EXT_LDAP='yes' has not been set!"
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if php_sqlite3 has been enabled
# input:  $1 - '-quiet' means no output
# return:  0 - installed and activated
#          1 - not installed and activated
# ----------------------------------------------------------------------------
check_active_php_sqlite ()
{
    retval=1

    if [ -f ${php5file} ] ; then
        # apache2_php5 installed
        . ${php5file}

        if [ "${PHP5_EXT_SQLITE3}" = "yes" ] ; then
            # sqlite support activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "php-sqlite3 has been enabled ..."
            fi
            retval=0
        else
            # sqlite support deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --error "php-sqlite3 is currently disabled ..."
            fi
            write_to_config_log -error "PHP5_EXT_SQLITE3='yes' has not been set!"
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if php_mysql has been enabled
#
# input:  $1 - '-quiet' - suppress screen output
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
        if [ "${PHP5_EXT_MYSQL}" = "yes" ] ; then
            # mysql support activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "php-mysql has been enabled ..."
            fi
            mysql_php=0
        else
            # mysql support deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "php-mysql has been disabled ..."
                mecho --warn "set PHP5_EXT_MYSQL='yes'"
            fi
        fi

        mysql_socket=1
        case ${EISFAIR_SYSTEM} in
            eisfair-1)
                # eisfair-1
                if [ -f /etc/my.cnf ] ; then
                    mysql_sock=`awk -F' = ' '/socket/ {print $2}' /etc/my.cnf | tail -1`

                    if [ "${PHP5_EXT_MYSQL_SOCKET}" = "${mysql_sock}" ] ; then
                        if [ "${1}" != "-quiet" ] ; then
                            mecho "php-mysql-socket has correctly been set ..."
                        fi
                        mysql_socket=0
                    else
                        if [ "${1}" != "-quiet" ] ; then
                            mecho --warn "php-mysql-socket hasn't been set correctly ..."
                            mecho --warn "set PHP5_EXT_MYSQL_SOCKET='${mysql_sock}'"
                        fi
                    fi
                else
                    mecho --error "MySQL/MariaDB configuration file /etc/my.cnf cannot be found!"
                fi
                ;;
            *)
                # eisfair-2
                if [ "${PHP5_EXT_MYSQL_SOCKET}" = "/var/run/mysql/mysql.sock" ] ; then
                    if [ "${1}" != "-quiet" ] ; then
                        mecho "php-mysql-socket has correctly been set ..."
                    fi
                    mysql_socket=0
                else
                    if [ "${1}" != "-quiet" ] ; then
                        mecho --warn "php-mysql-socket hasn't been set correctly ..."
                        mecho --warn "set PHP5_EXT_MYSQL_SOCKET='/var/run/mysql/mysql.sock'"
                    fi
                fi
                ;;
        esac

        if [ ${mysql_php} -eq 0 -a ${mysql_socket} -eq 0 ] ; then
            retval=0
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if php_pgsql has been enabled
#
# input:  $1 - '-quiet' - suppress screen output
# return:  0 - extension enabled
#          1 - extension disabled
# ----------------------------------------------------------------------------
check_active_php_pgsql ()
{
    retval=1

    if [ -f ${php5file} ] ; then
        # apache2_php5 installed
        . ${php5file}

        if [ "${PHP5_EXT_PGSQL}" = "yes" ] ; then
            # pgsql support activated
            if [ "${1}" != "-quiet" ] ; then
                mecho "php-pgsql has been enabled ..."
            fi
            retval=0
        else
            # pgsql support deactivated
            if [ "${1}" != "-quiet" ] ; then
                mecho --warn "php-pgsql has been disabled ..."
                mecho --warn "set PHP5_EXT_PGSQL='yes'"
            fi
        fi
    fi

    return ${retval}
}

#----------------------------------------------------------------------------------
# check if port is accessible
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
            smtp_nbr=`cat ${services_file} | tr -s ' \011\/' ':' | grep -E "^${smtp_str}:[0-9]+:tcp" | cut -d: -f2`

            if ! is_numeric ${smtp_nbr} ; then
                smtp_nbr='25'
            fi
        fi
    fi

    echo ${smtp_nbr}
}

# ----------------------------------------------------------------------------
# check if mysql has been enabled
# input:  $1 - '-quiet' means no output
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
            if [ "$1" != "-quiet" ] ; then
                mecho "MySQL/MariaDB support has been enabled ..."
            fi
            mysql_active=0
        else
            # mysql deactivated
            if [ "$1" != "-quiet" ] ; then
                mecho --warn "MySQL/MariaDB support has been disabled ..."
            fi
        fi
    fi

    if [ ${mysql_active} -eq 0 ] ; then
        retval=0
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# check if postgres has been enabled
# input:  $1 - '-quiet' means no output
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
            if [ "$1" != "-quiet" ] ; then
                mecho "PostgreSQL support has been enabled ..."
            fi
            retval=0
        else
            # postgres deactivated
            if [ "$1" != "-quiet" ] ; then
                mecho --warn "PostgreSQL support has been disabled ..."
            fi
        fi
    fi

    return ${retval}
}

# ----------------------------------------------------------------------------
# ask for sql root password
# ----------------------------------------------------------------------------
get_sql_root_password ()
{
    if [ "${root_pass}" = "" ] ; then
        /var/install/bin/ask "Please enter the SQL root password" "" "*" > /tmp/ask.$$
        rc=$?
        root_pass=`cat /tmp/ask.$$ | sed 's/ *//g'`
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
# create SQL database and table
# $1 - force or ''
# ----------------------------------------------------------------------------
create_sql_db_and_table ()
{
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
            write_to_config_log -warn "The parameter ROUNDCUBE_DB_PASS hasn't been set therefore the default"
            write_to_config_log -warn -ff " password 'pass' will be used!"
        fi
    fi

    doc_root=''
    rc_nbr=1
    while [ ${rc_nbr} -le ${ROUNDCUBE_N} ] ; do
        eval active='$ROUNDCUBE_'${rc_nbr}'_ACTIVE'

        if [ "${active}" = "yes" ] ; then
            eval doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'
            break
        fi

        rc_nbr=`expr ${rc_nbr} + 1`
    done

    if [ "${doc_root}" = "" ] ; then
        # no active instance found, exit function
        write_to_config_log -error "Unable to initialize database because no active Roundcube instance found!"
        return 1
    fi

    if [ ! -d "${doc_root}" ] ; then
        mkdir -p "${doc_root}"
    fi

    # set database specific options
    case ${db_type} in
        mysql|mysqli)
            # MySQL
            sql_init=${doc_root}/SQL/mysql.initial.sql
            ;;
        pgsql)
            # PostgreSQL
            sql_init=${doc_root}/SQL/postgres.initial.sql
            ;;
        sqlite)
            # SQLite3
            sql_init=${doc_root}/SQL/sqlite.initial.sql
            ;;
        *)
            # mssql, sqlsrv
            sql_init=${doc_root}/SQL/${db_type}.initial.sql
            ;;
    esac

    if [ ! -f ${sql_init} ] ; then
        # extract sql files from archive
        tar --wildcards -C "${doc_root}" -x "*.sql" -zf ${roundcube_path}/.install/rc_bin_prog.tgz
    fi

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
                        mecho -n "${step_name} ..."
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
                            mecho --info "done."
                        fi
                        ;;

                    2)
                        step_name="checking sql database"
                        mecho -n "${step_name} ..."
                        db_exists=`${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW DATABASES" | grep -c "${DB_NAME}$"`

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
                            mecho --info "done."
                        fi
                        ;;

                    3)
                        step_name="granting sql database access"
                        mecho -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW GRANTS FOR '${db_user}'@'${DB_HOST}'" | grep -q -E "GRANT ALL PRIVILEGES ON .*${DB_NAME}.*\.\* TO .*${db_user}.*@.*${DB_HOST}" 2> /dev/null

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            echo
                            get_sql_root_password

                            {
                                echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${db_user}'@'${DB_HOST}' IDENTIFIED BY '${db_pass}';"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "done."
                        fi
                        ;;
                    4)
                        step_name="initializing sql database"
                        mecho -n "${step_name} ..."
                        table_exists=`${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -D${DB_NAME} -e"SHOW TABLES" | grep -c "^users$"`

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
                            mecho --info "done."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -uroot -p${root_pass} < ${sql_cmd_file} 2>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        mecho --info "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        mecho --error "failed."
                        mecho --warn  "an error appeared while ${step_name}!"
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
                        mecho -n "${step_name} ..."
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
                            mecho --info "done."
                        fi
                        ;;
                    2)
                        step_name="checking sql database"
                        mecho -n "${step_name} ..."
                        db_exists=`${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep -c "^ ${DB_NAME} "`

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
                            mecho --info "done."
                        fi
                        ;;
                    3)
                        step_name="granting sql database access"
                        mecho -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep " ${DB_NAME} " | cut -d'|' -f2 | sed -e 's/^ */:/' -e 's/ *$/:/' | grep -q ":${db_user}:"

                        if [ $? -ne 0 -o ${force} -eq 1 ] ; then
                            echo
                          # get_sql_root_password

                            {
                                echo "ALTER DATABASE ${DB_NAME} OWNER TO ${db_user};"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "done."
                        fi
                        ;;
                    4)
                        step_name="initializing sql database"
                        mecho -n "${step_name} ..."
                        table_exists=`${SQL_BIN} --tuples-only -h${DB_HOST} -U${db_user} -d${DB_NAME} -c "SELECT * FROM pg_catalog.pg_tables WHERE tablename = 'users'" | grep -c " users "`

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
                            mecho --info "done."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -Upostgres < ${sql_cmd_file} >>${roundcube_path}/roundcube-sql-db-results.txt 2>>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        mecho --info "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        mecho --error "failed."
                        mecho --warn  "an error appeared while ${step_name}!"
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
                mecho -n "${step_name} ..."
                ${SQL_BIN} ${roundcube_data_path}/roundcubemail.db < ${sql_init} 2>${roundcube_path}/roundcube-sql-db-results.txt

                if [ $? -eq 0 ] ; then
                    # database created
                    rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                    mecho --info "done."
                else
                    # error
                    mecho --error "failed."
                    mecho --warn  "an error appeared while ${step_name}!"
                    break
                fi
            fi
            ;;
    esac
}

# ----------------------------------------------------------------------------
# remove SQL table and database
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

    rc_nbr=1
    while [ ${rc_nbr} -le ${ROUNDCUBE_N} ] ; do
        eval active='$ROUNDCUBE_'${rc_nbr}'_ACTIVE'

        if [ "${active}" = "yes" ] ; then
            eval doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'
            break
        fi

        rc_nbr=`expr ${rc_nbr} + 1`
    done

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
                        mecho -n "${step_name} ..."
                        db_exists=`${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"SHOW DATABASES" | grep -c "${DB_NAME}$"`

                        if [ ${db_exists} -ne 0 ] ; then
                            echo
                            get_sql_root_password

                            {
                                echo "DROP DATABASE ${DB_NAME};"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "not found."
                        fi
                        ;;
                    2)
                        step_name="removing sql database user"
                        mecho -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -u${db_user} -p${db_pass} -e"QUIT" > /dev/null

                        if [ $? -eq 0 ] ; then
                            # database can be accessed, go on...
                            echo
                            get_sql_root_password

                            {
                                echo "DROP USER '${db_user}'@'${DB_HOST}';"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "not found."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -uroot -p${root_pass} < ${sql_cmd_file} 2>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        mecho --info "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        mecho --error "failed."
                        mecho --warn  "an error appeared while ${step_name}!"
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
                        mecho -n "${step_name} ..."
                        db_exists=`${SQL_BIN} -h${DB_HOST} -U${db_user} -l | grep -c "^ ${DB_NAME} "`

                        if [ ${db_exists} -ne 0 ] ; then
                            echo
                          # get_sql_root_password

                            {
                                echo "DROP DATABASE ${DB_NAME};"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "not found."
                        fi
                        ;;
                    2)
                        step_name="removing sql database user"
                        mecho -n "${step_name} ..."
                        ${SQL_BIN} -h${DB_HOST} -U${db_user} -l >/dev/null 2>/dev/null

                        if [ $? -eq 0 ] ; then
                            # database can be accessed, go on...
                            echo
                          # get_sql_root_password

                            {
                                echo "DROP USER ${db_user};"
                            } > ${sql_cmd_file}
                        else
                            mecho --info "not found."
                        fi
                        ;;
                esac

                if [ -f ${sql_cmd_file} ] ; then
                    ${SQL_BIN} -h${DB_HOST} -Upostgres < ${sql_cmd_file} >>${roundcube_path}/roundcube-sql-db-results.txt 2>>${roundcube_path}/roundcube-sql-db-results.txt

                    if [ $? -eq 0 ] ; then
                        # database created
                        rm -f ${sql_cmd_file}
                        rm -f ${roundcube_path}/roundcube-sql-db-results.txt

                        mecho --info "done."
                    else
                        # error
                        rm -f ${sql_cmd_file}

                        mecho --error "failed."
                        mecho --warn  "an error appeared while ${step_name}!"
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
                mecho -n "${step_name} ..."
                rm -f ${roundcube_data_path}/roundcubemail.db

                mecho --info "done."
            fi
            ;;
    esac
}

# ----------------------------------------------------------------------------
# check if unique document root
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
is_unique_docroot ()
{
    rc_nbr=$1
    rcret=0

    if [ ${rc_nbr} -gt 1 -a ${ROUNDCUBE_N} -ne 0 ] ; then
        eval rc_active1='$ROUNDCUBE_'${rc_nbr}'_ACTIVE'
        eval rc_doc_root1='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'

        if [ "${rc_active1}" = "yes" ] ; then
            # active entry - compare it...
            mecho "- checking if document root is unique ..."

            idx=1
            while [ ${idx} -le ${ROUNDCUBE_N} ] ; do
                if [ ${idx} -ne ${rc_nbr} ] ; then
                    eval rc_active2='$ROUNDCUBE_'${idx}'_ACTIVE'

                    if [ "${rc_active2}" = "yes" ] ; then
                        # active entry - compare it...
                        eval rc_doc_root2='$ROUNDCUBE_'${idx}'_DOCUMENT_ROOT'

                        if [ "${rc_doc_root1}" = "${rc_doc_root2}" ] ; then
                            mecho "! Error: duplicate document roots (${rc_nbr} = ${idx}) found, please check configuration!"
                            write_to_config_log -error "Duplicate document roots (${rc_nbr} = ${idx}) found!"
                            rcret=1
                            break
                        fi
                    fi
                fi

                idx=`expr ${idx} + 1`
            done
        fi
    fi

    return ${rcret}
}

# ----------------------------------------------------------------------------
# force update of roundcube database and configuration
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
force_roundcube_update ()
{
    rc_nbr=1
    rc_prev_version=''
    rc_curr_version=''
    while [ ${rc_nbr} -le ${ROUNDCUBE_N} ] ; do
        eval rc_doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'

        if [ -f ${version_file} ] ; then
            # previoud version information found
            rc_prev_version=`cat ${version_file}`
        fi

        rc_curr_version=`grep "RCMAIL_VERSION" ${rc_doc_root}/program/include/iniset.php | sed "s/^.*RCMAIL_VERSION' *, *'\(.*\)'.*$/\1/"`

        if [ "${rc_prev_version}" != "" -a "${rc_curr_version}" != "" ] ; then
            if [ "${rc_prev_version}" != "${rc_curr_version}" ] ; then
                mecho "- updating configuration (${rc_doc_root}) ..."

                # import database content once
                /var/install/bin/roundcube-import-database --update

                # update database schema and run configuration check
                if [ -f ${rc_doc_root}/installer/rcube_install.php ] ; then
                    # installer sub-directory exists, update database schema and run configuration check
                    chmod 544 ${rc_doc_root}/bin/update.sh
                    ${rc_doc_root}/bin/update.sh --version=${rc_prev_version}
                fi
            else
                # no update possible/necessary
                break
            fi
        fi

        if [ -f ${rc_doc_root}/installer/rcube_install.php ] ; then
            # remove installer sub-directory
            mecho "- removing installation files ..."
            rm -fr ${rc_doc_root}/installer
        fi

        rc_nbr=`expr ${rc_nbr} + 1`
    done

    if [ "${rc_curr_version}" != "" ] ; then
        # save version information
        echo "${rc_curr_version}" > ${version_file}
    fi
}

# ----------------------------------------------------------------------------
# copy program files
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
copy_program_files ()
{
    rc_nbr=$1
    eval rc_doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'

    mecho "- copying program files (${rc_doc_root}) ..."

    if [ ! -f "${rc_doc_root}/index.php" ] ; then
        # files don't exist - copy ...
        if [ ! -d "${rc_doc_root}" ] ; then
            mkdir -p "${rc_doc_root}"
        fi

        # extract Roundcube software
        tar xzf ${roundcube_path}/.install/rc_bin_prog.tgz -C "${rc_doc_root}"

        # extract additional Roundcube plugins
        tar xzf ${roundcube_path}/.install/rc_bin_plugins.tgz -C "${rc_doc_root}/plugins"

        if [ ! -h ${rc_doc_root}/config -a -d ${rc_doc_root}/config ] ; then
            # not a symbolic link but a directory - move file to 'save' directory
            if [ ! -d ${roundcube_path}/config ] ; then
                mkdir -p ${roundcube_path}/config
            fi

            for FNAME in `find ${rc_doc_root}/config -maxdepth 1 \( -name "*.dist" -o -name "*.php" \)`
            do
                # move file
                mv ${FNAME} ${roundcube_path}/config/
            done

            if [ -f ${rc_doc_root}/config/.htaccess ] ; then
                rm -f ${rc_doc_root}/config/.htaccess
            fi
            rm -rf ${rc_doc_root}/config
        fi

        # check symbolic links
        if [ ! -h ${rc_doc_root}/config ] ; then
            # a symbolic link doesn't exist
            if [ ! -d ${rc_doc_root}/config ] ; then
                # check if destination source directory exists
                if [ ! -d ${roundcube_path}/config ] ; then
                    mkdir -p ${roundcube_path}/config
                fi

                # create a symbolic link
                cd ${rc_doc_root}
                ln -sf ${roundcube_path}/config config
            else
                # error - directory with this name found
                write_to_config_log -error "A problem exists with '${roundcube_path}/config' - it should be a symbolic link!"
            fi
        fi

        # remove obsolete directories
        rm -fr ${rc_doc_root}/logs

        # add document root to list
        echo "${rc_doc_root}:" >> "${docroot_addlist}"
    fi
}

# ----------------------------------------------------------------------------
# generate roundcube configuration
# $1 - Roundcube instance
# $2 - 'stop' - generate stop configuration
# ----------------------------------------------------------------------------
create_roundcube_conf ()
{
    rc_nbr=$1
    rc_config_type=$2
    eval rc_doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'
    eval rc_active='$ROUNDCUBE_'${rc_nbr}'_ACTIVE'

    if [ "${START_ROUNDCUBE}" = "yes" -a "${rc_active}" = "yes" ] ; then
        if [ ${rc_nbr} -ne 0 -a ${rc_nbr} -le ${ROUNDCUBE_N} ] ; then
            roundcube_dbconf_file=${rc_doc_root}/config/db.inc.php
            roundcube_mainconf_file=${rc_doc_root}/config/main.inc.php
            roundcube_conf_file=${rc_doc_root}/config/config.inc.php
            roundcube_helpconf_file=${rc_doc_root}/plugins/help/config.inc.php

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

            mecho "- creating roundcube program configuration ..."

            eval rc_db_type='$ROUNDCUBE_DB_TYPE'
            eval rc_db_user='$ROUNDCUBE_DB_USER'
            eval rc_db_pass='$ROUNDCUBE_DB_PASS'

            eval rc_general_des_key='$ROUNDCUBE_'${rc_nbr}'_GENERAL_DES_KEY'
            eval rc_general_def_charset='$ROUNDCUBE_'${rc_nbr}'_GENERAL_DEF_CHARSET'
            eval rc_general_allow_receipt='$ROUNDCUBE_'${rc_nbr}'_GENERAL_ALLOW_RECEIPTS_USE'
            eval rc_general_allow_ident='$ROUNDCUBE_'${rc_nbr}'_GENERAL_ALLOW_IDENTITY_EDIT'

            eval rc_orga_provider_url='$ROUNDCUBE_'${rc_nbr}'_ORGA_PROVIDER_URL'
            eval rc_orga_logo='$ROUNDCUBE_'${rc_nbr}'_ORGA_LOGO'
            eval rc_orga_name='$ROUNDCUBE_'${rc_nbr}'_ORGA_NAME'
            eval rc_orga_def_language='$ROUNDCUBE_'${rc_nbr}'_ORGA_DEF_LANGUAGE'

            eval rc_server_domain='$ROUNDCUBE_'${rc_nbr}'_SERVER_DOMAIN'
            eval rc_server_domain_check='$ROUNDCUBE_'${rc_nbr}'_SERVER_DOMAIN_CHECK'
            eval rc_imap_hostport='$ROUNDCUBE_'${rc_nbr}'_SERVER_IMAP_HOST'
            eval rc_imap_type='$ROUNDCUBE_'${rc_nbr}'_SERVER_IMAP_TYPE'
            eval rc_imap_auth='$ROUNDCUBE_'${rc_nbr}'_SERVER_IMAP_AUTH'
            eval rc_imap_transport='$ROUNDCUBE_'${rc_nbr}'_SERVER_IMAP_TRANSPORT'
            eval rc_smtp_hostport='$ROUNDCUBE_'${rc_nbr}'_SERVER_SMTP_HOST'
            eval rc_smtp_auth='$ROUNDCUBE_'${rc_nbr}'_SERVER_SMTP_AUTH'
            eval rc_smtp_transport='$ROUNDCUBE_'${rc_nbr}'_SERVER_SMTP_TRANSPORT'

            eval rc_mv_msgs_to_trash='$ROUNDCUBE_'${rc_nbr}'_FOLDER_MOVE_MSGS_TO_TRASH'
            eval rc_mv_msgs_to_send='$ROUNDCUBE_'${rc_nbr}'_FOLDER_MOVE_MSGS_TO_SEND'
            eval rc_mv_msgs_to_draft='$ROUNDCUBE_'${rc_nbr}'_FOLDER_MOVE_MSGS_TO_DRAFT'
            eval rc_auto_expunge='$ROUNDCUBE_'${rc_nbr}'_FOLDER_AUTO_EXPUNGE'
            eval rc_force_nsfolder='$ROUNDCUBE_'${rc_nbr}'_FOLDER_FORCE_NSFOLDER'

            eval rc_plugins_use_all='$ROUNDCUBE_'${rc_nbr}'_PLUGINS_USE_ALL'
            eval rc_plugins_n='$ROUNDCUBE_'${rc_nbr}'_PLUGINS_N'

            eval rc_globldap_n='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_N'

            {
                echo "<?php"
                echo '/*'
                echo '+-----------------------------------------------------------------------+'
                echo '| Local configuration for the Roundcube Webmail installation generated  |'
                echo "| by ${pgmname}                                                       |"
                echo '|                                                                       |'
                echo "| Do not edit this file, edit ${roundcubefile}                   |"
                echo "| Creation date: `date`                           |"
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
                    rc_imap_host="`echo ${rc_imap_hostport} | cut -d: -f1`"
                    rc_imap_port="`echo ${rc_imap_hostport} | cut -d: -f2`"
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
                            write_to_config_log -warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_IMAP_HOST='...:${rc_imap_port}' has been set to a non-standard port!"
                            write_to_config_log -warn "This might cause a communication problem!"
                        fi
                        ;;
                esac

                # check IMAP listen port availability
                if ! check_port_availabilty "${rc_imap_host}" "${rc_imap_port}"
                then
                    write_to_config_log -warn "Unable to connect to IMAP server '${rc_imap_host}' on port '${rc_imap_port}/tcp'!"
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
                    rc_smtp_host="`echo ${rc_smtp_hostport} | cut -d: -f1`"
                    rc_smtp_port="`echo ${rc_smtp_hostport} | cut -d: -f2`"
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
                      #     write_to_config_log -warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='localhost' has not been set although a local vmail"
                      #     write_to_config_log -warn -ff "package has been installed!"
                      # fi
                        ;;
                    *)
                        # none local
                        # check port number
                        if [ "${rc_smtp_port}" != "25" -a "${rc_smtp_port}" != "587" ] ; then
                            write_to_config_log -warn "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='...:${rc_smtp_port}' has been set to a non-standard port!"
                            write_to_config_log -warn "This might cause a communication problem!"
                        fi

                        # check hostname
                      # if [ "${rc_smtp_host}" = "localhost" -o "${rc_smtp_host}" = "127.0.0.1" ] ; then
                      #     write_to_config_log -error "Parameter ROUNDCUBE_${rc_nbr}_SERVER_SMTP_HOST='localhost' has been set although no local mail or"
                      #     write_to_config_log -error -ff "vmail package has been installed!"
                      # fi
                        ;;
                esac

                # check SMTP listen port availability
                if ! check_port_availabilty "${rc_smtp_host}" "${rc_smtp_port}"
                then
                    write_to_config_log -warn "Unable to connect to SMTP server '${rc_smtp_host}' on port '${rc_smtp_port}/tcp'!"
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
                rc_plugins_path="${rc_doc_root}/plugins"
                rc_plugins_list=''

                if [ "${rc_plugins_use_all}" = "yes" ] ; then
                    # activate all existing plugins
                    for rc_plugins_dirname in `find ${rc_plugins_path} -maxdepth 1 | sed "s#^${rc_plugins_path}/##g" | sort` ; do
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
                        eval rc_plugins_dirname='$ROUNDCUBE_'${rc_nbr}'_PLUGINS_'${idx}'_DIRNAME'

                        if [ -d ${rc_plugins_path}/${rc_plugins_dirname} ] ; then
                            if [ "${rc_plugins_list}" = "" ] ; then
                                rc_plugins_list="'${rc_plugins_dirname}'"
                            else
                                rc_plugins_list="${rc_plugins_list},'${rc_plugins_dirname}'"
                            fi
                        else
                            write_to_config_log -error "You've set ROUNDCUBE_${rc_nbr}_PLUGINS_${idx}_DIRNAME='${rc_plugins_dirname}' although"
                            write_to_config_log -error -ff "it doesn't exist. The plugin will be skipped."
                        fi

                        idx=`expr ${idx} + 1`
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
                    eval rc_globldap_active='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_ACTIVE'

                    if [ "${rc_globldap_active}" = "yes" ] ; then
                        if [ "${rc_globldap_list}" = "" ] ; then
                            rc_globldap_list="'ldap_${idx}'"
                        else
                            rc_globldap_list="${rc_globldap_list},'ldap_${idx}'"
                        fi

                        eval rc_globldap_info='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_INFO'
                        eval rc_globldap_hostport='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_HOST'
                        eval rc_globldap_basedn='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_BASEDN'
                        eval rc_globldap_force_tls='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_FORCE_TLS}'
                        eval rc_globldap_auth='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_AUTH'
                        eval rc_globldap_binddn='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_BINDDN'
                        eval rc_globldap_bindpass='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_BINDPASS'
                        eval rc_globldap_writeable='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_WRITEABLE'
                        eval rc_globldap_charset='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_CHARSET'       # optional
                        eval rc_globldap_maxrows='$ROUNDCUBE_'${rc_nbr}'_GLOBADDR_LDAP_'${idx}'_MAXROWS'       # optional

                        # LDAP directory
                        echo "\$config['ldap_public'] = array("
                        echo "  'ldap_${idx}' =>"
                        echo "  array ("
                        echo "    'name'            => '${rc_globldap_info}',"

                        # temporarily remove ldap(s):// protocol information
                        tmp_globldap_hostport=`echo "${rc_globldap_hostport}" | sed 's#^ldap.*://##'`

                        # check if port number has been given
                        echo "${tmp_globldap_hostport}" | grep -q ":"

                        if [ $? -eq 0 ] ; then
                            # split hostname and port
                            rc_globldap_port=`echo "${tmp_globldap_hostport}" | cut -d: -f2`
                            rc_globldap_host=`echo "${rc_globldap_hostport}" | sed "s#:${rc_globldap_port}##"`
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

                    idx=`expr ${idx} + 1`
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

            mecho "- creating roundcube help plugin configuration ..."

            {
                echo "<?php"
                echo '/*'
                echo '+-----------------------------------------------------------------------+'
                echo "| Configuration file for help plugin generated by ${pgmname}          |"
                echo '|                                                                       |'
                echo "| Do not edit this file, edit ${roundcubefile}                   |"
                echo "| Creation date: `date`                           |"
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
    fi
}

# ----------------------------------------------------------------------------
# set access rights
# ----------------------------------------------------------------------------
set_roundcube_access_rights ()
{
    mecho "checking directories ..."

    # check directories
    for DNAME in ${roundcube_data_path} ${roundcube_log_path} ; do
        if [ ! -f ${DNAME} ] ; then
            mkdir -p ${DNAME}
        fi
    done

    mecho "setting access rights ..."

    idx=1
    while [ ${idx} -le ${ROUNDCUBE_N} ] ; do
        eval rc_doc_root='$ROUNDCUBE_'${idx}'_DOCUMENT_ROOT'

#       roundcube_dbconf_file=${rc_doc_root}/config/db.inc.php
#       roundcube_mainconf_file=${rc_doc_root}/config/main.inc.php
        roundcube_conf_file=${rc_doc_root}/config/config.inc.php
        roundcube_helpconf_file=${rc_doc_root}/plugins/help/config.inc.php
        roundcube_sqlite_file=${roundcube_data_path}/roundcubemail.db

        if [ -d ${rc_doc_root} ] ; then
            chown -R ${roundcube_apache_user}  ${rc_doc_root}
            chgrp -R ${roundcube_apache_group} ${rc_doc_root}
            chmod -R 0444 ${rc_doc_root}

            # set directory access rights
            find ${rc_doc_root} -type d -exec chmod 0755 '{}' \;

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

        idx=`expr ${idx} + 1`
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
				mecho "local imap server is active - ok."
			else
				mecho --warn "local imap server is inactive!"
				write_to_config_log -warn "Parameter START_COURIER='yes' has not been set although a local vmail"
				write_to_config_log -warn -ff "package has been installed! Email can't be retrieved!"
			fi
			;;
        *)
            # none local
            mecho --warn "no local mail/vmail package found - imap server status cannot be evaluate!"
            write_to_config_log -warn "no local mail/vmail package found - imap server status cannot be evaluate!"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# add cron job
# ----------------------------------------------------------------------------
add_cron_job ()
{
    mecho "creating cron job ..."

    # check for cron directory
    if [ ! -d ${crontab_path} ] ; then
        mkdir -p ${crontab_path}
    fi

    rc_nbr=1
    while [ ${rc_nbr} -le ${ROUNDCUBE_N} ] ; do
        eval active='$ROUNDCUBE_'${rc_nbr}'_ACTIVE'

        if [ "${active}" = "yes" ] ; then
            eval doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'
            break
        fi

        rc_nbr=`expr ${rc_nbr} + 1`
    done

    # write file
    {
        echo "#--------------------------------------------------------------------"
        echo "#  cron webmail file generated by ${pgmname} version: ${roundcube_version}"
        echo "#"
        echo "#  Do not edit this file, edit ${roundcubefile}"
        echo "#  Creation Date: ${EISDATE} Time: ${EISTIME}"
        echo "#--------------------------------------------------------------------"
        case ${EISFAIR_SYSTEM} in
            eisfair-1)
                echo "${ROUNDCUBE_CRON_SCHEDULE} chmod 544 ${doc_root}/bin/cleandb.sh; ${doc_root}/bin/cleandb.sh >/dev/null"
                ;;
            *)
                # suppress all kind of messages due to php output '/usr/lib/liblber-2.4.so.2: no version information available' etc.
                echo "${ROUNDCUBE_CRON_SCHEDULE} chmod 544 ${doc_root}/bin/cleandb.sh; ${doc_root}/bin/cleandb.sh >/dev/null 2>/dev/null"
                ;;
        esac
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
    mecho "deleting cron job ..."

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
    rc_nbr=$1
    eval rc_doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'

    if [ -f ${rc_doc_root}/.htaccess ] ; then
        cp ${rc_doc_root}/.htaccess ${rc_doc_root}/.htaccess.tmp
        sed 's/^# AddDefaultCharset[ \t]*UTF-8/AddDefaultCharset UTF-8/' ${rc_doc_root}/.htaccess.tmp > ${rc_doc_root}/.htaccess
        rm -f ${rc_doc_root}/.htaccess.tmp
    fi
}

# ----------------------------------------------------------------------------
# show which Roundcube version is currently installed
# $1 - Roundcube instance
# ----------------------------------------------------------------------------
show_installed_version ()
{
    rc_nbr=$1
    eval rc_doc_root='$ROUNDCUBE_'${rc_nbr}'_DOCUMENT_ROOT'

    if [ -f ${rc_doc_root}/program/include/iniset.php ] ; then
        rc_version=`grep "RCMAIL_VERSION" ${rc_doc_root}/program/include/iniset.php | sed "s/^.*RCMAIL_VERSION' *, *'\(.*\)'.*$/\1/"`
        echo "- Roundcube version: ${rc_version}"
    fi
}

# ----------------------------------------------------------------------------
# remove installed program files
# $1 - Roundcube document root
# ----------------------------------------------------------------------------
remove_program_files ()
{
    rc_doc_root="$1"

    if [ -d "${rc_doc_root}" ] ; then
        mecho "- removing program files (${rc_doc_root}) ..."

        if [ -f "${docroot_filelist}" ] ; then
            while read line ; do
                # check for comment
                echo "${line}" | grep -q "^#"

                if [ $? -ne 0 ] ; then
                    # no comment - go on...
                    FDNAME="${testroot}${rc_doc_root}/${line}"

                    if [ -d "${FDNAME}" ] ; then
                        # remove directory
                        rmdir --ignore-fail-on-non-empty "${FDNAME}"
                    elif [ -f "${FDNAME}" ] ; then
                        # remove file
                        rm -f "${FDNAME}"
                    fi
                fi
            done < "${docroot_filelist}"
        else
            mecho --error "missing ${docroot_filelist} file, error removing package files!"
        fi

        # remove document root directory
        rmdir --ignore-fail-on-non-empty "${rc_doc_root}"
    fi
}

# ----------------------------------------------------------------------------
# purge document roots
# ----------------------------------------------------------------------------
purge_document_roots ()
{
    mecho "purging document root directories ..."

    # backup doccument root deletion list
    /var/install/bin/backup-file --quiet "${docroot_dellist}" backup

    if [ -f "${docroot_addlist}" ] ; then
        # document root list exists
        /var/install/bin/backup-file --quiet "${docroot_addlist}" backup

        if [ -f "${docroot_dellist}" ] ; then
            # append current document root list to deletion list
            cat "${docroot_dellist}" "${docroot_addlist}" | sort > "${docroot_tmplist}"
            mv  "${docroot_tmplist}" "${docroot_dellist}"
        else
            # copy current document root list to deletion list
            cp  "${docroot_addlist}" "${docroot_dellist}"
        fi

        # remove previous document root list
        rm -f "${docroot_addlist}"
    fi

    if [ ${ROUNDCUBE_N} -ne 0 ] ; then
        idx=1
        while [ ${idx} -le ${ROUNDCUBE_N} ] ; do
            eval rc_doc_root='$ROUNDCUBE_'${idx}'_DOCUMENT_ROOT'

            # add entry to document root list
            echo "${rc_doc_root}:" >> "${docroot_addlist}"

            if [ -f "${docroot_dellist}" ] ; then
                grep -q "^${rc_doc_root}:" "${docroot_dellist}"

                if [ $? -eq 0 ] ; then
                    # remove document root from deletion list
                    grep -v "^${rc_doc_root}:" "${docroot_dellist}" > "${docroot_tmplist}"
                    mv  "${docroot_tmplist}" "${docroot_dellist}"
                fi
            fi

            idx=`expr ${idx} + 1`
        done
    fi

    if [ -f "${docroot_dellist}" ] ; then
        if [ -f "${docroot_tmplist}" ] ; then
            rm -f "${docroot_tmplist}"
        fi

        cut -d: -f1 "${docroot_dellist}" |\
        while read line ; do
            echo "${line}" | grep -q "^#"

            if [ $? -ne 0 ] ; then
                if [ -d "${line}" ] ; then
                    # directory exists
                    /var/install/bin/ask "Directory '${line}' is not used anymore, delete it" 'n' > /tmp/ask.$$ <$tty
                    rc=$?
                    yesno=`cat /tmp/ask.$$|tr 'A-Z' 'a-z'`
                    rm -f /tmp/ask.$$
                    if [ $rc = 255 ] ; then
                        rm $tmpfile
                        exit 1
                    fi

                    if [ "${yesno}" = "yes" ] ; then
                        # delete Roundcube program directory
                        remove_program_files "${line}"
                    else
                        # preserve directory
                        echo "${line}:" >> "${docroot_tmplist}"
                    fi
                fi
            fi
        done

        if [ -f "${docroot_tmplist}" -a -s "${docroot_tmplist}" ] ; then
            # tmp file exists and contains data, replace deletion list
            mv "${docroot_tmplist}" "${docroot_dellist}"
        else
            # remove deletion list
            if [ -f "${docroot_dellist}" ] ; then
                rm -f "${docroot_dellist}"
            fi
        fi
    fi

    # delete temp file
    if [ -f "${docroot_tmplist}" ] ; then
        rm -f "${docroot_tmplist}"
    fi
}

#========================================================================================
# Main
#========================================================================================

case "$1" in
    create-sql-db)
        create_sql_db_and_table 'force'
        ;;
    delete-sql-db)
        remove_sql_db_and_table "$2" "$3" "$4"
        ;;
    removecron)
        delete_cron_job
        ;;
    *)
        mecho "version: ${roundcube_version}"

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
                # no local mail or vmail package installed
                MAIL_INSTALLED='none'
            fi

            # owncloud
            check_installed_owncloud
            OWNCLOUD_INSTALLED=$?

            write_to_config_log -header

            config_error=0
          # if ! check_active_apache_ssl
          # then
          #     config_error=1
          # fi

            mecho "db type: ${ROUNDCUBE_DB_TYPE}"

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
                mecho --error "pre-requisites not met, fix it and re-run configuration!"
                exit 1
            fi

            check_active_php_ldap
            check_imap_server

            create_sql_db_and_table ""

            rcidx=1
            while [ ${rcidx} -le ${ROUNDCUBE_N} ] ; do
                mecho "processing Roundcube instance (${rcidx}) ..."

                eval active='$ROUNDCUBE_'${rcidx}'_ACTIVE'

                if is_unique_docroot ${rcidx} ; then
                    # document root is unique
                    if [ "${active}" = "yes" ] ; then
                        copy_program_files ${rcidx}
                        show_installed_version ${rcidx}
                        set_default_charset ${rcidx}
                        create_roundcube_conf ${rcidx}
                    else
                        # generate stop configuration file
                        mecho --warn "- instance has been disabled."
                        write_to_config_log -warn "roundcube has been disabled."

                        create_roundcube_conf ${rcidx} 'stop'
                    fi
                fi

                rcidx=`expr ${rcidx} + 1`
            done

            force_roundcube_update
            set_roundcube_access_rights
            purge_document_roots
            add_cron_job

            mecho "finished."

            compress_config_log
            display_config_log
        else
            rcidx=1
            while [ ${rcidx} -le ${ROUNDCUBE_N} ] ; do
                create_roundcube_conf ${rcidx} 'stop'

                rcidx=`expr ${rcidx} + 1`
            done

            delete_cron_job
        fi

        # restart web server
        if /var/install/bin/ask "Do you want to restart the webserver now (recommended)" "yes" ; then
            /etc/init.d/apache2 restart
        fi
        ;;
esac

#========================================================================================
# End
#========================================================================================
exit 0
