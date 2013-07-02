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
#include <mysql.h>


typedef struct
{
	MYSQL      HConnect;

	wchar_t*   User;
	wchar_t*   Password;
	wchar_t*   Database;
	wchar_t*   Host;
	wchar_t*   Port;

	wchar_t*   ErrMsg;
	int        Connected;
} SQLCONNECT;


typedef struct
{
	int        RowIndex;
	int        NumRows;
	int        NumColumns;
	MYSQL_RES* Result;
	MYSQL_ROW  Row;
	wchar_t**  Columns;
	wchar_t**  RowData;
} SQLRESULT;


typedef enum
{
	SQL_COMMAND_OK = 0,
	SQL_DATA_READY = 1,
	SQL_ERROR      = 2,
} SQLEXECSTATUS;


SQLCONNECT*    MyServerConnect(const wchar_t* host, const wchar_t* port, 
                               const wchar_t* user, const wchar_t* passwd,
                               const wchar_t* database);
void           MyServerDisconnect(SQLCONNECT* con);
int            MyServerIsConnected(SQLCONNECT* con);
const wchar_t* MyServerGetError(SQLCONNECT* con);
const wchar_t* MyServerPasswd(SQLCONNECT* con);
const wchar_t* MyServerUser(SQLCONNECT* con);
const wchar_t* MyServerHost(SQLCONNECT* con);
const wchar_t* MyServerPort(SQLCONNECT* con);

SQLCONNECT*    MyServerDupTo(SQLCONNECT* con, const wchar_t* database);

SQLRESULT*     MyQuerySQL(SQLCONNECT* con, const wchar_t* sqlstmt);
int            MyExecSQL(SQLCONNECT* con, const wchar_t* sqlstmt);

SQLCONNECT*    MyServerDefault(void);

SQLEXECSTATUS  MyResultStatus(SQLRESULT* result);
int            MyResultNumRows(SQLRESULT* result);
int            MyResultNumColumns(SQLRESULT* result);
const wchar_t* MyResultColumnName(SQLRESULT* result, int index);
int            MyResultColumnSize(SQLRESULT* result, int index);
int            MyResultFetch(SQLRESULT* result);
const wchar_t* MyResultData(SQLRESULT* result, int index);
int            MyResultIsNull(SQLRESULT* result, int index);
void           MyResultReset(SQLRESULT* result);
void           MyResultFree(SQLRESULT* result);

#endif
