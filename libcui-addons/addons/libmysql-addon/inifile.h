/* ---------------------------------------------------------------------
 * File: inifile.h
 * (read and write windows ini-file style files)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: inifile.h 23497 2010-03-14 21:53:08Z dv $
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

#ifndef INIFILE_H
#define INIFILE_H

typedef enum
{
	IGNORE,
	CREATE,
} ACCESS_T;

typedef struct
{
	char*             Name;
	char*             Value;
	void*             Next;
} INIVALUE_T;

typedef struct
{
	char*             Name;
	INIVALUE_T*       Values;
	int               NumValues;
	void*             Next;
} INISECTION_T;

typedef struct
{
	INISECTION_T*    Sections;
} INI_T;


INI_T*         IniFileCreate      (void);
void           IniFileDelete      (INI_T* ini);
int            IniFileRead        (INI_T* ini, const char* filename);
int            IniFileWrite       (INI_T* ini, const char* filename);
INISECTION_T*  IniFileAddSection  (INI_T* ini, const char* name);
INISECTION_T*  IniFileGetSection  (INI_T* ini, const char* name, ACCESS_T ac);

const char*    IniSectionGetName  (INISECTION_T* sec);
void           IniSectionSetName  (INISECTION_T* sec, const char* name);
const char*    IniSectionGetValue (INISECTION_T* sec, const char* key, const char* defval);
void           IniSectionSetValue (INISECTION_T* sec, const char* key, const char* newval);
void           IniSectionClear    (INISECTION_T* sec);
void           IniSectionSort     (INISECTION_T* sec);


#endif
