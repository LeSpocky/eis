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
int        ConfigMatchName  (const wchar_t* mask, const wchar_t* name, 
                             int* nummasked, int* values);
CONFENTRY* ConfigMatchMasks (CONFIG* cfg, const wchar_t* variable);
void       ConfigBuildName  (const wchar_t* mask, wchar_t* varname, int* index);
CONFENTRY* ConfigFindEntry  (CONFENTRY* first, const wchar_t* varname);


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
ConfigAddNode(CONFIG* cfg, const wchar_t* n_node, const wchar_t* mask)
{
	CONFNODE* node = malloc(sizeof(CONFNODE));
	if (node)
	{
		node->NNode = wcsdup(n_node);
		node->Mask = wcsdup(mask);
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
ConfigReadFile(CONFIG* cfg, const wchar_t* filename)
{
	if (cfg->FileName) 
	{
		free(cfg->FileName);
	}

	cfg->FileName = wcsdup(filename);

	if (!CfgFileOpen(filename, cfg->ErrOut, cfg->ErrInst))
	{
		cfg->ErrOut(cfg->ErrInst, _T("file not found"), filename, 0, FALSE);
	}
	else
	{
		int sym = CfgRead();
		while (sym != CFG_EOF)
		{
			wchar_t* variable = NULL;

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
ConfigGetEntry(CONFIG* cfg, CONFENTRY* parent, const wchar_t* name, int * index)
{
	wchar_t  varname[64 + 1];

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
const wchar_t* 
ConfigGetString(CONFIG* cfg, CONFENTRY* parent, const wchar_t* name,
                OPT_TYPE type, const wchar_t* defval, int * index)
{
	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		return entry->Value;
	}
	else if (type == REQUIRED)
	{
		wchar_t errmsg[128 + 1];

		swprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
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
ConfigGetBool(CONFIG* cfg, CONFENTRY* parent, const wchar_t* name,
                OPT_TYPE type, const wchar_t* defval, int * index)
{
	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		if (wcscasecmp(entry->Value, _T("yes")) == 0)
		{
			return TRUE;
		}
		else if (wcscasecmp(entry->Value, _T("no")) == 0)
		{
			return FALSE;
		}
		else
		{
			wchar_t errmsg[128 + 1];

			swprintf(errmsg, 128, _T("Option '%ls' contains an invalid value"), name);
			cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
		}
	}
	else if (type == REQUIRED)
	{
		wchar_t errmsg[128 + 1];

		swprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}
	if (wcscasecmp(defval, _T("yes")) == 0)
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
ConfigGetNum(CONFIG* cfg, CONFENTRY* parent, const wchar_t* name,
                OPT_TYPE type, const wchar_t* defval, int * index)
{
	int  value;

	CONFENTRY* entry = ConfigGetEntry(cfg, parent, name, index);
	if (entry)
	{
		wchar_t errmsg[128 + 1];

		if (swscanf(entry->Value, _T("%d"), &value) == 1)
		{
			return value;
		}
		swprintf(errmsg, 128, _T("Option '%ls' contains an invalid value"), name);

		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}
	else if (type == REQUIRED)
	{
		wchar_t errmsg[128 + 1];
		swprintf(errmsg, 128, _T("Missing required option '%ls'"), name);
		cfg->ErrOut(cfg->ErrInst, errmsg, cfg->FileName, 0, TRUE);
	}

	if (swscanf(defval, _T("%d"), &value) == 1)
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
ConfigMatchName(const wchar_t* mask, const wchar_t* name, int* nummasked, int* values)
{
	int len = wcslen(mask);
	int i, pos;

	*nummasked = 0;

	pos = 0;
	i = 0;
	while (i < len)
	{
		if (mask[i] == _T('%'))
		{
			if (iswdigit(name[pos]))
			{
				values[*nummasked] = name[pos++] - 48;

				while (iswdigit(name[pos]))
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
ConfigBuildName(const wchar_t* mask, wchar_t* varname, int* index)
{
	const wchar_t* pos1 = mask;
	const wchar_t* pos2 = wcschr(pos1,_T('%'));
	int   cpos = 0;
	int   i = 0;

	while (pos1)
	{
		int len = wcslen(pos1);
		if (pos2)
		{
			len = pos2 - pos1;
		}
		wcsncpy(&varname[cpos],pos1,len);
		cpos += len;

		varname[cpos] = 0;

		if (pos2)
		{
			swprintf(&varname[cpos], 32, _T("%i"),index[i]);
			pos1 = pos2 + 1;
			pos2 = wcschr(pos1,_T('%'));

			cpos += wcslen(&varname[cpos]);

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
ConfigMatchMasks(CONFIG* cfg, const wchar_t* variable)
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
ConfigFindEntry(CONFENTRY* first, const wchar_t* varname)
{
	while (first)
	{
		if (wcscmp(first->Name,varname)==0)
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

