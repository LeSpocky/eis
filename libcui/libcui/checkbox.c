/* ---------------------------------------------------------------------
 * File: checkbox.c
 * (checkbox control for dialog windows)
 *   
 * Copyright (C) 2004
 * Daniel Vogel, <daniel_vogel@t-online.de>
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
#include "global.h"

typedef struct CHECKBOXDATAStruct
{
	CustomHook1PtrProc      SetFocusHook;        /* Custom callback */
	CustomHookProc          KillFocusHook;       /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;          /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;         /* Custom callback */
	CustomHookProc          ButtonClickedHook;   /* Custom callback */
	CUIWINDOW*              SetFocusTarget;      /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;     /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;        /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;       /* Custom callback target */
	CUIWINDOW*              ButtonClickedTarget; /* Custom callback target */
	int                     Checked;             /* Control is checked */
} CHECKBOXDATA;


static void CheckboxUpdate(CUIWINDOW* win);


/* ---------------------------------------------------------------------
 * EvPaintCheckbox
 * Handle EVENT_PAINT events by redrawing the checkbox button control
 * ---------------------------------------------------------------------
 */
static void
CheckboxPaintHook(void* w)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	CHECKBOXDATA*  data = (CHECKBOXDATA*) win->InstData;
	CUIRECT        rc;
	int            i;
	int            hkey_pos = 0;
	wchar_t        hkey = _T('\0');
	wchar_t        buffer[128 + 1];

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	if (rc.W > 1) 
	{
		int   pos, n;
		wchar_t* ch;
		wchar_t* ch2;

		for (i = 0; i < rc.W; i++) buffer[i] = _T(' ');
		buffer[i] = 0;
	
		buffer[0] = _T('[');
		if (data->Checked)
		{
			buffer[1] = _T('x');
		}
		buffer[2] = _T(']');

		pos = 4;
		ch  = win->Text;
		ch2 = (wchar_t*) wcschr(ch, _T('&'));
		while (ch2)
		{
			n = (pos + (ch2 - ch)) < 128 ? (ch2 - ch) : (128 - pos);

			wcsncpy(&buffer[pos], ch, n);
			pos += (ch2 - ch);
			hkey_pos = pos;

			ch = ch2 + 1;
			hkey = *ch;
			ch2 = (wchar_t*) wcschr(ch, _T('&'));
		}

		n = (pos + wcslen(ch)) < 128 ? (int)wcslen(ch) : (int)(128 - pos);
		wcsncpy(&buffer[pos], ch, n);
		buffer[128] = 0;
	}
	else 
	{
		buffer[0] = 0;
	}

	if (win->IsEnabled)
	{
		if (win == WindowGetFocus())
		{
			SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
		}
		else 
		{
			SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
		}
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	MOVEYX(win->Win, 0, 0); PRINT(win->Win, buffer);
	if ((hkey != _T('\0')) && (win->IsEnabled) && (win != WindowGetFocus()))
	{
		SetColor(win->Win, win->Color.HilightColor, win->Color.WndColor, FALSE);
		MOVEYX(win->Win, 0, hkey_pos); PRINTN(win->Win, &hkey, 1);
	}

	WindowSetCursor(win, 1, 0);
}

/* ---------------------------------------------------------------------
 * CheckboxKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
CheckboxKeyHook(void* w, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CHECKBOXDATA* data = (CHECKBOXDATA*) win->InstData;

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

		if ((key == KEY_SPACE) || ((key == win->HotKey) && (key != _T('\0'))))
		{
			if (win->Parent)
			{
				data->Checked = !data->Checked;
				WindowInvalidate(win);
			}

			if (data->ButtonClickedHook)
			{
				data->ButtonClickedHook(data->ButtonClickedTarget, win);
			}
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
	return FALSE;
}

/* ---------------------------------------------------------------------
 * CheckboxMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
CheckboxMButtonHook(void* w, int x, int y, int flags)
{
	CUI_USE_ARG(x);
	CUI_USE_ARG(y);
	
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED) || 
	    (flags & BUTTON1_TRIPLE_CLICKED) || (flags & BUTTON1_PRESSED))
	{
		CheckboxKeyHook(w, KEY_SPACE);
	}
}

/* ---------------------------------------------------------------------
 * CheckboxDestroyHook
 * Handle EVENT_DELETE events by deleting the checkbox's control data
 * ---------------------------------------------------------------------
 */
static void
CheckboxDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free (win->InstData);
}

/* ---------------------------------------------------------------------
 * CheckboxSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
CheckboxSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CHECKBOXDATA* data = (CHECKBOXDATA*) win->InstData;

	if (data)
	{
		WindowInvalidate(win);
		WindowCursorOn();
		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * CheckboxKillFocusHook
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
CheckboxKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CHECKBOXDATA* data = (CHECKBOXDATA*) win->InstData;

	if (data)
	{
		WindowInvalidate(win);
		WindowCursorOn();
		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}

/* ---------------------------------------------------------------------
 * CheckboxNew
 * Create a checkbox dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
CheckboxNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
            int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* checkbox;
		int flags = sflags | CWS_TABSTOP;
		flags &= ~(cflags);

		checkbox = WindowNew(parent, x, y, w, h, flags);
		checkbox->Class = _T("CHECKBOX");
		WindowSetId(checkbox, id);
		WindowSetPaintHook(checkbox, CheckboxPaintHook);
		WindowSetKeyHook(checkbox, CheckboxKeyHook);
		WindowSetDestroyHook(checkbox, CheckboxDestroyHook);
		WindowSetSetFocusHook(checkbox, CheckboxSetFocusHook);
		WindowSetKillFocusHook(checkbox, CheckboxKillFocusHook);
		WindowSetMButtonHook(checkbox, CheckboxMButtonHook);

                checkbox->InstData = (CHECKBOXDATA*) malloc(sizeof(CHECKBOXDATA));
                ((CHECKBOXDATA*)checkbox->InstData)->SetFocusHook    = NULL;
                ((CHECKBOXDATA*)checkbox->InstData)->KillFocusHook   = NULL;
		((CHECKBOXDATA*)checkbox->InstData)->PreKeyHook      = NULL;
		((CHECKBOXDATA*)checkbox->InstData)->PostKeyHook     = NULL;
                ((CHECKBOXDATA*)checkbox->InstData)->ButtonClickedHook = NULL;
		((CHECKBOXDATA*)checkbox->InstData)->Checked = FALSE;

                WindowSetText(checkbox, text);

                return checkbox;
        }
        return NULL;
}


/* ---------------------------------------------------------------------
 * CheckboxGetCheck
 * Read the check-state of the control
 * ---------------------------------------------------------------------
 */
int 
CheckboxGetCheck(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		return ((CHECKBOXDATA*)win->InstData)->Checked;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * CheckboxSetCheck
 * Set the check-state of the control
 * ---------------------------------------------------------------------
 */
void
CheckboxSetCheck(CUIWINDOW* win, int state)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->Checked = state;
		CheckboxUpdate(win);
	}
}

/* ---------------------------------------------------------------------
 * CheckboxSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
CheckboxSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->PreKeyHook = proc;
		((CHECKBOXDATA*)win->InstData)->PreKeyTarget = target;
	}
}
  
/* ---------------------------------------------------------------------
 * CheckboxSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
CheckboxSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CHECKVIEW")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->PostKeyHook = proc;
		((CHECKBOXDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * CheckboxSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
CheckboxSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->SetFocusHook = proc;
		((CHECKBOXDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * CheckboxSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
CheckboxSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->KillFocusHook = proc;
		((CHECKBOXDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * CheckboxSetClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
CheckboxSetClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CHECKBOX")) == 0))
	{
		((CHECKBOXDATA*)win->InstData)->ButtonClickedHook = proc;
		((CHECKBOXDATA*)win->InstData)->ButtonClickedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * CheckboxUpdate
 * Update checkbox view
 * ---------------------------------------------------------------------
 */
static void
CheckboxUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


