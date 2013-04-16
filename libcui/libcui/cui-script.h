/* ---------------------------------------------------------------------
 * File: cui-script.h
 * (Header file for libcui-script - scripting interface library)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: cui-script.h 33397 2013-04-02 20:48:05Z dv $
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

typedef int  (*ApiProc)        (int func_nr, int argc, const wchar_t* argv[]);
typedef void (*DeleteProc)     (void* ctrlstub);

typedef struct
{
	CUIWINDOW*     Window;
	wchar_t*       CreateHookProc;     /* create hook function */
	wchar_t*       DestroyHookProc;    /* destroy hook function */
	wchar_t*       CanCloseHookProc;   /* can close hook function */
	wchar_t*       InitHookProc;       /* init hook */
	wchar_t*       PaintHookProc;      /* paint hook function */
	wchar_t*       NcPaintHookProc;    /* non client paint hook fn. (size_x, size_y) */
	wchar_t*       SizeHookProc;       /* size/resize hook function */
	wchar_t*       SetFocusHookProc;   /* set focus hook function (lastfocus) */
	wchar_t*       KillFocusHookProc;  /* kill focus hook function */
	wchar_t*       ActivateHookProc;   /* not used yet */
	wchar_t*       DeactivateHookProc; /* not used yes */
	wchar_t*       KeyHookProc;        /* key input hook function (key) */
	wchar_t*       MMoveHookProc;      /* mouse move hook function (x, y)*/
	wchar_t*       MButtonHookProc;    /* mouse button hook function (x, y, flags)*/
	wchar_t*       VScrollHookProc;    /* vertical scroll hook fn. (sbcode, pos) */
	wchar_t*       HScrollHookProc;    /* horiz. scroll hook fn. (sbcode, pos) */
	wchar_t*       TimerHookProc;      /* timer elapsed hook fn. (id) */
	wchar_t*       LayoutHookProc;     /* layout in invalid -> update */

	void*          CtrlStub;           /* additional control hooks */
	const wchar_t* CtrlStubClass;      /* control class */
	DeleteProc     CtrlStubDelete;     /* delete control hook struct */
	void*          Next;               /* next window stub */
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


typedef void        (*StartFrameProc)    (wchar_t ctype, int size);
typedef void        (*InsertStrProc)     (const wchar_t* str);
typedef void        (*InsertIntProc)     (int val);
typedef void        (*InsertLongProc)    (unsigned long val);
typedef void        (*InsertRawProc)     (void* data, int size);
typedef void        (*SendFrameProc)     (void);
typedef int         (*ExecFrameProc)     (void);
typedef void        (*WriteErrorProc)    (int code);

typedef WINDOWSTUB* (*StubCreateProc)    (CUIWINDOW* win);
typedef void        (*StubCheckStubProc) (CUIWINDOW* win);
typedef void        (*StubDeleteProc)    (WINDOWSTUB* stub);
typedef void        (*StubSetHookProc)   (WINDOWSTUB* stub, HOOKTYPE hook, const wchar_t* procname);
typedef void        (*StubSetProcProc)   (wchar_t** p, const wchar_t* procname);
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
void         StubSetHook(WINDOWSTUB* stub, HOOKTYPE hook, const wchar_t* procname);
void         StubSetProc(wchar_t** p, const wchar_t* procname);
WINDOWSTUB*  StubFind(unsigned long key);

int          BackendCreatePipes(void);
void         BackendRemovePipes(void);

int          BackendOpen(const wchar_t* command, int debug);
int          BackendClose(void);
int          BackendRun(void);

void         BackendStartFrame(wchar_t ctype, int size);
void         BackendInsertStr (const wchar_t* str);
void         BackendInsertInt (int val);
void         BackendInsertLong(unsigned long val);
void         BackendSendFrame (void);
int          BackendExecFrame (void);
void         BackendWriteError(int code);

int          BackendNumResultParams(void);
const wchar_t* BackendResultParam(int nr);

void         BackendSetExternalApi(ApiProc api);

#endif

