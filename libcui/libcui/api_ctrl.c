/* ---------------------------------------------------------------------
 * File: api_ctrl.h
 * (controls script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api_ctrl.c 24868 2010-07-04 11:02:11Z dv $
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
#include "cui-script.h"
#include "api.h"
#include "api_ctrl.h"


/* ---------------------------------------------------------------------
 *                 EDIT CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	EDIT_SETFOCUS = 0,
	EDIT_KILLFOCUS,
	EDIT_PREKEY,
	EDIT_POSTKEY,
	EDIT_CHANGED,
} EDITHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ChangedHookProc;      /* changed hook function */
} EDITSTUB;

static void ApiEditSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiEditKillFocusHook(void* win, void* ctrl);
static int  ApiEditPreKeyHook(void* win, void* ctrl, int key);
static int  ApiEditPostKeyHook(void* win, void* ctrl, int key);
static void ApiEditChangedHook(void* win, void* ctrl);
static void ApiEditFreeStub(void* ctrlstub);

void
ApiEditNew(int argc, const TCHAR* argv[])
{
	if (argc == 10)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  edit;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   len;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &len);
		stscanf(argv[7], _T("%d"), &id);
		stscanf(argv[8], _T("%d"), &sflags);
		stscanf(argv[9], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		edit = EditNew(
			win,
			argv[1],
			x, y, w, h, len, id,
			sflags, cflags);

		stub = StubCreate(edit);
		if (stub)
		{
			stub->CtrlStubClass = _T("EDITSTUB");
			stub->CtrlStub = malloc(sizeof(EDITSTUB));
			memset(stub->CtrlStub, 0, sizeof(EDITSTUB));
			stub->CtrlStubDelete = ApiEditFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiEditSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= EDIT_SETFOCUS) && (hook <= EDIT_CHANGED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("EDITSTUB")) == 0))
			{
				EDITSTUB* editstub = (EDITSTUB*) winstub->CtrlStub;

				switch((EDITHOOKTYPE) hook)
				{
				case EDIT_SETFOCUS:
					StubSetProc(&editstub->SetFocusHookProc, procname);
					if (editstub->SetFocusHookProc)
					{
						EditSetSetFocusHook(winstub->Window, ApiEditSetFocusHook, targetwin->Window);
					}
					else
					{
						EditSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case EDIT_KILLFOCUS:
					StubSetProc(&editstub->KillFocusHookProc, procname);
					if (editstub->KillFocusHookProc)
					{
						EditSetKillFocusHook(winstub->Window, ApiEditKillFocusHook, targetwin->Window);
					}
					else
					{
						EditSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case EDIT_PREKEY:
					StubSetProc(&editstub->PreKeyHookProc, procname);
					if (editstub->PreKeyHookProc)
					{
						EditSetPreKeyHook(winstub->Window, ApiEditPreKeyHook, targetwin->Window);
					}
					else
					{
						EditSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case EDIT_POSTKEY:
					StubSetProc(&editstub->PostKeyHookProc, procname);
					if (editstub->PostKeyHookProc)
					{
						EditSetPostKeyHook(winstub->Window, ApiEditPostKeyHook, targetwin->Window);
					}
					else
					{
						EditSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case EDIT_CHANGED:
					StubSetProc(&editstub->ChangedHookProc, procname);
					if (editstub->ChangedHookProc)
					{
						EditSetChangedHook(winstub->Window, ApiEditChangedHook, targetwin->Window);
					}
					else
					{
						EditSetChangedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiEditSetText(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			EditSetText(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiEditGetText(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TCHAR* result = (TCHAR*) malloc((1024 + 1) * sizeof(TCHAR));
			if (result)
			{
				EditGetText(winstub->Window, result, 1000);

				BackendStartFrame(_T('R'), tcslen(result) + 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendInsertStr (result);
				BackendSendFrame ();
				free(result);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiEditFreeStub(void* ctrlstub)
{
	EDITSTUB* editstub = (EDITSTUB*) ctrlstub;
	if (editstub)
	{
		if (editstub->SetFocusHookProc)  free(editstub->SetFocusHookProc);
		if (editstub->KillFocusHookProc) free(editstub->KillFocusHookProc);
		if (editstub->PreKeyHookProc)    free(editstub->PreKeyHookProc);
		if (editstub->PostKeyHookProc)   free(editstub->PostKeyHookProc);
		if (editstub->ChangedHookProc)   free(editstub->ChangedHookProc);
		free(editstub);
	}
}

static void
ApiEditSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("EDITSTUB")) == 0))
	{
		EDITSTUB* editstub = (EDITSTUB*) ctrlstub->CtrlStub;
		if (editstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(editstub->SetFocusHookProc) + 64);
			BackendInsertStr (editstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiEditKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("EDITSTUB")) == 0))
	{
		EDITSTUB* editstub = (EDITSTUB*) ctrlstub->CtrlStub;
		if (editstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(editstub->KillFocusHookProc) + 64);
			BackendInsertStr (editstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiEditPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("EDITSTUB")) == 0))
	{
		EDITSTUB* editstub = (EDITSTUB*) ctrlstub->CtrlStub;
		if (editstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(editstub->PreKeyHookProc) + 64);
			BackendInsertStr (editstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiEditPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("EDITSTUB")) == 0))
	{
		EDITSTUB* editstub = (EDITSTUB*) ctrlstub->CtrlStub;
		if (editstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(editstub->PostKeyHookProc) + 64);
			BackendInsertStr (editstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiEditChangedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("EDITSTUB")) == 0))
	{
		EDITSTUB* editstub = (EDITSTUB*) ctrlstub->CtrlStub;
		if (editstub->ChangedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(editstub->ChangedHookProc) + 64);
			BackendInsertStr (editstub->ChangedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 LABEL CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	LABEL_SETFOCUS = 0,
	LABEL_KILLFOCUS,
} LABELHOOKTYPE;

typedef struct
{
	TCHAR*     SetFocusHookProc;     /* control got input focus */
	TCHAR*     KillFocusHookProc;    /* control lost input focus */
} LABELSTUB;

static void ApiLabelSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiLabelKillFocusHook(void* win, void* ctrl);
static void ApiLabelFreeStub(void* ctrlstub);

void
ApiLabelNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  label;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int    x, y, w, h, id;
		int    sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		label = LabelNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(label);
		if (stub)
		{
			stub->CtrlStubClass = _T("LABELSTUB");
			stub->CtrlStub = malloc(sizeof(LABELSTUB));
			memset(stub->CtrlStub, 0, sizeof(LABELSTUB));
			stub->CtrlStubDelete = ApiLabelFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiLabelSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= LABEL_SETFOCUS) && (hook <= LABEL_KILLFOCUS))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("LABELSTUB")) == 0))
			{
				LABELSTUB* labelstub = (LABELSTUB*) winstub->CtrlStub;

				switch((LABELHOOKTYPE) hook)
				{
				case LABEL_SETFOCUS:
					StubSetProc(&labelstub->SetFocusHookProc, procname);
					if (labelstub->SetFocusHookProc)
					{
						LabelSetSetFocusHook(winstub->Window, ApiLabelSetFocusHook, targetwin->Window);
					}
					else
					{
						LabelSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LABEL_KILLFOCUS:
					StubSetProc(&labelstub->KillFocusHookProc, procname);
					if (labelstub->KillFocusHookProc)
					{
						LabelSetKillFocusHook(winstub->Window, ApiLabelKillFocusHook, targetwin->Window);
					}
					else
					{
						LabelSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}
				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiLabelFreeStub(void* ctrlstub)
{
	LABELSTUB* labelstub = (LABELSTUB*) ctrlstub;
	if (labelstub)
	{
		if (labelstub->SetFocusHookProc)  free(labelstub->SetFocusHookProc);
		if (labelstub->KillFocusHookProc) free(labelstub->KillFocusHookProc);
		free(labelstub);
	}
}

static void
ApiLabelSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LABELSTUB")) == 0))
	{
		LABELSTUB* labelstub = (LABELSTUB*) ctrlstub->CtrlStub;
		if (labelstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(labelstub->SetFocusHookProc) + 64);
			BackendInsertStr (labelstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiLabelKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LABELSTUB")) == 0))
	{
		LABELSTUB* labelstub = (LABELSTUB*) ctrlstub->CtrlStub;
		if (labelstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(labelstub->KillFocusHookProc) + 64);
			BackendInsertStr (labelstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}



/* ---------------------------------------------------------------------
 *                 BUTTON CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	BUTTON_SETFOCUS = 0,
	BUTTON_KILLFOCUS,
	BUTTON_PREKEY,
	BUTTON_POSTKEY,
	BUTTON_CLICKED
} BUTTONHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ClickedHookProc;      /* clicked hook function */
} BUTTONSTUB;

static void ApiButtonSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiButtonKillFocusHook(void* win, void* ctrl);
static int  ApiButtonPreKeyHook(void* win, void* ctrl, int key);
static int  ApiButtonPostKeyHook(void* win, void* ctrl, int key);
static void ApiButtonClickedHook(void* win, void* ctrl);
static void ApiButtonFreeStub(void* ctrlstub);

void
ApiButtonNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  button;
		unsigned long wndnr;
		int    x, y, w, h, id;
		int    sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		button = ButtonNew(
			ApiLookupWindow(wndnr),
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(button);
		if (stub)
		{
			stub->CtrlStubClass = _T("BUTTONSTUB");
			stub->CtrlStub = malloc(sizeof(BUTTONSTUB));
			memset(stub->CtrlStub, 0, sizeof(BUTTONSTUB));
			stub->CtrlStubDelete = ApiButtonFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiButtonSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= BUTTON_SETFOCUS) && (hook <= BUTTON_CLICKED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
			{
				BUTTONSTUB* butstub = (BUTTONSTUB*) winstub->CtrlStub;

				switch((BUTTONHOOKTYPE) hook)
				{
				case BUTTON_SETFOCUS:
					StubSetProc(&butstub->SetFocusHookProc, procname);
					if (butstub->SetFocusHookProc)
					{
						ButtonSetSetFocusHook(winstub->Window, ApiButtonSetFocusHook, targetwin->Window);
					}
					else
					{
						ButtonSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case BUTTON_KILLFOCUS:
					StubSetProc(&butstub->KillFocusHookProc, procname);
					if (butstub->KillFocusHookProc)
					{
						ButtonSetKillFocusHook(winstub->Window, ApiButtonKillFocusHook, targetwin->Window);
					}
					else
					{
						ButtonSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case BUTTON_PREKEY:
					StubSetProc(&butstub->PreKeyHookProc, procname);
					if (butstub->PreKeyHookProc)
					{
						ButtonSetPreKeyHook(winstub->Window, ApiButtonPreKeyHook, targetwin->Window);
					}
					else
					{
						ButtonSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case BUTTON_POSTKEY:
					StubSetProc(&butstub->PostKeyHookProc, procname);
					if (butstub->PostKeyHookProc)
					{
						ButtonSetPostKeyHook(winstub->Window, ApiButtonPostKeyHook, targetwin->Window);
					}
					else
					{
						ButtonSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case BUTTON_CLICKED:
					StubSetProc(&butstub->ClickedHookProc, procname);
					if (butstub->ClickedHookProc)
					{
						ButtonSetClickedHook(winstub->Window, ApiButtonClickedHook, targetwin->Window);
					}
					else
					{
						ButtonSetClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiButtonFreeStub(void* ctrlstub)
{
	BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub;
	if (buttonstub)
	{
		if (buttonstub->SetFocusHookProc)  free(buttonstub->SetFocusHookProc);
		if (buttonstub->KillFocusHookProc) free(buttonstub->KillFocusHookProc);
		if (buttonstub->PreKeyHookProc)    free(buttonstub->PreKeyHookProc);
		if (buttonstub->PostKeyHookProc)   free(buttonstub->PostKeyHookProc);
		if (buttonstub->ClickedHookProc)   free(buttonstub->ClickedHookProc);
		free(buttonstub);
	}
}

static void
ApiButtonSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
	{
		BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub->CtrlStub;
		if (buttonstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(buttonstub->SetFocusHookProc) + 64);
			BackendInsertStr (buttonstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiButtonKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
	{
		BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub->CtrlStub;
		if (buttonstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(buttonstub->KillFocusHookProc) + 64);
			BackendInsertStr (buttonstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiButtonPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
	{
		BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub->CtrlStub;
		if (buttonstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(buttonstub->PreKeyHookProc) + 64);
			BackendInsertStr (buttonstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiButtonPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
	{
		BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub->CtrlStub;
		if (buttonstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(buttonstub->PostKeyHookProc) + 64);
			BackendInsertStr (buttonstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiButtonClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("BUTTONSTUB")) == 0))
	{
		BUTTONSTUB* buttonstub = (BUTTONSTUB*) ctrlstub->CtrlStub;
		if (buttonstub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(buttonstub->ClickedHookProc) + 64);
			BackendInsertStr (buttonstub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 GROUPBOX CONTROL API
 * ---------------------------------------------------------------------
 */

void
ApiGroupboxNew(int argc, const TCHAR* argv[])
{
	if (argc == 8)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  box;
		unsigned long wndnr;
		int    x, y, w, h;
		int    sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &sflags);
		stscanf(argv[7], _T("%d"), &cflags);

		box = GroupboxNew(
			ApiLookupWindow(wndnr),
			argv[1],
			x, y, w, h,
			sflags, cflags);

		stub = StubCreate(box);
		if (stub)
		{
			stub->CtrlStubClass = _T("GROUPBOXSTUB");

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 *                 RADIO CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	RADIO_SETFOCUS = 0,
	RADIO_KILLFOCUS,
	RADIO_PREKEY,
	RADIO_POSTKEY,
	RADIO_CLICKED,
} RADIOHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ClickedHookProc;      /* changed hook function */
} RADIOSTUB;

static void ApiRadioSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiRadioKillFocusHook(void* win, void* ctrl);
static int  ApiRadioPreKeyHook(void* win, void* ctrl, int key);
static int  ApiRadioPostKeyHook(void* win, void* ctrl, int key);
static void ApiRadioClickedHook(void* win, void* ctrl);
static void ApiRadioFreeStub(void* ctrlstub);

void
ApiRadioNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  radio;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		radio = RadioNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(radio);
		if (stub)
		{
			stub->CtrlStubClass = _T("RADIOSTUB");
			stub->CtrlStub = malloc(sizeof(RADIOSTUB));
			memset(stub->CtrlStub, 0, sizeof(RADIOSTUB));
			stub->CtrlStubDelete = ApiRadioFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiRadioSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= RADIO_SETFOCUS) && (hook <= RADIO_CLICKED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("RADIOSTUB")) == 0))
			{
				RADIOSTUB* radiostub = (RADIOSTUB*) winstub->CtrlStub;

				switch((RADIOHOOKTYPE) hook)
				{
				case RADIO_SETFOCUS:
					StubSetProc(&radiostub->SetFocusHookProc, procname);
					if (radiostub->SetFocusHookProc)
					{
						RadioSetSetFocusHook(winstub->Window, ApiRadioSetFocusHook, targetwin->Window);
					}
					else
					{
						RadioSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case RADIO_KILLFOCUS:
					StubSetProc(&radiostub->KillFocusHookProc, procname);
					if (radiostub->KillFocusHookProc)
					{
						RadioSetKillFocusHook(winstub->Window, ApiRadioKillFocusHook, targetwin->Window);
					}
					else
					{
						RadioSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case RADIO_PREKEY:
					StubSetProc(&radiostub->PreKeyHookProc, procname);
					if (radiostub->PreKeyHookProc)
					{
						RadioSetPreKeyHook(winstub->Window, ApiRadioPreKeyHook, targetwin->Window);
					}
					else
					{
						RadioSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case RADIO_POSTKEY:
					StubSetProc(&radiostub->PostKeyHookProc, procname);
					if (radiostub->PostKeyHookProc)
					{
						RadioSetPostKeyHook(winstub->Window, ApiRadioPostKeyHook, targetwin->Window);
					}
					else
					{
						RadioSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case RADIO_CLICKED:
					StubSetProc(&radiostub->ClickedHookProc, procname);
					if (radiostub->ClickedHookProc)
					{
						RadioSetClickedHook(winstub->Window, ApiRadioClickedHook, targetwin->Window);
					}
					else
					{
						RadioSetClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiRadioSetCheck(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           check;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &check);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			RadioSetCheck(winstub->Window, check);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiRadioGetCheck(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (RadioGetCheck(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiRadioFreeStub(void* ctrlstub)
{
	RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub;
	if (radiostub)
	{
		if (radiostub->SetFocusHookProc)  free(radiostub->SetFocusHookProc);
		if (radiostub->KillFocusHookProc) free(radiostub->KillFocusHookProc);
		if (radiostub->PreKeyHookProc)    free(radiostub->PreKeyHookProc);
		if (radiostub->PostKeyHookProc)   free(radiostub->PostKeyHookProc);
		if (radiostub->ClickedHookProc)   free(radiostub->ClickedHookProc);
		free(radiostub);
	}
}

static void
ApiRadioSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("RADIOSTUB")) == 0))
	{
		RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub->CtrlStub;
		if (radiostub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(radiostub->SetFocusHookProc) + 64);
			BackendInsertStr (radiostub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiRadioKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("RADIOSTUB")) == 0))
	{
		RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub->CtrlStub;
		if (radiostub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(radiostub->KillFocusHookProc) + 64);
			BackendInsertStr (radiostub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiRadioPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("RADIOSTUB")) == 0))
	{
		RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub->CtrlStub;
		if (radiostub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(radiostub->PreKeyHookProc) + 64);
			BackendInsertStr (radiostub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiRadioPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("RADIOBOXSTUB")) == 0))
	{
		RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub->CtrlStub;
		if (radiostub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(radiostub->PostKeyHookProc) + 64);
			BackendInsertStr (radiostub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiRadioClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("RADIOSTUB")) == 0))
	{
		RADIOSTUB* radiostub = (RADIOSTUB*) ctrlstub->CtrlStub;
		if (radiostub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(radiostub->ClickedHookProc) + 64);
			BackendInsertStr (radiostub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 CHECKBOX CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	CHECKBOX_SETFOCUS = 0,
	CHECKBOX_KILLFOCUS,
	CHECKBOX_PREKEY,
	CHECKBOX_POSTKEY,
	CHECKBOX_CLICKED,
} CHECKBOXHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ClickedHookProc;      /* changed hook function */
} CHECKBOXSTUB;

static void ApiCheckboxSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiCheckboxKillFocusHook(void* win, void* ctrl);
static int  ApiCheckboxPreKeyHook(void* win, void* ctrl, int key);
static int  ApiCheckboxPostKeyHook(void* win, void* ctrl, int key);
static void ApiCheckboxClickedHook(void* win, void* ctrl);
static void ApiCheckboxFreeStub(void* ctrlstub);

void
ApiCheckboxNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  checkbox;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		checkbox = CheckboxNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(checkbox);
		if (stub)
		{
			stub->CtrlStubClass = _T("CHECKBOXSTUB");
			stub->CtrlStub = malloc(sizeof(CHECKBOXSTUB));
			memset(stub->CtrlStub, 0, sizeof(CHECKBOXSTUB));
			stub->CtrlStubDelete = ApiCheckboxFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiCheckboxSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= CHECKBOX_SETFOCUS) && (hook <= CHECKBOX_CLICKED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
			{
				CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) winstub->CtrlStub;

				switch((CHECKBOXHOOKTYPE) hook)
				{
				case CHECKBOX_SETFOCUS:
					StubSetProc(&checkboxstub->SetFocusHookProc, procname);
					if (checkboxstub->SetFocusHookProc)
					{
						CheckboxSetSetFocusHook(winstub->Window, ApiCheckboxSetFocusHook, targetwin->Window);
					}
					else
					{
						CheckboxSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case CHECKBOX_KILLFOCUS:
					StubSetProc(&checkboxstub->KillFocusHookProc, procname);
					if (checkboxstub->KillFocusHookProc)
					{
						CheckboxSetKillFocusHook(winstub->Window, ApiCheckboxKillFocusHook, targetwin->Window);
					}
					else
					{
						CheckboxSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case CHECKBOX_PREKEY:
					StubSetProc(&checkboxstub->PreKeyHookProc, procname);
					if (checkboxstub->PreKeyHookProc)
					{
						CheckboxSetPreKeyHook(winstub->Window, ApiCheckboxPreKeyHook, targetwin->Window);
					}
					else
					{
						CheckboxSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case CHECKBOX_POSTKEY:
					StubSetProc(&checkboxstub->PostKeyHookProc, procname);
					if (checkboxstub->PostKeyHookProc)
					{
						CheckboxSetPostKeyHook(winstub->Window, ApiCheckboxPostKeyHook, targetwin->Window);
					}
					else
					{
						CheckboxSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case CHECKBOX_CLICKED:
					StubSetProc(&checkboxstub->ClickedHookProc, procname);
					if (checkboxstub->ClickedHookProc)
					{
						CheckboxSetClickedHook(winstub->Window, ApiCheckboxClickedHook, targetwin->Window);
					}
					else
					{
						CheckboxSetClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}
				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiCheckboxSetCheck(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           check;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &check);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			CheckboxSetCheck(winstub->Window, check);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiCheckboxGetCheck(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (CheckboxGetCheck(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiCheckboxFreeStub(void* ctrlstub)
{
	CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub;
	if (checkboxstub)
	{
		if (checkboxstub->SetFocusHookProc)  free(checkboxstub->SetFocusHookProc);
		if (checkboxstub->KillFocusHookProc) free(checkboxstub->KillFocusHookProc);
		if (checkboxstub->PreKeyHookProc)    free(checkboxstub->PreKeyHookProc);
		if (checkboxstub->PostKeyHookProc)   free(checkboxstub->PostKeyHookProc);
		if (checkboxstub->ClickedHookProc)   free(checkboxstub->ClickedHookProc);
		free(checkboxstub);
	}
}

static void
ApiCheckboxSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
	{
		CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub->CtrlStub;
		if (checkboxstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(checkboxstub->SetFocusHookProc) + 64);
			BackendInsertStr (checkboxstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiCheckboxKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
	{
		CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub->CtrlStub;
		if (checkboxstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(checkboxstub->KillFocusHookProc) + 64);
			BackendInsertStr (checkboxstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiCheckboxPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
	{
		CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub->CtrlStub;
		if (checkboxstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(checkboxstub->PreKeyHookProc) + 64);
			BackendInsertStr (checkboxstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiCheckboxPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
	{
		CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub->CtrlStub;
		if (checkboxstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(checkboxstub->PostKeyHookProc) + 64);
			BackendInsertStr (checkboxstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiCheckboxClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("CHECKBOXSTUB")) == 0))
	{
		CHECKBOXSTUB* checkboxstub = (CHECKBOXSTUB*) ctrlstub->CtrlStub;
		if (checkboxstub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(checkboxstub->ClickedHookProc) + 64);
			BackendInsertStr (checkboxstub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 LISTBOX CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	LISTBOX_SETFOCUS = 0,
	LISTBOX_KILLFOCUS,
	LISTBOX_PREKEY,
	LISTBOX_POSTKEY,
	LISTBOX_CHANGED,
	LISTBOX_CHANGING,
	LISTBOX_CLICKED,
} LISTBOXHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ChangedHookProc;      /* control lost input focus */
	TCHAR*      ChangingHookProc;     /* control lost input focus */
	TCHAR*      ClickedHookProc;      /* changed hook function */
} LISTBOXSTUB;

static void ApiListboxSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiListboxKillFocusHook(void* win, void* ctrl);
static int  ApiListboxPreKeyHook(void* win, void* ctrl, int key);
static int  ApiListboxPostKeyHook(void* win, void* ctrl, int key);
static void ApiListboxChangedHook(void* win, void* ctrl);
static int  ApiListboxChangingHook(void* win, void* ctrl);
static void ApiListboxClickedHook(void* win, void* ctrl);
static void ApiListboxFreeStub(void* ctrlstub);

void
ApiListboxNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  listbox;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		listbox = ListboxNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(listbox);
		if (stub)
		{
			stub->CtrlStubClass = _T("LISTBOXSTUB");
			stub->CtrlStub = malloc(sizeof(LISTBOXSTUB));
			memset(stub->CtrlStub, 0, sizeof(LISTBOXSTUB));
			stub->CtrlStubDelete = ApiListboxFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*    winstub;
		WINDOWSTUB*    targetwin;
		unsigned long  wndnr;
		unsigned long  target;
		int            hook;
		const TCHAR*   procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= LISTBOX_SETFOCUS) && (hook <= LISTBOX_CLICKED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
			{
				LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) winstub->CtrlStub;

				switch((LISTBOXHOOKTYPE) hook)
				{
				case LISTBOX_SETFOCUS:
					StubSetProc(&listboxstub->SetFocusHookProc, procname);
					if (listboxstub->SetFocusHookProc)
					{
						ListboxSetSetFocusHook(winstub->Window, ApiListboxSetFocusHook, targetwin->Window);
					}
					else
					{
						ListboxSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_KILLFOCUS:
					StubSetProc(&listboxstub->KillFocusHookProc, procname);
					if (listboxstub->KillFocusHookProc)
					{
						ListboxSetKillFocusHook(winstub->Window, ApiListboxKillFocusHook, targetwin->Window);
					}
					else
					{
						ListboxSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_PREKEY:
					StubSetProc(&listboxstub->PreKeyHookProc, procname);
					if (listboxstub->PreKeyHookProc)
					{
						ListboxSetPreKeyHook(winstub->Window, ApiListboxPreKeyHook, targetwin->Window);
					}
					else
					{
						ListboxSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_POSTKEY:
					StubSetProc(&listboxstub->PostKeyHookProc, procname);
					if (listboxstub->PostKeyHookProc)
					{
						ListboxSetPostKeyHook(winstub->Window, ApiListboxPostKeyHook, targetwin->Window);
					}
					else
					{
						ListboxSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_CHANGED:
					StubSetProc(&listboxstub->ChangedHookProc, procname);
					if (listboxstub->ChangedHookProc)
					{
						ListboxSetLbChangedHook(winstub->Window, ApiListboxChangedHook, targetwin->Window);
					}
					else
					{
						ListboxSetLbChangedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_CHANGING:
					StubSetProc(&listboxstub->ChangingHookProc, procname);
					if (listboxstub->ChangingHookProc)
					{
						ListboxSetLbChangingHook(winstub->Window, ApiListboxChangingHook, targetwin->Window);
					}
					else
					{
						ListboxSetLbChangingHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTBOX_CLICKED:
					StubSetProc(&listboxstub->ClickedHookProc, procname);
					if (listboxstub->ClickedHookProc)
					{
						ListboxSetLbClickedHook(winstub->Window, ApiListboxClickedHook, targetwin->Window);
					}
					else
					{
						ListboxSetLbClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxAdd(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListboxAdd(winstub->Window, argv[1]));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxDelete(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListboxDelete(winstub->Window, index);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxGet(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			const TCHAR* data   = ListboxGet(winstub->Window, index);
			int          len    = tcslen(data);

			BackendStartFrame(_T('R'), len + 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertStr (data);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxSetData(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		unsigned long data;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &index);
		stscanf(argv[2], _T("%ld"), &data);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListboxSetData(winstub->Window, index, data);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxGetData(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong(ListboxGetData(winstub->Window, index));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxSetSel(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListboxSetSel(winstub->Window, index);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxGetSel(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListboxGetSel(winstub->Window));
			BackendSendFrame ();			
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxClear(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListboxClear(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxGetCount(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListboxGetCount(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListboxSelect(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListboxSelect(winstub->Window, argv[1]));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiListboxFreeStub(void* ctrlstub)
{
	LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub;
	if (listboxstub)
	{
		if (listboxstub->SetFocusHookProc)  free(listboxstub->SetFocusHookProc);
		if (listboxstub->KillFocusHookProc) free(listboxstub->KillFocusHookProc);
		if (listboxstub->PreKeyHookProc)    free(listboxstub->PreKeyHookProc);
		if (listboxstub->PostKeyHookProc)   free(listboxstub->PostKeyHookProc);
		if (listboxstub->ChangedHookProc)   free(listboxstub->ChangedHookProc);
		if (listboxstub->ChangingHookProc)  free(listboxstub->ChangingHookProc);
		if (listboxstub->ClickedHookProc)   free(listboxstub->ClickedHookProc);
		free(listboxstub);
	}
}

static void
ApiListboxSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(listboxstub->SetFocusHookProc) + 64);
			BackendInsertStr (listboxstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiListboxKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->KillFocusHookProc) + 64);
			BackendInsertStr (listboxstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiListboxPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->PreKeyHookProc) + 64);
			BackendInsertStr (listboxstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiListboxPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->PostKeyHookProc) + 64);
			BackendInsertStr (listboxstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiListboxChangedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->ChangedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->ChangedHookProc) + 64);
			BackendInsertStr (listboxstub->ChangedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiListboxChangingHook(void* win, void* ctrl)
{
	int result = TRUE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->ChangingHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->ChangingHookProc) + 64);
			BackendInsertStr (listboxstub->ChangingHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("0")) == 0))
			{
				result = FALSE;
			}
		}
	}
	return result;
}

static void
ApiListboxClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTBOXSTUB")) == 0))
	{
		LISTBOXSTUB* listboxstub = (LISTBOXSTUB*) ctrlstub->CtrlStub;
		if (listboxstub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listboxstub->ClickedHookProc) + 64);
			BackendInsertStr (listboxstub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 COMBOBOX CONTROL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	COMBOBOX_SETFOCUS = 0,
	COMBOBOX_KILLFOCUS,
	COMBOBOX_PREKEY,
	COMBOBOX_POSTKEY,
	COMBOBOX_CHANGED,
	COMBOBOX_CHANGING
} COMBOBOXHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ChangedHookProc;      /* control lost input focus */
	TCHAR*      ChangingHookProc;     /* control lost input focus */
} COMBOBOXSTUB;

static void ApiComboboxSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiComboboxKillFocusHook(void* win, void* ctrl);
static int  ApiComboboxPreKeyHook(void* win, void* ctrl, int key);
static int  ApiComboboxPostKeyHook(void* win, void* ctrl, int key);
static void ApiComboboxChangedHook(void* win, void* ctrl);
static int  ApiComboboxChangingHook(void* win, void* ctrl);
static void ApiComboboxFreeStub(void* ctrlstub);

void
ApiComboboxNew(int argc, const TCHAR* argv[])
{
	if (argc == 8)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  combobox;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &x);
		stscanf(argv[2], _T("%d"), &y);
		stscanf(argv[3], _T("%d"), &w);
		stscanf(argv[4], _T("%d"), &h);
		stscanf(argv[5], _T("%d"), &id);
		stscanf(argv[6], _T("%d"), &sflags);
		stscanf(argv[7], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		combobox = ComboboxNew(
			win,
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(combobox);
		if (stub)
		{
			stub->CtrlStubClass = _T("COMBOBOXSTUB");
			stub->CtrlStub = malloc(sizeof(COMBOBOXSTUB));
			memset(stub->CtrlStub, 0, sizeof(COMBOBOXSTUB));
			stub->CtrlStubDelete = ApiComboboxFreeStub;

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= COMBOBOX_SETFOCUS) && (hook <= COMBOBOX_CHANGING))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
			{
				COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) winstub->CtrlStub;

				switch((COMBOBOXHOOKTYPE) hook)
				{
				case COMBOBOX_SETFOCUS:
					StubSetProc(&comboboxstub->SetFocusHookProc, procname);
					if (comboboxstub->SetFocusHookProc)
					{
						ComboboxSetSetFocusHook(winstub->Window, ApiComboboxSetFocusHook, targetwin->Window);
					}
					else
					{
						ComboboxSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case COMBOBOX_KILLFOCUS:
					StubSetProc(&comboboxstub->KillFocusHookProc, procname);
					if (comboboxstub->KillFocusHookProc)
					{
						ComboboxSetKillFocusHook(winstub->Window, ApiComboboxKillFocusHook, targetwin->Window);
					}
					else
					{
						ComboboxSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case COMBOBOX_PREKEY:
					StubSetProc(&comboboxstub->PreKeyHookProc, procname);
					if (comboboxstub->PreKeyHookProc)
					{
						ComboboxSetPreKeyHook(winstub->Window, ApiComboboxPreKeyHook, targetwin->Window);
					}
					else
					{
						ComboboxSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case COMBOBOX_POSTKEY:
					StubSetProc(&comboboxstub->PostKeyHookProc, procname);
					if (comboboxstub->PostKeyHookProc)
					{
						ComboboxSetPostKeyHook(winstub->Window, ApiComboboxPostKeyHook, targetwin->Window);
					}
					else
					{
						ComboboxSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case COMBOBOX_CHANGED:
					StubSetProc(&comboboxstub->ChangedHookProc, procname);
					if (comboboxstub->ChangedHookProc)
					{
						ComboboxSetCbChangedHook(winstub->Window, ApiComboboxChangedHook, targetwin->Window);
					}
					else
					{
						ComboboxSetCbChangedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case COMBOBOX_CHANGING:
					StubSetProc(&comboboxstub->ChangingHookProc, procname);
					if (comboboxstub->ChangingHookProc)
					{
						ComboboxSetCbChangingHook(winstub->Window, ApiComboboxChangingHook, targetwin->Window);
					}
					else
					{
						ComboboxSetCbChangingHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxAdd(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ComboboxAdd(winstub->Window, argv[1]));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxDelete(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ComboboxDelete(winstub->Window, index);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxGet(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			const TCHAR* data   = ComboboxGet(winstub->Window, index);
			int          len    = tcslen(data);

			BackendStartFrame(_T('R'), len + 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertStr (data);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxSetData(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		unsigned long data;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &index);
		stscanf(argv[2], _T("%ld"), &data);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ComboboxSetData(winstub->Window, index, data);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxGetData(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong(ComboboxGetData(winstub->Window, index));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxSetSel(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ComboboxSetSel(winstub->Window, index);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxGetSel(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ComboboxGetSel(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxClear(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ComboboxClear(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxGetCount(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ComboboxGetCount(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiComboboxSelect(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ComboboxSelect(winstub->Window, argv[1]));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiComboboxFreeStub(void* ctrlstub)
{
	COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub;
	if (comboboxstub)
	{
		if (comboboxstub->SetFocusHookProc)  free(comboboxstub->SetFocusHookProc);
		if (comboboxstub->KillFocusHookProc) free(comboboxstub->KillFocusHookProc);
		if (comboboxstub->PreKeyHookProc)    free(comboboxstub->PreKeyHookProc);
		if (comboboxstub->PostKeyHookProc)   free(comboboxstub->PostKeyHookProc);
		if (comboboxstub->ChangedHookProc)   free(comboboxstub->ChangedHookProc);
		if (comboboxstub->ChangingHookProc)  free(comboboxstub->ChangingHookProc);
		free(comboboxstub);
	}
}

static void
ApiComboboxSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(comboboxstub->SetFocusHookProc) + 64);
			BackendInsertStr (comboboxstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiComboboxKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(comboboxstub->KillFocusHookProc) + 64);
			BackendInsertStr (comboboxstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiComboboxPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(comboboxstub->PreKeyHookProc) + 64);
			BackendInsertStr (comboboxstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiComboboxPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(comboboxstub->PostKeyHookProc) + 64);
			BackendInsertStr (comboboxstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiComboboxChangedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->ChangedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(comboboxstub->ChangedHookProc) + 64);
			BackendInsertStr (comboboxstub->ChangedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiComboboxChangingHook(void* win, void* ctrl)
{
	int result = TRUE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("COMBOBOXSTUB")) == 0))
	{
		COMBOBOXSTUB* comboboxstub = (COMBOBOXSTUB*) ctrlstub->CtrlStub;
		if (comboboxstub->ChangingHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(comboboxstub->ChangingHookProc) + 64);
			BackendInsertStr (comboboxstub->ChangingHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("0")) == 0))
			{
				result = FALSE;
			}
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 *                 PROGRESSBAR CONTROL API
 * ---------------------------------------------------------------------
 */

void
ApiProgressbarNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  progressbar;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		progressbar = ProgressbarNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(progressbar);
		if (stub)
		{
			stub->CtrlStubClass = _T("PROGRESSBARSTUB");

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiProgressbarSetRange(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           range;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &range);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ProgressbarSetRange(winstub->Window, range);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiProgressbarSetPos(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           pos;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &pos);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ProgressbarSetPos(winstub->Window, pos);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiProgressbarGetRange(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ProgressbarGetRange(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiProgressbarGetPos(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		int           index;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ProgressbarGetPos(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 *                 TEXTVIEW API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	TEXTVIEW_SETFOCUS = 0,
	TEXTVIEW_KILLFOCUS,
	TEXTVIEW_PREKEY,
	TEXTVIEW_POSTKEY
} TEXTVIEWHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
} TEXTVIEWSTUB;

static void ApiTextviewSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiTextviewKillFocusHook(void* win, void* ctrl);
static int  ApiTextviewPreKeyHook(void* win, void* ctrl, int key);
static int  ApiTextviewPostKeyHook(void* win, void* ctrl, int key);
static void ApiTextviewFreeStub(void* ctrlstub);

void
ApiTextviewNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  textview;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		textview = TextviewNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(textview);
		if (stub)
		{
			stub->CtrlStubClass = _T("TEXTVIEWSTUB");
			stub->CtrlStub = malloc(sizeof(TEXTVIEWSTUB));
			memset(stub->CtrlStub, 0, sizeof(TEXTVIEWSTUB));
			stub->CtrlStubDelete = ApiTextviewFreeStub;

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= TEXTVIEW_SETFOCUS) && (hook <= TEXTVIEW_POSTKEY))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("TEXTVIEWSTUB")) == 0))
			{
				TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) winstub->CtrlStub;

				switch((TEXTVIEWHOOKTYPE) hook)
				{
				case TEXTVIEW_SETFOCUS:
					StubSetProc(&textviewstub->SetFocusHookProc, procname);
					if (textviewstub->SetFocusHookProc)
					{
						TextviewSetSetFocusHook(winstub->Window, ApiTextviewSetFocusHook, targetwin->Window);
					}
					else
					{
						TextviewSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TEXTVIEW_KILLFOCUS:
					StubSetProc(&textviewstub->KillFocusHookProc, procname);
					if (textviewstub->KillFocusHookProc)
					{
						TextviewSetKillFocusHook(winstub->Window, ApiTextviewKillFocusHook, targetwin->Window);
					}
					else
					{
						TextviewSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TEXTVIEW_PREKEY:
					StubSetProc(&textviewstub->PreKeyHookProc, procname);
					if (textviewstub->PreKeyHookProc)
					{
						TextviewSetPreKeyHook(winstub->Window, ApiTextviewPreKeyHook, targetwin->Window);
					}
					else
					{
						TextviewSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TEXTVIEW_POSTKEY:
					StubSetProc(&textviewstub->PostKeyHookProc, procname);
					if (textviewstub->PostKeyHookProc)
					{
						TextviewSetPostKeyHook(winstub->Window, ApiTextviewPostKeyHook, targetwin->Window);
					}
					else
					{
						TextviewSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewEnableWordWrap(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           enable;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &enable);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TextviewEnableWordWrap(winstub->Window, enable);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewAdd(int argc, const TCHAR* argv[])
{
	if ((argc == 2) || (argc == 3)) /* simply ignore "doupdate" parameter */
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TextviewAdd(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewClear(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TextviewClear(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewRead(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (TextviewRead(winstub->Window, argv[1]));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTextviewSearch(int argc, const TCHAR* argv[])
{
	if (argc == 5)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           wholeword;
		int           casesens;
		int           down;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &wholeword);
		stscanf(argv[3], _T("%d"), &casesens);
		stscanf(argv[4], _T("%d"), &down);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (TextviewSearch(winstub->Window, argv[1],
				wholeword, casesens, down));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiTextviewFreeStub(void* ctrlstub)
{
	TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) ctrlstub;
	if (textviewstub)
	{
		if (textviewstub->SetFocusHookProc)  free(textviewstub->SetFocusHookProc);
		if (textviewstub->KillFocusHookProc) free(textviewstub->KillFocusHookProc);
		if (textviewstub->PreKeyHookProc)    free(textviewstub->PreKeyHookProc);
		if (textviewstub->PostKeyHookProc)   free(textviewstub->PostKeyHookProc);
		free(textviewstub);
	}
}

static void
ApiTextviewSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TEXTVIEWSTUB")) == 0))
	{
		TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) ctrlstub->CtrlStub;
		if (textviewstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(textviewstub->SetFocusHookProc) + 64);
			BackendInsertStr (textviewstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiTextviewKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TEXTVIEWSTUB")) == 0))
	{
		TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) ctrlstub->CtrlStub;
		if (textviewstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(textviewstub->KillFocusHookProc) + 64);
			BackendInsertStr (textviewstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiTextviewPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TEXTVIEWSTUB")) == 0))
	{
		TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) ctrlstub->CtrlStub;
		if (textviewstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(textviewstub->PreKeyHookProc) + 64);
			BackendInsertStr (textviewstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiTextviewPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TEXTVIEWSTUB")) == 0))
	{
		TEXTVIEWSTUB* textviewstub = (TEXTVIEWSTUB*) ctrlstub->CtrlStub;
		if (textviewstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(textviewstub->PostKeyHookProc) + 64);
			BackendInsertStr (textviewstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}



/* ---------------------------------------------------------------------
 *                 LISTVIEW API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	LISTVIEW_SETFOCUS = 0,
	LISTVIEW_KILLFOCUS,
	LISTVIEW_PREKEY,
	LISTVIEW_POSTKEY,
	LISTVIEW_CHANGED,
	LISTVIEW_CHANGING,
	LISTVIEW_CLICKED
} LISTVIEWHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ChangedHookProc;      /* selection has been changed */
	TCHAR*      ChangingHookProc;     /* selection is beeing changed */
	TCHAR*      ClickedHookProc;      /* record has been selected/clicked */
} LISTVIEWSTUB;

static void ApiListviewSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiListviewKillFocusHook(void* win, void* ctrl);
static int  ApiListviewPreKeyHook(void* win, void* ctrl, int key);
static int  ApiListviewPostKeyHook(void* win, void* ctrl, int key);
static void ApiListviewChangedHook(void* win, void* ctrl);
static int  ApiListviewChangingHook(void* win, void* ctrl);
static void ApiListviewClickedHook(void* win, void* ctrl);
static void ApiListviewFreeStub(void* ctrlstub);

void
ApiListviewNew(int argc, const TCHAR* argv[])
{
	if (argc == 10)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  listview;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   cols;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &cols);
		stscanf(argv[7], _T("%d"), &id);
		stscanf(argv[8], _T("%d"), &sflags);
		stscanf(argv[9], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		listview = ListviewNew(
			win,
			argv[1],
			x, y, w, h, cols, id,
			sflags, cflags);

		stub = StubCreate(listview);
		if (stub)
		{
			stub->CtrlStubClass = _T("LISTVIEWSTUB");
			stub->CtrlStub = malloc(sizeof(LISTVIEWSTUB));
			memset(stub->CtrlStub, 0, sizeof(LISTVIEWSTUB));
			stub->CtrlStubDelete = ApiListviewFreeStub;

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListviewSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= LISTVIEW_SETFOCUS) && (hook <= LISTVIEW_CLICKED))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
			{
				LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) winstub->CtrlStub;

				switch((LISTVIEWHOOKTYPE) hook)
				{
				case LISTVIEW_SETFOCUS:
					StubSetProc(&listviewstub->SetFocusHookProc, procname);
					if (listviewstub->SetFocusHookProc)
					{
						ListviewSetSetFocusHook(winstub->Window, ApiListviewSetFocusHook, targetwin->Window);
					}
					else
					{
						ListviewSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_KILLFOCUS:
					StubSetProc(&listviewstub->KillFocusHookProc, procname);
					if (listviewstub->KillFocusHookProc)
					{
						ListviewSetKillFocusHook(winstub->Window, ApiListviewKillFocusHook, targetwin->Window);
					}
					else
					{
						ListviewSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_PREKEY:
					StubSetProc(&listviewstub->PreKeyHookProc, procname);
					if (listviewstub->PreKeyHookProc)
					{
						ListviewSetPreKeyHook(winstub->Window, ApiListviewPreKeyHook, targetwin->Window);
					}
					else
					{
						ListviewSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_POSTKEY:
					StubSetProc(&listviewstub->PostKeyHookProc, procname);
					if (listviewstub->PostKeyHookProc)
					{
						ListviewSetPostKeyHook(winstub->Window, ApiListviewPostKeyHook, targetwin->Window);
					}
					else
					{
						ListviewSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_CHANGED:
					StubSetProc(&listviewstub->ChangedHookProc, procname);
					if (listviewstub->ChangedHookProc)
					{
						ListviewSetLbChangedHook(winstub->Window, ApiListviewChangedHook, targetwin->Window);
					}
					else
					{
						ListviewSetLbChangedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_CHANGING:
					StubSetProc(&listviewstub->ChangingHookProc, procname);
					if (listviewstub->ChangingHookProc)
					{
						ListviewSetLbChangingHook(winstub->Window, ApiListviewChangingHook, targetwin->Window);
					}
					else
					{
						ListviewSetLbChangingHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case LISTVIEW_CLICKED:
					StubSetProc(&listviewstub->ClickedHookProc, procname);
					if (listviewstub->ClickedHookProc)
					{
						ListviewSetLbClickedHook(winstub->Window, ApiListviewClickedHook, targetwin->Window);
					}
					else
					{
						ListviewSetLbClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}
				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewAddColumn(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           colnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &colnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListviewAddColumn(winstub->Window, colnr, argv[2]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewSetTitleAlignment(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           colnr;
		int           align;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &colnr);
		stscanf(argv[2], _T("%d"),  &align);

		winstub = StubFind(wndnr);
		if (winstub && (align >= ALIGN_CENTER) && (align <= ALIGN_RIGHT))
		{
			ListviewSetTitleAlignment(
				winstub->Window, 
				colnr, 
				(ALIGNMENT_T) align);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewClear(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListviewClear(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewAdd(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			LISTREC* rec = ListviewCreateRecord(winstub->Window);
			if (rec)
			{
				BackendStartFrame(_T('R'), 48);
				BackendInsertInt (ERROR_SUCCESS);
				BackendInsertInt (ListviewInsertRecord(winstub->Window, rec));
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewSetText(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;
		int           colnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);
		stscanf(argv[2], _T("%d"), &colnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			LISTREC* rec = ListviewGetRecord(winstub->Window, index);
			if (rec)
			{
				ListviewSetColumnText(rec, colnr, argv[3]);
			}
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewGetText(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;
		int           colnr;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);
		stscanf(argv[2], _T("%d"), &colnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			LISTREC*     rec = ListviewGetRecord(winstub->Window, index);
			const TCHAR* text = _T("");
			int          len = 0;

			if (rec)
			{
				text = ListviewGetColumnText(rec, colnr);
				len = tcslen(text);
			}
			BackendStartFrame(_T('R'), len + 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertStr (text);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewSetData(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		unsigned long data;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);
		stscanf(argv[2], _T("%ld"), &data);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			LISTREC* rec = ListviewGetRecord(winstub->Window, index);
			if (rec)
			{
				rec->Data = data;
			}
			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiListviewGetData(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			LISTREC* rec = ListviewGetRecord(winstub->Window, index);
			unsigned long data = 0;
			if (rec)
			{
				data = rec->Data;
			}
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong(data);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListviewSetSel(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           index;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &index);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListviewSetSel(winstub->Window, index);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListviewGetSel(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListviewGetSel(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListviewGetCount(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (ListviewGetCount(winstub->Window));
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiListviewUpdate(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			/* ListviewUpdate(winstub->Window); // no longer exists! */ 

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void 
ApiListviewAlphaSort(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           colnr;
		int           up;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &colnr);
		stscanf(argv[2], _T("%d"), &up); 

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListviewAlphaSort(winstub->Window, colnr, up);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void 
ApiListviewNumericSort(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           colnr;
		int           up;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"), &colnr);
		stscanf(argv[2], _T("%d"), &up); 

		winstub = StubFind(wndnr);
		if (winstub)
		{
			ListviewNumericSort(winstub->Window, colnr, up);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiListviewFreeStub(void* ctrlstub)
{
	LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub;
	if (listviewstub)
	{
		if (listviewstub->SetFocusHookProc)  free(listviewstub->SetFocusHookProc);
		if (listviewstub->KillFocusHookProc) free(listviewstub->KillFocusHookProc);
		if (listviewstub->PreKeyHookProc)    free(listviewstub->PreKeyHookProc);
		if (listviewstub->PostKeyHookProc)   free(listviewstub->PostKeyHookProc);
		if (listviewstub->ChangedHookProc)   free(listviewstub->ChangedHookProc);
		if (listviewstub->ChangingHookProc)  free(listviewstub->ChangingHookProc);
		if (listviewstub->ClickedHookProc)   free(listviewstub->ClickedHookProc);
		free(listviewstub);
	}
}

static void
ApiListviewSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(listviewstub->SetFocusHookProc) + 64);
			BackendInsertStr (listviewstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiListviewKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->KillFocusHookProc) + 64);
			BackendInsertStr (listviewstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiListviewPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->PreKeyHookProc) + 64);
			BackendInsertStr (listviewstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiListviewPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->PostKeyHookProc) + 64);
			BackendInsertStr (listviewstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiListviewChangedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->ChangedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->ChangedHookProc) + 64);
			BackendInsertStr (listviewstub->ChangedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiListviewChangingHook(void* win, void* ctrl)
{
	int result = TRUE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->ChangingHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->ChangingHookProc) + 64);
			BackendInsertStr (listviewstub->ChangingHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("0")) == 0))
			{
				result = FALSE;
			}
		}
	}
	return result;
}

static void
ApiListviewClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("LISTVIEWSTUB")) == 0))
	{
		LISTVIEWSTUB* listviewstub = (LISTVIEWSTUB*) ctrlstub->CtrlStub;
		if (listviewstub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(listviewstub->ClickedHookProc) + 64);
			BackendInsertStr (listviewstub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 TERMINAL API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	TERMINAL_SETFOCUS = 0,
	TERMINAL_KILLFOCUS,
	TERMINAL_PREKEY,
	TERMINAL_POSTKEY,
	TERMINAL_EXIT,
} TERMINALHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      CoProcExitHookProc;   /* co process has terminated */
} TERMINALSTUB;

static void ApiTerminalSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiTerminalKillFocusHook(void* win, void* ctrl);
static int  ApiTerminalPreKeyHook(void* win, void* ctrl, int key);
static int  ApiTerminalPostKeyHook(void* win, void* ctrl, int key);
static void ApiTerminalCoProcExitHook(void* win, void* ctrl, int exitcode);
static void ApiTerminalFreeStub(void* ctrlstub);

void
ApiTerminalNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  terminal;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		terminal = TerminalNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(terminal);
		if (stub)
		{
			stub->CtrlStubClass = _T("TERMINALSTUB");
			stub->CtrlStub = malloc(sizeof(TERMINALSTUB));
			memset(stub->CtrlStub, 0, sizeof(TERMINALSTUB));
			stub->CtrlStubDelete = ApiTerminalFreeStub;

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiTerminalSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= TERMINAL_SETFOCUS) && (hook <= TERMINAL_EXIT))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
			{
				TERMINALSTUB* terminalstub = (TERMINALSTUB*) winstub->CtrlStub;

				switch((TERMINALHOOKTYPE) hook)
				{
				case TERMINAL_SETFOCUS:
					StubSetProc(&terminalstub->SetFocusHookProc, procname);
					if (terminalstub->SetFocusHookProc)
					{
						TerminalSetSetFocusHook(winstub->Window, ApiTerminalSetFocusHook, targetwin->Window);
					}
					else
					{
						TerminalSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TERMINAL_KILLFOCUS:
					StubSetProc(&terminalstub->KillFocusHookProc, procname);
					if (terminalstub->KillFocusHookProc)
					{
						TerminalSetKillFocusHook(winstub->Window, ApiTerminalKillFocusHook, targetwin->Window);
					}
					else
					{
						TerminalSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TERMINAL_PREKEY:
					StubSetProc(&terminalstub->PreKeyHookProc, procname);
					if (terminalstub->PreKeyHookProc)
					{
						TerminalSetPreKeyHook(winstub->Window, ApiTerminalPreKeyHook, targetwin->Window);
					}
					else
					{
						TerminalSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TERMINAL_POSTKEY:
					StubSetProc(&terminalstub->PostKeyHookProc, procname);
					if (terminalstub->PostKeyHookProc)
					{
						TerminalSetPostKeyHook(winstub->Window, ApiTerminalPostKeyHook, targetwin->Window);
					}
					else
					{
						TerminalSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case TERMINAL_EXIT:
					StubSetProc(&terminalstub->CoProcExitHookProc, procname);
					if (terminalstub->CoProcExitHookProc)
					{
						TerminalSetCoProcExitHook(winstub->Window, ApiTerminalCoProcExitHook, targetwin->Window);
					}
					else
					{
						TerminalSetCoProcExitHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}

				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiTerminalWrite(int argc, const TCHAR* argv[])
{
	if ((argc == 2) || (argc == 3)) /* simply ignore "doupdate" parameter */
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TerminalWrite(winstub->Window, argv[1], tcslen(argv[1]));

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiTerminalRun(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			int r = TerminalRun(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (r);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiTerminalPipeData(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			TerminalPipeData(winstub->Window, argv[1]);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

static void
ApiTerminalFreeStub(void* ctrlstub)
{
	TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub;
	if (terminalstub)
	{
		if (terminalstub->SetFocusHookProc)   free(terminalstub->SetFocusHookProc);
		if (terminalstub->KillFocusHookProc)  free(terminalstub->KillFocusHookProc);
		if (terminalstub->PreKeyHookProc)     free(terminalstub->PreKeyHookProc);
		if (terminalstub->PostKeyHookProc)    free(terminalstub->PostKeyHookProc);
		if (terminalstub->CoProcExitHookProc) free(terminalstub->CoProcExitHookProc);
		free(terminalstub);
	}
}

static void
ApiTerminalSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
	{
		TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub->CtrlStub;
		if (terminalstub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(terminalstub->SetFocusHookProc) + 64);
			BackendInsertStr (terminalstub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiTerminalKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
	{
		TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub->CtrlStub;
		if (terminalstub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(terminalstub->KillFocusHookProc) + 64);
			BackendInsertStr (terminalstub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiTerminalPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
	{
		TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub->CtrlStub;
		if (terminalstub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(terminalstub->PreKeyHookProc) + 64);
			BackendInsertStr (terminalstub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiTerminalPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
	{
		TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub->CtrlStub;
		if (terminalstub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(terminalstub->PostKeyHookProc) + 64);
			BackendInsertStr (terminalstub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}


static void
ApiTerminalCoProcExitHook(void* win, void* ctrl, int exitcode)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("TERMINALSTUB")) == 0))
	{
		TERMINALSTUB* terminalstub = (TERMINALSTUB*) ctrlstub->CtrlStub;
		if (terminalstub->CoProcExitHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(terminalstub->CoProcExitHookProc) + 64);
			BackendInsertStr (terminalstub->CoProcExitHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (exitcode);
			BackendExecFrame ();
		}
	}
}


/* ---------------------------------------------------------------------
 *                 MENU API
 * ---------------------------------------------------------------------
 */

typedef enum
{
	MENU_SETFOCUS = 0,
	MENU_KILLFOCUS,
	MENU_PREKEY,
	MENU_POSTKEY,
	MENU_CHANGED,
	MENU_CHANGING,
	MENU_CLICKED,
	MENU_ESCAPE
} MENUHOOKTYPE;

typedef struct
{
	TCHAR*      SetFocusHookProc;     /* control got input focus */
	TCHAR*      KillFocusHookProc;    /* control lost input focus */
	TCHAR*      PreKeyHookProc;       /* control got input focus */
	TCHAR*      PostKeyHookProc;      /* control lost input focus */
	TCHAR*      ChangedHookProc;      /* selection changed */
	TCHAR*      ChangingHookProc;     /* selection is changing */
	TCHAR*      ClickedHookProc;      /* item has been clicked */
	TCHAR*      EscapeHookProc;       /* selection aborted due to escape key */
} MENUSTUB;

static void ApiMenuSetFocusHook(void* win, void* ctrl, void* oldfocus);
static void ApiMenuKillFocusHook(void* win, void* ctrl);
static int  ApiMenuPreKeyHook(void* win, void* ctrl, int key);
static int  ApiMenuPostKeyHook(void* win, void* ctrl, int key);
static void ApiMenuChangedHook(void* win, void* ctrl);
static int  ApiMenuChangingHook(void* win, void* ctrl);
static void ApiMenuClickedHook(void* win, void* ctrl);
static void ApiMenuEscapeHook(void* win, void* ctrl);
static void ApiMenuFreeStub(void* ctrlstub);

void
ApiMenuNew(int argc, const TCHAR* argv[])
{
	if (argc == 9)
	{
		WINDOWSTUB* stub;
		CUIWINDOW*  menu;
		CUIWINDOW*  win;
		unsigned long wndnr;
		int   x, y, w, h, id;
		int   sflags, cflags;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &x);
		stscanf(argv[3], _T("%d"), &y);
		stscanf(argv[4], _T("%d"), &w);
		stscanf(argv[5], _T("%d"), &h);
		stscanf(argv[6], _T("%d"), &id);
		stscanf(argv[7], _T("%d"), &sflags);
		stscanf(argv[8], _T("%d"), &cflags);

		win = ApiLookupWindow(wndnr);

		menu = MenuNew(
			win,
			argv[1],
			x, y, w, h, id,
			sflags, cflags);

		stub = StubCreate(menu);
		if (stub)
		{
			stub->CtrlStubClass = _T("MENUSTUB");
			stub->CtrlStub = malloc(sizeof(MENUSTUB));
			memset(stub->CtrlStub, 0, sizeof(MENUSTUB));
			stub->CtrlStubDelete = ApiMenuFreeStub;

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong((unsigned long) stub->Window);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void
ApiMenuSetCallback(int argc, const TCHAR* argv[])
{
	if (argc == 4)
	{
		WINDOWSTUB*   winstub;
		WINDOWSTUB*   targetwin;
		unsigned long wndnr;
		unsigned long target;
		int           hook;
		const TCHAR*  procname;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%d"),  &hook);
		stscanf(argv[2], _T("%ld"), &target);
		procname = argv[3];

		if ((hook >= MENU_SETFOCUS) && (hook <= MENU_ESCAPE))
		{
			winstub = StubFind(wndnr);
			targetwin = StubFind(target);
			if (targetwin && winstub && winstub->CtrlStubClass &&
			   (tcscmp(winstub->CtrlStubClass, _T("MENUSTUB")) == 0))
			{
				MENUSTUB* menustub = (MENUSTUB*) winstub->CtrlStub;

				switch((MENUHOOKTYPE) hook)
				{
				case MENU_SETFOCUS:
					StubSetProc(&menustub->SetFocusHookProc, procname);
					if (menustub->SetFocusHookProc)
					{
						MenuSetSetFocusHook(winstub->Window, ApiMenuSetFocusHook, targetwin->Window);
					}
					else
					{
						MenuSetSetFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_KILLFOCUS:
					StubSetProc(&menustub->KillFocusHookProc, procname);
					if (menustub->KillFocusHookProc)
					{
						MenuSetKillFocusHook(winstub->Window, ApiMenuKillFocusHook, targetwin->Window);
					}
					else
					{
						MenuSetKillFocusHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_PREKEY:
					StubSetProc(&menustub->PreKeyHookProc, procname);
					if (menustub->PreKeyHookProc)
					{
						MenuSetPreKeyHook(winstub->Window, ApiMenuPreKeyHook, targetwin->Window);
					}
					else
					{
						MenuSetPreKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_POSTKEY:
					StubSetProc(&menustub->PostKeyHookProc, procname);
					if (menustub->PostKeyHookProc)
					{
						MenuSetPostKeyHook(winstub->Window, ApiMenuPostKeyHook, targetwin->Window);
					}
					else
					{
						MenuSetPostKeyHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_CHANGED:
					StubSetProc(&menustub->ChangedHookProc, procname);
					if (menustub->ChangedHookProc)
					{
						MenuSetMenuChangedHook(winstub->Window, ApiMenuChangedHook, targetwin->Window);
					}
					else
					{
						MenuSetMenuChangedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_CHANGING:
					StubSetProc(&menustub->ChangingHookProc, procname);
					if (menustub->ChangingHookProc)
					{
						MenuSetMenuChangingHook(winstub->Window, ApiMenuChangingHook, targetwin->Window);
					}
					else
					{
						MenuSetMenuChangingHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_CLICKED:
					StubSetProc(&menustub->ClickedHookProc, procname);
					if (menustub->ClickedHookProc)
					{
						MenuSetMenuClickedHook(winstub->Window, ApiMenuClickedHook, targetwin->Window);
					}
					else
					{
						MenuSetMenuClickedHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				case MENU_ESCAPE:
					StubSetProc(&menustub->EscapeHookProc, procname);
					if (menustub->EscapeHookProc)
					{
						MenuSetMenuEscapeHook(winstub->Window, ApiMenuEscapeHook, targetwin->Window);
					}
					else
					{
						MenuSetMenuEscapeHook(winstub->Window, NULL, targetwin->Window);
					}
					break;
				}
				BackendStartFrame(_T('R'), 32);
				BackendInsertInt (ERROR_SUCCESS);
				BackendSendFrame ();
			}
			else
			{
				BackendWriteError(ERROR_INVALID);
			}
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiMenuAddItem(int argc, const TCHAR* argv[])
{
	if (argc == 3)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		int           id;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[2], _T("%d"), &id);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			MenuAddItem(winstub->Window, argv[1], id, FALSE);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiMenuAddSeparator(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			MenuAddSeparator(winstub->Window, FALSE);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiMenuSelectItem(int argc, const TCHAR* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;
		unsigned long id;

		stscanf(argv[0], _T("%ld"), &wndnr);
		stscanf(argv[1], _T("%ld"), &id);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			MenuSelectItem(winstub->Window, id);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiMenuGetSelectedItem(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			unsigned long id = 0;
			MENUITEM* item = MenuGetSelectedItem(winstub->Window);
			if (item)
			{
				id = item->ItemId;
			}
			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertLong(id);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

void ApiMenuClear(int argc, const TCHAR* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   winstub;
		unsigned long wndnr;

		stscanf(argv[0], _T("%ld"), &wndnr);

		winstub = StubFind(wndnr);
		if (winstub)
		{
			MenuClear(winstub->Window);

			BackendStartFrame(_T('R'), 32);
			BackendInsertInt (ERROR_SUCCESS);
			BackendSendFrame ();
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}


static void
ApiMenuFreeStub(void* ctrlstub)
{
	MENUSTUB* menustub = (MENUSTUB*) ctrlstub;
	if (menustub)
	{
		if (menustub->SetFocusHookProc)   free(menustub->SetFocusHookProc);
		if (menustub->KillFocusHookProc)  free(menustub->KillFocusHookProc);
		if (menustub->PreKeyHookProc)     free(menustub->PreKeyHookProc);
		if (menustub->PostKeyHookProc)    free(menustub->PostKeyHookProc);
		if (menustub->ChangedHookProc)    free(menustub->ChangedHookProc);
		if (menustub->ChangingHookProc)   free(menustub->ChangingHookProc);
		if (menustub->EscapeHookProc)     free(menustub->EscapeHookProc);
		free(menustub);
	}
}

static void
ApiMenuSetFocusHook(void* win, void* ctrl, void* oldfocus)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->SetFocusHookProc)
		{
			StubCheckStub(oldfocus);

			BackendStartFrame(_T('H'), tcslen(menustub->SetFocusHookProc) + 64);
			BackendInsertStr (menustub->SetFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertLong((unsigned long) oldfocus);
			BackendExecFrame ();
		}
	}
}

static void
ApiMenuKillFocusHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->KillFocusHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->KillFocusHookProc) + 64);
			BackendInsertStr (menustub->KillFocusHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiMenuPreKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->PreKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->PreKeyHookProc) + 64);
			BackendInsertStr (menustub->PreKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static int
ApiMenuPostKeyHook(void* win, void* ctrl, int key)
{
	int result = FALSE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->PostKeyHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->PostKeyHookProc) + 64);
			BackendInsertStr (menustub->PostKeyHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendInsertInt (key);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("1")) == 0))
			{
				result = TRUE;
			}
		}
	}
	return result;
}

static void
ApiMenuChangedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->ChangedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->ChangedHookProc) + 64);
			BackendInsertStr (menustub->ChangedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static int
ApiMenuChangingHook(void* win, void* ctrl)
{
	int result = TRUE;

	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->ChangingHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->ChangingHookProc) + 64);
			BackendInsertStr (menustub->ChangingHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
			if ((BackendNumResultParams() > 0) && (tcscmp(BackendResultParam(0), _T("0")) == 0))
			{
				result = FALSE;
			}
		}
	}
	return result;
}

static void
ApiMenuClickedHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->ClickedHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->ClickedHookProc) + 64);
			BackendInsertStr (menustub->ClickedHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

static void
ApiMenuEscapeHook(void* win, void* ctrl)
{
	WINDOWSTUB* ctrlstub = StubFind((unsigned long)ctrl);
	if (ctrlstub && (tcscmp(ctrlstub->CtrlStubClass, _T("MENUSTUB")) == 0))
	{
		MENUSTUB* menustub = (MENUSTUB*) ctrlstub->CtrlStub;
		if (menustub->EscapeHookProc)
		{
			BackendStartFrame(_T('H'), tcslen(menustub->EscapeHookProc) + 64);
			BackendInsertStr (menustub->EscapeHookProc);
			BackendInsertLong((unsigned long) win);
			BackendInsertLong((unsigned long) ctrl);
			BackendExecFrame ();
		}
	}
}

