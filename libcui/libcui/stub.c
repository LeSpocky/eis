/* ---------------------------------------------------------------------
 * File: stub.c
 * (window stubs for shell functions)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: stub.c 33402 2013-04-02 21:32:17Z dv $
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

#include "cui-script.h"

/* local prototypes */

static void          StubFreeData(WINDOWSTUB* stub);
static unsigned char StubCalcHash(unsigned long key);

static void          StubCreateHook(void* win);
static void          StubDestroyHook(void* win);
static int           StubCanCloseHook(void* win);
static void          StubInitHook(void* win);
static void          StubPaintHook(void* win);
static void          StubNcPaintHook(void* win, int cx, int cy);
static int           StubSizeHook(void* win);
static void          StubSetFocusHook(void* win, void* oldfocus);
static void          StubKillFocusHook(void* win);
static void          StubActivateHook(void* win);
static void          StubDeactivateHook(void* win);
static int           StubKeyHook(void* win, int key);
static void          StubMMoveHook(void* win, int x, int y);
static void          StubMButtonHook(void* win, int x, int y, int flags);
static void          StubVScrollHook(void* win, int sbcode, int pos);
static void          StubHScrollHook(void* win, int sbcode, int pos);;
static void          StubTimerHook(void* win, int id);
static void          StubLayoutHook(void* win);

/* local data */

static WINDOWSTUB* Stubs[256];

/* public functions */

/* ---------------------------------------------------------------------
 * StubInit
 * Initialize window stub repository
 * ---------------------------------------------------------------------
 */
void
StubInit(void)
{
	memset(Stubs, 0, 256 * sizeof(WINDOWSTUB*));
}

/* ---------------------------------------------------------------------
 * StubClear
 * Free data from  window stub repository
 * ---------------------------------------------------------------------
 */
void
StubClear(void)
{
	int i;

	for (i = 0; i < 256; i++)
	{
		WINDOWSTUB* delptr = Stubs[i];
		while (delptr)
		{
			Stubs[i] = delptr->Next;
			StubFreeData(delptr);
			free(delptr);
			delptr = Stubs[i];
		}
	}
}

/* ---------------------------------------------------------------------
 * StubCreate
 * Create a new window stub and add it to the repository
 * ---------------------------------------------------------------------
 */
WINDOWSTUB*
StubCreate(CUIWINDOW* win)
{
	unsigned char hashcode;
	if (win)
	{
		WINDOWSTUB* stub = (WINDOWSTUB*) malloc(sizeof(WINDOWSTUB));
		memset(stub, 0, sizeof(WINDOWSTUB));
		stub->Window = win;

		hashcode = StubCalcHash((unsigned long) win);
		stub->Next = Stubs[hashcode];
		Stubs[hashcode] = stub;

		WindowSetDestroyHook(stub->Window, StubDestroyHook);

		return stub;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * StubCheckStub
 * Check if a stub exists for window 'win'. If no stub exists, one is
 * created.
 * ---------------------------------------------------------------------
 */
void
StubCheckStub(CUIWINDOW* win)
{
	if (win)
	{
		WINDOWSTUB* stub = StubFind((unsigned long)win);
		if (!stub)
		{
			StubCreate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * StubDelete
 * Remove a stub from the sub repository
 * ---------------------------------------------------------------------
 */ 
void
StubDelete(WINDOWSTUB* stub)
{
	unsigned char hashcode = StubCalcHash((unsigned long) stub->Window);
	WINDOWSTUB* oldptr = NULL;
	WINDOWSTUB* ptr = Stubs[hashcode];

	while (ptr)
	{
		if (ptr == stub)
		{
			if (oldptr)
			{
				oldptr->Next = stub->Next;
			}
			else
			{
				Stubs[hashcode] = stub->Next;
			}
			StubFreeData(stub);
			free(stub);
			return;
		}
		oldptr = ptr;
		ptr = (WINDOWSTUB*) ptr->Next;
	}
}

/* ---------------------------------------------------------------------
 * StubSetProc
 * Assign or replace procedure name
 * ---------------------------------------------------------------------
 */ 
void
StubSetProc(wchar_t** p, const wchar_t* procname)
{
	if (*p)
	{
		free(*p);
		*p = NULL;
	}
	if (procname && wcslen(procname))
	{
		*p = wcsdup(procname);
	}
}

/* ---------------------------------------------------------------------
 * StubSetHook
 * Assign a window hook procedure name
 * ---------------------------------------------------------------------
 */ 
void
StubSetHook(WINDOWSTUB* stub, HOOKTYPE hook, const wchar_t* procname)
{
	switch(hook)
	{
	case HOOK_CREATE:
		StubSetProc(&stub->CreateHookProc, procname);
		if (stub->CreateHookProc)
		{
			WindowSetCreateHook(stub->Window, StubCreateHook);
		}
		else
		{
			WindowSetCreateHook(stub->Window, NULL);
		}
		break;
	case HOOK_DESTROY:
		/* The destroy hook is always executed */
		StubSetProc(&stub->DestroyHookProc, procname);
		break;
	case HOOK_CANCLOSE:
		StubSetProc(&stub->CanCloseHookProc, procname);
		if (stub->CanCloseHookProc)
		{
			WindowSetCanCloseHook(stub->Window, StubCanCloseHook);
		}
		else
		{
			WindowSetCanCloseHook(stub->Window, NULL);
		}
		break;
	case HOOK_INIT:
		StubSetProc(&stub->InitHookProc, procname);
		if (stub->InitHookProc)
		{
			WindowSetInitHook(stub->Window, StubInitHook);
		}
		else
		{
			WindowSetInitHook(stub->Window, NULL);
		}
		break;
	case HOOK_PAINT:
		StubSetProc(&stub->PaintHookProc, procname);
		if (stub->PaintHookProc)
		{
			WindowSetPaintHook(stub->Window, StubPaintHook);
		}
		else
		{
			WindowSetPaintHook(stub->Window, NULL);
		}
		break;
	case HOOK_NCPAINT:
		StubSetProc(&stub->NcPaintHookProc, procname);
		if (stub->NcPaintHookProc)
		{
			WindowSetNcPaintHook(stub->Window, StubNcPaintHook);
		}
		else
		{
			WindowSetNcPaintHook(stub->Window, NULL);
		}
		break;
	case HOOK_SIZE:
		StubSetProc(&stub->SizeHookProc, procname);
		if (stub->SizeHookProc)
		{
			WindowSetSizeHook(stub->Window, StubSizeHook);
		}
		else
		{
			WindowSetSizeHook(stub->Window, NULL);
		}
		break;
	case HOOK_SETFOCUS:
		StubSetProc(&stub->SetFocusHookProc, procname);
		if (stub->SetFocusHookProc)
		{
			WindowSetSetFocusHook(stub->Window, StubSetFocusHook);
		}
		else
		{
			WindowSetSetFocusHook(stub->Window, NULL);
		}
		break;
	case HOOK_KILLFOCUS:
		StubSetProc(&stub->KillFocusHookProc, procname);
		if (stub->KillFocusHookProc)
		{
			WindowSetKillFocusHook(stub->Window, StubKillFocusHook);
		}
		else
		{
			WindowSetKillFocusHook(stub->Window, NULL);
		}
		break;
	case HOOK_ACTIVATE:
		StubSetProc(&stub->ActivateHookProc, procname);
		if (stub->ActivateHookProc)
		{
			WindowSetActivateHook(stub->Window, StubActivateHook);
		}
		else
		{
			WindowSetActivateHook(stub->Window, NULL);
		}
		break;
	case HOOK_DEACTIVATE:
		StubSetProc(&stub->DeactivateHookProc, procname);
		if (stub->DeactivateHookProc)
		{
			WindowSetDeactivateHook(stub->Window, StubDeactivateHook);
		}
		else
		{
			WindowSetDeactivateHook(stub->Window, NULL);
		}
		break;
	case HOOK_KEY:
		StubSetProc(&stub->KeyHookProc, procname);
		if (stub->KeyHookProc)
		{
			WindowSetKeyHook(stub->Window, StubKeyHook);
		}
		else
		{
			WindowSetKeyHook(stub->Window, NULL);
		}
		break;
	case HOOK_MMOVE:
		StubSetProc(&stub->MMoveHookProc, procname);
		if (stub->MMoveHookProc)
		{
			WindowSetMMoveHook(stub->Window, StubMMoveHook);
		}
		else
		{
			WindowSetMMoveHook(stub->Window, NULL);
		}
		break;
	case HOOK_MBUTTON:
		StubSetProc(&stub->MButtonHookProc, procname);
		if (stub->MButtonHookProc)
		{
			WindowSetMButtonHook(stub->Window, StubMButtonHook);
		}
		else
		{
			WindowSetMButtonHook(stub->Window, NULL);
		}
		break;
	case HOOK_VSCROLL:
		StubSetProc(&stub->VScrollHookProc, procname);
		if (stub->VScrollHookProc)
		{
			WindowSetVScrollHook(stub->Window, StubVScrollHook);
		}
		else
		{
			WindowSetVScrollHook(stub->Window, NULL);
		}
		break;
	case HOOK_HSCROLL:
		StubSetProc(&stub->HScrollHookProc, procname);
		if (stub->HScrollHookProc)
		{
			WindowSetHScrollHook(stub->Window, StubHScrollHook);
		}
		else
		{
			WindowSetHScrollHook(stub->Window, NULL);
		}
		break;
	case HOOK_TIMER:
		StubSetProc(&stub->TimerHookProc, procname);
		if (stub->TimerHookProc)
		{
			WindowSetTimerHook(stub->Window, StubTimerHook);
		}
		else
		{
			WindowSetTimerHook(stub->Window, NULL);
		}
		break;
	case HOOK_LAYOUT:
		StubSetProc(&stub->LayoutHookProc, procname);
		if (stub->LayoutHookProc)
		{
			WindowSetLayoutHook(stub->Window, StubLayoutHook);
		}
		else
		{
			WindowSetLayoutHook(stub->Window, NULL);
		}
		break;
	}
}

/* ---------------------------------------------------------------------
 * StubFind
 * Search a window stub 
 * ---------------------------------------------------------------------
 */ 
WINDOWSTUB*
StubFind(unsigned long key)
{
	unsigned char hashcode = StubCalcHash((unsigned long) key);
	WINDOWSTUB* ptr = Stubs[hashcode];
	CUIWINDOW* win = (CUIWINDOW*) key;

	while (ptr)
	{
		if (ptr->Window == win)
		{
			return ptr;
		}
		ptr = (WINDOWSTUB*) ptr->Next;
	}
	return NULL;
}

/* local helper functions */

/* ---------------------------------------------------------------------
 * StubFreeData
 * Free all window procedures
 * ---------------------------------------------------------------------
 */ 
static void
StubFreeData(WINDOWSTUB* stub)
{
	if (stub->CreateHookProc) free(stub->CreateHookProc);
	if (stub->DestroyHookProc) free(stub->DestroyHookProc);
	if (stub->CanCloseHookProc) free(stub->CanCloseHookProc);
	if (stub->InitHookProc) free(stub->InitHookProc);
	if (stub->PaintHookProc) free(stub->PaintHookProc);
	if (stub->NcPaintHookProc) free(stub->NcPaintHookProc);
	if (stub->SizeHookProc) free(stub->SizeHookProc);
	if (stub->SetFocusHookProc) free(stub->SetFocusHookProc);
	if (stub->KillFocusHookProc) free(stub->KillFocusHookProc);
	if (stub->ActivateHookProc) free(stub->ActivateHookProc);
	if (stub->DeactivateHookProc) free(stub->DeactivateHookProc);
	if (stub->KeyHookProc) free(stub->KeyHookProc);
	if (stub->MMoveHookProc) free(stub->MMoveHookProc);
	if (stub->MButtonHookProc) free(stub->MButtonHookProc);
	if (stub->VScrollHookProc) free(stub->VScrollHookProc);
	if (stub->HScrollHookProc) free(stub->HScrollHookProc);
	if (stub->TimerHookProc) free(stub->TimerHookProc);
	if (stub->LayoutHookProc) free(stub->LayoutHookProc);
	if (stub->CtrlStubDelete)
	{
		stub->CtrlStubDelete(stub->CtrlStub);
	}
}

/* ---------------------------------------------------------------------
 * StubCalcHash
 * Calcuate a hash value
 * ---------------------------------------------------------------------
 */
static unsigned char
StubCalcHash(unsigned long key)
{
	unsigned char* p = (unsigned char*) &key;

	return (p[0] + p[1] + p[2] + p[3]);
}

/* local hook functions */

/* ---------------------------------------------------------------------
 * StubCreateHook
 * Call a remote backend hook: CreateHook
 * ---------------------------------------------------------------------
 */
static void
StubCreateHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->CreateHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->CreateHookProc) + 48);
		BackendInsertStr (winstub->CreateHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubDestroyHook
 * Call a remote backend hook: DestroyHook
 * ---------------------------------------------------------------------
 */
static void
StubDestroyHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub)
	{
		if (winstub->DestroyHookProc)
		{
			BackendStartFrame(_T('H'), wcslen(winstub->DestroyHookProc) + 48);
			BackendInsertStr (winstub->DestroyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendExecFrame ();
		}
		StubDelete(winstub);
	}
}

/* ---------------------------------------------------------------------
 * StubCanCloseHook
 * Call a remote backend hook: CanCloseHook
 * ---------------------------------------------------------------------
 */
static int
StubCanCloseHook(void* win)
{
	int result = TRUE;

	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->CanCloseHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->CanCloseHookProc) + 48);
		BackendInsertStr (winstub->CanCloseHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
		if ((BackendNumResultParams() > 0) && (wcscmp(BackendResultParam(0), _T("0")) == 0))
		{
			result = FALSE;
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * StubInitHook
 * Call a remote backend hook: InitHook
 * ---------------------------------------------------------------------
 */
static void
StubInitHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->InitHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->InitHookProc) + 48);
		BackendInsertStr (winstub->InitHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubPaintHook
 * Call a remote backend hook: PaintHook
 * ---------------------------------------------------------------------
 */
static void
StubPaintHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->PaintHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->PaintHookProc) + 48);
		BackendInsertStr (winstub->PaintHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubNcPaintHook
 * Call a remote backend hook: NcPaintHook
 * ---------------------------------------------------------------------
 */
static void
StubNcPaintHook(void* win, int cx, int cy)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->NcPaintHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->NcPaintHookProc) + 64);
		BackendInsertStr (winstub->NcPaintHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (cx);
		BackendInsertInt (cy);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubSizeHook
 * Call a remote backend hook: SizeHook
 * ---------------------------------------------------------------------
 */
static int
StubSizeHook(void* win)
{
	int result = FALSE;

	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->SizeHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->SizeHookProc) + 48);
		BackendInsertStr (winstub->SizeHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
		if ((BackendNumResultParams() > 0) && (wcscmp(BackendResultParam(0), _T("1")) == 0))
		{
			result = TRUE;
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * StubSetFocusHook
 * Call a remote backend hook: SetFocusHook
 * ---------------------------------------------------------------------
 */
static void
StubSetFocusHook(void* win, void* oldfocus)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->SetFocusHookProc)
	{
		StubCheckStub((CUIWINDOW*)oldfocus);

		BackendStartFrame(_T('H'), wcslen(winstub->SetFocusHookProc) + 64);
		BackendInsertStr (winstub->SetFocusHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertLong((unsigned long) oldfocus);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubKillFocusHook
 * Call a remote backend hook: KillFocusHook
 * ---------------------------------------------------------------------
 */
static void
StubKillFocusHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->KillFocusHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->KillFocusHookProc) + 48);
		BackendInsertStr (winstub->KillFocusHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubActivateHook
 * Call a remote backend hook: ActivateHook
 * ---------------------------------------------------------------------
 */
static void
StubActivateHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->ActivateHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->ActivateHookProc) + 48);
		BackendInsertStr (winstub->ActivateHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubDeactivateHook
 * Call a remote backend hook: DeactivateHook
 * ---------------------------------------------------------------------
 */
static void
StubDeactivateHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->DeactivateHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->DeactivateHookProc) + 48);
		BackendInsertStr (winstub->DeactivateHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubKeyHook
 * Call a remote backend hook: KeyHook
 * ---------------------------------------------------------------------
 */
static int
StubKeyHook(void* win, int key)
{
	int result = FALSE;

	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->KeyHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->KeyHookProc) + 64);
		BackendInsertStr (winstub->KeyHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (key);
		BackendExecFrame ();
		if ((BackendNumResultParams() > 0) && (wcscmp(BackendResultParam(0), _T("1")) == 0))
		{
			result = TRUE;
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * StubMMoveHook
 * Call a remote backend hook: MMoveHook
 * ---------------------------------------------------------------------
 */
static void
StubMMoveHook(void* win, int x, int y)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->MMoveHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->MMoveHookProc) + 64);
		BackendInsertStr (winstub->MMoveHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (x);
		BackendInsertInt (y);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubMButtonHook
 * Call a remote backend hook: MButtonHook
 * ---------------------------------------------------------------------
 */
static void
StubMButtonHook(void* win, int x, int y, int flags)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->MButtonHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->MButtonHookProc) + 96);
		BackendInsertStr (winstub->MButtonHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (x);
		BackendInsertInt (y);
		BackendInsertInt (flags);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubVScrollHook
 * Call a remote backend hook: VScrollHook
 * ---------------------------------------------------------------------
 */
static void
StubVScrollHook(void* win, int sbcode, int pos)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->VScrollHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->VScrollHookProc) + 64);
		BackendInsertStr (winstub->VScrollHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (sbcode);
		BackendInsertInt (pos);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubHScrollHook
 * Call a remote backend hook: HScrollHook
 * ---------------------------------------------------------------------
 */
static void
StubHScrollHook(void* win, int sbcode, int pos)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->HScrollHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->HScrollHookProc) + 64);
		BackendInsertStr (winstub->HScrollHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (sbcode);
		BackendInsertInt (pos);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubTimerHook
 * Call a remote backend hook: TimerHook
 * ---------------------------------------------------------------------
 */
static void
StubTimerHook(void* win, int id)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->TimerHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->TimerHookProc) + 64);
		BackendInsertStr (winstub->TimerHookProc);
		BackendInsertLong((unsigned long) win);
		BackendInsertInt (id);
		BackendExecFrame ();
	}
}

/* ---------------------------------------------------------------------
 * StubLayoutHook
 * Call a remote backend hook: LayoutHook
 * ---------------------------------------------------------------------
 */
static void
StubLayoutHook(void* win)
{
	WINDOWSTUB* winstub = StubFind((unsigned long)win);
	if (winstub && winstub->LayoutHookProc)
	{
		BackendStartFrame(_T('H'), wcslen(winstub->LayoutHookProc) + 48);
		BackendInsertStr (winstub->LayoutHookProc);
		BackendInsertLong((unsigned long) win);
		BackendExecFrame ();
	}
}
