/* ---------------------------------------------------------------------
 * File: config.c
 * (routines to read simple eisfair-style config files)
 *
 * Copyright (C) 2004
 * Daniel Vogel, <daniel_vogel@t-online.de>
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

#include "global.h"
#include "cui-util.h"
#include "cfg.h"

#define MAX_DEPTH 15

/* local prototypes */
void       ConfigDeleteEntry(CONFENTRY* entry);
int        ConfigMatchName  (const TCHAR* mask, const TCHAR* name, 
                             int* nummasked, int* values);
CONFENTRY* ConfigMatchMasks (CONFIG* cfg, const TCHAR* variable);
void       ConfigBuildName  (const TCHAR* mask, TCHAR* varname, int* index);
CONFENTRY* ConfigFindEntry  (CONFENTRY* first, const TCHAR* varname);


/* ---------------------------------------------------------------------
 * ConfigOpen
 * Create and initialize config structure
 * ---------------------------------------------------------------------
 */
CONFIG* 
ConfigOpen(ErrorCallback errout, void* instance)
{
	CONFIG* cfg = (CONFIG*) malloc(sizeof(CONFIG));
	cfg->FirstEntry = NULL;
	cfg->LastEntry  = NULL;
	cfg->FirstNode  = NULL;
	cfg->ErrOut     = errout;
	cfg->ErrInst    = instance;
	cfg->FileName   = NULL;
	return cfg;
}

/* ---------------------------------------------------------------------
 * ConfigAddNode
 * Add a structure node. With structure nodes enumerations can be
 * realized
 * ---------------------------------------------------------------------
 */
void 
ConfigAddNode(CONFIG* cfg, const TCHAR* n_node, const TCHAR* mask)
{
	CONFNODE* node = malloc(sizeof(CONFNODE));
	if (node)
	{
		node->NNode = tcsdup(n_node);
		node->Mask = tcsdup(mask);
		node->Next = cfg->FirstNode;
		cfg->FirstNode = node;
	}
}

/* ---------------------------------------------------------------------
 * ConfigReadFile
 * Read a config file and add it's contents to the config structure.
 * When the parser hits an error, the callback errout is called.
 * ---------------------------------------------------------------------
 */
void 
ConfigReadFile(CONFIG* cfg, const TCHAR* filename)
{
	if (cfg->FileName) 
	{
		free(cfg->FileName);
	}

	cfg->FileName = tcsdup(filename);

	if (!CfgFileOpen(filename, cfg->ErrOut, cfg->ErrInst))
	{
		cfg->ErrOut(cfg->ErrInst, _T("file not found"), filename, 0, FALSE);
	}
	else
	{
		int sym = CfgRead();
		while (sym != CFG_EOF)
		{
			TCHAR* variable = NULL;

			if (sym == CFG_IDENT)
			{
				variable = CfgGetTextDup();

				sym = CfgRead();
				if (sym != CFG_EQUAL)
				{
					cfg->ErrOut(cfg->ErrInst, 
						_T("missing '='"), 
						filename, 
						CfgGetLineNumber(), 
						FALSE);
					CfgRecoverFromError();
				}
				else
				{
					sym = CfgRead();
					if (sym != CFG_STRING)
					{
						cfg->ErrOut(cfg->ErrInst, 
							_T("missing 'value'"),
							filename, 
							CfgGetLineNumber(), 
							FALSE);
						CfgRecoverFromError();
					}
					else
					{
						CONFENTRY* parent;
						CONFENTRY* newentry;

						newentry = (CONFENTRY*) malloc(sizeof(CONFENTRY));
						newentry->Name = variable;
						newentry->Value = CfgGetStringDup();
						newentry->FirstChild = NULL;
						newentry->LastChild = NULL;
						newentry->Next = NULL;
						newentry->LineNo = CfgGetLineNumber();

						variable = NULL;
								
						parent = ConfigMatchMasks(cfg, newentry->Name);
						if (parent)
						{
							if (!parent->FirstChild)
							{
								parent->FirstChild = newentry;
							}
							else
							{
								((CONFENTRY*)parent->LastChild)->Next = newentry;
							}
							parent->LastChild = newentry;
						}
						else
						{
							if (!cfg->FirstEntry)
							{
								cfg->FirstEntry = newentry;
							}
							else
							{
								((CONFENTRY*)cfg->LastEntry)->Next = newentry;
							}
							cfg->LastEntry = newentry;
						}
						sym = CfgRead();
					}
				}
			}

			if (variable)
			{
				free(variable);
			}

			if ((sym != CFG_COMMENT) && (sym != CFG_LINE_COMMENT) && (sym != CFG_NL))
			{
				cfg->ErrOut(cfg->ErrInst, 
					_T("syntax error"), 
					filename, 
					CfgGetLineNumber(), 
					FALSE);
			}
			sym = CfgRead();
		}
		CfgClose();
	}
}

/* ---------------------------------------------------------------------
 * ConfigGetEntry
 * Find and return an config entry by it's name and it's index
 * ---------------------------------------------------------------------
 */
CONFENTRY* 
ConfigGetEntry(CONFIG* cfg, CONFENTRY* parent, const TCHAR* name, int * index)
{
	TCHAR  varname[64 + 1];

	ConfigBuildName(name, varname, index);
	if (parent)
	{
		return ConfigFindEntry(parent->FirstChild, varname);
	}
	else
	{
		return ConfigFindEntry(cfg->FirstEntry, varname);
	}
}

/* ---------------------------------------------------------------------
 * ConfigGetString
 * Find and return an config value as string
 * ---------------------------------------------------------------------
 */
const TCHAR* 
ConfigGetString(CONFIG* cfg, CONFENTRY* parent, const TCHAR* name,
                OPT_TYPE type, const TCHAR* defval, int * index)
{
	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		return entry->Value;
	}
	else if (type == REQUIRED)
	{
		TCHAR errmsg[128 + 1];
#ifdef _UNICODE
		stprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
#else
		stprintf(errmsg, 128, _T("Missing required option '%s'"), name);
#endif
		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}
	return defval;
}

/* ---------------------------------------------------------------------
 * ConfigGetBool
 * Find and return an config value as bool
 * ---------------------------------------------------------------------
 */
int
ConfigGetBool(CONFIG* cfg, CONFENTRY* parent, const TCHAR* name,
                OPT_TYPE type, const TCHAR* defval, int * index)
{
	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		if (tcscasecmp(entry->Value, _T("yes")) == 0)
		{
			return TRUE;
		}
		else if (tcscasecmp(entry->Value, _T("no")) == 0)
		{
			return FALSE;
		}
		else
		{
			TCHAR errmsg[128 + 1];
#ifdef _UNICODE
			stprintf(errmsg, 128, _T("Option '%ls' contains an invalid value"), name);
#else
			stprintf(errmsg, 128, _T("Option '%s' contains an invalid value"), name);
#endif
			cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
		}
	}
	else if (type == REQUIRED)
	{
		TCHAR errmsg[128 + 1];
#ifdef _UNICODE
		stprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
#else
		stprintf(errmsg, 128, _T("Missing required option '%s'"), name);
#endif
		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}
	if (tcscasecmp(defval, _T("yes")) == 0)
	{
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfigGetNum
 * Find and return an config value as numeric
 * ---------------------------------------------------------------------
 */
int
ConfigGetNum(CONFIG* cfg, CONFENTRY* parent, const TCHAR* name,
                OPT_TYPE type, const TCHAR* defval, int * index)
{
	int  value;

	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		TCHAR errmsg[128 + 1];

		if (stscanf(entry->Value, _T("%d"), &value) == 1)
		{
			return value;
		}
#ifdef _UNICODE
		stprintf(errmsg, 128, _T("Option '%ls' contains an invalid value"), name);
#else
		stprintf(errmsg, 128, _T("Option '%s' contains an invalid value"), name);
#endif

		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}
	else if (type == REQUIRED)
	{
		TCHAR errmsg[128 + 1];
#ifdef _UNICODE
		stprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
#else
		stprintf(errmsg, 128, _T("Missing required option '%s'"), name);
#endif
		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}

	if (stscanf(defval, _T("%d"), &value) == 1)
	{
		return value;
	}
	return 0;
}


/* ---------------------------------------------------------------------
 * ConfigClose
 * Free all data associated with the config structure
 * ---------------------------------------------------------------------
 */
void 
ConfigClose(CONFIG* cfg)
{
	CONFNODE* worknode   = cfg->FirstNode;
	CONFENTRY* workentry = cfg->FirstEntry;

	while (worknode)
	{
		cfg->FirstNode = worknode->Next;
		free(worknode->NNode);
		free(worknode->Mask);
		free(worknode);
		worknode = cfg->FirstNode;
	}

	while (workentry)
	{
		cfg->FirstEntry = workentry->Next;
		ConfigDeleteEntry(workentry);
		workentry = cfg->FirstEntry;
	}
	if (cfg->FileName) free(cfg->FileName);
	free(cfg);
}


/* helper functions */

/* ---------------------------------------------------------------------
 * ConfigDeleteEntry
 * Free the one config entry and all it's children
 * ---------------------------------------------------------------------
 */
void 
ConfigDeleteEntry(CONFENTRY* entry)
{
	CONFENTRY* workentry = entry->FirstChild;
	while (workentry)
	{
		entry->FirstChild = workentry->Next;
		ConfigDeleteEntry(workentry);
		workentry = entry->FirstChild;
	}
	free(entry->Name);
	free(entry->Value);
	free(entry);
}

/* ---------------------------------------------------------------------
 * ConfigMatchName
 * Check if a name matches a node's name mask
 * ---------------------------------------------------------------------
 */
int 
ConfigMatchName(const TCHAR* mask, const TCHAR* name, int* nummasked, int* values)
{
	int len = tcslen(mask);
	int i, pos;

	*nummasked = 0;

	pos = 0;
	i = 0;
	while (i < len)
	{
		if (mask[i] == _T('%'))
		{
			if (istdigit(name[pos]))
			{
				values[*nummasked] = name[pos++] - 48;

				while (istdigit(name[pos]))
				{
					values[*nummasked] *= 10;
					values[*nummasked] += name[pos++] - 48;
				}
				i++;
				(*nummasked)++;
			}
			else
			{
				break;
			}
		}
		else
		{
			if (mask[i++] != name[pos++])
			{
				break;
			}
		}
	}

	if (i == len)
	{
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfigBuildName
 * Create a name from a given mask
 * ---------------------------------------------------------------------
 */
void 
ConfigBuildName(const TCHAR* mask, TCHAR* varname, int* index)
{
	const TCHAR* pos1 = mask;
	const TCHAR* pos2 = tcschr(pos1,_T('%'));
	int   cpos = 0;
	int   i = 0;

	while (pos1)
	{
		int len = tcslen(pos1);
		if (pos2)
		{
			len = pos2 - pos1;
		}
		tcsncpy(&varname[cpos],pos1,len);
		cpos += len;

		varname[cpos] = 0;

		if (pos2)
		{
			stprintf(&varname[cpos], 32, _T("%i"),index[i]);
			pos1 = pos2 + 1;
			pos2 = tcschr(pos1,_T('%'));

			cpos += tcslen(&varname[cpos]);

			i++;
		}
		else
		{
			pos1 = NULL;
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfigMatchMasks
 * Find the node (if any) the variable belongs to by searching all masks
 * ---------------------------------------------------------------------
 */
CONFENTRY* 
ConfigMatchMasks(CONFIG* cfg, const TCHAR* variable)
{
	CONFNODE* node = cfg->FirstNode;
	int nummasked;
	int values[MAX_DEPTH];

	while(node)
	{
		if (ConfigMatchName(node->Mask,variable,&nummasked, values))
		{
			return ConfigGetEntry(cfg, NULL, node->NNode, values);
		}
		node = (CONFNODE*) node->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfigFindEntry
 * This function searches for a given value by recursively walking 
 * through the configuration tree
 * ---------------------------------------------------------------------
 */
CONFENTRY* 
ConfigFindEntry(CONFENTRY* first, const TCHAR* varname)
{
	while (first)
	{
		if (tcscmp(first->Name,varname)==0)
		{
			return first;
		}
		else if (first->FirstChild)
		{
			CONFENTRY* child = ConfigFindEntry(first->FirstChild, varname);
			if (child)
			{
				return child;
			}
		}

		first = first->Next;
	}
	return NULL;
}

