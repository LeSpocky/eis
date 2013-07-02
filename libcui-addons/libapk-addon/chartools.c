/* ---------------------------------------------------------------------
 * File: chartools.c
 * (helper routines for character string management)
 *
 * Copyright (C) 2009 Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: chartools.c 23691 2010-04-08 19:17:14Z dv $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
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

int ModuleMbByteLen(const wchar_t* str)
{
#ifdef _UNICODE
	return wcsrtombs(NULL, &str, SIZE_MAX, NULL);	
#else
	return strlen(str);
#endif
}

wchar_t* ModuleMbToTCharDup(const char*  str)
{
	int    len = ModuleMbStrLen(str);
	wchar_t* tstr = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
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

char* ModuleTCharToMbDup(const wchar_t* str)
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


