/* ---------------------------------------------------------------------
 * File: mainwin.c
 * (application main window)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: mainwin.c 30935 2012-05-27 14:32:42Z dv $
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
#include "mainwin.h"
#include "pagerview.h"

#define IDC_TEXTVIEW  10
#define IDC_INDEXLIST 11

#define STATUS_TAILOFF _T("Commands: F3=Tail-On F4=Index F6=Filter F7=Search F10=Exit")
#define STATUS_TAILON  _T("Commands: F3=Tail-Off F4=Index F6=Filter F7=Search F10=Exit")

/* prototypes */
static void MainSetFilter(CUIWINDOW* win, MAINWINDATA* data);
static void MainSearchKeyword(CUIWINDOW* win, MAINWINDATA* data);
static void MainToggleTailFunction(CUIWINDOW* win, MAINWINDATA* data);
static void MainShowIndex(CUIWINDOW* win, MAINWINDATA* data);
static void MainReadIndex(CUIWINDOW* win);
static void MainJumpToIndex(CUIWINDOW* win, INDEXENTRY* entry);
static void MainError(void* w, const TCHAR* errmsg, 
                      const TCHAR* filename,
                      int linenr, int is_warning);


/* Custom callback hooks from index listbox */

/* ---------------------------------------------------------------------
 * MainListClickedHook
 * Popup Index Listbox item clicked
 * ---------------------------------------------------------------------
 */
static void 
MainListClickedHook(void* w, void* c)
{
	CUIWINDOW* ctrl = (CUIWINDOW*) c;

	WindowClose(ctrl, IDOK);
}

/* ---------------------------------------------------------------------
 * MainListPreKeyHook
 * Capture RETURN and ESC keys to close the popup listbox
 * ---------------------------------------------------------------------
 */
static int
MainListPreKeyHook(void* w, void* c, int key)
{
	CUIWINDOW* ctrl = (CUIWINDOW*) c;

	switch(key)
	{
	case KEY_RETURN:
		WindowClose(ctrl, IDOK);
		return TRUE;
	case KEY_ESC:
		WindowClose(ctrl, IDCANCEL);
		return TRUE;
	case KEY_F(10):
		WindowClose(ctrl, IDCANCEL);
		WindowQuit(0);
		break;
	case KEY_HOME:
		ListboxSetSel(ctrl, 0);
		return TRUE;
	case KEY_END:
		if (ListboxGetCount(ctrl) > 0)
		{
			ListboxSetSel(ctrl, ListboxGetCount(ctrl) - 1);
		}
		return TRUE;
	}
	return FALSE;
}


/* window hooks*/

/* ---------------------------------------------------------------------
 * MainCreateHook
 * Handle EVENT_CREATE events
 * ---------------------------------------------------------------------
 */
static void
MainCreateHook(void* w)
{
	CUIRECT      rc;
	CUIWINDOW*   win  = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW*   ctrl;
	TCHAR        version[32 + 1];

	stprintf(version, 32, _T("V%i.%i.%i"), VERSION, SUBVERSION, PATCHLEVEL);
	WindowSetRStatusText(win, version);

	WindowSetLStatusText(win, STATUS_TAILOFF);

	WindowGetClientRect(win, &rc);

	ctrl = PagerviewNew(win, 
		_T(""), 
		rc.X, rc.Y, rc.W, rc.H, 
		IDC_TEXTVIEW, 
		CWS_NONE, 
		data->Config->NoFrame ? CWS_BORDER : CWS_NONE);

	WindowColScheme(ctrl, _T("WINDOW"));
	WindowCreate(ctrl);
}

/* ---------------------------------------------------------------------
 * MainInitHook
 * Handle EVENT_INIT events 
 * ---------------------------------------------------------------------
 */
static void
MainInitHook(void* w)
{
	CUIWINDOW*   ctrl;
	CUIWINDOW*   win  = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	int          len = tcslen(data->Config->Filename) + 128;
	TCHAR*       cmd;
	
	data->Config->TmpFile = FALSE;

	/* check if file is an archive */
	cmd = malloc((len + 1) * sizeof(TCHAR));
	if (cmd)
	{
		TCHAR* p = tcsstr(data->Config->Filename, _T(".gz"));
		if ((p != NULL) && (p[3] == 0))
		{
#ifdef _UNICODE
			stprintf(cmd, len, _T("gunzip -c %ls > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#else
			stprintf(cmd, len, _T("gunzip -c %s > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#endif
			ExecSysCmd(cmd);

			data->Config->TmpFile = TRUE;
		}
		else
		{
			if (((p = tcsstr(data->Config->Filename, _T(".bz2"))) != NULL) && (p[4] == 0))
			{
#ifdef _UNICODE
				stprintf(cmd, len, _T("bunzip2 -c %ls > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#else
				stprintf(cmd, len, _T("bunzip2 -c %s > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#endif
				ExecSysCmd(cmd);

				data->Config->TmpFile = TRUE;
			}
			else if (((p = tcsstr(data->Config->Filename, _T(".lzma"))) != NULL) && (p[5] == 0))
			{
#ifdef _UNICODE
				stprintf(cmd, len, _T("unlzma -c %ls > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#else
				stprintf(cmd, len, _T("unlzma -c %s > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#endif
				ExecSysCmd(cmd);

				data->Config->TmpFile = TRUE;
			}
			else if (((p = tcsstr(data->Config->Filename, _T(".xz"))) != NULL) && (p[3] == 0))
			{
#ifdef _UNICODE
				stprintf(cmd, len, _T("unxz -c %ls > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#else
				stprintf(cmd, len, _T("unxz -c %s > /tmp/tmpfile%i"), data->Config->Filename, (int) getpid());
#endif
				ExecSysCmd(cmd);

				data->Config->TmpFile = TRUE;
			}
		}
		free(cmd);
	}

	/* change name of input file in case of temporary files */
	if (data->Config->TmpFile)
	{
		free(data->Config->Filename);
		data->Config->Filename = (TCHAR*) malloc((64 + 1) * sizeof(TCHAR));

		stprintf(data->Config->Filename, 64, _T("/tmp/tmpfile%i"), (int) getpid());
	}

	/* open file in pager view */
	ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if (ctrl)
	{
		if (!PagerviewSetFile(ctrl, data->Config->Filename))
		{
			TCHAR message[255 + 1];
#ifdef _UNICODE
			stprintf(message,255, _T("File '%ls' not found!"), data->Config->Filename);
#else
			stprintf(message,255, _T("File '%s' not found!"), data->Config->Filename);
#endif
			message[255] = 0;

			MessageBox(win, message, _T("Error"), MB_ERROR);
		}
		else if (data->Config->Indexfile != NULL)
		{
			MainReadIndex(win);
		}
		if (data->Config->Follow)
		{
			MainToggleTailFunction(win, data);
		}
	}
}


/* ---------------------------------------------------------------------
 * MainDestroyHook
 * Handle EVENT_DELETE events by deleting the window
 * ---------------------------------------------------------------------
 */
static void
MainDestroyHook(void* w)
{
	CUIWINDOW*   ctrl;
	CUIWINDOW*   win  = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	/* close file in pager view */
	ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if (ctrl)
	{
		PagerviewSetFile(ctrl, _T(""));
	}

	/* remove temporary file */
	if (data->Config->TmpFile)
	{
		FileRemove(data->Config->Filename);
	}

	/* free data */
	if (data->FileIndex) IndexDelete(data->FileIndex);
	if (data->HelpData)  XmlDelete(data->HelpData);
	if (data->ErrorMsg)  free(data->ErrorMsg);
	free (data);
}

/* ---------------------------------------------------------------------
 * MainResizeHook
 * Handle RESIZE events
 * ---------------------------------------------------------------------
 */
static int
MainSizeHook(void* w)
{
	CUIRECT      rc;
	CUIWINDOW*   win = (CUIWINDOW*) w;
	CUIWINDOW*   ctrl;

	WindowGetClientRect(win, &rc);

	ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if ((ctrl) && ((rc.H / 2) > 0))
	{
		WindowMove(ctrl, 0, 0, rc.W, rc.H);
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * MainPaintHook
 * Handle PAINT events by redrawing
 * ---------------------------------------------------------------------
 */
static void
MainPaintHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	MAINWINDATA*  data;

	data = win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;
}

/* ---------------------------------------------------------------------
 * MainKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
MainKeyHook(void* w, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	if (!data) return FALSE;

	if (win->IsEnabled)
	{
		switch (key)
		{
		case KEY_F(3):
			MainToggleTailFunction(win, data);
			return TRUE;
		case KEY_F(4):
			MainShowIndex(win, data);
			return TRUE;
		case KEY_F(6):
			MainSetFilter(win, data);
			return TRUE;
		case KEY_F(7):
			MainSearchKeyword(win, data);
			return TRUE;
		case KEY_F(10):
			WindowQuit(0);
			return TRUE;
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * MainwinNew
 * Create a new main window
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
MainwinNew(CUIWINDOW* parent, const TCHAR* text, int x, int y, int w, int h, 
           int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* mainwin;
		int flags = sflags | CWS_POPUP | CWS_CAPTION | CWS_STATUSBAR;
		flags &= ~(cflags);

		mainwin = WindowNew(parent, x, y, w, h, flags);
		mainwin->Class = _T("SHOW-DOC.CUI");
		WindowColScheme(mainwin, _T("DESKTOP"));
		WindowSetText(mainwin, text);
		WindowSetCreateHook(mainwin, MainCreateHook);
		WindowSetDestroyHook(mainwin, MainDestroyHook);
		WindowSetInitHook(mainwin, MainInitHook);
		WindowSetPaintHook(mainwin, MainPaintHook);
		WindowSetKeyHook(mainwin, MainKeyHook);
		WindowSetSizeHook(mainwin, MainSizeHook);

		mainwin->InstData = (MAINWINDATA*) malloc(sizeof(MAINWINDATA));
		((MAINWINDATA*)mainwin->InstData)->HelpData = NULL;
		((MAINWINDATA*)mainwin->InstData)->FileIndex = NULL;
		((MAINWINDATA*)mainwin->InstData)->LastIndexChoice = -1;
		((MAINWINDATA*)mainwin->InstData)->ErrorMsg = NULL;
		((MAINWINDATA*)mainwin->InstData)->Config = NULL;
		((MAINWINDATA*)mainwin->InstData)->TextWin = NULL;
		((MAINWINDATA*)mainwin->InstData)->TailOn = FALSE;
		((MAINWINDATA*)mainwin->InstData)->FindData.Keyword[0] = 0;
		((MAINWINDATA*)mainwin->InstData)->FindData.WholeWords = FALSE;
		((MAINWINDATA*)mainwin->InstData)->FindData.CaseSens = FALSE;
		((MAINWINDATA*)mainwin->InstData)->FindData.Direction = SEARCH_DOWN;

		return mainwin;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MainwinFindHelpEntry
 * Seek the help data for an entry matching 'topic'
 * ---------------------------------------------------------------------
 */
XMLOBJECT* 
MainwinFindHelpEntry(CUIWINDOW* win, const TCHAR* topic)
{
	if (win && (tcscmp(win->Class, _T("SHOW-DOC.CUI")) == 0))
	{
		TCHAR searchstr[128 + 1];
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
#ifdef _UNICODE
		stprintf(searchstr, 128, _T("help(name=%ls)"), topic);
#else
		stprintf(searchstr, 128, _T("help(name=%s)"), topic);
#endif
		searchstr[128] = 0;
		if (data->HelpData)
		{
			return XmlSearch(data->HelpData, searchstr);
		}
	}
        return NULL;
}


/* ---------------------------------------------------------------------
 * MainwinSetConfig
 * Assign configuration read from command line
 * ---------------------------------------------------------------------
 */
void
MainwinSetConfig(CUIWINDOW* win, PROGRAM_CONFIG* cfg)
{
	if (win && (tcscmp(win->Class, _T("SHOW-DOC.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		data->Config = cfg;
	}
}


/* ---------------------------------------------------------------------
 * MainwinMakeIndexFile
 * Derive the name of an index file from a known file name
 * ---------------------------------------------------------------------
 */
TCHAR*
MainwinMakeIndexFile(const TCHAR* file)
{
	TCHAR* pos1;
	TCHAR* pos2;
	TCHAR* idxfile;

	idxfile = (TCHAR*) malloc((tcslen(file) + 5) * sizeof(TCHAR));
	if (idxfile)
	{
		tcscpy(idxfile, file);
		pos1 = tcsrchr(idxfile, _T('.'));
		pos2 = tcsrchr(idxfile, _T('/'));

		if (pos2 && pos1 && (pos2 < pos1))
		{
			tcscpy(pos1, _T(".toc"));
		}
		else if (pos1 && !pos2)
		{
			tcscpy(pos1, _T(".toc"));
		}
		else
		{
			tcscat(idxfile, _T(".toc"));
		}

		/* check if the file exists */
		if (FileAccess(idxfile, F_OK) != 0)
		{
			free(idxfile);
			return NULL;
		}
	}
	return idxfile;
}

/* ---------------------------------------------------------------------
 * MainwinFreeMessage
 * Free the error message stored in the windows instance data
 * ---------------------------------------------------------------------
 */
void
MainwinFreeMessage(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	if (data->ErrorMsg)
	{
		free(data->ErrorMsg);
		data->ErrorMsg = NULL;
	}
}

/* ---------------------------------------------------------------------
 * MainwinAddMessage
 * Add a text to the error message stored in the windows instance data
 * ---------------------------------------------------------------------
 */
void
MainwinAddMessage(CUIWINDOW* win, const TCHAR* msg)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	if (!data->ErrorMsg)
	{
		data->ErrorMsg = tcsdup(msg);
	}
	else
	{
		int    len = tcslen(data->ErrorMsg) + tcslen(msg) + 2;
		TCHAR* err = (TCHAR*) malloc((len + 1) * sizeof(TCHAR));
#ifdef _UNICODE
		stprintf(err, len, _T("%ls\n%ls"), data->ErrorMsg, msg);
#else
		stprintf(err, len, _T("%s\n%s"), data->ErrorMsg, msg);
#endif
		free(data->ErrorMsg);
		data->ErrorMsg = err;
	}
}


/* helper functions */

/* ---------------------------------------------------------------------
 * MainError
 * Error callback routine for text file parser
 * ---------------------------------------------------------------------
 */
static void
MainError(void* w, const TCHAR* errmsg, const TCHAR* filename,
             int linenr, int is_warning)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	if (win)
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;

		if ((data->NumErrors + data->NumWarnings) < 8)
		{
			TCHAR err[512 + 1];
			if (is_warning)
			{
#ifdef _UNICODE
				stprintf(err, 512, _T("WARNING: %ls (%i): %ls"),filename, linenr,errmsg);
#else
				stprintf(err, 512, _T("WARNING: %s (%i): %s"),filename, linenr,errmsg);
#endif
				MainwinAddMessage(win, err);
			}
			else
			{
#ifdef _UNICODE
				stprintf(err, 512, _T("ERROR: %ls (%i): %ls"),filename, linenr,errmsg);
#else
				stprintf(err, 512, _T("ERROR: %s (%i): %s"),filename, linenr,errmsg);
#endif
				MainwinAddMessage(win, err);
			}
		}
		else if ((data->NumErrors + data->NumWarnings) == 8)
		{
			MainwinAddMessage(win, _T("... more errors"));
		}

		if (is_warning)
		{
			data->NumWarnings++;
		}
		else
		{
			data->NumErrors++;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainSetFilter
 * Apply a view filter to the pager window
 * ---------------------------------------------------------------------
 */
static void
MainSetFilter(CUIWINDOW* win, MAINWINDATA* data)
{
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if (ctrl)
	{
		CUIWINDOW* dlg = InputdlgNew(win, _T("View Filter"), CWS_NONE, CWS_NONE);
		if (dlg)
		{
			WindowCreate(dlg);
			if (WindowModal(dlg) == IDOK)
			{
				INPUTDLGDATA* data = InputdlgGetData(dlg);
				PagerviewSetFilter(ctrl, data->Text);
			}
			WindowDestroy(dlg);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainSearchKeyword
 * Search for a keyword within the current file
 * ---------------------------------------------------------------------
 */
static void
MainSearchKeyword(CUIWINDOW* win, MAINWINDATA* data)
{
	CUIWINDOW*  dlg;
	CUIWINDOW*  ctrl;
	FINDDLGDATA* dlgdata;
	dlg = FinddlgNew(win, _T("Search for keyword"), CWS_NONE, CWS_NONE);
	if (dlg)
	{
		dlgdata = FinddlgGetData(dlg);
		if (dlgdata)
		{
			*dlgdata = data->FindData;			

			WindowCreate(dlg);
			if (WindowModal(dlg) == IDOK)
			{
				data->FindData = *dlgdata;

				ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
				if (ctrl)
				{
					if (!PagerviewSearch(
						ctrl,
						data->FindData.Keyword,
						data->FindData.WholeWords,
						data->FindData.CaseSens,
						data->FindData.Direction == SEARCH_DOWN))
					{
						PagerviewResetSearch(ctrl, 
							data->FindData.Direction == SEARCH_DOWN);
						
						if (!PagerviewSearch(
							ctrl,
							data->FindData.Keyword,
							data->FindData.WholeWords,
							data->FindData.CaseSens,
							data->FindData.Direction == SEARCH_DOWN))
						{
							MessageBox(win, _T("Not found!"), _T("Message"), MB_INFO);
						}
					}
				}
			}
			WindowDestroy(dlg);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainToggleTailFunction
 * Enable or disable tail function
 * ---------------------------------------------------------------------
 */
static void
MainToggleTailFunction(CUIWINDOW* win, MAINWINDATA* data)
{
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if (ctrl)
	{
		PagerviewEnableTail(ctrl, !data->TailOn);
		data->TailOn = !data->TailOn;

		if (!data->TailOn)
		{
			WindowSetLStatusText(win, STATUS_TAILOFF);
		}
		else
		{
			WindowSetLStatusText(win, STATUS_TAILON);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainShowIndex
 * Show table of contents (if available)
 * ---------------------------------------------------------------------
 */
static void
MainShowIndex(CUIWINDOW* win, MAINWINDATA* data)
{
	if (data->FileIndex != NULL)
	{
		CUIWINDOW* list = ListboxNew(win, 
			data->FileIndex->Title ? data->FileIndex->Title : _T(""), 
			0, 0, 60, 20, 
			IDC_INDEXLIST, 
			CWS_POPUP | CWS_CENTERED, CWS_NONE);
		if (list)
		{
			INDEXENTRY* entry = data->FileIndex->FirstEntry;
			while (entry)
			{
				int index;
				int level;
				TCHAR buffer[256 + 1];

				level = (entry->Level < 8) ? entry->Level : 8;
				level = (level > 0) ? level : 1;

				buffer[0] = 0;
				for (index = 1; index < level; index++)
				{
					tcscat(buffer, _T("   "));
				}

				tcsncpy(&buffer[(level - 1) * 3], entry->Description, 200);
				buffer[256] = 0; 

				ListboxAdd(list, buffer);

				entry = (INDEXENTRY*) entry->Next;
			}
			ListboxSetLbClickedHook (list, MainListClickedHook, win);
			ListboxSetPreKeyHook    (list, MainListPreKeyHook, win);
			if (data->LastIndexChoice >= 0)
			{
				ListboxSetSel(list, data->LastIndexChoice);
			}
			else
			{
				ListboxSetSel(list, 0);
			}
			WindowColScheme(list, _T("MENU"));
			WindowCreate(list);
			if (WindowModal(list) == IDOK)
			{
				data->LastIndexChoice = ListboxGetSel(list);
				if (data->LastIndexChoice >= 0)
				{
					int index = 0;
					entry = data->FileIndex->FirstEntry;
					while (entry && (index < data->LastIndexChoice))
					{
						index++;
						entry = (INDEXENTRY*) entry->Next;
					}
					MainJumpToIndex(win, entry);
				}
			}
			WindowDestroy(list);
		} 
	}
	else
	{
		MessageBox(win, _T("No index available for this file!"), _T("Info"), MB_OK);
	}
}

/* ---------------------------------------------------------------------
 * MainReadIndex
 * Read an index file
 * ---------------------------------------------------------------------
 */
static void 
MainReadIndex(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	if (data)
	{
		if (data->FileIndex)
		{
			IndexDelete(data->FileIndex);
			data->FileIndex = NULL;
			data->LastIndexChoice = -1;
		}
		if (data->Config->Indexfile[0] != 0)
		{
			MainwinFreeMessage(win);
			data->NumErrors = 0;
			data->NumWarnings = 0;

			data->FileIndex = IndexReadFile(
			                     data->Config->Indexfile,
			                     MainError, 
			                     win);

			if (data->NumErrors || data->NumWarnings)
			{
				TCHAR buffer[128 + 1];

				MainwinAddMessage(win, _T(""));

				stprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
				    data->NumErrors, data->NumWarnings);

				MainwinAddMessage(win, buffer);

#ifdef _UNICODE
				stprintf(buffer, 128, _T("file: %ls"), data->Config->Indexfile);
#else
				stprintf(buffer, 128, _T("file: %s"), data->Config->Indexfile);
#endif

				MainwinAddMessage(win, buffer);

				MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
			}
			MainwinFreeMessage(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainJumToIndex
 * Jump to a given line
 * ---------------------------------------------------------------------
 */
static void
MainJumpToIndex(CUIWINDOW* win, INDEXENTRY* entry)
{
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_TEXTVIEW);
	if (entry && ctrl)
	{
		if (entry->FilePosition < 0)
		{
			entry->FilePosition = PagerviewResolveLine(ctrl, entry->LineNumber);
		}
		if (entry->FilePosition >= 0)
		{
			PagerviewJumpTo(ctrl, entry->FilePosition);
		}
	}
}


