/* ---------------------------------------------------------------------
 * File: server.c
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: system.c 33468 2013-04-14 16:40:27Z dv $
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "system.h"


#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif


static USER_T*   SysReadEtcPasswd(int query_flags);
static GROUP_T*  SysReadEtcGroup (int query_flags);
static PASSWD_T* SysReadEtcShadow(void);

static int       SysMinUserId  = 1000;



/* ---------------------------------------------------------------------
 * SysGetUserList
 * Read a list of users from the user database
 * ---------------------------------------------------------------------
 */
USER_T*
SysGetUserList(int query_flags)
{
	USER_T* users = SysReadEtcPasswd(query_flags);
	if (users)
	{
		GROUP_T* groups = SysReadEtcGroup(GROUPS_SHOW_ALL);
		if (groups)
		{
			USER_T* user = users;
			while (user)
			{
				GROUP_T* group = SysFindGroupById(groups, user->GroupId);
				if (group)
				{
					free(user->GroupName);
					user->GroupName = wcsdup(group->GroupName);
				}
				user = (USER_T*) user->Next;
			}
			SysFreeGroupList(groups);
		}
	}
	if (users)
	{
		PASSWD_T* passwds = SysReadEtcShadow();
		if (passwds)
		{
			USER_T* user = users;
			while (user)
			{
				PASSWD_T* pwd = SysFindPasswd(passwds, user->UserName);
				if (pwd)
				{
					if ((pwd->Password[0] != _T('*')) && (pwd->Password[0] != _T('!')))
					{
						user->ValidPW = TRUE;
					}
				}
				user = (USER_T*) user->Next;
			}
			SysFreePasswdList(passwds);
		}
	}
	return users;
}

/* ---------------------------------------------------------------------
 * SysGetGroupList
 * Read a list of groups from the group database
 * ---------------------------------------------------------------------
 */
GROUP_T*
SysGetGroupList(int query_flags)
{
	return SysReadEtcGroup(query_flags);
}

/* ---------------------------------------------------------------------
 * SysFreeUserList
 * free user list data
 * ---------------------------------------------------------------------
 */
void
SysFreeUserList(USER_T* users)
{
	USER_T* user = users;
	while (user)
	{
		users = (USER_T*) user->Next;
		
		if (user->UserName)  free(user->UserName);
		if (user->UserId)    free(user->UserId);
		if (user->GroupName) free(user->GroupName);
		if (user->GroupId)   free(user->GroupId);
		if (user->RealName)  free(user->RealName);
		free(user);
		
		user = users;
	}
}

/* ---------------------------------------------------------------------
 * SysFreeGroupList
 * free group list data
 * ---------------------------------------------------------------------
 */
void
SysFreeGroupList(GROUP_T* groups)
{
	GROUP_T* group = groups;
	while (group)
	{
		groups = (GROUP_T*) group->Next;
		
		if (group->GroupName) free(group->GroupName);
		if (group->GroupId)   free(group->GroupId);
		if (group->Members)   free(group->Members);
		free(group);
		
		group = groups;
	}
}

/* ---------------------------------------------------------------------
 * SysFreePasswdList
 * free passwd list data
 * ---------------------------------------------------------------------
 */
void
SysFreePasswdList(PASSWD_T* passwds)
{
	PASSWD_T* passwd = passwds;
	while (passwd)
	{
		passwds = (PASSWD_T*) passwd->Next;
		
		if (passwd->UserName) free(passwd->UserName);
		if (passwd->Password) free(passwd->Password);
		free(passwd);
		
		passwd = passwds;
	}
}


/* ---------------------------------------------------------------------
 * SysFindGroupById
 * search group list for an entry specified by groupid
 * ---------------------------------------------------------------------
 */
GROUP_T*
SysFindGroupById(GROUP_T* groups, const wchar_t* groupid)
{
	while (groups)
	{
		if (wcscmp(groups->GroupId, groupid) == 0)
		{
			return groups;
		}
		groups = (GROUP_T*) groups->Next;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * SysFindGroupByName
 * search group list for an entry specified by name
 * ---------------------------------------------------------------------
 */
GROUP_T*
SysFindGroupByName(GROUP_T* groups, const wchar_t* name)
{
	while (groups)
	{
		if (wcscmp(groups->GroupName, name) == 0)
		{
			return groups;
		}
		groups = (GROUP_T*) groups->Next;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * SysFindPasswd
 * search password list for an entry specified by username
 * ---------------------------------------------------------------------
 */
PASSWD_T*
SysFindPasswd(PASSWD_T* passwds, const wchar_t* username)
{
	while (passwds)
	{
		if (wcscmp(passwds->UserName, username) == 0)
		{
			return passwds;
		}
		passwds = (PASSWD_T*) passwds->Next;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * SysWriteGroupList
 * write group list
 * ---------------------------------------------------------------------
 */
int
SysWriteGroupList(GROUP_T* groups)
{
	FILE* out = fopen("/etc/group", "wt");
	if (out)
	{
		while (groups)
		{
			char* tmpchar = ModuleTCharToMbDup(groups->GroupName);
			if (tmpchar)
			{
				fprintf(out, "%s:", tmpchar);
				free(tmpchar);
			}
			tmpchar = ModuleTCharToMbDup(groups->Password);
			if (tmpchar)
			{
				fprintf(out, "%s:", tmpchar);
				free(tmpchar);
			}
			tmpchar = ModuleTCharToMbDup(groups->GroupId);
			if (tmpchar)
			{
				fprintf(out, "%s:", tmpchar);
				free(tmpchar);
			}
			tmpchar = ModuleTCharToMbDup(groups->Members);
			if (tmpchar)
			{
				fprintf(out, "%s\n", tmpchar);
				free(tmpchar);
			}
			groups = (GROUP_T*) groups->Next;
		}
		fclose(out);
		return TRUE;
	}
	return FALSE;
}


/* helper function */

/* ---------------------------------------------------------------------
 * SysReadEtcPasswd
 * read /etc/passwd file
 * ---------------------------------------------------------------------
 */
static USER_T*
SysReadEtcPasswd(int query_flags)
{
	USER_T* users = NULL;
	USER_T* last  = NULL;
	char    buffer[256];
	
	FILE* in = fopen("/etc/passwd", "rt");
	if (!in)
	{
		return NULL;
	}
	
	while (!feof(in))
	{
		if (fgets(buffer, 255, in))
		{
			USER_T* newuser;
			char* s = buffer;
			char* p = strchr(buffer, '\n');
			if (p)
			{
				*p = '\0';
			}
			
			newuser = (USER_T*) malloc(sizeof(USER_T));
			if (newuser)
			{
				int loop = 0;
				
				memset(newuser, 0, sizeof(USER_T));
				newuser->Next      = NULL;
				newuser->ValidPW   = FALSE;
				newuser->GroupName = wcsdup(_T("unknown"));
				
				p = strchr(s, ':');
				while (p)
				{
					*p = '\0';
					switch(loop)
					{
					case 0: newuser->UserName = ModuleMbToTCharDup(s); break;
					case 2: newuser->UserId   = ModuleMbToTCharDup(s); break;
					case 3: newuser->GroupId  = ModuleMbToTCharDup(s); break;
					case 4: newuser->RealName = ModuleMbToTCharDup(s); break;
					default: break;
					}
					
					s = p + 1;
					p = strchr(s, ':');
					loop++;
				}
				
				if ((loop >= 6) && (newuser->UserName[0] != _T('\0')))
				{
					int uid = 0;
					swscanf(newuser->UserId, _T("%d"), &uid);
					
					if (((query_flags & USERS_HIDE_SYSTEM) && (uid < SysMinUserId) && (uid > 0)) ||
						((query_flags & USERS_HIDE_ROOT) && (uid == 0)) ||
						((query_flags & USERS_HIDE_NOBODY) && (uid >= 65534)) ||
						((query_flags & USERS_HIDE_MACHINES) && 
						(newuser->UserName[wcslen(newuser->UserName) - 1] == _T('$'))))
					{
						/* user is hidden */
						SysFreeUserList(newuser);
					}
					else
					{
						if (last)
						{
							last->Next = newuser;
						}
						else
						{
							users = newuser;
						}
						last = newuser;
					}
				}
				else
				{
					SysFreeUserList(newuser);
				}
			}
		}
	}
	fclose(in);

	return users;
}


/* ---------------------------------------------------------------------
 * SysReadEtcGroup
 * read /etc/group file
 * ---------------------------------------------------------------------
 */
static GROUP_T*
SysReadEtcGroup(int query_flags)
{
	GROUP_T* groups = NULL;
	GROUP_T* last  = NULL;
	char     buffer[256];
	
	CUI_USE_ARG(query_flags);
	
	FILE* in = fopen("/etc/group", "rt");
	if (!in)
	{
		return NULL;
	}
	
	while (!feof(in))
	{
		if (fgets(buffer, 255, in))
		{
			GROUP_T* newgroup;
			char* s = buffer;
			char* p = strchr(buffer, '\n');
			if (p)
			{
				*p = '\0';
			}
			
			newgroup = (GROUP_T*) malloc(sizeof(GROUP_T));
			if (newgroup)
			{
				int   loop = 0;
				memset(newgroup, 0, sizeof(GROUP_T));
				newgroup->Next = NULL;
				
				p = strchr(s, ':');
				while (p)
				{
					*p = '\0';
					switch(loop)
					{
					case 0: newgroup->GroupName = ModuleMbToTCharDup(s); break;
					case 1: newgroup->Password  = ModuleMbToTCharDup(s); break;
					case 2: newgroup->GroupId   = ModuleMbToTCharDup(s); break;
					default: break;
					}
					
					s = p + 1;
					p = strchr(s, ':');
					loop++;
				}
				if (loop == 3)
				{
					newgroup->Members   = ModuleMbToTCharDup(s); 
				}
				else
				{
					newgroup->Members   = wcsdup(_T(""));
				}
				
				if (loop >= 3)
				{
					int id = 0;
					
					swscanf(newgroup->GroupId, _T("%d"), &id);
					
					if (last)
					{
						last->Next = newgroup;
					}
					else
					{
						groups = newgroup;
					}
					last = newgroup;
				}
				else
				{
					SysFreeGroupList(newgroup);
				}
			}
		}
	}
	fclose(in);

	return groups;
}


/* ---------------------------------------------------------------------
 * SysReadEtcShadow
 * read /etc/shadow file
 * ---------------------------------------------------------------------
 */
static PASSWD_T*
SysReadEtcShadow(void)
{
	PASSWD_T* passwds = NULL;
	PASSWD_T* last    = NULL;
	char      buffer[256];
	
	FILE* in = fopen("/etc/shadow", "rt");
	if (!in)
	{
		return NULL;
	}
	
	while (!feof(in))
	{
		if (fgets(buffer, 255, in))
		{
			PASSWD_T* newpasswd;
			char* s = buffer;
			char* p = strchr(buffer, '\n');
			if (p)
			{
				*p = '\0';
			}
			
			newpasswd = (PASSWD_T*) malloc(sizeof(PASSWD_T));
			if (newpasswd)
			{
				int loop = 0;
				memset(newpasswd, 0, sizeof(PASSWD_T));
				newpasswd->Next      = NULL;
				
				p = strchr(s, ':');
				while (p)
				{
					*p = '\0';
					switch(loop)
					{
					case 0: newpasswd->UserName = ModuleMbToTCharDup(s); break;
					case 1: newpasswd->Password = ModuleMbToTCharDup(s); break;
					default: break;
					}
					
					s = p + 1;
					p = strchr(s, ':');
					loop++;
				}
				
				if (loop >= 2)
				{
					if (last)
					{
						last->Next = newpasswd;
					}
					else
					{
						passwds = newpasswd;
					}
					last = newpasswd;
				}
				else
				{
					SysFreePasswdList(newpasswd);
				}
			}
		}
	}
	fclose(in);

	return passwds;
}


/*int main(void)
{
	USER_T* users = SysGetUserList(USERS_SHOW_ALL);
	if (users)
	{
		USER_T* user = users;
		while (user)
		{
			printf("%s:%s:%s:", user->UserName, user->UserId, user->GroupName);
			if (user->ValidPW)
			{
				printf("VALID\n");
			}
			else
			{
				printf("INVALID\n");
			}
			
			user = (USER_T*) user->Next;
		}
		SysFreeUserList(users);
	}
	return 0;
}*/

