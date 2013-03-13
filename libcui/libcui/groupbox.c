/* ---------------------------------------------------------------------
 * File: groupbox.c
 * (groupbox control for dialog windows)
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

extern int FocusMove;


/* ---------------------------------------------------------------------
 * GroupboxNcPaintHook
 * Handle PAINT events by redrawing the groupbox control
 * ---------------------------------------------------------------------
 */
static void
GroupboxNcPaintHook(void* w, int size_x, int size_y)
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

		len = tcslen(win->Text);
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
		MOVEYX(win->Frame, 0, 2);
		PRINTN(win->Frame, win->Text, len);
		if (rc.W > 2)
		{
			MOVEYX(win->Frame, 0, 1); PRINT(win->Frame, _T(" ")); 
			MOVEYX(win->Frame, 0, len + 2); PRINT(win->Frame, _T(" ")); 
		}
	}
}


/* ---------------------------------------------------------------------
 * GroupboxSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
GroupboxSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;

	if (FocusMove > 0)
	{
		win->ActiveChild = NULL;
		WindowFocusNext(win);		
	}
	else if (FocusMove < 0)
	{
		win->ActiveChild = NULL;
		WindowFocusPrevious(win);
	}
	else
	{
		if (!win->ActiveChild)
		{
			WindowFocusNext(win);
		}
		else
		{
			WindowSetFocus(win->ActiveChild);
		}
	}
}


/* ---------------------------------------------------------------------
 * GroupBoxNew
 * Create a group box dialog control
 * ---------------------------------------------------------------------
 */

CUIWINDOW*
GroupboxNew(CUIWINDOW* parent, const TCHAR* text, int x, int y, int w, int h, 
            int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* groupbox;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		groupbox = WindowNew(parent, x, y, w, h, flags);
		groupbox->Class = _T("GROUPBOX");
		WindowSetNcPaintHook(groupbox, GroupboxNcPaintHook);
		WindowSetSetFocusHook(groupbox, GroupboxSetFocusHook);

		WindowSetText(groupbox, text);

		return groupbox;
	}
	return NULL;
}

