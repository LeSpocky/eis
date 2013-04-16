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
static int SysApiIsMember(const wchar_t* user, const wchar_t* members);


/* ---------------------------------------------------------------------
 * SysApiInit
 * Initialize API
 * ---------------------------------------------------------------------
 */
void 
SysApiInit(void)
{
	/* nothing to do right now */
	SysInit();
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
		int           flags;
		int           selindex = 0;
		const wchar_t*  keyword = _T("");

		swscanf(argv[0], _T("%ld"), &tmplong);
		listview = LibSysStubFind(tmplong);
		
		swscanf(argv[1], _T("%d"), &flags);
		
		if (argc >= 3)
		{
			keyword = argv[2];
		}
		
		if (listview && listview->Window)
		{
			int     index;
			USER_T* userslist = SysGetUserList(flags);
			if (userslist)
			{
				USER_T* user = userslist;
			
				while (user)
				{
					LISTREC* rec = ListviewCreateRecord (listview->Window);
					if (rec)
					{
						ListviewSetColumnText(rec, 0, user->UserName);
						ListviewSetColumnText(rec, 1, user->UserId);
						ListviewSetColumnText(rec, 2, user->GroupName);
						ListviewSetColumnText(rec, 3, user->GroupId);
					
						if (user->ValidPW)
						{
							ListviewSetColumnText(rec, 4, _T("yes"));
						}
						else
						{
							ListviewSetColumnText(rec, 4, _T("no"));
						}
					
						ListviewSetColumnText(rec, 5, user->RealName);
					
						index = ListviewInsertRecord(listview->Window, rec);
						if (wcscmp(user->UserName, keyword) == 0)
						{
							selindex = index;
						}
					}
					user = (USER_T*) user->Next;
				}
				SysFreeUserList(userslist);
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


/* ---------------------------------------------------------------------
 * SysApiGroupsToList
 * Read user database
 * ---------------------------------------------------------------------
 */ 
void 
SysApiGroupsToList(int argc, const wchar_t* argv[])
{
	if (argc >= 2)
	{
		WINDOWSTUB*   listview;
		unsigned long tmplong;
		int           flags;
		int           selindex = 0;
		const wchar_t*  keyword = _T("");

		swscanf(argv[0], _T("%ld"), &tmplong);
		listview = LibSysStubFind(tmplong);
		
		swscanf(argv[1], _T("%d"), &flags);
		
		if (argc >= 3)
		{
			keyword = argv[2];
		}
		
		if (listview && listview->Window)
		{
			int      index;
			GROUP_T* grouplist = SysGetGroupList(flags);
			if (grouplist)
			{
				GROUP_T* group = grouplist;
				while (group)
				{
					LISTREC* rec = ListviewCreateRecord (listview->Window);
					if (rec)
					{
						ListviewSetColumnText(rec, 0, group->GroupName);
						ListviewSetColumnText(rec, 1, group->GroupId);
						ListviewSetColumnText(rec, 2, group->Members);
					
						index = ListviewInsertRecord(listview->Window, rec);
						if (wcscmp(grouplist->GroupName, keyword) == 0)
						{
							selindex = index;
						}
					}
					group = (GROUP_T*) group->Next;
				}
				SysFreeGroupList(grouplist);
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

/* ---------------------------------------------------------------------
 * SysApiGroupMembersSelection
 * Prepare group member selection by copying selected users to one and
 * unselected users to another listbox
 * ---------------------------------------------------------------------
 */ 
void
SysApiGroupMemberSelection(int argc, const wchar_t* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   listbox1;
		WINDOWSTUB*   listbox2;
		GROUP_T*      grouplist;
		unsigned long tmplong;
		
		swscanf(argv[0], _T("%ld"), &tmplong);
		listbox1 = LibSysStubFind(tmplong);

		swscanf(argv[1], _T("%ld"), &tmplong);
		listbox2 = LibSysStubFind(tmplong);

		grouplist = SysGetGroupList(GROUPS_SHOW_ALL);
		if (grouplist)
		{
			GROUP_T* group = SysFindGroupByName(grouplist, argv[2]);
			if (group)
			{
				USER_T* userslist = SysGetUserList(USERS_SHOW_ALL);
				
				if (userslist)
				{
					USER_T* user = userslist;
					while (user)
					{
						if (SysApiIsMember(user->UserName, group->Members))
						{
							ListboxAdd(listbox2->Window, user->UserName);
						}
						else
						{
							ListboxAdd(listbox1->Window, user->UserName);
						}
						user = (USER_T*) user->Next;
					}
					SysFreeUserList(userslist);
				}
			}
			SysFreeGroupList(grouplist);
		}
		
		LibSysStartFrame(_T('R'), 32);
		LibSysInsertInt (ERROR_SUCCESS);
		LibSysSendFrame ();
	}
	else
	{
		LibSysWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * SysApiSetGroupMembers
 * Assign a new list of members to a given group
 * $1 = group, $2 = member list separated by comma
 * ---------------------------------------------------------------------
 */ 
void
SysApiSetGroupMembers(int argc, const wchar_t* argv[])
{
	int result = FALSE;
	
	if (argc == 2)
	{
		GROUP_T*      grouplist;
		
		grouplist = SysGetGroupList(GROUPS_SHOW_ALL);
		if (grouplist)
		{
			GROUP_T* group = SysFindGroupByName(grouplist, argv[0]);
			if (group)
			{
				if (group->Members)
				{
					free(group->Members);
				}
				group->Members = wcsdup(argv[1]);
				
				if (SysWriteGroupList(grouplist))
				{
					result = TRUE;
				}
			}
			SysFreeGroupList(grouplist);
		}
		
		LibSysStartFrame(_T('R'), 48);
		LibSysInsertInt (ERROR_SUCCESS);
		LibSysInsertInt (result ? 1 : 0);
		LibSysSendFrame ();
	}
	else
	{
		LibSysWriteError(ERROR_ARGC);
	}
}


/* local helper functions */

/* ---------------------------------------------------------------------
 * SysApiIsMember
 * Check if a user is in members list
 * ---------------------------------------------------------------------
 */
static int
SysApiIsMember(const wchar_t* user, const wchar_t* members)
{
	const wchar_t* p = wcsstr(members, user);
	if (p)
	{
		if ((p == members) || (*(p - 1) == _T(',')))
		{
			if ((p[wcslen(user)] == _T(',')) || (p[wcslen(user)] == _T('\0')))
			{
				return TRUE;
			}
		}
	}
	return FALSE;
}
