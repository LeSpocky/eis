/* ---------------------------------------------------------------------
 * File: createdlg.h
 * (create item dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: createdlg.c 23498 2010-03-14 21:57:47Z dv $
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

#include <cui.h>
#include "createdlg.h"

#define IDC_EDTEXT     10


/* prototypes */
static int CreatedlgCheckInput(CUIWINDOW* win);


/* ---------------------------------------------------------------------
 * CreatedlgButtonHook
 * Handle button events
 * ---------------------------------------------------------------------
 */
static void
CreatedlgButtonHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = (CUIWINDOW*) c;
	CREATEDLGDATA* data = (CREATEDLGDATA*) win->InstData;

	if (ctrl->Id == IDOK)
	{
		ctrl = WindowGetCtrl(win, IDC_EDTEXT);
		if (ctrl)
		{
			EditGetText(ctrl, data->Name, MAX_ITEM_SIZE);
			if (!CreatedlgCheckInput(win))
			{
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
 * CreatedlgCreateHook
 * Create dialog controls
 * ---------------------------------------------------------------------
 */
static void
CreatedlgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	CREATEDLGDATA* data = (CREATEDLGDATA*) win->InstData;

	ctrl = LabelNew(win, _T("Name:"), 1, 1, 10, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(win, data->Name, 11, 1, 42, 1, 1024, IDC_EDTEXT, CWS_NONE, CWS_NONE);
	WindowSetFocus(ctrl);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&OK"), 18, 4, 10, 1, IDOK, CWS_DEFOK, CWS_NONE);
	ButtonSetClickedHook(ctrl, CreatedlgButtonHook, win);
	WindowCreate(ctrl);

	ctrl = ButtonNew(win, _T("&Cancel"), 32, 4, 10, 1, IDCANCEL, CWS_DEFCANCEL, CWS_NONE);
	ButtonSetClickedHook(ctrl, CreatedlgButtonHook, win);
	WindowCreate(ctrl);
}

/* ---------------------------------------------------------------------
 * CreatedlgDestroyHook
 * Destroy dialog data
 * ---------------------------------------------------------------------
 */
static void
CreatedlgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}

/* ---------------------------------------------------------------------
 * CreatedlgNew
 * Create a new dialog instance
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
CreatedlgNew(CUIWINDOW* parent, const TCHAR* title, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* dlg;
		int flags = sflags | CWS_POPUP | CWS_BORDER | CWS_CENTERED;
		flags &= ~(cflags);

		dlg = WindowNew(parent, 0, 0, 58, 8, flags);
		dlg->Class = _T("CREATE_DLG");
		WindowColScheme(dlg, _T("DIALOG"));
		WindowSetCreateHook(dlg, CreatedlgCreateHook);
		WindowSetDestroyHook(dlg, CreatedlgDestroyHook);

		dlg->InstData = (CREATEDLGDATA*) malloc(sizeof(CREATEDLGDATA));
		((CREATEDLGDATA*)dlg->InstData)->Name[0] = 0;
		((CREATEDLGDATA*)dlg->InstData)->ConfData = NULL;

		WindowSetText(dlg, title);
		return dlg;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * CreatedlgGetData
 * Get a reference to the dialog data
 * ---------------------------------------------------------------------
 */
CREATEDLGDATA*
CreatedlgGetData(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("CREATE_DLG")) == 0))
	{
		return (CREATEDLGDATA*) win->InstData;
	}
	return NULL;
}


/* helper functions */

/* ---------------------------------------------------------------------
 * CreatedlgCheckInput
 * Check if the users input is valid
 * ---------------------------------------------------------------------
 */
static int
CreatedlgCheckInput(CUIWINDOW* win)
{
	CREATEDLGDATA* data = (CREATEDLGDATA*) win->InstData;
	int level = 0;

	if (tcslen(data->Name))
	{
		regex_t expr;
		int     res;

		res = RegCompile(&expr, _T("^[A-Za-z][A-Za-z0-9_%]*$"), REG_EXTENDED | REG_NOSUB | REG_NEWLINE);
		if (res == 0)
		{
			res = RegExec (&expr, data->Name, 0, NULL, 0);
		}
		RegFree(&expr);

		if (res != 0)
		{
			MessageBox(win, _T("The value specified in \"Name\" is invalid."),
				_T("Error"), MB_ERROR);
			WindowSetFocus(WindowGetCtrl(win, IDC_EDTEXT));
			return FALSE;
		}
		else
		{
			int cnt = 0;
			int len = tcslen(data->Name);
			int i;

			for (i = 0; i < len; i++)
			{
				data->Name[i] = totupper(data->Name[i]);
				if (data->Name[i] == _T('%'))
				{
					cnt++;
				}
			}

			if (cnt > level)
			{
				MessageBox(win, _T("The value specified in \"Name\" does contain too many ")
					_T("placeholders for index data."),
					_T("Error"), MB_ERROR);
				WindowSetFocus(WindowGetCtrl(win, IDC_EDTEXT));
				return FALSE;
			}
			else if (cnt < level)
			{
				MessageBox(win, _T("The value specified in \"Name\" does not contain enough ")
					_T("placeholders for index data."),
					_T("Error"), MB_ERROR);
				WindowSetFocus(WindowGetCtrl(win, IDC_EDTEXT));
				return FALSE;
			}
			else if (data->ConfData)
			{
				CONFITEM* item = ConfFileFindItem(data->ConfData, data->Name);
				if (item)
				{
					MessageBox(win, _T("The value specified in \"Name\" already exists."),
						_T("Error"), MB_ERROR);
					WindowSetFocus(WindowGetCtrl(win, IDC_EDTEXT));
					return FALSE;
				}
			}
		}
	}
	else
	{
		MessageBox(win, _T("Missing value in datafield \"Name\"."), _T("Error"), MB_ERROR);
		WindowSetFocus(WindowGetCtrl(win, IDC_EDTEXT));
		return FALSE;
	}
	return TRUE;
}

