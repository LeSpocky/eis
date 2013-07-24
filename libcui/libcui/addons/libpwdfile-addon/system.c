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
 * SysReadPasswdList
 * read flat text "username:password" file
 * ---------------------------------------------------------------------
 */
PASSWD_T*
SysReadPasswdList(char* passwdfile )
{
	PASSWD_T* passwds = NULL;
	PASSWD_T* last    = NULL;
	char      buffer[256];
	
	FILE* in = fopen( passwdfile, "rt");
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
				memset(newpasswd, 0, sizeof(newpasswd));
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



