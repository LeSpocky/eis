/* ---------------------------------------------------------------------
 * File: server.h
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.h 28545 2011-06-13 19:27:26Z dv $
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

	TCHAR*    User;
	TCHAR*    Password;
	TCHAR*    Database;
	TCHAR*    Host;
	TCHAR*    Port;

	TCHAR*    ErrMsg;
} SQLCONNECT;


typedef struct
{
	int       RowIndex;
	int       NumRows;
	int       NumColumns;
	PGresult* Result;
	TCHAR**   Columns;
	TCHAR**   RowData;
} SQLRESULT;


typedef enum
{
        SQL_COMMAND_OK = 0,
        SQL_DATA_READY = 1,
        SQL_ERROR      = 2,
} SQLEXECSTATUS;


SQLCONNECT*    PgServerConnect(const TCHAR* host, const TCHAR* port, 
                               const TCHAR* user, const TCHAR* passwd,
                               const TCHAR* database);
void           PgServerDisconnect(SQLCONNECT* con);
int            PgServerIsConnected(SQLCONNECT* con);
const TCHAR*   PgServerGetError(SQLCONNECT* con);
const TCHAR*   PgServerPasswd(SQLCONNECT* con);
const TCHAR*   PgServerUser(SQLCONNECT* con);
const TCHAR*   PgServerHost(SQLCONNECT* con);
const TCHAR*   PgServerPort(SQLCONNECT* con);

SQLCONNECT*    PgServerDupTo(SQLCONNECT* con, const TCHAR* database);

SQLRESULT*     PgQuerySQL(SQLCONNECT* con, const TCHAR* sqlstmt);
int            PgExecSQL(SQLCONNECT* con, const TCHAR* sqlstmt);

SQLCONNECT*    PgServerDefault(void);

SQLEXECSTATUS  PgResultStatus(SQLRESULT* result);
int            PgResultNumRows(SQLRESULT* result);
int            PgResultNumColumns(SQLRESULT* result);
const TCHAR*   PgResultColumnName(SQLRESULT* result, int index);
int            PgResultColumnSize(SQLRESULT* result, int index);
int            PgResultFirst(SQLRESULT* result);
int            PgResultPrevious(SQLRESULT* result);
int            PgResultNext(SQLRESULT* result);
int            PgResultLast(SQLRESULT* result);
const TCHAR*   PgResultData(SQLRESULT* result, int index);
int            PgResultIsNull(SQLRESULT* result, int index);
void           PgResultReset(SQLRESULT* result);
void           PgResultFree(SQLRESULT* result);

#endif
