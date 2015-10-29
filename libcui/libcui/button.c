/* ---------------------------------------------------------------------
 * File: button.c
 * (button control for dialog windows)
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

typedef struct BUTTONDATAStruct
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
	int                     ButtonDown;          /* Mouse button down */
} BUTTONDATA;


/* ---------------------------------------------------------------------
 * ButtonPaintHook
 * Handle EVENT_PAINT events by redrawing the button control
 * ---------------------------------------------------------------------
 */
static void
ButtonPaintHook(void* w)
{
	CUIWINDOW*  win = (CUIWINDOW*) w;
	CUIRECT     rc;
	int   x;
	int   len, i, cpos;
	int   hkey_pos = -1;
	wchar_t hkey = _T('\0');
	wchar_t buffer[128+1];

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	cpos = 0;
	if (rc.W > 1) 
	{
		for (i = 0; i < rc.W; i++) buffer[i] = ' ';
		buffer[i] = 0;
	
		buffer[0] = _T('[');
		buffer[rc.W - 1] = _T(']');
	
		if (win->IsDefOk)
		{
			buffer[1] = _T('<');
			buffer[rc.W - 2] = _T('>');
		}
	
		len = wcslen(win->Text);
		if (wcschr(win->Text, _T('&')) != NULL)
		{
			x = (rc.W - (len - 1)) / 2;
			if (x < 2) x = 2;
		}
		else
		{
			x = (rc.W - len) / 2;
			if (x < 2) x = 2;
		}
		
		cpos = x;
		for (i = 0; i < len; i++)
		{
			if (x < rc.W - 2) 
			{
				if (win->Text[i] != _T('&'))
				{
					buffer[x] = win->Text[i];
					x++;
				}
				else
				{
					hkey_pos = x;
					hkey = win->Text[i + 1];
				}
			}
		}
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

	MOVEYX(win->Win, 0, 0);
	PRINT(win->Win, buffer);
	if ((hkey != _T('\0')) && (win->IsEnabled) && (win != WindowGetFocus()))
	{
		SetColor(win->Win, win->Color.HilightColor, win->Color.WndColor, FALSE);
		MOVEYX(win->Win, 0, hkey_pos);
		PRINTN(win->Win, &hkey, 1);
	}

	WindowSetCursor(win, cpos, 0);
}

/* ---------------------------------------------------------------------
 * ButtonKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
ButtonKeyHook(void* w, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	BUTTONDATA* data = (BUTTONDATA*) win->InstData;

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

		if ((key == KEY_RETURN) || (key == KEY_SPACE) || 
		    ((key == win->HotKey) && (key != '\0')))
		{
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
 * ButtonMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
ButtonMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	BUTTONDATA* data = (BUTTONDATA*) win->InstData;
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
	{
		if (data->ButtonClickedHook)
		{
			data->ButtonClickedHook(data->ButtonClickedTarget, win);
		}
	}
	else if (flags & BUTTON1_PRESSED)
	{
		data->ButtonDown = TRUE;
		WindowSetCapture(win);
	}
	else if ((flags & BUTTON1_RELEASED) && (data->ButtonDown))
	{
		CUIRECT rc;
		WindowGetClientRect(win, &rc);

		data->ButtonDown = FALSE;
		WindowReleaseCapture();

		if ((x >= rc.X) && (x < (rc.X + rc.W)) &&
		    (y >= rc.Y) && (y < (rc.Y + rc.H)) &&
		    (data->ButtonClickedHook))
		{
			data->ButtonClickedHook(data->ButtonClickedTarget, win);
		}
	}
}

/* ---------------------------------------------------------------------
 * ButtonDestroyHook
 * Handle EVENT_DELETE events by deleting the button's control data
 * ---------------------------------------------------------------------
 */
static void
ButtonDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free (win->InstData);
}

/* ---------------------------------------------------------------------
 * ButtonSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ButtonSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	BUTTONDATA* data = (BUTTONDATA*) win->InstData;

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
 * ButtonKillFocusHook
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ButtonKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	BUTTONDATA* data = (BUTTONDATA*) win->InstData;

	if (data)
	{
		WindowInvalidate(win);
		WindowCursorOff();
		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}


/* ---------------------------------------------------------------------
 * ButtonCreate
 * Create al button dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ButtonNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
          int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* button;
		int flags = sflags | CWS_TABSTOP;
		flags &= ~(cflags);

		button = WindowNew(parent, x, y, w, h, flags);
		button->Class = _T("BUTTON");
		WindowSetId(button, id);
		WindowSetPaintHook(button, ButtonPaintHook);
		WindowSetKeyHook(button, ButtonKeyHook);
		WindowSetDestroyHook(button, ButtonDestroyHook);
		WindowSetSetFocusHook(button, ButtonSetFocusHook);
		WindowSetKillFocusHook(button, ButtonKillFocusHook);
		WindowSetMButtonHook(button, ButtonMButtonHook);

		button->InstData = (BUTTONDATA*) malloc(sizeof(BUTTONDATA));
		((BUTTONDATA*)button->InstData)->SetFocusHook    = NULL;
		((BUTTONDATA*)button->InstData)->KillFocusHook   = NULL;
		((BUTTONDATA*)button->InstData)->PreKeyHook      = NULL;
		((BUTTONDATA*)button->InstData)->PostKeyHook     = NULL;
		((BUTTONDATA*)button->InstData)->ButtonClickedHook = NULL;
		((BUTTONDATA*)button->InstData)->ButtonDown = FALSE;

		WindowSetText(button, text);

		return button;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ButtonSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ButtonSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("BUTTON")) == 0))
	{
		((BUTTONDATA*)win->InstData)->SetFocusHook = proc;
		((BUTTONDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ButtonSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ButtonSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("BUTTON")) == 0))
	{
		((BUTTONDATA*)win->InstData)->KillFocusHook = proc;
		((BUTTONDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ButtonSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
ButtonSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("BUTTON")) == 0))
	{
		((BUTTONDATA*)win->InstData)->PreKeyHook = proc;
		((BUTTONDATA*)win->InstData)->PreKeyTarget = target;
	}
}
  
/* ---------------------------------------------------------------------
 * ButtonSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
ButtonSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("BUTTON")) == 0))
	{
		((BUTTONDATA*)win->InstData)->PostKeyHook = proc;
		((BUTTONDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ButtonSetClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ButtonSetClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("BUTTON")) == 0))
	{
		((BUTTONDATA*)win->InstData)->ButtonClickedHook = proc;
		((BUTTONDATA*)win->InstData)->ButtonClickedTarget = target;
	}
}

