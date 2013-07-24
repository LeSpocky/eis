/* ---------------------------------------------------------------------
 * File: system_api.c
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
#include "chartools.h"
#include "system_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

/* ---------------------------------------------------------------------
 * global data
 * ---------------------------------------------------------------------
 */
extern StartFrameProc    LibSysStartFrame;
extern InsertStrProc     LibSysInsertStr;
extern InsertIntProc     LibSysInsertInt;
extern InsertLongProc    LibSysInsertLong;
extern SendFrameProc     LibSysSendFrame;
extern ExecFrameProc     LibSysExecFrame;
extern WriteErrorProc    LibSysWriteError;

extern StubCreateProc    LibSysStubCreate;
extern StubCheckStubProc LibSysStubCheck;
extern StubDeleteProc    LibSysStubDelete;
extern StubSetHookProc   LibSysStubSetHook;
extern StubSetProcProc   LibSysStubSetProc;
extern StubFindProc      LibSysStubFind;



/* ---------------------------------------------------------------------
 * local prototypes
 * ---------------------------------------------------------------------
 */


/* ---------------------------------------------------------------------
 * SysApiInit
 * Initialize API
 * ---------------------------------------------------------------------
 */
void 
SysApiInit(void)
{
	/* nothing to do right now */
}

/* ---------------------------------------------------------------------
 * SysApiClear
 * Clear API
 * ---------------------------------------------------------------------
 */
void 
SysApiClear(void)
{
	/* nothing to do right now */
}


/* ---------------------------------------------------------------------
 * API functions
 * ---------------------------------------------------------------------
 */ 

/* ---------------------------------------------------------------------
 * SysApiUsersToList
 * Read user database
 * ---------------------------------------------------------------------
 */ 
void 
SysApiUsersToList(int argc, const wchar_t* argv[])
{
	if (argc >= 2)
	{
		WINDOWSTUB*   listview;
		unsigned long tmplong;
		int           selindex = 0;
		const wchar_t*  keyword = _T("");

		swscanf(argv[0], _T("%ld"), &tmplong);
		listview = LibSysStubFind(tmplong);
		
		if (argc >= 3)
		{
			keyword = argv[2];
		}
		
		if (listview && listview->Window)
		{
			int     index;
			PASSWD_T* userslist = SysReadPasswdList( argv[1] );
			if (userslist)
			{
				PASSWD_T* user = userslist;
			
				while (user)
				{
					LISTREC* rec = ListviewCreateRecord (listview->Window);
					if (rec)
					{
						ListviewSetColumnText(rec, 0, user->UserName);
						ListviewSetColumnText(rec, 1, user->Password);
						index = ListviewInsertRecord(listview->Window, rec);
						if (wcscmp(user->UserName, keyword) == 0)
						{
							selindex = index;
						}
					}
					user = (PASSWD_T*) user->Next;
				}
				SysFreePasswdList(userslist);
			}
			
			ListviewSetSel(listview->Window, selindex);
			
			LibSysStartFrame(_T('R'), 32);
			LibSysInsertInt (ERROR_SUCCESS);
			LibSysSendFrame ();
		}
		else
		{
			LibSysWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibSysWriteError(ERROR_ARGC);
	}
}


