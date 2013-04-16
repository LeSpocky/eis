/* ---------------------------------------------------------------------
 * File: server.c
 * (connection to database server)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: server.c 33402 2013-04-02 21:32:17Z dv $
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
#include <stdio.h>
#include <string.h>
#include "server.h"
#include "inifile.h"


#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

SQLCONNECT* DefaultConnect = NULL;
int         Initialized = FALSE;

/* local prototypes */
static const char* MyGetClientSocket(void);


/* ---------------------------------------------------------------------
 * MyServerConnect
 * Establish connection to database server
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
MyServerConnect(const wchar_t* host, const wchar_t* port, 
                const wchar_t* user, const wchar_t* passwd,
                const wchar_t* database)
{
	SQLCONNECT* con;

	if (!Initialized)
	{
		my_init();
		Initialized = TRUE;
	}

	con = (SQLCONNECT*) malloc(sizeof(SQLCONNECT));
	if (con)
	{
		int  iport = 3306;
		const char* socket = NULL;
		
		char *mbhost     = (host != NULL)     ? ModuleTCharToMbDup(host) : NULL;
		char *mbuser     = (user != NULL)     ? ModuleTCharToMbDup(user) : NULL;
		char *mbdatabase = (database != NULL) ? ModuleTCharToMbDup(database) : NULL;
		char *mbpasswd   = (passwd != NULL)   ? ModuleTCharToMbDup(passwd) : NULL;
		
		if (port)
		{
			swscanf(port, _T("%d"), &iport);
		}
		
		/* in case of local connections, we try to read the name of the socket
		   from /etc/my.cnf */
		if (wcscmp(host, _T("localhost")) == 0)
		{
			socket = MyGetClientSocket();
		}

		con->Connected   = FALSE;
		con->Host        = (host != NULL)     ? wcsdup(host) : NULL;
		con->User        = (user != NULL)     ? wcsdup(user) : NULL;
		con->Database    = (database != NULL) ? wcsdup(database) : NULL;
		con->Password    = (passwd != NULL)   ? wcsdup(passwd) : NULL;
		con->Port        = (port != NULL)     ? wcsdup(port) : NULL;
		con->ErrMsg      = NULL;

		mysql_init(&con->HConnect);

		if (mysql_real_connect(&con->HConnect, mbhost, mbuser, mbpasswd, mbdatabase, iport, socket, 0))
		{
			con->Connected = TRUE;

			if (!DefaultConnect)
			{
				DefaultConnect = con;
			}
		}
		else
		{   
			con->Connected = FALSE;
		}

		if (mbhost)     free(mbhost);
		if (mbuser)     free(mbuser);
		if (mbdatabase) free(mbdatabase);
		if (mbpasswd)   free(mbpasswd);

		return con;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MyServerIsConnected
 * Check if database connection is established
 * ---------------------------------------------------------------------
 */
int 
MyServerIsConnected(SQLCONNECT* con)
{
	return (con && (con->Connected));
}


/* ---------------------------------------------------------------------
 * MyServerDisconnect
 * Close connection to database server
 * ---------------------------------------------------------------------
 */
void
MyServerDisconnect(SQLCONNECT* con)
{
	if (con)
	{
		if (DefaultConnect == con)
		{
			DefaultConnect = NULL;
		}
		mysql_close(&con->HConnect);
		if (con->User)     free(con->User);
		if (con->Password) free(con->Password);
		if (con->Database) free(con->Database);
		if (con->Host)     free(con->Host);
		if (con->Port)     free(con->Port);
		if (con->ErrMsg)   free(con->ErrMsg);
		free(con);
	}
}


/* ---------------------------------------------------------------------
 * MyServerGetError
 * Get last error message available on this connection
 * ---------------------------------------------------------------------
 */
const wchar_t*
MyServerGetError(SQLCONNECT* con)
{
	if (con)
	{
		if (con->ErrMsg)
		{
			free(con->ErrMsg);
		}
		con->ErrMsg = ModuleMbToTCharDup(mysql_error(&con->HConnect));
		return con->ErrMsg;
	}
	else
	{
		return _T("No error message available!");
	}
}


/* ---------------------------------------------------------------------
 * MyServerPasswd
 * Returns the password used to open the connection
 * ---------------------------------------------------------------------
 */
const wchar_t*
MyServerPasswd(SQLCONNECT* con)
{
	if (con)
	{
		return con->Password;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * MyServerUser
 * Returns the user used to open the connection
 * ---------------------------------------------------------------------
 */
const wchar_t*
MyServerUser(SQLCONNECT* con)
{
	if (con)
	{
		return con->User;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * MyServerHost
 * Returns the host used to open the connection
 * ---------------------------------------------------------------------
 */
const wchar_t*
MyServerHost(SQLCONNECT* con)
{
	if (con)
	{
		return con->Host;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * MyServerPort
 * Returns the port used to open the connection
 * ---------------------------------------------------------------------
 */
const wchar_t* 
MyServerPort(SQLCONNECT* con)
{
	if (con)
	{
		return con->Port;
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * MyServerDupTo
 * Opens a connection to the same server with a different database
 * target but with the same user authentication
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
MyServerDupTo(SQLCONNECT* con, const wchar_t* database)
{
	if (con)
	{
		return MyServerConnect(con->Host, con->Port,
			con->User, con->Password,
			database);
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MyServerDefault
 * Returns the first database connection (used as default)
 * ---------------------------------------------------------------------
 */
SQLCONNECT*
MyServerDefault(void)
{
	return DefaultConnect;
}


/* ---------------------------------------------------------------------
 * MyQuerySQL
 * Execute an SQL statement and return a result set, if the was statement
 * successfully executed by the server
 * ---------------------------------------------------------------------
 */
SQLRESULT* 
MyQuerySQL(SQLCONNECT* con, const wchar_t* sqlstmt)
{
	if (con && con->Connected)
	{
		char* mbstmt = ModuleTCharToMbDup(sqlstmt);
		if (mbstmt)
		{
			if (mysql_query(&con->HConnect, mbstmt))
			{
				free(mbstmt);
				return NULL;
			}
			else
			{   
				SQLRESULT* result = (SQLRESULT*) malloc(sizeof(SQLRESULT));
				if (result)
				{
					result->Result = mysql_store_result(&con->HConnect);
					if (result->Result)
					{
						int index;
						result->NumColumns = mysql_num_fields(result->Result);
						result->NumRows    = mysql_num_rows(result->Result);
						result->RowIndex   = 0;
						result->Row        = NULL;

						result->Columns   = (wchar_t**) malloc(result->NumColumns * sizeof(wchar_t*));
						result->RowData   = (wchar_t**) malloc(result->NumColumns * sizeof(wchar_t*));

						for (index = 0; index < result->NumColumns; index++)
						{
							MYSQL_FIELD* field;

							field = mysql_fetch_field_direct(result->Result, index);
							result->Columns[index]  = ModuleMbToTCharDup(field->name);
							result->RowData[index]  = NULL;
						}
					}
					else
					{      
						// mysql_store_result() returned nothing; should it have?
						if (mysql_field_count(&con->HConnect) == 0)
						{
							// query does not return data
							// (it was not a SELECT)
							result->NumColumns = 0;  
							result->NumRows = mysql_affected_rows(&con->HConnect);
							result->Columns = NULL;
							result->RowData = NULL;
						}
						else
						{
							free(result);
							result = NULL;
						}
					}
					free(mbstmt);
					return result;
				}
			}
			free(mbstmt);
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MyExecSQL
 * Execute an SQL statement directly without returning an result set
 * ---------------------------------------------------------------------
 */
int
MyExecSQL(SQLCONNECT* con, const wchar_t* sqlstmt)
{
	SQLRESULT* res = MyQuerySQL(con, sqlstmt);
	if (res)
	{
		MyResultFree(res);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * MyResultStatus
 * Status of the last operation
 * ---------------------------------------------------------------------
 */
SQLEXECSTATUS 
MyResultStatus(SQLRESULT* result)
{
	if (result)
	{
		if (result->Result)
		{
			return SQL_DATA_READY;
		}
		else
		{
			return SQL_COMMAND_OK;
		}
	}
	return SQL_ERROR;
}


/* ---------------------------------------------------------------------
 * MyResultNumRows
 * Returns the number of rows contained in the result set
 * ---------------------------------------------------------------------
 */
int 
MyResultNumRows(SQLRESULT* result)
{
	return result->NumRows;
}


/* ---------------------------------------------------------------------
 * MyResultNumColumns
 * Returns the number of columns contained in the result set
 * ---------------------------------------------------------------------
 */
int 
MyResultNumColumns(SQLRESULT* result)
{
	return result->NumColumns;
}


/* ---------------------------------------------------------------------
 * MyResultColumnName
 * Return the name of the specified column
 * ---------------------------------------------------------------------
 */
const wchar_t* 
MyResultColumnName(SQLRESULT* result, int index)
{
	if ((index >= 0) && (index < result->NumColumns))
	{
		return (result->Columns[index]) ? result->Columns[index] : _T("");
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * MyResultColumnSize
 * Field size in the specified column
 * ---------------------------------------------------------------------
 */
int 
MyResultColumnSize(SQLRESULT* result, int index)
{
	if (result && result->Result && (index < result->NumColumns))
	{
		MYSQL_FIELD* field;
         
		field = mysql_fetch_field_direct(result->Result, index);
		return (field->length);
	}
	return 0;
}


/* ---------------------------------------------------------------------
 * MyResultFetch
 * Move the cursor to the next result tuple. Note that after a result
 * set is return, the cursor has to be moved with ResultFetch to the
 * first row.
 * ---------------------------------------------------------------------
 */
int 
MyResultFetch(SQLRESULT* result)
{
	if (result && result->Result)
	{
		if (result->RowIndex < (result->NumRows))
		{
			result->Row = mysql_fetch_row(result->Result);
			result->RowIndex++;

			if (result->Row)
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

					data = result->Row[index];
					if (data)
					{
						result->RowData[index] = ModuleMbToTCharDup(data);
					}
				}
			}
			return (result->Row != NULL);
		}
		else
		{
			result->Row = NULL;
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * MyResultData
 * Read the data from the result set.
 * ---------------------------------------------------------------------
 */
const wchar_t* 
MyResultData(SQLRESULT* result, int index)
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
 * MyResultIsNull
 * is column 'index' a NULL value?
 * ---------------------------------------------------------------------
 */
int 
MyResultIsNull(SQLRESULT* result, int index)
{
	if (result && result->Result && result->Row && (index < result->NumColumns))
	{
		return (result->Row[index] == NULL);
	}
	else
	{
		return FALSE;
	}
}


/* ---------------------------------------------------------------------
 * MyResultReset
 * Reset the data cursor. The next call to ResultFetch will address the
 * first row within the result set.
 * ---------------------------------------------------------------------
 */
void
MyResultReset(SQLRESULT* result)
{
	if (result && result->Result)
	{
		result->RowIndex = 0;
		mysql_data_seek(result->Result, 0);
	}
}


/* ---------------------------------------------------------------------
 * MyResultFree
 * Free the result set and all associated data
 * ---------------------------------------------------------------------
 */
void 
MyResultFree(SQLRESULT* result)
{
	if (result)
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
		if (result->Result)    mysql_free_result(result->Result);
		free(result);
	}
}

/* helper */

/* ---------------------------------------------------------------------
 * MyGetClientSocket
 * Try to read the name of the unix domain socket from my.cnf
 * ---------------------------------------------------------------------
 */
static const char*
MyGetClientSocket(void)
{
	static char socket[256];
	int success = FALSE;
	
	INI_T* ini = IniFileCreate();
	if (ini)
	{
		if (IniFileRead(ini, "/etc/my.cnf"))
		{
			INISECTION_T* sec = IniFileGetSection(ini, "client", IGNORE);
			if (sec)
			{
				const char* value = IniSectionGetValue(sec, "socket", NULL);
				if (value)
				{
					strncpy(socket, value, 255);
					socket[255] = 0;
					success = TRUE;
				}
			}
		}
		IniFileDelete(ini);
	}	
	if (success)
	{
		return socket;
	}
	else
	{
		return NULL;
	}
}
