# !/bin/sh

. /var/install/include/cuilib
. /var/install/include/mysqllib-1


#----------------------------------------------------------------------------
# init routine (entry point of all shellrun.cui based programs)
#    $p2 --> desktop window handle
#----------------------------------------------------------------------------

function init()
{
    local win="$p2"

    my_initmodule
    if [ "$?" != "0" ]
    then
        cui_message "$win" "Unable to load mysql module" "Error" "$MB_ERROR"
        cui_return 0
        return
    else
        cui_message "$win" "mysql module loaded${CUINL}Success" "Error" "$MB_OK"
    fi

    my_server_connect "192.168.56.1" "3300" "test" "test" "testdb"
    if [ "$p2" != "0" ]
    then
        myconn="$p2"

        my_server_isconnected "$p2"
        if [ "$p2" != "0" ]
        then
            cui_message "$win" "Connection established" "Result" "$MB_OK"

            my_query_sql "$myconn" "SELECT name FROM test WHERE firstname = 'Willi';"
            if [ "$p2" != "0" ]
            then
                myres="$p2"
                my_result_status "$myres"
                if [ "$p2" == "${SQL_DATA_READY}" ]
                then

                    my_result_fetch "$myres"
                    while [ "$p2" == "1" ]  
                    do
                        my_result_data "$myres" "0" && name="$p2"

                        cui_message "$win" "Name = $name" "Result" "$MB_OK"

                        my_result_fetch "$myres"
                    done

                    cui_message "$win" "Query OK" "Result" "$MB_OK"
                else
                    my_server_geterror "$myconn"
                    cui_message "$win" "$p2" "Error" "$MB_ERROR"
                fi

                my_result_free "$myres"
            else
                my_server_geterror "$myconn"
                cui_message "$win" "$p2" "Error" "$MB_ERROR"
            fi
        else  
            my_server_geterror "$myconn"
            cui_message "$win" "$p2" "Error" "$MB_ERROR"
        fi

        my_server_disconnect "$myconn"
    fi

    cui_return 0
}


#----------------------------------------------------------------------------
# main routines (always at the bottom of the file)
#----------------------------------------------------------------------------

cui_init
cui_run

exit 0
