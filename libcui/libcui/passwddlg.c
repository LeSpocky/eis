/* ---------------------------------------------------------------------
 * File: passwddlg.h
 * (enter password dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: passwddlg.c 33402 2013-04-02 21:32:17Z dv $
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

#include "cui.h"

#define IDC_EDTEXT1    10
#define IDC_EDTEXT2    11


/* ---------------------------------------------------------------------
 * PasswddlgButtonHook
 * Handle button events
 * ---------------------------------------------------------------------
 */
static void
PasswddlgButtonHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = (CUIWINDOW*) c;
	PASSWDDLGDATA* data = (PASSWDDLGDATA*) win->InstData;

	if (ctrl->Id == IDOK)
	{
		ctrl = WindowGetCtrl(win, IDC_EDTEXT1);
		if (ctrl)
		{
			EditGetText(ctrl, data->Password, MAX_PASSWD_SIZE);
		}
		ctrl = WindowGetCtrl(win, IDC_EDTEXT2);
		if (ctrl)
		{
			wchar_t cmptext[MAX_PASSWD_SIZE + 1];

			EditGetText(ctrl, cmptext, MAX_PASSWD_SIZE);
			if (wcscmp(cmptext, data->Password) != 0)
			{
				MessageBox(win,
				           _T("Passwords to not match! Please enter them again."),
				           _T("Error"),
				           MB_ERROR);
				EditResetInput(ctrl);

				ctrl = WindowGetCtrl(win, IDC_EDTEXT1);
				if (ctrl)
				{
					EditResetInput(ctrl);
					WindowSetFocus(ctrl);
				}

				return;
			}
		}
		WindowClose(win, IDOK);
	}
	else
	{
		WindowClose(win, IDCANCEL);
	}
}


/* ---------------------------------------------------------------------
 * PasswddlgCreateHook
 * Create dialog controls
 * ---------------------------------------------------------------------
 */
static void
PasswddlgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	PASSWDDLGDATA* data = (PASSWDDLGDATA*) win->InstData;

	ctrl = LabelNew(win, _T("Enter Password:"), 1, 1, 15, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(win, data->Password, 18, 1, 30, 1, 128, IDC_EDTEXT1, EF_PASSWORD, CWS_NONE);
	WindowSetFocus(ctrl);
	WindowCreate(ctrl);

	ctrl = LabelNew(win, _T("Retype Password:"), 1, 3, 15, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(win, data->Password, 18, 3, 30, 1, 128, IDC_EDTEXT2, EF_PASSWORD, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&OK"), 14, 6, 10, 1, IDOK, CWS_DEFOK, CWS_NONE);
	ButtonSetClickedHook(ctrl, PasswddlgButtonHook, win);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&Cancel"), 27, 6, 10, 1, IDCANCEL, CWS_DEFCANCEL, CWS_NONE);
	ButtonSetClickedHook(ctrl, PasswddlgButtonHook, win);
	WindowCreate(ctrl);
}


/* ---------------------------------------------------------------------
 * PasswddlgDestroyHook
 * Destroy dialog data
 * ---------------------------------------------------------------------
 */
static void
PasswddlgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}


/* ---------------------------------------------------------------------
 * PasswddlgNew
 * Create a new dialog instance
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
PasswddlgNew(CUIWINDOW* parent, const wchar_t* title, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* dlg;
		int flags = sflags | CWS_POPUP | CWS_BORDER | CWS_CENTERED;
		flags &= ~(cflags);

		dlg = WindowNew(parent, 0, 0, 51, 10, flags);
		dlg->Class = _T("PASSWD_DLG");
		WindowColScheme(dlg, _T("DIALOG"));
		WindowSetCreateHook(dlg, PasswddlgCreateHook);
		WindowSetDestroyHook(dlg, PasswddlgDestroyHook);

		dlg->InstData = (PASSWDDLGDATA*) malloc(sizeof(PASSWDDLGDATA));
		((PASSWDDLGDATA*)dlg->InstData)->Password[0] = 0;

		WindowSetText(dlg, title);
		return dlg;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * PasswddlgGetData
 * Get a reference to the dialog data
 * ---------------------------------------------------------------------
 */
PASSWDDLGDATA*
PasswddlgGetData(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("PASSWD_DLG")) == 0))
	{
		return (PASSWDDLGDATA*) win->InstData;
	}
	return NULL;
}


