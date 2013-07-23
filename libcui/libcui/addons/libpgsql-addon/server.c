/* ---------------------------------------------------------------------
 * File: server.c
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.c 33455 2013-04-13 00:02:22Z dv $
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


static const char *PgServerGetEncoding(char *buffer, int buflen);

SQLCONNECT* DefaultConnect = NULL;


/* ---------------------------------------------------------------------
 * PgServerConnect
 * Establish connection to database server
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
PgServerConnect(const wchar_t* host, const wchar_t* port, 
                const wchar_t* user, const wchar_t* passwd,
                const wchar_t* database)
{
	SQLCONNECT* con = (SQLCONNECT*) malloc(sizeof(SQLCONNECT));
	if (con)
	{
		wchar_t connstr[256 + 1];
		char* mbstr;

		wcscpy(connstr, _T("dbname='"));
		wcscat(connstr, database);
		wcscat(connstr, _T("' user='"));
		wcscat(connstr, user);
		wcscat(connstr, _T("'"));
		if (wcslen(passwd))
		{
			wcscat(connstr, _T(" password='"));
			wcscat(connstr, passwd);
			wcscat(connstr, _T("'"));
		}
		if (wcslen(host))
		{
			wcscat(connstr, _T(" host='"));
			wcscat(connstr, host);
			wcscat(connstr, _T("'"));

			if (wcslen(port))
			{			
				wcscat(connstr, _T(" port='"));
				wcscat(connstr, port);
				wcscat(connstr, _T("'"));
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
					char encoding[64 + 1];
				
					if (!DefaultConnect)
					{
						DefaultConnect = con;
					}					

					PgServerGetEncoding(encoding, 64);
														
					PgExecSQL(con, _T("SET client_min_messages = 'ERROR';"));
					
					if ((strcasecmp(encoding, "utf-8") == 0) ||
					    (strcasecmp(encoding, "utf8")  == 0))
					{
						PgExecSQL(con, _T("SET client_encoding = 'UNICODE';"));
					}
					else
					{
						PgExecSQL(con, _T("SET client_encoding = 'LATIN9';"));
					}
				}
				con->User     = wcsdup(user);
				con->Database = wcsdup(database);
				con->Password = wcsdup(passwd);
				con->Host     = wcsdup(host);
				con->Port     = wcsdup(port);
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
const wchar_t*
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
const wchar_t*
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
const wchar_t*
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
const wchar_t*
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
const wchar_t* 
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
PgServerDupTo(SQLCONNECT* con, const wchar_t* database)
{
	if (con)
	{
		SQLCONNECT* con2 = (SQLCONNECT*) malloc(sizeof(SQLCONNECT));
		if (con2)
		{
			wchar_t connstr[256 + 1];
			char* mbstr;

			wcscpy(connstr, _T("dbname='"));
			wcscat(connstr, database);
			wcscat(connstr, _T("' user='"));
			wcscat(connstr, PgServerUser(con));
			wcscat(connstr, _T("'"));
			if (PgServerPasswd(con) && (wcslen(PgServerPasswd(con)) > 0))
			{
				wcscat(connstr, _T(" password='"));
				wcscat(connstr, PgServerPasswd(con));
				wcscat(connstr, _T("'"));
			}
			if (PgServerHost(con) && (wcslen(PgServerHost(con)) > 0))
			{
				wcscat(connstr, _T(" host='"));
				wcscat(connstr, PgServerHost(con));
				wcscat(connstr, _T("'"));
			}
			if (PgServerPort(con) && (wcslen(PgServerPort(con)) > 0))
			{
				wcscat(connstr, _T(" port='"));
				wcscat(connstr, PgServerPort(con));
				wcscat(connstr, _T("'"));
			}

			mbstr = ModuleTCharToMbDup(connstr);
			if (mbstr)
			{
				con2->HConnect = PQconnectdb(mbstr);
				free(mbstr);

				if (con2->HConnect)
				{
					char encoding[64 + 1];
				
					if (!DefaultConnect)
					{
						DefaultConnect = con2;
					}					

					PgServerGetEncoding(encoding, 64);

					PgExecSQL(con2, _T("SET client_min_messages = 'ERROR';"));

					if ((strcasecmp(encoding, "utf-8") == 0) ||
					    (strcasecmp(encoding, "utf8")  == 0))
					{
						PgExecSQL(con2, _T("SET client_encoding = 'UNICODE';"));
					}
					else
					{
						PgExecSQL(con2, _T("SET client_encoding = 'LATIN9';"));
					}
					
					con2->User     = wcsdup(PgServerUser(con));
					con2->Database = wcsdup(database);
					con2->Password = wcsdup(PgServerPasswd(con));
					con2->Host     = wcsdup(PgServerHost(con));
					con2->Port     = wcsdup(PgServerPort(con));
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
PgQuerySQL(SQLCONNECT* con, const wchar_t* sqlstmt)
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

						result->Columns   = (wchar_t**) malloc(result->NumColumns * sizeof(wchar_t*));
						result->RowData   = (wchar_t**) malloc(result->NumColumns * sizeof(wchar_t*));

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
PgExecSQL(SQLCONNECT* con, const wchar_t* sqlstmt)
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
const wchar_t* 
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
const wchar_t* 
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


/* ---------------------------------------------------------------------
 * PgServerGetEncoding
 * Copy contents of environment variable $LC_CTYPE into a memory buffer
 * beginning with the char position right behind the fullstop
 * ---------------------------------------------------------------------
 */
static const char *
PgServerGetEncoding(char *buffer, int buflen)
{
	const char *env = getenv("LC_CTYPE");
	
	buffer[0] = '\0';
	if (env)
	{
		env = strchr(env, '.');
		if (env)
		{
			strncpy(buffer, env + 1, buflen);
			buffer[buflen] = '\0';
		}
	}
	return buffer;
}
