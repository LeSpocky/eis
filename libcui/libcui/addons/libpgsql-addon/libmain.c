/* ---------------------------------------------------------------------
 * File: libmain.c
 * (main file of cui script module)
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
#include <libpq-fe.h>
#include "server_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#define API_TESTFUNCTION 100

StartFrameProc    LibPqStartFrame;
InsertStrProc     LibPqInsertStr;
InsertIntProc     LibPqInsertInt;
InsertLongProc    LibPqInsertLong;
SendFrameProc     LibPqSendFrame;
ExecFrameProc     LibPqExecFrame;
WriteErrorProc    LibPqWriteError;

StubCreateProc    LibPqStubCreate;
StubCheckStubProc LibPqStubCheck;
StubDeleteProc    LibPqStubDelete;
StubSetHookProc   LibPqStubSetHook;
StubSetProcProc   LibPqStubSetProc;
StubFindProc      LibPqStubFind;

void
Testfunc(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		int    a, b;

		stscanf(argv[0], _T("%d"), &a);
		stscanf(argv[1], _T("%d"), &b);

		LibPqStartFrame(_T('R'), 32);
		LibPqInsertInt (ERROR_SUCCESS);
		LibPqInsertInt (a + b);
		LibPqSendFrame ();
	}
	else
	{
		LibPqWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ModuleInit
 * Initialize module
 * ---------------------------------------------------------------------
 */
int
ModuleInit(MODULEINIT_T* modinit)
{
	LibPqStartFrame  = modinit->StartFrame;
	LibPqInsertStr   = modinit->InsertStr;
	LibPqInsertInt   = modinit->InsertInt;
	LibPqInsertLong  = modinit->InsertLong;
	LibPqSendFrame   = modinit->SendFrame;
	LibPqExecFrame   = modinit->ExecFrame;
	LibPqWriteError  = modinit->WriteError;
	
	LibPqStubCreate  = modinit->StubCreate;
	LibPqStubCheck   = modinit->StubCheck;
	LibPqStubDelete  = modinit->StubDelete;
	LibPqStubSetHook = modinit->StubSetHook;
	LibPqStubSetProc = modinit->StubSetProc;
	LibPqStubFind    = modinit->StubFind;
	
	PgApiInit();
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ModuleExecFunction
 * Execute the function that corresponds to the function number passed
 * in func_nr.
 * ---------------------------------------------------------------------
 */
int
ModuleExecFunction(int func_nr, int argc, const TCHAR* argv[])
{
	switch (func_nr)
	{
	case PG_API_SERVERCONNECT:
		PgApiServerConnect(argc, argv);
		return TRUE;
	case PG_API_SERVERDISCONNECT:
		PgApiServerDisconnect(argc, argv);
		return TRUE;
	case PG_API_SERVERISCONNECTED:
		PgApiServerIsConnected(argc, argv);
		return TRUE;
	case PG_API_SERVERGETERROR:
		PgApiServerGetError(argc, argv);
		return TRUE;
	case PG_API_SERVERPASSWD:
		PgApiServerPasswd(argc, argv);
		return TRUE;
	case PG_API_SERVERUSER:
		PgApiServerUser(argc, argv);
		return TRUE;
	case PG_API_SERVERHOST:
		PgApiServerHost(argc, argv);
		return TRUE;
	case PG_API_SERVERPORT:
		PgApiServerPort(argc, argv);
		return TRUE;
	case PG_API_SERVERDUPTO:
		PgApiServerDupTo(argc, argv);
		return TRUE;
	case PG_API_QUERYSQL:
		PgApiQuerySQL(argc, argv);
		return TRUE;
	case PG_API_EXECSQL:
		PgApiExecSQL(argc, argv);
		return TRUE;
	case PG_API_SERVERDEFAULT:
		PgApiServerDefault(argc, argv);
		return TRUE;
	case PG_API_RESULTSTATUS:
		PgApiResultStatus(argc, argv);
		return TRUE;
	case PG_API_RESULTNUMROWS:
		PgApiResultNumRows(argc, argv);
		return TRUE;
	case PG_API_RESULTNUMCOLUMNS:
		PgApiResultNumColumns(argc, argv);
		return TRUE;
	case PG_API_RESULTCOLUMNNAME:
		PgApiResultColumnName(argc, argv);
		return TRUE;
	case PG_API_RESULTCOLUMNSIZE:
		PgApiResultColumnSize(argc, argv);
		return TRUE;
	case PG_API_RESULTFETCH:
		PgApiResultFetch(argc, argv);
		return TRUE;
	case PG_API_RESULTFIRST:
		PgApiResultFirst(argc, argv);
		return TRUE;
	case PG_API_RESULTPREVIOUS:
		PgApiResultPrevious(argc, argv);
		return TRUE;
	case PG_API_RESULTNEXT:
		PgApiResultFetch(argc, argv);
		return TRUE;
	case PG_API_RESULTLAST:
		PgApiResultLast(argc, argv);
		return TRUE;
	case PG_API_RESULTDATA:
		PgApiResultData(argc, argv);
		return TRUE;
	case PG_API_RESULTISNULL:
		PgApiResultIsNull(argc, argv);
		return TRUE;
	case PG_API_RESULTRESET:
		PgApiResultReset(argc, argv);
		return TRUE;
	case PG_API_RESULTFREE:
		PgApiResultFree(argc, argv);
		return TRUE;
	case PG_API_RESULTTOLIST:
		PgApiResultToList(argc, argv);
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ModuleClose
 * Free all data associated to this module
 * ---------------------------------------------------------------------
 */
int
ModuleClose(void)
{
	PgApiClear();
	return TRUE;
}

