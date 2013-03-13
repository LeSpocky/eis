# !/bin/sh

. /var/install/include/cuilib
. /var/install/include/pgsqllib-1


#----------------------------------------------------------------------------
# init routine (entry point of all shellrun.cui based programs)
#    $p2 --> desktop window handle
#----------------------------------------------------------------------------

function init()
{
    local win="$p2"

    pg_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load postgres module" "Error" "$MB_ERROR"
        cui_return 0
        return
    else
        cui_message "$win" "postgres module loaded${CUINL}Success" "Error" "$MB_OK"
    fi

    pg_server_connect "localhost" "5432" "testuser" "testtest" "testdb"
    if [ "$p2" != "0" ]
    then
        pgconn="$p2"

        pg_server_isconnected "$p2"
        if [ "$p2" != "0" ]
        then
            cui_message "$win" "Connection established" "Result" "$MB_OK"

            pg_query_sql "$pgconn" "SELECT name FROM test WHERE firstname = 'Willi';"
            if [ "$p2" != "0" ]
            then
                pgres="$p2"
                pg_result_status "$pgres"
                if [ "$p2" == "${SQL_DATA_READY}" ]
                then

                    pg_result_first "$pgres"
                    while [ "$p2" == "1" ]  
                    do
                        pg_result_data "$pgres" "0" && name="$p2"
                        pg_result_next "$pgres"
                    done

                    cui_message "$win" "Query OK" "Result" "$MB_OK"
                else
                    pg_server_geterror "$pgconn"
                    cui_message "$win" "$p2" "Error" "$MB_ERROR"
                fi

                pg_result_free "$pgres"
            else
                pg_server_geterror "$pgconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi
        else  
            pg_server_geterror "$pgconn"
            cui_message "$win" "$p2" "Error" "$MB_ERROR"
        fi

        pg_server_disconnect "$pgconn"
    fi

    cui_return 0
}


#----------------------------------------------------------------------------
# main routines (always at the bottom of the file)
#----------------------------------------------------------------------------

cui_init
cui_run

exit 0
