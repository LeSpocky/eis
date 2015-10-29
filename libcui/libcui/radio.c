/* ---------------------------------------------------------------------
 * File: radio.c
 * (radio button control for dialog windows)
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

typedef struct RADIODATAStruct
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
} RADIODATA;


static void RadioUpdate(CUIWINDOW* win);


/* ---------------------------------------------------------------------
 * EvPaintRadio
 * Handle EVENT_PAINT events by redrawing the radio button control
 * ---------------------------------------------------------------------
 */
static void
RadioPaintHook(void* w)
{
	CUIWINDOW*  win = (CUIWINDOW*) w;
	RADIODATA*  data = (RADIODATA*) win->InstData;
	CUIRECT     rc;
	int         i;
	wchar_t     buffer[128 + 1];

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	if (rc.W > 1) 
	{
		int    pos, n;
		wchar_t* ch;
		wchar_t* ch2;

		for (i = 0; i < rc.W; i++) buffer[i] = _T(' ');
		buffer[i] = 0;
	
		buffer[0] = _T('(');
		if (data->Checked)
		{
			buffer[1] = _T('*');
		}
		buffer[2] = _T(')');

		pos = 4;
		ch  = win->Text;
		ch2 = (wchar_t*) wcschr(ch, _T('&'));
		while (ch2)
		{
			n = (pos + (ch2 - ch)) < 128 ? (ch2 - ch) : (128 - pos);

			wcsncpy(&buffer[pos], ch, n);
			pos += (ch2 - ch);

			ch = ch2 + 1;
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

	MOVEYX(win->Win, 0, 0); 
	PRINT (win->Win, buffer);

	WindowSetCursor(win, 1, 0);
}


/* ---------------------------------------------------------------------
 * EvKeyRadio
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
RadioKeyHook(void* w, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	RADIODATA* data = (RADIODATA*) win->InstData;

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

		if ((key == KEY_SPACE) || ((key == win->HotKey) && (key != '\0')))
		{
			if (win->Parent)
			{
				CUIWINDOW* others = ((CUIWINDOW*)win->Parent)->FirstChild;
				while (others)
				{
					if ((others != win) &&
					    (wcscmp(others->Class, _T("RADIOBUTTON")) == 0))
					{
						((RADIODATA*) others->InstData)->Checked = FALSE;
					}
					WindowInvalidate(others);
					others = (CUIWINDOW*) others->Next;
				}

				data->Checked = TRUE;
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
 * RadioMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
RadioMButtonHook(void* w, int x, int y, int flags)
{
	CUI_USE_ARG(x);
	CUI_USE_ARG(y);
	
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED) ||
	    (flags & BUTTON1_TRIPLE_CLICKED) || (flags & BUTTON1_PRESSED))
	{
		RadioKeyHook(w, KEY_SPACE);
	}
}

/* ---------------------------------------------------------------------
 * RadioDestroyHook
 * Handle EVENT_DELETE events by deleting the checkbox's control data
 * ---------------------------------------------------------------------
 */
static void
RadioDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free (win->InstData);
}

/* ---------------------------------------------------------------------
 * RadioSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
RadioSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	RADIODATA* data = (RADIODATA*) win->InstData;

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
 * RadioKillFocusHook
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
RadioKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	RADIODATA* data = (RADIODATA*) win->InstData;

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
 * RadioNew
 * Create a radiobutton dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
RadioNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
         int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* radio;
		int flags = sflags | CWS_TABSTOP;
		flags &= ~(cflags);

		radio = WindowNew(parent, x, y, w, h, flags);
		radio->Class = _T("RADIOBUTTON");
		WindowSetId(radio, id);
		WindowSetPaintHook(radio, RadioPaintHook);
		WindowSetKeyHook(radio, RadioKeyHook);
		WindowSetDestroyHook(radio, RadioDestroyHook);
		WindowSetSetFocusHook(radio, RadioSetFocusHook);
		WindowSetKillFocusHook(radio, RadioKillFocusHook);
		WindowSetMButtonHook(radio, RadioMButtonHook);

                radio->InstData = (RADIODATA*) malloc(sizeof(RADIODATA));
                ((RADIODATA*)radio->InstData)->SetFocusHook    = NULL;
                ((RADIODATA*)radio->InstData)->KillFocusHook   = NULL;
                ((RADIODATA*)radio->InstData)->PreKeyHook      = NULL;
                ((RADIODATA*)radio->InstData)->PostKeyHook     = NULL;
                ((RADIODATA*)radio->InstData)->ButtonClickedHook = NULL;
		((RADIODATA*)radio->InstData)->Checked = FALSE;

                WindowSetText(radio, text);

                return radio;
        }
        return NULL;
}


/* ---------------------------------------------------------------------
 * RadioGetCheck
 * Read the check-state of the control
 * ---------------------------------------------------------------------
 */
int 
RadioGetCheck(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		return ((RADIODATA*)win->InstData)->Checked;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * RadioSetCheck
 * Set the check-state of the control
 * ---------------------------------------------------------------------
 */
void
RadioSetCheck(CUIWINDOW* win, int state)
{
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->Checked = state;
		RadioUpdate(win);
	}
}

/* ---------------------------------------------------------------------
 * RadioSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
RadioSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->SetFocusHook = proc;
		((RADIODATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * RadioSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
RadioSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->KillFocusHook = proc;
		((RADIODATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * RadioSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
RadioSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{  
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->PreKeyHook = proc;
		((RADIODATA*)win->InstData)->PreKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * RadioSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
RadioSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{  
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->PostKeyHook = proc;
		((RADIODATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * RadioSetClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
RadioSetClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("RADIOBUTTON")) == 0))
	{
		((RADIODATA*)win->InstData)->ButtonClickedHook = proc;
		((RADIODATA*)win->InstData)->ButtonClickedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * RadioUpdate
 * Update radio button view
 * ---------------------------------------------------------------------
 */
static void
RadioUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}

