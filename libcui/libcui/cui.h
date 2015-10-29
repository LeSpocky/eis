/* ---------------------------------------------------------------------
 * File: cui.h
 * (Header file for libcui - a library for curses user interfaces
 * with windows)
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

#ifndef CUI_H
#define CUI_H

#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "cui-char.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#define CUI_USE_ARG(a) (a) = (a)

struct _win_st;

typedef struct _win_st WINDOW;

/* ---------------------------------------------------------------------
 * color constants
 * ---------------------------------------------------------------------
 */
 
enum
{
	/* foreground and background */
	BLACK            =  0,
	RED              =  1,
	GREEN            =  2,
	BROWN            =  3,
	BLUE             =  4,
	MAGENTA          =  5,
	CYAN             =  6,
	LIGHTGRAY        =  7,

	/* foreground only */
	DARKGRAY         =  8,
	LIGHTRED         =  9,
	LIGHTGREEN       = 10,
	YELLOW           = 11,
	LIGHTBLUE        = 12,
	LIGHTMAGENTA     = 13,
	LIGHTCYAN        = 14,
	WHITE            = 15,
};

/* ---------------------------------------------------------------------
 * window styles
 * ---------------------------------------------------------------------
 */
enum
{
	/* general flags */
	CWS_NONE          = 0x00000000,
	CWS_BORDER        = 0x00000001,
	CWS_CAPTION       = 0x00000002,
	CWS_MINIMIZEBOX   = 0x00000004,
	CWS_MAXIMIZEBOX   = 0x00000008,
	CWS_CLOSEBOX      = 0x00000010,
	CWS_SYSMENU       = 0x00000020,
	CWS_RESIZE        = 0x00000040,
	CWS_HIDDEN        = 0x00000100,
	CWS_DISABLED      = 0x00000200,
	CWS_TABSTOP       = 0x00000400,
	CWS_CENTERED      = 0x00000800,
	CWS_POPUP         = 0x00001000,
	CWS_MAXIMIZED     = 0x00002000,
	CWS_MINIMIZED     = 0x00004000,
	CWS_STATUSBAR     = 0x00008000,
	CWS_DEFOK         = 0x00010000,
	CWS_DEFCANCEL     = 0x00020000,

	/* edit control flags */
	EF_PASSWORD       = 0x01000000,

	/* memo control flags */
	MF_AUTOWORDWRAP   = 0x01000000,
	
	/* listbox control flags */
	LB_SORTED         = 0x01000000,
	LB_DESCENDING     = 0x02000000,
};

/* ---------------------------------------------------------------------
 * message box styles and result codes
 * ---------------------------------------------------------------------
 */
enum
{
	MB_NORMAL         = 0x00000000,
	MB_INFO           = 0x01000000,
	MB_ERROR          = 0x02000000,
	MB_OK             = 0x00000000,
	MB_OKCANCEL       = 0x04000000,
	MB_YESNO          = 0x08000000,
	MB_YESNOCANCEL    = 0x10000000,
	MB_RETRYCANCEL    = 0x20000000,
	MB_DEFBUTTON1     = 0x40000000,
	MB_DEFBUTTON2     = 0x80000000,
};

enum
{
	IDOK              = 0x00000001,
	IDCANCEL          = 0x00000002,
	IDYES             = 0x00000003,
	IDNO              = 0x00000004,
	IDRETRY           = 0x00000005,
};

/* ---------------------------------------------------------------------
 * scroll bar control codes
 * ---------------------------------------------------------------------
 */
enum
{
	SB_LINEDOWN       = 0x00000001,
	SB_LINEUP         = 0x00000002,
	SB_PAGEDOWN       = 0x00000003,
	SB_PAGEUP         = 0x00000004,
	SB_THUMBTRACK     = 0x00000005,
};

/* ---------------------------------------------------------------------
 * additional key constants
 * ---------------------------------------------------------------------
 */
#define KEY_ESC           27
#define KEY_RETURN        10
#define KEY_TAB           _T('\t')
#define KEY_SPACE         _T(' ')

/* ---------------------------------------------------------------------
 * common window hook function tyles
 * ---------------------------------------------------------------------
 */
typedef void (*HookProc)         (void* win);
typedef void (*Hook1PtrProc)     (void* win, void* ptr);
typedef void (*Hook1IntProc)     (void* win, int val1);
typedef void (*Hook2IntProc)     (void* win, int val1, int val2);
typedef void (*Hook3IntProc)     (void* win, int val1, int val2, int val3);
typedef void (*Hook4IntProc)     (void* win, int val1, int val2, int val3, int val4);
typedef void (*Hook5IntProc)     (void* win, int val1, int val2, int val3, int val4, int val5);

typedef int  (*BoolHookProc)     (void* win);
typedef int  (*BoolHook1PtrProc) (void* win, void* ptr);
typedef int  (*BoolHook1IntProc) (void* win, int val1);
typedef int  (*BoolHook2IntProc) (void* win, int val1, int val2);
typedef int  (*BoolHook3IntProc) (void* win, int val1, int val2, int val3);
typedef int  (*BoolHook4IntProc) (void* win, int val1, int val2, int val3, int val4);
typedef int  (*BoolHook5IntProc) (void* win, int val1, int val2, int val3, int val4, int val5);


/* ---------------------------------------------------------------------
 * custom control hook function types
 * ---------------------------------------------------------------------
 */

typedef void (*CustomHookProc)         (void* win, void* ctrl);
typedef void (*CustomHook1PtrProc)     (void* win, void* ctrl, void* ptr);
typedef void (*CustomHook1IntProc)     (void* win, void* ctrl, int val1);
typedef void (*CustomHook2IntProc)     (void* win, void* ctrl, int val1, int val2);

typedef int  (*CustomBoolHookProc)     (void* win, void* ctrl);
typedef int  (*CustomBoolHook1PtrProc) (void* win, void* ctrl, void* ptr);
typedef int  (*CustomBoolHook1IntProc) (void* win, void* ctrl, int val1);
typedef int  (*CustomBoolHook2IntProc) (void* win, void* ctrl, int val1, int val2);


/* ---------------------------------------------------------------------
 * data structures
 * ---------------------------------------------------------------------
 */

typedef struct
{
	int X, Y;               /* point coordinates */
} CUIPOINT;

typedef struct
{
	int X, Y, W, H;         /* coordinates */
} CUIRECT;

typedef struct
{
	int X, Y;               /* 2D size */
} CUISIZE;

typedef struct
{
	int Pos;                /* scroll bar position */
	int Range;              /* maximum scroll range */
} CUISCBAR;

typedef struct
{
	int WndColor;           /* normal window background color */
	int WndSelColor;        /* selected text background color */
	int WndTxtColor;        /* normal window text color */
	int SelTxtColor;        /* selected text color */
	int InactTxtColor;      /* inactive window text color */
	int HilightColor;       /* hilight window text color */
	int TitleTxtColor;      /* window caption text color */
	int TitleBkgndColor;    /* window caption background color */
	int StatusTxtColor;     /* window status bar text color */
	int StatusBkgndColor;   /* window status bar bkgnd color */
	int BorderColor;        /* color of window frame */
} CUIWINCOLOR;

/* ---------------------------------------------------------------------
 * window structure (only access members if there is no API function)
 * ---------------------------------------------------------------------
 */
typedef struct
{
	WINDOW* Win;            /* curses window handle for client area */
	WINDOW* Frame;          /* curses window handle for non client area */
	CUIRECT Position;       /* window position */
	const wchar_t* Class;     /* window class name */

	                        /* window appearance set on win. creation */
	int     HasCaption;     /* win. has a cation -> WS_CAPTION */
	int     HasMenu;        /* win. has a menu   -> n. y. d. */
	int     HasMaximizeBox; /* win. has a max. box -> CWS_MAXIMIZEBOX */
	int     HasMinimizeBox; /* win. has a min. box -> CWS_MINIMIZEBOX */
	int     HasCloseBox;    /* win. has a close box-> CWS_CLOSEBOX */
	int     HasSysMenu;     /* win. has a sysmenu  -> CWS_SYSMENU */
	int     HasBorder;      /* win. has a border   -> CWS_BORDER */
	int     HasResize;      /* win. has a resize handle */
	int     HasVScroll;     /* win. has a visible vert. scroll bar */
	int     HasHScroll;     /* win. has a visible horz. scroll bar */
	int     HasStatusBar;   /* win. has a status bar at the bottom */

	int     IsCreated;      /* window is created */
	int     IsPopup;        /* window is a popup window */
	int     IsEnabled;      /* window is enabled */
	int     IsActive;       /* not used yet */
	int     IsCentered;     /* window is always centered on screen */
	int     IsMaximized;    /* window is maximized */
	int     IsMinimized;    /* window is minimized */
	int     IsHidden;       /* window is hidden */
	int     IsDefOk;        /* window is default OK control */
	int     IsDefCancel;    /* window is default Cancel control */
	int     IsClosed;       /* window has been closed (by the user) */
	int     WantsFocus;     /* window accepts the input focus */
	int     LayoutValid;    /* window layout is valid or needs recalculation */

	CUIWINCOLOR Color;      /* window colors */

	int     CursorX;        /* cursor position within the window */
	int     CursorY;        /* cursor position within the window */

	int     ExitCode;       /* exit code / used for modal dialogs */

	void*              CreateHooks;    /* create hook function */
	void*              DestroyHooks;   /* destroy hook function */
	BoolHookProc       CanCloseHook;   /* can close hook function */
	HookProc           InitHook;       /* init hook */
	HookProc           PaintHook;      /* paint hook function */
	Hook2IntProc       NcPaintHook;    /* non client paint hook fn. (size_x, size_y) */
	BoolHookProc       SizeHook;       /* size/resize hook function */
	Hook1PtrProc       SetFocusHook;   /* set focus hook function (lastfocus) */
	HookProc           KillFocusHook;  /* kill focus hook function */
	HookProc           ActivateHook;   /* not used yet */
	HookProc           DeactivateHook; /* not used yes */
	BoolHook1IntProc   KeyHook;        /* key input hook function (key) */
	Hook2IntProc       MMoveHook;      /* mouse move hook function (x, y)*/
	Hook3IntProc       MButtonHook;    /* mouse button hook function (x, y, flags)*/
	Hook4IntProc       MMoveNcHook;    /* non client mouse move hook function (x, y, sizex, sizey)*/
	Hook5IntProc       MButtonNcHook;  /* non client mouse button hook function (x, y, flags, sizex, sizey)*/
	Hook2IntProc       VScrollHook;    /* vertical scroll hook fn. (sbcode, pos) */
	Hook2IntProc       HScrollHook;    /* horiz. scroll hook fn. (sbcode, pos) */
	Hook1IntProc       TimerHook;      /* timer elapsed hook fn. (id) */
	HookProc           LayoutHook;    /* recalculate window layout */

	void*              Parent;         /* window's parent window */
	void*              FirstChild;     /* first child window */
	void*              LastChild;      /* last child window */
	void*              Next;           /* next sibling window */
	void*              Previous;       /* previous sibling window */
	void*              Owner;          /* owner window (in case of popup windows)*/
	void*              ActiveChild;    /* active child window */

	void*              InstData;       /* instance data of this window instance */

	wchar_t*           Text;           /* normal window text */
	wchar_t*           RText;          /* right aligned window title text */
	wchar_t*           LText;          /* left aligned window title text */

	wchar_t*           RStatusText;    /* right aligned status text */
	wchar_t*           StatusText;     /* centered status text */
	wchar_t*           LStatusText;    /* left aligned status text */

	int                Id;             /* control id */
	char               HotKey;         /* the windows hot-key (from &text) */

	int                MouseAction;    /* code that stores the last mouse action */

	CUISCBAR           VScrollBar;     /* pos. info of vert. scroll bar */
	CUISCBAR           HScrollBar;     /* pos. info of horz. scroll bar */
	CUIPOINT           MouseSpot;      /* mouse drag position */
} CUIWINDOW;


/* ---------------------------------------------------------------------
 * CORE API
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * color functions
 * ---------------------------------------------------------------------
 */
void InitColor(void);
void SetColor(WINDOW* win, int fcolor, int bcolor, int reverse);
void SetDefaultColor(WINDOW* win, int fcolor, int bcolor, int reverse);

/* ---------------------------------------------------------------------
 * window and runtime control
 * ---------------------------------------------------------------------
 */
void WindowStart(int color, int mouse);
void WindowEnd(void);
void WindowQuit(int exitcode);
int  WindowRun(void);
int  WindowModal(CUIWINDOW* win);
int  WindowClose(CUIWINDOW* win, int exitcode);
void WindowLeaveCurses(void);
void WindowResumeCurses(void);

/* ---------------------------------------------------------------------
 * window functions
 * ---------------------------------------------------------------------
 */
CUIWINDOW* WindowNew(CUIWINDOW* parent, int x, int y, int w, int h, int flags);
void WindowCreate(CUIWINDOW* win);
void WindowDestroy(CUIWINDOW* win);
int  WindowToTop(CUIWINDOW* win);
void WindowGetWindowRect(CUIWINDOW* win, CUIRECT* rc);
void WindowGetClientRect(CUIWINDOW* win, CUIRECT* rc);
void WindowUpdate(void);
void WindowClear(CUIWINDOW* win, CUIRECT* rc);
void WindowInvalidate(CUIWINDOW* win);
void WindowInvalidateLayout(CUIWINDOW* win);
void WindowInvalidateScreen(void);
int  WindowMove(CUIWINDOW* win, int x, int y, int w, int h);
int  WindowMaximize(CUIWINDOW* win, int state);
int  WindowMinimize(CUIWINDOW* win, int state);
void WindowSetText(CUIWINDOW* win, const wchar_t* text);
void WindowSetRText(CUIWINDOW* win, const wchar_t* text);
void WindowSetLText(CUIWINDOW* win, const wchar_t* text);
void WindowSetStatusText(CUIWINDOW* win, const wchar_t* text);
void WindowSetRStatusText(CUIWINDOW* win, const wchar_t* text);
void WindowSetLStatusText(CUIWINDOW* win, const wchar_t* text);
const wchar_t* WindowGetText(CUIWINDOW* win, wchar_t* text, int len);
void WindowHide(CUIWINDOW* win, int state);
void WindowEnable(CUIWINDOW* win, int state);
void WindowSetId(CUIWINDOW* win, int id);
int  WindowGetId(CUIWINDOW* win);
CUIWINDOW* WindowGetCtrl(CUIWINDOW* win, int id);
CUIWINDOW* WindowGetHKeyCtrl(CUIWINDOW* win, int key);
CUIWINDOW* WindowGetDesktop(void);

/* ---------------------------------------------------------------------
 * focus functions
 * ---------------------------------------------------------------------
 */
void WindowSetFocus(CUIWINDOW* win);
CUIWINDOW* WindowGetFocus(void);
void WindowFocusNext(CUIWINDOW* win);
void WindowFocusPrevious(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * mosue capture functions
 * ---------------------------------------------------------------------
 */
void WindowSetCapture(CUIWINDOW* win);
void WindowSetNcCapture(CUIWINDOW* win);
void WindowReleaseCapture(void);

/* ---------------------------------------------------------------------
 * color schemes
 * ---------------------------------------------------------------------
 */
void WindowAddColScheme(const wchar_t* name, CUIWINCOLOR* colrec);
int  WindowHasColScheme(const wchar_t* name);
void WindowColScheme(CUIWINDOW* win, const wchar_t* name);

/* ---------------------------------------------------------------------
 * scroll bar functions
 * ---------------------------------------------------------------------
 */
void WindowEnableVScroll(CUIWINDOW* win, int enable);
void WindowEnableHScroll(CUIWINDOW* win, int enable);
void WindowSetVScrollRange(CUIWINDOW* win, int range);
void WindowSetHScrollRange(CUIWINDOW* win, int range);
void WindowSetVScrollPos(CUIWINDOW* win, int pos);
void WindowSetHScrollPos(CUIWINDOW* win, int pos);
int  WindowGetVScrollRange(CUIWINDOW* win);
int  WindowGetHScrollRange(CUIWINDOW* win);
int  WindowGetVScrollPos(CUIWINDOW* win);
int  WindowGetHScrollPos(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * scroll bar mouse handling (for windows with custom nc area)
 * ---------------------------------------------------------------------
 */
void WindowMButtonVScroll(CUIWINDOW* win, int y1, int y2, int y, int flags);
void WindowMButtonHScroll(CUIWINDOW* win, int x1, int x2, int x, int flags);
void WindowMMoveVScroll(CUIWINDOW* win, int y1, int y2, int y);
void WindowMMoveHScroll(CUIWINDOW* win, int x1, int x2, int x);

/* ---------------------------------------------------------------------
 * cursor functions
 * ---------------------------------------------------------------------
 */
void WindowCursorOn(void);
void WindowCursorOff(void);
void WindowSetCursor(CUIWINDOW* win, int x, int y);

/* ---------------------------------------------------------------------
 * hook functions
 * ---------------------------------------------------------------------
 */
void WindowSetCreateHook(CUIWINDOW* win, HookProc proc);
void WindowSetDestroyHook(CUIWINDOW* win, HookProc proc);
void WindowSetCanCloseHook(CUIWINDOW* win, BoolHookProc proc);
void WindowSetInitHook(CUIWINDOW* win, HookProc proc);
void WindowSetPaintHook(CUIWINDOW* win, HookProc proc);
void WindowSetNcPaintHook(CUIWINDOW* win, Hook2IntProc proc);
void WindowSetSizeHook(CUIWINDOW* win, BoolHookProc proc);
void WindowSetSetFocusHook(CUIWINDOW* win, Hook1PtrProc proc);
void WindowSetKillFocusHook(CUIWINDOW* win, HookProc proc);
void WindowSetActivateHook(CUIWINDOW* win, HookProc proc);
void WindowSetDeactivateHook(CUIWINDOW* win, HookProc proc);
void WindowSetKeyHook(CUIWINDOW* win, BoolHook1IntProc proc);
void WindowSetMMoveHook(CUIWINDOW* win, Hook2IntProc proc);
void WindowSetMButtonHook(CUIWINDOW* win, Hook3IntProc proc);
void WindowSetVScrollHook(CUIWINDOW* win, Hook2IntProc proc);
void WindowSetHScrollHook(CUIWINDOW* win, Hook2IntProc proc);
void WindowSetTimerHook(CUIWINDOW* win, Hook1IntProc proc);
void WindowSetLayoutHook(CUIWINDOW* win, HookProc proc);

/* ---------------------------------------------------------------------
 * timer functions
 * ---------------------------------------------------------------------
 */
void WindowSetTimer(CUIWINDOW* win, int id, int msec);
void WindowKillTimer(CUIWINDOW* win, int id);

/* ---------------------------------------------------------------------
 * window decoration painting (for customized windows)
 * ---------------------------------------------------------------------
 */
void WindowPaintVScroll(CUIWINDOW* win, int y1, int y2);
void WindowPaintHScroll(CUIWINDOW* win, int x1, int x2);
void WindowPaintCaption(CUIWINDOW* win, int size_x);
void WindowPaintStatusBar(CUIWINDOW* win, int size_x, int size_y);

/* ---------------------------------------------------------------------
 * Dialog controls
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * edit control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* EditNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int len, int id, int sflags, int cflags);
void EditSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void EditSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void EditSetPreKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void EditSetPostKeyHook  (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void EditSetChangedHook  (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void EditSetText         (CUIWINDOW* win, const wchar_t* text);
const wchar_t* EditGetText (CUIWINDOW* win, wchar_t* text, int len);
void EditResetInput      (CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * memo text control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* MemoNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void MemoSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void MemoSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MemoSetPreKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void MemoSetPostKeyHook  (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void MemoSetChangedHook  (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MemoSetText         (CUIWINDOW* win, const wchar_t* text);
const wchar_t* MemoGetText (CUIWINDOW* win, wchar_t* text, int len);
int  MemoGetTextBufSize  (CUIWINDOW* win);
void MemoSetWrapColumns  (CUIWINDOW* win, int cols);

/* ---------------------------------------------------------------------
 * label control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* LabelNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void LabelSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void LabelSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);

/* ---------------------------------------------------------------------
 * button control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* ButtonNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void ButtonSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void ButtonSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ButtonSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ButtonSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ButtonSetClickedHook   (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);

/* ---------------------------------------------------------------------
 * radio button control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* RadioNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void RadioSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void RadioSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void RadioSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void RadioSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void RadioSetClickedHook   (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void RadioSetCheck(CUIWINDOW* win, int state);
int  RadioGetCheck(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * checkbox control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* CheckboxNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void CheckboxSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void CheckboxSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void CheckboxSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void CheckboxSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void CheckboxSetClickedHook   (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void CheckboxSetCheck(CUIWINDOW* win, int state);
int  CheckboxGetCheck(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * groupbox control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* GroupboxNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int sflags, int cflags);

/* ---------------------------------------------------------------------
 * listbox control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* ListboxNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void ListboxSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void ListboxSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ListboxSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ListboxSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ListboxSetLbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ListboxSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target);
void ListboxSetLbClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
int  ListboxAdd              (CUIWINDOW* win, const wchar_t* text);
void ListboxDelete           (CUIWINDOW* win, int index);
const wchar_t* ListboxGet      (CUIWINDOW* win, int index);
void ListboxSetData          (CUIWINDOW* win, int index, unsigned long data);
unsigned long ListboxGetData (CUIWINDOW* win, int index);
void ListboxSetSel           (CUIWINDOW* win, int index);
int  ListboxGetSel           (CUIWINDOW* win);
void ListboxClear            (CUIWINDOW* win);
int  ListboxGetCount         (CUIWINDOW* win);
int  ListboxSelect           (CUIWINDOW* win, const wchar_t* text);

/* ---------------------------------------------------------------------
 * combobox control
 * ---------------------------------------------------------------------
 */
CUIWINDOW* ComboboxNew(CUIWINDOW* parent,
                    int x, int y, int w, int h, int id, int sflags, int cflags);
void ComboboxSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void ComboboxSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ComboboxSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ComboboxSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ComboboxSetCbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ComboboxSetCbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target);
int  ComboboxAdd              (CUIWINDOW* win, const wchar_t* text);
void ComboboxDelete           (CUIWINDOW* win, int index);
const wchar_t* ComboboxGet      (CUIWINDOW* win, int index);
void ComboboxSetData          (CUIWINDOW* win, int index, unsigned long data);
unsigned long ComboboxGetData (CUIWINDOW* win, int index);
void ComboboxSetSel           (CUIWINDOW* win, int index);
int  ComboboxGetSel           (CUIWINDOW* win);
void ComboboxClear            (CUIWINDOW* win);
int  ComboboxGetCount         (CUIWINDOW* win);
int  ComboboxSelect           (CUIWINDOW* win, const wchar_t* text);

/* ---------------------------------------------------------------------
 * progress bar
 * ---------------------------------------------------------------------
 */
CUIWINDOW* ProgressbarNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void ProgressbarSetRange(CUIWINDOW* win, int range);
void ProgressbarSetPos(CUIWINDOW* win, int pos);
int  ProgressbarGetRange(CUIWINDOW* win);
int  ProgressbarGetPos(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * text view
 * ---------------------------------------------------------------------
 */
CUIWINDOW* TextviewNew(CUIWINDOW* parent, const wchar_t* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void TextviewSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void TextviewSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void TextviewSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void TextviewSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void TextviewEnableWordWrap   (CUIWINDOW* win, int enable);
void TextviewAdd              (CUIWINDOW* win, const wchar_t* text);
void TextviewClear            (CUIWINDOW* win);
int  TextviewRead             (CUIWINDOW* win, const wchar_t* filename);
int  TextviewSearch           (CUIWINDOW* win, const wchar_t* text, int wholeword, int casesens, int down);
int  TextviewResetSearch      (CUIWINDOW* win, int at_bottom);

/* ---------------------------------------------------------------------
 * list view
 * ---------------------------------------------------------------------
 */
typedef enum
{
	ALIGN_CENTER = 0,                /* center alignment of text */
	ALIGN_LEFT   = 1,                /* left alignment of text */
	ALIGN_RIGHT  = 2                 /* right alignment of text */
} ALIGNMENT_T;

typedef struct LISTREC_S
{
	wchar_t         **ColumnText;        /* char array with text data */
	int              *ColumnWidth;       /* Width of column */
	ALIGNMENT_T      *ColumnAlignment;   /* Alignment of column text */
	int               NumColumns;        /* Numer of columns */
	unsigned long     Data;              /* User data */
	struct LISTREC_S *Next;              /* Next list record */
	CUIWINDOW        *Owner;             /* Pointer to control window */
} LISTREC;

CUIWINDOW* ListviewNew(CUIWINDOW* parent, const wchar_t* text,
           int x, int y, int w, int h, int num_cols, int id, int sflags, int cflags);
void ListviewSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc     proc, CUIWINDOW* target);
void ListviewSetKillFocusHook (CUIWINDOW* win, CustomHookProc         proc, CUIWINDOW* target);
void ListviewSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ListviewSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ListviewSetLbChangedHook (CUIWINDOW* win, CustomHookProc         proc, CUIWINDOW* target);
void ListviewSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc     proc, CUIWINDOW* target);
void ListviewSetLbClickedHook (CUIWINDOW* win, CustomHookProc         proc, CUIWINDOW* target);
void ListviewAddColumn        (CUIWINDOW* win, int colnr, const wchar_t* text);
void ListviewSetTitleAlignment(CUIWINDOW* win, int colnr, ALIGNMENT_T  align);
void ListviewClear            (CUIWINDOW* win);
LISTREC* ListviewCreateRecord (CUIWINDOW* win);
int  ListviewInsertRecord     (CUIWINDOW* win, LISTREC* newrec);
void ListviewSetColumnText    (LISTREC* rec, int colnr, const wchar_t* text);
const wchar_t* ListviewGetColumnText(LISTREC* rec, int colnr);
void ListviewSetSel           (CUIWINDOW* win, int index);
int  ListviewGetSel           (CUIWINDOW* win);
LISTREC* ListviewGetRecord    (CUIWINDOW* win, int index);
int  ListviewGetCount         (CUIWINDOW* win);
void ListviewAlphaSort        (CUIWINDOW* win, int colnr, int up);
void ListviewNumericSort      (CUIWINDOW* win, int colnr, int up);

/* ---------------------------------------------------------------------
 * terminal window
 * ---------------------------------------------------------------------
 */
CUIWINDOW* TerminalNew(CUIWINDOW* parent, const wchar_t* text,
           int x, int y, int w, int h, int id, int sflags, int cflags);
void TerminalSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void TerminalSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void TerminalSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void TerminalSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void TerminalSetCoProcExitHook(CUIWINDOW* win, CustomHook1IntProc proc, CUIWINDOW* target);
void TerminalWrite            (CUIWINDOW* win, const wchar_t* text, int numchar);
int  TerminalRun              (CUIWINDOW* win, const wchar_t* cmd);
void TerminalPipeData         (CUIWINDOW* win, const wchar_t* data);
int  TerminalRunning          (CUIWINDOW* win);
void TerminalUpdateView       (CUIWINDOW* win);


/* ---------------------------------------------------------------------
 * menu control
 * ---------------------------------------------------------------------
 */
typedef struct
{
	wchar_t*      ItemText;
	int           IsSeparator;
	int           IsMoveable;
	unsigned long ItemId;
	void*         Next;
	void*         Previous;
} MENUITEM;

CUIWINDOW* MenuNew(CUIWINDOW* parent, const wchar_t* text,
           int x, int y, int w, int h, int id, int sflags, int cflags);
void MenuSetSetFocusHook    (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void MenuSetKillFocusHook   (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MenuSetPreKeyHook      (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void MenuSetPostKeyHook     (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void MenuSetMenuChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MenuSetMenuChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target);
void MenuSetMenuClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MenuSetMenuEscapeHook  (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void MenuAddItem            (CUIWINDOW* win, const wchar_t* text, unsigned long id, int moveable);
void MenuAddSeparator       (CUIWINDOW* win, int moveable);
void MenuSelectItem         (CUIWINDOW* win, unsigned long id);
MENUITEM* MenuGetSelectedItem(CUIWINDOW* win);
MENUITEM* MenuGetItems      (CUIWINDOW* win);
void MenuSetDragMode        (CUIWINDOW* win, int state);
void MenuClear              (CUIWINDOW* win);


/* ---------------------------------------------------------------------
 * standard dialogs
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * find dialog
 * ---------------------------------------------------------------------
 */
#define SEARCH_DOWN  0
#define SEARCH_UP    1

typedef struct
{
	wchar_t Keyword[128 + 1];
	int   WholeWords;
	int   CaseSens;
	int   Direction;
} FINDDLGDATA;

CUIWINDOW*   FinddlgNew(CUIWINDOW* parent, const wchar_t* title, int sflags, int cflags);
FINDDLGDATA* FinddlgGetData(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * input dialog
 * ---------------------------------------------------------------------
 */
#define MAX_INPUT_SIZE 1024

typedef struct
{
	wchar_t Text[MAX_INPUT_SIZE + 1];
} INPUTDLGDATA;

CUIWINDOW* InputdlgNew(CUIWINDOW* parent, const wchar_t* title, int sflags, int cflags);
INPUTDLGDATA* InputdlgGetData(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * password dialog
 * ---------------------------------------------------------------------
 */
#define MAX_PASSWD_SIZE 128

typedef struct
{
	wchar_t Password[MAX_PASSWD_SIZE + 1];
} PASSWDDLGDATA;

CUIWINDOW* PasswddlgNew(CUIWINDOW* parent, const wchar_t* title, int sflags, int cflags);
PASSWDDLGDATA* PasswddlgGetData(CUIWINDOW* win);

/* ---------------------------------------------------------------------
 * message box
 * ---------------------------------------------------------------------
 */
int MessageBox(CUIWINDOW* parent, const wchar_t* text, const wchar_t* title, int flags);


#endif

