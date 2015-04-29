/* ---------------------------------------------------------------------
 * File: chartools.c
 * (helper routines for character string management)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: chartools.c 33446 2013-04-10 21:12:27Z dv $
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
#ifndef SIZE_MAX
#define SIZE_MAX 64535
#endif

int ModuleMbStrLen(const char* str)
{
	return mbsrtowcs(NULL, &str, SIZE_MAX, NULL);
}

int ModuleMbByteLen(const wchar_t* str)
{
	return wcsrtombs(NULL, &str, SIZE_MAX, NULL);	
}

wchar_t* ModuleMbToTCharDup(const char*  str)
{
	int    len = ModuleMbStrLen(str);
	wchar_t* tstr = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
	if (tstr)
	{
		mbsrtowcs(tstr, &str, len + 1, NULL);
		return tstr;
	}
	return NULL;
}

char* ModuleTCharToMbDup(const wchar_t* str)
{
	int   len = ModuleMbByteLen(str);
	char* mbstr = (char*) malloc((len + 1) * sizeof(char));
	if (mbstr)
	{
		wcsrtombs(mbstr, &str, len + 1, NULL);	
		return mbstr;
	}
	return NULL;
}


