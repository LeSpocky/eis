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
#include "server_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#define API_TESTFUNCTION 100

StartFrameProc    LibMyStartFrame;
InsertStrProc     LibMyInsertStr;
InsertIntProc     LibMyInsertInt;
InsertLongProc    LibMyInsertLong;
SendFrameProc     LibMySendFrame;
ExecFrameProc     LibMyExecFrame;
WriteErrorProc    LibMyWriteError;

StubCreateProc    LibMyStubCreate;
StubCheckStubProc LibMyStubCheck;
StubDeleteProc    LibMyStubDelete;
StubSetHookProc   LibMyStubSetHook;
StubSetProcProc   LibMyStubSetProc;
StubFindProc      LibMyStubFind;


/* ---------------------------------------------------------------------
 * ModuleInit
 * Initialize module
 * ---------------------------------------------------------------------
 */
int
ModuleInit(MODULEINIT_T* modinit)
{
	LibMyStartFrame  = modinit->StartFrame;
	LibMyInsertStr   = modinit->InsertStr;
	LibMyInsertInt   = modinit->InsertInt;
	LibMyInsertLong  = modinit->InsertLong;
	LibMySendFrame   = modinit->SendFrame;
	LibMyExecFrame   = modinit->ExecFrame;
	LibMyWriteError  = modinit->WriteError;
	
	LibMyStubCreate  = modinit->StubCreate;
	LibMyStubCheck   = modinit->StubCheck;
	LibMyStubDelete  = modinit->StubDelete;
	LibMyStubSetHook = modinit->StubSetHook;
	LibMyStubSetProc = modinit->StubSetProc;
	LibMyStubFind    = modinit->StubFind;

	MyApiInit();
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ModuleExecFunction
 * Execute the function that corresponds to the function number passed
 * in func_nr.
 * ---------------------------------------------------------------------
 */
int
ModuleExecFunction(int func_nr, int argc, const wchar_t* argv[])
{
	switch (func_nr)
	{
	case MY_API_SERVERCONNECT:
		MyApiServerConnect(argc, argv);
		return TRUE;
	case MY_API_SERVERDISCONNECT:
		MyApiServerDisconnect(argc, argv);
		return TRUE;
	case MY_API_SERVERISCONNECTED:
		MyApiServerIsConnected(argc, argv);
		return TRUE;
	case MY_API_SERVERGETERROR:
		MyApiServerGetError(argc, argv);
		return TRUE;
	case MY_API_SERVERPASSWD:
		MyApiServerPasswd(argc, argv);
		return TRUE;
	case MY_API_SERVERUSER:
		MyApiServerUser(argc, argv);
		return TRUE;
	case MY_API_SERVERHOST:
		MyApiServerHost(argc, argv);
		return TRUE;
	case MY_API_SERVERPORT:
		MyApiServerPort(argc, argv);
		return TRUE;
	case MY_API_SERVERDUPTO:
		MyApiServerDupTo(argc, argv);
		return TRUE;
	case MY_API_QUERYSQL:
		MyApiQuerySQL(argc, argv);
		return TRUE;
	case MY_API_EXECSQL:
		MyApiExecSQL(argc, argv);
		return TRUE;
	case MY_API_SERVERDEFAULT:
		MyApiServerDefault(argc, argv);
		return TRUE;
	case MY_API_RESULTSTATUS:
		MyApiResultStatus(argc, argv);
		return TRUE;
	case MY_API_RESULTNUMROWS:
		MyApiResultNumRows(argc, argv);
		return TRUE;
	case MY_API_RESULTNUMCOLUMNS:
		MyApiResultNumColumns(argc, argv);
		return TRUE;
	case MY_API_RESULTCOLUMNNAME:
		MyApiResultColumnName(argc, argv);
		return TRUE;
	case MY_API_RESULTCOLUMNSIZE:
		MyApiResultColumnSize(argc, argv);
		return TRUE;
	case MY_API_RESULTFETCH:
		MyApiResultFetch(argc, argv);
		return TRUE;
	case MY_API_RESULTDATA:
		MyApiResultData(argc, argv);
		return TRUE;
	case MY_API_RESULTISNULL:
		MyApiResultIsNull(argc, argv);
		return TRUE;
	case MY_API_RESULTRESET:
		MyApiResultReset(argc, argv);
		return TRUE;
	case MY_API_RESULTFREE:
		MyApiResultFree(argc, argv);
		return TRUE;
	case MY_API_RESULTTOLIST:
		MyApiResultToList(argc, argv);
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
	MyApiClear();
	return TRUE;
}

