/* ---------------------------------------------------------------------
 * File: edit.c
 * (edit control for dialog windows)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: edit.c 33402 2013-04-02 21:32:17Z dv $
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

typedef struct EDITDATAStruct
{
	int    Len;                 /* max length of edit text / size of buffer */
	int    CursorPos;           /* position of cursor in buffer */
	int    ScrollPos;           /* horizontal scroll offset */
	int    FirstChar;           /* Is this the first charater entered? */
	int    PasswChar;           /* Hide input character */
	wchar_t* EditText;            /* Text data of edit control */

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CustomHookProc          EditChangedHook;   /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*              EditChangedTarget; /* Custom callback target */
} EDITDATA;


/* ---------------------------------------------------------------------
 * CheckEditScrollPos
 * Check if the cursor is within the visible area of the control. If
 * necessary adjust scroll position
 * ---------------------------------------------------------------------
 */
static void
CheckEditScrollPos(CUIWINDOW* win)
{
	EDITDATA* data = (EDITDATA*) win->InstData;
	CUIRECT    rc;

	WindowGetClientRect(win, &rc);

	while (data->CursorPos > (data->ScrollPos + rc.W))
	{
		data->ScrollPos += (rc.W / 2);
	}
	while (data->CursorPos < data->ScrollPos)
	{
		data->ScrollPos -= (rc.W / 2);
		if (data->ScrollPos < 0) data->ScrollPos = 0;
	}
}

/* ---------------------------------------------------------------------
 * EditPaintHook
 * Handle PAINT events by redrawing the edit control
 * ---------------------------------------------------------------------
 */
static void
EditPaintHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	EDITDATA*  data;
	int x;
	int len;

	data = win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	len = wcslen(data->EditText);
	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndSelColor, TRUE);
	}

	MOVEYX(win->Win, 0, 0);
	for(x = 0; x < rc.W; x++)
	{
		if (x < (len - data->ScrollPos))
		{
			if (data->PasswChar)
			{
				waddch(win->Win, '*');
			}
			else
			{
				PRINTN(win->Win, &data->EditText[x + data->ScrollPos], 1);
			}
		}
		else
		{
			waddch(win->Win, ' ');
		}
	}
	WindowSetCursor(win, data->CursorPos - data->ScrollPos, 0);
}

/* ---------------------------------------------------------------------
 * EditKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
EditKeyHook(void* w, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	EDITDATA* data = (EDITDATA*) win->InstData;
	int       len  = wcslen(data->EditText);

	if (!data) return FALSE;

	if (win->IsEnabled)
	{
		/* if the key is processed by the custom callback hook, we
		   are over and done with it, else processing continues */
		if (data->PreKeyHook)
		{
			if (data->PreKeyHook(data->PreKeyTarget, win, key))
			{
				return TRUE;
			}
		}

		switch(key)
		{
		case KEY_RIGHT:
			if (data->CursorPos < len)
			{
				data->CursorPos++;
				CheckEditScrollPos(win);
				WindowInvalidate(win);
			}
			data->FirstChar = FALSE;
			return TRUE;
		case KEY_LEFT:
			if (data->CursorPos > 0)
			{
				data->CursorPos--;
				CheckEditScrollPos(win);
				WindowInvalidate(win);
			}
			data->FirstChar = FALSE;
			return TRUE;
		case KEY_HOME:
			if (data->CursorPos > 0)
			{
				data->CursorPos = 0;
				CheckEditScrollPos(win);
				WindowInvalidate(win);
			}
			data->FirstChar = FALSE;
			return TRUE;
		case KEY_END:
			if (data->CursorPos < len)
			{
				data->CursorPos = len;
				CheckEditScrollPos(win);
				WindowInvalidate(win);
			}
			data->FirstChar = FALSE;
			return TRUE;
		case KEY_BACKSPACE:
			if (data->CursorPos > 0)
			{
				int i;
				for (i = data->CursorPos - 1; i < len; i++)
				{
					data->EditText[i] = data->EditText[i + 1];
				}
				data->CursorPos--;

				if (data->EditChangedHook)
				{
					data->EditChangedHook(data->EditChangedTarget, win);
				}

				CheckEditScrollPos(win);
				WindowInvalidate(win);
			}
			data->FirstChar = FALSE;
			return TRUE;
		case KEY_DC:
			{
				int i;
				for (i = data->CursorPos; i < len; i++)
				{
					data->EditText[i] = data->EditText[i + 1];
				}

				if (data->EditChangedHook)
				{
					data->EditChangedHook(data->EditChangedTarget, win);
				}

				WindowInvalidate(win);
				data->FirstChar = FALSE;
			}
			return TRUE;
		default:
			if ((key >= ' ')&&(key <= 255))
			{
				if (len < data->Len)
				{
					if (!data->FirstChar)
					{
						int i;
						for (i = len; i >= data->CursorPos; i--)
						{
							data->EditText[i + 1] = data->EditText[i];
						}
					}
					else
					{
						data->EditText[1] = 0;
						data->CursorPos = 0;
					}
					data->EditText[data->CursorPos++] = key;

					if (data->EditChangedHook)
					{
						data->EditChangedHook(data->EditChangedTarget, win);
					}

					CheckEditScrollPos(win);
					WindowInvalidate(win);
				}
				data->FirstChar = FALSE;
				return TRUE;
			}

			if (data->PostKeyHook)
			{
				if (data->PostKeyHook(data->PostKeyTarget, win, key))
				{
					return TRUE;
				}
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * DestroyEditHook
 * Handle EVENT_DELETE events by deleting the edit's control data
 * ---------------------------------------------------------------------
 */
static void
EditDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	EDITDATA* data = (EDITDATA*) win->InstData;
	free(data->EditText);
	free(data);
}

/* ---------------------------------------------------------------------
 * EditSetFocus
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
EditSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	EDITDATA* data = (EDITDATA*) win->InstData;

	if (data)
	{
		WindowSetCursor(win, data->CursorPos - data->ScrollPos, 0);
		WindowCursorOn();

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * EditKillFocus
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
EditKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	EDITDATA* data = (EDITDATA*) win->InstData;

	if (data)
	{
		WindowCursorOff();
		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}


/* ---------------------------------------------------------------------
 * EditNew
 * Create a edit dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
EditNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
        int len, int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* edit;
		int flags = sflags | CWS_TABSTOP;
		flags &= ~(cflags);

		edit = WindowNew(parent, x, y, w, h, flags);
		edit->Class = _T("EDIT");
		WindowSetId(edit, id);
		WindowSetPaintHook(edit, EditPaintHook);
		WindowSetKeyHook(edit, EditKeyHook);
		WindowSetDestroyHook(edit, EditDestroyHook);
		WindowSetSetFocusHook(edit, EditSetFocusHook);
		WindowSetKillFocusHook(edit, EditKillFocusHook);

		edit->InstData = (EDITDATA*) malloc(sizeof(EDITDATA));
		((EDITDATA*)edit->InstData)->Len = len;
		((EDITDATA*)edit->InstData)->CursorPos = 0;
		((EDITDATA*)edit->InstData)->ScrollPos = 0;
		((EDITDATA*)edit->InstData)->FirstChar = TRUE;
		((EDITDATA*)edit->InstData)->PasswChar = (flags & EF_PASSWORD);
		((EDITDATA*)edit->InstData)->SetFocusHook    = NULL;
		((EDITDATA*)edit->InstData)->KillFocusHook   = NULL;
		((EDITDATA*)edit->InstData)->PreKeyHook      = NULL;
		((EDITDATA*)edit->InstData)->PostKeyHook     = NULL;
		((EDITDATA*)edit->InstData)->EditChangedHook = NULL;
		((EDITDATA*)edit->InstData)->EditText = malloc((len + 1) * sizeof(wchar_t));

		EditSetText(edit, text);

		return edit;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * EditSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
EditSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		((EDITDATA*)win->InstData)->SetFocusHook = proc;
		((EDITDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * EditSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
EditSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		((EDITDATA*)win->InstData)->KillFocusHook = proc;
		((EDITDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * EditSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
EditSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		((EDITDATA*)win->InstData)->PreKeyHook = proc;
		((EDITDATA*)win->InstData)->PreKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * EditSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
EditSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		((EDITDATA*)win->InstData)->PostKeyHook = proc;
		((EDITDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * EditSetChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
EditSetChangedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		((EDITDATA*)win->InstData)->EditChangedHook = proc;
		((EDITDATA*)win->InstData)->EditChangedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * EditSetText
 * Set edit text
 * ---------------------------------------------------------------------
 */
void
EditSetText(CUIWINDOW* win, const wchar_t* text)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		EDITDATA* data = (EDITDATA*) win->InstData;
		wcsncpy(data->EditText, text, data->Len);
		data->EditText[data->Len] = 0;
		data->CursorPos = 0;
		data->ScrollPos = 0;
		data->FirstChar = TRUE;

		if (win->IsCreated)
		{
			WindowInvalidate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * EditGetText
 * Get edit text
 * ---------------------------------------------------------------------
 */
const wchar_t*
EditGetText(CUIWINDOW* win, wchar_t* text, int len)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		EDITDATA* data = (EDITDATA*) win->InstData;
		wcsncpy(text, data->EditText, len);
		return text;
	}
	return _T("");
}

/* ---------------------------------------------------------------------
 * EditResetInput
 * Place the cursor at the beginning of the line and
 * set "firstchar" flag
 * ---------------------------------------------------------------------
 */
void
EditResetInput(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("EDIT")) == 0))
	{
		EDITDATA* data = (EDITDATA*) win->InstData;

		data->FirstChar = TRUE;
		data->CursorPos = 0;
		if (win->IsCreated)
		{
			WindowInvalidate(win);
		}
	}
}

