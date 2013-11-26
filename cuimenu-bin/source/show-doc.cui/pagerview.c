/* ---------------------------------------------------------------------
 * File: pagerview.c
 * (pager text view window)
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
#include "pagerview.h"
#include "pagerfile.h"

/* local constants */
#define TABWIDTH      8
#define IDC_TAILTIMER 10


typedef struct 
{
	int          SelPos1, SelPos2;
	int          NumLines;
	int          MaxWidth;
	int          DoWordWrap;
	int          TailOn;
	long         FirstPos;
	long         LastPos;
	PAGERFILE*   File;
	wchar_t*       Filter;

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
} PAGERVIEWDATA;


/* local prototypes */

static void PagerviewShowLine(CUIWINDOW* win, const wchar_t* text, int ypos, int selpos1, int selpos2, int do_print);
static void PagerviewUpdate(CUIWINDOW* win);
static void PagerviewCalculate(CUIWINDOW* win);
static int  PagerviewLineLength(const wchar_t* line);
static int  PagerviewMatchWord(PAGERFILE* pfile, int c, const wchar_t* s2, int casesens);
static int  PagerviewIsChar(wchar_t c);
static void PagerviewCheckSelectionPos(CUIWINDOW* win);
static void PagerviewGotoEnd(CUIWINDOW* win, int force);
static long PagerviewNextLine(PAGERVIEWDATA* data, long pos, wchar_t** lbuffer);
static long PagerviewPrevLine(PAGERVIEWDATA* data, long pos, wchar_t** lbuffer);


/* ---------------------------------------------------------------------
 * PagerviewNcPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
PagerviewNcPaintHook(void* w, int size_x, int size_y)
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
		if (!win->Text || (win->Text[0] == 0)) return;

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
}


/* ---------------------------------------------------------------------
 * PagerviewPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
PagerviewPaintHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	PAGERVIEWDATA* data;
	int           ypos;
	wchar_t*        lbuffer;

	data = (PAGERVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	WindowGetVScrollPos(win);

	/* show text */
	ypos = 0;

	if (data->File)
	{
		long pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
		long lastpos = data->FirstPos;

		while ((pos != NOPOS) && (ypos < rc.H))
		{
			if ((data->SelPos2 <= lastpos) || (data->SelPos1 >= pos))
			{
				PagerviewShowLine(win, lbuffer, ypos, 0, 0, TRUE);
			}
			else if ((data->SelPos1 >= lastpos) && (data->SelPos2 <= pos))
			{
				PagerviewShowLine(win, lbuffer, ypos, 
				   data->SelPos1 - lastpos, data->SelPos2 - lastpos, TRUE);
			}
			else if (data->SelPos1 >= lastpos)
			{
				PagerviewShowLine(win, lbuffer, ypos, 
				   data->SelPos1 - lastpos, wcslen(lbuffer), TRUE);
			}
			else if (data->SelPos2 <= pos)
			{
				PagerviewShowLine(win, lbuffer, ypos, 
				   0, data->SelPos2 - lastpos, TRUE);
			}
			else
			{
				PagerviewShowLine(win, lbuffer, ypos, 
				   0, wcslen(lbuffer), TRUE);
			}
			ypos++;

			lastpos = pos;
			pos = PagerviewNextLine(data, pos, &lbuffer);
		}
	}	
	WindowSetCursor(win, 0, 0);
}


/* ---------------------------------------------------------------------
 * PagerviewSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int 
PagerviewSizeHook(void* w)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;

	PagerviewCalculate(win);
	if (data->TailOn)
	{
		PagerviewGotoEnd(win, FALSE);
	}
	return TRUE;
}


/* ---------------------------------------------------------------------
 * PagerviewKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
PagerviewKeyHook(void* w, int key)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;
	CUIRECT        rc;
	int            xscroll;
	int            xrange;
	wchar_t*         lbuffer;

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
			if (data->File)
			{
				long pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
				if (pos != NOPOS)
				{
					data->FirstPos = pos;
					PagerviewCalculate(win);
					PagerviewUpdate(win);
				}
			}
			return TRUE;
		case KEY_UP:
			if (data->File)
			{
				long pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
				if (pos != NOPOS)
				{
					data->FirstPos = pos;
					PagerviewCalculate(win);
					PagerviewUpdate(win);
				}
			}
			return TRUE;
		case KEY_NPAGE:
			if (data->File)
			{
				int  ypos = 0;
				long pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
				if (pos != NOPOS)
				{
					while ((pos != NOPOS) && (ypos < (rc.H - 1)))
					{
						data->FirstPos = pos;
						pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
						ypos++;
					}
					PagerviewCalculate(win);
					PagerviewUpdate(win);
				}
			}
			return TRUE;			
		case KEY_PPAGE:
			if (data->File)
			{
				int  ypos = 0;
				long pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
				if (pos != NOPOS)
				{
					while ((pos != NOPOS) && (ypos < (rc.H - 1)))
					{
						data->FirstPos = pos;
						pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
						ypos++;
					}
					PagerviewCalculate(win);
					PagerviewUpdate(win);
				}
			}
			return TRUE;			
		case KEY_HOME:
			if (data->File && ((data->FirstPos > 0) || (xscroll > 0))) 
			{
				WindowSetHScrollPos(win, 0);

				data->FirstPos = 0;
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
			return TRUE;
		case KEY_END:
			if (data->File) 
			{
				PagerviewGotoEnd(win, FALSE);
			}
			return TRUE;
		case KEY_RIGHT:
			if (xscroll < xrange)
			{
				WindowSetHScrollPos(win, xscroll + 1);
				PagerviewUpdate(win);
			}
			return TRUE;
		case KEY_LEFT:
			if (xscroll > 0) 
			{
				WindowSetHScrollPos(win, xscroll - 1);
				PagerviewUpdate(win);
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
 * PagerviewVScrollHook
 * Pagerview scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
PagerviewVScrollHook(void* w, int sbcode, int pos)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;
	CUIRECT        rc;
	wchar_t*         lbuffer;

	WindowGetClientRect(win, &rc);

	switch(sbcode)
	{
	case SB_LINEUP:
		if (data->File)
		{
			long pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
			if (pos != NOPOS)
			{
				data->FirstPos = pos;
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
		}
		break;
	case SB_LINEDOWN:
		if (data->File)
		{
			long pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
			if (pos != NOPOS)
			{
				data->FirstPos = pos;
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
		}
		break;
	case SB_PAGEUP:
		if (data->File)
		{
			int  ypos = 0;
			long pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
			if (pos != NOPOS)
			{
				while ((pos != NOPOS) && (ypos < (rc.H - 1)))
				{
					data->FirstPos = pos;
					pos = PagerviewPrevLine(data, data->FirstPos, &lbuffer);
					ypos++;
				}
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
		}
		break;
	case SB_PAGEDOWN:
		if (data->File)
		{
			int  ypos = 0;
			long pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
			if (pos != NOPOS)
			{
				while ((pos != NOPOS) && (ypos < (rc.H - 1)))
				{
					data->FirstPos = pos;
					pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
					ypos++;
				}
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
		}
		break;
	case SB_THUMBTRACK:
		if (data->File)
		{
			data->FirstPos = (data->File->FileSize * pos) / 100;
			data->FirstPos = PagerviewPrevLine(data, data->FirstPos, NULL);
			PagerviewCalculate(win);
			PagerviewUpdate(win);
		}
		break;
	}
}


/* ---------------------------------------------------------------------
 * PagerviewDestroyHook
 * Handle EVENT_DELETE event
 * ---------------------------------------------------------------------
 */
static void
PagerviewDestroyHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	WindowKillTimer(win, IDC_TAILTIMER);
	PagerviewClear(win);

	free (win->InstData);
}


/* ---------------------------------------------------------------------
 * PagerviewSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
PagerviewSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;

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
 * PagerviewKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
PagerviewKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;

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
 * PagerviewKillFocusHook
 * Handle EVENT_TIMER events
 * ---------------------------------------------------------------------
 */
static void
PagerviewTimerHook(void* w, int id)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;
	wchar_t*         lbuffer;

	if ((id == IDC_TAILTIMER) && (data->File))
	{
		long size = data->File->FileSize;
		long pos  = size;

		while (pos != NOPOS)
		{
			pos = PagerviewNextLine(data, pos, &lbuffer);
		}
		if (size != data->File->FileSize)
		{
			PagerviewGotoEnd(win, TRUE);
		}		
	}
}


/* ---------------------------------------------------------------------
 * PagerviewNew
 * Create a text view dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
PagerviewNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* pagerview;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		pagerview = WindowNew(parent, x, y, w, h, flags);
		pagerview->Class = _T("PAGERVIEW");
		WindowSetId(pagerview, id);
		WindowSetNcPaintHook(pagerview, PagerviewNcPaintHook);
		WindowSetPaintHook(pagerview, PagerviewPaintHook);
		WindowSetKeyHook(pagerview, PagerviewKeyHook);
		WindowSetSetFocusHook(pagerview, PagerviewSetFocusHook);
		WindowSetKillFocusHook(pagerview, PagerviewKillFocusHook);
		WindowSetSizeHook(pagerview, PagerviewSizeHook);
		WindowSetVScrollHook(pagerview, PagerviewVScrollHook);
		WindowSetDestroyHook(pagerview, PagerviewDestroyHook);
		WindowSetTimerHook(pagerview, PagerviewTimerHook);

		pagerview->InstData = (PAGERVIEWDATA*) malloc(sizeof(PAGERVIEWDATA));
		((PAGERVIEWDATA*)pagerview->InstData)->SetFocusHook    = NULL;
		((PAGERVIEWDATA*)pagerview->InstData)->KillFocusHook   = NULL;
		((PAGERVIEWDATA*)pagerview->InstData)->PreKeyHook      = NULL;
		((PAGERVIEWDATA*)pagerview->InstData)->PostKeyHook     = NULL;
		((PAGERVIEWDATA*)pagerview->InstData)->SelPos1 = 0;
		((PAGERVIEWDATA*)pagerview->InstData)->SelPos2 = 0;
		((PAGERVIEWDATA*)pagerview->InstData)->NumLines = 9;
		((PAGERVIEWDATA*)pagerview->InstData)->MaxWidth = 0;
		((PAGERVIEWDATA*)pagerview->InstData)->DoWordWrap = FALSE;
		((PAGERVIEWDATA*)pagerview->InstData)->TailOn = FALSE;
		((PAGERVIEWDATA*)pagerview->InstData)->FirstPos = 0;
		((PAGERVIEWDATA*)pagerview->InstData)->LastPos = 0;
		((PAGERVIEWDATA*)pagerview->InstData)->File = NULL;
		((PAGERVIEWDATA*)pagerview->InstData)->Filter = NULL;

		WindowSetText(pagerview, text);

		return pagerview;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * PagerviewSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
PagerviewSetSetFocusHook(CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		((PAGERVIEWDATA*)win->InstData)->SetFocusHook = proc;
		((PAGERVIEWDATA*)win->InstData)->SetFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * PagerviewSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
PagerviewSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		((PAGERVIEWDATA*)win->InstData)->KillFocusHook = proc;
		((PAGERVIEWDATA*)win->InstData)->KillFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * PagerviewSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
PagerviewSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		((PAGERVIEWDATA*)win->InstData)->PreKeyHook = proc;
		((PAGERVIEWDATA*)win->InstData)->PreKeyTarget = target;
	}
}
 
 
/* ---------------------------------------------------------------------
 * PagerviewSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
PagerviewSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		((PAGERVIEWDATA*)win->InstData)->PostKeyHook = proc;
		((PAGERVIEWDATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * PagerviewEnableWordWrap
 * Enable or disable word wrap
 * ---------------------------------------------------------------------
 */
void
PagerviewEnableWordWrap(CUIWINDOW* win, int enable)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		if (((PAGERVIEWDATA*)win->InstData)->DoWordWrap != enable)
		{
			((PAGERVIEWDATA*)win->InstData)->DoWordWrap = enable;
			PagerviewCalculate(win);
			PagerviewUpdate(win);
		}
	}
}


/* ---------------------------------------------------------------------
 * PagerviewClear
 * Free file that is associated with this view
 * ---------------------------------------------------------------------
 */
void
PagerviewClear(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;

		if (data->File)
		{
			PagerFileClose(data->File);
		}
		data->File = NULL;
		data->FirstPos = 0;
		data->LastPos = 0;

		PagerviewCalculate(win);
		PagerviewUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * PagerviewSetFile
 * Associate the file 'filename' to the view
 * ---------------------------------------------------------------------
 */
int
PagerviewSetFile(CUIWINDOW *win, const wchar_t *filename, const wchar_t *encoding)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;
		if (data->File)
		{
			PagerFileClose(data->File);
		}
		data->File = PagerFileOpen(filename, encoding);
		data->FirstPos = 0;
		data->LastPos = 0;

		PagerviewCalculate(win);
		PagerviewUpdate(win);

		return (data->File != NULL);
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PagerviewSearch
 * Search function
 * ---------------------------------------------------------------------
 */
int
PagerviewSearch(CUIWINDOW* win, const wchar_t* text, int wholeword, int casesens, int down)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;
		long pos;

		if (!data->File)
		{
			return FALSE;
		}

		/* find starting position for text search */
		if (down)
		{
			pos = data->SelPos2;
		}
		else
		{
			pos = data->SelPos1 - 1;
		}
		if (!PagerFileSeek(data->File, pos) == 0)
		{
			return FALSE;
		}

		/* search text */
		if (pos >= ZEROPOS)
		{
			int   searchc = tolower(*text);
			int   c;

			if (down)
			{
				c = PagerFileForwGet(data->File);
				while (c != EOI)
				{
					if (tolower(c) == searchc)
					{
						if (PagerviewMatchWord(data->File, c, text, casesens))
						{
							long oldpos = PagerFilePos(data->File) - 1;
							int  lastc = EOI;
							int  firstc = EOI;

							if (PagerFileSeek(data->File, oldpos + wcslen(text)) == 0)
							{
								lastc = PagerFileGet(data->File);
							}
							if (PagerFileSeek(data->File, oldpos - 1) == 0)
							{
								firstc = PagerFileGet(data->File);
							}

							if (!wholeword || (lastc == EOI) || !PagerviewIsChar(lastc))
							{
								if (!wholeword || (firstc == EOI) || 
								    !PagerviewIsChar(firstc))
								{
									data->SelPos1 = oldpos;
									data->SelPos2 = data->SelPos1 + wcslen(text);
									PagerviewCheckSelectionPos(win);
									PagerviewUpdate(win);
									return TRUE;
								}
							}
							PagerFileSeek(data->File, oldpos + 1);
						}
					}
					c = PagerFileForwGet(data->File);
				}
			}
			else
			{
				c = PagerFileBackGet(data->File);
				while (c != EOI)
				{
					if (tolower(c) == searchc)
					{
						c = PagerFileForwGet(data->File);
						if (PagerviewMatchWord(data->File, c, text, casesens))
						{
							long oldpos = PagerFilePos(data->File) - 1;
							int  lastc = EOI;
							int  firstc = EOI;

							if (PagerFileSeek(data->File, oldpos + wcslen(text)) == 0)
							{
								lastc = PagerFileGet(data->File);
							}
							if (PagerFileSeek(data->File, oldpos - 1) == 0)
							{
								firstc = PagerFileGet(data->File);
							}

							if (!wholeword || (lastc == EOI) || !PagerviewIsChar(lastc))
							{
								if (!wholeword || (firstc == EOI) || 
								    !PagerviewIsChar(firstc))
								{
									data->SelPos1 = oldpos;
									data->SelPos2 = data->SelPos1 + wcslen(text);
									PagerviewCheckSelectionPos(win);
									PagerviewUpdate(win);
									return TRUE;
								}
							}
							PagerFileSeek(data->File, oldpos);
						}
						else
						{
							c = PagerFileBackGet(data->File);
						}
					}
					c = PagerFileBackGet(data->File);
				}
			}
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * PagerviewResetSearch
 * Reset search position
 * ---------------------------------------------------------------------
 */
void  
PagerviewResetSearch(CUIWINDOW* win, int at_bottom)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;

		if (at_bottom)
		{
			data->SelPos1 = 0;
			data->SelPos2 = 0;
		}
		else if (data->File)
		{
			data->SelPos1 = data->File->FileSize;
			data->SelPos2 = data->File->FileSize;
		}
	}
}


/* ---------------------------------------------------------------------
 * PagerviewEnableTail
 * Enable or disable tail function
 * ---------------------------------------------------------------------
 */
void 
PagerviewEnableTail(CUIWINDOW* win, int enable)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;

		if (data->TailOn)
		{
			WindowKillTimer(win, IDC_TAILTIMER);
		}
		data->TailOn = enable;
		if (data->TailOn)
		{
			PagerviewGotoEnd(win, FALSE);
			WindowSetTimer(win, IDC_TAILTIMER, 500);
		}
	}
}


/* ---------------------------------------------------------------------
 * PagerviewResolveLine
 * Resolve file position of line
 * ---------------------------------------------------------------------
 */
long 
PagerviewResolveLine(CUIWINDOW* win, int linenr)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		long  pos = 0;
		wchar_t* buf;
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;

		while ((linenr > 1) && (pos != NOPOS))
		{
			pos = PagerForwRawLine(data->File, pos, &buf);
			linenr--;
		}
		return pos;
	}
	return NOPOS;
}


/* ---------------------------------------------------------------------
 * PagerviewJumpTo
 * Jump to a given line position
 * ---------------------------------------------------------------------
 */
void 
PagerviewJumpTo(CUIWINDOW* win, long filepos)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;
		if (filepos != NOPOS)
		{
			data->FirstPos = filepos;
			PagerviewCalculate(win);
			PagerviewUpdate(win);
		}
	}
}


/* ---------------------------------------------------------------------
 * PagerviewSetFilter
 * Set view filter
 * ---------------------------------------------------------------------
 */
void  
PagerviewSetFilter(CUIWINDOW* win, const wchar_t* filter)
{
	if (win && (wcscmp(win->Class, _T("PAGERVIEW")) == 0))
	{
		wchar_t buffer[64 + 1];
		PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;

		if (data->Filter)
		{
			free(data->Filter);
			data->Filter = NULL;
		}
		if (filter && (wcslen(filter) > 0))
		{
			data->Filter = wcsdup(filter);
			swprintf(buffer, 64, _T("[VIEW-FILTER=%ls]"), filter);
			buffer[64] = 0;

			WindowSetText(win, buffer);
		}
		else
		{
			WindowSetText(win, _T(""));
		}
		PagerviewCalculate(win);
		PagerviewUpdate(win);
	}
}


/* helper functions */

/* ---------------------------------------------------------------------
 * PagerviewShowLine (display helper)
 * Print a line of text at the position 'ypos' on the screen clipped by
 * the area specified by the 'txt'-structure
 * ---------------------------------------------------------------------
 */
static void
PagerviewShowLine(CUIWINDOW* win, const wchar_t* text, int ypos, int selpos1, int selpos2, int do_print)
{
	CUIRECT       rc;
	WINDOW*       w = win->Win;
	int           index;	
	int           len, x;
	int           xscroll;

	WindowGetClientRect(win, &rc);

	xscroll = WindowGetHScrollPos(win);

	len = wcslen(text);
	if (do_print)
	{
		SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}

	if ((do_print) && (ypos < rc.H) && (ypos >= 0))
	{
		index = 0;
		x = 0;

		MOVEYX(w, ypos, 0);
		while (x < (rc.W + xscroll)) 
		{
			if (index == selpos1)
			{
				SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor, FALSE);
			}
			if (index == selpos2)
			{
				SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
			}
			if (index < len)
			{
				if (text[index]=='\t') 
				{
					x += TABWIDTH;
					MOVEYX(w, ypos, x - xscroll);
				}
				else 
				{
					if (x >= xscroll)
					{
						PRINTN(w, &text[index], 1);
					}
					x++;
				}
			}
			else 
			{
				x++;
			}		
			index++;
		}
	}
}


/* ---------------------------------------------------------------------
 * PagerviewMatchWord
 * Compare two text strings
 * ---------------------------------------------------------------------
 */
static int
PagerviewMatchWord(PAGERFILE* pfile, int c, const wchar_t* s2, int casesens)
{
	int len = wcslen(s2);
	int i;
	long oldpos = PagerFilePos(pfile);

	if (!casesens)
	{
		for (i = 0; i < len; i++)
		{
			if (towlower(c) != towlower(*s2))
			{
				PagerFileSeek(pfile, oldpos);
				return FALSE;
			}
			c = PagerFileForwGet(pfile);
			s2++;
		}
	}
	else
	{
		for (i = 0; i < len; i++)
		{
			if (c != (int) *s2)
			{
				PagerFileSeek(pfile, oldpos);
				return FALSE;
			}
			c = PagerFileForwGet(pfile);
			s2++;
		}
	}

	PagerFileSeek(pfile, oldpos);
	return TRUE;
}

/* ---------------------------------------------------------------------
 * PagerviewIsChar
 * Check if 'c' is a alphanumeric character. Include special german 
 * and frensh letters (that's why isalpha() is not used)
 * ---------------------------------------------------------------------
 */
static int
PagerviewIsChar(wchar_t c)
{
	return iswalnum(c);
}


/* ---------------------------------------------------------------------
 * PagerviewCheckSelectionPos
 * Make the selection visible within the visible area
 * ---------------------------------------------------------------------
 */
static void
PagerviewCheckSelectionPos(CUIWINDOW* win)
{
	CUIRECT rc;
	PAGERVIEWDATA* data = (PAGERVIEWDATA*) win->InstData;
	long linepos;
	int  xscroll = WindowGetHScrollPos(win);

	if (!data->File)
	{
		return;
	}

	WindowGetClientRect(win, &rc);

	linepos = PagerBackRawLine(data->File, data->SelPos1 + 1, NULL);
	if (data->SelPos1 >= data->LastPos)
	{
		long pos = linepos;
		int ypos = 0;
		while ((pos != NOPOS) && (ypos < 3 * rc.H / 4))
		{
			data->FirstPos = pos;
			pos = PagerBackRawLine(data->File, pos, NULL);
			ypos++;
		}
		PagerviewCalculate(win);
	}
	else if (data->SelPos2 <= data->FirstPos)
	{
		long pos = linepos;
		int ypos = 0;
		while ((pos != NOPOS) && (ypos < rc.H / 4))
		{
			data->FirstPos = pos;
			pos = PagerBackRawLine(data->File, pos, NULL);
			ypos++;
		}
		PagerviewCalculate(win);
	}

	if ((data->SelPos1 - linepos >= (xscroll + rc.W)) ||
	    (data->SelPos1 - linepos < xscroll))
	{
		int pos = data->SelPos1 - linepos - rc.W / 4;
		int xrange;

		PagerviewCalculate(win);

		xrange = WindowGetVScrollRange(win);
		if (pos > xrange)
		{
			pos = xrange;
		}
		else if (pos < 0)
		{
			pos = 0;
		}
		WindowSetHScrollPos(win, pos);
	}	
}


/* ---------------------------------------------------------------------
 * PagerviewLineLegth  (local helper)
 * calculates the real length of a text line translating tab-characters
 * to spaces
 * ---------------------------------------------------------------------
 */
static int 
PagerviewLineLength(const wchar_t* line)
{
	int pos = 0;
	int len = 0;

	if (line) 
	{
		while (line[pos])
		{
			if (line[pos] == _T('\t')) 
			{
				len += TABWIDTH;
			}
			else len++;
			pos++;
		}
	}
	return len;
}


/* ---------------------------------------------------------------------
 * PagerviewUpdate
 * Update text view
 * ---------------------------------------------------------------------
 */
static void 
PagerviewUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* ---------------------------------------------------------------------
 * PagerviewCalculate
 * Calculate range and scroll bars of text view
 * ---------------------------------------------------------------------
 */
static void 
PagerviewCalculate(CUIWINDOW* win)
{
	CUIRECT       rc;
	PAGERVIEWDATA* data;
	int           maxlength = 0;
	long          filesize = 0;
	int           visiblearea;
	int           invisiblearea;

	data = (PAGERVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	if (data->File)
	{
		wchar_t* lbuffer;
		int    ypos = 0;
		long   pos = PagerviewNextLine(data, data->FirstPos, &lbuffer);
		while ((pos != NOPOS) && (ypos < (rc.H - 1)))
		{
			int len = PagerviewLineLength(lbuffer); 
			if (len > maxlength)
			{
				maxlength = len;
			}
			ypos++;
			pos = PagerviewNextLine(data, pos, &lbuffer);
		}

		if (pos == NOPOS)
		{
			data->LastPos = data->File->FileSize;
		}
		else
		{
			data->LastPos = pos;
		}
		filesize = data->File->FileSize;
	}
	else
	{
		data->LastPos = 0;
	}

	visiblearea = data->LastPos - data->FirstPos;
	invisiblearea = filesize - visiblearea;

	if (invisiblearea > 0)
	{
		WindowEnableVScroll(win, TRUE);
		WindowSetVScrollRange(win, 100);
		WindowSetVScrollPos(win, (data->FirstPos * 100) / invisiblearea);
	}
	else
	{
		WindowEnableVScroll(win, FALSE);
		WindowSetVScrollRange(win, 0);
		WindowSetVScrollPos(win, 0);
	}

	if (maxlength > data->MaxWidth)
	{
		data->MaxWidth = maxlength;
	}
	if (data->MaxWidth > rc.W)
	{
		WindowSetHScrollRange(win, data->MaxWidth - rc.W);
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
 * PagerviewGotoEnd
 * Enable or disable tail function
 * ---------------------------------------------------------------------
 */
static void
PagerviewGotoEnd(CUIWINDOW* win, int force)
{
	PAGERVIEWDATA* data = (PAGERVIEWDATA*)win->InstData;
	CUIRECT rc;
	wchar_t*  lbuffer;

	WindowGetClientRect(win, &rc);
	if (data->File) 
	{
		int  ypos = 0;
		long pos = data->File->FileSize;
		if (pos != NOPOS)
		{
			while ((pos != NOPOS) && (ypos < (rc.H - 1)))
			{
				pos = PagerviewPrevLine(data, pos, &lbuffer);
				ypos++;
			}
			if (pos == NOPOS)
			{
				pos = ZEROPOS;
			}
			if ((pos != data->FirstPos) || force)
			{
				data->FirstPos = pos;
				PagerviewCalculate(win);
				PagerviewUpdate(win);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * PagerviewNextLine
 * Read to next line
 * ---------------------------------------------------------------------
 */
static long
PagerviewNextLine(PAGERVIEWDATA* data, long pos, wchar_t** lbuffer)
{
	pos = PagerForwRawLine(data->File, pos, lbuffer);
	while (pos != NOPOS)
	{
		if (!data->Filter ||
		   (wcslen(data->Filter) == 0) ||
		   (wcsstr(*lbuffer, data->Filter) != NULL))
		{
			return pos;
		}
		pos = PagerForwRawLine(data->File, pos, lbuffer);
	}
	return pos;
}

/* ---------------------------------------------------------------------
 * PagerviewPrevLine
 * Read to previous line
 * ---------------------------------------------------------------------
 */
static long
PagerviewPrevLine(PAGERVIEWDATA* data, long pos, wchar_t** lbuffer)
{
	pos = PagerBackRawLine(data->File, pos, lbuffer);
	while ((pos != NOPOS) && (pos > ZEROPOS))
	{
		if (!data->Filter ||
		   (wcslen(data->Filter) == 0) ||
		   (wcsstr(*lbuffer, data->Filter) != NULL))
		{
			return pos;
		}
		pos = PagerBackRawLine(data->File, pos, lbuffer);
	}
	return pos;
}

