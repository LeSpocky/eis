/* ---------------------------------------------------------------------
 * File: api.c
 * (basic script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api.c 25003 2010-07-17 05:50:58Z dv $
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, U
 * ---------------------------------------------------------------------
 */

#include "global.h"
#include "cui-script.h"
#include "cui-util.h"
#include "api.h"

/* ---------------------------------------------------------------------
 * ApiLookupWindow
 * Lookup window stub from handle
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ApiLookupWindow(unsigned long nr)
{
	WINDOWSTUB* stub = StubFind(nr);
	if (stub)
	{
		return stub->Window;
	}
	else
	{
		return WindowGetDesktop();
	}
}

/* ---------------------------------------------------------------------
 * ApiMessageBox
 * MessageBox API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiMessageBox(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		unsigned long wndnr = 0;
		int    res;
		int    flags = MB_OK;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[3], _T("%d"), &flags);

		res = MessageBox(ApiLookupWindow(wndnr), argv[1], argv[2], flags);

		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendInsertInt (res);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowNew
 * WindowNew API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowNew(int argc, const TCHAR* argv[])
{
	if (argc == 6)
	{
		WINDOWSTUB* stub;
		unsigned long wndnr;
		int    x, y, w, h;
		int    flags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &x);
		stscanf(argv[2], _T("%d"), &y);
		stscanf(argv[3], _T("%d"), &w);
		stscanf(argv[4], _T("%d"), &h);
		stscanf(argv[5], _T("%d"), &flags);

		stub = StubCreate(WindowNew(ApiLookupWindow(wndnr), x, y, w, h, flags));
		if (stub)
		{
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowCreate
 * WindowCreate API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowCreate(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowCreate(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowDestroy
 * WindowDestroy API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowDestroy(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowDestroy(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowQuit
 * WindowQuit API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowQuit(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		int   exitcode;

		stscanf(argv[0], _T("%d"), &exitcode);

		WindowQuit(exitcode);

		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowModal
 * WindowModal API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowModal(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;
		int            res;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			res = WindowModal(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (res);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowClose
 * WindowClose API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowClose(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;
		int            exitcode;
		int            res;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &exitcode);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			res = WindowClose(winstub->Window, exitcode);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (res);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetHook
 * WindowSetHook API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowSetHook(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           hook;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &hook);

		if ((hook >= HOOK_CREATE) && (hook <= HOOK_LAYOUT))
		{
			winstub = StubFind(wndnr);
			if (winstub)
			{
				StubSetHook(winstub, (HOOKTYPE) hook, argv[2]);

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetCtrl
 * WindowGetCtrl API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowGetCtrl(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &id);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			CUIWINDOW* ctrl = WindowGetCtrl(winstub->Window, id);
			if (ctrl)
			{
				winstub = StubFind((unsigned long)ctrl);
				if (!winstub)
				{
					StubCreate(ctrl);
				}
			}

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) ctrl);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetDesktop
 * WindowGetDesktop API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowGetDesktop(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		WINDOWSTUB*   winstub;

		CUIWINDOW* desktop = WindowGetDesktop();
		if (desktop)
		{
			winstub = StubFind((unsigned long)desktop);
			if (!winstub)
			{
				StubCreate(desktop);
			}
		}

		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendInsertLong((unsigned long) desktop);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowMove
 * WindowMove API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowMove(int argc, const TCHAR* argv[])
{
	if (argc == 5)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           x, y, w, h;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &x);
		stscanf(argv[2], _T("%d"), &y);
		stscanf(argv[3], _T("%d"), &w);
		stscanf(argv[4], _T("%d"), &h);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowMove(winstub->Window, x, y, w, h);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetWindowRect
 * WindowGetWindowRect API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowGetWindowRect(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		CUIRECT       rc;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowGetWindowRect(winstub->Window, &rc);

			BackendStartFrame(_T('R'), 128);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (rc.X);
			BackendInsertInt (rc.Y);
			BackendInsertInt (rc.W);
			BackendInsertInt (rc.H);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetClientRect
 * WindowGetClientRect API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowGetClientRect(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		CUIRECT       rc;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowGetClientRect(winstub->Window, &rc);

			BackendStartFrame(_T('R'), 128);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (rc.X);
			BackendInsertInt (rc.Y);
			BackendInsertInt (rc.W);
			BackendInsertInt (rc.H);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetTimer
 * WindowSetTimer API Wrapper
 * ---------------------------------------------------------------------
 */
void
ApiWindowSetTimer(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;
		int           time;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &id);
		stscanf(argv[2], _T("%d"), &time);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetTimer(winstub->Window, id, time);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowKillTimer
 * WindowKillTimer API Wrapper     
 * ---------------------------------------------------------------------
 */
void
ApiWindowKillTimer(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &id);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowKillTimer(winstub->Window, id);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowAddColScheme
 * WindowAddColScheme API Wrapper     
 * ---------------------------------------------------------------------
 */
void
ApiWindowAddColScheme(int argc, const TCHAR* argv[])
{
	if (argc == 12)
	{
		CUIWINCOLOR   colrec;

		stscanf(argv[1], _T("%d"), &colrec.WndColor);
		stscanf(argv[2], _T("%d"), &colrec.WndSelColor);
		stscanf(argv[3], _T("%d"), &colrec.SelTxtColor);
		stscanf(argv[4], _T("%d"), &colrec.WndTxtColor);
		stscanf(argv[5], _T("%d"), &colrec.InactTxtColor);
		stscanf(argv[6], _T("%d"), &colrec.HilightColor);
		stscanf(argv[7], _T("%d"), &colrec.TitleTxtColor);
		stscanf(argv[8], _T("%d"), &colrec.TitleBkgndColor);
		stscanf(argv[9], _T("%d"), &colrec.StatusTxtColor);
		stscanf(argv[10], _T("%d"), &colrec.StatusBkgndColor);
		stscanf(argv[11], _T("%d"), &colrec.BorderColor);

		WindowAddColScheme(argv[0], &colrec);

		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowHasColScheme
 * WindowHasColScheme API Wrapper     
 * ---------------------------------------------------------------------
 */
void
ApiWindowHasColScheme(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		int r = WindowHasColScheme(argv[0]);

		BackendStartFrame(_T('R'), 48);
		BackendInsertInt (ERROR_SUCCESS);
		BackendInsertInt (r);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowColScheme
 * WindowColScheme API Wrapper     
 * ---------------------------------------------------------------------
 */
void
ApiWindowColScheme(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowColScheme(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetText
 * WindowSetText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetRText
 * WindowSetRText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetRText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetRText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetLText
 * WindowSetLText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetLText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetLText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetStatusText
 * WindowSetStatusText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetStatusText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetStatusText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetRStatusText
 * WindowSetRStatusText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetRStatusText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetRStatusText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetLStatusText
 * WindowSetLStatusText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetLStatusText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetLStatusText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetText
 * WindowGetText API Wrapper     
 * ---------------------------------------------------------------------
 */
void 
ApiWindowGetText(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TCHAR* result = (TCHAR*) malloc((1024 + 1) * sizeof(TCHAR));
			if (result)
			{
				WindowGetText(winstub->Window, result, 1024);

				BackendStartFrame(_T('R'), tcslen(result) + 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendInsertStr (result);
				BackendSendFrame ();
				free(result);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowToTop
 * WindowToTop API Wrapper            
 * ---------------------------------------------------------------------
 */
void 
ApiWindowToTop(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowToTop(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowMaximize
 * WindowMaximize API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowMaximize(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &state);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowMaximize(winstub->Window, state);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowMinimize
 * WindowMinimize API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowMinimize(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &state);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowMinimize(winstub->Window, state);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowHide
 * WindowHide API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowHide(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &state);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowHide(winstub->Window, state);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowEnable
 * WindowEnable API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowEnable(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &state);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowEnable(winstub->Window, state);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowSetFocus
 * WindowSetFocus API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowSetFocus(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowSetFocus(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowGetFocus
 * WindowGetFocus API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowGetFocus(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		WINDOWSTUB*   winstub = NULL;

		CUIWINDOW* fwin = WindowGetFocus();
		if (fwin)
		{
			winstub = StubFind((unsigned long)fwin);
			if (!winstub)
			{
				StubCreate(fwin);
			}
		}

		BackendStartFrame(_T('R'), 48);
		BackendInsertInt (ERROR_SUCCESS);
		BackendInsertLong((unsigned long) fwin);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowInvalidate
 * WindowInvalidate API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowInvalidate(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowInvalidate(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowInvalidateLayout
 * WindowInvalidateLayout API Wrapper              
 * ---------------------------------------------------------------------
 */
void
ApiWindowInvalidateLayout(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			WindowInvalidateLayout(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowUpdate
 * WindowUpdate API Wrapper              
 * ---------------------------------------------------------------------
 */
void 
ApiWindowUpdate(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		WindowUpdate();

		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowCursesLeave
 * Leave Curses mode, goto console text mode
 * ---------------------------------------------------------------------
 */
void
ApiWindowCursesLeave(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		WindowLeaveCurses();
		
		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowCursesLeave
 * Leave console text mode, resume curses mode
 * ---------------------------------------------------------------------
 */
void
ApiWindowCursesResume(int argc, const TCHAR* argv[])
{
	if (argc == 0)
	{
		WindowResumeCurses();
		
		BackendStartFrame(_T('R'), 32);
		BackendInsertInt (ERROR_SUCCESS);
		BackendSendFrame ();
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiWindowShellExecute
 * Execute a shell command (when in text mode)
 * ---------------------------------------------------------------------
 */
void
ApiWindowShellExecute(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		char *cmd = TCharToMbDup(argv[0]);
		if (cmd)
		{
			int res = system(cmd);
		
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (res);
			BackendSendFrame ();
			
			free(cmd);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

