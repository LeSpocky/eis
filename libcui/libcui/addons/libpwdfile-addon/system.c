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
 * estrtok
 * local tokenizer function
 * ---------------------------------------------------------------------
 */
char 
*estrtok(char *str, const char *delim)
{
    static char *last = NULL;
    char *ret;

    if(str)
        last = str;
    else {
        if(!last)
            return NULL;
        last++;
    }  

    ret = last;

    for(;;)
    {  
        if(*last == 0) 
        {  
            last = NULL;
            return "";
        }  

        if(strchr(delim, *last))
        {  
            *last = 0; 
            return ret;
        }  
        last++;
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
	char      *tmp;
	
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
			newpasswd = (PASSWD_T*) malloc(sizeof(PASSWD_T));
			if (newpasswd)
			{
				int loop = 0;
				memset(newpasswd, 0, sizeof(PASSWD_T));
				newpasswd->Next      = NULL;

				tmp = estrtok(buffer, ":");
				while(tmp)
				{  
					switch(loop)
					{
					case 0: newpasswd->UserName = ModuleMbToTCharDup(tmp); break;
					case 1: newpasswd->Password = ModuleMbToTCharDup(tmp); break;
					default: break;
					}
                	tmp = estrtok(NULL, ":");
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



