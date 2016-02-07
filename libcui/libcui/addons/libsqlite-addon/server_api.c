/* ---------------------------------------------------------------------
 * File: server_api.c
 * (wrapper for sqlite client library)
 *
 * Copyright (C) 2016 Jens Vehlhaber
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * ---------------------------------------------------------------------
 */

#include <cui.h>
#include <cui-script.h>
#include "chartools.h"
#include "server_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

/* ---------------------------------------------------------------------
 * global data
 * ---------------------------------------------------------------------
example:
*/

#include <sqlite3.h>
#include <stdio.h>

int callback(void *, int, char **, char **);

int main(void) {
    sqlite3 *db;
    char *err_msg = 0;

    int rc = sqlite3_open("test.db", &db);

    if (rc != SQLITE_OK) {
        
        fprintf(stderr, "Cannot open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        
        return 1;
    }
    
    char *sql = "SELECT * FROM Cars";
        
    rc = sqlite3_exec(db, sql, callback, 0, &err_msg);
    
    if (rc != SQLITE_OK ) {
        
        fprintf(stderr, "Failed to select data\n");
        fprintf(stderr, "SQL error: %s\n", err_msg);

        sqlite3_free(err_msg);
        sqlite3_close(db);
        
        return 1;
    }
    
    sqlite3_close(db);
    
    return 0;
}

int callback(void *NotUsed, int argc, char **argv, 
                    char **azColName) {
    
    NotUsed = 0;
    
    for (int i = 0; i < argc; i++) {

        printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
    }
    
    printf("\n");
    
    return 0;
}

