/* ---------------------------------------------------------------------
 * File: finddlg.h
 * (find text dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: finddlg.c 23497 2010-03-14 21:53:08Z dv $
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

#define IDC_BUTOK      10
#define IDC_BUTCANCEL  11
#define IDC_EDIT       12
#define IDC_WHOLEWORDS 13
#define IDC_CASESENS   14
#define IDC_SEARCHUP   15
#define IDC_SEARCHDOWN 16

/* ---------------------------------------------------------------------
 * FindDlgButtonHook
 * Handle button events
 * ---------------------------------------------------------------------
 */
static void
FindDlgButtonHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = (CUIWINDOW*) c;
	FINDDLGDATA* data = (FINDDLGDATA*) win->InstData;

	if (ctrl->Id == IDOK)
	{
		ctrl = WindowGetCtrl(win, IDC_EDIT);
		if (ctrl)
		{
			EditGetText(ctrl, data->Keyword, 128);
			if (data->Keyword[0] == 0)
			{
				MessageBox(win,
					_T("No keyword specified!\nPlease enter a valid keyword to search for"),
					_T("Error"),
					MB_ERROR);
				WindowSetFocus(ctrl);
				return;
			}
		}
		ctrl = WindowGetCtrl(win, IDC_WHOLEWORDS);
		if (ctrl)
		{
			data->WholeWords = CheckboxGetCheck(ctrl);
		}
		ctrl = WindowGetCtrl(win, IDC_CASESENS);
		if (ctrl)
		{
			data->CaseSens = CheckboxGetCheck(ctrl);
		}
		ctrl = WindowGetCtrl(win, IDC_SEARCHUP);
		if (ctrl)
		{
			data->Direction = RadioGetCheck(ctrl) ? 
			    SEARCH_UP : SEARCH_DOWN;
		}
		WindowClose(win, IDOK);
	}
	else
	{
		WindowClose(win, IDCANCEL);
	}
}

/* ---------------------------------------------------------------------
 * FindDlgCreateHook
 * Create dialog controls
 * ---------------------------------------------------------------------
 */
static void
FindDlgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	FINDDLGDATA* data = (FINDDLGDATA*) win->InstData;

	ctrl = LabelNew(win, _T("Keyword:"), 2, 1, 12, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(win, data->Keyword, 12, 1, 42, 1, 128, IDC_EDIT, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = CheckboxNew(win, _T("&Whole Words Only"), 3, 3, 20, 1, IDC_WHOLEWORDS, CWS_NONE, CWS_NONE);
	CheckboxSetCheck(ctrl, data->WholeWords == TRUE);
	WindowCreate(ctrl);

	ctrl = CheckboxNew(win, _T("&Case Sensitive"), 3, 4, 20, 1, IDC_CASESENS, CWS_NONE, CWS_NONE);
	CheckboxSetCheck(ctrl, data->CaseSens == TRUE);
	WindowCreate(ctrl);

	ctrl = RadioNew(win, _T("Search &Up"), 30, 3, 20, 1, IDC_SEARCHUP, CWS_NONE, CWS_NONE);
	RadioSetCheck(ctrl, data->Direction == SEARCH_UP);
	WindowCreate(ctrl);

	ctrl = RadioNew(win, _T("Search &Down"), 30, 4, 20, 1, IDC_SEARCHDOWN, CWS_NONE, CWS_NONE);
	RadioSetCheck(ctrl, data->Direction == SEARCH_DOWN);
	WindowCreate(ctrl);
	
	ctrl = ButtonNew(win, _T("&OK"), 17, 6, 10, 1, IDOK, CWS_DEFOK, CWS_NONE);
	ButtonSetClickedHook(ctrl, FindDlgButtonHook, win);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&Cancel"), 29, 6, 10, 1, IDCANCEL, CWS_DEFCANCEL, CWS_NONE);
	ButtonSetClickedHook(ctrl, FindDlgButtonHook, win);
	WindowCreate(ctrl);
}

/* ---------------------------------------------------------------------
 * FindDlgDestroyHook
 * Destroy dialog data
 * ---------------------------------------------------------------------
 */
static void
FindDlgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}

/* ---------------------------------------------------------------------
 * FindDlgNew
 * Create a new dialog instance
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
FinddlgNew(CUIWINDOW* parent, const TCHAR* title, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* dlg;
		int flags = sflags | CWS_POPUP | CWS_BORDER | CWS_CENTERED;
		flags &= ~(cflags);

		dlg = WindowNew(parent, 0, 0, 58, 10, flags);
		dlg->Class = _T("FIND_DLG");
		WindowColScheme(dlg, _T("DIALOG"));
		WindowSetCreateHook(dlg, FindDlgCreateHook);
		WindowSetDestroyHook(dlg, FindDlgDestroyHook);

		dlg->InstData = (FINDDLGDATA*) malloc(sizeof(FINDDLGDATA));
		((FINDDLGDATA*)dlg->InstData)->Keyword[0] = 0;
		((FINDDLGDATA*)dlg->InstData)->WholeWords = FALSE;
		((FINDDLGDATA*)dlg->InstData)->CaseSens = FALSE;
		((FINDDLGDATA*)dlg->InstData)->Direction = SEARCH_UP;

		WindowSetText(dlg, title);
		return dlg;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * FindDlgGetData
 * Get a reference to the dialog data
 * ---------------------------------------------------------------------
 */
FINDDLGDATA*
FinddlgGetData(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("FIND_DLG")) == 0))
	{
		return (FINDDLGDATA*) win->InstData;
	}
	return NULL;
}

