/* ---------------------------------------------------------------------
 * File: server.h
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.h 33397 2013-04-02 20:48:05Z dv $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * ---------------------------------------------------------------------
 */

#ifndef SERVER_H
#define SERVER_H

#include "chartools.h"
#include <libpq-fe.h>


typedef struct
{
	PGconn*   HConnect;

	wchar_t*    User;
	wchar_t*    Password;
	wchar_t*    Database;
	wchar_t*    Host;
	wchar_t*    Port;

	wchar_t*    ErrMsg;
} SQLCONNECT;


typedef struct
{
	int       RowIndex;
	int       NumRows;
	int       NumColumns;
	PGresult* Result;
	wchar_t**   Columns;
	wchar_t**   RowData;
} SQLRESULT;


typedef enum
{
        SQL_COMMAND_OK = 0,
        SQL_DATA_READY = 1,
        SQL_ERROR      = 2,
} SQLEXECSTATUS;


SQLCONNECT*    PgServerConnect(const wchar_t* host, const wchar_t* port, 
                               const wchar_t* user, const wchar_t* passwd,
                               const wchar_t* database);
void           PgServerDisconnect(SQLCONNECT* con);
int            PgServerIsConnected(SQLCONNECT* con);
const wchar_t* PgServerGetError(SQLCONNECT* con);
const wchar_t* PgServerPasswd(SQLCONNECT* con);
const wchar_t* PgServerUser(SQLCONNECT* con);
const wchar_t* PgServerHost(SQLCONNECT* con);
const wchar_t* PgServerPort(SQLCONNECT* con);

SQLCONNECT*    PgServerDupTo(SQLCONNECT* con, const wchar_t* database);

SQLRESULT*     PgQuerySQL(SQLCONNECT* con, const wchar_t* sqlstmt);
int            PgExecSQL(SQLCONNECT* con, const wchar_t* sqlstmt);

SQLCONNECT*    PgServerDefault(void);

SQLEXECSTATUS  PgResultStatus(SQLRESULT* result);
int            PgResultNumRows(SQLRESULT* result);
int            PgResultNumColumns(SQLRESULT* result);
const wchar_t* PgResultColumnName(SQLRESULT* result, int index);
int            PgResultColumnSize(SQLRESULT* result, int index);
int            PgResultFirst(SQLRESULT* result);
int            PgResultPrevious(SQLRESULT* result);
int            PgResultNext(SQLRESULT* result);
int            PgResultLast(SQLRESULT* result);
const wchar_t* PgResultData(SQLRESULT* result, int index);
int            PgResultIsNull(SQLRESULT* result, int index);
void           PgResultReset(SQLRESULT* result);
void           PgResultFree(SQLRESULT* result);

#endif
