/* ---------------------------------------------------------------------
 * File: cui-script.h
 * (Header file for libcui-script - scripting interface library)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: cui-script.h 25003 2010-07-17 05:50:58Z dv $
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

#ifndef CUISCRIPT_H
#define CUISCRIPT_H

#include "cui.h"

enum
{
	ERROR_SUCCESS = 0,
	ERROR_PROTO   = 1,
	ERROR_UNKNWN  = 2,
	ERROR_ARGC    = 3,
	ERROR_INVALID = 4,
	ERROR_FAILED  = 5,
};

typedef int  (*ApiProc)        (int func_nr, int argc, const TCHAR* argv[]);
typedef void (*DeleteProc)     (void* ctrlstub);

typedef struct
{
	CUIWINDOW*  Window;
	TCHAR*      CreateHookProc;     /* create hook function */
	TCHAR*      DestroyHookProc;    /* destroy hook function */
	TCHAR*      CanCloseHookProc;   /* can close hook function */
	TCHAR*      InitHookProc;       /* init hook */
	TCHAR*      PaintHookProc;      /* paint hook function */
	TCHAR*      NcPaintHookProc;    /* non client paint hook fn. (size_x, size_y) */
	TCHAR*      SizeHookProc;       /* size/resize hook function */
	TCHAR*      SetFocusHookProc;   /* set focus hook function (lastfocus) */
	TCHAR*      KillFocusHookProc;  /* kill focus hook function */
	TCHAR*      ActivateHookProc;   /* not used yet */
	TCHAR*      DeactivateHookProc; /* not used yes */
	TCHAR*      KeyHookProc;        /* key input hook function (key) */
	TCHAR*      MMoveHookProc;      /* mouse move hook function (x, y)*/
	TCHAR*      MButtonHookProc;    /* mouse button hook function (x, y, flags)*/
	TCHAR*      VScrollHookProc;    /* vertical scroll hook fn. (sbcode, pos) */
	TCHAR*      HScrollHookProc;    /* horiz. scroll hook fn. (sbcode, pos) */
	TCHAR*      TimerHookProc;      /* timer elapsed hook fn. (id) */
	TCHAR*      LayoutHookProc;     /* layout in invalid -> update */

	void*       CtrlStub;           /* additional control hooks */
	const TCHAR*CtrlStubClass;      /* control class */
	DeleteProc  CtrlStubDelete;     /* delete control hook struct */
	void*       Next;               /* next window stub */
} WINDOWSTUB;

typedef enum
{
	HOOK_CREATE = 0,
	HOOK_DESTROY,
	HOOK_CANCLOSE,
	HOOK_INIT,
	HOOK_PAINT,
	HOOK_NCPAINT,
	HOOK_SIZE,
	HOOK_SETFOCUS,
	HOOK_KILLFOCUS,
	HOOK_ACTIVATE,
	HOOK_DEACTIVATE,
	HOOK_KEY,
	HOOK_MMOVE,
	HOOK_MBUTTON,
	HOOK_VSCROLL,
	HOOK_HSCROLL,
	HOOK_TIMER,
	HOOK_LAYOUT,
} HOOKTYPE;


typedef void        (*StartFrameProc)    (TCHAR ctype, int size);
typedef void        (*InsertStrProc)     (const TCHAR* str);
typedef void        (*InsertIntProc)     (int val);
typedef void        (*InsertLongProc)    (unsigned long val);
typedef void        (*InsertRawProc)     (void* data, int size);
typedef void        (*SendFrameProc)     (void);
typedef int         (*ExecFrameProc)     (void);
typedef void        (*WriteErrorProc)    (int code);

typedef WINDOWSTUB* (*StubCreateProc)    (CUIWINDOW* win);
typedef void        (*StubCheckStubProc) (CUIWINDOW* win);
typedef void        (*StubDeleteProc)    (WINDOWSTUB* stub);
typedef void        (*StubSetHookProc)   (WINDOWSTUB* stub, HOOKTYPE hook, const TCHAR* procname);
typedef void        (*StubSetProcProc)   (TCHAR** p, const TCHAR* procname);
typedef WINDOWSTUB* (*StubFindProc)      (unsigned long key);

typedef struct
{
	StartFrameProc    StartFrame;
	InsertStrProc     InsertStr;
	InsertIntProc     InsertInt;
	InsertLongProc    InsertLong;
	SendFrameProc     SendFrame;
	ExecFrameProc     ExecFrame;
	WriteErrorProc    WriteError;

	StubCreateProc    StubCreate;
	StubCheckStubProc StubCheck;
	StubDeleteProc    StubDelete;
	StubSetHookProc   StubSetHook;
	StubSetProcProc   StubSetProc;
	StubFindProc      StubFind;
} MODULEINIT_T;


void         ScriptingInit(void);
void         ScriptingEnd(void);

WINDOWSTUB*  StubCreate(CUIWINDOW* win);
void         StubCheckStub(CUIWINDOW* win);
void         StubDelete(WINDOWSTUB* stub);
void         StubSetHook(WINDOWSTUB* stub, HOOKTYPE hook, const TCHAR* procname);
void         StubSetProc(TCHAR** p, const TCHAR* procname);
WINDOWSTUB*  StubFind(unsigned long key);

int          BackendCreatePipes(void);
void         BackendRemovePipes(void);

int          BackendOpen(const TCHAR* command, int debug);
int          BackendClose(void);
int          BackendRun(void);

void         BackendStartFrame(TCHAR ctype, int size);
void         BackendInsertStr (const TCHAR* str);
void         BackendInsertInt (int val);
void         BackendInsertLong(unsigned long val);
void         BackendSendFrame (void);
int          BackendExecFrame (void);
void         BackendWriteError(int code);

int          BackendNumResultParams(void);
const TCHAR* BackendResultParam(int nr);

void         BackendSetExternalApi(ApiProc api);

#endif

