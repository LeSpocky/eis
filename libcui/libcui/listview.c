/* ---------------------------------------------------------------------
 * File: listview.c
 * (list view control)
 *
 * Copyright (C) 2004
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: listview.c 33467 2013-04-14 16:23:14Z dv $
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

/* Appearence:
 * +---------+----------+--------------------------
 * | Col1    |   Col2   |                         |
 * +---------+----------+-------------------------^
 * | Text1   |  Text1   |                         X
 * | Text2   |  Text2   |                         X
 * | ...                                          v
 * +--------------------<XXXXXXXXXXXXXXXXXXXXXXXX>+
 */

#include "cui.h"

typedef struct LISTVIEWStruct
{
	int       NumRecords;
	int       SelIndex;
	int       TotalWidth;
	LISTREC*  ListTitle;
	LISTREC*  FirstRecord;
	LISTREC*  LastRecord;

	LISTREC*  LastReadRecord;
	int       LastReadIndex;

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CustomHookProc          LbChangedHook;     /* Custom callback */
	CustomBoolHookProc      LbChangingHook;    /* Custom callback */
	CustomHookProc          LbClickedHook;     /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*              LbChangedTarget;   /* Custom callback target */
	CUIWINDOW*              LbChangingTarget;  /* Custom callback target */
	CUIWINDOW*              LbClickedTarget;   /* Custom callback target */
	int                     MouseDown;         /* Mouse button down */
} LISTVIEWDATA;


/* local prototypes */
static void ListviewShowTitle(CUIWINDOW* win);
static void ListviewShowRecord(CUIWINDOW* win, LISTREC* recptr, int ypos, int xscroll, CUIRECT* rc, int select);
static void ListviewUpdateView(CUIWINDOW* win);
static void ListviewCalculate(CUIWINDOW* win);
static void ListviewCalculateWidth(CUIWINDOW* win);
static void ListviewCheckScrollPos(CUIWINDOW* win);
static int  ListviewQueryChange(CUIWINDOW* win, LISTVIEWDATA* data);
static void ListviewNotifyChange(CUIWINDOW* win, LISTVIEWDATA* data);


/* ---------------------------------------------------------------------
 * ListviewNcPaintHook
 * Handle PAINT events by redrawing the list view control
 * ---------------------------------------------------------------------
 */
static void
ListviewNcPaintHook(void* w, int size_x, int size_y)
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

		/* scroll bars */
		if (win->HasVScroll && (size_y > 2))
		{
			WindowPaintVScroll(win, 1, size_y - 2);
		}
		if (win->HasHScroll && (size_x > 2))
		{
			WindowPaintHScroll(win, 1, size_x - 2);
		}
	}
	else
	{
		if (win->HasVScroll && win->HasHScroll)
		{
			WindowPaintVScroll(win, 0, size_y - 2);
			WindowPaintHScroll(win, 0, size_x - 2);
			MOVEYX(win->Frame, size_y - 1, size_x - 1);
			PRINT(win->Frame, _T(" "));
		}
		else if (win->HasVScroll)
		{
			WindowPaintVScroll(win, 0, size_y - 1);
		}
		else if (win->HasHScroll)
		{
			WindowPaintHScroll(win, 0, size_x - 1);
		}
	}

	/* title text */
	if (!win->Text || (win->Text[0] == 0) || (!win->HasBorder)) return;

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

/* ---------------------------------------------------------------------
 * ListviewPaintHook
 * Handle PAINT events by redrawing the list view control
 * ---------------------------------------------------------------------
 */
static void
ListviewPaintHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	LISTVIEWDATA* data;
	LISTREC*      recptr;
	int           yscroll;
	int           xscroll;
	int           ypos;
	int           index;
	int           cpos;

	data = (LISTVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	yscroll = WindowGetVScrollPos(win);
	xscroll = WindowGetHScrollPos(win);

	ListviewShowTitle(win);

	/* show list data */
	index = 0;
	recptr = data->FirstRecord;
	while (recptr && (index < yscroll))
	{
		index++;
		recptr = recptr->Next;
	}

	ypos = 2;
	cpos = 2;
	while (recptr && (ypos < rc.H))
	{
		ListviewShowRecord(win, recptr, ypos, xscroll, &rc, data->SelIndex == index);

		if (data->SelIndex == index)
		{
			cpos = ypos;
		}

		ypos++;
		index++;
		recptr = recptr->Next;
	}
	WindowSetCursor(win, 0, cpos);
}

/* ---------------------------------------------------------------------
 * ListviewSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int
ListviewSizeHook(void* w)
{
	ListviewCalculate     ((CUIWINDOW*) w);
	ListviewCheckScrollPos((CUIWINDOW*) w);
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ListviewKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
ListviewKeyHook(void* w, int key)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
	CUIRECT       rc;
	int           xscroll;
	int           xrange;

	if (!data) return FALSE;

	xscroll = WindowGetHScrollPos(win);
	xrange  = WindowGetHScrollRange(win);

	WindowGetClientRect(win, &rc);

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
		case KEY_DOWN:
			if ((data->SelIndex < (data->NumRecords - 1)) && ListviewQueryChange(win, data))
			{
				data->SelIndex++;
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_UP:
			if ((data->SelIndex > 0) && ListviewQueryChange(win, data))
			{
				data->SelIndex--;
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_NPAGE:
			if ((data->SelIndex < (data->NumRecords - 1)) && ListviewQueryChange(win, data))
			{
				data->SelIndex += (rc.H - 1);
				if (data->SelIndex >= data->NumRecords)
				{
					data->SelIndex = data->NumRecords - 1;
				}
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_PPAGE:
			if ((data->SelIndex > 0) && ListviewQueryChange(win, data))
			{
				data->SelIndex -= (rc.H - 1);
				if (data->SelIndex < 0)
				{
					data->SelIndex = 0;
				}
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_HOME:
			if ((data->SelIndex > 0) && ListviewQueryChange(win, data))
			{
				data->SelIndex = 0;
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_END:
			if ((data->SelIndex < (data->NumRecords - 1)) && ListviewQueryChange(win, data))
			{
				data->SelIndex = data->NumRecords - 1;
				ListviewCheckScrollPos(win);
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			return TRUE;
		case KEY_RIGHT:
			if (xscroll < xrange)
			{
				WindowSetHScrollPos(win, xscroll + 1);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_LEFT:
			if (xscroll > 0)
			{
				WindowSetHScrollPos(win, xscroll - 1);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_SPACE:
			if (data->LbClickedHook)
			{
				data->LbClickedHook(data->LbClickedTarget, win);
			}
			return TRUE;
		default:
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
 * ListviewMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
ListviewMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
	{
		int offsy = WindowGetVScrollPos(win);
		int nochange = FALSE;
		y += offsy - 2;

		WindowReleaseCapture();

		if ((y != data->SelIndex) && (y < data->NumRecords) && (y >= 0))
		{
			if (ListviewQueryChange(win, data))
			{
				data->SelIndex = y;
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
			else
			{
				nochange = TRUE;
			}
		}
		/* only execute clicked hook, if change was not rejected
		   by the application */
		if (!nochange)
		{
			if ((flags & BUTTON1_DOUBLE_CLICKED) &&
			    (data->LbClickedHook))
			{
				data->LbClickedHook(data->LbClickedTarget, win);
			}
		}
	}
	else if (flags & BUTTON1_PRESSED)
	{
		data->MouseDown = TRUE;
		WindowSetCapture(win);
	}
	else if ((flags & BUTTON1_RELEASED) && (data->MouseDown))
	{
		CUIRECT rc;
		WindowGetClientRect(win, &rc);

		data->MouseDown = FALSE;
		WindowReleaseCapture();

		if ((x >= rc.X) && (x < (rc.X + rc.W)) &&
		    (y >= rc.Y) && (y < (rc.Y + rc.H)))
		{
			int offsy = WindowGetVScrollPos(win);

			y += offsy - 2;

			if ((y != data->SelIndex) && (y < data->NumRecords) && (y >= 0))
			{
				ListviewQueryChange(win, data);
				data->SelIndex = y;
				ListviewUpdateView(win);
				ListviewNotifyChange(win, data);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ListviewVScrollHook
 * Listview scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
ListviewVScrollHook(void* w, int sbcode, int pos)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT rc;
	int sbpos, range;
	
	CUI_USE_ARG(pos);

	WindowGetClientRect(win, &rc);
	sbpos = WindowGetVScrollPos(win);
	range = WindowGetVScrollRange(win);

	switch(sbcode)
	{
	case SB_LINEUP:
		if (sbpos > 0)
		{
			WindowSetVScrollPos(win, sbpos - 1);
			WindowInvalidate(win);
		}
		break;
	case SB_LINEDOWN:
		if (sbpos < range)
		{
			WindowSetVScrollPos(win, sbpos + 1);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEUP:
		if (sbpos > 0)
		{
			sbpos -= (rc.H - 3);
			sbpos = (sbpos < 0) ? 0 : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.H - 3);
			sbpos = (sbpos > range) ? range : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_THUMBTRACK:
		WindowInvalidate(win);
		break;
        }
}

/* ---------------------------------------------------------------------
 * ListviewDestroyHook
 * Handle EVENT_DELETE event
 * ---------------------------------------------------------------------
 */
static void
ListviewDestroyHook(void* w)
{
	int i;
	CUIWINDOW*    win = (CUIWINDOW*) w;
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;

	ListviewClear(win);

	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		if (data->ListTitle->ColumnText[i])
		{
			free(data->ListTitle->ColumnText[i]);
		}
	}
	if (data->ListTitle->ColumnText)      free(data->ListTitle->ColumnText);
	if (data->ListTitle->ColumnWidth)     free(data->ListTitle->ColumnWidth);
	if (data->ListTitle->ColumnAlignment) free(data->ListTitle->ColumnAlignment);
	if (data->ListTitle)                  free(data->ListTitle);

	free (win->InstData);
}

/* ---------------------------------------------------------------------
 * TextviewSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ListviewSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;

	if (data)
	{
		WindowCursorOn();

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * ListviewKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ListviewKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;

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
 * ListviewLayoutHook
 * Handle EVENT_UPDATELAYOUT Events
 * ---------------------------------------------------------------------
 */
static void
ListviewLayoutHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	
	ListviewCalculateWidth(win);
	ListviewCalculate(win);
	ListviewUpdateView(win);
}

/* ---------------------------------------------------------------------
 * ListviewNew
 * Create a list view dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ListviewNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int num_cols, int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* listview;
		int i;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		listview = WindowNew(parent, x, y, w, h, flags);
                listview->Class = _T("LISTVIEW");
		WindowSetId(listview, id);
		WindowSetNcPaintHook(listview, ListviewNcPaintHook);
		WindowSetPaintHook(listview, ListviewPaintHook);
		WindowSetKeyHook(listview, ListviewKeyHook);
		WindowSetSetFocusHook(listview, ListviewSetFocusHook);
		WindowSetKillFocusHook(listview, ListviewKillFocusHook);
		WindowSetSizeHook(listview, ListviewSizeHook);
		WindowSetDestroyHook(listview, ListviewDestroyHook);
		WindowSetMButtonHook(listview, ListviewMButtonHook);
		WindowSetVScrollHook(listview, ListviewVScrollHook);
		WindowSetLayoutHook(listview, ListviewLayoutHook);

		listview->InstData = (LISTVIEWDATA*) malloc(sizeof(LISTVIEWDATA));
		((LISTVIEWDATA*)listview->InstData)->SetFocusHook    = NULL;
		((LISTVIEWDATA*)listview->InstData)->KillFocusHook   = NULL;
		((LISTVIEWDATA*)listview->InstData)->PreKeyHook      = NULL;
		((LISTVIEWDATA*)listview->InstData)->PostKeyHook     = NULL;
		((LISTVIEWDATA*)listview->InstData)->LbChangedHook   = NULL;
		((LISTVIEWDATA*)listview->InstData)->LbChangingHook  = NULL;
		((LISTVIEWDATA*)listview->InstData)->LbClickedHook   = NULL;

		((LISTVIEWDATA*)listview->InstData)->NumRecords      = 0;
		((LISTVIEWDATA*)listview->InstData)->SelIndex        = 0;
		((LISTVIEWDATA*)listview->InstData)->TotalWidth      = 0;
		((LISTVIEWDATA*)listview->InstData)->ListTitle       = NULL;
		((LISTVIEWDATA*)listview->InstData)->FirstRecord     = NULL;
		((LISTVIEWDATA*)listview->InstData)->LastRecord      = NULL;
		((LISTVIEWDATA*)listview->InstData)->MouseDown       = FALSE;
		((LISTVIEWDATA*)listview->InstData)->LastReadRecord  = NULL;
		((LISTVIEWDATA*)listview->InstData)->LastReadIndex   = -1;

		((LISTVIEWDATA*)listview->InstData)->ListTitle =
		      (LISTREC*)     malloc(sizeof(LISTREC));
		((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnText =
		      (wchar_t**)      malloc(num_cols * sizeof(wchar_t*));
		((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnWidth =
		      (int*)         malloc(num_cols * sizeof(int));
		((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnAlignment =
		      (ALIGNMENT_T*) malloc(num_cols * sizeof(ALIGNMENT_T));

		((LISTVIEWDATA*)listview->InstData)->ListTitle->NumColumns = num_cols;
		((LISTVIEWDATA*)listview->InstData)->ListTitle->Next        = NULL;

		for (i = 0; i < ((LISTVIEWDATA*)listview->InstData)->ListTitle->NumColumns; i++)
		{
			((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnText[i] = NULL;
			((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnWidth[i] = 0;
			((LISTVIEWDATA*)listview->InstData)->ListTitle->ColumnAlignment[i] = ALIGN_CENTER;
		}

		WindowSetText(listview, text);

		return listview;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ListviewSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetSetFocusHook(CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->SetFocusHook = proc;
		((LISTVIEWDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->KillFocusHook = proc;
		((LISTVIEWDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->PreKeyHook = proc;
		((LISTVIEWDATA*)win->InstData)->PreKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->PostKeyHook = proc;
		((LISTVIEWDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetLbChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetLbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->LbChangedHook = proc;
		((LISTVIEWDATA*)win->InstData)->LbChangedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetLbChangingHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->LbChangingHook = proc;
		((LISTVIEWDATA*)win->InstData)->LbChangingTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetLbClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListviewSetLbClickedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		((LISTVIEWDATA*)win->InstData)->LbClickedHook = proc;
		((LISTVIEWDATA*)win->InstData)->LbClickedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListviewAddColumn
 * Add a column text to the list view
 * ---------------------------------------------------------------------
 */
void
ListviewAddColumn(CUIWINDOW* win, int colnr, const wchar_t* text)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = win->InstData;

		if ((colnr >= 0) && (colnr < data->ListTitle->NumColumns))
		{
			if (data->ListTitle->ColumnText[colnr])
			{
				free(data->ListTitle->ColumnText[colnr]);
			}
			data->ListTitle->ColumnText[colnr] = wcsdup(text);
			data->ListTitle->ColumnWidth[colnr] = wcslen(text);
		}

		ListviewCalculate(win);
		ListviewUpdateView(win);
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetTitleAlignment
 * Add an alinment information for title text
 * ---------------------------------------------------------------------
 */
void
ListviewSetTitleAlignment(CUIWINDOW* win, int colnr, ALIGNMENT_T align)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = win->InstData;

		if ((colnr >= 0) && (colnr < data->ListTitle->NumColumns))
		{
		        data->ListTitle->ColumnAlignment[colnr] = align;
		}

		ListviewUpdateView(win);
	}
}

/* ---------------------------------------------------------------------
 * ListviewClear
 * Delete all records from the list
 * ---------------------------------------------------------------------
 */
void
ListviewClear(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = win->InstData;
		LISTREC* delptr;
		int i;

		delptr = data->FirstRecord;
		while (delptr)
		{
			data->FirstRecord = delptr->Next;
			for (i = 0; i < delptr->NumColumns; i++)
			{
				if (delptr->ColumnText[i])
				{
					free(delptr->ColumnText[i]);
				}
			}
			if (delptr->ColumnText)  free(delptr->ColumnText);
			if (delptr->ColumnWidth) free(delptr->ColumnWidth);
			if (delptr) free(delptr);
			delptr = data->FirstRecord;
		}
		data->LastRecord = NULL;
		data->NumRecords = 0;
		data->LastReadRecord  = NULL;
		data->LastReadIndex   = -1;


		for (i = 0; i < data->ListTitle->NumColumns; i++)
		{
			if (data->ListTitle->ColumnText[i])
			{
				data->ListTitle->ColumnWidth[i] = wcslen(data->ListTitle->ColumnText[i]);
			}
			else
			{
				data->ListTitle->ColumnWidth[i] = 0;
			}
		}

		WindowInvalidateLayout(win);
	}
}

/* ---------------------------------------------------------------------
 * ListviewCreateRecord
 * Create a new record suitable to be inserted into the list specified
 * by 'list'
 * ---------------------------------------------------------------------
 */
LISTREC*
ListviewCreateRecord(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		LISTREC* newrec;
		int i, numcols;

		numcols = data->ListTitle->NumColumns;

		newrec = (LISTREC*) malloc(sizeof(LISTREC));
		newrec->ColumnText      = (wchar_t**) malloc(numcols * sizeof(wchar_t*));
		newrec->ColumnWidth     = (int*) malloc(numcols * sizeof(int));
		newrec->NumColumns      = numcols;
		newrec->ColumnAlignment = NULL;
		newrec->Next            = NULL;
		newrec->Owner           = NULL;

		for (i = 0; i < numcols; i++)
		{
			newrec->ColumnText[i]  = NULL;
			newrec->ColumnWidth[i] = 0;
		}
		return newrec;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ListWinInsertRecord
 * Insert a new record into the list view
 * ---------------------------------------------------------------------
 */
int
ListviewInsertRecord (CUIWINDOW* win, LISTREC* newrec)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		int i;

		if (data->ListTitle->NumColumns != newrec->NumColumns)
		{
			return (-1);
		}

		for (i = 0; i < newrec->NumColumns; i++)
		{
			if (data->ListTitle->ColumnWidth[i] < newrec->ColumnWidth[i])
			{
				data->ListTitle->ColumnWidth[i] = newrec->ColumnWidth[i];
			}
		}

		if (!data->LastRecord)
		{
			data->FirstRecord = newrec;
		}
		else
		{
			data->LastRecord->Next = newrec;
		}
		data->LastRecord     = newrec;
		data->LastReadIndex  = data->NumRecords;
		data->LastReadRecord = newrec;
		data->NumRecords++;

		newrec->Owner = win;

		WindowInvalidateLayout(win);
		
		return data->NumRecords - 1;
	}
	return (-1);
}

/* ---------------------------------------------------------------------
 * ListviewSetColumnText
 * Insert text into column 'colnr'
 * ---------------------------------------------------------------------
 */
void
ListviewSetColumnText(LISTREC* rec, int colnr, const wchar_t* text)
{
	if (!rec) return;

	if ((colnr >= 0)&&(colnr < rec->NumColumns))
	{
		if (rec->ColumnText[colnr])
		{
			free(rec->ColumnText[colnr]);
		}
		rec->ColumnText[colnr] = wcsdup(text);
		rec->ColumnWidth[colnr] = wcslen(text);

		if (rec->Owner)
		{
      	WindowInvalidateLayout(rec->Owner);
		}
	}
}

/* ---------------------------------------------------------------------
 * ListviewGetColumnText
 * Get the string from record
 * ---------------------------------------------------------------------
 */
const wchar_t*
ListviewGetColumnText(LISTREC* rec, int colnr)
{
	if (!rec) return _T("");

	if ((colnr >= 0) && (colnr < rec->NumColumns))
	{
		return rec->ColumnText[colnr];
	}
	return _T("");
}

/* ---------------------------------------------------------------------
 * ListviewSetSel
 * Set the current selection
 * ---------------------------------------------------------------------
 */
void
ListviewSetSel(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;

		if ((index >= 0) && (index < data->NumRecords))
		{
			data->SelIndex = index;
		}
		ListviewCalculate(win);
		ListviewCheckScrollPos(win);
		ListviewUpdateView(win);
	}
}

/* ---------------------------------------------------------------------
 * ListviewSetSel
 * Set the current selection
 * ---------------------------------------------------------------------
 */
int
ListviewGetSel(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		return ((LISTVIEWDATA*)win->InstData)->SelIndex;
	}
	return -1;
}

/* ---------------------------------------------------------------------
 * ListviewGetRecord
 * Return record 'index' (count from zero) or NULL if not found
 * ---------------------------------------------------------------------
 */
LISTREC*
ListviewGetRecord(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		int count = 0;
		LISTREC* seekptr;

		if ((index == data->LastReadIndex) &&
		    (data->LastReadRecord != NULL))
		{
			return data->LastReadRecord;
		}
		else
		{
			seekptr = data->FirstRecord;
			while (seekptr && (count < index))
			{
				count++;
				seekptr = seekptr->Next;
			}
			if (seekptr)
			{
				data->LastReadIndex = index;
				data->LastReadRecord = seekptr;
			}
			return seekptr;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ListviewGetCount
 * Return number of records
 * ---------------------------------------------------------------------
 */
int
ListviewGetCount(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		return ((LISTVIEWDATA*)win->InstData)->NumRecords;
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * ListviewAlphaSort
 * Sort list view in alphabetical order (bubble sort)
 * ---------------------------------------------------------------------
 */
void
ListviewAlphaSort(CUIWINDOW* win, int colnr, int up)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		int           num = data->NumRecords - 1;

		while (num > 0)
		{
			int i = 0;
			LISTREC* workptr = data->FirstRecord;
			while (workptr && (i < num))
			{
				LISTREC* cmpptr = workptr->Next;

				if ((colnr >= 0) && (colnr < workptr->NumColumns) &&
				    (colnr < cmpptr->NumColumns))
				{
					int exchange =
						(up && (wcscmp(workptr->ColumnText[colnr], 
							cmpptr->ColumnText[colnr]) > 0)) ||
						(!up && (wcscmp(workptr->ColumnText[colnr], 
							cmpptr->ColumnText[colnr]) < 0));

					if (exchange)
					{
						wchar_t** p;
						unsigned long data;
						int* width;
						int  num;

						p = workptr->ColumnText;
						workptr->ColumnText = cmpptr->ColumnText;
						cmpptr->ColumnText  = p;

						data = workptr->Data;
						workptr->Data = cmpptr->Data;
						cmpptr->Data = workptr->Data;

						width = workptr->ColumnWidth;
						workptr->ColumnWidth = cmpptr->ColumnWidth;
						cmpptr->ColumnWidth = width;

						num = workptr->NumColumns;
						workptr->NumColumns = cmpptr->NumColumns;
						cmpptr->NumColumns = num;
					}
					workptr = (LISTREC*) workptr->Next;
					i++;
				}
			}
			num--;
		}
		ListviewUpdateView(win);
	}
}

/* ---------------------------------------------------------------------
 * ListviewNumericSort
 * Sort list view in numerical order (bubble sort)
 * ---------------------------------------------------------------------
 */
void
ListviewNumericSort(CUIWINDOW* win, int colnr, int up)
{
	if (win && (wcscmp(win->Class, _T("LISTVIEW")) == 0))
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		int           num = data->NumRecords - 1;

		while (num > 0)
		{
			int i = 0;
			LISTREC* workptr = data->FirstRecord;
			while (workptr && (i < num))
			{
				LISTREC* cmpptr = workptr->Next;

				if ((colnr >= 0) && (colnr < workptr->NumColumns) &&
				    (colnr < cmpptr->NumColumns))
				{
					int val1, val2;
					int exchange;

					swscanf(workptr->ColumnText[colnr], _T("%d"), &val1);
					swscanf(cmpptr->ColumnText[colnr],  _T("%d"), &val2);

					exchange = (up  && (val1 > val2)) || (!up && (val1 < val2));
					if (exchange)
					{
						wchar_t** p;
						unsigned long data;
						int* width;
						int  num;

						p = workptr->ColumnText;
						workptr->ColumnText = cmpptr->ColumnText;
						cmpptr->ColumnText  = p;

						data = workptr->Data;
						workptr->Data = cmpptr->Data;
						cmpptr->Data = workptr->Data;

						width = workptr->ColumnWidth;
						workptr->ColumnWidth = cmpptr->ColumnWidth;
						cmpptr->ColumnWidth = width;

						num = workptr->NumColumns;
						workptr->NumColumns = cmpptr->NumColumns;
						cmpptr->NumColumns = num;
					}
					workptr = (LISTREC*) workptr->Next;
					i++;
				}
			}
			num--;
		}
		ListviewUpdateView(win);
	}
}

/* helper functions */

/* ---------------------------------------------------------------------
 * ListviewShowTitle
 * Show the column head lines
 * ---------------------------------------------------------------------
 */
static void
ListviewShowTitle(CUIWINDOW* win)
{
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
	WINDOW* w = win->Win;
	CUIRECT rc;
	int     xscroll;
	int     i, x, y;

	xscroll = WindowGetHScrollPos(win);

	WindowGetClientRect(win, &rc);
	if (rc.H < 1) return;

	y = 0;
	x = 0 - xscroll;
	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		int n;
		int len = 0;
		int offs = 0;
		wchar_t* ch = data->ListTitle->ColumnText[i];

		if (ch)
		{
			len = wcslen(ch);
			
			switch(data->ListTitle->ColumnAlignment[i])
			{
			case ALIGN_CENTER:
				offs = (data->ListTitle->ColumnWidth[i] - len) / 2;
				break;
			case ALIGN_LEFT:
				offs = 0;
				break;
			case ALIGN_RIGHT:
				offs = (data->ListTitle->ColumnWidth[i] - len);
				break;
			}

			if (offs < 0) offs = 0;
		}

		if (win->IsEnabled)
		{
			SetColor(w, win->Color.HilightColor, win->Color.WndColor, FALSE);
		}
		else
		{
			SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
		}

		for (n = 0; n < data->ListTitle->ColumnWidth[i]; n++)
		{
			if ((x >= 0) && (x < rc.W))
			{
				if (((n - offs) >= 0) && ((n - offs) < len))
				{
					MOVEYX(w, y, x); PRINTN(w, ch++, 1);
				}
			}
			else if ((n -offs) >= 0)
			{
				ch++;
			}
			x++;
		}

		if (win->IsEnabled)
		{
			SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
		}
		else
		{
			SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
		}

		if ((x >= 0) && (x < rc.W))
		{
			mvwaddch(w, y, x, ACS_VLINE);
		}
		x++;
	}

	if (rc.H < 2) return;

	if (win->IsEnabled)
	{
		SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	y = 1;
	x = 0 - xscroll;
	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		int n;

		for (n = 0; n < data->ListTitle->ColumnWidth[i]; n++)
		{
			if ((x >= 0) && (x < rc.W))
			{
				mvwaddch(w, y, x, ACS_HLINE);
			}
			x++;
		}
		if ((x >= 0) && (x < rc.W))
		{
			mvwaddch(w, y, x, ACS_PLUS);
		}
		x++;
	}

	while((x >= 0) && (x < rc.W))
	{
		mvwaddch(w, y, x, ACS_HLINE);
		x++;
	}
}

/* ---------------------------------------------------------------------
 * ListviewShowRecord
 * Print a record into the list view
 * ---------------------------------------------------------------------
 */
static void
ListviewShowRecord(CUIWINDOW* win, LISTREC* recptr, int ypos, int xscroll, CUIRECT* rc, int select)
{
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
	WINDOW* w = win->Win;
	int i, x, y;

	y = ypos;
	x = 0 - xscroll;

	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		int n, p;
		int len = 0;
		wchar_t* ch = recptr->ColumnText[i];

		if (ch)
		{
			len = wcslen(ch);
		}
		else
		{
			ch = _T("");
		}

		if (select)
		{
			SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
		}
		else
		{
			if (win->IsEnabled)
			{
				SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
			}
			else
			{
				SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
			}
		}

		/* calculate length of visible text. if not zero, print visible part of it as a whole */
		/* not character by character. This is supposed to produce better performance */
		n = (data->ListTitle->ColumnWidth[i] < len) ? data->ListTitle->ColumnWidth[i] : len;
		p = (x < 0) ? (0 - x) : 0;
		n -= p;
		if (n >= 0)
		{
			if ((x + p + n) >= rc->W)
			{
				n = (rc->W - x - p);
			}
			if (n > 0)
			{
				ch += p;
				MOVEYX(w, y, x + p); PRINTN(w, ch, n);
			}
			if (select)
			{
				while (((p + n) < data->ListTitle->ColumnWidth[i]) &&
				       ((x + p + n) < rc->W))
				{
					PRINT(w, _T(" "));
					n++;
				}
			}
		}
		else if ((select) && (x < 0) && (x + data->ListTitle->ColumnWidth[i] > 0))
		{
			n = (data->ListTitle->ColumnWidth[i] - p);
			MOVEYX(w, y, x + p);
			while ((n-- > 0) && ((x + p++) < rc->W))
			{
				PRINT(w, _T(" "));
			}
		}
		x += data->ListTitle->ColumnWidth[i];


		if ((x >= 0) && (x < rc->W))
		{
			mvwaddch(w, y, x, ACS_VLINE);
		}
		x++;
	}
}

/* ---------------------------------------------------------------------
 * ListviewCalculate
 * Calculate range and scroll bars of text view
 * ---------------------------------------------------------------------
 */
static void
ListviewCalculate(CUIWINDOW* win)
{
	CUIRECT       rc;
	LISTVIEWDATA* data;
	int           i;
	int           yscroll;
	int           width = 0;
	int           height = 0;

	data = (LISTVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	/* calculate total width */
	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		width += data->ListTitle->ColumnWidth[i] + 1;
	}
	if (width > 0)
	{
		width--;
	}
	data->TotalWidth = width;

	/* set vertical scrollbar range */
	height = rc.H - 2;
	if (data->NumRecords > height)
	{
		WindowSetVScrollRange(win, data->NumRecords - height);
		WindowEnableVScroll(win, TRUE);

		yscroll = WindowGetVScrollPos(win);
		if ((yscroll + height) > data->NumRecords)
		{
			WindowSetVScrollPos(win, data->NumRecords - height); 
		}
	}
	else
	{
		WindowEnableVScroll(win, FALSE);
		WindowSetVScrollRange(win, 0);
		WindowSetVScrollPos(win, 0);
	}

	/* set horizontal scrollbar range */
	if (data->TotalWidth > rc.W)
	{
		WindowSetHScrollRange(win, data->TotalWidth - rc.W);
		WindowEnableHScroll(win, TRUE);
	}
	else
	{
		WindowEnableHScroll(win, FALSE);
		WindowSetHScrollRange(win, 0);
		WindowSetHScrollPos(win, 0);
	}
}

/* ---------------------------------------------------------------------
 * ListviewCalculateWidth
 * (Re-)Calculate width of columns
 * ---------------------------------------------------------------------
 */
static void
ListviewCalculateWidth(CUIWINDOW* win)
{
	LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
	LISTREC* rec;
	int i;

	for (i = 0; i < data->ListTitle->NumColumns; i++)
	{
		data->ListTitle->ColumnWidth[i] = wcslen(data->ListTitle->ColumnText[i]);
	}

	rec = data->FirstRecord;
	while (rec)
	{
		int n = (rec->NumColumns < data->ListTitle->NumColumns) ? 
			rec->NumColumns : data->ListTitle->NumColumns;

		for (i = 0; i < n; i++)
		{
			if (data->ListTitle->ColumnWidth[i] < rec->ColumnWidth[i])
			{
				data->ListTitle->ColumnWidth[i] = rec->ColumnWidth[i];
			}
		}
		rec = rec->Next;
	}
}

/* ---------------------------------------------------------------------
 * ListviewCheckScrollPos
 * Adjust scroll position of the list view to ensure that the selection
 * is always visible
 * ---------------------------------------------------------------------
 */
static void
ListviewCheckScrollPos(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		LISTVIEWDATA* data = (LISTVIEWDATA*) win->InstData;
		CUIRECT rc;
		int yscroll = WindowGetVScrollPos(win);

		WindowGetClientRect(win, &rc);

		if (data->SelIndex > (yscroll + (rc.H - 2) - 1))
		{
			yscroll = data->SelIndex - (rc.H - 2) + 1;
		}
		else if (data->SelIndex < yscroll)
		{
			yscroll = data->SelIndex;
		}
		if (yscroll > (data->NumRecords - (rc.H - 2) - 1))
		{
			yscroll = data->NumRecords - (rc.H - 2);
		}
		if (yscroll < 0)
		{
			yscroll = 0;
		}
		WindowSetVScrollPos(win, yscroll);
	}
}

/* ---------------------------------------------------------------------
 * ListviewUpdateView
 * Update list view
 * ---------------------------------------------------------------------
 */
static void
ListviewUpdateView(CUIWINDOW* win)
{
        if (win->IsCreated)
        {
                WindowInvalidate(win);
        }
}

/* ---------------------------------------------------------------------
 * ListviewQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int
ListviewQueryChange(CUIWINDOW* win, LISTVIEWDATA* data)
{
	if (data->LbChangingHook)
	{
		return data->LbChangingHook(data->LbChangingTarget, win);
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ListviewNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void
ListviewNotifyChange(CUIWINDOW* win, LISTVIEWDATA* data)
{
	if (data->LbChangedHook)
	{
		data->LbChangedHook(data->LbChangedTarget, win);
	}
}

