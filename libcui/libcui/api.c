/* ---------------------------------------------------------------------
 * File: api.c
 * (basic script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api.c 33467 2013-04-14 16:23:14Z dv $
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
ApiMessageBox(int argc, const wchar_t* argv[])
{
	if (argc == 4)
	{
		unsigned long wndnr = 0;
		int    res;
		int    flags = MB_OK;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[3], _T("%d"), &flags);

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
ApiWindowNew(int argc, const wchar_t* argv[])
{
	if (argc == 6)
	{
		WINDOWSTUB* stub;
		unsigned long wndnr;
		int    x, y, w, h;
		int    flags;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &x);
		swscanf(argv[2], _T("%d"), &y);
		swscanf(argv[3], _T("%d"), &w);
		swscanf(argv[4], _T("%d"), &h);
		swscanf(argv[5], _T("%d"), &flags);

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
ApiWindowCreate(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowDestroy(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowQuit(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		int   exitcode;

		swscanf(argv[0], _T("%d"), &exitcode);

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
ApiWindowModal(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;
		int            res;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowClose(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*    winstub;
		unsigned long  wndnr;
		int            exitcode;
		int            res;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &exitcode);

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
ApiWindowSetHook(int argc, const wchar_t* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           hook;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &hook);

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
ApiWindowGetCtrl(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &id);

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
ApiWindowGetDesktop(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);
	
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
ApiWindowMove(int argc, const wchar_t* argv[])
{
	if (argc == 5)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           x, y, w, h;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &x);
		swscanf(argv[2], _T("%d"), &y);
		swscanf(argv[3], _T("%d"), &w);
		swscanf(argv[4], _T("%d"), &h);

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
ApiWindowGetWindowRect(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		CUIRECT       rc;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowGetClientRect(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		CUIRECT       rc;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetTimer(int argc, const wchar_t* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;
		int           time;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &id);
		swscanf(argv[2], _T("%d"), &time);

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
ApiWindowKillTimer(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &id);

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
ApiWindowAddColScheme(int argc, const wchar_t* argv[])
{
	if (argc == 12)
	{
		CUIWINCOLOR   colrec;

		swscanf(argv[1], _T("%d"), &colrec.WndColor);
		swscanf(argv[2], _T("%d"), &colrec.WndSelColor);
		swscanf(argv[3], _T("%d"), &colrec.SelTxtColor);
		swscanf(argv[4], _T("%d"), &colrec.WndTxtColor);
		swscanf(argv[5], _T("%d"), &colrec.InactTxtColor);
		swscanf(argv[6], _T("%d"), &colrec.HilightColor);
		swscanf(argv[7], _T("%d"), &colrec.TitleTxtColor);
		swscanf(argv[8], _T("%d"), &colrec.TitleBkgndColor);
		swscanf(argv[9], _T("%d"), &colrec.StatusTxtColor);
		swscanf(argv[10], _T("%d"), &colrec.StatusBkgndColor);
		swscanf(argv[11], _T("%d"), &colrec.BorderColor);

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
ApiWindowHasColScheme(int argc, const wchar_t* argv[])
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
ApiWindowColScheme(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetRText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetLText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetStatusText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetRStatusText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowSetLStatusText(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowGetText(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			wchar_t* result = (wchar_t*) malloc((1024 + 1) * sizeof(wchar_t));
			if (result)
			{
				WindowGetText(winstub->Window, result, 1024);

				BackendStartFrame(_T('R'), wcslen(result) + 32);
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
ApiWindowToTop(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowMaximize(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &state);

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
ApiWindowMinimize(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &state);

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
ApiWindowHide(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &state);

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
ApiWindowEnable(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           state;

		swscanf(argv[0], _T("%ld"), &wndnr);
		swscanf(argv[1], _T("%d"), &state);

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
ApiWindowSetFocus(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowGetFocus(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);

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
ApiWindowInvalidate(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowInvalidateLayout(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		swscanf(argv[0], _T("%ld"), &wndnr);

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
ApiWindowUpdate(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);

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
ApiWindowCursesLeave(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);

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
ApiWindowCursesResume(int argc, const wchar_t* argv[])
{
	CUI_USE_ARG(argv);

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
ApiWindowShellExecute(int argc, const wchar_t* argv[])
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

