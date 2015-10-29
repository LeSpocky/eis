/* ---------------------------------------------------------------------
 * File: label.c
 * (label control for dialog windows)
 *   
 * Copyright (C) 2006
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

typedef struct LABELDATAStruct
{
	CustomHook1PtrProc  SetFocusHook;    /* Custom callback */
	CustomHookProc      KillFocusHook;   /* Custom callback */
	CUIWINDOW*          SetFocusTarget;  /* Custom callback target */
	CUIWINDOW*          KillFocusTarget; /* Custom callback target */
} LABELDATA;


/* ---------------------------------------------------------------------
 * LabelPaintHook
 * Handle PAINT events by redrawing the label control
 * ---------------------------------------------------------------------
 */
static void
LabelPaintHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	int x = 0;
	int y = 0;
	int i, len;

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	len = wcslen(win->Text);
	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	MOVEYX(win->Win, y, x);
	for (i = 0; i < len; i++)
	{
		if (win->Text[i] == '\n')
		{
			x = 0;
			MOVEYX(win->Win, ++y, x);
		}
		else
		{
			if (x >= rc.W)
			{
				x = 0;
				MOVEYX(win->Win, ++y, x);
			}
			PRINTN(win->Win, &win->Text[i], 1);
			x++;
		}
	}
}

/* ---------------------------------------------------------------------
 * LabelSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
LabelSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LABELDATA* data = (LABELDATA*) win->InstData;

	if (data)
	{
		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * EvKillFocusLabel
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
LabelKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LABELDATA* data = (LABELDATA*) win->InstData;

	if (data)
	{
		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}


/* ---------------------------------------------------------------------
 * LabelDestroyHook
 * Handle EVENT_DELETE events by deleting the edit's control data
 * ---------------------------------------------------------------------
 */
static void
LabelDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free (win->InstData);
}


/* ---------------------------------------------------------------------
 * LabelNew
 * Create a label dialog control
 * ---------------------------------------------------------------------
 */

CUIWINDOW*
LabelNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
         int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* label;
		int flags = sflags;
		flags &= ~(cflags);

		label = WindowNew(parent, x, y, w, h, flags);
		label->Class = _T("LABEL");
		WindowSetId(label, id);
		WindowSetPaintHook(label, LabelPaintHook);
		WindowSetDestroyHook(label, LabelDestroyHook);
		WindowSetSetFocusHook(label, LabelSetFocusHook);
		WindowSetKillFocusHook(label, LabelKillFocusHook);

		label->InstData = (LABELDATA*) malloc(sizeof(LABELDATA));
		((LABELDATA*)label->InstData)->SetFocusHook    = NULL;
		((LABELDATA*)label->InstData)->KillFocusHook   = NULL;

		WindowSetText(label, text);

		return label;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * LabelSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
LabelSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LABEL")) == 0))
	{
		((LABELDATA*)win->InstData)->SetFocusHook = proc;
		((LABELDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * LabelSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
LabelSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LABEL")) == 0))
	{
		((LABELDATA*)win->InstData)->KillFocusHook = proc;
		((LABELDATA*)win->InstData)->KillFocusTarget = target;
	}
}

