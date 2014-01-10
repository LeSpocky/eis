/* ---------------------------------------------------------------------
 * File: confview.c
 * (config edit view)
 *
 * Copyright (C) 2007
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

#include "global.h"
#include "confview.h"

typedef struct
{
	const wchar_t* Keyword;
	int          WholeWords;
	int          CaseSens;
} ECESEARCH;

typedef struct
{
	int          CursorPos;          /* Line index where the cursor is placed on */
	int          RelCursor;          /* Cursor position including separators (for drawing) */
	int          RelCursorSize;      /* Number of lines the cursor consists of */
	int          NumVisOptions;      /* Number of currently visible options */
	int          YRange;             /* Length of the list inc. seperators and vis. options */
	int          HasSeparator;       /* Working flag signaling that a seperator was applied */

	int          IsDragging;         /* Is the editor in drag mode? */
	short        DragIndex[NUM_DIM]; /* Array index of current drag item */

	CONFFILE*    ConfData;           /* Config file data */

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
} CONFVIEWDATA;


/* local prototypes */

static void ConfviewCalculate(CUIWINDOW* win);
static void ConfviewUpdate(CUIWINDOW* win);
static int  ConfviewQueryChange(CUIWINDOW* win, CONFVIEWDATA* data);
static void ConfviewNotifyChange(CUIWINDOW* win, CONFVIEWDATA* data);

static void ConfviewShowComment(CUIWINDOW* win, const wchar_t* text, int ypos);
static int  ConfviewShowItem(CUIWINDOW* win, CONFVIEWDATA* data, CONFITEM* item,
                 int level, int line, int drag, int* ypos, short* index);
static int  ConfviewShowLine(CUIWINDOW* win, const wchar_t* name, const wchar_t* value, int ypos,
                 int level, int line, int drag, int readonly, int do_print);
static void ConfviewUpdateListMetrics(CUIWINDOW* win, CONFVIEWDATA* data);
static void ConfviewUpdateItemMetrics(CUIWINDOW* win, CONFITEM* item, int level, short* index);
static int  ConfviewSearchValueByIndexD(CONFITEM* item, int level, int* line, 
                 int lineindex, short* index, ECESEARCH* sdata);
static int  ConfviewSearchValueByIndexU(CONFITEM* item, int level, int* line, 
                 int lineindex, short* index, ECESEARCH* sdata);
static int  ConfviewIsChar(wchar_t c);
static int  ConfviewMatchWord(const wchar_t* text, ECESEARCH* sdata);
static int  ConfviewMatch(const wchar_t* text, ECESEARCH* sdata);


/* ---------------------------------------------------------------------
 * ConfviewNcPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
ConfviewNcPaintHook(void* w, int size_x, int size_y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	int len;

	rc.W = size_x;
	rc.H = size_y;
	rc.X = 0;
	rc.Y = 0;

	if ((rc.W <= 0)||(rc.H <= 0)) return;

	/* border */
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

	/* title text */
	if (!win->Text || (win->Text[0] == 0) || (!win->HasBorder)) return;

	len = wcslen(win->Text);
	if (len > rc.W - 4)
	{
		len = rc.W - 4;
	}

	MOVEYX(win->Frame, 0, 2); PRINTN(win->Frame, win->Text, len);
	if (rc.W > 2)
	{
		MOVEYX(win->Frame, 0, 1); PRINT(win->Frame, _T(" "));
		MOVEYX(win->Frame, 0, len + 2); PRINT(win->Frame, _T(" "));
	}
}


/* ---------------------------------------------------------------------
 * ConfviewPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
ConfviewPaintHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	CONFVIEWDATA* data;
	int           ypos;
	int           line = 0;
	short         index[5];
	CONFITEM*     workptr;

	data = (CONFVIEWDATA*) win->InstData;
	if (!data || !data->ConfData) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0) || (rc.H <= 0)) return;

	ypos = -(WindowGetVScrollPos(win));

	data->HasSeparator = TRUE;

	workptr = data->ConfData->FirstItem;

	while (workptr && (ypos <= rc.H))
	{
		if (ConfFileArrayLookupVisible(workptr, index, 0))
		{
			line = ConfviewShowItem(win, data, workptr, 0, line, FALSE, &ypos, index);
		}
		workptr = (CONFITEM*) workptr->Next;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int
ConfviewSizeHook(void* w)
{
	ConfviewCalculate((CUIWINDOW*) w);
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ConfviewKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
ConfviewKeyHook(void* w, int key)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	CONFVIEWDATA*  data = (CONFVIEWDATA*) win->InstData;
	CUIRECT        rc;

	if (!data) return FALSE;

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
			if (data->ConfData)
			{
				if (data->IsDragging)
				{
					if (ConfFileDragValueDown(data->ConfData, &data->CursorPos))
					{
						ConfviewCalculate(win);
						ConfviewUpdate(win);
					}
				}
				else
				{
					if ((data->CursorPos < (data->NumVisOptions - 1)) && ConfviewQueryChange(win, data))
					{
						data->CursorPos++;

						ConfviewCalculate(win);
						ConfviewUpdate(win);
						ConfviewNotifyChange(win, data);
					}
				}
			}
			return TRUE;
		case KEY_UP:
			if (data->ConfData)
			{
				if (data->IsDragging)
				{
					if (ConfFileDragValueUp(data->ConfData, &data->CursorPos))
					{
						ConfviewCalculate(win);
						ConfviewUpdate(win);
					}
				}
				else
				{
					if ((data->CursorPos > 0) && ConfviewQueryChange(win, data))
					{
						data->CursorPos--;

						ConfviewCalculate(win);
						ConfviewUpdate(win);
						ConfviewNotifyChange(win, data);
					}
				}
			}
			return TRUE;
		case KEY_NPAGE:
			if (data->ConfData && !data->IsDragging )
			{
				if ((data->CursorPos < (data->NumVisOptions - 1)) && ConfviewQueryChange(win, data))
				{
					data->CursorPos += (rc.H / 4 + 2);
					if (data->CursorPos >= data->NumVisOptions)
					{
						data->CursorPos = data->NumVisOptions - 1;
					}

					ConfviewCalculate(win);
					ConfviewUpdate(win);
					ConfviewNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_PPAGE:
			if ((data->ConfData && !data->IsDragging )&& ConfviewQueryChange(win, data))
			{
				if (data->CursorPos > 0)
				{
					data->CursorPos -= (rc.H / 4 + 2);
					if (data->CursorPos < 0)
					{
						data->CursorPos = 0;
					}

					ConfviewCalculate(win);
					ConfviewUpdate(win);
					ConfviewNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_HOME:
			if (data->ConfData && !data->IsDragging )
			{
				if ((data->CursorPos > 0) && ConfviewQueryChange(win, data))
				{
					data->CursorPos = 0;

					ConfviewCalculate(win);
					ConfviewUpdate(win);
					ConfviewNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_END:
			if (data->ConfData && !data->IsDragging )
			{
				if ((data->CursorPos < (data->NumVisOptions - 1)) && ConfviewQueryChange(win, data))
				{
					data->CursorPos = data->NumVisOptions - 1;

					ConfviewCalculate(win);
					ConfviewUpdate(win);
					ConfviewNotifyChange(win, data);
				}
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
 * ConfviewVScrollHook
 * Confview scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
ConfviewVScrollHook(void* w, int sbcode, int pos)
{
	CUI_USE_ARG(w);
	CUI_USE_ARG(sbcode);
	CUI_USE_ARG(pos);
	
	/* not implemented right now */
}

/* ---------------------------------------------------------------------
 * ConfviewDestroyHook
 * Handle EVENT_DELETE event
 * ---------------------------------------------------------------------
 */
static void
ConfviewDestroyHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	free (win->InstData);
}

/* ---------------------------------------------------------------------
 * ConfviewSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ConfviewSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CONFVIEWDATA* data = (CONFVIEWDATA*) win->InstData;

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
 * ConfviewKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ConfviewKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CONFVIEWDATA* data = (CONFVIEWDATA*) win->InstData;

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
 * ConfviewNew
 * Create a config view dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ConfviewNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* confview;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		confview = WindowNew(parent, x, y, w, h, flags);
		confview->Class = _T("CONFVIEW");
		WindowSetId(confview, id);
		WindowSetNcPaintHook(confview, ConfviewNcPaintHook);
		WindowSetPaintHook(confview, ConfviewPaintHook);
		WindowSetKeyHook(confview, ConfviewKeyHook);
		WindowSetSetFocusHook(confview, ConfviewSetFocusHook);
		WindowSetKillFocusHook(confview, ConfviewKillFocusHook);
		WindowSetSizeHook(confview, ConfviewSizeHook);
		WindowSetVScrollHook(confview, ConfviewVScrollHook);
		WindowSetDestroyHook(confview, ConfviewDestroyHook);

		confview->InstData = (CONFVIEWDATA*) malloc(sizeof(CONFVIEWDATA));
		((CONFVIEWDATA*)confview->InstData)->SetFocusHook    = NULL;
		((CONFVIEWDATA*)confview->InstData)->KillFocusHook   = NULL;
		((CONFVIEWDATA*)confview->InstData)->PreKeyHook      = NULL;
		((CONFVIEWDATA*)confview->InstData)->PostKeyHook     = NULL;
		((CONFVIEWDATA*)confview->InstData)->LbChangedHook   = NULL;
		((CONFVIEWDATA*)confview->InstData)->LbChangingHook  = NULL;
		((CONFVIEWDATA*)confview->InstData)->LbClickedHook   = NULL;
		((CONFVIEWDATA*)confview->InstData)->CursorPos = 0;
		((CONFVIEWDATA*)confview->InstData)->RelCursor = 0;
		((CONFVIEWDATA*)confview->InstData)->RelCursorSize = 9;
		((CONFVIEWDATA*)confview->InstData)->NumVisOptions = 0;
		((CONFVIEWDATA*)confview->InstData)->YRange = 0;
		((CONFVIEWDATA*)confview->InstData)->HasSeparator = FALSE;
		((CONFVIEWDATA*)confview->InstData)->ConfData = NULL;
		((CONFVIEWDATA*)confview->InstData)->IsDragging = FALSE;

		WindowSetText(confview, text);

		return confview;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfviewSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetSetFocusHook(CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->SetFocusHook = proc;
		((CONFVIEWDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->KillFocusHook = proc;
		((CONFVIEWDATA*)win->InstData)->KillFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ConfviewSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->PreKeyHook = proc;
		((CONFVIEWDATA*)win->InstData)->PreKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->PostKeyHook = proc;
		((CONFVIEWDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetLbChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetLbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->LbChangedHook = proc;
		((CONFVIEWDATA*)win->InstData)->LbChangedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetLbChangingHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->LbChangingHook = proc;
		((CONFVIEWDATA*)win->InstData)->LbChangingTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetLbClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ConfviewSetLbClickedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		((CONFVIEWDATA*)win->InstData)->LbClickedHook = proc;
		((CONFVIEWDATA*)win->InstData)->LbClickedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSetData
 * Associate the file 'filename' to the view
 * ---------------------------------------------------------------------
 */
void
ConfviewSetData(CUIWINDOW* win, CONFFILE* confdata)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;

		data->ConfData = confdata;
		data->CursorPos = 0;
		data->RelCursor = 0;
		data->RelCursorSize = 0;
		data->NumVisOptions = 0;
		data->YRange = 0;

		ConfviewCalculate(win);
		ConfviewUpdate(win);
		ConfviewNotifyChange(win, data);
	}
}


/* ---------------------------------------------------------------------
 * ConfviewUpdateData
 * Update current data by recalculating the list
 * ---------------------------------------------------------------------
 */
void
ConfviewUpdateData(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		ConfviewCalculate(win);
		ConfviewUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * ConfviewGetSel
 * Get index of selected item
 * ---------------------------------------------------------------------
 */
int
ConfviewGetSel(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;

		if (data->ConfData)
		{
			return data->CursorPos;
		}
	}
	return -1;
}

/* ---------------------------------------------------------------------
 * ConfviewSetSel
 * Set the select index
 * ---------------------------------------------------------------------
 */
void
ConfviewSetSel(CUIWINDOW* win, int selindex)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;

		if (data->ConfData && (selindex < data->NumVisOptions))
		{
			if ((selindex != data->CursorPos) && (ConfviewQueryChange(win, data)))
			{
				data->CursorPos = selindex;
				ConfviewCalculate(win);
				ConfviewUpdate(win);
				ConfviewNotifyChange(win, data);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfviewToggleOptView
 * Toggle drag mode
 * ---------------------------------------------------------------------
 */ 
void 
ConfviewToggleOptView(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;
		CONFITEM*     selitem = NULL;
		short         index[NUM_DIM];

		/* save old cursor pos */
		int lineindex = data->CursorPos;
		if (lineindex > 0)
		{
			CONFVALUE* selval = ConfFileGetValue(data->ConfData, lineindex);
			while ((selval == NULL) && (lineindex > 0))
			{
				lineindex--;
				selval = ConfFileGetValue(data->ConfData, lineindex);
			}
			selitem = ConfFileGetItem(data->ConfData, lineindex);
			if (selitem)
			{
				ConfFileGetIndex(data->ConfData, lineindex, index);
			}			
		}

		/* switch visibility on or off */
		ConfFileSetOptionalOn(!ConfFileGetOptionalOn());

		/* calculate new cursor pos */
		data->CursorPos = 0;
		if (selitem)
		{
			data->CursorPos = ConfFileGetLineIndex(data->ConfData, selitem, index);
		}		
		ConfviewUpdateData(win);
	}
}

/* ---------------------------------------------------------------------
 * ConfviewToggleDrag
 * Toggle drag mode
 * ---------------------------------------------------------------------
 */
void
ConfviewToggleDrag(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;

		if (!data->IsDragging && data->ConfData)
		{
			data->IsDragging = ConfFileStartDrag(data->ConfData, data->CursorPos);
			if (data->IsDragging)
			{
				ConfviewUpdate(win);
			}
		}
		else if (data->IsDragging)
		{
			ConfFileEndDrag(data->ConfData);
			data->IsDragging = FALSE;
			ConfviewUpdate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfviewIsInDrag
 * Query if the control is currently dragging an array index
 * ---------------------------------------------------------------------
 */
int
ConfviewIsInDrag(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		return ((CONFVIEWDATA*)win->InstData)->IsDragging;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfigTextSearch
 * Perform a full text search within the current configuration tree
 * ---------------------------------------------------------------------
 */
int
ConfviewSearch(CUIWINDOW* win, const wchar_t* text, int wholeword, int casesens, int down)
{
	if (win && (wcscmp(win->Class, _T("CONFVIEW")) == 0))
	{
		CONFVIEWDATA* data = (CONFVIEWDATA*)win->InstData;
		ECESEARCH     sdata;
		CONFITEM*     workptr;
		int           line = 0;
		short         index[5];       /* only five hierarchy levels */
		int           result;
		int           lineindex;

		if (data->ConfData)
		{
			lineindex = data->CursorPos;

			sdata.Keyword    = text;
			sdata.WholeWords = wholeword;
			sdata.CaseSens   = casesens;

			if ((lineindex < 0) && !down)
			{
				lineindex = data->NumVisOptions;
			}

			if (down)
			{
				line = 0;
				workptr = data->ConfData->FirstItem;
				while (workptr)
				{
					if (ConfFileArrayLookupVisible(workptr, index, 0))
					{
						result = ConfviewSearchValueByIndexD (workptr, 0, &line, lineindex, index, &sdata);
						if (result >= 0)
						{
							ConfviewSetSel(win, result);
							return TRUE;
						}
					}
					workptr = (CONFITEM*) workptr->Next;
				}
			}
			else
			{
				line = data->NumVisOptions - 1;
				workptr = data->ConfData->LastItem;
				while (workptr)
				{
					if (ConfFileArrayLookupVisible(workptr, index, 0))
					{
						result = ConfviewSearchValueByIndexU (workptr, 0, &line, lineindex, index, &sdata);
						if (result >= 0)
						{
							ConfviewSetSel(win, result);
							return TRUE;
						}
					}
					workptr = (CONFITEM*) workptr->Previous;
				}
			}
		}
	}
	return FALSE;
}




/* helper functions */

/* ---------------------------------------------------------------------
 * ConfviewCalculate
 * Recalculate Confview metrics
 * ---------------------------------------------------------------------
 */
static void
ConfviewCalculate(CUIWINDOW* win)
{
	CUIRECT rc;
	CONFVIEWDATA* data = (CONFVIEWDATA*) win->InstData;
	int pos1;
	int pos2;

	WindowGetClientRect(win, &rc);

	ConfviewUpdateListMetrics(win, data);
	if (data)
	{
		int yscroll = WindowGetVScrollPos(win);

		pos1 = data->RelCursor;
		pos2 = data->RelCursor + data->RelCursorSize - 1;

		if (pos1 >= 0)
		{
			if (pos2 >= (rc.H + yscroll))
			{
				WindowSetVScrollPos(win, pos2 - rc.H + 1);
			}
			else if (pos1 < yscroll)
			{
				WindowSetVScrollPos(win, pos1);
			}
			if ((data->CursorPos == 0) && (yscroll > 0))
			{
				WindowSetVScrollPos(win, 0);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfviewUpdateListMetrics
 * Counts the number of options (values) that are visible (not hidden by the
 * item's optnode) and the absolute length of the list including seperators
 * also updates the cursor min max positions
 * ---------------------------------------------------------------------
 */
static void
ConfviewUpdateListMetrics(CUIWINDOW* win, CONFVIEWDATA* data)
{
	CUIRECT   rc;
	CONFITEM* workptr;
	short     index[5];

	data->NumVisOptions = 0;
	data->YRange = 0;
	data->RelCursor = 0;
	data->RelCursorSize = 1;
	data->HasSeparator = TRUE;

	if (data->ConfData)
	{
		workptr = data->ConfData->FirstItem;
		while (workptr)
		{
			if (ConfFileArrayLookupVisible(workptr, index, 0))
			{
				ConfviewUpdateItemMetrics(win, workptr, 0, index);
			}
			workptr = (CONFITEM*) workptr->Next;
		}
	}

	WindowGetClientRect(win, &rc);
	if (data->YRange - rc.H > 0)
	{
		WindowSetVScrollRange(win, data->YRange - rc.H);
		WindowEnableVScroll(win, TRUE);
	}
	else
	{
		WindowSetVScrollRange(win, 0);
		WindowEnableVScroll(win, FALSE);
	}
}

/* ---------------------------------------------------------------------
 * ConfviewUpdateItemMetrics
 * Runs through the tree calculating the number of visible values, the
 * real display length of the list and the "relative" cursor position
 * = number of values and separators bevor the current cursor position
 * ---------------------------------------------------------------------
 */
static void
ConfviewUpdateItemMetrics(CUIWINDOW* win, CONFITEM* item, int level, short* index)
{
	CONFVALUE*   valptr;
	CONFITEM*    workptr;
	CONFCOMMENT* valcmmt;
	int numlines;

	if (level > 4) return;  /* limit iteration depth */

	/* is there a block comment trailing this option ? */
	valcmmt = item->FirstBlockComment;
	if (valcmmt)
	{
		if (!((CONFVIEWDATA*) win->InstData)->HasSeparator)
		{
			((CONFVIEWDATA*) win->InstData)->YRange++;
			((CONFVIEWDATA*) win->InstData)->HasSeparator = TRUE;
		}
		while (valcmmt)
		{
			((CONFVIEWDATA*) win->InstData)->YRange++;

			if ((item->NumBlockComments > 10) &&
			    (valcmmt != item->FirstBlockComment) &&
			    (valcmmt != item->LastBlockComment))
			{
				valcmmt = item->LastBlockComment;
			}
			else
			{
				valcmmt = (CONFCOMMENT*) valcmmt->Next;
			}
		}
		((CONFVIEWDATA*) win->InstData)->YRange++;
		((CONFVIEWDATA*) win->InstData)->HasSeparator = TRUE;
	}

	valptr = ConfFileArrayLookupValue(item, index, level);
	if (valptr)
	{
		numlines = ConfviewShowLine(win,
			valptr->Name,
			valptr->Value,
			((CONFVIEWDATA*) win->InstData)->YRange,
			level,
			((CONFVIEWDATA*) win->InstData)->NumVisOptions,
			FALSE,
			item->IsReadOnly,
			FALSE);
	}
	else
	{
		wchar_t buffer[128 + 1];
		ConfFileArrayLookupName(item, index, level, buffer, 128);
		numlines = ConfviewShowLine(win,
			buffer,
			_T("<<< no value >>>"),
			((CONFVIEWDATA*) win->InstData)->YRange,
			level,
			((CONFVIEWDATA*) win->InstData)->NumVisOptions,
			FALSE,
			item->IsReadOnly,
			FALSE);
	}

	if (((CONFVIEWDATA*) win->InstData)->NumVisOptions == ((CONFVIEWDATA*) win->InstData)->CursorPos)
	{
		((CONFVIEWDATA*) win->InstData)->RelCursor     = ((CONFVIEWDATA*) win->InstData)->YRange;
		((CONFVIEWDATA*) win->InstData)->RelCursorSize = numlines;
	}

	((CONFVIEWDATA*) win->InstData)->YRange += numlines;
	((CONFVIEWDATA*) win->InstData)->NumVisOptions++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr, index, level + 1))
				{
					ConfviewUpdateItemMetrics(win, workptr, level + 1, index);
				}
				workptr = (CONFITEM*) workptr->Next;
			}
			if (((CONFITEM*)item->Child)->Next)
			{
				((CONFVIEWDATA*) win->InstData)->YRange++;
				((CONFVIEWDATA*) win->InstData)->HasSeparator = TRUE;
			}
		}
		if (!((CONFITEM*)item->Child)->Next)
		{
			((CONFVIEWDATA*) win->InstData)->YRange++;
			((CONFVIEWDATA*) win->InstData)->HasSeparator = TRUE;
		}
	}
	else if (item->Next)
	{
		if (((CONFITEM*)item->Next)->Child)
		{
			((CONFVIEWDATA*) win->InstData)->YRange++;
			((CONFVIEWDATA*) win->InstData)->HasSeparator = TRUE;
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfviewShowComment (display helper)
 * Print one line of comment onto the screen
 * ---------------------------------------------------------------------
 */
static void
ConfviewShowComment(CUIWINDOW* win, const wchar_t* text, int ypos)
{
	CUIRECT rc;
	int len;
	int seperator = FALSE;

	WindowGetClientRect(win, &rc);
	len = wcslen(text);
	if (len > (rc.W - 1))
	{
		len = rc.W - 1;
	}

	/* is it a seperator line */
	if (wcsstr(text,_T("---------------------------")))
	{
		seperator = TRUE;
		len = rc.W;
	}

	/* show comment */
	if ((ypos >= 0) && (ypos < rc.H))
	{
		if (win->IsEnabled)
		{
			SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
		}
		else
		{
			SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
		}
		if (seperator)
		{
			MOVEYX(win->Win, ypos, 0);
			while (len > 0)
			{
				int c = (len > 32) ? 32 : len;
				PRINTN(win->Win, _T("---------------------------------"), c);
				len -= c;
			}
		}
		else
		{
			MOVEYX(win->Win, ypos, 1);
			PRINTN(win->Win, text, len);
		}
	}
	((CONFVIEWDATA*)(win->InstData))->HasSeparator = FALSE; /* signal that an comment has been printed */
}

/* ---------------------------------------------------------------------
 * ConfviewShowLine (display helper)
 * Print a config value, specified by 'name' and 'value' on the screen
 * within the area specified by the 'conf'-structure
 * The function returns the number of display lines used to display the
 * value. If the parameter 'do_print' is FALSE, the date are not
 * printed to the screen. Only counting is performed.
 * ---------------------------------------------------------------------
 */
static int
ConfviewShowLine(CUIWINDOW* win, const wchar_t* name, const wchar_t* value, int ypos,
               int level, int line, int drag, int readonly, int do_print)
{
	CUIRECT rc;
	int     tabpos;                             /* position of vertical separator */
	int     rwidth;                             /* width of right area */
	int     lwidth;                             /* width of left area */
	int     num_lines = 0;                      /* number of lines for the value */
	int     namelines = 0;                      /* number of lines needed for the name */
	int     selected;
	const wchar_t *start, *end, *next;

	WindowGetClientRect(win, &rc);

	tabpos = ((32 * rc.W) / 80);
	rwidth = rc.W - tabpos - 3;
	lwidth = tabpos - 2;

	if (rwidth <= 0) return 1;

//	wcslen(name);
//	wcslen(value);

	/* show value name */

	start = &name[0];
	end = &name[0];

	while (*start != 0)
	{
		next = wcschr(start, _T('_'));
		if (!next)
		{
			next = &name[wcslen(name)];
		}

		while ((next - start) <= (lwidth - 2 * level))
		{
			end = next;

			if (*next != 0)
			{
				next = wcschr(next + 1,'_');
				if (!next) next = &name[wcslen(name)];
			}
			else break;
		}

		if ((next - start > (lwidth - 2 * level))&&(end == start))
		{
			end += (lwidth - 2 * level);
		}

		if (do_print && (ypos + namelines >= 0) &&
		   (ypos + namelines < rc.H))
		{
			int len;

			if (win->IsEnabled)
			{
				if (!readonly)
				{
					SetColor(win->Win, win->Color.HilightColor, win->Color.WndColor, FALSE);
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

			len = (end - start) < (lwidth - 2 * level) ? (end - start) : (lwidth - 2 * level);
			MOVEYX(win->Win, ypos + namelines, 2 * level + 1);
			PRINTN(win->Win, start, len);
		}

		while (*end == _T('_'))
		{
			end++;
		}

		start = end;

		namelines++;
	}

	/* equal sign */
	if (do_print && (ypos >= 0) &&
	   (ypos < rc.H))
	{
		if (win->IsEnabled)
		{
			SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
		}
		else
		{
			SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
		}
		MOVEYX(win->Win, ypos, tabpos - 1);
		if (drag)
		{
			PRINT(win->Win, _T(">"));
		}
		else
		{
			PRINT(win->Win, _T("="));
		}
	}

	/* set selection or normal color */
	if (do_print)
	{
		selected = FALSE;
		if (win->IsEnabled)
		{
			if ((line == ((CONFVIEWDATA*)(win->InstData))->CursorPos) || drag)
			{
				selected = TRUE;
				if ((ypos + num_lines >= 0) && (ypos + num_lines < rc.H))
				{
					WindowSetCursor(win, tabpos + 1, ypos);
				}
				SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
			}
			else
			{
				SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
			}
		}
		else
		{
			if ((line == ((CONFVIEWDATA*)(win->InstData))->CursorPos) || drag)
			{
				selected = TRUE;
				if ((ypos + num_lines >= 0) && (ypos + num_lines < rc.H))
				{
					WindowSetCursor(win, tabpos + 1, ypos);
				}
				SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndSelColor, TRUE);
			}
			else
			{
				SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
			}
		}
	}

	start = &value[0];
	end = &value[0];

	while ((*start != 0) || (num_lines < namelines))
	{
		next = wcschr(start, _T(' '));
		if (!next)
		{
			next = &value[wcslen(value)];
		}

		while ((next - start <= rwidth))
		{
			end = next;

			if (*next != 0)
			{
				next = wcschr(next + 1, _T(' '));
				if (!next) next = &value[wcslen(value)];
			}
			else break;
		}

		if ((next - start > rwidth)&&(end == start))
		{
			end += rwidth;
		}

		if (do_print && (ypos + num_lines >= 0) &&
		   (ypos + num_lines < rc.H))
		{
			int len = (end - start) < rwidth ? (end - start) : rwidth;
			if (selected)
			{
				MOVEYX(win->Win, ypos + num_lines, tabpos + 1);
				PRINT(win->Win, _T(" "));
			}
			MOVEYX(win->Win, ypos + num_lines, tabpos + 2);
			PRINTN(win->Win, start, len);
			if (selected)
			{
				while (len < rwidth)
				{
					PRINT(win->Win, _T(" "));
					len ++;
				}
			}
		}

		while (*end == _T(' '))
		{
			end++;
		}
		start = end;

		num_lines++;
	}
	if (num_lines == 0) num_lines = 1;

	((CONFVIEWDATA*)(win->InstData))->HasSeparator = FALSE; /* signal that an item has been printed */

	return num_lines;
}

/* ---------------------------------------------------------------------
 * ConfviewShowItem (display helper)
 * Recursively runs through the item tree, retreives the associated values
 * and calls 'ShowConfigLine' to display the data.
 * ---------------------------------------------------------------------
 */
static int
ConfviewShowItem(CUIWINDOW* win, CONFVIEWDATA* data, CONFITEM* item,
                 int level, int line, int drag, int* ypos, short* index)
{
	CUIRECT      rc;
	CONFVALUE*   valptr;
	CONFITEM*    workptr;
	CONFCOMMENT* valcmmt;

	if (level > 4) return line;  /* limit iteration depth */

	WindowGetClientRect(win, &rc);

	/* is there a block comment trailing this option ? */
	valcmmt = item->FirstBlockComment;
	if (valcmmt)
	{
		if (!data->HasSeparator)
		{
			data->HasSeparator = TRUE;
			(*ypos)++;
		}
		while (valcmmt)
		{
			wchar_t  buffer[128 + 1];
			wchar_t* p = valcmmt->Text;
			while (*p == _T('#')) p++;

			swprintf(buffer, 128, p, index[0], index[1], index[2], index[3], index[4]);
			buffer[128] = 0;

			ConfviewShowComment(win, buffer, *ypos);
			(*ypos)++;

			if ((item->NumBlockComments > 10) &&
			    (valcmmt != item->FirstBlockComment) &&
			    (valcmmt != item->LastBlockComment))
			{
				valcmmt = item->LastBlockComment;
			}
			else
			{
				valcmmt = (CONFCOMMENT*) valcmmt->Next;
			}
		}
		data->HasSeparator = TRUE;
		(*ypos)++;
	}

	/* show the option itself */
	valptr = ConfFileArrayLookupValue(item, index, level);
	if (valptr)
	{
		if (!item->IsMasked)
		{
			*ypos += ConfviewShowLine(win,
				valptr->Name,
				valptr->Value,
				*ypos,
				level,
				line,
				drag,
				item->IsReadOnly,
				TRUE);
		}
		else
		{
			*ypos += ConfviewShowLine(win,
				valptr->Name,
				_T("************"),
				*ypos,
				level,
				line,
				drag,
				item->IsReadOnly,
				TRUE);
		}
		line++;
	}
	else
	{
		wchar_t buffer[128 + 1];
		*ypos += ConfviewShowLine(win,
			ConfFileArrayLookupName(item, index, level, buffer, 128),
			_T("<<< no value >>>"),
			*ypos,
			level,
			line,
			drag,
			item->IsReadOnly,
			TRUE);
		line++;
	}

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		int dragchild;

		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			dragchild = drag;
			if (((CONFVIEWDATA*)(win->InstData))->IsDragging && !drag)
			{
				if ((item == ((CONFVIEWDATA*)(win->InstData))->ConfData->DragItem) &&
				    (memcmp(index, ((CONFVIEWDATA*)(win->InstData))->ConfData->DragIndex, (level + 1) * sizeof(short)) == 0))
				{
					dragchild = TRUE;
				}
			}

			workptr = item->Child;
			while (workptr && (*ypos <= rc.H))
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					line = ConfviewShowItem(win,
						data,
						workptr,
						level+1,
						line,
						dragchild,
						ypos,
						index);
				}
				workptr = (CONFITEM*) workptr->Next;
			}
			if (((CONFITEM*)item->Child)->Next)
			{
				data->HasSeparator = TRUE;
				(*ypos)++;
 			}
		}
		if (!((CONFITEM*)item->Child)->Next)
		{
			data->HasSeparator = TRUE;
			(*ypos)++;
		}
	}
	else if (item->Next)
	{
		if (((CONFITEM*)item->Next)->Child)
		{
			data->HasSeparator = TRUE;
			(*ypos)++;
		}
	}
	return line;
}

/* ---------------------------------------------------------------------
 * ConfviewUpdate
 * Update listbox view
 * ---------------------------------------------------------------------
 */
static void
ConfviewUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}

/* ---------------------------------------------------------------------
 * ConfviewQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int
ConfviewQueryChange(CUIWINDOW* win, CONFVIEWDATA* data)
{
	if (data->LbChangingHook)
	{
		return data->LbChangingHook(data->LbChangingTarget, win);
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ConfviewNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void
ConfviewNotifyChange(CUIWINDOW* win, CONFVIEWDATA* data)
{
	if (data->LbChangedHook)
	{
		data->LbChangedHook(data->LbChangedTarget, win);
	}
}

/* ---------------------------------------------------------------------
 * ConfviewSearchValueByIndexD
 * Search the tree match find a given search pattern, starting at the
 * line specified by 'lineindex'
 * ---------------------------------------------------------------------
 */
static int
ConfviewSearchValueByIndexD (CONFITEM* item, int level, int* line, int lineindex, short* index, ECESEARCH* sdata)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return -1;         /* limit iteration depth */

	valptr = ConfFileArrayLookupValue(item,index,level);
	if ((*line > lineindex) && valptr)
	{
		if (ConfviewMatch(valptr->Name, sdata))
		{
			return *line;
		}
		if (ConfviewMatch(valptr->Value, sdata))
		{
			return *line;
		}
	}
	(*line)++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					int idx = ConfviewSearchValueByIndexD(workptr,level+1,line,lineindex,index,sdata);
					if (idx >= 0) return idx;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return -1;
}

/* ---------------------------------------------------------------------
 * ConfviewSearchValueByIndexU
 * Search the tree match find a given search pattern, starting at the
 * line specified by 'lineindex'
 * ---------------------------------------------------------------------
 */
int
ConfviewSearchValueByIndexU (CONFITEM* item, int level, int* line, int lineindex, short* index, ECESEARCH* sdata)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return -1;         /* limit iteration depth */

	valptr = ConfFileArrayLookupValue(item,index,level);

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = count; i > 0; i--)
		{
			index[level] = i;

			workptr = item->Last;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					int idx = ConfviewSearchValueByIndexU(workptr,level+1,line,lineindex,index,sdata);
					if (idx >= 0) return idx;
				}
				workptr = (CONFITEM*) workptr->Previous;
			}
		}
	}

	if ((*line < lineindex) && valptr)
	{
		if (ConfviewMatch(valptr->Name, sdata))
		{
			return *line;
		}
		if (ConfviewMatch(valptr->Value, sdata))
		{
			return *line;
		}
	}
	(*line)--;

	return -1;
}

/* ---------------------------------------------------------------------
 * ConfviewIsChar
 * Check if 'c' is a alphanumeric character. Include special german
 * and frensh letters (that's why isalpha() is not used)
 * ---------------------------------------------------------------------
 */
static int
ConfviewIsChar(wchar_t c)
{
	return iswalnum(c);
}

/* ---------------------------------------------------------------------
 * ConfviewMatchWord
 * Compare two text strings
 * ---------------------------------------------------------------------
 */
static int
ConfviewMatchWord(const wchar_t* text, ECESEARCH* sdata)
{
	const wchar_t* s1 = text;
	const wchar_t* s2 = sdata->Keyword;
	int len = wcslen(s2);
	int i;

	if (!sdata->CaseSens)
	{
		for (i = 0; i < len; i++)
		{
			if (towlower(*s1) != towlower(*s2))
			{
				return FALSE;
			}
			s1++;
			s2++;
		}
	}
	else
	{
		for (i = 0; i < len; i++)
		{
			if (*s1 != *s2)
			{
				return FALSE;
			}
			s1++;
			s2++;
		}
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ConfviewMatch
 * Look for a match of sdata->Keyword within text
 * ---------------------------------------------------------------------
 */
static int
ConfviewMatch(const wchar_t* text, ECESEARCH* sdata)
{
	wchar_t        searchc = towlower(sdata->Keyword[0]);
	const wchar_t* c = text;

	while (*c)
	{
		if ((wchar_t)towlower(*c) == searchc)
		{
			if (ConfviewMatchWord(c,sdata))
			{
				wchar_t lastc = c[wcslen(sdata->Keyword)];
				if (!(sdata->WholeWords && (c > text) && (ConfviewIsChar(*(c - 1)))))
				{
					if (!(sdata->WholeWords && ConfviewIsChar(lastc)))
					{
						return TRUE;
					}
				}
			}
		}
		c++;
	}
	return FALSE;
}

