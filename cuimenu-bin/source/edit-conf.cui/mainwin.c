/* ---------------------------------------------------------------------
 * File: mainwin.c
 * (application main window)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: mainwin.c 33469 2013-04-14 17:32:04Z dv $
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
#include "confview.h"
#include "createdlg.h"

#define IDC_CONFVIEW  10
#define IDC_HELPVIEW  11

#define KEY_INC _T('+')
#define KEY_DEC _T('-')

#define IDLE_STATUS_TEXT_1 _T("ENTER=Edit F1=Help F2=Save F3=Move F7=Search F8=Delete F9=Create F10=Exit")
#define IDLE_STATUS_TEXT_2 _T("ENTER=Edit F1=Help F2=Save F3=Move F7=Search F8=Delete F10=Exit")
#define IDLE_STATUS_TEXT_2_OFF _T("ENTER=Edit F1=Help F2=Save F3=Move F4=Opt-ON F7=Search F8=Delete F10=Exit")
#define IDLE_STATUS_TEXT_2_ON  _T("ENTER=Edit F1=Help F2=Save F3=Move F4=Opt-OFF F7=Search F8=Delete F10=Exit")
#define DRAG_STATUS_TEXT   _T("Ok, ready to move! F3=End Move F10=Exit")

#define CHECK_OK       0
#define CHECK_WARNINGS 1
#define CHECK_ERRORS   2
#define CHECK_SYSERROR 3

#define ECE_API_GETVALUE 1000


/* prototypes */
static void       MainwinError(void* w, const wchar_t* errmsg,
                         const wchar_t* filename,
                         int linenr, int is_warning);
static void       MainwinRunOut(const char* buffer,
                         int source,
                         void* instance);

static void       MainwinReadHelp(CUIWINDOW* win);
static void       MainwinToggleHelp(CUIWINDOW* win);
static void       MainwinToggleDragMode(CUIWINDOW* win);
static void       MainwinEditLocation(CUIWINDOW* win);
static void       MainwinDeleteLocation(CUIWINDOW* win);
static void       MainwinIncDecLocation(CUIWINDOW* win, int do_increment);
static void       MainwinCreateItem(CUIWINDOW* win);
static void       MainwinManualSaveOptions(CUIWINDOW* win);
static void       MainwinShowCheckError(CUIWINDOW* win, CONFCHECK* chkptr,
                         int res, int is_warning);
static void       MainwinExit(CUIWINDOW* win, int escsape);
static void       MainwinSearchKeyword(CUIWINDOW* win);
static int        MainwinSaveOptions(CUIWINDOW* win, MAINWINDATA* data);
static int        MainwinCheckOptions(CUIWINDOW* win, MAINWINDATA* data);
static CONFCHECK* MainwinCheckUserDialog(CUIWINDOW* win, MAINWINDATA* data, CONFITEM* item);
static void       MainwinToggleOptView(CUIWINDOW* win);
static void       MainwinShowStatusBar(CUIWINDOW* win);
static int        MainwinApi(int func_nr, int argc, const wchar_t* argv[]);
static void       MainwinApiGetValue(int argc, const wchar_t* argv[]);


/* Custom callback hooks from index config view */

/* ---------------------------------------------------------------------
 * MainConfPreKeyHook
 * Preprocess key input
 * ---------------------------------------------------------------------
 */
static int
MainConfPreKeyHook(void* w, void* c, int key)
{
	CUI_USE_ARG(c);
	
	switch(key)
	{
	case KEY_ESC:
		MainwinExit((CUIWINDOW*) w, TRUE);
		return TRUE;
	case KEY_RETURN:
		MainwinEditLocation((CUIWINDOW*) w);
		return TRUE;
	case KEY_F0 + 4:
		MainwinToggleOptView((CUIWINDOW*) w);
		return TRUE;
	case KEY_INC:
		MainwinIncDecLocation((CUIWINDOW*) w, TRUE);
		return TRUE;
	case KEY_DEC:
		MainwinIncDecLocation((CUIWINDOW*) w, FALSE);
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MainConfClickedHook
 * A config entry has been clicked
 * ---------------------------------------------------------------------
 */
static void
MainConfClickedHook(void* w, void* c)
{
	CUI_USE_ARG(c);

	MainwinEditLocation((CUIWINDOW*) w);
}

/* ---------------------------------------------------------------------
 * MainConfSelChangedHook
 * The selection has been changed / update help window
 * ---------------------------------------------------------------------
 */
static void
MainConfSelChangedHook(void* w, void* c)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	CUIWINDOW*   ctrl = (CUIWINDOW*) c;
	CUIWINDOW*   helpview;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	helpview = WindowGetCtrl(win, IDC_HELPVIEW);

	TextviewClear(helpview);
	if (data->ShowHelp)
	{
		int index = ConfviewGetSel(ctrl);
		if (index >= 0)
		{
			XMLOBJECT* obj = NULL;
			CONFITEM*  item = ConfFileGetItem(data->Config->ConfData, index);

			TextviewEnableWordWrap(helpview, TRUE);

			obj = MainwinFindHelpEntry(win, item->Name);
			if (obj)
			{
				int linebreak = FALSE;
				XMLNODE* node = obj->FirstNode;

				while (node)
				{
					XMLNODE* nnode = (XMLNODE*) node->Next;
					if ((node->Type == XML_DATANODE) && (node->Data))
					{
						TextviewAdd(helpview, node->Data);
						linebreak = TRUE;
					}
					else
					{
						if (!linebreak || (nnode == NULL))
						{
							TextviewAdd(helpview, _T(""));
						}
						linebreak = FALSE;
					}
					node = nnode;
				}
				WindowInvalidate(helpview);
			}
			else
			{
				TextviewAdd(helpview, _T("no help available"));
			}
		}
		else
		{
			TextviewAdd(helpview, _T("no help available"));
		}
	}
}

/* Window hooks of main window */

/* ---------------------------------------------------------------------
 * MainCreateHook
 * Handle EVENT_CREATE events
 * ---------------------------------------------------------------------
 */
static void
MainCreateHook(void* w)
{
	CUIRECT      rc;
	CUIWINDOW*   win = (CUIWINDOW*) w;
	CUIWINDOW*   ctrl;
	wchar_t        version[32 + 1];

	swprintf(version, 32, _T("V%i.%i.%i"), VERSION, SUBVERSION, PATCHLEVEL);
	WindowSetRStatusText(win, version);

	MainwinShowStatusBar(win);

	WindowGetClientRect(win, &rc);

	ctrl = ConfviewNew(win, _T(""), rc.X, rc.Y, rc.W, rc.H, IDC_CONFVIEW, CWS_NONE, CWS_NONE);
	ConfviewSetLbChangedHook(ctrl, MainConfSelChangedHook, win);
	ConfviewSetLbClickedHook(ctrl, MainConfClickedHook, win);
	ConfviewSetPreKeyHook(ctrl, MainConfPreKeyHook, win);
	WindowColScheme(ctrl, _T("WINDOW"));
	WindowCreate(ctrl);

	ctrl = TextviewNew(win, _T(""), rc.X, rc.Y, rc.W, rc.H, IDC_HELPVIEW, CWS_NONE, CWS_NONE);
	WindowColScheme(ctrl, _T("HELP"));
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
	CUIWINDOW*   win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	MainwinFreeMessage(win);

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (ctrl)
	{
		if (MainwinReadExpressions(win, data->Config, MainwinError))
		{
			MainwinReadConfig(win, data->Config, MainwinError);
			MainwinShowStatusBar(win);
			if (data->Config->BeTolerant)
			{
				ConfFileSetOptionalOn(TRUE);
			}
		}

		if (data->Config->NumErrors || data->Config->NumWarnings)
		{
			wchar_t buffer[128 + 1];

			MainwinAddMessage(win, _T(""));

			swprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
			    data->Config->NumErrors, data->Config->NumWarnings);

			MainwinAddMessage(win, buffer);

			MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
			if (data->Config->NumErrors)
			{
				WindowQuit(EXIT_FAILURE);
			}
		}
/*		else
		{
			if (data->Config->ConfData && (data->Config->ConfData->NumOptional > 0))
			{
				MessageBox(win,
				           _T("This config has some optional values that are\n")
				           _T("currently hidden. \n\n")
				           _T("Press F4 to see all values"), _T("Info"), MB_OK);
			}
		}*/

		MainwinFreeMessage(win);

		ConfviewSetData(ctrl, data->Config->ConfData);
	}
	if (data->Config->NumErrors == 0)
	{
		MainwinReadHelp(win);
	}

	if (data->Config->ConfData && (data->Config->ConfData->NumOptional > 0))
	{
		MessageBox(win,
		           _T("This config has some optional values that are\n")
		           _T("currently hidden. \n\n")
		           _T("Press F4 to see all values"), _T("Info"), MB_OK);
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
	CUIWINDOW* win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	if (data->HelpData) XmlDelete(data->HelpData);
	if (data->ErrorMsg) free(data->ErrorMsg);
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
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW*   confview;
	CUIWINDOW*   helpview;

	WindowGetClientRect(win, &rc);

	confview = WindowGetCtrl(win, IDC_CONFVIEW);
	helpview = WindowGetCtrl(win, IDC_HELPVIEW);

	if (confview && helpview && ((rc.H / 2) > 0))
	{
		if (data->ShowHelp)
		{
			int height = rc.H - rc.H / 4;

			if ((rc.H - height) < 6)
			{
				if (rc.H > 6) height = rc.H - 6;
			}
			if ((height > 0) && (height % 2 != 1)) height++;

			WindowMove(confview, 0, 0, rc.W, height);
			WindowMove(helpview, 0, height, rc.W, rc.H - height);
			WindowHide(helpview, FALSE);
		}
		else
		{
			WindowMove(confview, 0, 0, rc.W, rc.H);
			WindowHide(helpview, TRUE);
		}
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

	if (win->IsEnabled)
	{
		switch(key)
		{
		case KEY_F(1):
			MainwinToggleHelp(win);
			return TRUE;
		case KEY_F(2):
			MainwinManualSaveOptions(win);
			return TRUE;
		case KEY_F(3):
			MainwinToggleDragMode(win);
			return TRUE;
		case KEY_F(7):
			MainwinSearchKeyword(win);
			return TRUE;
		case KEY_F(8):
			MainwinDeleteLocation(win);
			return TRUE;
		case KEY_F(9):
			MainwinCreateItem(win);
			return TRUE;
		case KEY_F(10):
			MainwinExit(win, FALSE);
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
MainwinNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* mainwin;
		int flags = sflags | CWS_POPUP | CWS_CAPTION | CWS_STATUSBAR;
		flags &= ~(cflags);

		mainwin = WindowNew(parent, x, y, w, h, flags);
		mainwin->Class = _T("EDIT-CONF.CUI");
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
		((MAINWINDATA*)mainwin->InstData)->ErrorMsg = NULL;
		((MAINWINDATA*)mainwin->InstData)->Config = NULL;
		((MAINWINDATA*)mainwin->InstData)->ShowHelp = FALSE;
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
MainwinFindHelpEntry(CUIWINDOW* win, const wchar_t* topic)
{
	if (win && (wcscmp(win->Class, _T("EDIT-CONF.CUI")) == 0))
	{
		wchar_t searchstr[128 + 1];
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;

		swprintf(searchstr, 128, _T("help(name=%ls)"), topic);
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
	if (win && (wcscmp(win->Class, _T("EDIT-CONF.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		data->Config = cfg;
	}
}


/* ---------------------------------------------------------------------
 * MainwinFreeMessage
 * Free the error message stored in the windows instance data
 * ---------------------------------------------------------------------
 */
void
MainwinFreeMessage(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("EDIT-CONF.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		if (data->ErrorMsg)
		{
			free(data->ErrorMsg);
			data->ErrorMsg = NULL;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinAddMessage
 * Add a text to the error message stored in the windows instance data
 * ---------------------------------------------------------------------
 */
void
MainwinAddMessage(CUIWINDOW* win, const wchar_t* msg)
{
	if (win && (wcscmp(win->Class, _T("EDIT-CONF.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		if (!data->ErrorMsg)
		{
			data->ErrorMsg = wcsdup(msg);
		}
		else
		{
			int len = wcslen(data->ErrorMsg) + wcslen(msg) + 2;

			wchar_t* err = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

			swprintf(err, len, _T("%ls\n%ls"), data->ErrorMsg, msg);

			free(data->ErrorMsg);
			data->ErrorMsg = err;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinCopyFile
 * Copy an orindary  file to another destination
 * ---------------------------------------------------------------------
 */
int
MainwinCopyFile(const wchar_t* sfile, const wchar_t* tfile)
{
	int result = FALSE;

	FILE* in = FileOpen(sfile, _T("rb"));
	if (in)
	{
		FILE* out = FileOpen(tfile, _T("wb"));
		if (out)
		{
			unsigned char* buffer = malloc(8 * 1024);
			if (buffer)
			{
				while (!feof(in))
				{
					int c = fread(buffer, 1, 8 * 1024, in);
					if (c > 0)
					{
						fwrite(buffer, 1, c, out);
					}
				}
				if (!ferror(in) && !ferror(out))
				{
					result = TRUE;
				}
				free(buffer);
			}
			FileClose(out);
		}
		FileClose(in);
	}
	return result;
}

/* ---------------------------------------------------------------------
 * MainwinReadExpressions
 * Read the regular expressions associated with this config file
 * ---------------------------------------------------------------------
 */
int
MainwinReadExpressions(CUIWINDOW* win, PROGRAM_CONFIG* cfg, ErrorCallback errout)
{
	DIR *    dirp;
	struct   dirent * dp;
	int      len;
	wchar_t    base_exp[256 + 1];

	swprintf(base_exp, 256, _T("%ls/base.exp"), cfg->CheckFileBase);
	base_exp[256] = 0;

	if (cfg->RegExpData)
	{
		ExpDelete(cfg->RegExpData);
	}

	cfg->RegExpData = ExpCreate();
	ExpAddFile(cfg->RegExpData, base_exp, errout, win);

	if (cfg->RunMkfli4l)
	{
		if ( (dirp = OpenDirectory(cfg->ConfigFileBase)) )
		{
			while ((dp = ReadDirectory(dirp)) != (struct dirent *) NULL)
			{
				len = strlen (dp->d_name);

				if (len > 4 && ! strcasecmp (dp->d_name + len - 4, ".txt") &&
				    strcasecmp (dp->d_name, "base.txt"))
				{
					dp->d_name[len - 4] = '\0';

					swprintf(base_exp, 256, _T("%ls/%s.exp"), cfg->ConfigFileBase, dp->d_name);
					base_exp[256] = 0;

					if (FileAccess(base_exp, R_OK) == 0)
					{
						ExpAddFile(cfg->RegExpData, base_exp, errout, win);
					}
				}
			}
			(void) CloseDirectory (dirp);
		}
		else
		{
			errout(win, _T("unable to open config dir"), cfg->ConfigFileBase, 0, 0);
		}
	}
	else
	{
		if ((cfg->NumErrors == 0) && (FileAccess(cfg->ExpFileName, R_OK) == 0))
		{
			if (wcscmp(cfg->ExpFileName, base_exp) != 0)
			{
				ExpAddFile(cfg->RegExpData, cfg->ExpFileName, errout, win);
			}
		}
	}
	return (cfg->NumErrors == 0);
}

/* ---------------------------------------------------------------------
 * MainwinReadConfig
 * Read the configuration. At first, the file in 'check.d' is read, then
 * we proceed by reading the files in 'config.d' and in 'default.d'.
 * Notice that errors in one of this files causes the application to
 * terminate itself.
 * ---------------------------------------------------------------------
 */
int
MainwinReadConfig(CUIWINDOW* win, PROGRAM_CONFIG* cfg, ErrorCallback errout)
{
	if (cfg->ConfData)
	{
		ConfFileDelete(cfg->ConfData);
	}

	cfg->ConfData = ConfFileCreate(errout, win);

	ConfFileReadCheck(cfg->ConfData, cfg->CheckFileName, cfg->RegExpData);
	if (cfg->NumErrors == 0)
	{
		ConfFileReadConfig(cfg->ConfData,
			cfg->ConfFileName,
			cfg->CheckFileBase,
			cfg->BeTolerant);
	}

	if (cfg->NumErrors == 0)
	{
		if (FileAccess(cfg->DefaultFileName, R_OK) == 0)
		{
			ConfFileReadDefault(cfg->ConfData,
				cfg->DefaultFileName,
				cfg->CheckFileBase,
				cfg->BeTolerant);
		}
		else if (cfg->NumWarnings == 0)
		{
			errout(win,
				_T("File not found, reading file from config.d instead!"),
				cfg->DefaultFileName,0,TRUE);

			ConfFileReadDefault(cfg->ConfData,
				cfg->ConfFileName,
				cfg->CheckFileBase,
				cfg->BeTolerant);
		}
	}
	return (cfg->NumErrors == 0);
}

/* helper functions */

/* ---------------------------------------------------------------------
 * MainwinError
 * Error callback routine for text file parser
 * ---------------------------------------------------------------------
 */
static void
MainwinError(void* w, const wchar_t* errmsg, const wchar_t* filename,
             int linenr, int is_warning)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	if (win)
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;

		if ((data->Config->NumErrors + data->Config->NumWarnings) < 8)
		{
			wchar_t err[512 + 1];
			if (is_warning)
			{
				swprintf(err, 512, _T("WARNING: %ls (%i): %ls"),filename, linenr,errmsg);
				MainwinAddMessage(win, err);
			}
			else
			{
				swprintf(err, 512, _T("ERROR: %s (%i): %s"),filename, linenr,errmsg);
				MainwinAddMessage(win, err);
			}
		}
		else if ((data->Config->NumErrors + data->Config->NumWarnings) == 8)
		{
			MainwinAddMessage(win, _T("... more errors"));
		}

		if (is_warning)
		{
			data->Config->NumWarnings++;
		}
		else
		{
			data->Config->NumErrors++;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinRunOut (callback)
 * This function is called from "RunCoProcess" when a coprocess is executed.
 * ---------------------------------------------------------------------
 */
static void
MainwinRunOut(const char* buffer, int source, void* instance)
{
	CUIWINDOW* win = (CUIWINDOW*) instance;
	
	CUI_USE_ARG(source);

	if (win)
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		if (data->Config->NumErrors < 20)
		{
			wchar_t* tbuffer = MbToTCharDup(buffer);
			if (tbuffer)
			{
				MainwinAddMessage(win, tbuffer);
				free(tbuffer);
			}
		}
		else if (data->Config->NumErrors == 20)
		{
			MainwinAddMessage(win, _T("... more errors"));
		}
		data->Config->NumErrors++;
	}
}

/* ---------------------------------------------------------------------
 * MainwinReadHelp
 * Read the XML help file for this program
 * ---------------------------------------------------------------------
 */
static void
MainwinReadHelp(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	MainwinFreeMessage(win);

	data->HelpData = XmlCreate(data->Config->HelpFileName);
	XmlSetErrorHook(data->HelpData, MainwinError, win);
	XmlAddSingleTag(data->HelpData, _T("BR"));

	data->Config->NumErrors = 0;
	data->Config->NumWarnings = 0;

	XmlReadFile(data->HelpData);

	if (data->Config->NumErrors || data->Config->NumWarnings)
	{
		wchar_t buffer[128 + 1];

		MainwinAddMessage(win, _T(""));

		swprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
			data->Config->NumErrors, data->Config->NumWarnings);
		MainwinAddMessage(win, buffer);

		swprintf(buffer, 128, _T("file: %ls"),
			data->Config->HelpFileName);
		MainwinAddMessage(win, buffer);

		MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
	}
	MainwinFreeMessage(win);
}

/* ---------------------------------------------------------------------
 * MainwinToggleHelp
 * Switch Help on or off
 * ---------------------------------------------------------------------
 */
static void
MainwinToggleHelp(CUIWINDOW* win)
{
	CUIWINDOW* ctrl;
	CUIWINDOW* help;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	help = WindowGetCtrl(win, IDC_HELPVIEW);

	data->ShowHelp = data->ShowHelp ? FALSE : TRUE;
	if (data->ShowHelp)
	{
		MainConfSelChangedHook(win, ctrl);
	}
	else if (WindowGetFocus() == help)
	{
		WindowSetFocus(ctrl);
	}
	MainSizeHook(win);
}

/* ---------------------------------------------------------------------
 * MainwinSearchKeyword
 * Search config for keyword
 * ---------------------------------------------------------------------
 */
static void
MainwinSearchKeyword(CUIWINDOW* win)
{
	CUIWINDOW* ctrl;
	CUIWINDOW* dlg;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config || !data->Config->ConfData)
	{
		return;
	}
	if (!ConfviewIsInDrag(ctrl))
	{
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

					if (!ConfviewSearch(
						ctrl,
						data->FindData.Keyword,
						data->FindData.WholeWords,
						data->FindData.CaseSens,
						data->FindData.Direction == SEARCH_DOWN))
					{
						int oldcursor = ConfviewGetSel(ctrl);
						ConfviewSetSel(ctrl, -1);

						if (!ConfviewSearch(
							ctrl,
							data->FindData.Keyword,
							data->FindData.WholeWords,
							data->FindData.CaseSens,
							data->FindData.Direction == SEARCH_DOWN))
						{
							ConfviewSetSel(ctrl, oldcursor);
							MessageBox(win, _T("Not found!"), _T("Message"), MB_INFO);
						}
					}
				}
				WindowDestroy(dlg);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinToggleDragMode
 * Switch Dragmode on or off
 * ---------------------------------------------------------------------
 */
static void
MainwinToggleDragMode(CUIWINDOW* win)
{
	CUIWINDOW* ctrl;

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);

	ConfviewToggleDrag(ctrl);
	if (ConfviewIsInDrag(ctrl))
	{
		WindowSetLStatusText(win, DRAG_STATUS_TEXT);
	}
	else
	{
		MainwinShowStatusBar(win);
	}
}

/* ---------------------------------------------------------------------
 * MainwinExit
 * Prepare to exit the application
 * ---------------------------------------------------------------------
 */
static void
MainwinExit(CUIWINDOW* win, int escape)
{
	CUIWINDOW* ctrl;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	
	CUI_USE_ARG(escape);

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config || !data->Config->ConfData)
	{
		WindowQuit(0);
	}
	else
	{
		if (ConfviewIsInDrag(ctrl))
		{
			MainwinToggleDragMode(win);
		}
		else
		{
			int chkres;
			int request_save = FALSE;
			int res;

			if (ConfFileIsModified(data->Config->ConfData))
			{
				/* Ask user to save the current config */
				res = MessageBox(win, _T("The config has been modified. Save changes?"),
					_T("Question"), MB_YESNOCANCEL);
				if (res == IDCANCEL)
				{
					return;
				}
				else if (res == IDYES)
				{
					request_save = TRUE;
				}
			}

			chkres = MainwinCheckOptions(win, data);
			if (chkres != CHECK_OK)
			{
				/* Ask user if he/she wants to edit the config again */
				switch(chkres)
				{
				case CHECK_SYSERROR:
					res = MessageBox(win, _T("Due to an internal error the config check failed!\n")
							_T("Do you still want to exit?"),
							_T("Question"), MB_YESNO | MB_DEFBUTTON1);
					break;
				case CHECK_WARNINGS:
					res = MessageBox(win, _T("Some warnings have been found!\n")
							_T("Do you still want to exit?"),
							_T("Question"), MB_YESNO | MB_DEFBUTTON1);
					break;
				default:
					if (request_save)
					{
						res = MessageBox(win, _T("The configuration is faulty!\n")
								_T("Do you really want to save and exit?"),
								_T("Question"), MB_YESNO | MB_DEFBUTTON1);
					}
					else
					{
						res = MessageBox(win, _T("The configuration is faulty!\n")
								_T("Do you really want to exit?"),
								_T("Question"), MB_YESNO | MB_DEFBUTTON1);
					}
					break;
				}

				if (res != IDYES)
				{
					return;
				}
			}
			if (request_save)
			{
				if (!MainwinSaveOptions(win, data))
				{
					return;
				}
			}
			WindowQuit(0);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinToggleOptView
 * Toggle visibility of empty optional values on or off
 * ---------------------------------------------------------------------
 */
static void
MainwinToggleOptView(CUIWINDOW* win)
{
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_CONFVIEW);

	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	if ((data->Config->ConfData) && 
	    (!data->Config->BeTolerant) &&
	    (data->Config->ConfData->NumOptional))
	{
		ConfviewToggleOptView(ctrl);
		MainwinShowStatusBar(win);
	}
}

/* ---------------------------------------------------------------------
 * MainwinEditLocation
 * Edit current cursor position
 * ---------------------------------------------------------------------
 */
static void
MainwinEditLocation(CUIWINDOW* win)
{
	CUIWINDOW* ctrl;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config->ConfData)
	{
		return;
	}

	if (ConfviewIsInDrag(ctrl))
	{
		MainwinToggleDragMode(win);
	}
	else
	{
		int created = FALSE;

		CONFITEM* item = ConfFileGetItem(data->Config->ConfData, ConfviewGetSel(ctrl));
		if (item && item->IsReadOnly)
		{
			MessageBox(win, _T("This value can not be modified!"), _T("Message"), MB_OK);
		}
		else if (item)
		{
			CONFVALUE* value = ConfFileGetValue(data->Config->ConfData, ConfviewGetSel(ctrl));
			if (!value)
			{
				ConfFileCreateValue(data->Config->ConfData, ConfviewGetSel(ctrl));
				value = ConfFileGetValue(data->Config->ConfData, ConfviewGetSel(ctrl));
				if (value)
				{
					created = TRUE;
				}
			}

			if (value && wcscasecmp(item->FirstCheck->Name, _T("YESNO"))==0)
			{
				if (wcscasecmp(value->Value, _T("yes"))==0)
				{
					free(value->Value);
					value->Value = wcsdup(_T("no"));
				}
				else
				{
					free(value->Value);
					value->Value = wcsdup(_T("yes"));
				}
				ConfFileSetModified(data->Config->ConfData, TRUE);
				ConfviewUpdateData(ctrl);
			}
			else if (value)
			{
				CONFCHECK* c = MainwinCheckUserDialog(win, data, item);
				if (c)
				{
					int  exitloop = FALSE;
					if (BackendCreatePipes())
					{
						int    len = wcslen(item->Name)
							+ wcslen(data->Config->DialogPath)
							+ 48;
						wchar_t* command = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

						swprintf(command, len, _T("%ls/%ls.sh CUISHELL %i"),
						data->Config->DialogPath, c->Name, getpid());

						ScriptingInit();
						StubCheckStub(win);
						BackendSetExternalApi(MainwinApi);
						if (BackendOpen(command, data->Config->Debug))
						{
							BackendStartFrame(_T('H'), wcslen(value->Value) + 32);
							BackendInsertStr (_T("setdata"));
							BackendInsertStr (value->Value);
							BackendExecFrame ();

							while (!exitloop)
							{
								BackendStartFrame(_T('H'), wcslen(value->Name) + 48);
								BackendInsertStr (_T("exec_dialog"));
								BackendInsertLong((unsigned long) win);
								BackendInsertStr (value->Name);
								BackendExecFrame ();

								if ((BackendNumResultParams() > 0) &&
								    (wcscmp(BackendResultParam(0), _T("1")) == 0))
								{
									int valid = TRUE;
									CONFCHECK* chkptr = item->FirstCheck;

									BackendStartFrame(_T('H'), 32);
									BackendInsertStr (_T("getdata"));
									BackendExecFrame ();

									if (BackendNumResultParams() > 0)
									{
										const wchar_t* newvalue = BackendResultParam(0);

										while (chkptr && valid)
										{
											int res = ExpMatch(data->Config->RegExpData, chkptr->Name, newvalue);
											if ((res == EXP_NOMATCH) || (res == EXP_ERROR))
											{
												int is_warning = (wcsstr(chkptr->Name,_T("WARN_")) == chkptr->Name);

												MainwinShowCheckError(win, chkptr, res, is_warning);
												if (!is_warning || (res == EXP_ERROR))
												{
													valid = false;
												}
											}
											chkptr = (CONFCHECK*) chkptr->Next;
										}

										if (valid)
										{
											if (wcscmp(value->Value, newvalue) != 0)
											{
												free (value->Value);

												value->Value = wcsdup(newvalue);

												if (item->Child)
												{
													ConfFileCreateValue(data->Config->ConfData, ConfviewGetSel(ctrl));
												}
												ConfFileSetModified(data->Config->ConfData, TRUE);
											}
											else if (created)
											{
												ConfFileSetModified(data->Config->ConfData, TRUE);
											}
											ConfviewUpdateData(ctrl);
											exitloop = TRUE;
										}
									}
								}
								else
								{
									if (created)
									{
										ConfFileDeleteValue(data->Config->ConfData, ConfviewGetSel(ctrl));
									}
									exitloop = TRUE;
								}
							}
							BackendStartFrame(_T('H'), 32);
							BackendInsertStr (_T("exit"));
							BackendExecFrame ();
							BackendClose();
							WindowSetFocus(ctrl);
						}
						else
						{
							MessageBox(win,
								_T("Unable to execute shell script"),
								_T("ERROR"), MB_ERROR);
						}
						BackendRemovePipes();
						ScriptingEnd();

						free(command);
					}
				}
				else if (item->IsMasked)
				{
					int            exitloop = FALSE;
					CUIWINDOW*     dlg;
					PASSWDDLGDATA* dlgdata;

					dlg  = PasswddlgNew(win, _T("Enter Password"), CWS_NONE, CWS_NONE);
					dlgdata = PasswddlgGetData(dlg);
					if (dlgdata)
					{
						wcsncpy(dlgdata->Password, value->Value, MAX_PASSWD_SIZE);
						dlgdata->Password[MAX_PASSWD_SIZE] = 0;
					}

					WindowCreate(dlg);
					while (dlgdata && !exitloop)
					{
						if (WindowModal(dlg) == IDOK)
						{
							int valid = TRUE;
							CONFCHECK* chkptr = item->FirstCheck;

							while (chkptr && valid)
							{
								int res = ExpMatch(data->Config->RegExpData, chkptr->Name, dlgdata->Password);
								if ((res == EXP_NOMATCH) || (res == EXP_ERROR))
								{
									int is_warning = (wcsstr(chkptr->Name, _T("WARN_")) == chkptr->Name);

									WindowHide(dlg, TRUE);
									MainwinShowCheckError(win, chkptr, res, is_warning);
									WindowHide(dlg, FALSE);
									if (!is_warning || (res == EXP_ERROR))
									{
										valid = false;
									}
								}
								chkptr = (CONFCHECK*) chkptr->Next;
							}

							if (valid)
							{
								if (wcscmp(value->Value, dlgdata->Password) != 0)
								{
									free (value->Value);
									value->Value = wcsdup(dlgdata->Password);

									if (item->Child)
									{
										ConfFileCreateValue(data->Config->ConfData, ConfviewGetSel(ctrl));
									}
									ConfFileSetModified(data->Config->ConfData, TRUE);
								}
								else if (created)
								{
									ConfFileSetModified(data->Config->ConfData, TRUE);
								}
								ConfviewUpdateData(ctrl);
								exitloop = TRUE;
							}
						}
						else
						{
							if (created)
							{
								ConfFileDeleteValue(data->Config->ConfData, ConfviewGetSel(ctrl));
							}
							exitloop = TRUE;
						}
					}
					WindowDestroy(dlg);
				}
				else
				{
					int           exitloop = FALSE;
					CUIWINDOW*    dlg;
					INPUTDLGDATA* dlgdata;

					dlg  = InputdlgNew(win, _T("Enter Value"), CWS_NONE, CWS_NONE);
					dlgdata = InputdlgGetData(dlg);
					if (dlgdata)
					{
						wcsncpy(dlgdata->Text, value->Value, MAX_INPUT_SIZE);
						dlgdata->Text[MAX_INPUT_SIZE] = 0;
					}

					WindowCreate(dlg);
					while (dlgdata && !exitloop)
					{
						if (WindowModal(dlg) == IDOK)
						{
							int valid = TRUE;
							CONFCHECK* chkptr = item->FirstCheck;

							while (chkptr && valid)
							{
								int res = ExpMatch(data->Config->RegExpData, chkptr->Name, dlgdata->Text);
								if ((res == EXP_NOMATCH) || (res == EXP_ERROR))
								{
									int is_warning = (wcsstr(chkptr->Name, _T("WARN_")) == chkptr->Name);

									WindowHide(dlg, TRUE);
									MainwinShowCheckError(win, chkptr, res, is_warning);
									WindowHide(dlg, FALSE);
									if (!is_warning || (res == EXP_ERROR))
									{
										valid = false;
									}
								}
								chkptr = (CONFCHECK*) chkptr->Next;
							}

							if (valid)
							{
								if (wcscmp(value->Value, dlgdata->Text) != 0)
								{
									free (value->Value);
									value->Value = wcsdup(dlgdata->Text);

									if (item->Child)
									{
										ConfFileCreateValue(data->Config->ConfData, ConfviewGetSel(ctrl));
									}
									ConfFileSetModified(data->Config->ConfData, TRUE);
								}
								else if (created)
								{
									ConfFileSetModified(data->Config->ConfData, TRUE);
								}
								ConfviewUpdateData(ctrl);
								exitloop = TRUE;
							}
						}
						else
						{
							if (created)
							{
								ConfFileDeleteValue(data->Config->ConfData, ConfviewGetSel(ctrl));
							}
							exitloop = TRUE;
						}
					}
					WindowDestroy(dlg);
				}
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinDeleteLocation
 * Delete an option from the configuration. This only is possible when
 * the selected value is marked as optional (check.d '+')
 * ---------------------------------------------------------------------
 */
static void
MainwinDeleteLocation(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_CONFVIEW);

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config->ConfData)
	{
		return;
	}

	if (!ConfviewIsInDrag(ctrl))
	{
		CONFITEM* item = ConfFileGetItem(data->Config->ConfData, ConfviewGetSel(ctrl));
		if (item)
		{
			CONFVALUE* value = ConfFileGetValue(data->Config->ConfData, ConfviewGetSel(ctrl));
			if (item->IsVirtual)
			{
				if (MessageBox(win, _T("This item will be deleted! Really proceed?"),
					_T("Question"), MB_YESNO) == IDYES)
				{
					ConfFileDeleteItem(data->Config->ConfData, item);
					ConfFileSetModified(data->Config->ConfData, TRUE);
					ConfviewUpdateData(ctrl);
				}
			}
			else if (item && item->Parent && ((item->Type == TYPE_REQUIRED) || (!value)))
			{
				if (MessageBox(win, _T("This will delete the selected array-element! Really proceed?"),
					_T("Question"), MB_YESNO) == IDYES)
				{
					int newpos;
					if (ConfFileDeleteArrayElement(data->Config->ConfData, ConfviewGetSel(ctrl), &newpos))
					{
						ConfFileSetModified(data->Config->ConfData, TRUE);
						ConfviewUpdateData(ctrl);
						ConfviewSetSel(ctrl, newpos);
					}
					else
					{
						MessageBox(win, _T("This value can't be deleted!"), _T("Message"), MB_INFO);
					}
				}
			}
			else
			{
				if (ConfFileDeleteValue(data->Config->ConfData, ConfviewGetSel(ctrl)))
				{
					ConfFileSetModified(data->Config->ConfData, TRUE);
					ConfviewUpdateData(ctrl);
				}
				else
				{
					MessageBox(win, _T("This value can't be deleted!"), _T("Message"), MB_INFO);
				}
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinIncDecLocation
 * Edit current cursor position with '+' and '-' keys
 * ---------------------------------------------------------------------
 */
static void
MainwinIncDecLocation(CUIWINDOW* win, int do_increment)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_CONFVIEW);

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config->ConfData)
	{
		return;
	}

	if (!ConfviewIsInDrag(ctrl))
	{
		CONFITEM* item = ConfFileGetItem(data->Config->ConfData, ConfviewGetSel(ctrl));

		if (item && item->IsReadOnly)
		{
			MessageBox(win, _T("This value can not be modified!"), _T("Message"), MB_OK);
		}
		else if (item && item->Child)
		{
			CONFVALUE* value = ConfFileGetValue(data->Config->ConfData, ConfviewGetSel(ctrl));
			if (value)
			{
				int tmpval;
				wchar_t buffer[48 + 1];

				swscanf(value->Value, _T("%d"),&tmpval);
				if (do_increment && tmpval < 999)
				{
					tmpval++;
				}
				else if (tmpval > 0)
				{
					tmpval--;
				}

				swprintf(buffer, 48, _T("%i"),tmpval);
				free(value->Value);
				value->Value = wcsdup(buffer);

				ConfFileCreateValue(data->Config->ConfData, ConfviewGetSel(ctrl));
				ConfFileSetModified(data->Config->ConfData, TRUE);
				ConfviewUpdateData(ctrl);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinCreateItem
 * Create a new item (if we are in tolerant mode)
 * ---------------------------------------------------------------------
 */
static void
MainwinCreateItem(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_CONFVIEW);

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config->ConfData)
	{
		return;
	}

	if (!ConfviewIsInDrag(ctrl) && data->Config->BeTolerant)
	{
		CONFITEM* item;
		CUIWINDOW* dlg;
		CREATEDLGDATA* dlgdata;

		dlg = CreatedlgNew(win, _T("Create new item"), CWS_NONE, CWS_NONE);
		dlgdata = CreatedlgGetData(dlg);
		if (dlg && dlgdata)
		{
			dlgdata->ConfData = data->Config->ConfData;

			WindowCreate(dlg);
			if (WindowModal(dlg) == IDOK)
			{
				ConfFileAddItem(data->Config->ConfData,
					dlgdata->Name,
					_T("NONE"),
					NULL,NULL,FALSE,NULL,TYPE_REQUIRED,TRUE);

				item = ConfFileFindItem(data->Config->ConfData, dlgdata->Name);
				if (item)
				{
					short index[NUM_DIM];
					int   lineindex;

					memset(index, 0, NUM_DIM * sizeof(short));

					ConfFileAddBlockComment(data->Config->ConfData,
						_T("#--------------------------------------")
						_T("---------------------------------------"));
					ConfFileAddBlockComment(data->Config->ConfData,
						_T("# User variable (UNCHECKED)"));
					ConfFileAddBlockComment(data->Config->ConfData,
						_T("#--------------------------------------")
						_T("---------------------------------------"));
					ConfFileUseBlockComment(data->Config->ConfData, item, dlgdata->Name);

					lineindex = ConfFileGetLineIndex(data->Config->ConfData, item, index);
					ConfFileCreateValue(data->Config->ConfData, lineindex);

					ConfFileSetModified(data->Config->ConfData, TRUE);
					ConfviewUpdateData(ctrl);
					ConfviewSetSel(ctrl, lineindex);
				}
			}
			WindowDestroy(dlg);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinManualSaveOptions
 * Check and save the new configuration to disk
 * ---------------------------------------------------------------------
 */
static void
MainwinManualSaveOptions(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	int result;

	ctrl = WindowGetCtrl(win, IDC_CONFVIEW);
	if (!data->Config->ConfData)
	{
		return;
	}

	result = MainwinCheckOptions(win, data);
	if (result == CHECK_ERRORS)
	{
		if (MessageBox(win, _T("The configuration is faulty!\n")
			_T("Do you really want to save?"),
			_T("Question"), MB_YESNO | MB_DEFBUTTON1) == IDYES)
		{
			result = CHECK_OK;
		}
	}
	if ((result == CHECK_OK) || (result == CHECK_WARNINGS))
	{
		MainwinSaveOptions(win, data);
	}
}

/* ---------------------------------------------------------------------
 * MainwinShowCheckError
 * Show errors resulting from value checks with regular expressions
 * ---------------------------------------------------------------------
 */
static void
MainwinShowCheckError(CUIWINDOW* win, CONFCHECK* chkptr, int res, int is_warning)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	if (res == EXP_NOMATCH)
	{
		const wchar_t* message;
		MainwinFreeMessage(win);

		if (is_warning)
		{
			MainwinAddMessage(win, _T("critical value of variable!"));
		}
		else
		{
			MainwinAddMessage(win, _T("wrong value of variable!"));
		}

		message = ExpGetExpressionError(data->Config->RegExpData, chkptr->Name);
		if (message)
		{
			const wchar_t* start = &message[0];
			const wchar_t* end = &message[0];
			const wchar_t* next;
			wchar_t buffer[128 + 1];
			int width = 65;

			while (*start != 0)
			{
				next = wcschr(start, _T(' '));
				if (!next) next = &message[wcslen(message)];

				while ((next - start <= width))
				{
					end = next;

					if (*next != 0)
					{
						next = wcschr(next + 1, _T(' '));
						if (!next) next = &message[wcslen(message)];
					}
					else break;
				}

				if ((next - start > width)&&(end == start))
				{
					end += width;
				}

				wcscpy(buffer, _T("    "));
				wcsncpy(&buffer[4], start, end - start);
				buffer[end - start + 4] = 0;

				MainwinAddMessage(win, buffer);

				start = end;

				while (*start == ' ') start++;
			}
		}
		MainwinAddMessage(win, chkptr->Name);

		if (is_warning)
		{
			MessageBox(win, data->ErrorMsg, _T("Warning"), MB_INFO);
		}
		else
		{
			MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
		}

		MainwinFreeMessage(win);
	}
	else if (res == EXP_ERROR)
	{
		MessageBox(win,
			_T("An internal error has occured!\n\n")
			_T("The regular expression associated with this value could\npropably not be compiled.\n")
			_T("Please contact the maintainer of the software in question."), _T("Error"), MB_ERROR);
	}
}

/* ---------------------------------------------------------------------
 * MainwinSaveOptions
 * Save data to /etc/config.d
 * ---------------------------------------------------------------------
 */
static int
MainwinSaveOptions(CUIWINDOW* win, MAINWINDATA* data)
{
	MainwinFreeMessage(win);
	data->Config->NumErrors = 0;
	data->Config->NumWarnings = 0;

	ConfFileWriteConfig(data->Config->ConfData, data->Config->ConfFileName);

	if (data->Config->NumErrors || data->Config->NumWarnings)
	{
		wchar_t buffer[128];

		swprintf(buffer, 128, _T("%i error(s), %i warning(s) writing file"),
			data->Config->NumErrors, data->Config->NumWarnings);
		MainwinAddMessage(win, buffer);
		MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
	}
	else
	{
		MessageBox(win, _T("Config saved successfully!"), _T("Info"), MB_OK);
		ConfFileSetModified(data->Config->ConfData, FALSE);
	}
	MainwinFreeMessage(win);
	return (data->Config->NumErrors == 0);
}

/* ---------------------------------------------------------------------
 * MainwinCheckOptions
 * Check config options for beeing correct / use eischk as external
 * program
 * ---------------------------------------------------------------------
 */
static int
MainwinCheckOptions(CUIWINDOW* win, MAINWINDATA* data)
{
	int    result = CHECK_OK;
	wchar_t  tmppath[64 + 1];
	const  wchar_t* p[11];
	wchar_t* win_name;
	wchar_t* coproc_name;
	wchar_t  logfile[64 + 1];
	int    status;
	int    msgflags = MB_ERROR;

	MainwinFreeMessage(win);
	data->Config->NumErrors = 0;
	data->Config->NumWarnings = 0;

	/* execute eischk to make sure everyting is all right */
	swprintf(logfile, 64, _T("/tmp/edit-conf%li.log"), (unsigned long)getpid());

	/* create temp-path encoded with our project id
	   we don't care about errors here, since it becomes
	   obvious lateron */
	swprintf(tmppath, 64, _T("/tmp/ece%li"),(unsigned long)getpid());

	CreateDirectory(tmppath, 0700);

	if (data->Config->RunMkfli4l)
	{
		if (MainwinCopyFile(data->Config->ConfFileName, data->Config->TempConfFileName))
		{
			ConfFileWriteConfig(data->Config->ConfData, data->Config->ConfFileName);
		}
		else
		{
			MainwinError(win,
				_T("Unable to create backup a file!"),
				data->Config->ConfFileName,
				0,
				FALSE);
		}

		win_name = _T("mkfli4l");
		coproc_name = _T("unix/mkfli4l");

		p[0] = coproc_name;
		p[1] = _T("-c");
		p[2] = data->Config->ConfigFileBase;
		p[3] = _T("-x");
		p[4] = _T("check");
		p[5] = _T("-l");
		p[6] = logfile;
		p[7] = 0;
	}
	else
	{
		ConfFileWriteConfig(data->Config->ConfData, data->Config->TempConfFileName);

		win_name = _T("EISCHK");
		coproc_name = _T("/var/install/bin/eischk");

		p[0] = _T("eischk");
		p[1] = _T("-c");
		p[2] = tmppath;
		p[3] = _T("-x");
		p[4] = _T("/etc/check.d");
		p[5] = _T("-l");
		p[6] = logfile;
		p[7] = _T("-p");
		p[8] = data->Config->ConfigName;
		p[9] = 0;

		if (data->Config->BeTolerant)
		{
			p[9] = _T("--weak");
			p[10] = 0;
		}
	}
	if (data->Config->NumErrors > 0)
	{
		result = CHECK_ERRORS;
	}
	else
	{
		MainwinFreeMessage(win);
		data->Config->NumErrors = 0;
		data->Config->NumWarnings = 0;

		if ((data->Config->NumErrors == 0) &&
			RunCoProcess(coproc_name, (wchar_t**) p, MainwinRunOut, win, &status))
		{
			if ((data->Config->NumErrors > 0) &&
				((status != 0) ||
				!data->Config->BeTolerant))
			{
				if (status != 0)
				{
					result = CHECK_ERRORS;
				}
				else
				{
					result = CHECK_WARNINGS;
					msgflags = MB_OK;
				}
			}
			else if (status != 0)
			{
				result = CHECK_SYSERROR;
			}

		}
	}

	/* remove log file */
	FileRemove(logfile);

	/* remove temporary config file */
	if (data->Config->RunMkfli4l)
	{
		if (MainwinCopyFile(data->Config->TempConfFileName, data->Config->ConfFileName))
		{
			FileRemove(data->Config->TempConfFileName);
		}
		else
		{
			MainwinError(win,
				_T("Unable to restore config file!"),
				data->Config->ConfFileName,
				0,
				FALSE);
		}
	}
	else
	{
		FileRemove(data->Config->TempConfFileName);
	}

	/* remove directory */
	RemoveDirectory(tmppath);

	/* Display error messages */
	if ((result == CHECK_ERRORS) || (result == CHECK_WARNINGS))
	{
		MessageBox(win, data->ErrorMsg, win_name, msgflags);
	}
	MainwinFreeMessage(win);

	return result;
}


/* ---------------------------------------------------------------------
 * MainwinCheckUserDialog
 * Check if an user defined dialog is available
 * ---------------------------------------------------------------------
 */
static CONFCHECK*
MainwinCheckUserDialog(CUIWINDOW* win, MAINWINDATA* data, CONFITEM* item)
{
	CONFCHECK* check;
	wchar_t tmpfile[255 + 1];
	
	CUI_USE_ARG(win);

	check = item->FirstCheck;
	while (check)
	{
		swprintf(tmpfile, 255, _T("%ls/%ls.sh"), data->Config->DialogPath, check->Name);
		tmpfile[255] = 0;

		if (FileAccess(tmpfile, R_OK) == 0)
		{
			return check;
		}
		check = (CONFCHECK*) check->Next;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MainwinShowStatusBar
 * Show status bar accoring to loaded config
 * ---------------------------------------------------------------------
 */
static void
MainwinShowStatusBar(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	if (data->Config)
	{
		if (data->Config->BeTolerant)
		{
			WindowSetLStatusText(win, IDLE_STATUS_TEXT_1);
		}
		else if (data->Config->ConfData && data->Config->ConfData->NumOptional)
		{
			if (ConfFileGetOptionalOn())
				WindowSetLStatusText(win, IDLE_STATUS_TEXT_2_ON);
			else
				WindowSetLStatusText(win, IDLE_STATUS_TEXT_2_OFF);
		}
		else
		{
			WindowSetLStatusText(win, IDLE_STATUS_TEXT_2);
		}
	}
	else
	{
		WindowSetLStatusText(win, IDLE_STATUS_TEXT_2);
	}
}


/* ---------------------------------------------------------------------
 * MainwinApi
 * API for libcui scripting interface
 * ---------------------------------------------------------------------
 */
static int
MainwinApi(int func_nr, int argc, const wchar_t* argv[])
{
	switch(func_nr)
	{
	case ECE_API_GETVALUE:
		MainwinApiGetValue(argc, argv);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * MainwinApiGetValue
 * API for searching values within the configuration
 * ---------------------------------------------------------------------
 */
static void
MainwinApiGetValue(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB*   mainwin;
		unsigned long wndnr;
		const wchar_t*   valname;

		swscanf(argv[0], _T("%ld"), &wndnr);
		valname = argv[1];

		mainwin = StubFind(wndnr);
		if (mainwin && mainwin->Window && (wcscmp(mainwin->Window->Class, _T("EDIT-CONF.CUI")) == 0))
		{
			MAINWINDATA* data = (MAINWINDATA*) mainwin->Window->InstData;
			if (data)
			{
				CONFVALUE* val = ConfFileFindValue(data->Config->ConfData, valname);
				if (val)
				{
					BackendStartFrame(_T('R'), wcslen(val->Value) + 32);
					BackendInsertInt (ERROR_SUCCESS);
					BackendInsertStr (val->Value);
					BackendSendFrame ();
				}
				else
				{
					BackendWriteError(ERROR_FAILED);
				}
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

