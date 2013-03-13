/* ---------------------------------------------------------------------
 * File: chartools.c
 * (helper routines for character string management)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: chartools.c 23497 2010-03-14 21:53:08Z dv $
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

#include "chartools.h"
#include <stdlib.h>
#include <string.h>

#define SIZE_MAX 64535

int ModuleMbStrLen(const char* str)
{
#ifdef _UNICODE
	return mbsrtowcs(NULL, &str, SIZE_MAX, NULL);
#else
	return strlen(str);
#endif
}

int ModuleMbByteLen(const TCHAR* str)
{
#ifdef _UNICODE
	return wcsrtombs(NULL, &str, SIZE_MAX, NULL);	
#else
	return strlen(str);
#endif
}

TCHAR* ModuleMbToTCharDup(const char*  str)
{
	int    len = ModuleMbStrLen(str);
	TCHAR* tstr = (TCHAR*) malloc((len + 1) * sizeof(TCHAR));
	if (tstr)
	{
#ifdef _UNICODE
		mbsrtowcs(tstr, &str, len + 1, NULL);
#else
		strncpy(tstr, str, len + 1);
#endif
		return tstr;
	}
	return NULL;
}

char* ModuleTCharToMbDup(const TCHAR* str)
{
	int   len = ModuleMbByteLen(str);
	char* mbstr = (char*) malloc((len + 1) * sizeof(char));
	if (mbstr)
	{
#ifdef _UNICODE
		wcsrtombs(mbstr, &str, len + 1, NULL);	
#else
		strncpy(mbstr, str, len + 1);
#endif
		return mbstr;
	}
	return NULL;
}


