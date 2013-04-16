/* ---------------------------------------------------------------------
 * File: server_api.c
 * (wrapper for mysql client library)
 *
 * Copyright (C) 2008
 * Daniel Vogel, <daniel_vogel@t-online.de>
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
 */
extern StartFrameProc    LibMyStartFrame;
extern InsertStrProc     LibMyInsertStr;
extern InsertIntProc     LibMyInsertInt;
extern InsertLongProc    LibMyInsertLong;
extern SendFrameProc     LibMySendFrame;
extern ExecFrameProc     LibMyExecFrame;
extern WriteErrorProc    LibMyWriteError;

extern StubCreateProc    LibMyStubCreate;
extern StubCheckStubProc LibMyStubCheck;
extern StubDeleteProc    LibMyStubDelete;
extern StubSetHookProc   LibMyStubSetHook;
extern StubSetProcProc   LibMyStubSetProc;
extern StubFindProc      LibMyStubFind;

/* ---------------------------------------------------------------------
 * local types
 * ---------------------------------------------------------------------
 */
typedef struct
{
	SQLCONNECT* Connection;
	void*       Next;
} DBCONNECTION;

typedef struct
{
	SQLRESULT*  Result;
	void*       Next;
} DBRESULT;


/* ---------------------------------------------------------------------
 * local varaibles
 * ---------------------------------------------------------------------
 */
static DBCONNECTION* Connections = NULL;
static DBRESULT*     ResultSets  = NULL;


/* ---------------------------------------------------------------------
 * local prototypes
 * ---------------------------------------------------------------------
 */
static DBCONNECTION* MyApiCreateConnection(SQLCONNECT* connection);
static int           MyApiCheckConnection(SQLCONNECT* connection);
static int           MyApiDeleteConnection(SQLCONNECT* connection);
static DBRESULT    * MyApiCreateResult(SQLRESULT* result);
static int           MyApiCheckResult(SQLRESULT* result);
static int           MyApiDeleteResult(SQLRESULT* result);
static wchar_t*        MyApiSingleLineDup(const wchar_t* data);


/* ---------------------------------------------------------------------
 * MyApiInit
 * Initialize API
 * ---------------------------------------------------------------------
 */
void 
MyApiInit(void)
{
	Connections = NULL;
	ResultSets = NULL;
}

/* ---------------------------------------------------------------------
 * MyApiClear
 * Clear all open connections and result sets
 * ---------------------------------------------------------------------
 */
void 
MyApiClear(void)
{
	DBCONNECTION* conptr = Connections;
	DBRESULT*     resptr = ResultSets;

	while (resptr)
	{
		ResultSets = (DBRESULT*) resptr->Next;
		MyResultFree(resptr->Result);
		free(resptr);
		resptr = ResultSets;
	}

	while (conptr)
	{
		Connections = (DBCONNECTION*) conptr->Next;
		MyServerDisconnect(conptr->Connection);
		free(conptr);
		conptr = Connections;
	}
}


/* ---------------------------------------------------------------------
 * API functions
 * ---------------------------------------------------------------------
 */ 
/* ---------------------------------------------------------------------
 * MyApiServerConnection
 * Establish a server connection
 * ---------------------------------------------------------------------
 */ 
void 
MyApiServerConnect(int argc, const wchar_t* argv[])
{
	if (argc == 5)
	{
		SQLCONNECT* nc = MyServerConnect(
			argv[0], argv[1], argv[2], argv[3], argv[4]);
		if (nc)
		{
			MyApiCreateConnection(nc);
		}
		LibMyStartFrame(_T('R'), 48);
		LibMyInsertInt (ERROR_SUCCESS);
		LibMyInsertLong((unsigned long) nc);
		LibMySendFrame ();
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerDisconnect
 * Close a server connection
 * ---------------------------------------------------------------------
 */ 
void 
MyApiServerDisconnect(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiDeleteConnection((SQLCONNECT*)connr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerIsConnected
 * Check if server connection is established
 * ---------------------------------------------------------------------
 */
void 
MyApiServerIsConnected(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			LibMyStartFrame(_T('R'), 48);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyServerIsConnected((SQLCONNECT*)connr));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerGetError
 * Get error message
 * ---------------------------------------------------------------------
 */
void 
MyApiServerGetError(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			const wchar_t* str = MyServerGetError((SQLCONNECT*)connr);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}

}

/* ---------------------------------------------------------------------
 * MyApiServerPasswd
 * Get password of this connection  
 * ---------------------------------------------------------------------
 */
void 
MyApiServerPasswd(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			const wchar_t* str = MyServerPasswd((SQLCONNECT*)connr);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerUser
 * Get user of this connection  
 * ---------------------------------------------------------------------
 */
void 
MyApiServerUser(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			const wchar_t* str = MyServerPasswd((SQLCONNECT*)connr);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerUser    
 * Get host of this connection  
 * ---------------------------------------------------------------------
 */
void 
MyApiServerHost(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			const wchar_t* str = MyServerPasswd((SQLCONNECT*)connr);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerPort
 * Get port of this connection  
 * ---------------------------------------------------------------------
 */
void 
MyApiServerPort(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			const wchar_t* str = MyServerPort((SQLCONNECT*)connr);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerDupTo
 * Duplicate connection
 * ---------------------------------------------------------------------
 */
void 
MyApiServerDupTo(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			SQLCONNECT* nc = MyServerDupTo((SQLCONNECT*)connr, argv[0]);
			if (nc)
			{
				MyApiCreateConnection(nc);
			}
			LibMyStartFrame(_T('R'), 48);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertLong((unsigned long) nc);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiQuerySQL
 * Execute a query
 * ---------------------------------------------------------------------
 */
void 
MyApiQuerySQL(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			SQLRESULT* nr = MyQuerySQL((SQLCONNECT*)connr, argv[1]);
			if (nr)
			{
				MyApiCreateResult(nr);
			}
			LibMyStartFrame(_T('R'), 48);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertLong((unsigned long) nr);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiExecSQL
 * Execute a SQL command
 * ---------------------------------------------------------------------
 */
void 
MyApiExecSQL(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		swscanf(argv[0], _T("%ld"), &connr);

		if (MyApiCheckConnection((SQLCONNECT*)connr))
		{
			LibMyStartFrame(_T('R'), 48);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyExecSQL((SQLCONNECT*)connr, argv[1]));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerDefault
 * Return default connection
 * ---------------------------------------------------------------------
 */
void 
MyApiServerDefault(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);
	
	if (argc == 0)
	{
		SQLCONNECT* nc = MyServerDefault();

		LibMyStartFrame(_T('R'), 48);
		LibMyInsertInt (ERROR_SUCCESS);
		LibMyInsertLong((unsigned long) nc);
		LibMySendFrame ();
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiServerStatus
 * Return result status
 * ---------------------------------------------------------------------
 */
void 
MyApiResultStatus(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 38);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt ((int) MyResultStatus((SQLRESULT*)resnr));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultNumRows
 * Return result status
 * ---------------------------------------------------------------------
 */
void 
MyApiResultNumRows(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyResultNumRows((SQLRESULT*)resnr));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultNumColumns
 * Return number of columns
 * ---------------------------------------------------------------------
 */
void 
MyApiResultNumColumns(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyResultNumColumns((SQLRESULT*)resnr));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultColumnName
 * Return name of column
 * ---------------------------------------------------------------------
 */
void 
MyApiResultColumnName(int argc, const wchar_t* argv[])

{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		swscanf(argv[0], _T("%ld"), &resnr);
		swscanf(argv[1], _T("%d"),  &index);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			const wchar_t* str = MyResultColumnName((SQLRESULT*)resnr, index);

			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultColumnSize
 * Return size of column
 * ---------------------------------------------------------------------
 */
void 
MyApiResultColumnSize(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int           index;

		swscanf(argv[0], _T("%ld"), &resnr);
		swscanf(argv[1], _T("%d"), &index);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyResultColumnSize((SQLRESULT*)resnr, index));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultFetch
 * Fetch next result line
 * ---------------------------------------------------------------------
 */
void 
MyApiResultFetch(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyResultFetch((SQLRESULT*)resnr));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultData 
 * Get column data
 * ---------------------------------------------------------------------
 */
void 
MyApiResultData(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		swscanf(argv[0], _T("%ld"), &resnr);
		swscanf(argv[1], _T("%d"), &index);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			const wchar_t* str = MyResultData((SQLRESULT*)resnr, index);
			
			LibMyStartFrame(_T('R'), 32 + wcslen(str) * sizeof(wchar_t));
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertStr (str);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultIsNull
 * Check if result in column 'index' is NULL
 * ---------------------------------------------------------------------
 */
void 
MyApiResultIsNull(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		swscanf(argv[0], _T("%ld"), &resnr);
		swscanf(argv[1], _T("%d"), &index);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			LibMyStartFrame(_T('R'), 48);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMyInsertInt (MyResultIsNull((SQLRESULT*)resnr, index));
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultReset
 * Return cursor to the top of the result set
 * ---------------------------------------------------------------------
 */
void 
MyApiResultReset(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiCheckResult((SQLRESULT*)resnr))
		{
			MyResultReset((SQLRESULT*)resnr);

			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * MyApiResultFree
 * Free the result set
 * ---------------------------------------------------------------------
 */  
void 
MyApiResultFree(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		swscanf(argv[0], _T("%ld"), &resnr);

		if (MyApiDeleteResult((SQLRESULT*) resnr))
		{
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * MyApiResultFree
 * Copy result set to listview window
 * ---------------------------------------------------------------------
 */  
void 
MyApiResultToList(int argc, const wchar_t* argv[])
{
	if (argc >= 2)
	{
		WINDOWSTUB*   listview;
		SQLRESULT*    result;
		unsigned long tmplong;
		int           selindex = 0;
		int           keycolumn = -1;
		const wchar_t*  keyword = _T("");

		swscanf(argv[0], _T("%ld"), &tmplong);
		result = (SQLRESULT*) tmplong;
		
		swscanf(argv[1], _T("%ld"), &tmplong);
		listview = LibMyStubFind(tmplong);
		
		if (argc >= 3)
		{
			swscanf(argv[2], _T("%d"), &keycolumn);
		}
		if (argc >= 4)
		{
			keyword = argv[3];
		}
		
		if (listview && listview->Window && result)
		{
			int cols = MyResultNumColumns(result);
			int i;
			int index;
			
			while (MyResultFetch(result))
			{
				LISTREC* rec = ListviewCreateRecord (listview->Window);
				if (rec)
				{
					int matched = FALSE;
					
					for (i = 0; i < cols; i++)
					{
						if (!MyResultIsNull(result, i))
						{
							wchar_t* data;
							
							data  = MyApiSingleLineDup(MyResultData(result, i));
							if (data)
							{
								ListviewSetColumnText(rec, i, data);
							
								if ((i == keycolumn) && (wcscmp(data, keyword) == 0))
								{
									matched = TRUE;
								}
								free(data);
							}
						}
					}
					index = ListviewInsertRecord(listview->Window, rec);
					if (matched)
					{
						selindex = index;
					}
				}
			}
			
			ListviewSetSel(listview->Window, selindex);
			
			LibMyStartFrame(_T('R'), 32);
			LibMyInsertInt (ERROR_SUCCESS);
			LibMySendFrame ();
		}
		else
		{
			LibMyWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibMyWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * Helper functions
 * ---------------------------------------------------------------------
 */  
/* ---------------------------------------------------------------------
 * MyApiCreateConnection
 * Create a connection structure
 * ---------------------------------------------------------------------
 */  
static DBCONNECTION*
MyApiCreateConnection(SQLCONNECT* connection)
{
	DBCONNECTION* newcon = (DBCONNECTION*) malloc(sizeof(DBCONNECTION));
	if (newcon)
	{
		newcon->Connection = connection;
		newcon->Next = Connections;
		Connections = newcon;
	}
	return newcon;
}

/* ---------------------------------------------------------------------
 * MyApiCheckConnection
 * Check if connection points to a valid connection
 * ---------------------------------------------------------------------
 */  
static int
MyApiCheckConnection(SQLCONNECT* connection)
{
	DBCONNECTION* conptr = Connections;
	while (conptr)
	{
		if (conptr->Connection == connection)
		{
			return TRUE;
		}
		conptr = (DBCONNECTION*) conptr->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MyApiDeleteConnection
 * Free a connection if it exists
 * ---------------------------------------------------------------------
 */ 
static int
MyApiDeleteConnection(SQLCONNECT* connection)
{
	DBCONNECTION* conptr = Connections;
	DBCONNECTION* oldptr = NULL;
	while (conptr)
	{
		if (conptr->Connection == connection)
		{
			MyServerDisconnect(conptr->Connection);
			if (oldptr)
			{
				oldptr->Next = conptr->Next;
			}
			else
			{
				Connections = conptr->Next;
			}
			free(conptr);
			return TRUE;
		}
		oldptr = conptr;
		conptr = (DBCONNECTION*) conptr->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MyApiCreateResult
 * Create a result structure
 * ---------------------------------------------------------------------
 */ 
static DBRESULT* 
MyApiCreateResult(SQLRESULT* result)
{
	DBRESULT* newres = (DBRESULT*) malloc(sizeof(DBRESULT));
	if (newres)
	{
		newres->Result = result;
		newres->Next = ResultSets;
		ResultSets = newres;
	}
	return newres;
}

/* ---------------------------------------------------------------------
 * MyApiCheckResult
 * Check if the result really exists
 * ---------------------------------------------------------------------
 */ 
static int 
MyApiCheckResult(SQLRESULT* result)
{
	DBRESULT* resptr = ResultSets;
	while (resptr)
	{
		if (resptr->Result == result)
		{
			return TRUE;
		}
		resptr = (DBRESULT*) resptr->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MyApiDeleteResult
 * Delete a result structure and free the result set
 * ---------------------------------------------------------------------
 */ 
static int 
MyApiDeleteResult(SQLRESULT* result)
{
	DBRESULT* resptr = ResultSets;
	DBRESULT* oldptr = NULL;
	while (resptr)
	{
		if (resptr->Result == result)
		{
			MyResultFree(resptr->Result);
			if (oldptr)
			{
				oldptr->Next = resptr->Next;
			}
			else
			{
				ResultSets = resptr->Next;
			}
			free(resptr);
			return TRUE;
		}
		oldptr = resptr;
		resptr = (DBRESULT*) resptr->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MyApiSingleLineDup
 * the text in data is duplicated but characters like \n, \r and \t are
 * removed
 * ---------------------------------------------------------------------
 */ 
static wchar_t* 
MyApiSingleLineDup(const wchar_t* data)
{
	wchar_t* line = (wchar_t*) malloc((wcslen(data) + 1) * sizeof(wchar_t));
	if (line)
	{
		wchar_t* l = line;
		while (*data != _T('\0'))
		{
			switch(*data)
			{
			case '\n':
			case '\t':
				*(l++) = _T(' ');
				break;
			case '\r':
				break;
			default:
				*(l++) = *data;
			}
			data++;
		}
		*l = _T('\0');
		return line;
	}
	return _T("");
}
