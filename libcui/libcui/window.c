/* ---------------------------------------------------------------------
 * File: window.c
 * (base cui API and core window functions)
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

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <term.h>
#include <ctype.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <locale.h>
#include <langinfo.h>

#include <stdlib.h>
#include "cui.h"

#define KEYDELAY 100

/* mouse action codes */
enum
{
	MOUSE_NO_ACTION      = 0,
	MOUSE_VSCROLL_UP     = 10,
	MOUSE_VSCROLL_DOWN   = 11,
	MOUSE_VSCROLL_PGUP   = 12,
	MOUSE_VSCROLL_PGDOWN = 13,
	MOUSE_VSCROLL_TRACK  = 14,
	MOUSE_HSCROLL_UP     = 20,
	MOUSE_HSCROLL_DOWN   = 21,
	MOUSE_HSCROLL_PGUP   = 22,
	MOUSE_HSCROLL_PGDOWN = 23,
	MOUSE_HSCROLL_TRACK  = 24,
	MOUSE_WINDOW_MOVE    = 30,
};


typedef void (*SigProc)(int);

/* ---------------------------------------------------------------------
 * color scheme type
 * ---------------------------------------------------------------------
 */
typedef struct
{
	wchar_t*      Name;         /* Name of this color scheme */
	CUIWINCOLOR ColorRec;     /* Colors defined here */
	void*       Next;         /* Next scheme in the list */
} CUICOLSCHEME;

/* ---------------------------------------------------------------------
 * window timer struct
 * ---------------------------------------------------------------------
 */
typedef struct
{
	CUIWINDOW* Window;        /* The window this timer belongs to */
	int        Deleted;       /* Has the timer been killed? */
	int        Id;            /* Id of this timer */
	int        ReloadValue;   /* Timer reload value */
	int        Value;         /* Current timer value */
	void*      Next;          /* Next timer in the list */
} CUITIMER;

/* ---------------------------------------------------------------------
 * node for window hook function list
 * ---------------------------------------------------------------------
 */
typedef struct
{
	HookProc   HookFunction;  /* Hook function */
	void*      Next;
} CUIHOOK;


/* ---------------------------------------------------------------------
 * global public variables
 * ---------------------------------------------------------------------
 */
int FocusMove = 0;               /* > 0 when moving down, < 0 moving up */

/* ---------------------------------------------------------------------
 * global private variables
 * ---------------------------------------------------------------------
 */
static int CursesOn = FALSE;     /* Has curses been switched on? */
static int ColorMode = FALSE;    /* Color mode active? */
static int Resize = FALSE;       /* Resize marker (set in signal handler) */
static int CursorOn = FALSE;     /* Cursor is on or off */
static int ScreenDirty = FALSE;  /* Redraw / update screen? */
static int CaptureNcArea = FALSE; /* The current mouse capture is on nc area */

static CUIWINDOW* Desktop = NULL;            /* The desktop window */
static CUIWINDOW* FirstWindow = NULL;        /* First global window */
static CUIWINDOW* LastWindow = NULL;         /* Last global window */
static CUIWINDOW* FocusWindow = NULL;        /* Window with focus */
static CUIWINDOW* CaptureWindow = NULL;      /* Mouse capture window */
static CUITIMER*  FirstTimer = NULL;         /* Timer list */
static CUICOLSCHEME* FirstColScheme = NULL;  /* Color scheme list */


struct sigaction  SignalAction, OldAction;

/* ---------------------------------------------------------------------
 * local prototypes
 * ---------------------------------------------------------------------
 */
static void WindowClearHooks(CUIHOOK* hooklst);
static void WindowExecHook(CUIWINDOW* win, CUIHOOK* hooklst);
static void WindowCalcIntersection(CUIRECT* rc1, CUIRECT* rc2, CUIRECT* rc);
static void WindowPaintDecoration(CUIWINDOW* win, int size_x, int size_y);
static void WindowPaint(CUIWINDOW* win);
static int  WindowActivate(CUIWINDOW* win);
static CUIWINDOW* WindowFindXY(CUIWINDOW* win, CUIPOINT* pt, CUIRECT* rcw,
                               CUIRECT* rc, CUIRECT* rcp);
static CUIWINDOW* WindowGetWindowXY(CUIWINDOW* basewnd, CUIPOINT* pt, CUIRECT* rcw);
static CUIWINDOW* WindowGetDefaultOk(CUIWINDOW* basewnd);
static CUIWINDOW* WindowGetDefaultCancel(CUIWINDOW* basewnd);
static void WindowMouse(CUIWINDOW* basewnd);
static void WindowMButtonNc(CUIWINDOW* win, int x, int y, int flags, int sizex, int sizey);
static void WindowMMoveNc(CUIWINDOW* win, int x, int y, int sizex, int sizey);
static void WindowGetRelWindowRect(CUIWINDOW* win, CUIRECT* rc);
static void WindowMakeClientRect(CUIWINDOW* win, CUIRECT* rc);
static void WindowGetVisibleRect(CUIWINDOW* win, CUIRECT* vrc, CUIRECT* tmprc);
static void WindowUpdateWindow(CUIWINDOW* win);
static void WindowResize(CUIWINDOW* win);
static void WindowCursorXY(CUIWINDOW* win);
static void WindowUpdateTimers(void);
static void WindowUpdateLayout(CUIWINDOW* win);
static void WindowExecSizeHook(CUIWINDOW* win);
static int  WindowExecKeyHook(CUIWINDOW* win, int key);
static void WindowResizeHandler(int sig);
static void WindowSigHandler(int sig);
static int  GetKey(int* key);


/* ---------------------------------------------------------------------
 * WindowStart
 * Initializes the curses subsystem, color schemes and the desktop
 * ---------------------------------------------------------------------
 */
void
WindowStart(int color, int mouse)
{
	int x, y;
	WINDOW* w;
	CUIWINCOLOR colrec;
	sigset_t set, old_set;
	struct winsize size;


	ESCDELAY = 200;

	/* setup locales */
	setlocale(LC_ALL,"");
#ifdef UNICODE
	if(strcmp(nl_langinfo(CODESET), "UTF-8")) 
	{
		fprintf(stderr, "Du willst UTF-8 aktivieren!\n");
		exit(EXIT_SUCCESS);
	}
#endif

	/* setup signals for job control handling */
	SignalAction.sa_handler = (SigProc) WindowSigHandler;
	SignalAction.sa_flags = 0;

	sigemptyset( &set);
	SignalAction.sa_mask = set;

	sigaddset( &set, SIGTSTP );
	sigaddset( &set, SIGTTIN ); 
	sigaddset( &set, SIGCONT );
	sigaddset( &set, SIGTTOU );
	sigprocmask(SIG_SETMASK, &set, &old_set );

	sigaction(SIGCONT, &SignalAction, NULL );
	SignalAction.sa_mask = set;  

	sigaction( SIGTTIN, &SignalAction, &OldAction );
	sigaction( SIGTTOU, &SignalAction, NULL );
	sigaction( SIGTSTP, &SignalAction, NULL );

	/* setup curses */
	initscr  ();
	clear    ();
	noecho   ();
	keypad   (stdscr,TRUE);
	curs_set (0);
	cbreak   ();
	halfdelay(1);
	if (color)
	{
		InitColor();
	}

	/* complete signals */
	sigprocmask(SIG_SETMASK, &old_set, NULL );
	signal     (SIGWINCH, WindowResizeHandler);

	/* check if console has been resized */
	if (ioctl(fileno(stdout), TIOCGWINSZ, &size) == 0)
	{
		if ((size.ws_row != LINES) || (size.ws_col != COLS))
		{
			Resize = TRUE;
		}
	}

	/* setup mouse */
	if (mouse)
	{
		mousemask(ALL_MOUSE_EVENTS | REPORT_MOUSE_POSITION, 0);
	}
	CursesOn = TRUE;

	/* define/initialize color schemes */
	if (!WindowHasColScheme(_T("WINDOW")))
	{
		colrec.WndColor = BLUE;
		colrec.WndSelColor = LIGHTGRAY;
		colrec.WndTxtColor = LIGHTGRAY;
		colrec.SelTxtColor = BLACK;
		colrec.InactTxtColor = DARKGRAY;
		colrec.HilightColor = YELLOW;
		colrec.TitleTxtColor = BLACK;
		colrec.TitleBkgndColor = LIGHTGRAY;
		colrec.StatusTxtColor = BLACK;
		colrec.StatusBkgndColor = LIGHTGRAY;
		colrec.BorderColor = LIGHTGRAY;
		WindowAddColScheme(_T("WINDOW"), &colrec);
	}
	if (!WindowHasColScheme(_T("DESKTOP")))
	{
		colrec.WndColor = BLUE;
		colrec.WndSelColor = LIGHTGRAY;
		colrec.WndTxtColor = LIGHTGRAY;
		colrec.SelTxtColor = BLACK;
		colrec.InactTxtColor = DARKGRAY;
		colrec.HilightColor = YELLOW;
		colrec.TitleTxtColor = BLACK;
		colrec.TitleBkgndColor = LIGHTGRAY;
		colrec.StatusTxtColor = LIGHTGRAY;
		colrec.StatusBkgndColor = BLACK;
		colrec.BorderColor = LIGHTGRAY;
		WindowAddColScheme(_T("DESKTOP"), &colrec);
	}
	if (!WindowHasColScheme(_T("DIALOG")))
	{
		colrec.WndColor = LIGHTGRAY;
		colrec.WndSelColor = LIGHTCYAN;
		colrec.WndTxtColor = BLACK;
		colrec.SelTxtColor = BLACK;
		colrec.InactTxtColor = DARKGRAY;
		colrec.HilightColor = BLUE;
		colrec.TitleTxtColor = WHITE;
		colrec.TitleBkgndColor = MAGENTA;
		colrec.StatusTxtColor = BLACK;
		colrec.StatusBkgndColor = LIGHTGRAY;
		colrec.BorderColor = BLACK;
		WindowAddColScheme(_T("DIALOG"), &colrec);
	}
	if (!WindowHasColScheme(_T("MENU")))
	{
		colrec.WndColor = CYAN;
		colrec.WndSelColor = BLACK;
		colrec.WndTxtColor = BLACK;
		colrec.SelTxtColor = WHITE;
		colrec.InactTxtColor = DARKGRAY;
		colrec.HilightColor = YELLOW;
		colrec.TitleTxtColor = BLACK;
		colrec.TitleBkgndColor = LIGHTGRAY;
		colrec.StatusTxtColor = BLACK;
		colrec.StatusBkgndColor = LIGHTGRAY;
		colrec.BorderColor = BLACK;
		WindowAddColScheme(_T("MENU"), &colrec);
	}
	if (!WindowHasColScheme(_T("TERMINAL")))
	{
		colrec.WndColor = BLACK;
		colrec.WndSelColor = LIGHTGRAY;
		colrec.WndTxtColor = LIGHTGRAY;
		colrec.SelTxtColor = BLACK;
		colrec.InactTxtColor = LIGHTGRAY;
		colrec.HilightColor = LIGHTGRAY;
		colrec.TitleTxtColor = BLACK;
		colrec.TitleBkgndColor = LIGHTGRAY;
		colrec.StatusTxtColor = BLACK;
		colrec.StatusBkgndColor = LIGHTGRAY;
		colrec.BorderColor = LIGHTGRAY;
		WindowAddColScheme(_T("TERMINAL"), &colrec);
	}
	if (!WindowHasColScheme(_T("HELP")))
	{
		colrec.WndColor = LIGHTGRAY;
		colrec.WndSelColor = BLACK;
		colrec.WndTxtColor = BLACK;
		colrec.SelTxtColor = WHITE;
		colrec.InactTxtColor = DARKGRAY;
		colrec.HilightColor = BLUE;
		colrec.TitleTxtColor = LIGHTGRAY;
		colrec.TitleBkgndColor = BLUE;
		colrec.StatusTxtColor = BLACK;
		colrec.StatusBkgndColor = LIGHTGRAY;
		colrec.BorderColor = BLACK;
		WindowAddColScheme(_T("HELP"), &colrec);
	}

	/* will be replaced by correct Desktop window implementation */
	Desktop = WindowNew(NULL, 0, 0, COLS, LINES, 0);
	WindowColScheme(Desktop, _T("DESKTOP"));
	WindowCreate(Desktop);

	w = stdscr;
	SetColor(w, Desktop->Color.WndTxtColor, Desktop->Color.WndColor, FALSE);
	for (y = 0; y < LINES; y++)
	{
		MOVEYX(w, y, 0); 
		for (x = 0; x < COLS; x++)
		{
			waddch(w, ' ');
		}
	}

	refresh();
}

/* ---------------------------------------------------------------------
 * WindowEnd
 * Frees all data structures and uninitializes the curses subsystem
 * ---------------------------------------------------------------------
 */
void
WindowEnd(void)
{
	CUICOLSCHEME* scheme = FirstColScheme;
	while (scheme)
	{
		FirstColScheme = (CUICOLSCHEME*) scheme->Next;
		free(scheme->Name);
		free(scheme);
		scheme = FirstColScheme;
	}
	if (Desktop)
	{
		WindowDestroy(Desktop);
	}
	if (CursesOn)
	{
		WINDOW* w = stdscr;
		int x, y;

		SetColor(w, LIGHTGRAY, BLACK, FALSE);
		for (y = 0; y < LINES; y++)
		{
			MOVEYX(w, y, 0);
			for (x = 0; x < COLS; x++)
			{
				waddch(w, ' ');
			}
		}

		refresh();
		keypad(stdscr, FALSE);
		clear();
		endwin();
		(void) signal(SIGWINCH, SIG_DFL);
		printf("\033[%i;0H", LINES);
	}
}

/* ---------------------------------------------------------------------
 * WindowRun
 * Enter the applications main message loop. Since the first child of
 * the desktop window always is a popup window and futher is the
 * applications main window, we execute it like a modal dialog and
 * quit the library when this window has been closed.
 * ---------------------------------------------------------------------
 */
int
WindowRun(void)
{
	if (Desktop->FirstChild && !((CUIWINDOW*)Desktop->FirstChild)->IsClosed)
	{
		return WindowModal(Desktop->FirstChild);
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * WindowModal
 * Enter a windows modal message loop
 * ---------------------------------------------------------------------
 */
int
WindowModal(CUIWINDOW* win)
{
	win->IsClosed = FALSE;
	WindowSetFocus(win);
	WindowUpdate();
	while(!win->IsClosed)
	{
		int key;
		
/*		WindowUpdateLayout(Desktop->FirstChild);*/
		
		if (GetKey(&key))
		{
			if (key == KEY_MOUSE)
			{
				WindowMouse(win);
				if (ScreenDirty)
				{
					WindowUpdate();
				}
				else
				{
					WindowUpdateLayout(Desktop->FirstChild);
				}
			}
			else if (key == KEY_RESIZE)
			{
				Desktop->Position.X = 0;
				Desktop->Position.Y = 0;
				Desktop->Position.W = COLS;
				Desktop->Position.H = LINES;
				WindowResize(Desktop);

				untouchwin(stdscr);

				WindowUpdate();
			}
			else if (FocusWindow)
			{
				if (!WindowExecKeyHook(FocusWindow, key))
				{
					if (key == KEY_RETURN)
					{
						CUIWINDOW* defctrl = WindowGetDefaultOk(win);
						if (defctrl && defctrl->KeyHook)
						{
							defctrl->KeyHook(defctrl, KEY_RETURN);
						}
					}
					else if (key == KEY_ESC)
					{
						CUIWINDOW* defctrl = WindowGetDefaultCancel(win);
						if (defctrl && defctrl->KeyHook)
						{
							defctrl->KeyHook(defctrl, KEY_RETURN);
						}
					}
				}
				if (ScreenDirty)
				{
					WindowUpdate();
				}
				else
				{
					WindowUpdateLayout(Desktop->FirstChild);
				}
			}
		}
		else
		{
			WindowUpdateTimers();
			if (ScreenDirty)
			{
				WindowUpdate();
			}
			else
			{
				WindowUpdateLayout(Desktop->FirstChild);
			}
		}
	}

	/* Set the focus to the owner of the modal window */
	if (win->Owner)
	{
		WindowSetFocus(win->Owner);
	}

	/* exit */
	return win->ExitCode;
}

/* ---------------------------------------------------------------------
 * WindowClose
 * Exit a modal message loop and pass an exitcode to the calling
 * function
 * ---------------------------------------------------------------------
 */
int
WindowClose(CUIWINDOW* win, int exitcode)
{
	CUIWINDOW* child;
	if (win->CanCloseHook)
	{
		if (!win->CanCloseHook(win))
		{
			return FALSE;
		}
	}
	child = win->FirstChild;
	while (child)
	{
		if (!WindowClose(child, 0))
		{
			return FALSE;
		}
		child = (CUIWINDOW*) child->Next;
	}
	win->IsClosed = TRUE;
	win->ExitCode = exitcode;
	return TRUE;
}

/* ---------------------------------------------------------------------
 * WindowQuit
 * Exit the applications main message loop, terminating the application
 * ---------------------------------------------------------------------
 */
void
WindowQuit(int exitcode)
{
	if (Desktop->FirstChild)
	{
		WindowClose(Desktop->FirstChild, exitcode);
	}
}

/* ---------------------------------------------------------------------
 * WindowLeaveCurses
 * Temporarily leave curses mode
 * ---------------------------------------------------------------------
 */
void
WindowLeaveCurses(void)
{
	if (CursesOn)
	{
		endwin();
		signal(SIGWINCH, SIG_DFL);
		printf("\033[%i;0H", LINES);
		reset_shell_mode();
	}
}

/* ---------------------------------------------------------------------
 * WindowResumeCurses
 * Restore curses mode after it has been left with WindowLeaveCurses
 * ---------------------------------------------------------------------
 */
void
WindowResumeCurses(void)
{
	if (CursesOn)
	{
		struct winsize size;

		reset_prog_mode();
		signal(SIGWINCH, WindowResizeHandler);

		if (ioctl(fileno(stdout), TIOCGWINSZ, &size) == 0)
		{
		        refresh();
			if ((size.ws_row != LINES) || (size.ws_col != COLS))
			{
				Resize = TRUE;
			}
		}
		else
		{
			refresh();
		}
	}
}


/* ---------------------------------------------------------------------
 * WindowNew
 * Allocate the structure for a new generic CUI window
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
WindowNew(CUIWINDOW* parent, int x, int y, int w, int h, int flags)
{
	CUIWINDOW* newwin = (CUIWINDOW*) malloc(sizeof(CUIWINDOW));
	if (newwin)
	{
		memset(newwin, 0, sizeof(CUIWINDOW));
		newwin->Class          = _T("WINDOW");
		newwin->HotKey         = _T('\0');
		newwin->Id             = 0;
		newwin->ExitCode       = 0;
		newwin->Position.X     = x;
		newwin->Position.Y     = y;
		newwin->Position.W     = w;
		newwin->Position.H     = h;
		newwin->HasBorder      = ((flags & CWS_BORDER)   != 0);
		newwin->HasCaption     = ((flags & CWS_CAPTION)  != 0);
		newwin->HasStatusBar   = ((flags & CWS_STATUSBAR) != 0);
		newwin->HasMenu        = FALSE;
		newwin->HasMinimizeBox = ((flags & CWS_MINIMIZEBOX) != 0);
		newwin->HasMaximizeBox = ((flags & CWS_MAXIMIZEBOX) != 0);
		newwin->HasCloseBox    = ((flags & CWS_CLOSEBOX)    != 0);
		newwin->HasSysMenu     = ((flags & CWS_SYSMENU)  != 0);
		newwin->HasResize      = ((flags & CWS_RESIZE)   != 0);

		newwin->HasVScroll     = FALSE;
		newwin->HasHScroll     = FALSE;
		newwin->IsCreated      = FALSE;
		newwin->IsPopup        = ((flags & CWS_POPUP)     != 0);
		newwin->IsHidden       = ((flags & CWS_HIDDEN)    != 0);
		newwin->IsEnabled      = ((flags & CWS_DISABLED)  == 0);
		newwin->IsMinimized    = ((flags & CWS_MINIMIZED) != 0);
		newwin->IsMaximized    = ((flags & CWS_MAXIMIZED) != 0);
		newwin->IsCentered     = ((flags & CWS_CENTERED)  != 0);
		newwin->IsActive       = FALSE;
		newwin->IsClosed       = FALSE;

		newwin->IsDefOk        = ((flags & CWS_DEFOK)     != 0);
		newwin->IsDefCancel    = ((flags & CWS_DEFCANCEL) != 0);

		newwin->WantsFocus     = ((flags & CWS_TABSTOP)   != 0);

		newwin->LayoutValid    = FALSE;

		if (newwin->IsPopup && (parent != Desktop))
		{
			newwin->Parent = Desktop;
			newwin->Owner  = parent;
		}
		else
		{
			newwin->Parent = parent;
			newwin->Owner  = NULL;
		}

		newwin->ActiveChild = NULL;

		newwin->Win = NULL;
		newwin->Frame = NULL;

		if (parent && !newwin->IsPopup)
		{
			newwin->Color = parent->Color;
		}
		else
		{
			newwin->Color.WndColor = LIGHTGRAY;
			newwin->Color.WndSelColor = LIGHTCYAN;
			newwin->Color.WndTxtColor = BLACK;
			newwin->Color.SelTxtColor = BLACK;
			newwin->Color.InactTxtColor = DARKGRAY;
			newwin->Color.HilightColor = BLUE;
		}
		
		newwin->VScrollBar.Range = 0;
		newwin->VScrollBar.Pos = 0;
		newwin->HScrollBar.Range = 0;
		newwin->HScrollBar.Pos = 0;
		newwin->MouseAction = MOUSE_NO_ACTION;
	}
	return newwin;
}

/* ---------------------------------------------------------------------
 * WindowCreate
 * Create a window by linking it into the window hierary tree, creating
 * the curses pads and calling the hook function for creation and
 * window painting
 * ---------------------------------------------------------------------
 */
void
WindowCreate(CUIWINDOW* win)
{
	if (!win->Parent)
	{
		if (FirstWindow)
		{
			LastWindow->Next = win;
			win->Previous = LastWindow;
		}
		else
		{
			FirstWindow = win;
		}
		LastWindow = win;

	}
	else
	{
		if (((CUIWINDOW*) win->Parent)->FirstChild)
		{
			((CUIWINDOW*)((CUIWINDOW*) win->Parent)->LastChild)->Next = win;
			win->Previous = ((CUIWINDOW*) win->Parent)->LastChild;
		}
		else
		{
			((CUIWINDOW*) win->Parent)->FirstChild = win;
		}
		((CUIWINDOW*) win->Parent)->LastChild = win;

		/* find the real owner */
		if (win->Owner)
		{
			while (((CUIWINDOW*)win->Owner)->Parent != Desktop)
			{
				win->Owner = ((CUIWINDOW*)win->Owner)->Parent;
			}
		}
	}

	win->IsClosed = FALSE;

	if (win->IsCentered && win->IsPopup)
	{
		win->Position.X = (COLS - win->Position.W) / 2;
		win->Position.Y = (LINES - win->Position.H) / 2;
	}

	if (win->IsMaximized && win->Parent)
	{
		CUIRECT rc = ((CUIWINDOW*)win->Parent)->Position;
		WindowMakeClientRect(win->Parent, &rc);
		win->Win = newpad(rc.H, rc.W);
		win->Frame = newpad(rc.H, rc.W);
		win->IsCreated = TRUE;

		WindowPaintDecoration(win, rc.W, rc.H);
	}
	else
	{
		win->Win = newpad(win->Position.H, win->Position.W);
		win->Frame = newpad(win->Position.H, win->Position.W);
		win->IsCreated = TRUE;

		WindowPaintDecoration(win, win->Position.W, win->Position.H);
	}
	WindowExecHook(win, win->CreateHooks);
	if (win->SizeHook) win->SizeHook(win);
	WindowPaint(win);
	if (win->InitHook) win->InitHook(win);
}

/* ---------------------------------------------------------------------
 * WindowDestroy
 * Remove a window by unlinking it from the window tree and deleting
 * all data and client windows
 * ---------------------------------------------------------------------
 */
void
WindowDestroy(CUIWINDOW* win)
{
	CUIWINDOW* child;

	/* Kill all window timers */
	WindowKillTimer(win, (-1));

	/* send message */
	if (FocusWindow == win)
	{
		WindowFocusNext(win);

		if (FocusWindow == win)
		{
			WindowSetFocus(Desktop);
		}
	}
	WindowExecHook(win, win->DestroyHooks);

	/* destroy child windows */
	child = (CUIWINDOW*) win->FirstChild;
	while (child)
	{
		win->FirstChild = child->Next;
		WindowDestroy(child);
		child = (CUIWINDOW*) win->FirstChild;
	}

	/* unlink window */
	if (win->Next)
	{
		((CUIWINDOW*) win->Next)->Previous = win->Previous;
	}
	if (!win->Parent)
	{
		if (win->Previous)
		{
			((CUIWINDOW*) win->Previous)->Next = win->Next;
		}
		else
		{
			FirstWindow = win->Next;
		}
		if (LastWindow == win)
		{
			LastWindow = win->Previous;
		}
	}
	else
	{
		if (win->Previous)
		{
			((CUIWINDOW*) win->Previous)->Next = win->Next;
		}
		else
		{
			win->FirstChild = win->Next;
		}
		if (win->LastChild == win)
		{
			win->LastChild = win->Previous;
		}
		if ( ((CUIWINDOW*) win->Parent)->ActiveChild == win)
		{
			((CUIWINDOW*) win->Parent)->ActiveChild = NULL;
		}
		if ( ((CUIWINDOW*) win->Parent)->FirstChild == win)
		{
			((CUIWINDOW*) win->Parent)->FirstChild = win->Next;
		}
		if ( ((CUIWINDOW*) win->Parent)->LastChild == win)
		{
			((CUIWINDOW*) win->Parent)->LastChild = win->Previous;
		}
	}

	/* pass focus to next window */
	if (FocusWindow == win)
	{
		if (win->Next)
		{
			FocusWindow = win->Next;
		}
		else if (win->Previous)
		{
			FocusWindow = win->Previous;
		}
		else
		{
			FocusWindow = win->Parent;
		}
	}

	/* release mouse capture if necessary */
	if (CaptureWindow == win)
	{
		CaptureWindow = NULL;
	}

	/* free memory */
	delwin(win->Win);
	delwin(win->Frame);

	if (win->Text)
	{
		free(win->Text);
	}
	if (win->RText)
	{
		free(win->RText);
	}
	if (win->LText)
	{
		free(win->LText);
	}
	if (win->StatusText)
	{
		free(win->StatusText);
	}
	if (win->RStatusText)
	{
		free(win->RStatusText);
	}
	if (win->LStatusText)
	{
		free(win->LStatusText);
	}
	WindowClearHooks(win->CreateHooks);
	WindowClearHooks(win->DestroyHooks);
	free(win);

	ScreenDirty = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowAddColScheme
 * Add or redefine the colors of a color scheme
 * ---------------------------------------------------------------------
 */
void
WindowAddColScheme(const wchar_t* name, CUIWINCOLOR* colrec)
{
	CUICOLSCHEME* scheme = FirstColScheme;
	while (scheme)
	{
		if (wcscasecmp(scheme->Name, name) == 0)
		{
			scheme->ColorRec = *colrec;
			return;
		}
		scheme = (CUICOLSCHEME*) scheme->Next;
	}
	scheme = (CUICOLSCHEME*) malloc(sizeof(CUICOLSCHEME));
	scheme->Name = wcsdup(name);
	scheme->ColorRec = *colrec;
	scheme->Next = FirstColScheme;
	FirstColScheme = scheme;
}

/* ---------------------------------------------------------------------
 * WindowColScheme
 * Assign a color scheme to a window. Normally a window inherits the
 * colors from it's parent, with WindowColScheme this behaviour can be
 * overwritten
 * ---------------------------------------------------------------------
 */
void
WindowColScheme(CUIWINDOW* win, const wchar_t* name)
{
	CUICOLSCHEME* scheme = FirstColScheme;
	while (scheme)
	{
		if (wcscasecmp(scheme->Name, name) == 0)
		{
			win->Color = scheme->ColorRec;
			return;
		}
		scheme = (CUICOLSCHEME*) scheme->Next;
	}
}

/* ---------------------------------------------------------------------
 * WindowHasColScheme
 * Check if a color scheme has already been defined
 * ---------------------------------------------------------------------
 */
int
WindowHasColScheme(const wchar_t* name)
{
	CUICOLSCHEME* scheme = FirstColScheme;
	while (scheme)
	{
		if (wcscasecmp(scheme->Name, name) == 0)
		{
			return TRUE;
		}
		scheme = (CUICOLSCHEME*) scheme->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowSetText
 * Set the window's (title) text
 * ---------------------------------------------------------------------
 */
void
WindowSetText(CUIWINDOW* win, const wchar_t* text)
{
	wchar_t* hkey = wcschr(text, _T('&'));
	if (hkey)
	{
		win->HotKey = tolower(*(hkey + 1));
	}
	if (!win->Text)
	{
		win->Text = wcsdup(text);
	}
	else
	{
		free(win->Text);
		win->Text = wcsdup(text);
	}
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowSetRText
 * Set right aligned title text (normally NULL)
 * ---------------------------------------------------------------------
 */
void
WindowSetRText(CUIWINDOW* win, const wchar_t* text)
{
	if (win->RText)
	{
		free(win->RText);
	}
	win->RText = wcsdup(text);
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowSetLText
 * Set left aligned title text (normally NULL)
 * ---------------------------------------------------------------------
 */
void
WindowSetLText(CUIWINDOW* win, const wchar_t* text)
{
	if (win->RText)
	{
		free(win->LText);
	}
	win->LText = wcsdup(text);
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowSetRStatusText
 * Set right aligned status text (normally NULL)
 * ---------------------------------------------------------------------
 */
void
WindowSetRStatusText(CUIWINDOW* win, const wchar_t* text)
{
	if (win->RStatusText)
	{
		free(win->RStatusText);
	}
	win->RStatusText = wcsdup(text);
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowSetLStatusText
 * Set left aligned status text (normally NULL)
 * ---------------------------------------------------------------------
 */
void
WindowSetLStatusText(CUIWINDOW* win, const wchar_t* text)
{
	if (win->LStatusText)
	{
		free(win->LStatusText);
	}
	win->LStatusText = wcsdup(text);
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowSetStatusText
 * Set centered status text
 * ---------------------------------------------------------------------
 */
void
WindowSetStatusText(CUIWINDOW* win, const wchar_t* text)
{
	if (win->StatusText)
	{
		free(win->StatusText);
	}
	win->StatusText = wcsdup(text);
	if (win->IsCreated)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);
		WindowPaintDecoration(win, rc.W, rc.H);
	}
}

/* ---------------------------------------------------------------------
 * WindowGetText
 * Read the (title) text from a window
 * ---------------------------------------------------------------------
 */
const wchar_t*
WindowGetText(CUIWINDOW* win, wchar_t* text, int len)
{
	if (len > 0)
	{
		if (win->Text)
		{
			wcsncpy(text, win->Text, len);
			text[len - 1] = 0;
		}
		else
		{
			text[0] = 0;
		}
	}
	return text;
}

/* ---------------------------------------------------------------------
 * WindowSetCreateHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetCreateHook(CUIWINDOW* win, HookProc proc)
{
	if (win && proc)
	{
		CUIHOOK* newhook = (CUIHOOK*) malloc(sizeof(CUIHOOK));
		if (newhook)
		{
			newhook->HookFunction = proc;
			newhook->Next = win->CreateHooks;
			win->CreateHooks = newhook;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetDestroyHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetDestroyHook(CUIWINDOW* win, HookProc proc)
{
	if (win && proc)
	{
		CUIHOOK* newhook = (CUIHOOK*) malloc(sizeof(CUIHOOK));
		if (newhook)
		{
			newhook->HookFunction = proc;
			newhook->Next = win->DestroyHooks;
			win->DestroyHooks = newhook;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetCanCloseHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetCanCloseHook(CUIWINDOW* win, BoolHookProc proc)
{
	win->CanCloseHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetInitHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetInitHook(CUIWINDOW* win, HookProc proc)
{
	win->InitHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetPaintHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetPaintHook(CUIWINDOW* win, HookProc proc)
{
	win->PaintHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetNcPaintHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetNcPaintHook(CUIWINDOW* win, Hook2IntProc proc)
{
	win->NcPaintHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetSizeHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetSizeHook(CUIWINDOW* win, BoolHookProc proc)
{
	win->SizeHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetSetFocusHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetSetFocusHook(CUIWINDOW* win, Hook1PtrProc proc)
{
	win->SetFocusHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetKillFocusHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetKillFocusHook(CUIWINDOW* win, HookProc proc)
{
	win->KillFocusHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetActivateHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetActivateHook(CUIWINDOW* win, HookProc proc)
{
	win->ActivateHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetDeactivateHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetDeactivateHook(CUIWINDOW* win, HookProc proc)
{
	win->DeactivateHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetKeyHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetKeyHook(CUIWINDOW* win, BoolHook1IntProc proc)
{
	win->KeyHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetMMoveHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetMMoveHook(CUIWINDOW* win, Hook2IntProc proc)
{
	win->MMoveHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetMButtonHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetMButtonHook(CUIWINDOW* win, Hook3IntProc proc)
{
	win->MButtonHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetMMoveNcHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetMMoveNcHook(CUIWINDOW* win, Hook4IntProc proc)
{
	win->MMoveNcHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetMButtonNcHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetMButtonNcHook(CUIWINDOW* win, Hook5IntProc proc)
{
	win->MButtonNcHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetVScrollHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetVScrollHook(CUIWINDOW* win, Hook2IntProc proc)
{
	win->VScrollHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetHScrollHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetHScrollHook(CUIWINDOW* win, Hook2IntProc proc)
{
	win->HScrollHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetTimerHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetTimerHook(CUIWINDOW* win, Hook1IntProc proc)
{
	win->TimerHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowSetLayoutHook
 * Hook function assignment
 * ---------------------------------------------------------------------
 */
void
WindowSetLayoutHook(CUIWINDOW* win, HookProc proc)
{
	win->LayoutHook = proc;
}

/* ---------------------------------------------------------------------
 * WindowToTop
 * Make a window the top window in it's sibling list
 * ---------------------------------------------------------------------
 */
int
WindowToTop(CUIWINDOW* win)
{
	if (win->Parent)
	{
		if (win != ((CUIWINDOW*) win->Parent)->LastChild)
		{
			/* unlink window from child list */
			if (win->Previous)
			{
				((CUIWINDOW*)win->Previous)->Next = win->Next;
			}
			if (win->Next)
			{
				((CUIWINDOW*)win->Next)->Previous = win->Previous;
			}
			if (win == ((CUIWINDOW*) win->Parent)->FirstChild)
			{
				((CUIWINDOW*) win->Parent)->FirstChild = win->Next;
			}

			/* add window to the end of the list */
			((CUIWINDOW*)((CUIWINDOW*) win->Parent)->LastChild)->Next = win;
			win->Previous = ((CUIWINDOW*) win->Parent)->LastChild;
			win->Next = NULL;
			((CUIWINDOW*) win->Parent)->LastChild = win;

			if (win->Parent == Desktop)
			{
				CUIWINDOW *topwindow, *nextwindow;

				/* process owned windows */
				topwindow = (CUIWINDOW*) Desktop->FirstChild;
				while (topwindow && (topwindow != win))
				{
					nextwindow = (CUIWINDOW*) topwindow->Next;
					if (topwindow->Owner == win)
					{
						WindowToTop(topwindow);
					}
					topwindow = nextwindow;
				}
			}

			return TRUE;
		}
	}
	else
	{
		if (win != LastWindow)
		{
			/* unlink window from child list */
			if (win->Previous)
			{
				((CUIWINDOW*)win->Previous)->Next = win->Next;
			}
			if (win->Next)
			{
				((CUIWINDOW*)win->Next)->Previous = win->Previous;
			}
			if (win == FirstWindow)
			{
				FirstWindow = win->Next;
			}

			/* add window to the end of the list */
			LastWindow->Next = win;
			win->Previous = LastWindow;
			win->Next = NULL;
			LastWindow = win;

			return TRUE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowGetClientRect
 * Calculate the rectangle of the windows client area with the upper
 * left corner beeing the coordinate origin
 * ---------------------------------------------------------------------
 */
void
WindowGetClientRect(CUIWINDOW* win, CUIRECT* rc)
{
	WindowGetRelWindowRect(win, rc);
	WindowMakeClientRect(win, rc);
	rc->X = 0;
	rc->Y = 0;
}

/* ---------------------------------------------------------------------
 * WindowGetWindowRect
 * Calculate the rectangle of the window in coordinates related to the
 * client area of the parent window
 * ---------------------------------------------------------------------
 */
void
WindowGetWindowRect(CUIWINDOW* win, CUIRECT* rc)
{
	CUIRECT rc_parent;

	if (win->Parent)
	{
		WindowGetWindowRect(win->Parent, &rc_parent);
		WindowMakeClientRect(win->Parent, &rc_parent);
	}
	else
	{
		rc_parent.X = 0;
		rc_parent.Y = 0;
	}

	/* see also GetClientRect */
	if (win->IsMinimized)
	{
		rc->X = 0; rc->Y = 0;
		rc->W = 0; rc->H = 0;
	}
	else if (win->IsMaximized && win->Parent)
	{
		*rc = rc_parent;
		WindowMakeClientRect(win->Parent, rc);
	}
	else
	{
		*rc = win->Position;
		rc->X += rc_parent.X;
		rc->Y += rc_parent.Y;
	}
}

/* ---------------------------------------------------------------------
 * WindowClear
 * Clear the window area from all text data
 * ---------------------------------------------------------------------
 */
void
WindowClear(CUIWINDOW* win, CUIRECT* rc)
{
	int x;
	int y;
	WINDOW* w = win->Win;

	if ((rc->W > 0) && (rc->H > 0))
	{
		for (y = rc->Y; y < (rc->Y + rc->H); y++)
		{
			MOVEYX(w, y, rc->X);
			for (x = rc->X; x < (rc->X + rc->W); x++)
			{
				waddch(w, ' ');
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowUpdate
 * Refresh the screen data. THIS IS NORMALLY CALLED FROM THE FRAMEWORK
 * and only required in some rare cases.
 * ---------------------------------------------------------------------
 */
void
WindowUpdate(void)
{
	CUIWINDOW* win;
	
	WindowUpdateLayout(Desktop->FirstChild);
	
	win = FirstWindow;
	while(win)
	{
		WindowUpdateWindow(win);
		win = (CUIWINDOW*) win->Next;
	}
	if (CursorOn && FocusWindow)
	{
		WindowCursorXY(FocusWindow);
	}
	doupdate();

	ScreenDirty = FALSE;
}

/* ---------------------------------------------------------------------
 * WindowInvalidate
 * Invalidate the given window, causing the window to redraw itself
 * ---------------------------------------------------------------------
 */
void
WindowInvalidate(CUIWINDOW* win)
{
	CUIRECT rc;
	WindowGetRelWindowRect(win, &rc);
	WindowPaintDecoration(win, rc.W, rc.H);

	WindowMakeClientRect(win, &rc);
	WindowPaint(win);
}

/* ---------------------------------------------------------------------
 * WindowInvalidateLayout
 * Mark the given window to have an invalid layout (needs UpdateLayout)
 * ---------------------------------------------------------------------
 */
void 
WindowInvalidateLayout(CUIWINDOW* win)
{
	win->LayoutValid = FALSE;
}

/* ---------------------------------------------------------------------
 * WindowInvalidateScreen
 * Tell the framework, that the screen has to be updated. This only
 * is necessary if there was some direct painting from outside of the
 * paint hook function
 * ---------------------------------------------------------------------
 */
void
WindowInvalidateScreen(void)
{
	ScreenDirty = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowMove
 * Move the window around and resize it if necessary
 * ---------------------------------------------------------------------
 */
int
WindowMove(CUIWINDOW* win, int x, int y, int w, int h)
{
	if (!win->IsMaximized)
	{
		int resize = FALSE;
		if ((w != win->Position.W) || (h != win->Position.H))
		{
			resize = TRUE;
		}
		win->Position.X = x;
		win->Position.Y = y;
		win->Position.W = w;
		win->Position.H = h;
		if (resize)
		{
			WindowResize(win);
		}
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowMaximize
 * Toggle the maximized state of a window
 * ---------------------------------------------------------------------
 */
int
WindowMaximize(CUIWINDOW* win, int state)
{
	if (state == TRUE)
	{
		if (!win->IsMaximized)
		{
			win->IsMaximized = TRUE;
			WindowResize(win);
			return TRUE;
		}
	}
	else
	{
		if (win->IsMaximized)
		{
			win->IsMaximized = FALSE;
			WindowResize(win);
			return TRUE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowMinimize
 * Toggle the minimized state of a window
 * ---------------------------------------------------------------------
 */
int WindowMinimize(CUIWINDOW* win, int state)
{
	if (state == TRUE)
	{
		if (!win->IsMinimized)
		{
			win->IsMinimized = TRUE;

			if (win->Parent == Desktop)
			{
				CUIWINDOW* topwindow = Desktop->FirstChild;
				while (topwindow)
				{
					if (topwindow->Owner == win)
					{
						topwindow->IsHidden = TRUE;
					}
					topwindow = (CUIWINDOW*) topwindow->Next;
				}
			}
			return TRUE;
		}
	}
	else
	{
		if (win->IsMinimized)
		{
			win->IsMinimized = FALSE;

			if (win->Parent == Desktop)
			{
				CUIWINDOW* topwindow = Desktop->FirstChild;
				while (topwindow)
				{
					if (topwindow->Owner == win)
					{
						topwindow->IsHidden = FALSE;
					}
					topwindow = (CUIWINDOW*) topwindow->Next;
				}
			}
			return TRUE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowHide
 * Toggle the hidden state of a window
 * ---------------------------------------------------------------------
 */
void
WindowHide(CUIWINDOW* win, int state)
{
	if (win->IsHidden != state)
	{
		CUIWINDOW* child;

		win->IsHidden = state;
		if (win->IsCreated && (state == FALSE))
		{
			WindowInvalidate(win);
		}

		child = win->FirstChild;
		while (child)
		{
			WindowHide(child, state);
			child = (CUIWINDOW*) child->Next;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowEnable
 * Toggle the enabled state of a window
 * ---------------------------------------------------------------------
 */
void
WindowEnable(CUIWINDOW* win, int state)
{
	if (win->IsEnabled != state)
	{
		CUIWINDOW* child;

		win->IsEnabled = state;
		if (win->IsCreated)
		{
			WindowInvalidate(win);
		}

		child = win->FirstChild;
		while (child)
		{
			WindowEnable(child, state);
			child = (CUIWINDOW*) child->Next;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetFocus
 * Assign the input focus to a window
 * ---------------------------------------------------------------------
 */
void
WindowSetFocus(CUIWINDOW* win)
{
	CUIWINDOW* oldfocus = FocusWindow;
	if (win)
	{
		CUIWINDOW* pwin;
		CUIWINDOW* cwin;

		/* first handle the focus in the normal way */
		FocusWindow = win;
		if (oldfocus && oldfocus->KillFocusHook)
		{
			oldfocus->KillFocusHook(oldfocus);
		}
		if (FocusWindow->SetFocusHook)
		{
			FocusWindow->SetFocusHook(FocusWindow, oldfocus);
		}
		if (CursorOn)
		{
			WindowCursorXY(FocusWindow);
		}

		pwin = FocusWindow->Parent;
		cwin = FocusWindow;
		while (pwin)
		{
			pwin->ActiveChild = cwin;
			cwin = pwin;
			pwin = (CUIWINDOW*) cwin->Parent;
		}

		/* if we don't accept the focus, try to pass it on */
		if (!win->WantsFocus)
		{
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
	}
}

/* ---------------------------------------------------------------------
 * WindowGetFocus
 * Return the window that currently owns the input focus
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
WindowGetFocus(void)
{
	return FocusWindow;
}

/* ---------------------------------------------------------------------
 * WindowSetId
 * Assign an id-number to a window structure
 * ---------------------------------------------------------------------
 */
void
WindowSetId(CUIWINDOW* win, int id)
{
	win->Id = id;
}

/* ---------------------------------------------------------------------
 * WindowGetId
 * Get the Id from the window structure
 * ---------------------------------------------------------------------
 */
int
WindowGetId(CUIWINDOW* win)
{
	return win->Id;
}

/* ---------------------------------------------------------------------
 * WindowGetControl
 * Search the client window tree for a window (control) with the given
 * id number
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
WindowGetCtrl(CUIWINDOW* win, int id)
{
	CUIWINDOW* child = win->FirstChild;
	while (child)
	{
		if (child->Id == id)
		{
			return child;
		}
		if (child->FirstChild)
		{
			CUIWINDOW* result = WindowGetCtrl(child, id);
			if (result)
			{
				return result;
			}
		}
		child = (CUIWINDOW*) child->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * WindowGetHKeyCtrl
 * Search for a control with a matching hot key
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
WindowGetHKeyCtrl(CUIWINDOW* win, int key)
{
	CUIWINDOW* child = win->FirstChild;
	while (child)
	{
		if (key && (child->HotKey == key))
		{
			return child;
		}
		if (child->FirstChild)
		{
			CUIWINDOW* result = WindowGetHKeyCtrl(child, key);
			if (result)
			{
				return result;
			}
		}
		child = (CUIWINDOW*) child->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * WindowGetDestrop
 * Return the reference to the desktop window
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
WindowGetDesktop(void)
{
	return Desktop;
}

/* ---------------------------------------------------------------------
 * WindowCursorOn
 * Make the input cursor visible (at the current coorinates)
 * ---------------------------------------------------------------------
 */
void
WindowCursorOn(void)
{
	curs_set(1);
	CursorOn = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowCursorOff
 * Make the input cursor invisible
 * ---------------------------------------------------------------------
 */
void
WindowCursorOff(void)
{
	curs_set(0);
	CursorOn = FALSE;
}

/* ---------------------------------------------------------------------
 * WindowSetCursor
 * Reposition the input cursor at the relative window coordinates x,y
 * ---------------------------------------------------------------------
 */
void
WindowSetCursor(CUIWINDOW* win, int x, int y)
{
	win->CursorX = x;
	win->CursorY = y;

	if (win == FocusWindow)
	{
		WindowCursorXY(win);
	}
}

/* ---------------------------------------------------------------------
 * WindowPaintCaption
 * Paint the window caption
 * ---------------------------------------------------------------------
 */
void
WindowPaintCaption(CUIWINDOW* win, int size_x)
{
	WINDOW* w = win->Frame;
	int  x, x1, x2;
	wchar_t buffer[256 + 1];
	int  max = 256;
	int  left = 0;
	int  right = 0;
	int  center = 0;
	int  limit;

	x1 = 0;
	x2 = size_x;

	SetColor(w, win->Color.TitleTxtColor, win->Color.TitleBkgndColor, TRUE);
	MOVEYX(w, 0, 0);
	for (x = 0; x < x2; x++)
	{
		waddch(w, ' ');		
	}

	SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	if (win->HasSysMenu)
	{
		MOVEYX(w, 0, x1); PRINT(w, _T("[]"));
		x1 += 2;
	}

	if (win->HasCloseBox)
	{
		if (win->HasMaximizeBox && win->HasMinimizeBox)
		{
			x2 -= 9;
			MOVEYX(w, 0, x2); PRINT(w, _T("[_][H][X]"));
		}
		else if (win->HasMaximizeBox)
		{
			x2 -= 6;
			MOVEYX(w, 0, x2); PRINT(w, _T("[H][X]"));
		}
		else if (win->HasMinimizeBox)
		{
			x2 -= 6;
			MOVEYX(w, 0, x2); PRINT(w, _T("[_][X]"));
		}
		else
		{
			x2 -= 3;
			MOVEYX(w, 0, x2); PRINT(w, _T("[X]"));
		}
	}
	else
	{
		if (win->HasMaximizeBox && win->HasMinimizeBox)
		{
			x2 -= 6;
			MOVEYX(w, 0, x2); PRINT(w, _T("[_][H]"));
		}
		else if (win->HasMaximizeBox)
		{
			x2 -= 3;
			MOVEYX(w, 0, x2); PRINT(w, _T("[H]"));
		}
		else if (win->HasMinimizeBox)
		{
			x2 -= 3;
			MOVEYX(w, 0, x2); PRINT(w, _T("[_]"));
		}
	}

	/* arrange text in the space between x1 and x2 */
	if (max > (x2 - x1))
	{
		max = (x2 - x1);
	}
	limit = max / 3;

	if (win->LText)
	{
		left = wcslen(win->LText);
	}
	if (win->RText)
	{
		right = wcslen(win->RText);
	}
	if (win->Text)
	{
		center = wcslen(win->Text);
	}

	while ((max > 0) && ((left + right + center) >= max))
	{
		if (left >= limit)
		{
			left--;
		}
		if (right >= limit)
		{
			right--;
		}
		if (center >= limit)
		{
			center--;
		}
	}

	/* show title text */
	SetColor(w, win->Color.TitleTxtColor, win->Color.TitleBkgndColor, TRUE);
	if (win->LText)
	{
		wcsncpy(buffer, win->LText, left);
		buffer[left] = 0;
		MOVEYX(w, 0, x1); PRINT(w, buffer);
	}
	if (win->RText)
	{
		wcsncpy(buffer, win->RText, right);
		buffer[right] = 0;
		MOVEYX(w, 0, x1 + max - right); PRINT(w, buffer);
	}
	if (win->Text)
	{
		wcsncpy(buffer, win->Text, center);
		buffer[center] = 0;
		MOVEYX(w, 0, x1 + max / 2 - center / 2); PRINT(w, buffer);
	}
}


/* ---------------------------------------------------------------------
 * WindowPaintStatusBar
 * Paint the window status bar
 * ---------------------------------------------------------------------
 */
void
WindowPaintStatusBar(CUIWINDOW* win, int size_x, int size_y)
{
	WINDOW* w = win->Frame;
	int  y, x, x1, x2;
	wchar_t buffer[256 + 1];
	int  max = 256;
	int  left = 0;
	int  right = 0;
	int  center = 0;
	int  limit;

	x1 = 0;
	x2 = size_x;
	y  = size_y - 1;

	if (y < 0) return;

	SetColor(w, win->Color.StatusTxtColor, win->Color.StatusBkgndColor, TRUE);
	MOVEYX(w, y, 0);
	for (x = 0; x < x2; x++)
	{
		waddch(w, ' ');
	}

	/* arrange text in the space between x1 and x2 */
	if (max > (x2 - x1))
	{
		max = (x2 - x1);
	}
	limit = max / 3;

	if (win->LStatusText)
	{
		left = wcslen(win->LStatusText);
	}
	if (win->RStatusText)
	{
		right = wcslen(win->RStatusText);
	}
	if (win->StatusText)
	{
		center = wcslen(win->StatusText);
	}

	while ((max > 0) && ((left + right + center) >= max))
	{
		if (left >= limit)
		{
			left--;
		}
		if (right >= limit)
		{
			right--;
		}
		if (center >= limit)
		{
			center--;
		}
	}

	/* show status text */
	if (win->LStatusText)
	{
		wcsncpy(buffer, win->LStatusText, left);
		buffer[left] = 0;
		MOVEYX(w, y, x1); PRINT(w, buffer);
	}
	if (win->RStatusText)
	{
		wcsncpy(buffer, win->RStatusText, right);
		buffer[right] = 0;
		MOVEYX(w, y, x1 + max - right); PRINT(w, buffer);
	}
	if (win->StatusText)
	{
		wcsncpy(buffer, win->StatusText, center);
		buffer[center] = 0;
		MOVEYX(w, y, x1 + max / 2 - center / 2); PRINT(w, buffer);
	}
}

/* ---------------------------------------------------------------------
 * WindowPaintVScroll
 * Paint a vertical scroll bar
 * ---------------------------------------------------------------------
 */
void WindowPaintVScroll(CUIWINDOW* win, int y1, int y2)
{
	WINDOW* w = win->Frame;
	int     x = win->Position.W - 1;
	int     y;

	if (win->IsEnabled)
	{
		SetColor(w, win->Color.BorderColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}
	for (y = y1; y <= y2; y++)
	{
		MOVEYX(w, y, x);
		waddch(w, ACS_CKBOARD);
	}

	MOVEYX(w, y1, x); waddch(w, ACS_UARROW);
	MOVEYX(w, y2, x); waddch(w, ACS_DARROW);

	if (win->VScrollBar.Range > 0)
	{
		int h = y2 - y1 - 2;
		if (h > 0)
		{
			int p = (h * win->VScrollBar.Pos) / win->VScrollBar.Range;
			MOVEYX(w, y1 + p + 1, x); waddch(w, ACS_BLOCK);
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowPaintHScroll
 * Paint a horizontal scroll bar
 * ---------------------------------------------------------------------
 */
void WindowPaintHScroll(CUIWINDOW* win, int x1, int x2)
{
	WINDOW* w = win->Frame;
	int     y = win->Position.H - 1;
	int     x;

	if (win->IsEnabled)
	{
		SetColor(w, win->Color.BorderColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	MOVEYX(w, y, x1);
	for (x = x1; x <= x2; x++)
	{
		waddch(w, ACS_CKBOARD);
	}

	MOVEYX(w, y, x1); waddch(w, ACS_LARROW);
	MOVEYX(w, y, x2); waddch(w, ACS_RARROW);

	if (win->HScrollBar.Range > 0)
	{
		int h = x2 - x1 - 2;
		if (h > 0)
		{
			int p = (h * win->HScrollBar.Pos) / win->HScrollBar.Range;
			MOVEYX(w, y, x1 + p + 1); waddch(w, ACS_BLOCK);
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowFocusNext
 * Cause the focus to be passed to the next sibling window
 * ---------------------------------------------------------------------
 */
void
WindowFocusNext(CUIWINDOW* win)
{
	CUIWINDOW* workptr;
	int loopcount = 0;
	int init = FALSE;

	if (!win->ActiveChild)
	{
		win->ActiveChild = win->FirstChild;
		if (!win->ActiveChild)
		{
			return;
		}
		init = TRUE;
	}

	workptr = (CUIWINDOW*) win->ActiveChild;

	FocusMove++; /* move focus down */
	do
	{
		if (workptr && !init)
		{
			 workptr = (CUIWINDOW*) workptr->Next;
		}
		init = FALSE;

		if  (!workptr)
		{
			if (!win->IsPopup && win->Parent && (win->Parent != Desktop))
			{
				WindowFocusNext(win->Parent);
				FocusMove--;
				return;
			}
			else
			{
				loopcount++;
				if (loopcount > 2)
				{
					FocusMove--;
					return;
				}

				workptr = win->FirstChild;
			}
		}

		if (workptr->IsEnabled && !workptr->IsHidden && workptr->WantsFocus)
		{
			WindowSetFocus(workptr);
			FocusMove--;
			return;
		}
	}
	while (workptr);
}

/* ---------------------------------------------------------------------
 * WindowFocusNext
 * Cause the focus to be passed to the previous sibling window
 * ---------------------------------------------------------------------
 */
void
WindowFocusPrevious(CUIWINDOW* win)
{
	CUIWINDOW* workptr;
	int loopcount = 0;
	int init = FALSE;

	if (!win->ActiveChild)
	{
		win->ActiveChild = win->LastChild;
		if (!win->ActiveChild)
		{
			return;
		}
		init = TRUE;
	}

	workptr = (CUIWINDOW*) win->ActiveChild;

	FocusMove--; /* move focus up */
	do
	{
		if (workptr && !init)
		{
			 workptr = (CUIWINDOW*) workptr->Previous;
		}
		init = FALSE;

		if  (!workptr)
		{
			if (!win->IsPopup && win->Parent && (win->Parent != Desktop))
			{
				WindowFocusPrevious(win->Parent);
				FocusMove++;
				return;
			}
			else
			{
				loopcount++;
				if (loopcount > 2)
				{
					FocusMove++;
					return;
				}

				workptr = win->LastChild;
			}
		}

		if (workptr->IsEnabled && !workptr->IsHidden && workptr->WantsFocus)
		{
			WindowSetFocus(workptr);
			FocusMove++;
			return;
		}
	}
	while (workptr);
}


/* ---------------------------------------------------------------------
 * WindowSetCapture
 * Set the mouse capture for the client area of "win"
 * ---------------------------------------------------------------------
 */
void WindowSetCapture(CUIWINDOW* win)
{
	CaptureWindow = win;
	CaptureNcArea = FALSE;
}

/* ---------------------------------------------------------------------
 * WindowSetNcCapture
 * Set the mouse capture for the non client area of "win"
 * ---------------------------------------------------------------------
 */
void WindowSetNcCapture(CUIWINDOW* win)
{
	CaptureWindow = win;
	CaptureNcArea = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowReleaseCapture
 * Release the mouse capture
 * ---------------------------------------------------------------------
 */
void WindowReleaseCapture(void)
{
	CaptureWindow = NULL;
}


/* ---------------------------------------------------------------------
 * WindowEnableVScroll
 * Show or hide vertical scroll bar
 * ---------------------------------------------------------------------
 */
void
WindowEnableVScroll(CUIWINDOW* win, int enable)
{
	if (win->HasVScroll != enable)
	{
		CUIRECT rc1, rc2;
		if (win->IsCreated)
		{
			WindowGetClientRect(win, &rc1);
		}
		win->HasVScroll = enable;
		if (win->IsCreated)
		{
			WindowGetClientRect(win, &rc2);
			if ((rc2.W != rc1.W) || (rc2.H != rc1.H))
			{
				WindowResize(win);
			}
			else
			{
				CUIRECT rc;
				WindowGetRelWindowRect(win, &rc);
				WindowPaintDecoration(win, rc.W, rc.H);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowEnableHScroll
 * Show or hide horizontal scroll bar
 * ---------------------------------------------------------------------
 */
void
WindowEnableHScroll(CUIWINDOW* win, int enable)
{
	if (win->HasHScroll != enable)
	{
		CUIRECT rc1, rc2;
		if (win->IsCreated)
		{
			WindowGetClientRect(win, &rc1);
		}
		win->HasHScroll = enable;
		if (win->IsCreated)
		{
			WindowGetClientRect(win, &rc2);
			if ((rc2.W != rc1.W) || (rc2.H != rc1.H))
			{
				WindowResize(win);
			}
			else
			{
				CUIRECT rc;
				WindowGetRelWindowRect(win, &rc);
				WindowPaintDecoration(win, rc.W, rc.H);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetVScrollRange
 * Set the maximum value for the vertical scroll range (0..range)
 * ---------------------------------------------------------------------
 */
void
WindowSetVScrollRange(CUIWINDOW* win, int range)
{
	if (range != win->VScrollBar.Range)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);

		win->VScrollBar.Range = range;
		if (win->VScrollBar.Pos > range)
		{
			win->VScrollBar.Pos = range;
		}
		if (win->IsCreated && win->HasVScroll)
		{
			WindowPaintDecoration(win, rc.W, rc.H);
			ScreenDirty = TRUE;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetHScrollRange
 * Set the maximum value for the horizontal scroll range (0..range)
 * ---------------------------------------------------------------------
 */
void
WindowSetHScrollRange(CUIWINDOW* win, int range)
{
	if (range != win->HScrollBar.Range)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);

		win->HScrollBar.Range = range;
		if (win->HScrollBar.Pos > range)
		{
			win->HScrollBar.Pos = range;
		}
		if (win->IsCreated && win->HasHScroll)
		{
			WindowPaintDecoration(win, rc.W, rc.H);
			ScreenDirty = TRUE;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetVScrollPos
 * Set the position value for the vertical scroll bar (0..range)
 * ---------------------------------------------------------------------
 */
void
WindowSetVScrollPos(CUIWINDOW* win, int pos)
{
	if (pos != win->VScrollBar.Pos)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);

		win->VScrollBar.Pos = pos;
		if (win->VScrollBar.Pos > win->VScrollBar.Range)
		{
			win->VScrollBar.Pos = win->VScrollBar.Range;
		}
		if (win->IsCreated && win->HasVScroll)
		{
			WindowPaintDecoration(win, rc.W, rc.H);
			ScreenDirty = TRUE;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetHScrollPos
 * Set the position value for the horizontal scroll bar (0..range)
 * ---------------------------------------------------------------------
 */
void
WindowSetHScrollPos(CUIWINDOW* win, int pos)
{
	if (pos != win->HScrollBar.Pos)
	{
		CUIRECT rc;
		WindowGetRelWindowRect(win, &rc);

		win->HScrollBar.Pos = pos;
		if (win->HScrollBar.Pos >= win->HScrollBar.Range)
		{
			win->HScrollBar.Pos = win->HScrollBar.Range;
		}
		if (win->IsCreated && win->HasHScroll)
		{
			WindowPaintDecoration(win, rc.W, rc.H);
			ScreenDirty = TRUE;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowGetVScrollRange
 * Get the maximum value of the vertical scroll bar
 * ---------------------------------------------------------------------
 */
int
WindowGetVScrollRange(CUIWINDOW* win)
{
	return win->VScrollBar.Range;
}

/* ---------------------------------------------------------------------
 * WindowGetHScrollRange
 * Get the maximum value of the horizontal scroll bar
 * ---------------------------------------------------------------------
 */
int
WindowGetHScrollRange(CUIWINDOW* win)
{
	return win->HScrollBar.Range;
}

/* ---------------------------------------------------------------------
 * WindowGetVScrollPos
 * Get the current vertical scroll pos
 * ---------------------------------------------------------------------
 */
int
WindowGetVScrollPos(CUIWINDOW* win)
{
	return win->VScrollBar.Pos;
}

/* ---------------------------------------------------------------------
 * WindowGetHScrollPos
 * Get the current horizontal scroll pos
 * ---------------------------------------------------------------------
 */
int
WindowGetHScrollPos(CUIWINDOW* win)
{
	return win->HScrollBar.Pos;
}

/* ---------------------------------------------------------------------
 * WindowMButtonVScroll
 * Handle mouse button events on vertical scroll bars
 * ---------------------------------------------------------------------
 */
void
WindowMButtonVScroll(CUIWINDOW* win, int y1, int y2, int y, int flags)
{
	CUIRECT rc;
	int thumbpos = -1;

	if (win->VScrollBar.Range > 0)
        {
                int h = y2 - y1 - 2;
                if (h > 0)
                {
                        thumbpos = y1 + (h * win->VScrollBar.Pos) / win->VScrollBar.Range + 1;
                }
        }


	/* Find mouse action for "pressed" and "clicked" events */
	if ((flags == BUTTON1_PRESSED) ||
	    (flags == BUTTON1_CLICKED) ||
	    (flags == BUTTON1_DOUBLE_CLICKED))
	{
		if (y == y1)
		{
			win->MouseAction = MOUSE_VSCROLL_UP;
		}
		else if (y == y2)
		{
			win->MouseAction = MOUSE_VSCROLL_DOWN;
		}
		else if ((y > y1) && (y < thumbpos))
		{
			win->MouseAction = MOUSE_VSCROLL_PGUP;
		}
		else if ((y < y2) && (y > thumbpos))
		{
			win->MouseAction = MOUSE_VSCROLL_PGDOWN;
		}
		else if ((y == thumbpos) && (flags == BUTTON1_PRESSED))
		{
			win->MouseAction = MOUSE_VSCROLL_TRACK;
		}
		else
		{
			win->MouseAction = MOUSE_NO_ACTION;
		}
	}

	/* make sure there is actually no mouse capture set */
	WindowReleaseCapture();

	/* now process "clicked" and "released" events. */
	if ((flags == BUTTON1_CLICKED) ||
	    (flags == BUTTON1_DOUBLE_CLICKED) ||
	    ((flags == BUTTON1_RELEASED) && (win->MouseAction != MOUSE_NO_ACTION)))
	{
		switch(win->MouseAction)
		{
		case MOUSE_VSCROLL_UP:
			if ((y == y1) && (win->VScrollBar.Pos > 0))
			{
				if (win->VScrollHook)
				{
					win->VScrollHook(win, SB_LINEUP, win->VScrollBar.Pos);
				}
				else
				{
					win->VScrollBar.Pos--;
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_VSCROLL_DOWN:
			if ((y == y2) && (win->VScrollBar.Pos < win->VScrollBar.Range))
			{
				if (win->VScrollHook)
				{
					win->VScrollHook(win, SB_LINEDOWN, win->VScrollBar.Pos);
				}
				else
				{
					win->VScrollBar.Pos++;
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_VSCROLL_PGUP:
			if ((y > y1) && (y < thumbpos) && (win->VScrollBar.Pos > 0))
			{
				if (win->VScrollHook)
				{
					win->VScrollHook(win, SB_PAGEUP, win->VScrollBar.Pos);
				}
				else
				{
					WindowGetClientRect(win, &rc);
					win->VScrollBar.Pos -= rc.H;
					if (win->VScrollBar.Pos < 0)
					{
						win->VScrollBar.Pos = 0;
					}
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_VSCROLL_PGDOWN:
			if ((y < y2) && (y > thumbpos) && (win->VScrollBar.Pos < win->VScrollBar.Range))
			{
				if (win->VScrollHook)
				{
					win->VScrollHook(win, SB_PAGEDOWN, win->VScrollBar.Pos);
				}
				else
				{
					WindowGetClientRect(win, &rc);
					win->VScrollBar.Pos += rc.H;
					if (win->VScrollBar.Pos > win->VScrollBar.Range)
					{
						win->VScrollBar.Pos = win->VScrollBar.Range;
					}
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_VSCROLL_TRACK:
			WindowMMoveVScroll(win, y1, y2, y);
			break;
		}
		win->MouseAction = MOUSE_NO_ACTION;
	}
	else if ((flags == BUTTON1_PRESSED) && (win->MouseAction != MOUSE_NO_ACTION))
	{
		WindowSetNcCapture(win);
	}
}

/* ---------------------------------------------------------------------
 * WindowMButtonHScroll
 * Handle mouse button events on horizontal scroll bars
 * ---------------------------------------------------------------------
 */
void
WindowMButtonHScroll(CUIWINDOW* win, int x1, int x2, int x, int flags)
{
	CUIRECT rc;
	int thumbpos = -1;

	if (win->HScrollBar.Range > 0)
	{
		int h = x2 - x1 - 2;
		if (h > 0)
		{
			thumbpos = x1 + (h * win->HScrollBar.Pos) / win->HScrollBar.Range + 1;
		}
	}

	/* Find mouse action for "pressed" and "clicked" events */
	if ((flags == BUTTON1_PRESSED) ||
	    (flags == BUTTON1_CLICKED) ||
	    (flags == BUTTON1_DOUBLE_CLICKED))
	{
		if (x == x1)
		{
			win->MouseAction = MOUSE_HSCROLL_UP;
		}
		else if (x == x2)
		{
			win->MouseAction = MOUSE_HSCROLL_DOWN;
		}
		else if ((x > x1) && (x < thumbpos))
		{
			win->MouseAction = MOUSE_HSCROLL_PGUP;
		}
		else if ((x < x2) && (x > thumbpos))
		{
			win->MouseAction = MOUSE_HSCROLL_PGDOWN;
		}
		else if ((x == thumbpos) && (flags == BUTTON1_PRESSED))
		{
			win->MouseAction = MOUSE_HSCROLL_TRACK;
		}
		else
		{
			win->MouseAction = MOUSE_NO_ACTION;
		}
	}

	/* make sure there is actually no mouse capture set */
	WindowReleaseCapture();

	/* now process "clicked" and "released" events. */
	if ((flags == BUTTON1_CLICKED) ||
	    (flags == BUTTON1_DOUBLE_CLICKED) ||
	    ((flags == BUTTON1_RELEASED) && (win->MouseAction != MOUSE_NO_ACTION)))
	{
		switch(win->MouseAction)
		{
		case MOUSE_HSCROLL_UP:
			if ((x == x1) && (win->HScrollBar.Pos > 0))
			{
				if (win->HScrollHook)
				{
					win->HScrollHook(win, SB_LINEUP, win->HScrollBar.Pos);
				}
				else
				{
					win->HScrollBar.Pos--;
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_HSCROLL_DOWN:
			if ((x == x2) && (win->HScrollBar.Pos < win->HScrollBar.Range))
			{
				if (win->HScrollHook)
				{
					win->HScrollHook(win, SB_LINEDOWN, win->HScrollBar.Pos);
				}
				else
				{
					win->HScrollBar.Pos++;
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_HSCROLL_PGUP:
			if ((x > x1) && (x < thumbpos) && (win->HScrollBar.Pos > 0))
			{
				if (win->HScrollHook)
				{
					win->HScrollHook(win, SB_PAGEUP, win->HScrollBar.Pos);
				}
				else
				{
					WindowGetClientRect(win, &rc);
					win->HScrollBar.Pos -= rc.W;
					if (win->HScrollBar.Pos < 0)
					{
						win->HScrollBar.Pos = 0;
					}
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_HSCROLL_PGDOWN:
			if ((x < x2) && (x > thumbpos) && (win->HScrollBar.Pos < win->HScrollBar.Range))
			{
				if (win->HScrollHook)
				{
					win->HScrollHook(win, SB_PAGEDOWN, win->HScrollBar.Pos);
				}
				else
				{
					WindowGetClientRect(win, &rc);
					win->HScrollBar.Pos += rc.W;
					if (win->HScrollBar.Pos > win->HScrollBar.Range)
					{
						win->HScrollBar.Pos = win->HScrollBar.Range;
					}
					WindowInvalidate(win);
				}
			}
			break;
		case MOUSE_HSCROLL_TRACK:
			WindowMMoveHScroll(win, x1, x2, x);
			break;
		}
		win->MouseAction = MOUSE_NO_ACTION;
		WindowReleaseCapture();
	}
	else if ((flags == BUTTON1_PRESSED) && (win->MouseAction != MOUSE_NO_ACTION))
	{
		WindowSetNcCapture(win);
	}
}

/* ---------------------------------------------------------------------
 * WindowMMoveVScroll
 * Handle mouse move events on vertical scroll bars
 * ---------------------------------------------------------------------
 */
void
WindowMMoveVScroll(CUIWINDOW* win, int y1, int y2, int y)
{
	if (win->MouseAction == MOUSE_VSCROLL_TRACK)
	{
		int thumbpos = y;
		thumbpos = y < (y1 + 1) ? (y1 + 1) : y;
		thumbpos = y > (y2 - 1) ? (y2 - 1) : y;
		win->VScrollBar.Pos = (win->VScrollBar.Range * (thumbpos - (y1 + 1)));
		win->VScrollBar.Pos += (win->VScrollBar.Range / 2);
		win->VScrollBar.Pos /= (y2 - y1 - 2);
		if (win->VScrollBar.Pos > win->VScrollBar.Range)
		{
			win->VScrollBar.Pos = win->VScrollBar.Range;
		}
		if (win->VScrollHook)
		{
			win->VScrollHook(win, SB_THUMBTRACK, win->VScrollBar.Pos);
		}
		else
		{
			WindowInvalidate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowMMoveHScroll
 * Handle mouse move events on horizontal scroll bars
 * ---------------------------------------------------------------------
 */
void
WindowMMoveHScroll(CUIWINDOW* win, int x1, int x2, int x)
{
	if (win->MouseAction == MOUSE_HSCROLL_TRACK)
	{
		int thumbpos = x;
		thumbpos = x < (x1 + 1) ? (x1 + 1) : x;
		thumbpos = x > (x2 - 1) ? (x2 - 1) : x;
		win->HScrollBar.Pos = (win->HScrollBar.Range * (thumbpos - (x1 + 1)));
		win->HScrollBar.Pos += (win->HScrollBar.Range / 2);
		win->HScrollBar.Pos /= (x2 - x1 - 2);
		if (win->HScrollBar.Pos > win->HScrollBar.Range)
		{
			win->HScrollBar.Pos = win->HScrollBar.Range;
		}
		if (win->HScrollHook)
		{
			win->HScrollHook(win, SB_THUMBTRACK, win->HScrollBar.Pos);
		}
		else
		{
			WindowInvalidate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowSetTimer
 * Set a window timer
 * ---------------------------------------------------------------------
 */
void
WindowSetTimer(CUIWINDOW* win, int id, int msec)
{
	CUITIMER* timer = FirstTimer;
	CUITIMER* settimer = NULL;
	while(timer)
	{
		if ((timer->Window == win) && (timer->Id == id))
		{
			settimer = timer;
			break;
		}
		timer = (CUITIMER*) timer->Next;
	}
	if (!settimer)
	{
		settimer = (CUITIMER*) malloc(sizeof(CUITIMER));
		settimer->Next = FirstTimer;
		settimer->Id = id;
		settimer->Window = win;
		FirstTimer = settimer;
	}
	settimer->ReloadValue = msec / KEYDELAY;
	settimer->Value = settimer->ReloadValue;
	settimer->Deleted = FALSE;
}

/* ---------------------------------------------------------------------
 * WindowKillTimer
 * Kill (stop and mark as deleted) a window timer
 * ---------------------------------------------------------------------
 */
void
WindowKillTimer(CUIWINDOW* win, int id)
{
	CUITIMER* timer = FirstTimer;
	while(timer)
	{
		if ((timer->Window == win) && ((timer->Id == id) || (id == -1)))
		{
			timer->Deleted = TRUE;
		}
		timer = (CUITIMER*) timer->Next;
	}
}

/* ---------------------------------------------------------------------
 * InitColor
 * Init color pairs for color mode displays
 * ---------------------------------------------------------------------
 */
void
InitColor(void)
{
	int l_vf, l_hf;
	int i;

	if (has_colors() == TRUE)
	{
		start_color();
		i = 0;
		for (l_vf = COLOR_WHITE; l_vf >= COLOR_BLACK; l_vf--)
		{
			for (l_hf = COLOR_BLACK; l_hf <= COLOR_WHITE; l_hf++)
			{
				if (i != 0)
				{
					init_pair(i,l_vf,l_hf);
				}
				i++;
			}
		}
		init_pair(i, -1, -1);
		ColorMode = TRUE;
	}
}

/* ---------------------------------------------------------------------
 * SetColor
 * Set foreground and background color for a specified window
 * to be used for further text output
 * ---------------------------------------------------------------------
 */
void
SetColor(WINDOW* win, int fcolor, int bcolor, int reverse)
{
	int pair = (7 - (fcolor & 0x07)) * 8 + (bcolor & 0x07);

	if (ColorMode == TRUE)
	{
		if (fcolor > 7)
		{
			wattrset(win,COLOR_PAIR(pair) | A_BOLD);
		}
		else
		{
			wattrset(win,COLOR_PAIR(pair));
		}
	}
	else
	{
		int flags = 0;
		if (reverse == TRUE) flags |= A_REVERSE;
		if (fcolor > 7) flags |= A_BOLD;

		wattrset(win,COLOR_PAIR(0) | flags);
	}
}


/* helper functions */

/* ---------------------------------------------------------------------
 * WindowClearHooks
 * Execute a list of hooks
 * ---------------------------------------------------------------------
 */
static void
WindowClearHooks(CUIHOOK* hooklst)
{
	CUIHOOK* delptr = hooklst;
	while (delptr)
	{
		hooklst = (CUIHOOK*) delptr->Next;
		free(delptr);
		delptr = hooklst;
	}
}

/* ---------------------------------------------------------------------
 * WindowExecHook
 * Execute a list of hooks
 * ---------------------------------------------------------------------
 */
static void
WindowExecHook(CUIWINDOW* win, CUIHOOK* hooklst)
{
	while (hooklst)
	{
		hooklst->HookFunction(win);
		hooklst = (CUIHOOK*) hooklst->Next;
	}
}

/* ---------------------------------------------------------------------
 * WindowCalcIntersection
 * Calculate the intersection of two rectangles
 * ---------------------------------------------------------------------
 */
static void
WindowCalcIntersection(CUIRECT* rc1, CUIRECT* rc2, CUIRECT* rc)
{
	if (rc1->X > rc2->X)
	{
		rc->X = rc1->X;
		if ((rc1->X - rc2->X + rc1->W) > rc2->W)
		{
			rc->W = rc2->W - (rc1->X - rc2->X);
		}
		else
		{
			rc->W = rc1->W;
		}
		if (rc->W < 0)
		{
			rc->W = 0;
		}
	}
	else
	{
		rc->X = rc2->X;
		if ((rc2->X - rc1->X + rc2->W) > rc1->W)
		{
			rc->W = rc1->W - (rc2->X - rc1->X);
		}
		else
		{
			rc->W = rc2->W;
		}
		if (rc->W < 0)
		{
			rc->W = 0;
		}
	}
	if (rc1->Y > rc2->Y)
	{
		rc->Y = rc1->Y;
		if ((rc1->Y - rc2->Y + rc1->H) > rc2->H)
		{
			rc->H = rc2->H - (rc1->Y - rc2->Y);
		}
		else
		{
			rc->H = rc1->H;
		}
		if (rc->H < 0)
		{
			rc->H = 0;
		}
	}
	else
	{
		rc->Y = rc2->Y;
		if ((rc2->Y - rc1->Y + rc2->H) > rc1->H)
		{
			rc->H = rc1->H - (rc2->Y - rc1->Y);
		}
		else
		{
			rc->H = rc2->H;
		}
		if (rc->H < 0)
		{
			rc->H = 0;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowPaintTitleText
 * Write title text for windows with frames but without caption
 * ---------------------------------------------------------------------
 */
static void
WindowPaintTitleText1(CUIWINDOW* win, int width)
{
	WINDOW* w = win->Frame;
	if ((width > 6) && (win->Text))
	{
		int len = wcslen(win->Text);
		int x1;

		if (len > (width - 4))
		{
			len = width - 4;
		}

		x1 = (width - len - 4) / 2;

		MOVEYX(w, 0, x1);           PRINT(w, _T("[ "));
		MOVEYX(w, 0, x1 + len + 2); PRINT(w, _T(" ]"));
		MOVEYX(w, 0, x1 + 2);       PRINTN(w, win->Text, len);
	}
}

/* ---------------------------------------------------------------------
 * WindowPaint
 * (Re)paint the window's decoration and client area
 * ---------------------------------------------------------------------
 */
static void
WindowPaint(CUIWINDOW* win)
{
	CUIRECT rc;
	WindowGetClientRect(win, &rc);
	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}
	WindowClear(win, &rc);

	if (win->PaintHook)
	{
		win->PaintHook(win);
	}
	ScreenDirty = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowPaintDecoration
 * Paint the window's decoration
 * ---------------------------------------------------------------------
 */
static void
WindowPaintDecoration(CUIWINDOW* win, int size_x, int size_y)
{
	CUIRECT rc;
	WindowGetClientRect(win, &rc);
	if (win->IsEnabled)
	{
		SetColor(win->Frame, win->Color.BorderColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Frame, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	/* if the window paints it's frame, call NcPaintHook */
	if (win->NcPaintHook)
	{
		win->NcPaintHook(win, size_x, size_y);
		ScreenDirty = TRUE;
		return;
	}

	/* else draw default decoration */
	if (win->HasBorder)
	{
		box(win->Frame, 0, 0);

		if (!win->HasCaption && win->Text)
		{
			WindowPaintTitleText1(win, size_x);
		}

		if (win->HasVScroll || win->HasHScroll)
		{
			int y1 = 1;
			int y2 = size_y - 2;
			int x1 = 1;
			int x2 = size_x - 2;

			if (win->HasMenu)
			{
				y1++;
			}

			if (win->HasVScroll)
			{
				WindowPaintVScroll(win, y1, y2);
			}
			if (win->HasHScroll)
			{
				WindowPaintHScroll(win, x1, x2);
			}
		}
	}
	else
	{
		if (win->HasVScroll || win->HasHScroll)
		{
			int y1 = 0;
			int y2 = size_y - 1;
			int x1 = 0;
			int x2 = size_x - 1;

			if (win->HasMenu)
			{
				y1++;
			}
			if (win->HasCaption)
			{
				y1++;
			}

			if (win->HasVScroll && win->HasHScroll)
			{
				WindowPaintVScroll(win, y1, y2 - 1);
				WindowPaintHScroll(win, x1, x2 - 1);
			}
			else if (win->HasVScroll)
			{
				WindowPaintVScroll(win, y1, y2);
			}
			else if (win->HasHScroll)
			{
				WindowPaintHScroll(win, x1, x2);
			}
		}
	}
	if (win->HasCaption)
	{
		WindowPaintCaption(win, size_x);
	}
	if (win->HasStatusBar)
	{
		WindowPaintStatusBar(win, size_x, size_y);
	}
	ScreenDirty = TRUE;
}

/* ---------------------------------------------------------------------
 * WindowActivate
 * Activate a popup window
 * ---------------------------------------------------------------------
 */
static int
WindowActivate(CUIWINDOW* win)
{
	int result = FALSE;
	while (win)
	{
		if (win->IsPopup)
		{
			if (WindowToTop(win))
			{
				result = TRUE;
			}
		}
		win = (CUIWINDOW*) win->Parent;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * WindowFindXY
 * Find the window matching screen coordinates x,y (recursive search)
 * rcw  : Rectangle of the found window (out)
 * rcp  : Parent window's client area (in)
 * rc   : visible area (not masked out by a parent window) (in)
 * ---------------------------------------------------------------------
 */
static CUIWINDOW*
WindowFindXY(CUIWINDOW* win, CUIPOINT* pt, CUIRECT* rcw, CUIRECT* rc, CUIRECT* rcp)
{
	CUIRECT  rcf;
	CUIRECT  rcc;
	CUIRECT  vrcf;
	CUIRECT  vrcc;
	CUIWINDOW* cwin = win->LastChild;
	CUIWINDOW* result;

	/* first calculate the new visible rectangle seen by
           client windows. This is the intersection between
           the parent's visible rectangle and the client area of
           win */
	if (win->IsMaximized && win->Parent)
        {
                rcf = *rcp;
                WindowMakeClientRect(win->Parent, &rcf);
        }
	else
	{
		rcf = win->Position;
		rcf.X += rcp->X;
		rcf.Y += rcp->Y;
	}

	rcc = rcf;
	WindowMakeClientRect(win, &rcc);
	WindowCalcIntersection(rc, &rcf, &vrcf);
	vrcc = vrcf;
	if ((rcf.W != rcc.W) || (rcf.H != rcc.H))
	{
		WindowCalcIntersection(rc, &rcc, &vrcc);
	}

	/* now we first look if a client window matches the
           given coordinates. If so, we simple return the
           result of the recursive function call... */
	while (cwin)
	{
		result = WindowFindXY(cwin, pt, rcw, &vrcc, &rcc);
		if (result)
		{
			return result;
		}
		cwin = (CUIWINDOW*) cwin->Previous;
	}

	/* ... if not, we check, if the coordinates match into
           the visible area of this window. Depending of the result
           we return the window itself of a NULL pointer. By
           the way we store the window-rect of the action window
           within "rcw" for later usage. */
	if ((pt->X >= vrcf.X) && (pt->X < vrcf.X + vrcf.W) &&
	    (pt->Y >= vrcf.Y) && (pt->Y < vrcf.Y + vrcf.H))
	{
		if (win->IsEnabled && !win->IsHidden && !win->IsMinimized)
		{
			*rcw = rcf;
			return win;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * WindowGetWindowXY
 * Find the window matching screen coordinates x,y
 * ---------------------------------------------------------------------
 */
static CUIWINDOW*
WindowGetWindowXY(CUIWINDOW* basewin, CUIPOINT* pt, CUIRECT* rcw)
{
	CUIRECT    rc = {0, 0, COLS, LINES};
	CUIRECT    rcc = {0, 0, COLS, LINES};
	CUIWINDOW* result = NULL;

	CUIWINDOW* win = Desktop->LastChild;
	while (win)
	{
		result = WindowFindXY(win, pt, rcw, &rc, &rcc);
		if (result)
		{
			break;
		}
		win = (CUIWINDOW*) win->Previous;
	}

	/* now check, if the found window is related to the
           base window (following parent and owner references) */
	if (result)
	{
		CUIWINDOW* checkwnd = result;
		while(checkwnd && (checkwnd != basewin))
		{
			if (checkwnd->IsPopup)
			{
				checkwnd = (CUIWINDOW*) checkwnd->Owner;
			}
			else
			{
				checkwnd = (CUIWINDOW*) checkwnd->Parent;
			}
		}
		if (!checkwnd)
		{
			result = NULL;
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * WindowMouse
 * Handle Mouse input (under construction)
 * ---------------------------------------------------------------------
 */
static void
WindowMouse(CUIWINDOW* basewin)
{
	MEVENT event;
	CUIRECT rcw;
	int nc_event = FALSE;

	if (getmouse(&event) == OK)
	{
		CUIWINDOW* win = CaptureWindow;
		if (win)
		{
			WindowGetWindowRect(win, &rcw);
			if (CaptureNcArea)
			{
				nc_event = TRUE;
			}
			else
			{
				WindowMakeClientRect(win, &rcw);
			}
			event.x -= rcw.X;
			event.y -= rcw.Y;
		}
		else
		{
			CUIRECT  rcc;
			CUIPOINT pt = { event.x, event.y };
			win = WindowGetWindowXY(basewin, &pt, &rcw);
			if (win)
			{
				rcc = rcw;
				WindowMakeClientRect(win, &rcc);
				if ((event.x >= rcc.X) && (event.x < rcc.X + rcc.W) &&
				    (event.y >= rcc.Y) && (event.y < rcc.Y + rcc.H))
				{
					event.x -= rcc.X;
					event.y -= rcc.Y;
				}
				else
				{
					nc_event = TRUE;
					event.x -= rcw.X;
					event.y -= rcw.Y;
				}
			}
		}

		if (win)
		{
			if (event.bstate != 0)
			{
				if (WindowActivate(win))
				{
					WindowUpdate();
				}
				if (FocusWindow != win)
				{
					WindowSetFocus(win);
				}
				if (!nc_event) /* nur wenn Hit-Code = Client_Area */
				{
					if (win->MButtonHook)
					{
						win->MButtonHook(win, event.x, event.y, event.bstate);
					}
				}
				else if (win->MButtonNcHook)
				{
					win->MButtonNcHook(win, event.x, event.y, event.bstate, rcw.W, rcw.H);
				}
				else
				{
					WindowMButtonNc(win, event.x, event.y, event.bstate, rcw.W, rcw.H);
				}
			}
			else
			{
				if (!nc_event)
				{
					if (win->MMoveHook)
					{
						win->MMoveHook(win, event.x, event.y);
					}
				}
				else if (win->MMoveNcHook)
				{
					win->MMoveNcHook(win, event.x, event.y, rcw.W, rcw.H);
				}
				else
				{
					WindowMMoveNc(win, event.x, event.y, rcw.W, rcw.H);
				}
			}
		}
		else
		{
			flash();
			beep();
		}
	}
}


/* ---------------------------------------------------------------------
 * WindowMButtonNc
 * Standard non client mouse handling
 * ---------------------------------------------------------------------
 */
static void
WindowMButtonNc(CUIWINDOW* win, int x, int y, int flags, int size_x, int size_y)
{
	if ((flags == BUTTON1_PRESSED) || (flags == BUTTON1_CLICKED) ||
	    (flags == BUTTON1_DOUBLE_CLICKED) || (flags == BUTTON1_RELEASED))
	{
		if (win->HasBorder)
		{
			if ((win->MouseAction == MOUSE_WINDOW_MOVE) &&
			    (flags == BUTTON1_RELEASED))
			{
				CUIRECT rc;
				WindowGetWindowRect(win, &rc);
				rc.X += (x - win->MouseSpot.X);
				rc.Y += (y - win->MouseSpot.Y);
				WindowMove(win, rc.X, rc.Y, rc.W, rc.H);
				win->MouseAction = MOUSE_NO_ACTION;
				WindowInvalidateScreen();
				WindowReleaseCapture();
			}
			else if (win->HasVScroll || win->HasHScroll)
			{
				int y1 = 1;
				int y2 = size_y - 2;
				int x1 = 1;
				int x2 = size_x - 2;

				if (win->HasMenu)
				{
					y1++;
				}

				if (win->HasVScroll)
				{
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_VSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_VSCROLL_TRACK)) ||
					    (((x + 1) == size_x) && (y >= y1) && (y <= y2)))
					{
						WindowMButtonVScroll(win, y1, y2, y, flags);
						return;
					}
				}
				if (win->HasHScroll)
				{
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_HSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_HSCROLL_TRACK)) ||
					    (((y + 1) == size_y) && (x >= x1) && (x <= x2)))
					{
						WindowMButtonHScroll(win, x1, x2, x, flags);
						return;
					}
				}
			}
			if ((flags == BUTTON1_PRESSED) && (win->IsPopup) && (!win->IsMaximized))
			{
				win->MouseSpot.X = x;
				win->MouseSpot.Y = y;
				win->MouseAction = MOUSE_WINDOW_MOVE;
				WindowSetNcCapture(win);
			}
		}
		else
		{
			if (win->HasVScroll || win->HasHScroll)
			{
				int y1 = 0;
				int y2 = size_y - 1;
				int x1 = 0;
				int x2 = size_x - 1;

				if (win->HasMenu)
				{
					y1++;
				}
				if (win->HasCaption)
				{
					y1++;
				}

				if (win->HasVScroll && win->HasHScroll)
				{
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_VSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_VSCROLL_TRACK)) ||
					    (((x + 1) == size_x) && (y >= y1) && (y <= (y2 - 1))))
					{
						WindowMButtonVScroll(win, y1, y2 - 1, y, flags);
					}
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_HSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_HSCROLL_TRACK)) ||
					    (((y + 1) == size_y) && (x >= x1) && (x <= (x2 - 1))))
					{
						WindowMButtonHScroll(win, x1, x2 - 1, y, flags);
					}
				}
				else if (win->HasVScroll)
				{
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_VSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_VSCROLL_TRACK)) ||
					    (((x + 1) == size_x) && (y >= y1) && (y <= y2)))
					{
						WindowMButtonVScroll(win, y1, y2, y, flags);
					}
				}
				else if (win->HasHScroll)
				{
					if (((flags == BUTTON1_RELEASED) &&
					     (win->MouseAction >= MOUSE_HSCROLL_UP) &&
					     (win->MouseAction <= MOUSE_HSCROLL_TRACK)) ||
					    (((y + 1) == size_y) && (x >= x1) && (x <= x2)))
					{
						WindowMButtonHScroll(win, x1, x2, x, flags);
					}
				}
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * WindowMMoveNc
 * Standard non client mouse handling
 * ---------------------------------------------------------------------
 */
static void
WindowMMoveNc(CUIWINDOW* win, int x, int y, int size_x, int size_y)
{
	if (win->HasBorder)
	{
		if (win->MouseAction == MOUSE_WINDOW_MOVE)
		{
			CUIRECT rc;
			WindowGetWindowRect(win, &rc);
			rc.X += (x - win->MouseSpot.X);
			rc.Y += (y - win->MouseSpot.Y);
			WindowMove(win, rc.X, rc.Y, rc.W, rc.H);
			win->MouseSpot.X = x;
			win->MouseSpot.Y = y;
			WindowInvalidateScreen();
		}
		else if (win->HasVScroll || win->HasHScroll)
		{
			int y1 = 1;
			int y2 = size_y - 2;
			int x1 = 1;
			int x2 = size_x - 2;

			if (win->HasMenu)
			{
				y1++;
			}

			if (win->HasVScroll)
			{
				if (win->MouseAction == MOUSE_VSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, y1, y2, y);
					return;
				}
			}
			if (win->HasHScroll)
			{
				if (win->MouseAction == MOUSE_HSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, x1, x2, x);
					return;
				}
			}
		}
	}
	else
	{
		if (win->HasVScroll || win->HasHScroll)
		{
			int y1 = 0;
			int y2 = size_y - 1;
			int x1 = 0;
			int x2 = size_x - 1;

			if (win->HasMenu)
			{
				y1++;
			}
			if (win->HasCaption)
			{
				y1++;
			}

			if (win->HasVScroll && win->HasHScroll)
			{
				if (win->MouseAction == MOUSE_VSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, y1, y2 - 1, y);
					return;
				}
				if (win->MouseAction == MOUSE_HSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, x1, x2 - 1, x);
					return;
				}
			}
			else if (win->HasVScroll)
			{
				if (win->MouseAction == MOUSE_VSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, y1, y2, y);
					return;
				}
			}
			else if (win->HasHScroll)
			{
				if (win->MouseAction == MOUSE_HSCROLL_TRACK)
				{
					WindowMMoveVScroll(win, x1, x2, x);
					return;
				}
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * WindowMakeClientRect
 * rc is the frame window in absolute coordinates
 * now we make a client window out of it
 * ---------------------------------------------------------------------
 */
static void
WindowMakeClientRect(CUIWINDOW* win, CUIRECT* rc)
{
	if (win->HasBorder)
	{
		if (win->HasMenu)
		{
			rc->X += 1;
			rc->Y += 2;
			rc->W -= 2;
			rc->H -= 3;
		}
		else
		{
			rc->X += 1;
			rc->Y += 1;
			rc->W -= 2;
			rc->H -= 2;
		}
	}
	else
	{
		if (win->HasVScroll)
		{
			rc->W -= 1;
		}
		if (win->HasHScroll)
		{
			rc->H -= 1;
		}
		if (win->HasCaption)
		{
			rc->H -= 1;
			rc->Y += 1;
		}
		if (win->HasStatusBar && !win->HasHScroll)
		{
			rc->H -= 1;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowGetVisibleRect
 * rc already is a rect in absolute coordinates
 * now we want to deliver the visible part
 * ---------------------------------------------------------------------
 */
static void
WindowGetVisibleRect(CUIWINDOW* win, CUIRECT* vrc, CUIRECT* tmprc)
{
	CUIRECT rc_parent;
	CUIRECT rc_sect;

	if (win->Parent)
	{
		WindowGetVisibleRect(win->Parent, vrc, tmprc);
	}
	else
	{
		rc_parent.X = 0;
		rc_parent.Y = 0;
		rc_parent.W = COLS;
		rc_parent.H = LINES;
		*tmprc = rc_parent;
	}

	if (win->IsMaximized)
	{
		rc_parent = *tmprc;
	}
	else
	{
		rc_parent = win->Position;
		rc_parent.X += tmprc->X;
		rc_parent.Y += tmprc->Y;
	}

	WindowMakeClientRect(win, &rc_parent);
	WindowCalcIntersection(vrc, &rc_parent, &rc_sect);
	*tmprc = rc_parent;

	*vrc = rc_sect;
}

/* ---------------------------------------------------------------------
 * WindowUpdateLayout
 * check if a window needs to recalculate it's layout
 * ---------------------------------------------------------------------
 */
static void
WindowUpdateLayout(CUIWINDOW* win)
{
	while (win)
	{
		if (win->FirstChild)
		{
			WindowUpdateLayout(win->FirstChild);
		}
		if (win->LayoutValid == FALSE)
		{
			if (win->LayoutHook)
			{
				win->LayoutHook(win);
			}
			win->LayoutValid = TRUE;
		}
		win = (CUIWINDOW*) win->Next;
	}
}

/* ---------------------------------------------------------------------
 * WindowUpdateWindow
 * recursive window update routine. Copies the visual parts of the
 * windows (curses pads) onto the screen (newscr) and draws a shadow
 * around popup windows. This is the magic part of libcui.
 * ---------------------------------------------------------------------
 */
static void
WindowUpdateWindow(CUIWINDOW* win)
{
	CUIWINDOW* child = win->FirstChild;
	CUIRECT rcf;
	CUIRECT rcc;
	CUIRECT vrcf;
	CUIRECT vrcc;
	CUIRECT tmprc;

	if (win->IsHidden)
	{
		return;
	}

	WindowGetWindowRect(win, &rcf);
	rcc = rcf;
	WindowMakeClientRect(win, &rcc);

	if (win->Parent)
	{
		vrcf = rcf;
		WindowGetVisibleRect(win->Parent, &vrcf, &tmprc);
		vrcc = rcc;
		if ((rcc.W != rcf.W) || (rcc.H != rcf.H))
		{
			WindowGetVisibleRect(win->Parent, &vrcc, &tmprc);
		}
		else
		{
			vrcc = vrcf;
		}
	}
	else
	{
		vrcf = rcf;
		vrcc = rcc;
	}

	if ((rcc.W > 0) && (rcc.H > 0))
	{
		int x, y;

		if ((rcc.W != rcf.W) || (rcc.H != rcf.H))
		{
			pnoutrefresh(
				win->Frame,
				vrcf.Y - rcf.Y,
				vrcf.X - rcf.X,
				vrcf.Y,
				vrcf.X,
				vrcf.Y + vrcf.H - 1,
				vrcf.X + vrcf.W - 1
				);
		}
		pnoutrefresh(
			win->Win,
			vrcc.Y - rcc.Y,
			vrcc.X - rcc.X,
			vrcc.Y,
			vrcc.X,
			vrcc.Y + vrcc.H - 1,
			vrcc.X + vrcc.W - 1
			);

		if (win->IsPopup)
		{
			CUIRECT rcs = rcf;
			CUIRECT vrcs;
			rcs.X += 2;
			rcs.Y += 1;
			vrcs = rcs;

			SetColor(newscr,DARKGRAY,BLACK,FALSE);

			if (win->Parent)
			{
				WindowGetVisibleRect(win->Parent, &vrcs, &tmprc);
			}

			/* vertical shadow */
			if ((vrcs.Y + vrcs.H == rcs.Y + rcs.H) && (vrcs.W > 0))
			{
				for (x = vrcs.X; x < vrcs.X + vrcs.W; x++)
				{
					chtype ch;

					ch = mvwinch(newscr, vrcs.Y + vrcs.H - 1, x);
					ch = ch & (A_CHARTEXT | (A_ATTRIBUTES & ~A_COLOR));
					mvwaddch(newscr, vrcs.Y + vrcs.H - 1, x, ch);
				}
			}

			/* horizontal shadow */
			if ((vrcs.X + vrcs.W >= (rcs.X + rcs.W - 1)) && (vrcs.H > 0))
			{
				for (y = vrcs.Y; y < vrcs.Y + vrcs.H; y++)
				{
					chtype ch;

					ch = mvwinch(newscr, y, vrcs.X + vrcs.W - 2);
					ch = ch & (A_CHARTEXT | (A_ATTRIBUTES & ~A_COLOR));
					mvwaddch(newscr, y, vrcs.X + vrcs.W - 2, ch);
				}
			}
			if ((vrcs.X + vrcs.W == rcs.X + rcs.W) && (vrcs.H > 0))
			{
				for (y = vrcs.Y; y < vrcs.Y + vrcs.H; y++)
				{
					chtype ch;

					ch = mvwinch(newscr, y, vrcs.X + vrcs.W - 1);
					ch = ch & (A_CHARTEXT | (A_ATTRIBUTES & ~A_COLOR));
					mvwaddch(newscr, y, vrcs.X + vrcs.W - 1, ch);
				}
			}
		}

		while(child)
		{
			WindowUpdateWindow(child);
			child = (CUIWINDOW*) child->Next;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowResize
 * Resize a window be reallocating the curses pads and redrawing the
 * window
 * ---------------------------------------------------------------------
 */
static void
WindowResize(CUIWINDOW* win)
{
	delwin(win->Win);
	delwin(win->Frame);

	if (win->IsMaximized && win->Parent)
	{
		CUIRECT rc = ((CUIWINDOW*)win->Parent)->Position;
		WindowMakeClientRect(win->Parent, &rc);
		win->Win = newpad(rc.H, rc.W);
		win->Frame = newpad(rc.H, rc.W);

		WindowPaintDecoration(win, rc.W, rc.H);
	}
	else
	{
		win->Win = newpad(win->Position.H, win->Position.W);
		win->Frame = newpad(win->Position.H, win->Position.W);

		WindowPaintDecoration(win, win->Position.W, win->Position.H);
	}
	WindowExecSizeHook(win);
	WindowPaint(win);
}

/* ---------------------------------------------------------------------
 * WindowCursorXY
 * Transform relative coordinates into screen coordinates and move
 * the cursor to this coordinates
 * ---------------------------------------------------------------------
 */
static void
WindowCursorXY(CUIWINDOW* win)
{
	CUIRECT rc;
	WindowGetWindowRect(win, &rc);
	WindowMakeClientRect(win, &rc);
	wmove(stdscr, rc.Y + win->CursorY, rc.X + win->CursorX);
}

/* ---------------------------------------------------------------------
 * WindowGetDefaultOk
 * Find the client window with the CWS_DEFOK style (normally a button
 * control)
 * ---------------------------------------------------------------------
 */
static CUIWINDOW*
WindowGetDefaultOk(CUIWINDOW* basewnd)
{
	CUIWINDOW* child = (CUIWINDOW*) basewnd->FirstChild;
	CUIWINDOW* tmp;
	while (child)
	{
		/* First check, if this ist the default control */
		if (child->IsDefOk)
		{
			return child;
		}

		/* now check if one of the client windows is the
                   default control */
		tmp = WindowGetDefaultOk(child);
		if (tmp)
		{
			return tmp;
		}

		/* next child */
		child = (CUIWINDOW*) child->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * WindowGetDefaultCancel
 * Find the client window with the CWS_DEFCANCEL style (normally a button
 * control)
 * ---------------------------------------------------------------------
 */
static CUIWINDOW*
WindowGetDefaultCancel(CUIWINDOW* basewnd)
{
	CUIWINDOW* child = (CUIWINDOW*) basewnd->FirstChild;
	CUIWINDOW* tmp;
	while (child)
	{
		/* First check, if this ist the default control */
		if (child->IsDefCancel)
		{
			return child;
		}

		/* now check if one of the client windows is the
                   default control */
		tmp = WindowGetDefaultCancel(child);
		if (tmp)
		{
			return tmp;
		}

		/* next child */
		child = (CUIWINDOW*) child->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * WindowUpdateTimers
 * Run through all timers and update the values. If a timer has expired
 * the windows timer hook is executed
 * ---------------------------------------------------------------------
 */
static void
WindowUpdateTimers(void)
{
	CUITIMER* timer = FirstTimer;
	CUITIMER* previous = NULL;

	/* first check if deleted timers exist */
	while(timer)
	{
		if (timer->Deleted)
		{
			if (previous)
			{
				previous->Next = timer->Next;
				free(timer);
				timer = previous->Next;
			}
			else
			{
				FirstTimer = timer->Next;
				free(timer);
				timer = FirstTimer;
			}
		}
		else
		{
			previous = timer;
			timer = (CUITIMER*) timer->Next;
		}
	}

	/* now execute timer hooks */
	timer = FirstTimer;
	while(timer)
	{
		timer->Value--;
		if (timer->Value <= 0)
		{
			timer->Value = timer->ReloadValue;
			if (timer->Window && timer->Window->TimerHook)
			{
				timer->Window->TimerHook(timer->Window, timer->Id);
			}
		}
		timer = (CUITIMER*) timer->Next;
	}
}

/* ---------------------------------------------------------------------
 * WindowExecSizeHook
 * Exit the windows size hook or perform default behaviour
 * ---------------------------------------------------------------------
 */
static void
WindowExecSizeHook(CUIWINDOW* win)
{
	int def = TRUE;

	if (win->SizeHook)
	{
		if (win->SizeHook(win)) def = FALSE;
	}
	if (def)
	{
		CUIWINDOW* child;
		CUIRECT rc;

		WindowGetClientRect(win, &rc);

		child = win->FirstChild;
		while (child)
		{
			if (child->IsMaximized)
			{
				WindowResize(child);
			}
			else if (child->IsCentered && child->IsPopup)
			{
				WindowMove(child,
					(COLS - child->Position.W) / 2,
					(LINES - child->Position.H) / 2,
					child->Position.W,
					child->Position.H);
			}

			child = (CUIWINDOW*) child->Next;
		}
	}
}

/* ---------------------------------------------------------------------
 * WindowExecSizeHook
 * Exit the windows size hook or perform default behaviour
 * ---------------------------------------------------------------------
 */
static int
WindowExecKeyHook(CUIWINDOW* win, int key)
{
	if (win->KeyHook)
	{
		if (win->KeyHook(win, key))
		{
			return TRUE;
		}

		if (win->Parent && !win->IsPopup)
		{
			return WindowExecKeyHook(win->Parent, key);
		}
	}

	/* default handling */
	if (key == KEY_TAB)
	{
		WindowFocusNext(win);
		return TRUE;
	}
	else if (key == KEY_BTAB)
	{
		WindowFocusPrevious(win);
		return TRUE;
	}
	else if ((key == KEY_RIGHT)||(key == KEY_DOWN))
	{
		WindowFocusNext(win);
		return TRUE;
	}
	else if ((key == KEY_LEFT)||(key == KEY_UP))
	{
		WindowFocusPrevious(win);
		return TRUE;
	}
	else if (win->IsPopup) /* look if key is a hot key */
	{
		CUIWINDOW* ctrl = WindowGetHKeyCtrl(win, key);
		if (ctrl && ctrl->WantsFocus && ctrl->IsEnabled &&
		   !ctrl->IsHidden && !ctrl->IsMinimized)
		{
			WindowSetFocus(ctrl);
			if (ctrl->KeyHook)
			{
				return ctrl->KeyHook(ctrl, key);
			}
			return TRUE;
		}
		return FALSE;
	}
	else if (!win->KeyHook)
	{
		return WindowExecKeyHook(win->Parent, key);
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * WindowGetRelWindowRect
 * Calculate the windows rectangle without absolute x and y coordinates
 * ---------------------------------------------------------------------
 */
static void
WindowGetRelWindowRect(CUIWINDOW* win, CUIRECT* rc)
{
	/* See also GetWindowRect */
	if (win == Desktop)
	{
		*rc = Desktop->Position;
	}
	else
	{
		if (win->IsMaximized && win->Parent)
		{
			WindowGetClientRect(win->Parent, rc);
		}
		else
		{
			*rc = win->Position;
		}
	}
	rc->X = 0;
	rc->Y = 0;
}

/* ---------------------------------------------------------------------
 * WindowResizeHandler
 * If the terminal is resized, the resize flag is set, so that the
 * GetKey routine causes the terminal and all windows to resize
 * ---------------------------------------------------------------------
 */
static void
WindowResizeHandler (int sig)
{
	CUI_USE_ARG(sig);
	
	Resize = TRUE;
	(void) signal(SIGWINCH, WindowResizeHandler);    /* some systems need this */
}

/* ---------------------------------------------------------------------
 * WindowSigHandler
 * Handle signals that notify us about state changes done by job-control
 * CTRL+Z or fg / bg done on the command line.
 * ---------------------------------------------------------------------
 */
static void
WindowSigHandler (int sig)
{
	if (sig == SIGCONT)
	{
		sigaction( SIGTTIN, &SignalAction, NULL );
		sigaction( SIGTTOU, &SignalAction, NULL );
		sigaction( SIGTSTP, &SignalAction, NULL );
		reset_prog_mode();
		refresh();
	}
	else
	{
		sigaction( sig, &OldAction, NULL );
		refresh();                          /* flush curses output */
		endwin();                           /* end curses          */
		printf("\033[%i;0H", LINES);        /* set cursor          */
		fflush(stdout);                     /* flush output        */
		kill( getpid(), sig );              /* send sigtstp        */
	}
}  

/* ---------------------------------------------------------------------
 * GetKey
 * Read a key from the console (and handle screen resize events)
 * ---------------------------------------------------------------------
 */
static int
GetKey(int* key)
{
	wint_t c;
	int result = get_wch(&c);
	if ((result == KEY_CODE_YES) || (result == OK))
	{
		*key = (int) c;
		return TRUE;
	}
	else
	{
		if (Resize)
		{
			struct winsize size;

			if (ioctl(fileno(stdout), TIOCGWINSZ, &size) == 0)
			{
				resizeterm(size.ws_row, size.ws_col);
				wrefresh(curscr);   /* Linux needs this */
			}
			Resize = FALSE;
		}
		return FALSE;
	}
}



