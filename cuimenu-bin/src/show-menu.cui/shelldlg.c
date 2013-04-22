/* ---------------------------------------------------------------------
 * File: shelldlg.c
 * (shell dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: shelldlg.c 26996 2010-12-19 11:24:25Z dv $
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

#include "shelldlg.h"

#define IDC_TERMINAL   10

#undef BE_VERBOSE

/* ---------------------------------------------------------------------
 * ShellDlgCoProcExitHook
 * CoProc terminate hook event
 * ---------------------------------------------------------------------
 */
static void 
ShellDlgCoProcExitHook(void* w, void* c, int code)
{
	TCHAR buffer[128 + 1];

#ifdef BE_VERBOSE
	stprintf(buffer, 128, _T("Terminated with exit code %i"), code);

	TerminalWrite((CUIWINDOW*) c, _T("\033[33m\033[1m"), tcslen(_T("\033[33m\033[1m")));
	TerminalWrite((CUIWINDOW*) c, buffer, tcslen(buffer));
	TerminalWrite((CUIWINDOW*) c, _T("\033[0m\n"), tcslen(_T("\033[0m\n")));
#endif

	tcscpy(buffer, _T("Press ENTER to continue"));
	TerminalWrite((CUIWINDOW*) c, _T("\033[33m\033[1m"), tcslen(_T("\033[33m\033[1m")));
	TerminalWrite((CUIWINDOW*) c, buffer, tcslen(buffer));
	TerminalWrite((CUIWINDOW*) c, _T("\033[0m"), tcslen(_T("\033[0m")));
}


/* ---------------------------------------------------------------------
 * ShellDlgCreateHook
 * Create dialog controls
 * ---------------------------------------------------------------------
 */
static void
ShellDlgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	SHELLDLGDATA* data = (SHELLDLGDATA*) win->InstData;
	CUIRECT rc;

	WindowGetClientRect(win, &rc);

	ctrl = TerminalNew(win, data->Title,  rc.X, rc.Y, rc.W, rc.H, IDC_TERMINAL, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);
	TerminalSetCoProcExitHook(ctrl, ShellDlgCoProcExitHook, win);
	
	TerminalWrite(ctrl, _T("\033[32m"), tcslen(_T("\033[32m")));
	TerminalWrite(ctrl, data->Command, tcslen(data->Command));
	TerminalWrite(ctrl, _T("\033[0m\n"), tcslen(_T("\033[0m\n")));
	TerminalRun(ctrl, data->Command);
}


/* ---------------------------------------------------------------------
 * ShellDlgDestroyHook
 * Destroy dialog data
 * ---------------------------------------------------------------------
 */
static void
ShellDlgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}


/* ---------------------------------------------------------------------
 * ShellDlgSizeHook
 * Handle size events
 * ---------------------------------------------------------------------
 */
static int
ShellDlgSizeHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	CUIRECT rc;

	WindowGetClientRect(win, &rc);

	ctrl = WindowGetCtrl(win, IDC_TERMINAL);
	if (ctrl)
	{
		WindowMove(ctrl, 0, 0, rc.W, rc.H);
	}
	return TRUE;
}


/* ---------------------------------------------------------------------
 * ShellDlgKeyHook
 * Handle key events
 * ---------------------------------------------------------------------
 */
static int
ShellDlgKeyHook(void* w, int key)
{
	if (key == KEY_RETURN)
	{
		WindowClose((CUIWINDOW*) w, IDOK);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ShellDlgNew
 * Create a new dialog instance
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ShellDlgNew(CUIWINDOW* parent, CUIRECT* rc, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* dlg;
		int flags = sflags | CWS_POPUP;
		flags &= ~(cflags | CWS_BORDER);

		dlg = WindowNew(parent, rc->X, rc->Y, rc->W, rc->H, flags);

		dlg->Class = _T("SHELL_DLG");
		WindowColScheme(dlg, _T("TERMINAL"));
		WindowSetCreateHook(dlg, ShellDlgCreateHook);
		WindowSetDestroyHook(dlg, ShellDlgDestroyHook);
		WindowSetSizeHook(dlg, ShellDlgSizeHook);
		WindowSetKeyHook(dlg, ShellDlgKeyHook);

		dlg->InstData = (SHELLDLGDATA*) malloc(sizeof(SHELLDLGDATA));
		((SHELLDLGDATA*)dlg->InstData)->Command[0] = 0;
		((SHELLDLGDATA*)dlg->InstData)->Title[0] = 0;
		((SHELLDLGDATA*)dlg->InstData)->ExitCode = 0;

		return dlg;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * ShellDlgGetData
 * Get a reference to the dialog data
 * ---------------------------------------------------------------------
 */
SHELLDLGDATA*
ShellDlgGetData(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("SHELL_DLG")) == 0))
	{
		return (SHELLDLGDATA*) win->InstData;
	}
	return NULL;
} 

