/* ---------------------------------------------------------------------
 * File: libmain.c
 * (main file of cui script module)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel@eisfair.org>
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
#include "system_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

StartFrameProc    LibSysStartFrame;
InsertStrProc     LibSysInsertStr;
InsertIntProc     LibSysInsertInt;
InsertLongProc    LibSysInsertLong;
SendFrameProc     LibSysSendFrame;
ExecFrameProc     LibSysExecFrame;
WriteErrorProc    LibSysWriteError;

StubCreateProc    LibSysStubCreate;
StubCheckStubProc LibSysStubCheck;
StubDeleteProc    LibSysStubDelete;
StubSetHookProc   LibSysStubSetHook;
StubSetProcProc   LibSysStubSetProc;
StubFindProc      LibSysStubFind;


/* ---------------------------------------------------------------------
 * ModuleInit
 * Initialize module
 * ---------------------------------------------------------------------
 */
int
ModuleInit(MODULEINIT_T* modinit)
{
	LibSysStartFrame  = modinit->StartFrame;
	LibSysInsertStr   = modinit->InsertStr;
	LibSysInsertInt   = modinit->InsertInt;
	LibSysInsertLong  = modinit->InsertLong;
	LibSysSendFrame   = modinit->SendFrame;
	LibSysExecFrame   = modinit->ExecFrame;
	LibSysWriteError  = modinit->WriteError;
	
	LibSysStubCreate  = modinit->StubCreate;
	LibSysStubCheck   = modinit->StubCheck;
	LibSysStubDelete  = modinit->StubDelete;
	LibSysStubSetHook = modinit->StubSetHook;
	LibSysStubSetProc = modinit->StubSetProc;
	LibSysStubFind    = modinit->StubFind;
	
	SysApiInit();
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
	case SYS_API_USERSTOLIST:
		SysApiUsersToList(argc, argv);
		return TRUE;
	case SYS_API_GROUPSTOLIST:
		SysApiGroupsToList(argc, argv);
		return TRUE;
	case SYS_API_GROUPMEMBERSELECTION:
		SysApiGroupMemberSelection(argc, argv);
		return TRUE;
	case SYS_API_SETGROUPMEMBERS:
		SysApiSetGroupMembers(argc, argv);
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
	SysApiClear();
	return TRUE;
}

