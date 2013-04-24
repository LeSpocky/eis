/* ---------------------------------------------------------------------
 * File: mainwin.h
 * (application main window)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: mainwin.h 33437 2013-04-10 20:37:24Z dv $
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
#include "expfile.h"
#include "conffile.h"

typedef struct
{
	int            Color;
	int            NoColor;
	int            Mouse;
	int            NoMouse;
	int            Help;
	int            Version;

	int            Debug;

	int            BeTolerant;
	int            CheckOnly;
	int            RunMkfli4l;

	EXPFILE*       RegExpData;
	CONFFILE*      ConfData;
	int            NumErrors;
	int            NumWarnings;

	wchar_t*       ConfigName;
	wchar_t*       CheckFileName;
	wchar_t*       TempConfFileName;
	wchar_t*       ExpFileName;
	wchar_t*       ConfFileName;
	wchar_t*       DefaultFileName;
	wchar_t*       HelpFileName;
	wchar_t*       LogFileName;
	wchar_t*       ConfigFileBase;   /* base directory for config files */
	wchar_t*       CheckFileBase;    /* base directory for check files */
	wchar_t*       DefaultFileBase;  /* base directory for default cfg files */
	wchar_t*       HelpFileBase;     /* base directory for help files */
	wchar_t*       DefaultExtention; /* default extension for cfg files */
	wchar_t*       MenuConfigFile;   /* config file for colors and style */
	wchar_t*       DialogPath;       /* path where to file dialog scripts */
} PROGRAM_CONFIG;

typedef struct
{
	PROGRAM_CONFIG* Config;
	int             ShowHelp;
	XMLFILE*        HelpData;
	wchar_t*        ErrorMsg;
	FINDDLGDATA     FindData;
} MAINWINDATA;

CUIWINDOW* MainwinNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int sflags, int cflags);

XMLOBJECT* MainwinFindHelpEntry(CUIWINDOW* win, const wchar_t* topic);
void       MainwinSetConfig(CUIWINDOW* win, PROGRAM_CONFIG* cfg);

void       MainwinFreeMessage(CUIWINDOW* win);
void       MainwinAddMessage(CUIWINDOW* win, const wchar_t* msg);

int        MainwinCopyFile(const wchar_t* sfile, const wchar_t* tfile);

int        MainwinReadExpressions(CUIWINDOW* win, PROGRAM_CONFIG* cfg, ErrorCallback errout);
int        MainwinReadConfig(CUIWINDOW* win, PROGRAM_CONFIG* cfg, ErrorCallback errout);

#endif
