/* ---------------------------------------------------------------------
 * File: mainwin.h
 * (application main window)
 *
 * Copyright (C) 2007
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
 *
 * Last Update:  $Id: mainwin.h 33438 2013-04-10 20:37:52Z dv $
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

#ifndef MAINWIN_H
#define MAINWIN_H

#include "global.h"

#define MAX_ARGS 128

typedef struct
{
	int            Color;
	int            NoColor;
	int            Mouse;
	int            NoMouse;
	int            Help;
	int            Version;
	wchar_t*         Title;
	wchar_t*         Column;
	char*          Path;
	char*          Filter[MAX_ARGS];
	int            FileTypeFilter;
	int            ColumnDate;
	int            ColumnMode;
	int            ColumnSize;
	int            ColumnUser;
	wchar_t*         Question;
	wchar_t*         ScriptFile;
	wchar_t*         HelpFile;
	wchar_t*         HelpName;
	int            ShowHelp;
	int            FileTypeN;
	int            Wait;
	wchar_t*         ShellCommand;
} PROGRAM_CONFIG;

typedef struct
{
	PROGRAM_CONFIG* Config;
	XMLFILE*        HelpData;
	wchar_t*          ErrorMsg;
	int             NumErrors;
	int             NumWarnings;
	wchar_t**         CUidList;
	int*            NUidList;
	int             NumUid;
	wchar_t**         CGidList;
	int*            NGidList;
	int             NumGid;
	int             NumColumns;
} MAINWINDATA;

CUIWINDOW* MainwinNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int sflags, int cflags);

XMLOBJECT* MainwinFindHelpEntry(CUIWINDOW* win, const wchar_t* topic);
void       MainwinSetConfig(CUIWINDOW* win, PROGRAM_CONFIG* cfg);

void       MainwinFreeMessage(CUIWINDOW* win);
void       MainwinAddMessage(CUIWINDOW* win, const wchar_t* msg);

#endif
