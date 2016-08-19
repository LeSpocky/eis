/* ---------------------------------------------------------------------
 * File: mainwin.c
 * (application main window)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: mainwin.c 42871 2016-08-16 20:59:33Z dv $
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
#include "shelldlg.h"

/* status text */

#define IDLE_STATUS_TEXT _T("Commands: ENTER=Select Left=Back F3=Move F10=Exit")
#define DRAG_STATUS_TEXT _T("Ok, move menu item!  ESC=Abort F3=End Move F10=Exit")

/* prototypes */

static void  MainMenuClickedHook( void* w, void* c );
static int   MainMenuPreKeyHook ( void* w, void* c, int key );

static wchar_t* GetAbsolutePath   ( int type, 
                                  const wchar_t* relpath, 
                                  const wchar_t* package, 
                                  wchar_t* abspath, 
                                  int len );

static int   GetSinglePackage   ( const wchar_t** ppchar, wchar_t* pname, int size );

static int   RunPrePostScript   ( CUIWINDOW* win,
                                  const wchar_t* script, const wchar_t* task, const wchar_t* package,
                                  const wchar_t* action, const wchar_t* param1, const wchar_t* param2,
                                  const wchar_t* itemname);

static void  UpdateMenuStack    ( CUIWINDOW* win );


static void  MainwinErrorOut    ( void* w, 
                                  const wchar_t* errmsg, 
                                  const wchar_t* filename,
                                  int linenr, 
                                  int is_warning );

static void  MainwinRunOut      ( const char* buffer, int source, void* instance );

static void  MainUpdateTitle    ( CUIWINDOW* win, EISMENU* menu );
static void  MainCloseMenu      ( CUIWINDOW* win, EISMENU* menu );
static void  MainExecuteMenu    ( CUIWINDOW* win, int index, MAINWINDATA* data );
static void  MainExecuteSubmenu ( CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data );
static void  MainExecuteDocument( CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data );
static void  MainExecuteConfig  ( CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data );
static void  MainExecuteService ( CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data );
static void  MainExecuteScript  ( CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data );

static void  MainOpenDragMode   ( CUIWINDOW* win );
static void  MainEscDragMode    ( CUIWINDOW* win );
static void  MainCloseDragMode  ( CUIWINDOW* win );

/* ---------------------------------------------------------------------
 * MainCreateHook
 * Handle EVENT_CREATE events
 * ---------------------------------------------------------------------
 */
static void
MainCreateHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	wchar_t        version[32 + 1];
	char         tmp[64 + 1];

	/* read hostname */
	gethostname(tmp, 64);
	tmp[64] = 0;
	data->Hostname = MbToTCharDup(tmp);

	/* read user name */
	if (getenv("USER"))
	{
		data->User = MbToTCharDup(getenv("USER"));
	}
	else
	{
		data->User = wcsdup(_T("unknown"));
	}

	swprintf(version, 32, _T("V%s"), VERSIONSTR);
	WindowSetRStatusText(win, version);

	WindowSetLStatusText(win, IDLE_STATUS_TEXT);
}


/* ---------------------------------------------------------------------
 * MainInitHook
 * Handle EVENT_INIT events 
 * ---------------------------------------------------------------------
 */
static void
MainInitHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	wchar_t        buffer[512 + 1];

	data->FirstMenu = EisMenuCreate();
	data->LastMenu  = data->FirstMenu;

	MainwinFreeMessage(win);
	data->NumErrors = 0;
	data->NumWarnings = 0;

	EisMenuReadFile(data->FirstMenu,
	                GetAbsolutePath(ITEMTYPE_MENU, data->Config->MenuFile, _T(""), buffer, 512),
			MainwinErrorOut, win);

	if (data->NumErrors || data->NumWarnings)
	{
		MainwinAddMessage(win, _T(""));

		swprintf(buffer, 512, _T("%i error(s), %i warning(s)"),
		        data->NumErrors, data->NumWarnings);
		MainwinAddMessage(win, buffer);

		swprintf(buffer, 512, _T("file: %ls"), data->Config->MenuFile);

		MainwinAddMessage(win, buffer);

		MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
		WindowQuit(EXIT_FAILURE);
	}
	else
	{
		data->LastMenu->Menu = EisMenuBuildGUI(data->LastMenu, win, win);
		MenuSetMenuClickedHook(data->LastMenu->Menu, MainMenuClickedHook, win);
		MenuSetPreKeyHook(data->LastMenu->Menu, MainMenuPreKeyHook, win);
		WindowCreate     (data->LastMenu->Menu);
		MenuSelectItem   (data->LastMenu->Menu, data->LastMenu->LastChoice);
		WindowSetFocus   (data->LastMenu->Menu);
		MainUpdateTitle  (win, data->LastMenu);
	}
	MainwinFreeMessage(win);
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

	EISMENU* workptr = data->LastMenu;
	while (workptr)
	{
		data->LastMenu = (EISMENU*) workptr->Previous;
		MainCloseMenu(win, workptr);
		workptr = data->LastMenu;
	}

	if (data->HelpData) XmlDelete(data->HelpData);
	if (data->Hostname) free(data->Hostname);
	if (data->User) free(data->User);
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
	EISMENU*     menu;

	WindowGetClientRect(win, &rc);
	if ((data->Terminal) && ((rc.H / 2) > 0))
	{
		WindowMove(data->Terminal, 0, LINES - rc.H / 2, rc.W - 2, rc.H / 2 - 1);
	}

	menu = data->FirstMenu;
	while (menu)
	{
		if (menu->Menu)
		{
			EisMenuResize(menu->Menu, menu, win);
		}
		menu = (EISMENU*) menu->Next;
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
		if (key == KEY_F(10))
		{
			WindowQuit(0);
			return TRUE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MainSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
MainSetFocusHook(void* w, void* old)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	
	CUI_USE_ARG(old);

	if (!data || !data->LastMenu || !data->LastMenu->Menu) 
	{
		return;
	}

	WindowSetFocus(data->LastMenu->Menu);
}

/* ---------------------------------------------------------------------
 * MainMenuPreKeyHook
 * Menu pre key processing
 * ---------------------------------------------------------------------
 */
static int 
MainMenuPreKeyHook(void* w, void* c, int key)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	switch(key)
	{
	case KEY_F(3):
		if (!data->DragMode)
		{
			MainOpenDragMode(win);
		}
		else
		{
			MainCloseDragMode(win);
		}
		return TRUE;
	case KEY_F(10): 
		WindowQuit(EXIT_SUCCESS);
		return TRUE;
	case KEY_RIGHT:
		MainMenuClickedHook(w, c);
		return TRUE;
	case KEY_LEFT:
	case KEY_ESC:
		if (data->DragMode)
		{
			MainEscDragMode(win);
		}
		else
		{
			if (data->LastMenu->Previous)
			{
				data->LastMenu = data->LastMenu->Previous;
				MainCloseMenu(win, data->LastMenu->Next);
				data->LastMenu->Next = NULL;

				UpdateMenuStack(win);

				MainUpdateTitle(win, data->LastMenu);
			}
			else if (key == KEY_ESC)
			{
				if ((data->User == NULL) || (wcscmp(data->User, _T("eis")) != 0))
				{
					WindowQuit(EXIT_SUCCESS);
				}
			}
		}
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MainMenuClickedHook
 * Menu select hook
 * ---------------------------------------------------------------------
 */
static 
void MainMenuClickedHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* menu = (CUIWINDOW*) c;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	/* if the clicked menu is not the top menu,
	   all menus above the clicked one are closed */
	if (menu != data->LastMenu->Menu)
	{
		while (menu != data->LastMenu->Menu)
		{
			if (data->LastMenu->Previous)
			{
				data->LastMenu = data->LastMenu->Previous;
				MainCloseMenu(win, data->LastMenu->Next);
				data->LastMenu->Next = NULL;
			}
			else
			{
				break;
			}
		}
		return;
	}

	/* else handle clicked event as normal */
	if (data->DragMode)
	{
		MainCloseDragMode(win);
	}
	else
	{
		MENUITEM* item = MenuGetSelectedItem(c);
		if (item)
		{
			int index = item->ItemId;
			if (index > 0)
			{
				data->LastMenu->LastChoice = index;
				MainExecuteMenu(win, index, data);
			}
			else if (index==0)
			{
				if (data->LastMenu->Previous)
				{
					data->LastMenu = data->LastMenu->Previous;
					MainCloseMenu(win, data->LastMenu->Next);
					data->LastMenu->Next = NULL;

					UpdateMenuStack(win);

					MainUpdateTitle(win, data->LastMenu);
				}
				else
				{
					WindowQuit(EXIT_SUCCESS);
				}
			}
		}
	}
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
		mainwin->Class = _T("SHOW-MENU.CUI");
		WindowColScheme(mainwin, _T("DESKTOP"));
		WindowSetText(mainwin, text);
		WindowSetCreateHook(mainwin, MainCreateHook);
		WindowSetDestroyHook(mainwin, MainDestroyHook);
		WindowSetInitHook(mainwin, MainInitHook);
		WindowSetPaintHook(mainwin, MainPaintHook);
		WindowSetKeyHook(mainwin, MainKeyHook);
		WindowSetSizeHook(mainwin, MainSizeHook);
		WindowSetSetFocusHook(mainwin, MainSetFocusHook);

		mainwin->InstData = (MAINWINDATA*) malloc(sizeof(MAINWINDATA));
		((MAINWINDATA*)mainwin->InstData)->HelpData = NULL;
		((MAINWINDATA*)mainwin->InstData)->ErrorMsg = NULL;
		((MAINWINDATA*)mainwin->InstData)->Config = NULL;
		((MAINWINDATA*)mainwin->InstData)->Terminal = NULL;
		((MAINWINDATA*)mainwin->InstData)->FirstMenu = NULL;
		((MAINWINDATA*)mainwin->InstData)->LastMenu = NULL;
		((MAINWINDATA*)mainwin->InstData)->DragMode = FALSE;
		((MAINWINDATA*)mainwin->InstData)->User = NULL;
		((MAINWINDATA*)mainwin->InstData)->Hostname = NULL;

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
	if (win && (wcscmp(win->Class, _T("SHOW-MENU.CUI")) == 0))
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
	if (win && (wcscmp(win->Class, _T("SHOW-MENU.CUI")) == 0))
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
	if (win && (wcscmp(win->Class, _T("SHOW-MENU.CUI")) == 0))
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
	if (win && (wcscmp(win->Class, _T("SHOW-MENU.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		if (!data->ErrorMsg)
		{
			data->ErrorMsg = wcsdup(msg);
		}
		else
		{
			int    len = wcslen(data->ErrorMsg) + wcslen(msg) + 2;
			wchar_t* err = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

			swprintf(err, len, _T("%ls\n%ls"), data->ErrorMsg, msg);

			free(data->ErrorMsg);
			data->ErrorMsg = err;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainwinShellExecute
 * Open a modal shell dialog and execute a command
 * ---------------------------------------------------------------------
 */
int
MainwinShellExecute(CUIWINDOW* win, const wchar_t* cmd, const wchar_t* title)
{
	if (win && (wcscmp(win->Class, _T("SHOW-MENU.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		CUIRECT rc = {0, 0, 40, 10};
		CUIRECT trc;

		WindowGetClientRect(win, &rc);

		trc.X = 0;
		trc.Y = LINES - rc.H / 2;
		trc.W = rc.W - 2;
		trc.H = rc.H / 2 - 1;

		data->Terminal = ShellDlgNew(win, &trc, CWS_NONE, CWS_NONE);
		if (data->Terminal)
		{
			SHELLDLGDATA* dlgdata = ShellDlgGetData(data->Terminal);
			if (dlgdata)
			{
				wcsncpy(dlgdata->Command, cmd, 256);
				dlgdata->Command[256] = 0;

				wcsncpy(dlgdata->Title, title, 128);
				dlgdata->Title[128] = 0;
			}
			WindowCreate(data->Terminal);
			WindowModal(data->Terminal);
			WindowDestroy(data->Terminal);
			data->Terminal = NULL;
		}
	}
	return TRUE;
}


/* helper functions */

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
		if (data->NumErrors < 20)
		{
			wchar_t* buf = MbToTCharDup(buffer);
			if (buf)
			{
				MainwinAddMessage(win, buf);
				free(buf);
			}
		}
		else if (data->NumErrors == 20)
		{
			MainwinAddMessage(win, _T("... more errors"));
		}
		data->NumErrors ++;
	}
}


/* ---------------------------------------------------------------------
 * GetSinglePackage
 * Retreive one package name from the list of package names given
 * in "package" menu attribute. If the end of the list has been reached
 * FALSE is returned
 * ---------------------------------------------------------------------
 */
static int
GetSinglePackage(const wchar_t** ppchar, wchar_t* pname, int size)
{
	const wchar_t* pos1 = *ppchar;
	const wchar_t* pos2;
	int len;

	while (*pos1 == _T(' '))
	{
		pos1++;
	}

	if (*pos1 == _T('\0'))
	{
		*ppchar = pos1;
		return FALSE;
	}

	pos2 = wcschr(pos1, _T(' '));
	if (!pos2)
	{
		pos2 = pos1 + wcslen(pos1);
	}

	len = pos2 - pos1;
	if (len > size)
	{
		len = size;
	}
	wcsncpy(pname, pos1, len);
	pname[len] = 0;

	*ppchar = pos2;
	return TRUE;
}


/* ---------------------------------------------------------------------
 * GetInterpreter
 * Tries to read the required interpreter from the shell script file.
 * If the given file exists and is not a binary ELF file, the return
 * value is TRUE. If no interpreter can be found on the first line
 * of the shell script, "/bin/sh" is used as default.
 * In case of binary files and non existent files, FALSE is returned.
 * ---------------------------------------------------------------------
 */
static int
GetInterpreter(const wchar_t* file, wchar_t* interpreter, int c)
{
	int result = FALSE;
	FILE* in;

	in = FileOpen(file, _T("rt"));
	if (in)
	{
		char buffer[128 + 1];

		if (fgets(buffer, 128, in))
		{
			if (!(((unsigned char)buffer[0] == 0x7F) && (buffer[1] == 'E') &&
			    (buffer[2] == 'L') && (buffer[3] == 'F')) && 
			    (buffer[0] != '\n') && (buffer[0] != '\0'))
			{
				char* ch = buffer;

				interpreter[0] = 0;
				if (buffer[strlen(buffer) - 1] == '\n')
				{
					buffer[strlen(buffer) - 1] = '\0';
                                }
				if (*ch == '#')
				{
					ch++;
					while ((*ch == ' ') || (*ch == '\t'))
					{
						ch++;
					}

					if (*ch == '!')
					{
						ch++;
						while ((*ch == ' ') || (*ch == '\t'))
						{
							ch++;
						}

						mbstowcs(interpreter, ch, c);
						interpreter[c] = 0;
					}
				}
				if (interpreter[0] == 0)
				{
					wcsncpy(interpreter, _T("/bin/sh"), c);
					interpreter[c] = 0;
				}
				result = TRUE;
			}
		}
		FileClose(in);
	}
	return result;
}

/* ---------------------------------------------------------------------
 * RunPrePostScript
 * Run program/script as pre or post action. If the program/script can
 * be executed and returns an exit code of value 0, the function returns
 * TRUE. Otherwise, the function display's an error message (composed of
 * the text output generated by the co process) and returns FALSE.
 * ---------------------------------------------------------------------
 */
static int
RunPrePostScript(CUIWINDOW* win,
                 const wchar_t* script, const wchar_t* task, const wchar_t* package,
                 const wchar_t* action, const wchar_t* param1, const wchar_t* param2,
                 const wchar_t* itemname)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	int   result = TRUE;
	int   status;
	wchar_t scriptfile[512 + 1];
	wchar_t interpreter[128 + 1];
	const wchar_t* p[9];

	GetAbsolutePath(ITEMTYPE_SCRIPT, script, _T(""), scriptfile, 512);

	MainwinFreeMessage(win);
	data->NumErrors = 0;
	data->NumWarnings = 0;

	if (!package || (package[0] == 0))
	{
		package = _T("{none}");
	}

	if (GetInterpreter(scriptfile, interpreter, 128))
	{
		p[0] = interpreter;
		p[1] = scriptfile;
		p[2] = task;
		p[3] = package;
		p[4] = action;
		p[5] = param1 ? param1 : _T("");
		p[6] = param2 ? param2 : _T("");
		p[7] = itemname;
		p[8] = NULL;

		/* execute */
		result = RunCoProcess(interpreter, (wchar_t**) p, MainwinRunOut, win, &status);
	}
	else
	{
		/* initialize for binary files */
		p[0] = scriptfile;
		p[1] = task;
		p[2] = package;
		p[3] = action;
		p[4] = param1 ? param1 : _T("");
		p[5] = param2 ? param2 : _T("");
		p[6] = itemname;
		p[7] = 0;

		/* execute */
		result = RunCoProcess(scriptfile, (wchar_t**) p, MainwinRunOut, win, &status);
	}

	if (result && (status != 0))
	{
		result = FALSE;
	}

	if (!result)
	{
		MainwinAddMessage(win, _T(""));
		MainwinAddMessage(win, _T("[ENTER] = Close"));
		MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
        }
	MainwinFreeMessage(win);

        return result;
}

/* ---------------------------------------------------------------------
 * UpdateMenuStack
 * Update the contents of the GUI menus if necessary
 * ---------------------------------------------------------------------
 */
static void  
UpdateMenuStack(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	EISMENU* workptr = data->FirstMenu;

	MainwinFreeMessage(win);
	data->NumErrors = 0;
	data->NumWarnings = 0;

	/* run through the menu stack and update menus */
	while (workptr)
	{
		if (EisMenuUpdate(workptr, MainwinErrorOut, win))
		{
			workptr->Menu = EisMenuBuildGUI(workptr, NULL, win);
			MenuSelectItem(workptr->Menu, workptr->LastChoice);
		}
		workptr = (EISMENU*) workptr->Next;
	}

	/* now error messages are displayed here */
	MainwinFreeMessage(win);
}

/* ---------------------------------------------------------------------
 * GetAbsolutePath
 * Translate a repative path into an absolute path, according to
 * the type of file, that has to be extended (type).
 * If relpath already contains an absolute path, the function copys
 * the data to the abspath buffer without modification.
 * ---------------------------------------------------------------------
 */
static wchar_t*
GetAbsolutePath( int type, const wchar_t* relpath, const wchar_t* package, 
                 wchar_t* abspath, int len )
{
	if (len > 0)
	{
		abspath[0] = 0;
		if (relpath[0] != _T('/'))
		{
			wchar_t* format = NULL;
			switch(type)
			{
			case ITEMTYPE_MENU:
				format = _T("/var/install/menu/%ls");
				swprintf(abspath,len,format,relpath);
				break;
			case ITEMTYPE_DOC:
				format = _T("/usr/share/doc/%ls/%ls");
				swprintf(abspath,len,format,package,relpath);
				break;
			case ITEMTYPE_EDIT:
				format = _T("/etc/config.d/%ls");
				swprintf(abspath,len,format,package);
				break;
			case ITEMTYPE_INIT:
				format = _T("/etc/init.d/%ls");
				swprintf(abspath,len,format,package);
				break;
			case ITEMTYPE_SCRIPT:
				format = _T("/var/install/bin/%ls");
				swprintf(abspath,len,format,relpath);
				break;
			}
			abspath[len] = 0;
		}
		else
		{
			wcsncpy(abspath, relpath, len);
			abspath[len] = 0;
		}
	}
	return abspath;
}

/* ---------------------------------------------------------------------
 * MainwinErrorOut
 * Error callback routine for text file parser
 * ---------------------------------------------------------------------
 */
static void
MainwinErrorOut(void* w, const wchar_t* errmsg, const wchar_t* filename,
             int linenr, int is_warning)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	
	CUI_USE_ARG(filename);

	if (win)
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;

		if ((data->NumErrors + data->NumWarnings) < 8)
		{
			wchar_t err[512 + 1];
			if (is_warning)
			{
				swprintf(err, 512, _T("WARNING: (%i): %ls"), linenr, errmsg);
				MainwinAddMessage(win, err);
			}
			else
			{
				swprintf(err, 512, _T("ERROR: (%i): %ls"), linenr, errmsg);
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
 * MainUpdateTitle
 * Update title text of main window
 * ---------------------------------------------------------------------
 */
static void
MainUpdateTitle (CUIWINDOW* win, EISMENU* menu)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	wchar_t ttext[128 + 1];

	CUI_USE_ARG(menu);

	swprintf(ttext, 128, _T("%ls@%ls"), data->User, data->Hostname);
	ttext[128] = 0;

	WindowSetLText(win, ttext);
	WindowSetRText(win, EisMenuGetSubTitle(data->LastMenu));
}

/* ---------------------------------------------------------------------
 * MainCloseMenu
 * Close sub menu and execute post-script if required
 * ---------------------------------------------------------------------
 */
static void
MainCloseMenu(CUIWINDOW* win, EISMENU* menu)
{
	CUIWINDOW* nextwin = NULL;

	if (menu->PostProcess)
	{
		const wchar_t *itemname = _T("");

		/* try to resolve previously selected item */
		if (menu->Previous)
		{
			EISMENUITEM* item = EisMenuGetItem(
				((EISMENU*)menu->Previous),
				((EISMENU*)menu->Previous)->LastChoice);
			if (item)
			{
				itemname = item->Name;
			}
		}

		/* run menu post script */
		RunPrePostScript(
		    win,
		    menu->PostProcess->ScriptFile,
		    _T("post"),
		    menu->PostProcess->PackageName,
		    _T("menu"),
		    menu->PostProcess->MenuFile,
		    NULL,
		    itemname);
	}
	if ((menu->Previous) && (((EISMENU*)menu->Previous)->Menu))
	{
		nextwin = ((EISMENU*)menu->Previous)->Menu;
	}
	EisMenuDelete(menu);
	WindowSetFocus(nextwin);
}


/* ---------------------------------------------------------------------
 * MainExecuteMenu
 * The user selected an item from the menu. Now we have to perform the
 * action that is associated to this item.
 * ---------------------------------------------------------------------
 */
static void
MainExecuteMenu(CUIWINDOW* win, int index, MAINWINDATA* data)
{
	EISMENUITEM* item = EisMenuGetItem(data->LastMenu, index);
	if (item)
	{
		switch(item->Type)
		{
		case ITEMTYPE_MENU:   MainExecuteSubmenu(win, item, data); break;
		case ITEMTYPE_DOC:    MainExecuteDocument(win, item, data); break;
		case ITEMTYPE_EDIT:   MainExecuteConfig(win, item, data); break;
		case ITEMTYPE_INIT:   MainExecuteService(win, item, data); break;
		case ITEMTYPE_SCRIPT: MainExecuteScript(win, item, data); break;
		}
	}
}

/* ---------------------------------------------------------------------
 * MainExecuteSubmenu
 * The item selected by the user is a Submenu (<menu>-Tag). This
 * function creates the new submenu by reading the data of the file
 * stored in the "FILE" attribute.
 * ---------------------------------------------------------------------
 */
static void
MainExecuteSubmenu(CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data)
{
	EISMENUATTR* file = EisMenuGetAttr(item, _T("FILE"));
	EISMENUATTR* package = EisMenuGetAttr(item, _T("PACKAGE"));
	EISMENUATTR* preprocess = EisMenuGetAttr(item, _T("PRE"));
	EISMENUATTR* postprocess = EisMenuGetAttr(item, _T("POST"));
	wchar_t  menufile[512 + 1];
	wchar_t* packname = NULL;

	if (file)
	{
		packname = data->LastMenu->Package;
		if (package)
		{
			packname = package->Value;
		}

		/* get absolute file path */
		GetAbsolutePath(ITEMTYPE_MENU, file->Value, _T(""), menufile, 512);

		if (!preprocess ||
		   RunPrePostScript(
			win, 
			preprocess->Value, 
			_T("pre"), 
			packname, 
			_T("menu"), 
			menufile, 
			NULL,
			item->Name))
		{
			EISMENU* newmenu = EisMenuCreate();

			/* assign package info */
			EisMenuAssignPackage(newmenu, packname);

			MainwinFreeMessage(win);
			data->NumErrors = 0;
			data->NumWarnings = 0;

			EisMenuReadFile(newmenu, menufile,
					MainwinErrorOut, win);

			if (data->NumErrors || data->NumWarnings)
			{
				wchar_t buffer[128 + 1];

				MainwinAddMessage(win, _T(""));

				swprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
				        data->NumErrors, data->NumWarnings);
				MainwinAddMessage(win, buffer);
#ifdef _UNICDE
				swprintf(buffer, 128, _T("file: %ls"), data->Config->MenuFile);
#else
				swprintf(buffer, 128, _T("file: %s"), data->Config->MenuFile);
#endif
				MainwinAddMessage(win, buffer);

				MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
			}
			MainwinFreeMessage(win);

                        /* if post processing is required, we have to copy all data
                           to the menu structure */
                        if (postprocess)
                        {
                                newmenu->PostProcess = (EISMENUPOST*) malloc(sizeof(EISMENUPOST));
                                newmenu->PostProcess->ScriptFile = wcsdup(postprocess->Value);
                                newmenu->PostProcess->PackageName = wcsdup(packname);
                                newmenu->PostProcess->MenuFile = wcsdup(menufile);
                        }

			if (data->NumErrors == 0)
			{
				CUIWINDOW* parent = data->LastMenu->Menu;

				data->LastMenu->Next = newmenu;
				newmenu->Previous = data->LastMenu;

				if (wcscmp(file->Value, _T("setup.system.base.menu"))==0)
				{
					EISMENUITEM* item = EisMenuAddItem(newmenu, _T("Menu and color settings"), ITEMTYPE_MENU);
					EisMenuAddAttribute(item, _T("FILE"), _T("setup.system.base.cui.menu"));
				}

				data->LastMenu = newmenu;
				data->LastMenu->Menu = EisMenuBuildGUI(data->LastMenu, parent, win);
				MenuSetMenuClickedHook(data->LastMenu->Menu, MainMenuClickedHook, win);
				MenuSetPreKeyHook(data->LastMenu->Menu, MainMenuPreKeyHook, win);
				WindowCreate     (data->LastMenu->Menu);
				MenuSelectItem   (data->LastMenu->Menu, data->LastMenu->LastChoice);
				MainUpdateTitle  (win, data->LastMenu);
			}
			else
			{
				MainCloseMenu(win, newmenu);
			}
			WindowSetFocus(data->LastMenu->Menu);
                }
        }
}

/* ---------------------------------------------------------------------
 * MainExecuteDocument
 * The item selected by the user is a reference to a documentation file
 * (<doc>-Tag). This function opens the system viewer and passes
 * the document to this application.
 * ---------------------------------------------------------------------
 */
static void
MainExecuteDocument(CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data)
{
	EISMENUATTR* package     = EisMenuGetAttr(item,  _T("PACKAGE"));
	EISMENUATTR* file        = EisMenuGetAttr(item,  _T("FILE"));
	EISMENUATTR* title       = EisMenuGetAttr(item,  _T("TITLE"));
	EISMENUATTR* tailattr    = EisMenuGetAttr(item,  _T("TAIL"));
	EISMENUATTR* encoding    = EisMenuGetAttr(item,  _T("ENCODING"));
	EISMENUATTR* preprocess  = EisMenuGetAttr(item,  _T("PRE"));
	EISMENUATTR* postprocess = EisMenuGetAttr(item,  _T("POST"));

	wchar_t* packname = NULL;
	wchar_t  document[128 + 1];
	wchar_t  shellcmd[256 + 1];
	wchar_t  tailcmd [8 + 1];

	/* get package name */
	packname = data->LastMenu->Package;
	if (package)
	{
		packname = package->Value;
	}

	/* check if tail attribute is set */
	tailcmd[0] = _T('\0');
	if (tailattr && (wcscasecmp(tailattr->Value, _T("yes")) == 0))
	{
		wcscpy(tailcmd, _T("-f"));
	}

	/* get absolute file path */
	if (!file)
	{
		wchar_t tmpdocname[64 + 1];

		swprintf(tmpdocname, 64, _T("%ls.txt"), packname);
		tmpdocname[64] = 0;
		GetAbsolutePath(ITEMTYPE_DOC, tmpdocname, packname, document, 128);
	}
	else
	{
		GetAbsolutePath(ITEMTYPE_DOC, file->Value, packname, document, 128);
	}
	if (!preprocess  ||
	   RunPrePostScript(
			win, 
			preprocess->Value, 
			_T("pre"), 
			packname, 
			_T("doc"), 
			document, 
			NULL,
			item->Name) )
	{
		int pos;
		
		wcscpy(shellcmd, _T("/var/install/bin/show-doc.cui "));
		
		pos = wcslen(shellcmd);
		
		/* append encoding option */
		if (encoding && (wcslen(encoding->Value) > 0))
		{
			swprintf(&shellcmd[pos], 256 - pos, 
				_T("-e \"%ls\" "), 
				encoding->Value);
			shellcmd[256] = L'\0';
			pos = wcslen(shellcmd);
		}
		
		/* append title option */
		if (title && (wcslen(title->Value) > 0))
		{
			swprintf(&shellcmd[pos], 256 - pos, 
				_T("-t \"%ls\" "), 
				title->Value);
			shellcmd[256] = L'\0';
			pos = wcslen(shellcmd);
		}
		
		/* append document and tail switch */
		swprintf(&shellcmd[pos], 256 - pos, 
			_T("%ls \"%ls\""), 
			tailcmd,
			document);
		shellcmd[256] = L'\0';
					
		WindowLeaveCurses();
		{
			ExecSysCmd(shellcmd);
		}
		WindowResumeCurses();

		UpdateMenuStack(win); 
		MainUpdateTitle(win, data->LastMenu);

		if (postprocess)
		{
			RunPrePostScript(
				win,
				postprocess->Value, 
				_T("post"),
				packname, 
				_T("doc"), 
				document, 
				NULL,
				item->Name);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainExecuteConfig
 * The item selected by the user is the configuration of a package
 * (<edit>-Tag). This function calls the script /var/install/edit
 * ---------------------------------------------------------------------
 */
static void
MainExecuteConfig(CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data)
{
	EISMENUATTR* package = EisMenuGetAttr(item, _T("PACKAGE"));
	EISMENUATTR* stopstart = EisMenuGetAttr(item, _T("STOPSTART"));
	EISMENUATTR* preprocess = EisMenuGetAttr(item, _T("PRE"));
	EISMENUATTR* postprocess = EisMenuGetAttr(item, _T("POST"));
	const wchar_t* strrestart = NULL;
	wchar_t* packname = NULL;
	wchar_t  config[128 + 1];
	wchar_t  shellcmd[256 + 1];

	packname = data->LastMenu->Package;
	if (package)
	{
		packname = package->Value;
	}

	if (stopstart)
	{
		strrestart = _T("apply-stopstart");
	}
	else
	{
		strrestart = _T("apply");
	}

	/* get absolute file path */
	GetAbsolutePath(ITEMTYPE_EDIT, _T(""), packname, config, 128);

	if (!preprocess ||
	   RunPrePostScript(
			win, 
			preprocess->Value, 
			_T("pre"), 
			packname, 
			_T("edit"), 
			config, 
			strrestart,
			item->Name))
	{
		if (stopstart)
		{
			swprintf(shellcmd, 256, _T("/var/install/bin/edit -apply-stopstart %ls"), config);
		}
		else
		{
			swprintf(shellcmd, 256, _T("/var/install/bin/edit -apply %ls"), config);
		}

		WindowLeaveCurses();
		{
			ExecSysCmd(shellcmd);
		}
		WindowResumeCurses();

		UpdateMenuStack(win); 
		MainUpdateTitle(win, data->LastMenu);

		if (postprocess)
		{
			RunPrePostScript(
				win,
				postprocess->Value,
				_T("post"),
				packname,
				_T("edit"),
				config,
				strrestart,
				item->Name);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainExecuteService
 * The item selected by the user is a service control function
 * (<init>-Tag). This function calls the script /etc/init.d/$package
 * and passes the given parameter from attribute "task"
 * ---------------------------------------------------------------------
 */
static void
MainExecuteService(CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data)
{
	EISMENUATTR* package = EisMenuGetAttr(item, _T("PACKAGE"));
	EISMENUATTR* task = EisMenuGetAttr(item, _T("TASK"));
	EISMENUATTR* preprocess = EisMenuGetAttr(item, _T("PRE"));
	EISMENUATTR* postprocess = EisMenuGetAttr(item, _T("POST"));
	wchar_t* plist = NULL;              /* pointer to list of package names */
	wchar_t  slist  [256 + 1];
	wchar_t  cmd    [512 + 1];
	wchar_t  service[128 + 1];          /* name of service to execute */
	wchar_t  pname  [64 + 1];           /* one single package name */

	if (task)
	{
		const wchar_t* pchar;

                /* retreive package list */
		plist = data->LastMenu->Package;
		if (package)
		{
			plist = package->Value;
		}

		/* process list of packages */
		pchar = plist;
		slist[0] = _T('\0');
		while (GetSinglePackage(&pchar, pname, 64))
		{
			/* add space character */
			if ((slist[0] != _T('\0')) && (wcslen(slist) + 1 < 255))
			{
				wcscat(slist, _T(" "));
			}

			/* get absolute file path */
			GetAbsolutePath(ITEMTYPE_INIT, _T(""), pname, service, 128);

			/* add to list of init scripts */
			if ((wcslen(slist) + wcslen(service)) < 255)
			{
				wcscat(slist, service);
			}
		}

		/* execute pre-script */
		if (!preprocess  ||
		   RunPrePostScript(win,
			preprocess->Value, 
			_T("pre"), 
			plist, 
			_T("init"), 
			slist, 
			task->Value,
			item->Name) )
		{
			pchar = plist;
			cmd[0] = _T('\0');
			while (GetSinglePackage(&pchar, pname, 64))
			{
				/* add space character */
				if ((cmd[0] != _T('\0')) && (wcslen(cmd) + 1 < 512))
				{
					wcscat(cmd, _T(";"));
				}

				/* get absolute file path */
				GetAbsolutePath(ITEMTYPE_INIT, _T(""), pname, service, 128);

				/* build command line */
				if ((wcslen(cmd) + wcslen(service) + wcslen(task->Value) + 1) < 512)
				{
					wcscat(cmd, service);
					wcscat(cmd, _T(" "));
					wcscat(cmd, task->Value);
				}
			}

			/* execute command line */
			MainwinShellExecute(win, cmd, item->Name);

			UpdateMenuStack(win);
			MainUpdateTitle(win, data->LastMenu);

			/* execute post-script */
			if (postprocess)
			{
				RunPrePostScript(win,
					postprocess->Value,
					_T("post"), 
					plist,
					_T("init"),
					slist,
					task->Value,
					item->Name);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * MainExecuteScript
 * The item selected by the user is a shell script reference
 * (<script>-Tag). This function calls the given script from the
 * "file" attribute.
 * ---------------------------------------------------------------------
 */
static void
MainExecuteScript(CUIWINDOW* win, EISMENUITEM* item, MAINWINDATA* data)
{
	EISMENUATTR* package = EisMenuGetAttr(item, _T("PACKAGE"));
	EISMENUATTR* file = EisMenuGetAttr(item, _T("FILE"));
	EISMENUATTR* preprocess = EisMenuGetAttr(item, _T("PRE"));
	EISMENUATTR* postprocess = EisMenuGetAttr(item, _T("POST"));
	static char  package_name[128 + 1];
	wchar_t*     packname = NULL;

	if (file)
	{
		wchar_t shellcmd[256 + 1];
		int   rc;

		packname = data->LastMenu->Package;
		if (package)
		{
			packname = package->Value;
		}

		if (packname)
		{
			wcstombs(package_name, packname, 128);
			package_name[128] = 0;
			if (setenv("PACKAGE", package_name, TRUE) != 0)
			{
				return;
			}
		}

		/* get absolute file path */
		GetAbsolutePath(ITEMTYPE_SCRIPT, file->Value, _T(""), shellcmd, 256);

		if (!preprocess ||
		   RunPrePostScript(
			win, 
			preprocess->Value, 
			_T("pre"), 
			packname, 
			_T("script"), 
			shellcmd, 
			NULL,
			item->Name))
		{
			WindowLeaveCurses();
			{
				rc = ExecSysCmd(shellcmd);
			}
			if (WIFEXITED(rc))
			{
				rc = WEXITSTATUS(rc);
				switch(rc)
				{
				case 127:
					WindowResumeCurses();
					if (postprocess)
					{
						RunPrePostScript(
							win,
							postprocess->Value,
							_T("post"),
							packname,
							_T("script"),
							shellcmd,
							NULL,
							item->Name);
					}
					WindowQuit(127);
					break;
				case 0:
					WindowResumeCurses();
					break;
				default:
					system("/var/install/bin/anykey");
					WindowResumeCurses();
					break;
				}
			}
			else
			{
				WindowResumeCurses();
			}

			UpdateMenuStack(win);
			MainUpdateTitle(win, data->LastMenu);

			if (postprocess)
			{
				RunPrePostScript(
					win,
					postprocess->Value,
					_T("post"),
					packname,
					_T("script"),
					shellcmd,
					NULL,
					item->Name);
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * Sort the menu
 * ---------------------------------------------------------------------
 */
/* ---------------------------------------------------------------------
 * MainOpenDragMode
 * Check if the cursor is placed over an item that is marked as
 * moveable. If so, activate drag mode to move the item up or down
 * ---------------------------------------------------------------------
 */
static void 
MainOpenDragMode(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	MENUITEM* item = MenuGetSelectedItem(data->LastMenu->Menu);
	if (item && item->IsMoveable)
	{
		data->LastMenu->LastChoice = item->ItemId;
		MenuSetDragMode(data->LastMenu->Menu, TRUE);
		data->DragMode = TRUE;
		WindowSetLStatusText(win, DRAG_STATUS_TEXT);
	}
}

/* ---------------------------------------------------------------------
 * MainEscDragMode
 * Abort an active drag mode without saving the data. The original menu
 * is restored.
 * ---------------------------------------------------------------------
 */
static void 
MainEscDragMode(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	data->LastMenu->Menu = EisMenuBuildGUI(data->LastMenu, NULL, win);

	MenuSetDragMode(data->LastMenu->Menu, FALSE);
	data->DragMode = FALSE;
	WindowSetLStatusText(win, IDLE_STATUS_TEXT);
}

/* ---------------------------------------------------------------------
 * MainCloseDragMode
 * Close an active drag mode. The modified menu is transferred to the
 * corresponding "EISMENU" structure and saved to disk.
 * ---------------------------------------------------------------------
 */
static void 
MainCloseDragMode(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	EISMENUITEM* pos;
	MENUITEM* item;

	item = MenuGetSelectedItem(data->LastMenu->Menu);
	if (item)
	{
		data->LastMenu->LastChoice = item->ItemId;
	}

	/* save the resorted menu */
	item = MenuGetItems(data->LastMenu->Menu);
	if (item)
	{
		pos = EisMenuMakeFirstItem(data->LastMenu, item->ItemText);
		item = (MENUITEM*) item->Next;
		while (item && !item->IsSeparator)
		{
			if (pos)
			{
				pos = EisMenuMakeNextItem(pos, item->ItemText);
			}
			item = (MENUITEM*) item->Next;
		}

		/* save file and display errors */
		MainwinFreeMessage(win);
		data->NumErrors = 0;
		data->NumWarnings = 0;

		EisMenuWriteFile(data->LastMenu, MainwinErrorOut, win);
		if (data->NumErrors || data->NumWarnings)
		{
			wchar_t buffer[128 + 1];

			MainwinAddMessage(win, _T(""));

			swprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
				data->NumErrors, data->NumWarnings);
			MainwinAddMessage(win, buffer);

			swprintf(buffer, 128, _T("file: %ls"), data->Config->MenuFile);

			MainwinAddMessage(win, buffer);

			MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
		}
		MainwinFreeMessage(win);
	}

	/* end drag mode */
	MenuSetDragMode(data->LastMenu->Menu, FALSE);
	data->DragMode = FALSE;
	WindowSetLStatusText(win, IDLE_STATUS_TEXT);
}
