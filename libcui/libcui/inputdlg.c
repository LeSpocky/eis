/* ---------------------------------------------------------------------
 * File: inputdlg.h
 * (input dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: inputdlg.c 33402 2013-04-02 21:32:17Z dv $
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

#define IDC_EDTEXT     10


/* ---------------------------------------------------------------------
 * InputdlgButtonHook
 * Handle button events
 * ---------------------------------------------------------------------
 */
static void
InputdlgButtonHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = (CUIWINDOW*) c;
	INPUTDLGDATA* data = (INPUTDLGDATA*) win->InstData;

	if (ctrl->Id == IDOK)
	{
		ctrl = WindowGetCtrl(win, IDC_EDTEXT);
		if (ctrl)
		{
			EditGetText(ctrl, data->Text, 1024);
		}
		WindowClose(win, IDOK);
	}
	else
	{
		WindowClose(win, IDCANCEL);
	}
}

/* ---------------------------------------------------------------------
 * InputdlgCreateHook
 * Create dialog controls
 * ---------------------------------------------------------------------
 */
static void
InputdlgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	INPUTDLGDATA* data = (INPUTDLGDATA*) win->InstData;

	ctrl = LabelNew(win, _T("Value:"), 1, 1, 10, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(win, data->Text, 11, 1, 42, 1, 1024, IDC_EDTEXT, CWS_NONE, CWS_NONE);
	WindowSetFocus(ctrl);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&OK"), 18, 4, 10, 1, IDOK, CWS_DEFOK, CWS_NONE);
	ButtonSetClickedHook(ctrl, InputdlgButtonHook, win);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&Cancel"), 32, 4, 10, 1, IDCANCEL, CWS_DEFCANCEL, CWS_NONE);
	ButtonSetClickedHook(ctrl, InputdlgButtonHook, win);
	WindowCreate(ctrl);
}

/* ---------------------------------------------------------------------
 * InputdlgDestroyHook
 * Destroy dialog data
 * ---------------------------------------------------------------------
 */
static void
InputdlgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}

/* ---------------------------------------------------------------------
 * InputdlgNew
 * Create a new dialog instance
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
InputdlgNew(CUIWINDOW* parent, const wchar_t* title, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* dlg;
		int flags = sflags | CWS_POPUP | CWS_BORDER | CWS_CENTERED;
		flags &= ~(cflags);

		dlg = WindowNew(parent, 0, 0, 58, 8, flags);
		dlg->Class = _T("INPUT_DLG");
		WindowColScheme(dlg, _T("DIALOG"));
		WindowSetCreateHook(dlg, InputdlgCreateHook);
		WindowSetDestroyHook(dlg, InputdlgDestroyHook);

		dlg->InstData = (INPUTDLGDATA*) malloc(sizeof(INPUTDLGDATA));
		((INPUTDLGDATA*)dlg->InstData)->Text[0] = 0;

		WindowSetText(dlg, title);
		return dlg;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * InputdlgGetData
 * Get a reference to the dialog data
 * ---------------------------------------------------------------------
 */
INPUTDLGDATA*
InputdlgGetData(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("INPUT_DLG")) == 0))
	{
		return (INPUTDLGDATA*) win->InstData;
	}
	return NULL;
}

