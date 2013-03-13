/* ---------------------------------------------------------------------
 * File: server.c
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.c 28545 2011-06-13 19:27:26Z dv $
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

#include <stdlib.h>
#include <string.h>
#include "server.h"


#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

SQLCONNECT* DefaultConnect = NULL;


/* ---------------------------------------------------------------------
 * PgServerConnect
 * Establish connection to database server
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
PgServerConnect(const TCHAR* host, const TCHAR* port, 
                const TCHAR* user, const TCHAR* passwd,
                const TCHAR* database)
{
	SQLCONNECT* con = (SQLCONNECT*) malloc(sizeof(SQLCONNECT));
	if (con)
	{
		TCHAR connstr[256 + 1];
		char* mbstr;

		tcscpy(connstr, _T("dbname='"));
		tcscat(connstr, database);
		tcscat(connstr, _T("' user='"));
		tcscat(connstr, user);
		tcscat(connstr, _T("'"));
		if (tcslen(passwd))
		{
			tcscat(connstr, _T(" password='"));
			tcscat(connstr, passwd);
			tcscat(connstr, _T("'"));
		}
		if (tcslen(host))
		{
			tcscat(connstr, _T(" host='"));
			tcscat(connstr, host);
			tcscat(connstr, _T("'"));

			if (tcslen(port))
			{			
				tcscat(connstr, _T(" port='"));
				tcscat(connstr, port);
				tcscat(connstr, _T("'"));
			}
		}

		mbstr = ModuleTCharToMbDup(connstr);
		if (mbstr)
		{
			con->HConnect = PQconnectdb(mbstr);
			free(mbstr);

			if (con->HConnect)
			{
				if (PgServerIsConnected(con))
				{
					if (!DefaultConnect)
					{
						DefaultConnect = con;
					}					
					
					PgExecSQL(con, _T("SET client_min_messages = 'ERROR';"));
#ifdef _UNICODE
					PgExecSQL(con, _T("SET client_encoding = 'UNICODE';"));
#else
					PgExecSQL(con, _T("SET client_encoding = 'LATIN9';"));
#endif
				}
				con->User     = tcsdup(user);
				con->Database = tcsdup(database);
				con->Password = tcsdup(passwd);
				con->Host     = tcsdup(host);
				con->Port     = tcsdup(port);
				con->ErrMsg   = NULL;

				return con;
			}
		}
		free(con);
		return NULL;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * PgServerIsConnected
 * Check if database connection is established
 * ---------------------------------------------------------------------
 */
int 
PgServerIsConnected(SQLCONNECT* con)
{
	return (con && (PQstatus(con->HConnect) == CONNECTION_OK));
}


/* ---------------------------------------------------------------------
 * PgServerDisconnect
 * Close connection to database server
 * ---------------------------------------------------------------------
 */
void
PgServerDisconnect(SQLCONNECT* con)
{
	if (con)
	{
		if (DefaultConnect == con)
		{
			DefaultConnect = NULL;
		}
		PQfinish(con->HConnect);
		if (con->User) free(con->User);
		if (con->Password) free(con->Password);
		if (con->Database) free(con->Database);
		if (con->Host) free(con->Host);
		if (con->Port) free(con->Port);
		if (con->ErrMsg) free(con->ErrMsg);
		
		free(con);
	}
}


/* ---------------------------------------------------------------------
 * PgServerGetError
 * Get last error message available on this connection
 * ---------------------------------------------------------------------
 */
const TCHAR*
PgServerGetError(SQLCONNECT* con)
{
	if (con)
	{
		if (con->ErrMsg)
		{
			free(con->ErrMsg);
		}
		con->ErrMsg = ModuleMbToTCharDup(PQerrorMessage(con->HConnect));
		return con->ErrMsg;
	}
	else
	{
		return _T("No error message available!");
	}
}


/* ---------------------------------------------------------------------
 * PgServerPasswd
 * Returns the password used to open the connection
 * ---------------------------------------------------------------------
 */
const TCHAR*
PgServerPasswd(SQLCONNECT* con)
{
	if (con)
	{
		return con->Password;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * PgServerUser
 * Returns the user used to open the connection
 * ---------------------------------------------------------------------
 */
const TCHAR*
PgServerUser(SQLCONNECT* con)
{
	if (con)
	{
		return con->User;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * PgServerHost
 * Returns the host used to open the connection
 * ---------------------------------------------------------------------
 */
const TCHAR*
PgServerHost(SQLCONNECT* con)
{
	if (con)
	{
		return con->Host;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * PgServerPort
 * Returns the port used to open the connection
 * ---------------------------------------------------------------------
 */
const TCHAR* 
PgServerPort(SQLCONNECT* con)
{
	if (con)
	{
		return con->Port;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * PgServerGetError
 * Opens a connection to the same server with a different database
 * target but with the same user authentication
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
PgServerDupTo(SQLCONNECT* con, const TCHAR* database)
{
	if (con)
	{
		SQLCONNECT* con2 = (SQLCONNECT*) malloc(sizeof(SQLCONNECT));
		if (con2)
		{
			TCHAR connstr[256 + 1];
			char* mbstr;

			tcscpy(connstr, _T("dbname='"));
			tcscat(connstr, database);
			tcscat(connstr, _T("' user='"));
			tcscat(connstr, PgServerUser(con));
			tcscat(connstr, _T("'"));
			if (PgServerPasswd(con) && (tcslen(PgServerPasswd(con)) > 0))
			{
				tcscat(connstr, _T(" password='"));
				tcscat(connstr, PgServerPasswd(con));
				tcscat(connstr, _T("'"));
			}
			if (PgServerHost(con) && (tcslen(PgServerHost(con)) > 0))
			{
				tcscat(connstr, _T(" host='"));
				tcscat(connstr, PgServerHost(con));
				tcscat(connstr, _T("'"));
			}
			if (PgServerPort(con) && (tcslen(PgServerPort(con)) > 0))
			{
				tcscat(connstr, _T(" port='"));
				tcscat(connstr, PgServerPort(con));
				tcscat(connstr, _T("'"));
			}

			mbstr = ModuleTCharToMbDup(connstr);
			if (mbstr)
			{
				con2->HConnect = PQconnectdb(mbstr);
				free(mbstr);

				if (con2->HConnect)
				{
					if (!DefaultConnect)
					{
						DefaultConnect = con2;
					}
					PgExecSQL(con2, _T("SET client_min_messages = 'ERROR';"));
#ifdef _UNICODE
					PgExecSQL(con2, _T("SET client_encoding = 'UNICODE';"));
#else
					PgExecSQL(con2, _T("SET client_encoding = 'LATIN9';"));
#endif
					con2->User     = tcsdup(PgServerUser(con));
					con2->Database = tcsdup(database);
					con2->Password = tcsdup(PgServerPasswd(con));
					con2->Host     = tcsdup(PgServerHost(con));
					con2->Port     = tcsdup(PgServerPort(con));
					con2->ErrMsg   = NULL;

					return con2;
				}
			}
			free(con2);
			return NULL;
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * PgServerDefault
 * Returns the first database connection (used as default)
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
PgServerDefault(void)
{
	return DefaultConnect;
}


/* ---------------------------------------------------------------------
 * PgQuerySQL
 * Execute an SQL statement and return a result set, if the was statement
 * successfully executed by the server
 * ---------------------------------------------------------------------
 */
SQLRESULT* 
PgQuerySQL(SQLCONNECT* con, const TCHAR* sqlstmt)
{
	if (con && con->HConnect)
	{
		char* mbstmt = ModuleTCharToMbDup(sqlstmt);
		if (mbstmt)
		{
			PGresult* res = PQexec(con->HConnect, mbstmt);

			free(mbstmt);

			if (res)
			{
				ExecStatusType status = PQresultStatus(res);
				if ((status == PGRES_COMMAND_OK)||(status == PGRES_TUPLES_OK))
				{
					SQLRESULT* result  = (SQLRESULT*) malloc(sizeof(SQLRESULT));
					result->Result     = res;
					result->RowIndex   = -1;
					result->NumRows    = PQntuples(res);
					result->NumColumns = PQnfields(res);

					if ((status == PGRES_TUPLES_OK) && (result->NumColumns > 0))
					{
						int index;

						result->Columns   = (TCHAR**) malloc(result->NumColumns * sizeof(TCHAR*));
						result->RowData   = (TCHAR**) malloc(result->NumColumns * sizeof(TCHAR*));

						for (index = 0; index < result->NumColumns; index++)
						{
							result->Columns[index]  = ModuleMbToTCharDup(PQfname(res, index));
							result->RowData[index]  = NULL;
						}
					}
					else
					{
						result->NumColumns = 0;
						result->Columns = NULL;
						result->RowData = NULL;
					}

					return result;
				}
				PQclear(res);
			}
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * PgExecSQL
 * Execute an SQL statement directly without returning an result set
 * ---------------------------------------------------------------------
 */
int
PgExecSQL(SQLCONNECT* con, const TCHAR* sqlstmt)
{
	SQLRESULT* res = PgQuerySQL(con, sqlstmt);
	if (res)
	{
		PgResultFree(res);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PgResultStatus
 * Status of the last operation
 * ---------------------------------------------------------------------
 */
SQLEXECSTATUS 
PgResultStatus(SQLRESULT* result)
{
	if (result)
	{
		switch(PQresultStatus(result->Result))
		{
		case PGRES_COMMAND_OK:
			return SQL_COMMAND_OK;
		case PGRES_TUPLES_OK:
			return SQL_DATA_READY;
		default:
			return SQL_ERROR;
		}
	}
	return SQL_ERROR;
}


/* ---------------------------------------------------------------------
 * PgResultNumRows
 * Returns the number of rows contained in the result set
 * ---------------------------------------------------------------------
 */
int 
PgResultNumRows(SQLRESULT* result)
{
	return result->NumRows;
}


/* ---------------------------------------------------------------------
 * PgResultNumColumns
 * Returns the number of columns contained in the result set
 * ---------------------------------------------------------------------
 */
int 
PgResultNumColumns(SQLRESULT* result)
{
	return result->NumColumns;
}


/* ---------------------------------------------------------------------
 * PgResultColumnName
 * Return the name of the specified column
 * ---------------------------------------------------------------------
 */
const TCHAR* 
PgResultColumnName(SQLRESULT* result, int index)
{
	if ((index >= 0) && (index < result->NumColumns))
	{
		return (result->Columns[index]) ? result->Columns[index] : _T("");
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * PgResultColumnSize
 * Field size in the specified column
 * ---------------------------------------------------------------------
 */
int 
PgResultColumnSize(SQLRESULT* result, int index)
{
	return PQfsize(result->Result, index);
}


/* ---------------------------------------------------------------------
 * PgResultFirst
 * Move the cursor to the next result tuple. Note that after a result
 * set is returned, the cursor has to be moved with ResultFirst to the
 * first row.
 * ---------------------------------------------------------------------
 */
int 
PgResultFirst(SQLRESULT* result)
{
	if (result->NumRows > 0)
	{
		result->RowIndex = 0;

		if (result->RowData)
		{
			int index;
			const char* data;

			for (index = 0; index < result->NumColumns; index++)
			{
				if (result->RowData[index] != NULL)
				{
					free(result->RowData[index]);
					result->RowData[index] = NULL;
				}

				data = PQgetvalue(result->Result, result->RowIndex, index);
				if (data)
				{
					result->RowData[index] = ModuleMbToTCharDup(data);
				}
			}
		}		
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PgResultPrevious
 * Move the cursor to the previous result tuple. 
 * ---------------------------------------------------------------------
 */
int 
PgResultPrevious(SQLRESULT* result)
{
	if (result->RowIndex > 0)
	{
		result->RowIndex--;

		if (result->RowData)
		{
			int index;
			const char* data;

			for (index = 0; index < result->NumColumns; index++)
			{
				if (result->RowData[index] != NULL)
				{
					free(result->RowData[index]);
					result->RowData[index] = NULL;
				}

				data = PQgetvalue(result->Result, result->RowIndex, index);
				if (data)
				{
					result->RowData[index] = ModuleMbToTCharDup(data);
				}
			}
		}		
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PgResultNext
 * Move the cursor to the next result tuple. 
 * ---------------------------------------------------------------------
 */
int 
PgResultNext(SQLRESULT* result)
{
	if (result->RowIndex < (result->NumRows - 1))
	{
		result->RowIndex++;

		if (result->RowData)
		{
			int index;
			const char* data;

			for (index = 0; index < result->NumColumns; index++)
			{
				if (result->RowData[index] != NULL)
				{
					free(result->RowData[index]);
					result->RowData[index] = NULL;
				}

				data = PQgetvalue(result->Result, result->RowIndex, index);
				if (data)
				{
					result->RowData[index] = ModuleMbToTCharDup(data);
				}
			}
		}		
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PgResultLast
 * Move the cursor to the last result tuple.
 * ---------------------------------------------------------------------
 */
int 
PgResultLast(SQLRESULT* result)
{
	if (result->NumRows > 0)
	{
		result->RowIndex = (result->NumRows - 1);

		if (result->RowData)
		{
			int index;
			const char* data;

			for (index = 0; index < result->NumColumns; index++)
			{
				if (result->RowData[index] != NULL)
				{
					free(result->RowData[index]);
					result->RowData[index] = NULL;
				}

				data = PQgetvalue(result->Result, result->RowIndex, index);
				if (data)
				{
					result->RowData[index] = ModuleMbToTCharDup(data);
				}
			}
		}		
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PgResultData
 * Read the data from the result set.
 * ---------------------------------------------------------------------
 */
const TCHAR* 
PgResultData(SQLRESULT* result, int index)
{
	if ((result->RowIndex >= 0) && (index >= 0) && (index < result->NumColumns))
	{
		return result->RowData[index];
	}
	else
	{
		return _T("");
	}
}


/* ---------------------------------------------------------------------
 * PgResultIsNull
 * is column 'index' a NULL value?
 * ---------------------------------------------------------------------
 */
int 
PgResultIsNull(SQLRESULT* result, int index)
{
	return PQgetisnull(result->Result, result->RowIndex, index);
}


/* ---------------------------------------------------------------------
 * PgResultReset
 * Reset the data cursor. The next call to ResultFetch will address the
 * first row within the result set.
 * ---------------------------------------------------------------------
 */
void
PgResultReset(SQLRESULT* result)
{
	result->RowIndex = -1;
}


/* ---------------------------------------------------------------------
 * PgResultFree
 * Free the result set and all associated data
 * ---------------------------------------------------------------------
 */
void 
PgResultFree(SQLRESULT* result)
{
	int i;

	if (result->Columns)
	{
		for (i = 0; i < result->NumColumns; i++)
		{
			if (result->Columns[i]) free(result->Columns[i]);
		}
	}
	if (result->RowData)
	{
		for (i = 0; i < result->NumColumns; i++)
		{
			if (result->RowData[i]) free(result->RowData[i]);
		}
	}
	if (result->Columns)   free(result->Columns);
	if (result->RowData)   free(result->RowData);
	PQclear(result->Result);
	free(result);
}

