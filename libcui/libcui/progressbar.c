/* ---------------------------------------------------------------------
 * File: progressbar.c
 * (progressbar control for dialog windows)
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

typedef struct PROGRESSBARStruct
{
	int  Pos;        /* actual position of the progress bar */
	int  Range;      /* maximum range of the progress bar */
} PROGRESSBARDATA;


static void ProgressbarUpdate(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * ProgressbarNcPaintHook
 * Handle PAINT events by redrawing the groupbox control
 * ---------------------------------------------------------------------
 */
static void
ProgressbarNcPaintHook(void* w, int size_x, int size_y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	int len;

	rc.W = size_x;
	rc.H = size_y;
	rc.X = 0;
	rc.Y = 0;

	if ((rc.W <= 0)||(rc.H <= 0)) return;

	if (win->HasBorder)
	{
		box(win->Frame, 0, 0);

		if (!win->Text) return;

		len = wcslen(win->Text);
		if (len > rc.W - 4)
		{
			len = rc.W - 4;
		}

		if (win->IsEnabled)
		{
			SetColor(win->Frame, win->Color.HilightColor, win->Color.WndColor, FALSE);
		}
		else
		{
			SetColor(win->Frame, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
		}
		MOVEYX(win->Frame, 0, 2); PRINTN(win->Frame, win->Text, len);
		if (rc.W > 2)
		{
			MOVEYX(win->Frame, 0, 1); PRINT(win->Frame, _T(" "));
			MOVEYX(win->Frame, 0, len + 2); PRINT(win->Frame, _T(" "));
		}
	}
}


/* ---------------------------------------------------------------------
 * ProgressbarPaintHook
 * Handle PAINT events by redrawing the groupbox control
 * ---------------------------------------------------------------------
 */
static void
ProgressbarPaintHook(void* w)
{
	CUIWINDOW*       win = (CUIWINDOW*) w;
	PROGRESSBARDATA* data = (PROGRESSBARDATA*) win->InstData;
	CUIRECT          rc;
	int              x, y;
	int              pos;

	WindowGetClientRect(win, &rc);

	if ((rc.W <= 0)||(rc.H <= 0)) return;
	if (data->Range > 0)
	{
		pos = (data->Pos * rc.W) / data->Range;
	}

	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	for (x = 0; x < rc.W; x++)
	{
		for (y = 0; y < rc.H; y++)
		{
			if (x > pos)
			{
				mvwaddch(win->Win, y, x, ACS_CKBOARD);
			}
			else
			{
				mvwaddch(win->Win, y, x, ACS_BLOCK);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ProgressbarDestroyHook
 * Handle EVENT_DELETE events by deleting the control
 * ---------------------------------------------------------------------
 */
static void
ProgressbarDestroyHook(void* w)
{
        CUIWINDOW* win = (CUIWINDOW*) w;
        free (win->InstData);
}

/* ---------------------------------------------------------------------
 * ProgressbarNew
 * Create a group box dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ProgressbarNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
               int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* progress;
		int flags = sflags | CWS_BORDER;
		flags &= ~(cflags);

		progress = WindowNew(parent, x, y, w, h, flags);
		progress->Class = _T("PROGRESSBAR");
		WindowSetNcPaintHook(progress, ProgressbarNcPaintHook);
		WindowSetPaintHook(progress, ProgressbarPaintHook);
		WindowSetDestroyHook(progress, ProgressbarDestroyHook);

		WindowSetId(progress, id);

		progress->InstData = (PROGRESSBARDATA*) malloc(sizeof(PROGRESSBARDATA));
		((PROGRESSBARDATA*) progress->InstData)->Pos = 0;
		((PROGRESSBARDATA*) progress->InstData)->Range = 100;

		WindowSetText(progress, text);

		return progress;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * ProgressbarSetRange
 * Assign range attribute
 * ---------------------------------------------------------------------
 */
void 
ProgressbarSetRange(CUIWINDOW* win, int range)
{
	if (win && (wcscmp(win->Class, _T("PROGRESSBAR")) == 0))
	{
		((PROGRESSBARDATA*) win->InstData)->Range = range;
		ProgressbarUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * ProgressbarSetPos
 * Assign pos attribute
 * ---------------------------------------------------------------------
 */
void 
ProgressbarSetPos(CUIWINDOW* win, int pos)
{
	if (win && (wcscmp(win->Class, _T("PROGRESSBAR")) == 0))
	{
		((PROGRESSBARDATA*) win->InstData)->Pos = pos;
		ProgressbarUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * ProgressbarGetRange
 * Retreive range attribute
 * ---------------------------------------------------------------------
 */
int 
ProgressbarGetRange(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("PROGRESSBAR")) == 0))
	{
		return ((PROGRESSBARDATA*) win->InstData)->Range;
	}
	return 0;
}


/* ---------------------------------------------------------------------
 * ProgressbarGetPos
 * Retreive pos attribute
 * ---------------------------------------------------------------------
 */
int 
ProgressbarGetPos(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("PROGRESSBAR")) == 0))
	{
		return ((PROGRESSBARDATA*) win->InstData)->Pos;
	}
	return 0;
}

/* local helper functions */

/* ---------------------------------------------------------------------
 * ProgressbarUpdate
 * Update progressbar view
 * ---------------------------------------------------------------------
 */
static void
ProgressbarUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}

