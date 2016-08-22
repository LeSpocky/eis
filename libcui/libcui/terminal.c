/* ---------------------------------------------------------------------
 * File: terminal.h
 * (ANSI terminal window)
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

#ifndef BYTE
#define BYTE unsigned char
#endif

#define MAX_CHARACTERS  512
#define MAX_TIMEOUT     60
#define DEFAULT_SHELL   "/bin/sh"

#define STATE_NORMAL    0
#define STATE_INTRO     1
#define STATE_SEQUENCE  2

#define MAX_TERMCOLS    128
#define MAX_TERMLINES   40
#define MAX_SEQUENCE    64

#define REFRESH_TIMER   10
#define REFRESH_CYCLE   100

#define PIPE_STDOUT     0
#define PIPE_STDERR     1

#define BUFSIZE         128

#define BUFFER_SIZE_MAX 64535


typedef struct
{
	char*    Command;
	char*    ReadBuf;
	int      ReadPos;
	int      ReadSize;
	int      Terminated;
	int      FdStdin;              /* stdin, stdout, stderr */
	int      FdStdout;
	int      FdStderr;
	int      StdoutOpen;
	int      StderrOpen;
	int      Pid;                  /* PID of child process */
} COPROC;


typedef struct TERMINALStruct
{
	wchar_t*     Lines[MAX_TERMLINES];         /* Text line buffers */
	BYTE*        Colors[MAX_TERMLINES];        /* Color line buffers */

	int          CurAttr;                      /* Current color attribute */

	int          FirstLine;                    /* Index of first terminal line */
	int          YCursor;                      /* Index of current input line */
	int          XCursor;                      /* Column index within input line */
	int          HasFocus;                     /* Do we own the input focus */

	int          InputState;                   /* State of input interpreter */
	int          InputPos;                     /* Sequence read pos */
	wchar_t      EscSeq[MAX_SEQUENCE + 1];     /* Buffer for ANSI control sequences */

	COPROC*      CoProc;                       /* Running co process */

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CustomHook1IntProc      CoProcExitHook;    /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*              CoProcExitTarget;  /* Custom callback target */
} TERMINALDATA;


/* local prototypes */
static void    TerminalShowLine   (CUIWINDOW* win, int ypos, int line, CUIRECT* rc);
static void    TerminalProcessEscSequence(CUIWINDOW* win, CUIRECT* rc);
static void    TerminalUpdate     (CUIWINDOW* win);
static void    TerminalCalcPos    (CUIWINDOW* win);
static void    TerminalNextLine   (CUIWINDOW* win);
static void    TerminalPrevLine   (CUIWINDOW* win);
static void    TerminalCursorOnOff(CUIWINDOW* win);
static COPROC* TerminalCoCreate   (const wchar_t* cmd);
static void    TerminalCoDelete   (COPROC* coproc);
static int     TerminalCoIsRunning(COPROC* coproc, int *exitcode);
static void    TerminalCoExecute  (int* pipe1, int* pipe2, int* pipe3, 
                                   const char* filename, char* const parameters[]);
static int     TerminalCoWrite    (COPROC* coproc, const wchar_t *buf, int count);
static int     TerminalCoRead     (COPROC* coproc, wchar_t *buf, int count);
static void    sig_handler        (int signr);

static char*   wchar_t_dup_to_mbchar(const wchar_t* str);
static int     mbchar_byte_len(const wchar_t* p);


/* ---------------------------------------------------------------------
 * TerminalNcPaintHook
 * Handle PAINT events by redrawing the terminal window
 * ---------------------------------------------------------------------
 */
static void
TerminalNcPaintHook(void* w, int size_x, int size_y)
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
	}
	else
	{
		/* scroll bars */
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
 * TerminalPaintHook
 * Handle PAINT events by redrawing the list view control
 * ---------------------------------------------------------------------
 */
static void
TerminalPaintHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	TERMINALDATA* data;
	int           yscroll;
	int           ypos;
	int           line;

	data = (TERMINALDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	yscroll = WindowGetVScrollPos(win);

	ypos = 0;

	line = (data->FirstLine + yscroll) % MAX_TERMLINES;
	while (line != data->YCursor)
	{
		if (ypos < rc.H)
		{
			TerminalShowLine(win, ypos, line, &rc);
			ypos++;
		}
		line = (line + 1) % MAX_TERMLINES;
	}
	if (ypos < rc.H)
	{
		TerminalShowLine(win, ypos, line, &rc);
		ypos++;
	}

	ypos = ((data->YCursor - data->FirstLine + MAX_TERMLINES) % MAX_TERMLINES) - 
		yscroll;

	WindowSetCursor(win, data->XCursor, ypos);
}


/* ---------------------------------------------------------------------
 * TerminalSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int 
TerminalSizeHook(void* w)
{
	TerminalCalcPos((CUIWINDOW*) w);
	return TRUE;
}


/* ---------------------------------------------------------------------
 * TerminalKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
TerminalKeyHook(void* w, int key)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;
	CUIRECT       rc;
	int           yrange;
	int           yscroll;

	if (!data) return FALSE;

	WindowGetClientRect(win, &rc);

	yscroll = WindowGetVScrollPos(win);
	yrange  = WindowGetVScrollRange(win);

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
				TerminalCursorOnOff(win);
			}
			return TRUE;
		case KEY_UP:
			if (yscroll > 0)
			{
				WindowSetVScrollPos(win, yscroll - 1);
				WindowInvalidate(win);
				TerminalCursorOnOff(win);
			}
			return TRUE;
		case KEY_NPAGE:
			if (yscroll < yrange)
			{
				yscroll += (rc.H - 1);
				if (yscroll > yrange)
				{
					yscroll = yrange;
				}
				WindowSetVScrollPos(win, yscroll);
				WindowInvalidate(win);
				TerminalCursorOnOff(win);
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
				TerminalCursorOnOff(win);
			}
			return TRUE;
		case KEY_HOME:
			if (yscroll > 0)
			{
				WindowSetVScrollPos(win, 0);
				WindowInvalidate(win);
				TerminalCursorOnOff(win);
			}
			return TRUE;
		case KEY_END:
			if (yscroll < yrange)
			{
				WindowSetVScrollPos(win, yrange);
				WindowInvalidate(win);
				TerminalCursorOnOff(win);
			}
			return TRUE;
		default:
			if (data->CoProc)
			{
				if ((key >= KEY_SPACE) && (key <= 255))
				{
					wchar_t c = (wchar_t) key;
					TerminalCoWrite(data->CoProc, &c, 1);
					return TRUE;
				}
				else if (key == KEY_RETURN)
				{
					TerminalCoWrite(data->CoProc, _T("\n"), 1);
					return TRUE;
				}
			}
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
 * TerminalVScrollHook
 * Terminal scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
TerminalVScrollHook(void* w, int sbcode, int pos)
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
 * TerminalDestroyHook
 * Handle EVENT_DELETE event
 * ---------------------------------------------------------------------
 */
static void
TerminalDestroyHook(void* w)
{
	int i;
	CUIWINDOW*    win = (CUIWINDOW*) w;
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	for(i = 0; i < MAX_TERMLINES; i++)
	{
		free(data->Lines[i]);
		free(data->Colors[i]);
	}

        free (win->InstData);
}


/* ---------------------------------------------------------------------
 * TerminalSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
TerminalSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	if (data)
	{
		data->HasFocus = TRUE;
		TerminalCursorOnOff(win);

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}


/* ---------------------------------------------------------------------
 * TerminalKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
TerminalKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	if (data)
	{
		data->HasFocus = FALSE;
		TerminalCursorOnOff(win);

		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}


/* ---------------------------------------------------------------------
 * TerminalTimerHook
 * Handle EVENT_TIMER events
 * ---------------------------------------------------------------------
 */
static void
TerminalTimerHook(void* w, int id)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	WindowKillTimer(win, id);

	if (data && data->CoProc)
	{
		int exitcode;
		wchar_t buffer[256 + 1];

		int c = TerminalCoRead(data->CoProc, buffer, 255);
		while (c > 0)
		{
			TerminalWrite(win, buffer, c);

			c = TerminalCoRead(data->CoProc, buffer, 255);
		}

		if (TerminalCoIsRunning(data->CoProc, &exitcode))
		{
			WindowSetTimer(win, id, REFRESH_CYCLE);
		}
		else
		{
			TerminalCoDelete(data->CoProc);
			data->CoProc = NULL;

			if (data->CoProcExitHook)
			{
				data->CoProcExitHook(data->CoProcExitTarget, win, exitcode);
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * TerminalLayoutHook
 * Handle EVENT_UPDATELAYOUT Events
 * ---------------------------------------------------------------------
 */
static void
TerminalLayoutHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	
	TerminalUpdate(win);
	TerminalCursorOnOff(win);
}


/* ---------------------------------------------------------------------
 * TerminalNew
 * Create a terminal window
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
TerminalNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* terminal;
		int i;
		int col;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		terminal = WindowNew(parent, x, y, w, h, flags);
		terminal->Class = _T("TERMINAL");
		WindowSetId           (terminal, id);
		WindowColScheme       (terminal, _T("TERMINAL"));
		WindowSetNcPaintHook  (terminal, TerminalNcPaintHook);
		WindowSetPaintHook    (terminal, TerminalPaintHook);
		WindowSetKeyHook      (terminal, TerminalKeyHook);
		WindowSetSetFocusHook (terminal, TerminalSetFocusHook);
		WindowSetKillFocusHook(terminal, TerminalKillFocusHook);
		WindowSetSizeHook     (terminal, TerminalSizeHook);
		WindowSetTimerHook    (terminal, TerminalTimerHook);
		WindowSetVScrollHook  (terminal, TerminalVScrollHook);
		WindowSetDestroyHook  (terminal, TerminalDestroyHook);
		WindowSetLayoutHook   (terminal, TerminalLayoutHook);
		col = (terminal->Color.WndTxtColor << 4) + terminal->Color.WndColor;

		terminal->InstData = (TERMINALDATA*) malloc(sizeof(TERMINALDATA));
		((TERMINALDATA*)terminal->InstData)->SetFocusHook    = NULL;
		((TERMINALDATA*)terminal->InstData)->KillFocusHook   = NULL;
                ((TERMINALDATA*)terminal->InstData)->PreKeyHook      = NULL;   
                ((TERMINALDATA*)terminal->InstData)->PostKeyHook     = NULL;  
		((TERMINALDATA*)terminal->InstData)->CoProcExitHook  = NULL;
		((TERMINALDATA*)terminal->InstData)->FirstLine       = 0;
		((TERMINALDATA*)terminal->InstData)->YCursor         = 0;
		((TERMINALDATA*)terminal->InstData)->XCursor         = 0;
		((TERMINALDATA*)terminal->InstData)->InputState      = STATE_NORMAL;
		((TERMINALDATA*)terminal->InstData)->InputPos        = 0;
		((TERMINALDATA*)terminal->InstData)->CurAttr         = col;
		((TERMINALDATA*)terminal->InstData)->HasFocus        = FALSE;
		((TERMINALDATA*)terminal->InstData)->CoProc          = NULL;

		for(i = 0; i < MAX_TERMLINES; i++)
		{
			((TERMINALDATA*)terminal->InstData)->Lines[i] = 
				(wchar_t*) malloc((MAX_TERMCOLS + 1) * sizeof(wchar_t));
			((TERMINALDATA*)terminal->InstData)->Colors[i] = 
				(BYTE*) malloc((MAX_TERMCOLS + 1) * sizeof(BYTE));

			wmemset(((TERMINALDATA*)terminal->InstData)->Lines[i],_T(' '),MAX_TERMCOLS);
			memset(((TERMINALDATA*)terminal->InstData)->Colors[i], col, MAX_TERMCOLS);
		}

		WindowSetText(terminal, text);

		return terminal;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * TerminalSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TerminalSetSetFocusHook(CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		((TERMINALDATA*)win->InstData)->SetFocusHook = proc;
		((TERMINALDATA*)win->InstData)->SetFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * TerminalSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TerminalSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		((TERMINALDATA*)win->InstData)->KillFocusHook = proc;
		((TERMINALDATA*)win->InstData)->KillFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ListviewSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
TerminalSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		((TERMINALDATA*)win->InstData)->PreKeyHook = proc;
		((TERMINALDATA*)win->InstData)->PreKeyTarget = target;
	}
}
 
 
/* ---------------------------------------------------------------------
 * ListviewSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
TerminalSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		((TERMINALDATA*)win->InstData)->PostKeyHook = proc;
		((TERMINALDATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * TerminalSetCoProcExitHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
TerminalSetCoProcExitHook(CUIWINDOW* win, CustomHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		((TERMINALDATA*)win->InstData)->CoProcExitHook = proc;
		((TERMINALDATA*)win->InstData)->CoProcExitTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * TerminalWrite
 * Write text into the terminal
 * ---------------------------------------------------------------------
 */
void
TerminalWrite(CUIWINDOW* win, const wchar_t* text, int numchar)
{
	int i;
	int width;

	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		TERMINALDATA* data = (TERMINALDATA*) win->InstData;
		CUIRECT rc;

		WindowGetClientRect(win, &rc);

		width = rc.W % MAX_TERMCOLS;

		width = rc.W;
		if (width > MAX_TERMCOLS)
		{
			width = MAX_TERMCOLS;
		}
	
		for(i = 0; i < numchar; i++)
		{
			if (data->InputState == STATE_NORMAL)
			{
				if (text[i] == 27)
				{
					data->InputState = STATE_INTRO;
				}
				else
				{
					switch(text[i])
					{
					case _T('\n'):
						TerminalNextLine(win);
						data->XCursor = 0;
						break;
					case _T('\r'):
						data->XCursor = 0;
						break;
					default:
						data->Lines[data->YCursor][data->XCursor] = text[i];
						data->Colors[data->YCursor][data->XCursor] = data->CurAttr;
						if (++data->XCursor >= width)
						{
							TerminalNextLine(win);
							data->XCursor = 0;
						}
					}
				}
			}
			else if (data->InputState == STATE_INTRO)
			{
				if (text[i] == _T('['))
				{
					data->InputState = STATE_SEQUENCE;
					data->InputPos = 0;
				}
				else
				{
					data->InputState = STATE_NORMAL;
					data->Lines[data->YCursor][data->XCursor] = 27;
					data->Colors[data->YCursor][data->XCursor] = data->CurAttr;
					if (++data->XCursor >= width)
					{
						TerminalNextLine(win);
						data->XCursor = 0;
					}
					data->Lines[data->YCursor][data->XCursor] = text[i];
					data->Colors[data->YCursor][data->XCursor] = data->CurAttr;
					if (++data->XCursor >= width)
					{
						TerminalNextLine(win);
						data->XCursor = 0;
					}
				}
			}
			else
			{
				if (data->InputPos < MAX_SEQUENCE)
				{
					data->EscSeq[data->InputPos++] = text[i];
				}
				if ((text[i] >= 64) && (text[i] <= 126))
				{
					data->EscSeq[data->InputPos] = 0;

					TerminalProcessEscSequence(win, &rc);

					data->InputState = STATE_NORMAL;
				}
			}
		}

		WindowInvalidateLayout(win);
	}
}


/* ---------------------------------------------------------------------
 * TerminalRun
 * Execute a shell or a shell command
 * ---------------------------------------------------------------------
 */
int
TerminalRun(CUIWINDOW* win, const wchar_t* cmd)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		TERMINALDATA* data = (TERMINALDATA*) win->InstData;

		if (data->CoProc == NULL)
		{
			data->CoProc = TerminalCoCreate(cmd);
			if (data->CoProc)
			{
				WindowSetTimer(win, REFRESH_TIMER, REFRESH_CYCLE);
				return TRUE;
			}
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * TerminalPipeData
 * Pipe data to co process
 * ---------------------------------------------------------------------
 */
void 
TerminalPipeData(CUIWINDOW* win, const wchar_t* txt_data)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		TERMINALDATA* data = (TERMINALDATA*) win->InstData;

		if (data->CoProc != NULL)
		{
			TerminalCoWrite(data->CoProc, txt_data, wcslen(txt_data));
		}
	}	
}


/* ---------------------------------------------------------------------
 * TerminalRunning
 * Check if co process is still running
 * ---------------------------------------------------------------------
 */
int  
TerminalRunning(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		int exitcode;
		TERMINALDATA* data = (TERMINALDATA*) win->InstData;

		if (data->CoProc && !TerminalCoIsRunning(data->CoProc, &exitcode))
		{
			WindowKillTimer(win, REFRESH_TIMER);

			TerminalCoDelete(data->CoProc);
			data->CoProc = NULL;

			if (data->CoProcExitHook)
			{
				data->CoProcExitHook(data->CoProcExitTarget, win, exitcode);
			}
		}
		return (data->CoProc != NULL);
	}	
	return FALSE;
}


/* ---------------------------------------------------------------------
 * TerminalUpdateView
 * Check if data is available for display
 * ---------------------------------------------------------------------
 */
void
TerminalUpdateView(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("TERMINAL")) == 0))
	{
		TERMINALDATA* data = (TERMINALDATA*) win->InstData;
		if (data->CoProc)
		{
			wchar_t buffer[256 + 1];

			int c = TerminalCoRead(data->CoProc, buffer, 255);
			while (c > 0)
			{
				TerminalWrite(win, buffer, c);
				c = TerminalCoRead(data->CoProc, buffer, 255);
			}
		}
	}	
}


/* helper functions */

/* ---------------------------------------------------------------------
 * TermShowLine
 * Show a terminal text line
 * ---------------------------------------------------------------------
 */
static void
TerminalShowLine(CUIWINDOW* win, int ypos, int line, CUIRECT* rc)
{
	TERMINALDATA* data = win->InstData;
	WINDOW* w = win->Win;
	int x, attr;
	wchar_t* text = data->Lines[line];
	BYTE*  cols = data->Colors[line];

	attr = cols[0];

	SetColor(w,attr >> 4,attr & 0x0F,FALSE);

	MOVEYX(w, ypos, 0);
	for (x = 0; x < rc->W; x++)
	{
		if (x < MAX_TERMCOLS)
		{
			if (cols[x] != attr)
			{
				attr = cols[x];
				SetColor(w,attr >> 4,attr & 0x0F,FALSE);
			}
			PRINTN(w, &text[x], 1);
		}
		else
		{
			break;
		}
	}
}


/* ---------------------------------------------------------------------
 * TerminalProcessEscSequence
 * Do something with the escape control sequence.
 * ---------------------------------------------------------------------
 */
static void
TerminalProcessEscSequence(CUIWINDOW* win, CUIRECT* rc)
{
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	switch(data->EscSeq[data->InputPos - 1])
	{
	case _T('m'):
		/* terminal colors */
		{
			wchar_t* pos1 = data->EscSeq;
			wchar_t* pos2;
			while (pos1)
			{
				int val;

				pos2 = wcschr(pos1,_T(';'));

				swscanf(pos1,_T("%d"),&val);
				switch(val)
				{
				case 0:  data->CurAttr = (win->Color.WndTxtColor << 4) + win->Color.WndColor; break;
				case 1: 
				case 4:
				case 5:  data->CurAttr |= 0x80; break;
				case 30: data->CurAttr = (data->CurAttr & 0x0F) + (BLACK << 4); break;
				case 31: data->CurAttr = (data->CurAttr & 0x0F) + (RED << 4); break;
				case 32: data->CurAttr = (data->CurAttr & 0x0F) + (GREEN << 4); break;
				case 33: data->CurAttr = (data->CurAttr & 0x0F) + (BROWN << 4); break;
				case 34: data->CurAttr = (data->CurAttr & 0x0F) + (BLUE << 4); break;
				case 35: data->CurAttr = (data->CurAttr & 0x0F) + (MAGENTA << 4); break;
				case 36: data->CurAttr = (data->CurAttr & 0x0F) + (CYAN << 4); break;
				case 37: data->CurAttr = (data->CurAttr & 0x0F) + (LIGHTGRAY << 4); break;
				case 40: data->CurAttr = (data->CurAttr & 0xF0) + BLACK; break;
				case 41: data->CurAttr = (data->CurAttr & 0xF0) + RED; break;
				case 42: data->CurAttr = (data->CurAttr & 0xF0) + GREEN; break;
				case 43: data->CurAttr = (data->CurAttr & 0xF0) + BROWN; break;
				case 44: data->CurAttr = (data->CurAttr & 0xF0) + BLUE; break;
				case 45: data->CurAttr = (data->CurAttr & 0xF0) + MAGENTA; break;
				case 46: data->CurAttr = (data->CurAttr & 0xF0) + CYAN; break;
				case 47: data->CurAttr = (data->CurAttr & 0xF0) + LIGHTGRAY; break;
				}
			
				pos1 = pos2;
				if (pos1) pos1++;
			}
		}
		break;

	case _T('H'):
	case _T('f'):
		/* cursor position (gotoxy)*/
		{
			int   x = 1 ,y = 1;
			wchar_t* sep = wcschr(data->EscSeq,_T(';'));

			if ((data->EscSeq[0] >= _T('0')) && (data->EscSeq[0] <= _T('9')))
			{
				swscanf(data->EscSeq,_T("%d"),&y);
			}
			if (sep)
			{
				sep++;
				if ((sep[0] >= _T('0')) && (sep[0] <= _T('9')))
				{
					swscanf(sep,_T("%d"),&x);
				}
			}
			x--; y--;
			if (y > rc->H) y = rc->H;
		
			while (((data->YCursor - data->FirstLine + MAX_TERMLINES) % MAX_TERMLINES + 1) < y)
			{
				TerminalNextLine(win);
			}
			data->XCursor = x;
			data->YCursor = (data->FirstLine + y) % MAX_TERMLINES;
		}
		break;

	case _T('A'):
		/* Move cursor up */
		{
			int count, i;
			if (swscanf(data->EscSeq,_T("%d"),&count) != 1)
			{
				count = 1;
			}
			for (i = 0; i < count; i++)
			{
				TerminalPrevLine(win);
			}
		}
		break;

	case _T('B'):
		/* Move cursor down */
		{
			int count, i;
			if (swscanf(data->EscSeq,_T("%d"),&count) != 1)
			{
				count = 1;
			}
			for (i = 0; i < count; i++)
			{
				TerminalNextLine(win);
			}
		}
		break;

	case _T('C'):
		/* Move cursor right */
		{
			int count;
			if (swscanf(data->EscSeq,_T("%d"),&count) != 1)
			{
				count = 1;
			}
			data->XCursor += count;
			if (data->XCursor >= rc->W)
			{
				data->XCursor = (rc->W > 0) ? rc->W - 1 : 0;
			}
			if (data->XCursor >= MAX_TERMCOLS)
			{
				data->XCursor = (MAX_TERMCOLS - 1);
			}
		}
		break;

	case _T('D'):
		/* Move cursor left */
		{
			int count;
			if (swscanf(data->EscSeq,_T("%d"),&count) != 1)
			{
				count = 1;
			}
			data->XCursor -= count;
			if (data->XCursor < 0)
			{
				data->XCursor = 0;
			}
		}
		break;

	case _T('J'):
		/* clear screen */
		{
			int i;
			data->YCursor = data->FirstLine;
			data->XCursor = 0;
			for (i = 0; i < rc->H; i++)
			{
				TerminalNextLine(win);
			}
		}
		break;

	case _T('K'):
		/* clear line */
		{
			wmemset(data->Lines[data->YCursor],_T(' '),MAX_TERMCOLS);
			memset(data->Colors[data->YCursor],data->CurAttr,MAX_TERMCOLS);
		}
		break;

	case _T('G'):
		/* Move cursor to column */
		{
			int column;
			if (swscanf(data->EscSeq,_T("%d"),&column) != 1)
			{
				column = 1;
			}
			data->XCursor = (column < rc->W) ? column : rc->W;
			if (data->XCursor > MAX_TERMCOLS)
			{
				data->XCursor = MAX_TERMCOLS;
			}
		}
		break;
	}
}


/* ---------------------------------------------------------------------
 * TerminalNextLine
 * Switch input focus to the next line
 * ---------------------------------------------------------------------
 */
static void
TerminalNextLine(CUIWINDOW* win)
{
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;

	data->YCursor = (data->YCursor + 1) % MAX_TERMLINES;

	if (data->YCursor == data->FirstLine)
	{
		wmemset(data->Lines[data->YCursor],_T(' '),MAX_TERMCOLS);
		memset(data->Colors[data->YCursor],data->CurAttr,MAX_TERMCOLS);
		data->FirstLine = (data->FirstLine + 1) % MAX_TERMLINES;
	}
	TerminalCalcPos(win);
}


/* ---------------------------------------------------------------------
 * TerminalPrevLine
 * Switch input focus to the prev line
 * ---------------------------------------------------------------------
 */
static void
TerminalPrevLine(CUIWINDOW* win)
{
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;
	if (data->YCursor != data->FirstLine)
	{
		if (data->YCursor > 0)
		{
			data->YCursor--;
		}
		else
		{
			data->YCursor = (MAX_TERMLINES - 1);
		}
	}
	TerminalCalcPos(win);
}


/* ---------------------------------------------------------------------
 * TerminalCursorOnOff
 * Changes the visibility of the cursor
 * ---------------------------------------------------------------------
 */
static void
TerminalCursorOnOff(CUIWINDOW* win)
{
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;
	CUIRECT rc;
	int ypos, yscroll;

	if (data->HasFocus)
	{
		WindowGetClientRect(win, &rc);
		yscroll = WindowGetVScrollPos(win);

		ypos = ((data->YCursor - data->FirstLine + MAX_TERMLINES) % MAX_TERMLINES) -
			yscroll;
		if (ypos >= rc.H)
		{
			WindowCursorOff();
		}
		else
		{
			WindowCursorOn();
		}
	}
	else
	{
		WindowCursorOff();
	}
}


/* ---------------------------------------------------------------------
 * TerminalCalcPos
 * Recalculate Terminal ranges
 * ---------------------------------------------------------------------
 */
static void
TerminalCalcPos(CUIWINDOW* win)
{
	TERMINALDATA* data = (TERMINALDATA*) win->InstData;
	CUIRECT rc;
	int     yrange;
	int     ynewrange;
	int     yscroll;
	int     ynewscroll;

	WindowGetClientRect(win, &rc);
	yrange = WindowGetVScrollRange(win);

	ynewrange =
		((data->YCursor - data->FirstLine + MAX_TERMLINES) % MAX_TERMLINES + 1) - 
		(rc.H);

	if (ynewrange != yrange)
	{
		yrange = ynewrange;
		if (yrange <= 0) 
		{
			yrange = 0;
			WindowEnableVScroll(win, FALSE);
			WindowSetVScrollRange(win, yrange);
		}
		else
		{
			WindowSetVScrollRange(win, yrange);
			WindowEnableVScroll(win, TRUE);
		}
	}

	yscroll = WindowGetVScrollPos(win);
	ynewscroll =
		((data->YCursor - data->FirstLine + MAX_TERMLINES) % MAX_TERMLINES + 1) - rc.H;

	if (yscroll != ynewscroll)
	{
		yscroll = ynewscroll;
		if (yscroll < 0) 
		{
			yscroll = 0;
			WindowSetVScrollPos(win, yscroll);
		}
		else
		{
			WindowSetVScrollPos(win, yscroll);
		}
	}
}


/* ---------------------------------------------------------------------
 * TerminalUpdate
 * Update terminal window
 * ---------------------------------------------------------------------
 */
static void
TerminalUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* co process handling */

/* ---------------------------------------------------------------------
 * TerminalCoCreate
 * Run a shell command
 * ---------------------------------------------------------------------
 */
static COPROC*
TerminalCoCreate(const wchar_t* cmd)
{
	int     pipe1[2], pipe2[2], pipe3[2];
	pid_t   pid;
	char*   pcmd;
	COPROC* coproc;

	if (signal(SIGPIPE, sig_handler) == SIG_ERR)
	{
		return NULL;
	}

	if (pipe(pipe1) < 0 || pipe(pipe2) < 0 || pipe(pipe3) < 0)
	{
		return NULL;
	}

	coproc = (COPROC*) malloc(sizeof(COPROC));
	coproc->Command = wchar_t_dup_to_mbchar(cmd);
	coproc->ReadBuf = (char*) malloc((BUFSIZE + 1) * sizeof(char));
	coproc->ReadPos = 0;
	coproc->ReadSize = 0;

	coproc->Terminated = FALSE;

	pcmd = coproc->Command;

	if ((pid = fork()) < 0)
	{
		free(coproc->Command);
		free(coproc->ReadBuf);
		free(coproc);
		return FALSE;
	}
	else if (pid > 0)
	{
		close(pipe1[0]);
		close(pipe2[1]);
		close(pipe3[1]);

		coproc->FdStdin = pipe1[1];
		coproc->FdStdout = pipe2[0];
		coproc->FdStderr = pipe3[0];
		coproc->Pid = pid;
		coproc->StdoutOpen = TRUE;
		coproc->StderrOpen = TRUE;
		return coproc;
	}
	else
	{
		char*  argv[4];

		if(!(argv[0] = getenv("SHELL")))
		{
			argv[0] = DEFAULT_SHELL;
		}
		argv[1] = NULL;

		if (cmd)
		{
			argv[1] = "-c";
			argv[2] = (char*) pcmd;
			argv[3] = NULL;
		}

		TerminalCoExecute(pipe1,pipe2,pipe3,argv[0],&argv[0]);
		return NULL;
	}
}

/* ---------------------------------------------------------------------
 * TerminalCoRead
 * Read data from shell running as a coprocess
 * ---------------------------------------------------------------------
 */
static int
TerminalCoRead(COPROC* coproc, wchar_t *buf, int count)
{
	mbstate_t    state;
	const char*  p;
	int          c;
	int          result = 0;
	
	memset (&state, 0, sizeof(state));
	do
	{	
		if (coproc->ReadPos >= coproc->ReadSize)
		{
			struct timeval timer1;
			fd_set set;
			int    res;

			coproc->ReadPos = 0;
			coproc->ReadSize = 0;
			coproc->ReadBuf[0] = 0;

			if ((coproc->StderrOpen != FALSE) || (coproc->StdoutOpen != FALSE))
			{
				int fhnr = (coproc->FdStdout > coproc->FdStderr) ? 
				    coproc->FdStdout : coproc->FdStderr;

				timer1.tv_sec = 0;
				timer1.tv_usec = 100;

				FD_ZERO(&set);
				if (coproc->StdoutOpen)
				{
					FD_SET(coproc->FdStdout,&set);
				}
				if (coproc->StderrOpen)
				{
					FD_SET(coproc->FdStderr,&set);
				}

				res = select(fhnr + 1, &set, NULL, NULL, &timer1);
				if (res > 0)
				{
					if (FD_ISSET(coproc->FdStderr,&set))
					{
						int c = read(coproc->FdStderr, coproc->ReadBuf, BUFSIZE);
						if (c > 0)
						{
							coproc->ReadSize = c;
							coproc->ReadBuf[c] = 0;
						}
						else
						{
							coproc->StderrOpen = FALSE;
						}
					}
					if (FD_ISSET(coproc->FdStdout,&set))
					{
						int c = read(coproc->FdStdout, coproc->ReadBuf, BUFSIZE);
						if (c > 0)
						{
							coproc->ReadSize = c;
							coproc->ReadBuf[c] = 0;
						}
						else
						{
							coproc->StdoutOpen = FALSE;
						}
					}
				}
			}
		}
		c = (coproc->ReadSize - coproc->ReadPos);
		p = &coproc->ReadBuf[coproc->ReadPos];
		if (c > 0)
		{
			int num;
			num = c;
			do
			{
				if (count > result)
				{
					int size = mbrtowc(buf, p, num, &state);
					if (size > 0)
					{
						buf++;
						result++;
						num -= size;
						p += size;
					}
					else if (size == -2)
					{
						break; /* character incompelte */
					}
					else
					{
						*(buf++) = L'?';
						result++;
						num--;
						p++;
					}
				}
				else
				{
					*(buf++) = 0;
					coproc->ReadPos += (c - num);
					return result;
				}
			}
			while (num > 0);
			coproc->ReadPos += c;
		}
	}
	while (c > 0);

	*(buf++) = 0;
	return result;
}


/* ---------------------------------------------------------------------
 * TerminalCoWrite
 * Write data to shell running as a coprocess
 * ---------------------------------------------------------------------
 */
static int
TerminalCoWrite(COPROC* coproc, const wchar_t *buf, int count)
{
	mbstate_t         state;
	int               result = 0;
	const wchar_t*    p1     = buf;
	const wchar_t*    p2     = buf;
	char              cbuffer[128 + 1];
	
	memset (&state, 0, sizeof(state));

	while ((count > 0) && (p1 != NULL))
	{
		int num = (count < 128) ? count : 128;
		int size = wcsrtombs(cbuffer, &p2, num, &state);
		if (size > 0)
		{
			result += write(coproc->FdStdin, cbuffer, size);
		}
		else if (size < 0)
		{
			break; /* -> invalid unicode character encountered */
		}
		if (p2 != NULL)
		{
			count -= (p2 - p1);
		}
		p1 = p2;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * TerminalCoDelete
 * Close an existing coprocess
 * ---------------------------------------------------------------------
 */
static void
TerminalCoDelete(COPROC* coproc)
{
	if (!coproc) return;

	if (!coproc->Terminated)
	{
		int status;
		if (kill(coproc->Pid, SIGINT) != -1)
		{
			waitpid(coproc->Pid,&status,0);
		}
	}

	close(coproc->FdStdin);
	close(coproc->FdStdout);
	close(coproc->FdStderr);
	free(coproc->Command);
	free(coproc->ReadBuf);
	free(coproc);
}

/* ---------------------------------------------------------------------
 * TerminalCoIsRunning
 * Has the shell been closed?
 * ---------------------------------------------------------------------
 */
static int
TerminalCoIsRunning(COPROC* coproc, int *exitcode)
{
	int status;
	if (!coproc) return FALSE;

	if (coproc->Terminated)
	{
		return FALSE;
	}

	if (waitpid(coproc->Pid,&status,WNOHANG) == coproc->Pid)
	{
		if (WIFEXITED(status))
		{
			coproc->Terminated = TRUE;
			if (exitcode)
			{
				*exitcode = status;
			}
			return FALSE;
		}
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * TerminalCoExecute (internal)
 * Execute the shell command "filename" and redirect stdin and stderr
 * to the given pipes.
 * ---------------------------------------------------------------------
 */
static void
TerminalCoExecute(int* pipe1, int* pipe2, int* pipe3,
              const char* filename,
              char* const parameters[])
{
	close(pipe1[1]);
	close(pipe2[0]);
	close(pipe3[0]);
	if (pipe1[0] != STDIN_FILENO)
	{
		dup2(pipe1[0], STDIN_FILENO);
		close(pipe1[0]);
	}
	if (pipe2[1] != STDOUT_FILENO)
	{
		dup2(pipe2[1], STDOUT_FILENO);
		close(pipe2[1]);
	}
	if (pipe3[1] != STDERR_FILENO)
	{
		dup2(pipe3[1], STDERR_FILENO);
		close(pipe3[1]);
	}

	if (execv(filename, parameters) < 0)
	{
		close(pipe1[0]);
		close(pipe2[1]);
		close(pipe3[1]);
		exit(EXIT_FAILURE);
	}
}

/* ---------------------------------------------------------------------
 * sig_handler
 * A signal has been send to us
 * ---------------------------------------------------------------------
 */
static void sig_handler(int signr)
{
	switch(signr)
	{
	case SIGPIPE:
		exit(EXIT_FAILURE);
		break;
	case SIGINT:
		/* killpg(pid, SIGINT); */
		break;
	case SIGCHLD:
		break;
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

static int
mbchar_byte_len(const wchar_t* s)
{
	return wcsrtombs(NULL, &s, BUFFER_SIZE_MAX, NULL);
}



