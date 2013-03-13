/* ---------------------------------------------------------------------
 * File: system_api.h
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
#ifndef SYSTEM_API_H
#define SYSTEM_API_H

#include <cui.h>
#include "system.h"

#define SYS_API_USERSTOLIST          10
#define SYS_API_GROUPSTOLIST         20
#define SYS_API_GROUPMEMBERSELECTION 30
#define SYS_API_SETGROUPMEMBERS      40

void SysApiInit                 (void);
void SysApiClear                (void);

void SysApiUsersToList          (int argc, const TCHAR* argv[]);
void SysApiGroupsToList         (int argc, const TCHAR* argv[]);
void SysApiGroupMemberSelection (int argc, const TCHAR* argv[]);
void SysApiSetGroupMembers      (int argc, const TCHAR* argv[]);

#endif
