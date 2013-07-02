/* ---------------------------------------------------------------------
 * File: inifile.h
 * (read and write windows ini-file style files)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: inifile.c 23497 2010-03-14 21:53:08Z dv $
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "inifile.h"


#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

/* local prototypes */
static INIVALUE_T* IniValueFind(INISECTION_T* sec, const char* key);
static INIVALUE_T* IniValueAdd(INISECTION_T* sec, const char* key);


/* ---------------------------------------------------------------------
 * IniFileCreate
 * Create an empty ini-file struture
 * ---------------------------------------------------------------------
 */
INI_T*
IniFileCreate(void)
{
	INI_T* result = (INI_T*) malloc(sizeof(INI_T));
	result->Sections = NULL;
	return result;
}

/* ---------------------------------------------------------------------
 * IniFileDelete
 * Delete ini-file struture and any associated data
 * ---------------------------------------------------------------------
 */
void
IniFileDelete(INI_T* ini)
{
	INISECTION_T* sec = ini->Sections;
	while (sec)
	{
		ini->Sections = (INISECTION_T*) sec->Next;
		IniSectionClear(sec);
		free(sec);
		sec = ini->Sections;
	}
	free(ini);
}

/* ---------------------------------------------------------------------
 * IniFileRead
 * Read data from an existing ini file
 * ---------------------------------------------------------------------
 */
int
IniFileRead(INI_T* ini, const char* filename)
{
	INISECTION_T* section = NULL;
	char buffer[256];
	
	FILE* in = fopen(filename, "rt");
	if (!in)
	{
		return FALSE;
	}
	
	while (!feof(in))
	{
		if (fgets(buffer, 255, in))
		{
			char* p = strchr(buffer, '\n');
			if (p)
			{
				*p = '\0';
			}
			
			p = strtok(buffer, " \t=");
			if (p)
			{
				if (*p == '[')
				{
					char* p2 = strrchr(p, ']');
					if (p2)
					{
						*p2 = '\0';
					}
					p++;
					section = IniFileAddSection(ini, p);
				}
				else if (section)
				{
					char* name = p;
					
					p = strtok(NULL, " \t=");
					if (p)
					{
						IniSectionSetValue (section, name, p);
					}
					else
					{
						IniSectionSetValue (section, name, "");
					}
				}
			}
		}
	}
	fclose(in);
	
	return TRUE;
}


/* ---------------------------------------------------------------------
 * IniFileWrite
 * Write data to an ini file
 * ---------------------------------------------------------------------
 */
int
IniFileWrite(INI_T* ini, const char* filename)
{
	INISECTION_T* section = ini->Sections;
	
	FILE* out = fopen(filename, "wt");
	if (!out)
	{
		return FALSE;
	}
	
	while (section)
	{
		INIVALUE_T* val = section->Values;
		
		fprintf(out, "[%s]\n", section->Name);
		while (val)
		{
			if (strlen(val->Value) > 0)
			{
				fprintf(out, "%s = %s\n", val->Name, val->Value);
			}
			else
			{
				fprintf(out, "%s\n", val->Name);
			}
			val = (INIVALUE_T*) val->Next;
		}
		fprintf(out, "\n");
		
		section = (INISECTION_T*) section->Next;
	}
	
	fclose(out);
	
	return TRUE;
}

/* ---------------------------------------------------------------------
 * IniFileAddSection
 * Add a section to the ini-file structure. If a section with the given
 * name already exists, the existing section is returned
 * ---------------------------------------------------------------------
 */
INISECTION_T*
IniFileAddSection(INI_T* ini, const char* name)
{
	INISECTION_T* newsec = NULL;
	INISECTION_T* sec    = ini->Sections;
	INISECTION_T* oldsec = NULL;

	while (sec)
	{
		if (strcasecmp(name, sec->Name) == 0)
		{
			return sec;
		}
		oldsec = sec;
		sec = (INISECTION_T*) sec->Next;
	}
		
	newsec = (INISECTION_T*) malloc(sizeof(INISECTION_T));
	if (oldsec)
	{
		oldsec->Next = newsec;
	}
	else
	{
		ini->Sections = newsec;
	}
	newsec->Name      = strdup(name);
	newsec->Values    = NULL;
	newsec->NumValues = 0;
	newsec->Next      = NULL;
	return newsec;
}

/* ---------------------------------------------------------------------
 * IniFileGetSection
 * Get a section from the ini-file structure. If the section does not
 * exist and ac is CREATE, then the section is created on the fly. Other-
 * wise, NULL is returend.
 * ---------------------------------------------------------------------
 */
INISECTION_T*
IniFileGetSection(INI_T* ini, const char* name, ACCESS_T ac)
{
	if (ac == CREATE)
	{
		return IniFileAddSection(ini, name);
	}
	else
	{
		INISECTION_T* sec = ini->Sections;
		while (sec)
		{
			if (strcasecmp(name, sec->Name) == 0)
			{
				return sec;
			}
			sec = (INISECTION_T*) sec->Next;
		}
	}
	return NULL;
}



/* ---------------------------------------------------------------------
 * IniSectionGetName
 * Read the name of a given section
 * ---------------------------------------------------------------------
 */
const char*
IniSectionGetName(INISECTION_T* sec)
{
	return (sec->Name) ? sec->Name : "";
}

/* ---------------------------------------------------------------------
 * IniSectionSetName
 * Set the name of a section
 * ---------------------------------------------------------------------
 */
void
IniSectionSetName(INISECTION_T* sec, const char* name)
{
	if (sec->Name)
	{
		free(sec->Name);
	}
	sec->Name = strdup(name);
}

/* ---------------------------------------------------------------------
 * IniSectionGetValue
 * Read a value from an entry addressed by key. If it does not exist,
 * the default value defval is returend instead
 * ---------------------------------------------------------------------
 */
const char*
IniSectionGetValue(INISECTION_T* sec, const char* key, const char* defval)
{
	INIVALUE_T* value = IniValueFind(sec, key);
	if (value)
	{
		return value->Value;
	}
	return defval;
}

/* ---------------------------------------------------------------------
 * IniSectionSetValue
 * Set a value from an entry addressed by key. If it does not exists,
 * it is created on the fly
 * ---------------------------------------------------------------------
 */
void
IniSectionSetValue(INISECTION_T* sec, const char* key, const char* newval)
{
	INIVALUE_T* value = IniValueAdd(sec, key);
	if (value)
	{
		if (value->Value)
		{
			free(value->Value);
		}
		value->Value = strdup(newval);
	}
}

/* ---------------------------------------------------------------------
 * IniSectionClear
 * Clears all data from a section
 * ---------------------------------------------------------------------
 */
void
IniSectionClear(INISECTION_T* sec)
{
	INIVALUE_T* value = sec->Values;
	while (value)
	{
		sec->Values = (INIVALUE_T*) value->Next;
		free(value->Name);
		if (value->Value)
		{
			free(value->Value);
		}
		free(value);
		value = sec->Values;
	}
	sec->NumValues = 0;
}

/* ---------------------------------------------------------------------
 * IniSectionSort
 * Sorts all data within a given section by name
 * ---------------------------------------------------------------------
 */
void
IniSectionSort(INISECTION_T* sec)
{
	int num = sec->NumValues - 1;
	while (num > 0)
	{
		int i = 0;
		INIVALUE_T* workptr = sec->Values;
		while (workptr && (i < num))
		{
			INIVALUE_T* cmpptr = workptr->Next;

			if (strcasecmp(workptr->Name, cmpptr->Name) > 0)
			{
				char* p;

				p = workptr->Name;
				workptr->Name = cmpptr->Name;
				cmpptr->Name  = p;

				p = workptr->Value;
				workptr->Value = cmpptr->Value;
				cmpptr->Value  = p;
			}
			workptr = (INIVALUE_T*) workptr->Next;
			i++;
		}
		num--;
	}
}

/* helper */

/* ---------------------------------------------------------------------
 * IniValueFind
 * Searches the value named 'key' within a given section
 * ---------------------------------------------------------------------
 */
static INIVALUE_T* 
IniValueFind(INISECTION_T* sec, const char* key)
{
	INIVALUE_T* value = sec->Values;
	while (value)
	{
		if (strcasecmp(key, value->Name) == 0)
		{
			return value;
		}
		value = (INIVALUE_T*) value->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * IniValueAdd
 * Adds a value named 'key' to a given section if it does not exist
 * ---------------------------------------------------------------------
 */
static INIVALUE_T* 
IniValueAdd(INISECTION_T* sec, const char* key)
{
	INIVALUE_T* newvalue = NULL;
	INIVALUE_T* value = sec->Values;
	INIVALUE_T* oldvalue = NULL;

	while (value)
	{
		if (strcasecmp(key, value->Name) == 0)
		{
			return value;
		}
		oldvalue = value;
		value = (INIVALUE_T*) value->Next;
	}
		
	newvalue = (INIVALUE_T*) malloc(sizeof(INIVALUE_T));
	if (oldvalue)
	{
		oldvalue->Next = newvalue;
	}
	else
	{
		sec->Values = newvalue;
	}
	newvalue->Name  = strdup(key);
	newvalue->Value = NULL;
	newvalue->Next  = NULL;
	sec->NumValues++;
	return newvalue;
}

/* for testing purpose 
int main(void)
{
	INI_T* ini = IniFileCreate();
	if (ini)
	{
		if (IniFileRead(ini, "/etc/my.cnf"))
		{
			INISECTION_T* sec = IniFileGetSection(ini, "client", IGNORE);
			if (sec)
			{
				const char* value = IniSectionGetValue(sec, "socket", NULL);
				if (value)
				{
					printf("Socket = '%s'\n", value);
				}
			}
			
			IniFileWrite(ini, "hallo.ini");
			
		}
		IniFileDelete(ini);
	}
	return 0;
}
*/
