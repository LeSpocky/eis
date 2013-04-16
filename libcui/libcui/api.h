/* ---------------------------------------------------------------------
 * File: api.h
 * (basic script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api.h 33397 2013-04-02 20:48:05Z dv $
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

void ApiMessageBox(int argc, const wchar_t* argv[]);
void ApiWindowNew(int argc, const wchar_t* argv[]);
void ApiWindowCreate(int argc, const wchar_t* argv[]);
void ApiWindowDestroy(int argc, const wchar_t* argv[]);
void ApiWindowQuit(int argc, const wchar_t* argv[]);
void ApiWindowModal(int argc, const wchar_t* argv[]);
void ApiWindowClose(int argc, const wchar_t* argv[]);
void ApiWindowSetHook(int argc, const wchar_t* argv[]);

void ApiWindowGetCtrl(int argc, const wchar_t* argv[]);
void ApiWindowGetDesktop(int argc, const wchar_t* argv[]);
void ApiWindowMove(int argc, const wchar_t* argv[]);
void ApiWindowGetWindowRect(int argc, const wchar_t* argv[]);
void ApiWindowGetClientRect(int argc, const wchar_t* argv[]);

void ApiWindowSetTimer(int argc, const wchar_t* argv[]);
void ApiWindowKillTimer(int argc, const wchar_t* argv[]);

void ApiWindowAddColScheme(int argc, const wchar_t* argv[]);
void ApiWindowHasColScheme(int argc, const wchar_t* argv[]);
void ApiWindowColScheme(int argc, const wchar_t* argv[]);

void ApiWindowSetText(int argc, const wchar_t* argv[]);
void ApiWindowSetRText(int argc, const wchar_t* argv[]);
void ApiWindowSetLText(int argc, const wchar_t* argv[]);
void ApiWindowSetStatusText(int argc, const wchar_t* argv[]);
void ApiWindowSetRStatusText(int argc, const wchar_t* argv[]);
void ApiWindowSetLStatusText(int argc, const wchar_t* argv[]);
void ApiWindowGetText(int argc, const wchar_t* argv[]);

void ApiWindowToTop(int argc, const wchar_t* argv[]);
void ApiWindowMaximize(int argc, const wchar_t* argv[]);
void ApiWindowMinimize(int argc, const wchar_t* argv[]);
void ApiWindowHide(int argc, const wchar_t* argv[]);
void ApiWindowEnable(int argc, const wchar_t* argv[]);
void ApiWindowSetFocus(int argc, const wchar_t* argv[]);
void ApiWindowGetFocus(int argc, const wchar_t* argv[]);

void ApiWindowInvalidate(int argc, const wchar_t* argv[]);
void ApiWindowInvalidateLayout(int argc, const wchar_t* argv[]);
void ApiWindowUpdate(int argc, const wchar_t* argv[]);

void ApiWindowCursesLeave(int argc, const wchar_t* argv[]);
void ApiWindowCursesResume(int argc, const wchar_t* argv[]);
void ApiWindowShellExecute(int argc, const wchar_t* argv[]);


#endif
