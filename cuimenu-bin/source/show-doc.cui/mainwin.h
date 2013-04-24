/* ---------------------------------------------------------------------
 * File: mainwin.h
 * (application main window)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: mainwin.h 33459 2013-04-13 10:13:16Z dv $
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
#include "index.h"

typedef struct
{
	int            Color;
	int            NoColor;
	int            NoFrame;
	int            Mouse;
	int            NoMouse;
	int            Help;
	int            Version;
	int            Follow;
	int            TmpFile;
	wchar_t       *Filename;
	wchar_t       *Indexfile;
	wchar_t       *Title;
	wchar_t       *Encoding;
} PROGRAM_CONFIG;

typedef struct
{
	PROGRAM_CONFIG *Config;
	INDEX          *FileIndex;
	XMLFILE        *HelpData;
	wchar_t        *ErrorMsg;
	int             NumErrors;
	int             NumWarnings;
	int             TailOn;
	int             LastIndexChoice;
	CUIWINDOW      *TextWin;
	FINDDLGDATA     FindData;
} MAINWINDATA;

CUIWINDOW *MainwinNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
           int sflags, int cflags);

XMLOBJECT *MainwinFindHelpEntry(CUIWINDOW* win, const wchar_t* topic);
void       MainwinSetConfig    (CUIWINDOW* win, PROGRAM_CONFIG* cfg);

void       MainwinFreeMessage  (CUIWINDOW* win);
void       MainwinAddMessage   (CUIWINDOW* win, const wchar_t* msg);

int        MainwinShellExecute (CUIWINDOW* win, const wchar_t* cmd, const wchar_t* title);

wchar_t   *MainwinMakeIndexFile(const wchar_t* file); 

#endif

