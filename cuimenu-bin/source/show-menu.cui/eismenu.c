/* ---------------------------------------------------------------------
 * File: eismenu.c
 * (show-menu for the EisFair-Server project)
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
#include "eismenu.h"

#define X_SPACE 4
#define Y_SPACE 2

int MenuLevel = 0;

/* local prototypes */

static void     EisMenuClear(EISMENU* eismenu);
static void     EisMenuInit(EISMENU* eismenu);
static void     EisMenuKernelVersion(wchar_t* version, int len);
static int      EisMenuGetNextMenu(const wchar_t* filename, wchar_t* menuname, int len);
static wchar_t* EisMenuKillSpaces(wchar_t* buffer);
static void     EisMenuReadClassicNode(EISMENU* eismenu, XMLNODE* node, int first);
static void     EisMenuCopyAttr(EISMENUITEM* item, XMLOBJECT* obj, const wchar_t* name);
static wchar_t* EisMenuGetObjectData(EISMENU* eismenu, XMLOBJECT* ob);
static void     EisMenuReadXmlNode(EISMENU* eismenu, XMLNODE* node);
static int      EisMenuCheckUI(const wchar_t *uistr);
static void     EisMenuSwapItems(EISMENUITEM* item1, EISMENUITEM* item2);
static wchar_t* EisMenuLowerStr(const wchar_t* str, wchar_t* buffer);
static void     EisMenuWriteToFile(const wchar_t* text, FILE* out);
static void     EisMenuGetFileData(const wchar_t* filename, wchar_t* data, int len);
static void     EisMenuRemoveLoginInfo(wchar_t* url);
static void     EisMenuUpdateVersionTitle(EISMENU* eismenu);
static void     EisMenuUpdateUrlTitle(EISMENU* eismenu);


/* public functions */

/* ---------------------------------------------------------------------
 * EisMenuCreate
 * Create the 'EISMENUE'-structure. 
 * ---------------------------------------------------------------------
 */
EISMENU*
EisMenuCreate()
{
	EISMENU* eismenu = (EISMENU*) malloc(sizeof(EISMENU));
	if (eismenu)
	{
		EisMenuInit(eismenu);
		eismenu->PostProcess = NULL;
		eismenu->Filename = NULL;
		eismenu->Next = NULL;
		eismenu->Previous = NULL;
		eismenu->Level = MenuLevel++;
		eismenu->LastChoice = 1;
		eismenu->Menu = NULL;
	}

	return eismenu;
}

/* ---------------------------------------------------------------------
 * EisMenuDelete
 * Delete the EISMENU-structure and all associated data
 * ---------------------------------------------------------------------
 */
void 
EisMenuDelete(EISMENU* eismenu)
{
	if (eismenu)
	{
		EisMenuClear(eismenu);
		if (eismenu->PostProcess)
		{
			if (eismenu->PostProcess->ScriptFile) 
			{
				free(eismenu->PostProcess->ScriptFile);
			}
			if (eismenu->PostProcess->PackageName) 
			{
				free(eismenu->PostProcess->PackageName);
			}
			if (eismenu->PostProcess->MenuFile) 
			{
				free(eismenu->PostProcess->MenuFile);
			}
			free(eismenu->PostProcess);
		}
		if (eismenu->Menu)
		{
			WindowDestroy(eismenu->Menu);
		}
		if (eismenu->Filename) 
		{
			free(eismenu->Filename);
		}
		free(eismenu);
		MenuLevel--;
	}
}

/* ---------------------------------------------------------------------
 * EisMenuReadFile
 * Read the specified Eisfair-Menu file 'filename' and transfer the menu
 * contents into the EISMENU-structure.
 * ---------------------------------------------------------------------
 */
void
EisMenuReadFile(EISMENU* eismenu, const wchar_t* filename, 
                ErrorCallback errout, void* instance)
{
	XMLFILE* menufile;
	XMLNODE* node = NULL;
	XMLOBJECT* root;
	struct stat filestat;

	if (!eismenu->Filename)
	{
		eismenu->Filename = wcsdup(filename);
	}

	if (FileStat(filename, &filestat) == 0)
	{
		eismenu->Filetime = filestat.st_mtime;
	}
	else
	{
		errout(instance, _T("unable to stat menu file"), filename, 0, TRUE);
	}

	menufile = XmlCreate(filename);
	XmlSetErrorHook   (menufile, errout, instance);
	XmlPreserveNewline(menufile, TRUE);
	XmlReadFile       (menufile);
	
	root = XmlGetObjectTree(menufile);
	if (root) node = root->FirstNode;

	while (node)
	{
		if ((node->Type == XML_OBJNODE)&&(node->Object))
		{
			EisMenuReadXmlNode(eismenu,node);
		}
		else if ((node->Type == XML_DATANODE)&&(node->Data))
		{
			EisMenuReadClassicNode(eismenu,node,node == root->FirstNode);
		}
		else if ((node->Type == XML_COMMENTNODE)&&(node->Data))
		{
			EISMENUCMMT* cmmt = (EISMENUCMMT*) malloc(sizeof(EISMENUCMMT));
			if (cmmt)
			{
				cmmt->Data = wcsdup(node->Data);
				cmmt->Next = NULL;

				if (eismenu->LastComment)
				{
					eismenu->LastComment->Next = cmmt;
				}
				else
				{
					eismenu->FirstComment = cmmt;
				}
				eismenu->LastComment = cmmt;
			}
		}
		node = (XMLNODE*) node->Next;
	}
	XmlDelete(menufile);
}

/* ---------------------------------------------------------------------
 * EisMenuWriteFile
 * Write a menu file back to disk
 * ---------------------------------------------------------------------
 */
void
EisMenuWriteFile(EISMENU* eismenu, ErrorCallback errout, void* instance)
{
	wchar_t buffer[256+1];
	struct stat filestat;
	FILE* out;

	out = FileOpen(eismenu->Filename, _T("wt"));
	if (out)
	{
		EISMENUITEM* item;
		EISMENUATTR* attr;
		EISMENUCMMT* cmmt;

		cmmt = eismenu->FirstComment;
		while (cmmt)
		{
			fputs("<!-- ", out);
			EisMenuWriteToFile(cmmt->Data, out);
			fputs(" -->\n", out);
			cmmt = (EISMENUCMMT*) cmmt->Next;
		}

		if (eismenu->Title)
		{
			fputs("<title>", out);
			EisMenuWriteToFile(eismenu->Title, out);
			fputs( "</title>\n", out);
		}
		if (eismenu->SubTitle)
		{
			if (wcsstr(eismenu->SubTitle, _T("URL:")) == eismenu->SubTitle)
			{
				fputs("<url></url>\n", out);
			}
			else
			{
				fputs("<version></version>\n", out);
			}
		}
		if (eismenu->Package)
		{
			fputs("<package>", out);
			EisMenuWriteToFile(eismenu->Package, out);
			fputs("</package>\n", out);
		}

		item = eismenu->FirstItem;
		while (item)
		{
			if (item->IsClassic)
			{
				attr = item->FirstAttr;
				while (attr)
				{
					if (wcscasecmp(attr->Name, _T("SCRIPT"))==0)
					{
						EisMenuWriteToFile(attr->Value, out);
						fputs(" ", out);
						EisMenuWriteToFile(item->Name, out);
						fputs("\n", out);
						break;
					}
					attr = (EISMENUATTR*) attr->Next;
				}
			}
			else
			{
				switch(item->Type)
				{
				case ITEMTYPE_MENU:   fputs("<menu", out); break;
				case ITEMTYPE_DOC:    fputs("<doc", out); break;
				case ITEMTYPE_EDIT:   fputs("<edit", out); break;
				case ITEMTYPE_INIT:   fputs("<init", out); break;
				case ITEMTYPE_SCRIPT: fputs("<script", out); break;
				default: fputs("<script", out); break;
				}

				attr = item->FirstAttr;
				while (attr)
				{
					fputs(" ", out);
					EisMenuWriteToFile(EisMenuLowerStr(attr->Name, buffer), out);
					if (attr->Value)
					{
						fputs("=\"", out);
						EisMenuWriteToFile(attr->Value, out);
						fputs("\"", out);
					}
					attr = (EISMENUATTR*) attr->Next;
				}
				fputs(">", out);
				EisMenuWriteToFile(item->Name, out);

				switch(item->Type)
				{
				case ITEMTYPE_MENU:   fputs("</menu>\n", out); break;
				case ITEMTYPE_DOC:    fputs("</doc>\n", out); break;
				case ITEMTYPE_EDIT:   fputs("</edit>\n", out); break;
				case ITEMTYPE_INIT:   fputs("</init>\n", out); break;
				case ITEMTYPE_SCRIPT: fputs("</script>\n", out); break;
				default: fputs("</script\n>", out); break;
				}
			}
			item = (EISMENUITEM*) item->Next;
		}
		if (ferror(out) && errout)
		{
			errout(instance, _T("Error writing file!"), eismenu->Filename, 0, FALSE);
		}
		FileClose(out);

		if (FileStat(eismenu->Filename, &filestat) == 0)
		{
			eismenu->Filetime = filestat.st_mtime;
		}
	}
	else if (errout)
	{
		errout(instance, _T("Error opening file for writing!"), eismenu->Filename, 0, FALSE);		
	}
}

/* ---------------------------------------------------------------------
 * EisMenuUpdate
 * Update the menu with the contents of the associated Eisfair-Menu file
 * if the file has been modified since last read.
 * ---------------------------------------------------------------------
 */
int
EisMenuUpdate(EISMENU* eismenu, ErrorCallback errout, void* instance)
{
	struct stat filestat;

	if ((FileStat(eismenu->Filename, &filestat) == 0) && 
	    (filestat.st_mtime != eismenu->Filetime))
	{
		EisMenuClear(eismenu);
		EisMenuInit(eismenu);
		EisMenuReadFile(eismenu, eismenu->Filename, errout, instance);
		return TRUE;
	}
	else
	{
		if (eismenu->SubTitle)
		{
			if (wcsstr(eismenu->SubTitle, _T("URL:")) == eismenu->SubTitle)
			{
				EisMenuUpdateUrlTitle(eismenu);
			}
			else
			{
				EisMenuUpdateVersionTitle(eismenu);
			}
		}
		return FALSE;
	}
}

/* ---------------------------------------------------------------------
 * EisMenuAddItem
 * Add an item to the given menu 'eismenu'
 * ---------------------------------------------------------------------
 */
EISMENUITEM*
EisMenuAddItem(EISMENU* eismenu, const wchar_t* name, int type)
{
	if (eismenu)
	{
		EISMENUITEM* item = (EISMENUITEM*) malloc(sizeof(EISMENUITEM));
		if (item)
		{
			item->Name      = wcsdup(name);
			item->Type      = type;
			item->Next      = NULL;
			item->FirstAttr = NULL;
			item->LastAttr  = NULL;
			item->IsClassic = FALSE;
			item->IsVisible = TRUE;
			if (eismenu->LastItem)
			{
				eismenu->LastItem->Next = item;
			}
			else
			{
				eismenu->FirstItem = item;
			}
			eismenu->LastItem = item;
			eismenu->NumVisItems++;
			return item;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EisMenuAddAttribute
 * Add an attribute to the given menu item 'item'
 * ---------------------------------------------------------------------
 */
EISMENUATTR*
EisMenuAddAttribute(EISMENUITEM* item, const wchar_t* name, const wchar_t* value)
{
	if (item)
	{
		EISMENUATTR* attr = (EISMENUATTR*) malloc(sizeof(EISMENUATTR));
		if (attr)
		{
			attr->Name = NULL;
			attr->Value = NULL;
			if (name)  attr->Name = wcsdup(name);
			if (value) attr->Value = wcsdup(value);
			attr->Next = NULL;
			if (item->LastAttr)
			{
				item->LastAttr->Next = attr;
			}
			else
			{
				item->FirstAttr = attr;
			}
			item->LastAttr = attr;
			return attr;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EisMenuAssignPackage
 * Assign a package to a newly created menu
 * ---------------------------------------------------------------------
 */
void
EisMenuAssignPackage(EISMENU* eismenu, const wchar_t* package)
{
	if (eismenu && package)
	{
		if (eismenu->Package) free(eismenu->Package);
		eismenu->Package = wcsdup(package);
	}
}

/* ---------------------------------------------------------------------
 * EisMenuGetSubTitle
 * Run through the menu structure until a menu is found with an existing
 * 'SubTitle'-entry.
 * ---------------------------------------------------------------------
 */
const wchar_t*
EisMenuGetSubTitle(EISMENU* eismenu)
{
	EISMENU* workptr = eismenu;
	while (workptr)
	{
		if (workptr->SubTitle) return workptr->SubTitle;
	
		workptr = (EISMENU*) workptr->Previous;	
	}
	return _T("");
}

/* ---------------------------------------------------------------------
 * EisMenuGetAttr
 * Seek for an attribute with the specified name. If this attribute
 * can't be found, the function returns NULL
 * ---------------------------------------------------------------------
 */
EISMENUATTR*
EisMenuGetAttr(EISMENUITEM* item, const wchar_t* name)
{
	if (item)
	{
		EISMENUATTR* workptr = item->FirstAttr;
		while (workptr)
		{
			if (wcscasecmp(workptr->Name,name) == 0) 
			{
				return workptr;
			}
			workptr = (EISMENUATTR*) workptr->Next;	
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EisMenuBuildGUI
 * Create the GUI-representation of the menu-contents
 * ---------------------------------------------------------------------
 */
CUIWINDOW* 
EisMenuBuildGUI(EISMENU* eismenu, CUIWINDOW* parent, CUIWINDOW* mainwin)
{
	CUIWINDOW*   menu;
	CUIRECT      rc;
	EISMENUITEM* workitem;
	int index = 0;
	int x, y;
	int rows, textwidth;

	rows      = eismenu->NumVisItems + 6;
	textwidth = eismenu->MaxWidth + 9;
	
	WindowGetClientRect(mainwin, &rc);

	if (rows > (rc.H - Y_SPACE * eismenu->Level)) 
	{
		rows = rc.H - Y_SPACE * eismenu->Level;
	}
	if (textwidth > (rc.W - X_SPACE * eismenu->Level)) 
	{
		textwidth = rc.W - X_SPACE * eismenu->Level;
	}

	y = Y_SPACE * eismenu->Level + 1;
	x = X_SPACE * eismenu->Level;

	/* use existing menu if possible */
	menu = eismenu->Menu;
	if (!menu)
	{
		menu = MenuNew(parent, 
			eismenu->Title ? eismenu->Title : _T("MENU"),
			x, y, textwidth, rows, 0, 
			CWS_POPUP, CWS_NONE);
	}
	else
	{
		MenuClear(menu);
		WindowMove(menu, x, y, textwidth, rows);
	}
	if (menu)
	{
		workitem = eismenu->FirstItem;
		while (workitem) 
		{
			if (workitem->IsVisible)
			{
				MenuAddItem(menu, workitem->Name, ++index, TRUE);
			}
			workitem = (EISMENUITEM*) workitem->Next;
		}

		MenuAddSeparator(menu, FALSE); 
		if (eismenu->Previous) 
		{
			MenuAddItem(menu, _T("Return"), 0, FALSE);
		}
		else 
		{
			MenuAddItem(menu, _T("Exit"), 0, FALSE);
		}
	}
	return menu;
}

/* ---------------------------------------------------------------------
 * EisMenuResize
 * Resize the menu, so that it does not exceed the display or terminal
 * area
 * ---------------------------------------------------------------------
 */
void 
EisMenuResize(CUIWINDOW* menu, EISMENU* eismenu, CUIWINDOW* mainwin)
{
	int x, y;
	int rows, textwidth;
	CUIRECT rc;

	rows      = eismenu->NumVisItems + 6;
	textwidth = eismenu->MaxWidth + 9;
	
	WindowGetClientRect(mainwin, &rc);

	if (rows > (rc.H - Y_SPACE * eismenu->Level)) 
	{
		rows = rc.H - Y_SPACE * eismenu->Level;
	}
	if (textwidth > (rc.W - X_SPACE * eismenu->Level)) 
	{
		textwidth = rc.W - X_SPACE * eismenu->Level;
	}

	y = Y_SPACE * eismenu->Level + 1;
	x = X_SPACE * eismenu->Level;

	WindowMove(menu, x, y, textwidth, rows); 
}

/* ---------------------------------------------------------------------
 * EisMenuGetItem
 * Get item with the given index. Index counts from 1!
 * ---------------------------------------------------------------------
 */
EISMENUITEM*
EisMenuGetItem(EISMENU* eismenu, int index)
{
	if (eismenu)
	{
		EISMENUITEM* workptr = eismenu->FirstItem;
		int i = 1;
		while (workptr != NULL)
		{
			if (workptr->IsVisible)
			{
				if (i == index) 
				{
					return workptr;
				}
				i++;
			}
			workptr = (EISMENUITEM*) workptr->Next;	
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EisMenuMakeFirstItem
 * Reorder menu to make the item "name" the first item
 * ---------------------------------------------------------------------
 */
EISMENUITEM* 
EisMenuMakeFirstItem(EISMENU* eismenu, const wchar_t* name)
{
	EISMENUITEM* workptr;
	if (eismenu)
	{
		workptr = eismenu->FirstItem;
		while (workptr)
		{
			if ((workptr->IsVisible) && (wcscmp(workptr->Name, name) == 0))
			{
				if (workptr != eismenu->FirstItem)
				{
					EisMenuSwapItems(workptr, eismenu->FirstItem);
				}
				break;
			}
			workptr = (EISMENUITEM*) workptr->Next;
		}
		return eismenu->FirstItem;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EisMenuMakeNextItem
 * Reorder menu to make the item "name" the next item following "pos"
 * ---------------------------------------------------------------------
 */
EISMENUITEM* 
EisMenuMakeNextItem(EISMENUITEM* pos, const wchar_t* name)
{
	EISMENUITEM* workptr;
	if (pos)
	{
		workptr = (EISMENUITEM*) pos->Next;
		while (workptr)
		{
			if ((workptr->IsVisible) && (wcscmp(workptr->Name, name) == 0))
			{
				if (workptr != pos->Next)
				{
					EisMenuSwapItems(workptr, pos->Next);
				}
				break;
			}
			workptr = (EISMENUITEM*) workptr->Next;
		}
		return pos->Next;
	}
	return NULL;
}


/* private functions */

/* ---------------------------------------------------------------------
 * EisMenuInit
 * Initialize all data associated with the EISMENU structure
 * ---------------------------------------------------------------------
 */
static void
EisMenuInit(EISMENU* eismenu)
{
	eismenu->FirstItem    = NULL;
	eismenu->FirstComment = NULL;
	eismenu->LastComment  = NULL;
	eismenu->LastItem     = NULL;
	eismenu->MaxWidth     = 0;
	eismenu->NumVisItems  = 0;
	eismenu->SubTitle     = NULL;
	eismenu->Title        = wcsdup(_T("unknown"));
	eismenu->Package      = wcsdup(_T("unknown"));
}

/* ---------------------------------------------------------------------
 * EisMenuClear
 * Clear all data associated with the EISMENU structure
 * ---------------------------------------------------------------------
 */
static void
EisMenuClear(EISMENU* eismenu)
{
	EISMENUITEM* workitem;
	EISMENUCMMT* workcmmt;

	workcmmt = eismenu->FirstComment;
	while (workcmmt)
	{
		eismenu->FirstComment = workcmmt->Next;
		if (workcmmt->Data) free(workcmmt->Data);
		free(workcmmt);
		workcmmt = eismenu->FirstComment;
	}
	eismenu->LastComment = NULL;

	workitem = eismenu->FirstItem;
	while (workitem) 
	{
		EISMENUATTR* workattr = workitem->FirstAttr;
		while (workattr)
		{
			workitem->FirstAttr = (EISMENUATTR*) workattr->Next;
			if (workattr->Name) free(workattr->Name);
			if (workattr->Value) free(workattr->Value);
			free (workattr);
			workattr = workitem->FirstAttr;
		}
		if (workitem->Name) free(workitem->Name);

		eismenu->FirstItem = (EISMENUITEM*) workitem->Next;
		free(workitem);
		workitem = eismenu->FirstItem;
	}
	eismenu->LastItem = NULL;

	if (eismenu->Title) free(eismenu->Title);
	if (eismenu->SubTitle) free(eismenu->SubTitle);
	if (eismenu->Package) free(eismenu->Package);
}

/* ---------------------------------------------------------------------
 * EisMenuLowerStr
 * Convert to lower case letters
 * ---------------------------------------------------------------------
 */
static wchar_t* 
EisMenuLowerStr(const wchar_t* str, wchar_t* buffer)
{
	int len = wcslen(str);
	int i;
	for (i = 0; i < len; i++)
	{
		buffer[i] = towlower(str[i]);
	}
	buffer[len] = 0;
	return buffer;
}

/* ---------------------------------------------------------------------
 * EisMenuSwapItems
 * Exchange item1 and item2
 * ---------------------------------------------------------------------
 */
static void  
EisMenuSwapItems(EISMENUITEM* item1, EISMENUITEM* item2)
{
	if (item1 && item2)
	{
		wchar_t*       Name = item1->Name;
		int          Type = item1->Type;
		int          IsClassic = item1->IsClassic;
		int          IsVisible = item1->IsVisible;
		EISMENUATTR* FirstAttr = item1->FirstAttr;
		EISMENUATTR* LastAttr = item1->LastAttr;

		item1->Name = item2->Name;
		item1->Type = item2->Type;
		item1->IsClassic = item2->IsClassic;
		item1->IsVisible = item2->IsVisible;
		item1->FirstAttr = item2->FirstAttr;
		item1->LastAttr = item2->LastAttr;

		item2->Name = Name;
		item2->Type = Type;
		item2->IsClassic = IsClassic;
		item2->IsVisible = IsVisible;
		item2->FirstAttr = FirstAttr;
		item2->LastAttr = LastAttr;
	}
}

/* ---------------------------------------------------------------------
 * EisMenuGetFileData
 * Read the first line of text within the specified file 'filename' into
 * the buffer 'data'
 * ---------------------------------------------------------------------
 */
static void 
EisMenuGetFileData(const wchar_t* filename, wchar_t* data, int len)
{
	FILE* in;
	char  buffer[256 + 1];

	if (len <= 0)
	{
		return;
	}

	data[0] = 0;

	in  = FileOpen(filename, _T("rt"));
	if (in) 
	{
		if (fgets(buffer, 256, in)) 
		{
			char* pos = strrchr(buffer,'\n');
			if (pos) 
			{
				*pos = 0;
			}

			mbstowcs(data, buffer, len);

			data[len] = 0;
		}
		FileClose(in);
	}
}

/* ---------------------------------------------------------------------
 * EisMenuKernelVersion
 * Read the package version number of the 'eis-kernel' package.
 * This information is found within the package info file
 * ---------------------------------------------------------------------
 */
static void 
EisMenuKernelVersion(wchar_t* version, int len)
{
	FILE* in;
	char  buffer[256 + 1];

	if (len <= 0) return;

	version[0] = 0;

	in  = FileOpen(_T("/var/install/packages/eiskernel"), _T("rt"));
	if (in) 
	{
		while (fgets(buffer,256,in)) 
		{
			char* pos2;
			char* pos1 = strrchr(buffer,'\n');
			if (pos1) 
			{
				*pos1 = 0;
			}

			pos1 = strstr(buffer,"<version>");
			pos2 = strstr(buffer,"</version>");
			if (pos1 && pos2 && (pos2 > (pos1 + 9))) 
			{
				pos1 += 9;
				*pos2 = 0;

				mbstowcs(version, pos1, len);

				version[len] = 0;
				break;
			}
		}                                                                                        
		FileClose(in);
	}
}

/* ---------------------------------------------------------------------
 * EisMenuRemoveLoginInfo
 * Strip embedded login information (username and password) from URLs 
 * ---------------------------------------------------------------------
 */
static void
EisMenuRemoveLoginInfo(wchar_t* url)
{
	wchar_t* pos1 = wcsstr(url, _T("//"));
	wchar_t* pos2 = wcschr(url, _T('@'));
	
	if (pos1 && pos2 && (pos1 < pos2))
	{
		wcscpy(&pos1[2], &pos2[1]);
	}
}

/* ---------------------------------------------------------------------
 * EisMenuGetNextMenu
 * Analyse the script-file 'filename' for a line with the data 
 * '/var/install/bin/show-menu ??????'. If this line exists and if this
 * line is the only script line within the file, ????? is the name of
 * the next menu file.
 * This is only used for classic menu entries...
 * ---------------------------------------------------------------------
 */
static int
EisMenuGetNextMenu(const wchar_t* filename, wchar_t* menuname, int len)
{
	int   result = FALSE;
	FILE* in;

	if (len <= 0) 
	{
		return FALSE;
	}
	menuname[0] = 0;

	in = FileOpen(filename, _T("rt"));
	if (in) 
	{
		char  buffer[512+1];
		int   linecount = 0;

		while (fgets(buffer,512,in)) 
		{
			char* pos;
			char* endpos = NULL;

			/* remove trailing newline character */	
			pos = strrchr(buffer,'\n');
			if (pos) 
			{
				*pos = 0;
			}

			/* remove leading spaces and tabs */
			pos = buffer;
			while ((*pos == ' ')||(*pos == '\t')) 
			{
				pos++;
			}
			if (pos != buffer) strcpy(buffer,pos);

			/* exclude comments and empty lines */
			if ((*pos != '#')&&(strlen(pos) > 0)) 
			{
				if (strstr(pos,"cd /tmp")!=pos) linecount++;
	
				if ((strstr(pos, "show-menu") == pos) ||
				    (strstr(pos, "/var/install/bin/show-menu") == pos)) 
				{
					pos = strchr(pos,' ');
					if (pos)
					{
						while (*pos == ' ') pos++;
		
						if (*pos=='"') 
						{
							pos ++;
						
							endpos = strchr(pos,'"');
							while (endpos && (*(endpos-1)=='\\'))
							{
								endpos = strchr(endpos+1,'"');
							}							
						}
						else 
						{
							endpos = pos;
							while ((*endpos!=0)&&(*endpos!=' ')&&(*endpos!='#')) 
							{
								endpos++;
							}
						}
		
						if (endpos)
						{
							*endpos = 0;

							mbstowcs(menuname, pos, len);

							menuname[len] = 0;
						}
		
						if (menuname[0] != 0) result = TRUE;
					}
				}
				if (linecount > 1) 
				{
					result = FALSE;
					break;
				}
			}			
		}
		FileClose(in);
	}
	return result;	
}

/* ---------------------------------------------------------------------
 * EisMenuKillSpaces
 * Remove leading spaces from character arrays
 * ---------------------------------------------------------------------
 */
static wchar_t*
EisMenuKillSpaces(wchar_t* buffer)
{
	wchar_t* result = buffer;

	while ((*result==_T(' '))||(*result==_T('\t'))) 
	{
		result++;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * EisMenuCopyAttr
 * Copy a xml-Attribute to the menu tree
 * ---------------------------------------------------------------------
 */
static void
EisMenuCopyAttr(EISMENUITEM* item, XMLOBJECT* obj, const wchar_t* name)
{
	XMLATTRIBUTE* attr = XmlGetAttribute(obj,name);
	if (attr)
	{
		EISMENUATTR* newattr = (EISMENUATTR*) malloc(sizeof(EISMENUATTR));
		newattr->Next = NULL;
		newattr->Name = wcsdup(name);
		newattr->Value = NULL;
		if (attr->Value)
		{
			newattr->Value = wcsdup(attr->Value);
		}
		if (item->FirstAttr)
		{
			item->LastAttr->Next = newattr;
		}
		else
		{
			item->FirstAttr = newattr;
		}
		item->LastAttr = newattr;
	}
}

/* ---------------------------------------------------------------------
 * EisMenuGetObjectData
 * Find first occurence of object data 
 * ---------------------------------------------------------------------
 */
static wchar_t*
EisMenuGetObjectData(EISMENU* eismenu, XMLOBJECT* ob)
{
	if (ob)
	{
		XMLNODE* node = ob->FirstNode;
		while(node)
		{
			if ((node->Type == XML_DATANODE) && (node->Data))
			{
				const wchar_t* pos = wcsstr(node->Data, _T("$PACKAGE"));
				if (pos && eismenu->Package)
				{
					wchar_t* buffer = (wchar_t*) malloc((wcslen(node->Data) +
						wcslen(eismenu->Package) + 1) * sizeof(wchar_t));

					wcsncpy(buffer,node->Data,pos - node->Data);
					buffer[pos - node->Data] = 0;
					wcscat(buffer,eismenu->Package);
					wcscat(buffer,pos + 8);
					return buffer;
				}
				else
				{
					return wcsdup(node->Data);
				}
			}
			node = (XMLNODE*) node->Next;
		}
	}
	return wcsdup(_T(""));
}

/* ---------------------------------------------------------------------
 * EisMenuReadXmlNode
 * Read an object Node containing new xml-menu data
 * ---------------------------------------------------------------------
 */
static void
EisMenuReadXmlNode(EISMENU* eismenu, XMLNODE* node)
{
	XMLOBJECT* object = node->Object;
	EISMENUITEM* newitem;

	if (wcscasecmp(object->Name, _T("TITLE")) == 0)
	{
		if (eismenu->Title) 
		{
			free(eismenu->Title);
		}
		eismenu->Title = EisMenuGetObjectData(eismenu,object);

		if ((int)(wcslen(eismenu->Title)) > eismenu->MaxWidth) 
		{
			eismenu->MaxWidth = wcslen(eismenu->Title);
		}
	}
	else if (wcscasecmp(object->Name, _T("PACKAGE")) == 0)
	{
		if (eismenu->Package) 
		{
			free(eismenu->Package);
		}
		eismenu->Package = EisMenuGetObjectData(eismenu,object);
	}
	else if (wcscasecmp(object->Name, _T("VERSION")) == 0)
	{
		EisMenuUpdateVersionTitle(eismenu);
	}
	else if (wcscasecmp(object->Name,_T("URL")) == 0)
	{
		EisMenuUpdateUrlTitle(eismenu);
	}
	else 
	{
		XMLATTRIBUTE* attr;
		
		newitem = (EISMENUITEM*) malloc(sizeof(EISMENUITEM));
		newitem->Next      = NULL;
		newitem->FirstAttr = NULL;
		newitem->LastAttr  = NULL;
		newitem->IsClassic = FALSE;
		newitem->IsVisible = TRUE;
		newitem->Name = EisMenuGetObjectData(eismenu, object);
		
		attr = XmlGetAttribute(object, _T("UI"));
		if (attr)
		{
			if (!EisMenuCheckUI(attr->Value))
			{
				newitem->IsVisible = FALSE;
			}
			EisMenuCopyAttr(newitem, object, _T("UI"));
		}

		EisMenuCopyAttr(newitem,object,_T("PRE"));
		EisMenuCopyAttr(newitem,object,_T("POST"));

		if (wcscasecmp(object->Name, _T("MENU")) == 0)
		{
			EisMenuCopyAttr(newitem,object,_T("FILE"));
			EisMenuCopyAttr(newitem,object,_T("PACKAGE"));
			newitem->Type = ITEMTYPE_MENU;
		}
		else if (wcscasecmp(object->Name, _T("DOC")) == 0)
		{
			EisMenuCopyAttr(newitem,object,_T("FILE"));
			EisMenuCopyAttr(newitem,object,_T("TAIL"));
			EisMenuCopyAttr(newitem,object,_T("ENCODING"));
			newitem->Type = ITEMTYPE_DOC;
		}
		else if (wcscasecmp(object->Name, _T("EDIT")) == 0)
		{
			EisMenuCopyAttr(newitem,object, _T("PACKAGE"));
			EisMenuCopyAttr(newitem,object, _T("STOPSTART"));
			newitem->Type = ITEMTYPE_EDIT;
		}
		else if (wcscasecmp(object->Name, _T("INIT")) == 0)
		{
			EisMenuCopyAttr(newitem,object, _T("TASK"));
			EisMenuCopyAttr(newitem,object, _T("PACKAGE"));
			newitem->Type = ITEMTYPE_INIT;
		}
		else if (wcscasecmp(object->Name, _T("SCRIPT")) == 0)
		{
			EisMenuCopyAttr(newitem,object, _T("FILE"));
			newitem->Type = ITEMTYPE_SCRIPT;
		}
		else
		{
			newitem->Type = ITEMTYPE_UNKNOWN;
		}

		if (!eismenu->LastItem) 
		{
			eismenu->FirstItem = newitem;
		}
		else 
		{
			eismenu->LastItem->Next = newitem;
		}
		eismenu->LastItem = newitem;
		
		if (newitem->IsVisible)
		{
			eismenu->NumVisItems++;
			
			if ((int)wcslen(newitem->Name) > eismenu->MaxWidth) 
			{
				eismenu->MaxWidth = wcslen(newitem->Name);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * EisMenuClassicNode
 * Read a data node, that contains classic menu data
 * ---------------------------------------------------------------------
 */
static void
EisMenuReadClassicNode(EISMENU* eismenu, XMLNODE* node, int first)
{
	wchar_t  buffer[256+1];

	wchar_t* pos1 = EisMenuKillSpaces(node->Data);
	wchar_t* pos2;
	int   len;

	pos2 = wcschr(pos1,_T('\n'));
	while(pos1)
	{
		if (pos2)
		{
			len = pos2 - pos1;
		}
		else
		{
			len = wcslen(pos1);
		}
		if (len > 255) len = 255;

		if (len > 0)
		{
			wchar_t* split;

			wcsncpy(buffer,pos1,len);
			buffer[len] = 0;

			if (first)
			{
				if (eismenu->Title) 
				{
					free(eismenu->Title);
				}
				eismenu->Title = wcsdup(buffer);

				if ((int)(wcslen(eismenu->Title)) > eismenu->MaxWidth) 
				{
					eismenu->MaxWidth = wcslen(eismenu->Title);
				}

				first = FALSE;
			}
			else
			{
				split = wcschr(buffer,_T(' '));
				if (split)
				{
					wchar_t menuname[256+1];
					EISMENUITEM* newitem;
		
					*split = 0; 
					split = EisMenuKillSpaces(split + 1);

					newitem = (EISMENUITEM*) malloc(sizeof(EISMENUITEM));
					newitem->Name      = wcsdup(split);
					newitem->Next      = NULL;
					newitem->IsClassic = TRUE;
					newitem->IsVisible = TRUE;
					newitem->FirstAttr = (EISMENUATTR*) malloc(sizeof(EISMENUATTR));
					newitem->FirstAttr->Name = wcsdup(_T("SCRIPT"));
					newitem->FirstAttr->Value = wcsdup(buffer);
					newitem->FirstAttr->Next  = (EISMENUATTR*) malloc(sizeof(EISMENUATTR));
					newitem->LastAttr = newitem->FirstAttr->Next;
					newitem->LastAttr->Name = wcsdup(_T("FILE"));
					newitem->LastAttr->Next = NULL;
					
					if (EisMenuGetNextMenu(buffer,menuname,255))
					{
						newitem->Type = ITEMTYPE_MENU;
						newitem->LastAttr->Value = wcsdup(menuname);
					}
					else
					{
						newitem->Type = ITEMTYPE_SCRIPT;
						newitem->LastAttr->Value = wcsdup(buffer);
					}

					if (!eismenu->LastItem) 
					{
						eismenu->FirstItem = newitem;
					}
					else 
					{
						eismenu->LastItem->Next = newitem;
					}
					eismenu->LastItem = newitem;
			
					if ((int)wcslen(newitem->Name) > eismenu->MaxWidth) 
					{
						eismenu->MaxWidth = wcslen(newitem->Name);
					}
					eismenu->NumVisItems++;
				}
			}
		}

		if (pos2)
		{
			pos1 = EisMenuKillSpaces(pos2 + 1);
			pos2 = wcschr(pos1, _T('\n'));
		}
		else 
		{
			pos1 = NULL;
		}
	}
}


/* ---------------------------------------------------------------------
 * EisMenuCheckUI
 * Check if argument string "uistr" contains the token "cui". This is used
 * to check if a menu item is visible in a CUI environment or not.
 * Note that the string may contain several interface names separated
 * by comma (i.e. "cui,webconf,classic").
 * ---------------------------------------------------------------------
 */
static int
EisMenuCheckUI(const wchar_t *uistr)
{
	wchar_t *tmpstr = wcsdup(uistr);
	if (tmpstr)
	{
		wchar_t *sp;
		wchar_t *tok = wcstok(tmpstr, _T(" ,"), &sp);
		
		while (tok != NULL)
		{
			if (wcscasecmp(tok, _T("cui")) == 0)
			{
				free(tmpstr);
				return TRUE;
			}
			tok = wcstok(NULL, _T(" ,"), &sp);
		}
		free(tmpstr);
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * EisMenuWriteLowcase
 * Write string in low-case letters
 * ---------------------------------------------------------------------
 */
static void
EisMenuWriteToFile(const wchar_t* text, FILE* out)
{
	mbstate_t state;
	char         buffer[128 + 1];
	int          size = 0;
	
	memset(&state, 0, sizeof(state));

	do
	{
		size = wcsrtombs(buffer, &text, 128, &state);
		if (size > 0)
		{
			fwrite(buffer, 1, size, out);
		}
	}
	while ((size > 0) && (text != NULL));
}

/* ---------------------------------------------------------------------
 * EisMenuUpdateVersionTitle
 * Update kernel version in menu title
 * ---------------------------------------------------------------------
 */
static void
EisMenuUpdateVersionTitle(EISMENU* eismenu)
{
	wchar_t base[64 + 1];
	int len;

	EisMenuGetFileData(_T("/etc/alpine-release"), base, 64);

	if (eismenu->SubTitle) 
	{
		free(eismenu->SubTitle);
	}
	len = wcslen(base) + 25;
	eismenu->SubTitle = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

	swprintf(eismenu->SubTitle, len, _T("Release: %ls"), base);
}

/* ---------------------------------------------------------------------
 * EisMenuUpdateUrlTitle
 * Update URL in menu title
 * ---------------------------------------------------------------------
 */
static void
EisMenuUpdateUrlTitle(EISMENU* eismenu)
{
	wchar_t url[512 + 1];
	int len;

	EisMenuGetFileData(_T("/var/install/url"), url, 512);
	EisMenuRemoveLoginInfo(url);

	if (eismenu->SubTitle) 
	{
		free(eismenu->SubTitle);
	}
	len = wcslen(url) + 10;
	eismenu->SubTitle = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

	swprintf(eismenu->SubTitle, len, _T("URL: %ls"), url);
}

