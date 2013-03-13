/* ---------------------------------------------------------------------
 * File: system.h
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: system.h 26614 2010-11-10 18:44:13Z dv $
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

#ifndef SYSTEN_H
#define SYSTEM_H

#include "chartools.h"

#define USERS_SHOW_ALL       0
#define USERS_HIDE_SYSTEM    1
#define USERS_HIDE_REAL      2
#define USERS_HIDE_MACHINES  4
#define USERS_HIDE_NOBODY    8
#define USERS_HIDE_ROOT     16

#define GROUPS_SHOW_ALL      0
#define GROUPS_HIDE_SYSTEM   1
#define GROUPS_HIDE_REAL     2
#define GROUPS_HIDE_NOGROUP  3

typedef struct
{
	TCHAR* UserName;
	TCHAR* UserId;
	TCHAR* GroupName;
	TCHAR* GroupId;
	int    ValidPW;
	TCHAR* RealName;
	void*  Next;
} USER_T;

typedef struct
{
	TCHAR* GroupName;
	TCHAR* Password;
	TCHAR* GroupId;
	TCHAR* Members;
	void*  Next;
} GROUP_T;

typedef struct
{
	TCHAR* UserName;
	TCHAR* Password;
	void*  Next;
} PASSWD_T;

typedef enum
{
	UNKNOWN_SYSTEM,
	EISFAIR_1,
	EISFAIR_2,
	EISXEN
} SYSTEM_T;

void           SysInit           (void);

USER_T*        SysGetUserList    (int query_flags);
GROUP_T*       SysGetGroupList   (int query_flags);

GROUP_T*       SysFindGroupById  (GROUP_T*  groups,  const TCHAR* groupid);
GROUP_T*       SysFindGroupByName(GROUP_T*  groups,  const TCHAR* name);
PASSWD_T*      SysFindPasswd     (PASSWD_T* passwds, const TCHAR* username);

void           SysFreeUserList   (USER_T*   users);
void           SysFreeGroupList  (GROUP_T*  groups);
void           SysFreePasswdList (PASSWD_T* passwds);

int            SysWriteGroupList (GROUP_T*  groups);

#endif

