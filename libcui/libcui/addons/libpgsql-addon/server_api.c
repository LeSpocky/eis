/* ---------------------------------------------------------------------
 * File: postgresql.c
 * (wrapper for postgresql client library)
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
extern StartFrameProc    LibPqStartFrame;
extern InsertStrProc     LibPqInsertStr;
extern InsertIntProc     LibPqInsertInt;
extern InsertLongProc    LibPqInsertLong;
extern SendFrameProc     LibPqSendFrame;
extern ExecFrameProc     LibPqExecFrame;
extern WriteErrorProc    LibPqWriteError;

extern StubCreateProc    LibPqStubCreate;
extern StubCheckStubProc LibPqStubCheck;
extern StubDeleteProc    LibPqStubDelete;
extern StubSetHookProc   LibPqStubSetHook;
extern StubSetProcProc   LibPqStubSetProc;
extern StubFindProc      LibPqStubFind;

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
static DBCONNECTION* PgApiCreateConnection(SQLCONNECT* connection);
static int           PgApiCheckConnection(SQLCONNECT* connection);
static int           PgApiDeleteConnection(SQLCONNECT* connection);
static DBRESULT    * PgApiCreateResult(SQLRESULT* result);
static int           PgApiCheckResult(SQLRESULT* result);
static int           PgApiDeleteResult(SQLRESULT* result);
static TCHAR*        PgApiSingleLineDup(const TCHAR* data);

/* ---------------------------------------------------------------------
 * PgApiInit
 * Initialize API
 * ---------------------------------------------------------------------
 */
void 
PgApiInit(void)
{
	Connections = NULL;
	ResultSets = NULL;
}

/* ---------------------------------------------------------------------
 * PgApiClear
 * Clear all open connections and result sets
 * ---------------------------------------------------------------------
 */
void 
PgApiClear(void)
{
	DBCONNECTION* conptr = Connections;
	DBRESULT*     resptr = ResultSets;

	while (resptr)
	{
		ResultSets = (DBRESULT*) resptr->Next;
		PgResultFree(resptr->Result);
		free(resptr);
		resptr = ResultSets;
	}

	while (conptr)
	{
		Connections = (DBCONNECTION*) conptr->Next;
		PgServerDisconnect(conptr->Connection);
		free(conptr);
		conptr = Connections;
	}
}


/* ---------------------------------------------------------------------
 * API functions
 * ---------------------------------------------------------------------
 */ 
/* ---------------------------------------------------------------------
 * PgApiServerConnection
 * Establish a server connection
 * ---------------------------------------------------------------------
 */ 
void 
PgApiServerConnect(int argc, const TCHAR* argv[])
{
	if (argc == 5)
	{
		SQLCONNECT* nc = PgServerConnect(
			argv[0], argv[1], argv[2], argv[3], argv[4]);
		if (nc)
		{
			PgApiCreateConnection(nc);
		}
		LibPqStartFrame(_T('R'), 48);
		LibPqInsertInt (ERROR_SUCCESS);
		LibPqInsertLong((unsigned long) nc);
		LibPqSendFrame ();
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerDisconnect
 * Close a server connection
 * ---------------------------------------------------------------------
 */ 
void 
PgApiServerDisconnect(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiDeleteConnection((SQLCONNECT*)connr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerIsConnected
 * Check if server connection is established
 * ---------------------------------------------------------------------
 */
void 
PgApiServerIsConnected(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			LibPqStartFrame(_T('R'), 48);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgServerIsConnected((SQLCONNECT*)connr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerGetError
 * Get error message
 * ---------------------------------------------------------------------
 */
void 
PgApiServerGetError(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			const TCHAR* str = PgServerGetError((SQLCONNECT*)connr);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}

}

/* ---------------------------------------------------------------------
 * PgApiServerPasswd
 * Get password of this connection  
 * ---------------------------------------------------------------------
 */
void 
PgApiServerPasswd(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			const TCHAR* str = PgServerPasswd((SQLCONNECT*)connr);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerUser
 * Get user of this connection  
 * ---------------------------------------------------------------------
 */
void 
PgApiServerUser(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			const TCHAR* str = PgServerPasswd((SQLCONNECT*)connr);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerUser    
 * Get host of this connection  
 * ---------------------------------------------------------------------
 */
void 
PgApiServerHost(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			const TCHAR* str = PgServerPasswd((SQLCONNECT*)connr);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerPort
 * Get port of this connection  
 * ---------------------------------------------------------------------
 */
void 
PgApiServerPort(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			const TCHAR* str = PgServerPort((SQLCONNECT*)connr);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerDupTo
 * Duplicate connection
 * ---------------------------------------------------------------------
 */
void 
PgApiServerDupTo(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			SQLCONNECT* nc = PgServerDupTo((SQLCONNECT*)connr, argv[0]);
			if (nc)
			{
				PgApiCreateConnection(nc);
			}
			LibPqStartFrame(_T('R'), 48);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertLong((unsigned long) nc);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiQuerySQL
 * Execute a query
 * ---------------------------------------------------------------------
 */
void 
PgApiQuerySQL(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			SQLRESULT* nr = PgQuerySQL((SQLCONNECT*)connr, argv[1]);
			if (nr)
			{
				PgApiCreateResult(nr);
			}
			LibPqStartFrame(_T('R'), 48);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertLong((unsigned long) nr);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiExecSQL
 * Execute a SQL command
 * ---------------------------------------------------------------------
 */
void 
PgApiExecSQL(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long connr;

		stscanf(argv[0], _T("%ld"), &connr);

		if (PgApiCheckConnection((SQLCONNECT*)connr))
		{
			LibPqStartFrame(_T('R'), 48);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgExecSQL((SQLCONNECT*)connr, argv[1]));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerDefault
 * Return default connection
 * ---------------------------------------------------------------------
 */
void 
PgApiServerDefault(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		SQLCONNECT* nc = PgServerDefault();

		LibPqStartFrame(_T('R'), 48);
		LibPqInsertInt (ERROR_SUCCESS);
		LibPqInsertLong((unsigned long) nc);
		LibPqSendFrame ();
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiServerStatus
 * Return result status
 * ---------------------------------------------------------------------
 */
void 
PgApiResultStatus(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 38);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt ((int) PgResultStatus((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultNumRows
 * Return result status
 * ---------------------------------------------------------------------
 */
void 
PgApiResultNumRows(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultNumRows((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultNumColumns
 * Return number of columns
 * ---------------------------------------------------------------------
 */
void 
PgApiResultNumColumns(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultNumColumns((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultColumnName
 * Return name of column
 * ---------------------------------------------------------------------
 */
void 
PgApiResultColumnName(int argc, const TCHAR* argv[])

{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		stscanf(argv[0], _T("%ld"), &resnr);
		stscanf(argv[1], _T("%d"),  &index);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			const TCHAR* str = PgResultColumnName((SQLRESULT*)resnr, index);

			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultColumnSize
 * Return size of column
 * ---------------------------------------------------------------------
 */
void 
PgApiResultColumnSize(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &resnr);
		stscanf(argv[1], _T("%d"), &index);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultColumnSize((SQLRESULT*)resnr, index));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultFetch
 * Fetch next result line
 * ---------------------------------------------------------------------
 */
void 
PgApiResultFetch(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultNext((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PgApiResultFirst
 * Fetch first result line
 * ---------------------------------------------------------------------
 */
void
PgApiResultFirst(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultFirst((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PgApiResultPrevious
 * Fetch previous result line
 * ---------------------------------------------------------------------
 */
void
PgApiResultPrevious(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultPrevious((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PgApiResultLast
 * Fetch last result line
 * ---------------------------------------------------------------------
 */
void
PgApiResultLast(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultLast((SQLRESULT*)resnr));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PgApiResultData 
 * Get column data
 * ---------------------------------------------------------------------
 */
void 
PgApiResultData(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		stscanf(argv[0], _T("%ld"), &resnr);
		stscanf(argv[1], _T("%d"), &index);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			const TCHAR* str = PgResultData((SQLRESULT*)resnr, index);
			
			LibPqStartFrame(_T('R'), 32 + tcslen(str) * sizeof(TCHAR));
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertStr (str);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultIsNull
 * Check if result in column 'index' is NULL
 * ---------------------------------------------------------------------
 */
void 
PgApiResultIsNull(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		unsigned long resnr;
		int index;

		stscanf(argv[0], _T("%ld"), &resnr);
		stscanf(argv[1], _T("%d"), &index);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			LibPqStartFrame(_T('R'), 48);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqInsertInt (PgResultIsNull((SQLRESULT*)resnr, index));
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultReset
 * Return cursor to the top of the result set
 * ---------------------------------------------------------------------
 */
void 
PgApiResultReset(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiCheckResult((SQLRESULT*)resnr))
		{
			PgResultReset((SQLRESULT*)resnr);

			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * PgApiResultFree
 * Free the result set
 * ---------------------------------------------------------------------
 */  
void 
PgApiResultFree(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		unsigned long resnr;

		stscanf(argv[0], _T("%ld"), &resnr);

		if (PgApiDeleteResult((SQLRESULT*) resnr))
		{
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PgApiResultFree
 * Copy result set to listview window
 * ---------------------------------------------------------------------
 */  
void 
PgApiResultToList(int argc, const TCHAR* argv[])
{
	if (argc >= 2)
	{
		WINDOWSTUB*   listview;
		SQLRESULT*    result;
		unsigned long tmplong;
		int           selindex = 0;
		int           keycolumn = -1;
		const TCHAR*  keyword = _T("");

		stscanf(argv[0], _T("%ld"), &tmplong);
		result = (SQLRESULT*) tmplong;
		
		stscanf(argv[1], _T("%ld"), &tmplong);
		listview = LibPqStubFind(tmplong);
		
		if (argc >= 3)
		{
			stscanf(argv[2], _T("%d"), &keycolumn);
		}
		if (argc >= 4)
		{
			keyword = argv[3];
		}
		
		if (listview && listview->Window && result)
		{
			int cols = PgResultNumColumns(result);
			int i;
			int index;
			
			while (PgResultNext(result))
			{
				LISTREC* rec = ListviewCreateRecord (listview->Window);
				if (rec)
				{
					int matched = FALSE;
					
					for (i = 0; i < cols; i++)
					{
						if (!PgResultIsNull(result, i))
						{
							TCHAR* data;
							
							data  = PgApiSingleLineDup(PgResultData(result, i));
							if (data)
							{
								ListviewSetColumnText(rec, i, data);
							
								if ((i == keycolumn) && (tcscmp(data, keyword) == 0))
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
			
			LibPqStartFrame(_T('R'), 32);
			LibPqInsertInt (ERROR_SUCCESS);
			LibPqSendFrame ();
		}
		else
		{
			LibPqWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * Helper functions
 * ---------------------------------------------------------------------
 */  
/* ---------------------------------------------------------------------
 * PgApiCreateConnection
 * Create a connection structure
 * ---------------------------------------------------------------------
 */  
static DBCONNECTION*
PgApiCreateConnection(SQLCONNECT* connection)
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
 * PgApiCheckConnection
 * Check if connection points to a valid connection
 * ---------------------------------------------------------------------
 */  
static int
PgApiCheckConnection(SQLCONNECT* connection)
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
 * PgApiDeleteConnection
 * Free a connection if it exists
 * ---------------------------------------------------------------------
 */ 
static int
PgApiDeleteConnection(SQLCONNECT* connection)
{
	DBCONNECTION* conptr = Connections;
	DBCONNECTION* oldptr = NULL;
	while (conptr)
	{
		if (conptr->Connection == connection)
		{
			PgServerDisconnect(conptr->Connection);
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
 * PgApiCreateResult
 * Create a result structure
 * ---------------------------------------------------------------------
 */ 
static DBRESULT* 
PgApiCreateResult(SQLRESULT* result)
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
 * PgApiCheckResult
 * Check if the result really exists
 * ---------------------------------------------------------------------
 */ 
static int 
PgApiCheckResult(SQLRESULT* result)
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
 * PgApiDeleteResult
 * Delete a result structure and free the result set
 * ---------------------------------------------------------------------
 */ 
static int 
PgApiDeleteResult(SQLRESULT* result)
{
	DBRESULT* resptr = ResultSets;
	DBRESULT* oldptr = NULL;
	while (resptr)
	{
		if (resptr->Result == result)
		{
			PgResultFree(resptr->Result);
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
 * PgApiSingleLineDup
 * the text in data is duplicated but characters like \n, \r and \t are
 * removed
 * ---------------------------------------------------------------------
 */ 
static TCHAR* 
PgApiSingleLineDup(const TCHAR* data)
{
	TCHAR* line = (TCHAR*) malloc((tcslen(data) + 1) * sizeof(TCHAR));
	if (line)
	{
		TCHAR* l = line;
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
