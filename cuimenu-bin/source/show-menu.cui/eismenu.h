/* ---------------------------------------------------------------------
 * File: eismenu.h
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
             
#ifndef EISMENU_H
#define EISMENU_H
                             
#include "global.h"

#define ITEMTYPE_UNKNOWN  0             /* Ignored menu items */
#define ITEMTYPE_MENU     1             /* Sub menu */
#define ITEMTYPE_DOC      2             /* Show documentation */
#define ITEMTYPE_EDIT     3             /* Edit configuration */
#define ITEMTYPE_INIT     4             /* Manage linux service */
#define ITEMTYPE_SCRIPT   5             /* Execute a shell script */

typedef struct EISMENUATTRStruct
{
	wchar_t*       Name;             /* Name of attribute */
	wchar_t*       Value;            /* value of attribute */
	void*          Next;             /* Next attribute */
} EISMENUATTR;

typedef struct EISMENUITEMStruct
{
	wchar_t*       Name;             /* Name to display in menu */
	int            Type;             /* Type of menu item */
	EISMENUATTR*   FirstAttr;        /* First attribute */
	EISMENUATTR*   LastAttr;         /* Last attribute */
	int            IsClassic;        /* Item read from an non xml entry */
	int            IsVisible;        /* Item is not marked as "classic"-menu-only */
	void*          Next;             /* Next menu item */
} EISMENUITEM;

typedef struct EISMENUCMMTStruct
{
	wchar_t*       Data;              /* Comment data */
	void*          Next;              /* Next comment entry */
} EISMENUCMMT;

typedef struct EISMENUPOSTStruct
{
	wchar_t*        ScriptFile;        /* Execute when the menu is closed */
	wchar_t*        PackageName;       /* Name of package(s) */
	wchar_t*        MenuFile;          /* Menu file name */
} EISMENUPOST;
        
typedef struct EISFAIRMENUStruct
{
	EISMENUITEM*    FirstItem;        /* First menu item */
	EISMENUITEM*    LastItem;         /* Last menu item */

	EISMENUCMMT*    FirstComment;     /* First comment entry */
	EISMENUCMMT*    LastComment;      /* Last comment entry */

	EISMENUPOST*    PostProcess;      /* Post process information */

	wchar_t*        Filename;         /* Name of the menu file */
	time_t          Filetime;         /* Modification time of the file */

	wchar_t*        Title;            /* Title of menu */
	wchar_t*        SubTitle;         /* Subtitle (version etc.) */
	wchar_t*        Package;          /* Name of package this menu belongs to */

	int             MaxWidth;         /* Max. Width required by menu items */
	int             NumVisItems;      /* Number of visible items in menu */
	int             Level;            /* Hierarchical level of menu */

	CUIWINDOW*      Menu;             /* Associated curses menu */
	int             LastChoice;       /* Index of currently selected item */

	void*           Next;             /* Next menu level = child menu */
	void*           Previous;         /* Previous menu level = parent menu */
} EISMENU;
                                                                                                       

EISMENU*     EisMenuCreate(void);
void         EisMenuReadFile(EISMENU* eismenu, 
                             const wchar_t* filename, 
                             ErrorCallback errout,
                             void* instance);
void         EisMenuWriteFile(EISMENU* eismenu, 
                             ErrorCallback errout, 
                             void* instance);
int          EisMenuUpdate(EISMENU* eismenu, 
                             ErrorCallback errout,
                             void* instance);

void         EisMenuAssignPackage(EISMENU* eismenu, const wchar_t* package);
EISMENUITEM* EisMenuAddItem(EISMENU* eismenu, const wchar_t* name, int type);
EISMENUATTR* EisMenuAddAttribute(EISMENUITEM* item, const wchar_t* name, const wchar_t* value);
void         EisMenuDelete(EISMENU* eismenu);
const wchar_t* EisMenuGetSubTitle(EISMENU* eismenu);
EISMENUATTR* EisMenuGetAttr(EISMENUITEM* item, const wchar_t* name);

CUIWINDOW*   EisMenuBuildGUI(EISMENU* eismenu, CUIWINDOW* parent, CUIWINDOW* mainwin);
void         EisMenuResize(CUIWINDOW* menu, EISMENU* eismenu, CUIWINDOW* mainwin);

EISMENUITEM* EisMenuGetItem(EISMENU* eismenu, int index);
EISMENUITEM* EisMenuMakeFirstItem(EISMENU* eismenu, const wchar_t* name);
EISMENUITEM* EisMenuMakeNextItem(EISMENUITEM* pos, const wchar_t* name);

#endif

