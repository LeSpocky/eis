/* ---------------------------------------------------------------------
 * File: textview.c
 * (text view window)
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
#include <ctype.h>

/* local constants */
#define TABWIDTH 8

#define SIZE_MAX 64535

typedef struct TEXTLINEStruct
{
	wchar_t*  Text;
	int     NumLines;
	void*   Next;
	void*   Previous;
} TEXTLINE;

typedef struct TEXTVIEWStruct
{
	int          SelY1, SelY2;
	int          SelX1, SelX2;
	int          NumLines;
	int          MaxWidth;
	int          DoWordWrap;
	TEXTLINE*    FirstLine;
	TEXTLINE*    LastLine;

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
} TEXTVIEWDATA;


/* local prototypes */
static int    TextviewShowLine(CUIWINDOW* win, TEXTLINE* text, int ypos, 
                               int selpos1, int selpos2, int do_print);
static void   TextviewUpdate(CUIWINDOW* win);
static void   TextviewCalculate(CUIWINDOW* win);
static int    TextviewLineLength(const wchar_t* line);
static int    TextviewMatchWord(const wchar_t* s1, const wchar_t* s2, int casesens);
static int    TextviewIsChar(wchar_t c);
static void   TextviewCheckSelectionPos(CUIWINDOW* win);

static char*  wchar_t_dup_to_mbchar(const wchar_t* str);
static wchar_t* mbchar_dup_to_wchar_t(const char* str);
static int    mbchar_char_len(const char* p);
static int    mbchar_byte_len(const wchar_t* p);

/* ---------------------------------------------------------------------
 * TextviewNcPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
TextviewNcPaintHook(void* w, int size_x, int size_y)
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
	if (!win->Text || (win->Text[0] == 0)) return;

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
 * TextviewPaintHook
 * Handle PAINT events by redrawing the text view control
 * ---------------------------------------------------------------------
 */
static void
TextviewPaintHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	TEXTVIEWDATA* data;
        TEXTLINE*     line;
	int           yscroll;
	int           ypos;
	int           index;

	data = (TEXTVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	yscroll = WindowGetVScrollPos(win);

	/* show text */
	ypos = 0;
	index = 0;
	line = data->FirstLine;
	while (line)
	{
		if ((ypos + line->NumLines > yscroll)&&
		    (ypos < yscroll + rc.H))
		{
			if ((index < data->SelY1) || (index > data->SelY2))
			{
				ypos += TextviewShowLine(win, line, ypos - yscroll, 0, 0, TRUE);
			}
			else if ((index == data->SelY1) && (index == data->SelY2))
			{
				ypos += TextviewShowLine(win, line, ypos - yscroll, data->SelX1, data->SelX2, TRUE);
			}
			else if (index == data->SelY1)
			{
				ypos += TextviewShowLine(win, line, ypos - yscroll, data->SelX1, wcslen(line->Text), TRUE);
			}
			else if (index == data->SelY2)
			{
				ypos += TextviewShowLine(win, line, ypos - yscroll, 0, data->SelX2, TRUE);
			}
		}
		else
		{
			ypos += line->NumLines;
			if (ypos >= yscroll + rc.H)
			{
				break;
			}
		}
		index++;
		line = (TEXTLINE*) line->Next;
	}
	WindowSetCursor(win, 0, 0);
}


/* ---------------------------------------------------------------------
 * TextviewSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int
TextviewSizeHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	TextviewCalculate(win);
	return TRUE;
}


/* ---------------------------------------------------------------------
 * TextviewKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
TextviewKeyHook(void* w, int key)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	TEXTVIEWDATA* data = (TEXTVIEWDATA*) win->InstData;
	CUIRECT       rc;
	int           yscroll;
	int           xscroll;
	int           yrange;
	int           xrange;

	if (!data) return FALSE;

	xscroll = WindowGetHScrollPos(win);
	yscroll = WindowGetVScrollPos(win);
	xrange  = WindowGetHScrollRange(win);
	yrange  = WindowGetVScrollRange(win);

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
			if (yscroll < yrange)
			{
				WindowSetVScrollPos(win, yscroll + 1);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_UP:
			if (yscroll > 0)
			{
				WindowSetVScrollPos(win, yscroll - 1);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_NPAGE:
			if (yscroll < yrange)
			{
				yscroll += (rc.H - 1);
				if (yscroll >= yrange)
				{
					yscroll = yrange;
				}
				WindowSetVScrollPos(win, yscroll);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_PPAGE:
			if (yscroll > 0)
			{
				yscroll -= (rc.H - 1);
				if (yscroll < 0)
				{
					yscroll = 0;
				}
				WindowSetVScrollPos(win, yscroll);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_HOME:
			if (yscroll > 0)
			{
				WindowSetVScrollPos(win, 0);
				WindowInvalidate(win);
			}
			return TRUE;
		case KEY_END:
			if (yscroll < yrange)
			{
				WindowSetVScrollPos(win, yrange);
				WindowInvalidate(win);
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
 * TextviewVScrollHook
 * Textview scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
TextviewVScrollHook(void* w, int sbcode, int pos)
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
			sbpos -= (rc.H - 1);
			sbpos = (sbpos < 0) ? 0 : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.H - 1);
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
 * TextviewDestroyHook
 * Handle EVENT_DELETE event
 * ---------------------------------------------------------------------
 */
static void
TextviewDestroyHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	TextviewClear(win);

	free (win->InstData);
}


/* ---------------------------------------------------------------------
 * TextviewSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
TextviewSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	TEXTVIEWDATA* data = (TEXTVIEWDATA*) win->InstData;

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
 * TextviewKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
TextviewKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	TEXTVIEWDATA* data = (TEXTVIEWDATA*) win->InstData;

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
 * TextviewLayoutHook
 * Handle EVENT_UPDATELAYOUT Events
 * ---------------------------------------------------------------------
 */
static void
TextviewLayoutHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	
	TextviewCalculate(win);
	TextviewUpdate(win);
}


/* ---------------------------------------------------------------------
 * TextviewNew
 * Create a text view dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
TextviewNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* textview;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		textview = WindowNew(parent, x, y, w, h, flags);
		textview->Class = _T("TEXTVIEW");
		WindowSetId(textview, id);
		WindowSetNcPaintHook(textview, TextviewNcPaintHook);
		WindowSetPaintHook(textview, TextviewPaintHook);
		WindowSetKeyHook(textview, TextviewKeyHook);
		WindowSetSetFocusHook(textview, TextviewSetFocusHook);
		WindowSetKillFocusHook(textview, TextviewKillFocusHook);
		WindowSetSizeHook(textview, TextviewSizeHook);
		WindowSetVScrollHook(textview, TextviewVScrollHook);
		WindowSetDestroyHook(textview, TextviewDestroyHook);
		WindowSetLayoutHook(textview, TextviewLayoutHook);

		textview->InstData = (TEXTVIEWDATA*) malloc(sizeof(TEXTVIEWDATA));
		((TEXTVIEWDATA*)textview->InstData)->SetFocusHook    = NULL;
		((TEXTVIEWDATA*)textview->InstData)->KillFocusHook   = NULL;
		((TEXTVIEWDATA*)textview->InstData)->PreKeyHook      = NULL;
		((TEXTVIEWDATA*)textview->InstData)->PostKeyHook     = NULL;
		((TEXTVIEWDATA*)textview->InstData)->SelY1 = 0;
		((TEXTVIEWDATA*)textview->InstData)->SelY2 = 0;
		((TEXTVIEWDATA*)textview->InstData)->SelX1 = 0;
		((TEXTVIEWDATA*)textview->InstData)->SelX2 = 0;
		((TEXTVIEWDATA*)textview->InstData)->NumLines = 9;
		((TEXTVIEWDATA*)textview->InstData)->MaxWidth = 0;
		((TEXTVIEWDATA*)textview->InstData)->DoWordWrap = FALSE;
		((TEXTVIEWDATA*)textview->InstData)->FirstLine = NULL;
		((TEXTVIEWDATA*)textview->InstData)->LastLine = NULL;

		WindowSetText(textview, text);

		return textview;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * TextviewSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TextviewSetSetFocusHook(CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
        if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
        {
                ((TEXTVIEWDATA*)win->InstData)->SetFocusHook = proc;
                ((TEXTVIEWDATA*)win->InstData)->SetFocusTarget = target;
        }
}


/* ---------------------------------------------------------------------
 * TextviewSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TextviewSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
        if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
        {
                ((TEXTVIEWDATA*)win->InstData)->KillFocusHook = proc;
                ((TEXTVIEWDATA*)win->InstData)->KillFocusTarget = target;
        }
}


/* ---------------------------------------------------------------------
 * TextviewSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TextviewSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		((TEXTVIEWDATA*)win->InstData)->PreKeyHook = proc;
		((TEXTVIEWDATA*)win->InstData)->PreKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * TextviewSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TextviewSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		((TEXTVIEWDATA*)win->InstData)->PostKeyHook = proc;
		((TEXTVIEWDATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * TextviewEnableWordWrap
 * Enable or disable word wrap
 * ---------------------------------------------------------------------
 */
void
TextviewEnableWordWrap(CUIWINDOW* win, int enable)
{
        if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
        {
		if (((TEXTVIEWDATA*)win->InstData)->DoWordWrap != enable)
		{
	                ((TEXTVIEWDATA*)win->InstData)->DoWordWrap = enable;
			TextviewCalculate(win);
			TextviewUpdate(win);
		}
        }
}


/* ---------------------------------------------------------------------
 * TextviewAdd
 * Add a line of text to the text window
 * ---------------------------------------------------------------------
 */
void
TextviewAdd(CUIWINDOW* win, const wchar_t* text)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		TEXTVIEWDATA* data = (TEXTVIEWDATA*)win->InstData;
		TEXTLINE* line;
		int len = TextviewLineLength(text);

		line = (TEXTLINE*) malloc(sizeof(TEXTLINE));
		line->Text = wcsdup(text);
		line->Next = NULL;

		if (data->FirstLine)
		{
			data->LastLine->Next = line;
			line->Previous = data->LastLine;
		}
		else
		{
			data->FirstLine = line;
			line->Previous = NULL;
		}
		data->LastLine = line;

		if (data->MaxWidth < len) data->MaxWidth = len;
		
		WindowInvalidateLayout(win);
	}
}


/* ---------------------------------------------------------------------
 * TextviewClear
 * Delete all text lines stored within the 'txt'-structure
 * ---------------------------------------------------------------------
 */
void
TextviewClear(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		TEXTVIEWDATA* data = (TEXTVIEWDATA*)win->InstData;
		TEXTLINE* line;

		line = data->FirstLine;
		while(line)
		{
			data->FirstLine = (TEXTLINE*) line->Next;
			free(line->Text);
			free(line);
			line = data->FirstLine;
		}
		data->LastLine = NULL;
		TextviewCalculate(win);
		TextviewUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * TextviewRead
 * Read the file specified by 'filename' and transfer the text data
 * into the 'txt' structure
 * ---------------------------------------------------------------------
 */
int
TextviewRead(CUIWINDOW* win, const wchar_t* filename)
{
	int result = FALSE;

	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		TEXTVIEWDATA* data = (TEXTVIEWDATA*)win->InstData;
		TEXTLINE* line;

		char* mbfile = wchar_t_dup_to_mbchar(filename);
		if (mbfile)
		{
			FILE* in = fopen(mbfile, "rt");
			if (in)
			{
				char buffer[256+1];
				while (fgets(buffer,256,in))
				{
					int len;

					line = (TEXTLINE*) malloc(sizeof(TEXTLINE));
					line->Text = mbchar_dup_to_wchar_t(buffer);
					line->Next = NULL;

					len = wcslen(line->Text);
					if (len > 0)
					{
						if (line->Text[len-1] == _T('\n')) line->Text[len-1] = 0;
					}

					if (data->FirstLine)
					{
						data->LastLine->Next = line;
						line->Previous = data->LastLine;
					}
					else
					{
						data->FirstLine = line;
						line->Previous = NULL;
					}
					data->LastLine = line;

					len = TextviewLineLength(line->Text);
					if (data->MaxWidth < len) data->MaxWidth = len;
				}
				fclose(in);

				TextviewCalculate(win);
				TextviewUpdate(win);
				result = TRUE;
			}
			free(mbfile);
		}
	}
	return result;
}


/* ---------------------------------------------------------------------
 * TextviewSearch
 * Search function
 * ---------------------------------------------------------------------
 */
int
TextviewSearch(CUIWINDOW* win, const wchar_t* text, int wholeword, int casesens, int down)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		TEXTVIEWDATA* data = (TEXTVIEWDATA*)win->InstData;
		TEXTLINE* line;
		int index = 0;
		int pos;
		int x;
		int y;

		if (down)
		{
			y = data->SelY2;
			x = data->SelX2;
		}
		else
		{
			y = data->SelY1;
			x = data->SelX1 - 1;
		}

		/* find starting position for text search */
		line = data->FirstLine;
		while (line && (index < y))
		{
			line = (TEXTLINE*)line->Next;
			index++;
		}
		if (!line) return FALSE;

		pos = x;
		if (pos >= (int)wcslen(line->Text))
		{
			pos = wcslen(line->Text) - 1;
		}

		/* search text */
		while (line)
		{
			if (pos >= 0)
			{
				wchar_t  searchc = tolower(*text);
				wchar_t* c = &line->Text[pos];
				int   len = wcslen(line->Text);

				if (down)
				{
					while (pos < len)
					{
						if (tolower(*c) == searchc)
						{
							if (TextviewMatchWord(c,text,casesens))
							{
								wchar_t lastc = c[wcslen(text)];
								if (!(wholeword && (pos > 0) && 
								     (TextviewIsChar(line->Text[pos - 1]))))
								{
									if (!(wholeword && TextviewIsChar(lastc)))
									{
										data->SelY1 = index;
										data->SelY2 = index;
										data->SelX1 = pos;
										data->SelX2 = pos + wcslen(text);
										TextviewCheckSelectionPos(win);
										TextviewUpdate(win);
										return TRUE;
									}
								}
							}
						}
						c++;
						pos++;
					}
				}
				else
				{
					while (pos >= 0)
					{
						if (tolower(*c) == searchc)
						{
							if (TextviewMatchWord(c,text,casesens))
							{
								wchar_t lastc = c[wcslen(text)];
								if (!(wholeword && (pos > 0) && (TextviewIsChar(line->Text[pos - 1]))))
								{
									if (!(wholeword && TextviewIsChar(lastc)))
									{
										data->SelY1 = index;
										data->SelY2 = index;
										data->SelX1 = pos;
										data->SelX2 = pos + wcslen(text);
										TextviewCheckSelectionPos(win);
										TextviewUpdate(win);
										return TRUE;
									}
								}
							}
						}
						c--;
						pos--;
					}
				}
			}

			if (down)
			{
				line = line->Next;
				pos = 0;
				index++;
			}
			else
			{
				line = line->Previous;
				if (line)
				{
					pos = wcslen(line->Text) - 1;
				}
				index--;
			}
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * TextviewResetSearch
 * Reset search position to beginning or end of file
 * ---------------------------------------------------------------------
 */
int
TextviewResetSearch(CUIWINDOW* win, int at_bottom)
{
	if (win && (wcscmp(win->Class, _T("TEXTVIEW")) == 0))
	{
		TEXTVIEWDATA* data = (TEXTVIEWDATA*)win->InstData;

		if (at_bottom)
		{
			data->SelX1 = 0;
			data->SelX2 = 0;
			data->SelY1 = 0;
			data->SelY2 = 0;
		}
		else if (data->LastLine)
		{
			data->SelX1 = wcslen(data->LastLine->Text);
			data->SelX2 = wcslen(data->LastLine->Text);
			data->SelY1 = data->NumLines - 1;
			data->SelY2 = data->NumLines - 1;
		}
		return TRUE;
	}
	return FALSE;
}


/* helper functions */

/* ---------------------------------------------------------------------
 * TextviewShowLine (display helper)
 * Print a line of text at the position 'ypos' on the screen clipped by
 * the area specified by the 'txt'-structure
 * ---------------------------------------------------------------------
 */
static int
TextviewShowLine(CUIWINDOW* win, TEXTLINE* text, int ypos, int selpos1, int selpos2, int do_print)
{
	CUIRECT       rc;
	WINDOW*       w = win->Win;
	TEXTVIEWDATA* data = (TEXTVIEWDATA*) win->InstData;
	int           index;
	int           len, x;
	int           num_lines = 0;
	int           xscroll;

	WindowGetClientRect(win, &rc);

	xscroll = WindowGetHScrollPos(win);

	len = wcslen(text->Text);
	if (do_print)
	{
		SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}

	if (!data->DoWordWrap)
	{
		if ((do_print) && (ypos < rc.H) && (ypos >= 0))
		{
			index = 0;
			x = 0;
			while (x < (rc.W + xscroll))
			{
				if (do_print)
				{
					if (index == selpos1)
					{
						SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor, FALSE);
					}
					if (index == selpos2)
					{
						SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
					}
				}
				if (index < len)
				{
					if (text->Text[index]==_T('\t'))
					{
						x += TABWIDTH;
					}
					else
					{
						if (x >= xscroll)
						{
							MOVEYX(w, ypos, x - xscroll); PRINTN(w, &text->Text[index], 1);
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
		num_lines = 1;
	}
	else
	{
		wchar_t* start = &text->Text[0];
		wchar_t* end = &text->Text[0];
		wchar_t* next;

		while (*start != 0)
		{
			next = wcschr(start,_T(' '));
			if (!next) next = &text->Text[wcslen(text->Text)];

			while ((next - start <= (rc.W - 2)))
			{
				end = next;

				if (*next != 0)
				{
					next = wcschr(next + 1,_T(' '));
					if (!next) next = &text->Text[wcslen(text->Text)];
				}
				else break;
			}

			if ((next - start > rc.W)&&(end == start))
			{
				end += rc.W;
			}

			if ((do_print)&&(ypos + num_lines < rc.H)&&(ypos + num_lines >= 0))
			{
				MOVEYX(win->Win, ypos + num_lines, 1); 
				for (x = 0; x < (rc.W - 2); x++)
				{
					if ((start < end)&&(*start != _T('\t')))
					{
						PRINTN(win->Win, start, 1);
					}
					else
					{
						PRINT(win->Win, _T(" "));
					}
					start++;
				}
			}
			start = end;

			while (*start == _T(' ')) start++;
			end = start;

			num_lines ++;
		}
		if (num_lines == 0) num_lines = 1;
	}
	return num_lines;
}


/* ---------------------------------------------------------------------
 * TextMatchWord
 * Compare two text strings
 * ---------------------------------------------------------------------
 */
static int
TextviewMatchWord(const wchar_t* s1, const wchar_t* s2, int casesens)
{
	int len = wcslen(s2);
	int i;

	if (!casesens)
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
 * TextviewIsChar
 * Check if 'c' is a alphanumeric character. Include special german
 * and frensh letters (that's why isalpha() is not used)
 * ---------------------------------------------------------------------
 */
static int
TextviewIsChar(wchar_t c)
{
	return iswalnum(c);
}


/* ---------------------------------------------------------------------
 * TextviewCheckSelectionPos
 * Make the selection visible within the visible area
 * ---------------------------------------------------------------------
 */
static void
TextviewCheckSelectionPos(CUIWINDOW* win)
{
	CUIRECT rc;
	TEXTVIEWDATA* data = (TEXTVIEWDATA*) win->InstData;
	int yscroll = WindowGetVScrollPos(win);
	int xscroll = WindowGetVScrollPos(win);
	int yrange = WindowGetVScrollRange(win);
	int xrange = WindowGetVScrollRange(win);

	WindowGetClientRect(win, &rc);

	if (data->SelY1 >= (yscroll + rc.H))
	{
		int pos = data->SelY1 - rc.H / 4;
		if (pos > yrange)
		{
			pos = yrange;
		}
		else if (pos < 0)
		{
			pos = 0;
		}
		WindowSetVScrollPos(win, pos);
	}
	if (data->SelY1 < yscroll)
	{
		int pos = data->SelY1 - rc.H / 4;
		if (pos > yrange)
		{
			pos = yrange;
		}
		else if (pos < 0)
		{
			pos = 0;
		}
		WindowSetVScrollPos(win, pos);
	}

	if (data->SelX1 >= (xscroll + rc.W))
	{
		int pos = data->SelX1 - rc.W / 4;
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
	if (data->SelX1 < xscroll)
	{
		int pos = data->SelX1 - rc.W / 4;
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
 * TextviewLineLegth  (local helper)
 * calculates the real length of a text line translating tab-characters
 * to spaces
 * ---------------------------------------------------------------------
 */
static int
TextviewLineLength(const wchar_t* line)
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
 * TextviewUpdate
 * Update text view
 * ---------------------------------------------------------------------
 */
static void
TextviewUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* ---------------------------------------------------------------------
 * TextviewCalculate
 * Calculate range and scroll bars of text view
 * ---------------------------------------------------------------------
 */
static void
TextviewCalculate(CUIWINDOW* win)
{
	CUIRECT       rc;
	TEXTVIEWDATA* data;
        TEXTLINE*     line;
	int           yscroll;
	int           ypos;
	int           totallines = 0;

	data = (TEXTVIEWDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	/* calculate num lines */
	ypos = 0;
	line = data->FirstLine;
	while (line)
	{
		line->NumLines = TextviewShowLine(win, line, ypos, 0, 0, FALSE);
		totallines += line->NumLines;
		line = (TEXTLINE*) line->Next;
	}
	data->NumLines = totallines;

	/* set vertical scrollbar range */
	if (data->NumLines > rc.H)
	{
		WindowSetVScrollRange(win, data->NumLines - rc.H);
		WindowEnableVScroll(win, TRUE);

		yscroll = WindowGetVScrollPos(win);
		if ((yscroll + (data->NumLines - rc.H)) > data->NumLines)
		{
			WindowSetVScrollPos(win, data->NumLines - (data->NumLines - rc.H));
		}
	}
	else
	{
		WindowEnableVScroll(win, FALSE);
		WindowSetVScrollRange(win, 0);
		WindowSetVScrollPos(win, 0);
	}

	if (!data->DoWordWrap && (data->MaxWidth > rc.W))
	{
		WindowSetHScrollRange(win, data->MaxWidth - rc.W);
		WindowEnableHScroll(win, TRUE);
	}
	else
	{
		WindowEnableHScroll(win, FALSE);
		WindowSetHScrollRange(win, 0);
		WindowSetVScrollPos(win, 0);
	}
}


/* ---------------------------------------------------------------------
 * Char conversion and help functions
 * These are declared static to be independant from libcui-util wich
 * exports them as public functions
 * ---------------------------------------------------------------------
 */
static char* 
wchar_t_dup_to_mbchar(const wchar_t* str)
{
	int   len = mbchar_byte_len(str);
	char* mbstr = (char*) malloc((len + 1) * sizeof(wchar_t));
	if (mbstr)
	{
		wcsrtombs(mbstr, &str, len + 1, NULL);	
		return mbstr;
	}
	return NULL;
}

static wchar_t* 
mbchar_dup_to_wchar_t(const char* str)
{
	int    len = mbchar_char_len(str);
	wchar_t* tstr = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
	if (tstr)
	{
		mbsrtowcs(tstr, &str, len + 1, NULL);
		return tstr;
	}
	return NULL;
}

static int
mbchar_char_len(const char* s)
{
	return mbsrtowcs(NULL, &s, SIZE_MAX, NULL);
}

static int
mbchar_byte_len(const wchar_t* s)
{
	return wcsrtombs(NULL, &s, SIZE_MAX, NULL);
}

