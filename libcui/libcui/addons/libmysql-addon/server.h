/* ---------------------------------------------------------------------
 * File: server.h
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.h 23497 2010-03-14 21:53:08Z dv $
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
#include <mysql.h>

typedef struct
{
	MYSQL      HConnect;

	TCHAR*     User;
	TCHAR*     Password;
	TCHAR*     Database;
	TCHAR*     Host;
	TCHAR*     Port;

	TCHAR*     ErrMsg;
	int        Connected;
} SQLCONNECT;


typedef struct
{
	int        RowIndex;
	int        NumRows;
	int        NumColumns;
	MYSQL_RES* Result;
	MYSQL_ROW  Row;
	TCHAR**    Columns;
	TCHAR**    RowData;
} SQLRESULT;


typedef enum
{
        SQL_COMMAND_OK = 0,
        SQL_DATA_READY = 1,
        SQL_ERROR      = 2,
} SQLEXECSTATUS;


SQLCONNECT*    MyServerConnect(const TCHAR* host, const TCHAR* port, 
                               const TCHAR* user, const TCHAR* passwd,
                               const TCHAR* database);
void           MyServerDisconnect(SQLCONNECT* con);
int            MyServerIsConnected(SQLCONNECT* con);
const TCHAR*   MyServerGetError(SQLCONNECT* con);
const TCHAR*   MyServerPasswd(SQLCONNECT* con);
const TCHAR*   MyServerUser(SQLCONNECT* con);
const TCHAR*   MyServerHost(SQLCONNECT* con);
const TCHAR*   MyServerPort(SQLCONNECT* con);

SQLCONNECT*    MyServerDupTo(SQLCONNECT* con, const TCHAR* database);

SQLRESULT*     MyQuerySQL(SQLCONNECT* con, const TCHAR* sqlstmt);
int            MyExecSQL(SQLCONNECT* con, const TCHAR* sqlstmt);

SQLCONNECT*    MyServerDefault(void);

SQLEXECSTATUS  MyResultStatus(SQLRESULT* result);
int            MyResultNumRows(SQLRESULT* result);
int            MyResultNumColumns(SQLRESULT* result);
const TCHAR*   MyResultColumnName(SQLRESULT* result, int index);
int            MyResultColumnSize(SQLRESULT* result, int index);
int            MyResultFetch(SQLRESULT* result);
const TCHAR*   MyResultData(SQLRESULT* result, int index);
int            MyResultIsNull(SQLRESULT* result, int index);
void           MyResultReset(SQLRESULT* result);
void           MyResultFree(SQLRESULT* result);

#endif
