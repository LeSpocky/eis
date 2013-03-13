/* ---------------------------------------------------------------------
 * File: api.h
 * (basic script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api.h 25003 2010-07-17 05:50:58Z dv $
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
#ifndef API_H
#define API_H

#include "cui.h"

#define API_MESSAGEBOX            0
#define API_WINDOWNEW             1
#define API_WINDOWCREATE          2
#define API_WINDOWDESTROY         3
#define API_WINDOWQUIT            4
#define API_WINDOWMODAL           5
#define API_WINDOWCLOSE           6
#define API_WINDOWSETHOOK         7

#define API_WINDOWGETCTRL        10
#define API_WINDOWGETDESKTOP     11
#define API_WINDOWMOVE           12
#define API_WINDOWGETWINDOWRECT  13
#define API_WINDOWGETCLIENTRECT  14

#define API_WINDOWSETTIMER       20
#define API_WINDOWKILLTIMER      21

#define API_WINDOWADDCOLSCHEME   30
#define API_WINDOWHASCOLSCHEME   31
#define API_WINDOWCOLSCHEME      32

#define API_WINDOWSETTEXT        40
#define API_WINDOWSETLTEXT       41
#define API_WINDOWSETRTEXT       42
#define API_WINDOWSETSTATUSTEXT  43
#define API_WINDOWSETLSTATUSTEXT 44
#define API_WINDOWSETRSTATUSTEXT 45
#define API_WINDOWGETTEXT        46

#define API_WINDOWTOTOP          50
#define API_WINDOWMAXIMIZE       51
#define API_WINDOWMINIMIZE       52
#define API_WINDOWHIDE           53
#define API_WINDOWENABLE         54
#define API_WINDOWSETFOCUS       55
#define API_WINDOWGETFOCUS       56

#define API_WINDOWINVALIDATE        60
#define API_WINDOWINVALIDATELAYOUT  61
#define API_WINDOWUPDATE            62

#define API_WINDOW_CURSES_LEAVE     70
#define API_WINDOW_CURSES_RESUME    71
#define API_WINDOW_SHELL_EXECUTE    72



CUIWINDOW* ApiLookupWindow(unsigned long nr);

void ApiMessageBox(int argc, const TCHAR* argv[]);
void ApiWindowNew(int argc, const TCHAR* argv[]);
void ApiWindowCreate(int argc, const TCHAR* argv[]);
void ApiWindowDestroy(int argc, const TCHAR* argv[]);
void ApiWindowQuit(int argc, const TCHAR* argv[]);
void ApiWindowModal(int argc, const TCHAR* argv[]);
void ApiWindowClose(int argc, const TCHAR* argv[]);
void ApiWindowSetHook(int argc, const TCHAR* argv[]);

void ApiWindowGetCtrl(int argc, const TCHAR* argv[]);
void ApiWindowGetDesktop(int argc, const TCHAR* argv[]);
void ApiWindowMove(int argc, const TCHAR* argv[]);
void ApiWindowGetWindowRect(int argc, const TCHAR* argv[]);
void ApiWindowGetClientRect(int argc, const TCHAR* argv[]);

void ApiWindowSetTimer(int argc, const TCHAR* argv[]);
void ApiWindowKillTimer(int argc, const TCHAR* argv[]);

void ApiWindowAddColScheme(int argc, const TCHAR* argv[]);
void ApiWindowHasColScheme(int argc, const TCHAR* argv[]);
void ApiWindowColScheme(int argc, const TCHAR* argv[]);

void ApiWindowSetText(int argc, const TCHAR* argv[]);
void ApiWindowSetRText(int argc, const TCHAR* argv[]);
void ApiWindowSetLText(int argc, const TCHAR* argv[]);
void ApiWindowSetStatusText(int argc, const TCHAR* argv[]);
void ApiWindowSetRStatusText(int argc, const TCHAR* argv[]);
void ApiWindowSetLStatusText(int argc, const TCHAR* argv[]);
void ApiWindowGetText(int argc, const TCHAR* argv[]);

void ApiWindowToTop(int argc, const TCHAR* argv[]);
void ApiWindowMaximize(int argc, const TCHAR* argv[]);
void ApiWindowMinimize(int argc, const TCHAR* argv[]);
void ApiWindowHide(int argc, const TCHAR* argv[]);
void ApiWindowEnable(int argc, const TCHAR* argv[]);
void ApiWindowSetFocus(int argc, const TCHAR* argv[]);
void ApiWindowGetFocus(int argc, const TCHAR* argv[]);

void ApiWindowInvalidate(int argc, const TCHAR* argv[]);
void ApiWindowInvalidateLayout(int argc, const TCHAR* argv[]);
void ApiWindowUpdate(int argc, const TCHAR* argv[]);

void ApiWindowCursesLeave(int argc, const TCHAR* argv[]);
void ApiWindowCursesResume(int argc, const TCHAR* argv[]);
void ApiWindowShellExecute(int argc, const TCHAR* argv[]);


#endif
