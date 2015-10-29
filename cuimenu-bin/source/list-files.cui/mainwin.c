/* ---------------------------------------------------------------------
 * File: mainwin.c
 * (application main window)
 *
 * Copyright (C) 2007
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
 *
 * Last Update:  $Id: mainwin.c 33470 2013-04-14 17:38:17Z dv $
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
#include "filetools.h"

#define IDC_LISTVIEW 10
#define IDC_HELPVIEW 11

/* prototypes */
static void MainwinReadUsersAndGroups(CUIWINDOW* win, MAINWINDATA* data);
static void MainwinReadData(CUIWINDOW* win, MAINWINDATA* data);
static void MainwinError(void* w, const wchar_t* errmsg, const wchar_t* filename,
                         int linenr, int is_warning);
static void MainwinReadHelp(CUIWINDOW* win);
static void MainwinUpdateHelp(CUIWINDOW* win, MAINWINDATA* data);
static void MainwinToggleHelp(CUIWINDOW* win);

static struct stat* GetEntryStat(PROGRAM_CONFIG* config, const char *s, struct stat* status);
static const wchar_t* GetFTime(struct stat* st, wchar_t* buf, int buflen);
static const wchar_t* GetFSize(struct stat* st, wchar_t* buf, int buflen);
static const wchar_t* GetFMode(struct stat* st, wchar_t* buf, int buflen);
static const wchar_t* GetFUser(struct stat* st, wchar_t* buf, int buflen, MAINWINDATA* data);
static const wchar_t* GetFromId(wchar_t** cidlist, const int* nidlist, int maxid, int id);
static int          CheckFileExtension(PROGRAM_CONFIG* config, const char *s);
static int          CheckEntryType(PROGRAM_CONFIG* config, const char *s );

/* ---------------------------------------------------------------------
 * LISTVIEW NOTIFY CALLBACKS
 * ---------------------------------------------------------------------
 */
/* ---------------------------------------------------------------------
 * MainListClickedHook
 * an item in the listview has been selected with SPACE or with the mouse
 * ---------------------------------------------------------------------
 */
static void
MainListClickedHook(void* w, void* c)
{
	CUIWINDOW*   ctrl = (CUIWINDOW*) c;
	CUIWINDOW*   win  = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	const wchar_t* pselect;

	pselect = ListviewGetColumnText(
		ListviewGetRecord(ctrl, ListviewGetSel(ctrl)), 0);

	if (data->Config && pselect && (wcslen(pselect) > 0))
	{
		if (data->Config->Question)
		{
			int    len = wcslen(data->Config->Question) + wcslen(pselect) + 64;
			wchar_t* msg = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
			if (msg)
			{
				swprintf(msg, len, data->Config->Question, pselect);
				if (MessageBox(win, msg, _T("Question"), MB_YESNO) != IDYES)
				{
					pselect = NULL;
				}
				free(msg);
			}
		}

		if (pselect)
		{
			if (data->Config->ScriptFile)
			{
				int len = wcslen(data->Config->ScriptFile) + wcslen(pselect) + 4;
				data->Config->ShellCommand = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
				swprintf(data->Config->ShellCommand,
					len,
					_T("%ls %ls"),
					data->Config->ScriptFile,
					pselect);
			}
			WindowQuit(EXIT_SUCCESS);
		}
	}
}

/* ---------------------------------------------------------------------
 * MainListPreKeyHook
 * capture ENTER-key that is normally ignored by the listview control
 * ---------------------------------------------------------------------
 */
static int
MainListPreKeyHook(void* w,void* c, int key)
{
	if ((key == KEY_RETURN) || (key == KEY_F0+2))
	{
		MainListClickedHook(w, c);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * MAIN WINDOW IMPLEMENTATION
 * ---------------------------------------------------------------------
 */
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
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;
	wchar_t        version[32 + 1];
	int          n;

	swprintf(version, 32, _T("V%i.%i.%i"), VERSION, SUBVERSION, PATCHLEVEL);
	WindowSetRStatusText(win, version);
	WindowSetLStatusText(win, _T("'F1'=Help 'ENTER'=Select 'F10'=Exit"));

	WindowGetClientRect(win, &rc);

	if (data->Config)
	{
			n = 1;
			if (data->Config->ColumnDate)
			{
				n++;
			}
			if (data->Config->ColumnSize)
			{
				n++;
			}
			if (data->Config->ColumnMode)
			{
				n++;
			}
			if (data->Config->ColumnUser)
			{
				n++;
			}
			data->NumColumns = n;
	}

	ctrl = ListviewNew(win, _T(""), rc.X, rc.Y, rc.W, rc.H, n, IDC_LISTVIEW, CWS_NONE, CWS_NONE);
	ListviewSetLbClickedHook(ctrl, MainListClickedHook, win);
	ListviewSetPreKeyHook(ctrl, MainListPreKeyHook, win);
	WindowColScheme(ctrl, _T("WINDOW"));
	WindowCreate(ctrl);

	if (data->Config)
	{
		n = 0;
		ListviewAddColumn(ctrl, n, data->Config->Column ? data->Config->Column : _T("Filenames:"));
		if (data->Config->ColumnDate)
		{
			n++;
			ListviewAddColumn(ctrl, n, _T("Date:       Time:   "));
		}
		if (data->Config->ColumnSize)
		{
			n++;
			ListviewAddColumn(ctrl, n, _T("Size:"));
		}
		if (data->Config->ColumnMode)
		{
			n++;
			ListviewAddColumn(ctrl, n, _T("Mode:    "));
		}
		if (data->Config->ColumnUser)
		{
			n++;
			ListviewAddColumn(ctrl, n, _T(" User:    Group:   "));
			MainwinReadUsersAndGroups(win, data);
		}
	}

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
	CUIWINDOW*   win = (CUIWINDOW*) w;
	MAINWINDATA* data =  (MAINWINDATA*) win->InstData;

	MainwinReadData(win, data);
	MainwinReadHelp(win);
	MainwinUpdateHelp(win, data);
}

/* ---------------------------------------------------------------------
 * MainDestroyHook
 * Handle EVENT_DELETE events by deleting the window
 * ---------------------------------------------------------------------
 */
static void
MainDestroyHook(void* w)
{
	int index;
	CUIWINDOW* win = (CUIWINDOW*) w;
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	/* free user id data */
	if (data->NumUid > 0)
	{
		for (index = 0; index < data->NumUid; index++)
		{
			free(data->CUidList[index]);
		}
		free(data->CUidList);
		free(data->NUidList);
	}

	/* free group id data */
	if (data->NumGid > 0)
	{
		for (index = 0; index < data->NumGid; index++)
		{
			free(data->CGidList[index]);
		}
		free(data->CGidList);
		free(data->NGidList);
	}

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
	CUIWINDOW*   listview;
	CUIWINDOW*   helpview;

	WindowGetClientRect(win, &rc);

	listview = WindowGetCtrl(win, IDC_LISTVIEW);
	helpview = WindowGetCtrl(win, IDC_HELPVIEW);

	if (listview && helpview && ((rc.H / 2) > 0))
	{
		if (data->Config && data->Config->ShowHelp)
		{
			int height = rc.H - rc.H / 4;

			if ((rc.H - height) < 6)
			{
				if (rc.H > 6) height = rc.H - 6;
			}
			if ((height > 0) && (height % 2 != 1)) height++;

			WindowMove(listview, 0, 0, rc.W, height);
			WindowMove(helpview, 0, height, rc.W, rc.H - height);
			WindowHide(helpview, FALSE);
		}
		else
		{
			WindowMove(listview, 0, 0, rc.W, rc.H);
			WindowHide(helpview, TRUE);
		}
	}
	return TRUE;
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
		switch(key)
		{
		case KEY_F0+1:
			MainwinToggleHelp(win);
			return TRUE;
		case KEY_F0+10:
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
MainwinNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h,
           int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* mainwin;
		int flags = sflags | CWS_POPUP | CWS_CAPTION | CWS_STATUSBAR;
		flags &= ~(cflags);

		mainwin = WindowNew(parent, x, y, w, h, flags);
		mainwin->Class = _T("LIST-FILES.CUI");
		WindowColScheme(mainwin, _T("DESKTOP"));
		WindowSetText(mainwin, text);
		WindowSetCreateHook(mainwin, MainCreateHook);
		WindowSetDestroyHook(mainwin, MainDestroyHook);
		WindowSetInitHook(mainwin, MainInitHook);
		WindowSetKeyHook(mainwin, MainKeyHook);
		WindowSetSizeHook(mainwin, MainSizeHook);

		mainwin->InstData = (MAINWINDATA*) malloc(sizeof(MAINWINDATA));
		((MAINWINDATA*)mainwin->InstData)->HelpData   = NULL;
		((MAINWINDATA*)mainwin->InstData)->ErrorMsg   = NULL;
		((MAINWINDATA*)mainwin->InstData)->Config     = NULL;
		((MAINWINDATA*)mainwin->InstData)->CUidList   = NULL;
		((MAINWINDATA*)mainwin->InstData)->NUidList   = FALSE;
		((MAINWINDATA*)mainwin->InstData)->NumUid     = 0;
		((MAINWINDATA*)mainwin->InstData)->CGidList   = FALSE;
		((MAINWINDATA*)mainwin->InstData)->NGidList   = NULL;
		((MAINWINDATA*)mainwin->InstData)->NumGid     = 0;
		((MAINWINDATA*)mainwin->InstData)->NumColumns = 0;

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
	if (win && (wcscmp(win->Class, _T("LIST-FILES.CUI")) == 0))
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
	if (win && (wcscmp(win->Class, _T("LIST-FILES.CUI")) == 0))
	{
		MAINWINDATA* data = (MAINWINDATA*) win->InstData;
		data->Config     = cfg;
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
	if (win && (wcscmp(win->Class, _T("LIST-FILES.CUI")) == 0))
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
	if (win && (wcscmp(win->Class, _T("LIST-FILES.CUI")) == 0))
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
 * MainwinReadHelp
 * Read the XML help file for this program
 * ---------------------------------------------------------------------
 */
static void
MainwinReadHelp(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	MainwinFreeMessage(win);

	if (data->Config && data->Config->HelpFile)
	{
		data->HelpData = XmlCreate(data->Config->HelpFile);
		XmlSetErrorHook(data->HelpData, MainwinError, win);
		XmlAddSingleTag(data->HelpData, _T("BR"));

		data->NumErrors = 0;
		data->NumWarnings = 0;

		XmlReadFile(data->HelpData);

		if (data->NumErrors || data->NumWarnings)
		{
			wchar_t buffer[128 + 1];

			MainwinAddMessage(win, _T(""));

			swprintf(buffer, 128, _T("%i error(s), %i warning(s)"),
				data->NumErrors, data->NumWarnings);
			MainwinAddMessage(win, buffer);

			swprintf(buffer, 128, _T("file: %ls"), data->Config->HelpFile);

			MainwinAddMessage(win, buffer);

			MessageBox(win, data->ErrorMsg, _T("Error"), MB_ERROR);
		}
	}
	MainwinFreeMessage(win);
}

/* ---------------------------------------------------------------------
 * MainwinUpdateHelp
 * Copy help item to text view window
 * ---------------------------------------------------------------------
 */
static void
MainwinUpdateHelp(CUIWINDOW* win, MAINWINDATA* data)
{
	CUIWINDOW* helpview = WindowGetCtrl(win, IDC_HELPVIEW);

	TextviewClear(helpview);
	if (data->Config && data->Config->ShowHelp)
	{
		XMLOBJECT* obj = NULL;

		TextviewEnableWordWrap(helpview, TRUE);

		if (data->Config && data->Config->HelpName)
		{
			obj = MainwinFindHelpEntry(win, data->Config->HelpName);
		}
		else
		{
			obj = MainwinFindHelpEntry(win, _T("FILEDIALOG"));
		}
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
					if (!linebreak) TextviewAdd(helpview, _T(""));
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
}

/* ---------------------------------------------------------------------
 * MainwinToggleHelp
 * Switch Help on or off
 * ---------------------------------------------------------------------
 */
static void
MainwinToggleHelp(CUIWINDOW* win)
{
	MAINWINDATA* data = (MAINWINDATA*) win->InstData;

	if (data->Config)
	{
		data->Config->ShowHelp = data->Config->ShowHelp ? FALSE : TRUE;
		if (data->Config->ShowHelp)
		{
			MainwinUpdateHelp(win, data);
		}
		MainSizeHook(win);
	}
}

/* ---------------------------------------------------------------------
 *  MainwinReadUsersAndGroups
 *  create memory copy of all users and group names
 *  ---------------------------------------------------------------------
 */
static void
MainwinReadUsersAndGroups(CUIWINDOW* win, MAINWINDATA* data)
{
	struct passwd *pwd;
	struct group  *grp;
	int           index;

	CUI_USE_ARG(win);

	/* process user list from /etc/passwd: */
	/* count user entries */
	data->NumUid = 0;
	setpwent();
	while ((pwd = getpwent()) != NULL )
	{
		data->NumUid++;
	}

	/* allocate memory */
	data->NumUid++;
	data->CUidList    = (wchar_t**) malloc(data->NumUid * sizeof(wchar_t*));
	data->NUidList    = (int*)    malloc(data->NumUid * sizeof(int));
	data->CUidList[0] = wcsdup(_T("?"));
	data->NUidList[0] = 0;

	/* read user entries */
	index = 1;
	setpwent();
	while ((pwd = getpwent()) != NULL )
	{
		data->NUidList[index] = pwd->pw_uid;
		data->CUidList[index] = MbToTCharDup(pwd->pw_name);
		index++;
	}
	endpwent();

	/* process group list from /etc/group: */
	/* count group entries */
	data->NumGid = 0;
	setgrent();
	while (( grp = getgrent()) != NULL )
	{
		data->NumGid++;
	}

	/* allocate memory */
	data->NumGid++;
	data->CGidList    = (wchar_t**) malloc(data->NumGid * sizeof(wchar_t*));
	data->NGidList    = (int*)    malloc(data->NumGid * sizeof(int));
	data->CGidList[0] = wcsdup(_T("?"));
	data->NGidList[0] = 0;

	/* read group entries */
	index = 1;
	setgrent();
	while ((grp = getgrent()) != NULL )
	{
		data->NGidList[index] = grp->gr_gid;
		data->CGidList[index] = MbToTCharDup(grp->gr_name);
		index++;
	}
	endgrent();
}

/* ---------------------------------------------------------------------
 *  MainwinReadData
 *  Read directory data and insert into the list view
 *  ---------------------------------------------------------------------
 */
static void
MainwinReadData(CUIWINDOW* win, MAINWINDATA* data)
{
	CUIWINDOW* listview;
	DIR *      dirp;
	struct     dirent * dp;

	listview = WindowGetCtrl(win, IDC_LISTVIEW);
	if (!listview)
	{
		return;
	}

	if ((dirp = opendir(data->Config->Path)))
	{
		while ((dp = readdir(dirp)) != (struct dirent *) NULL)
		{
			if ((dp->d_name[0] != '.') && (CheckFileExtension(data->Config, (char *)dp->d_name) != -1))
			{
				if ((data->Config->FileTypeN == 0) ||
				    (data->Config->FileTypeN == CheckEntryType(data->Config, (char *)dp->d_name)))
				{
					int      n = 0;
					wchar_t    buffer[256 + 1];
					LISTREC* rec;

					rec = ListviewCreateRecord(listview);
					if (rec)
					{
						struct stat status;
						const char* p = dp->d_name;

						mbsrtowcs(buffer, &p, 256, NULL);
						buffer[256] = 0;
						
						ListviewSetColumnText(rec, 0, buffer);

						if (data->NumColumns > 1)
						{
							GetEntryStat(data->Config, dp->d_name, &status);
						}

						if (data->Config->ColumnDate)
						{
							n++;
							ListviewSetColumnText(rec, n, GetFTime(&status, buffer, 256));
						}
						if (data->Config->ColumnSize)
						{
							n++;
							ListviewSetColumnText(rec, n, GetFSize(&status, buffer, 256));
						}
						if (data->Config->ColumnMode)
						{
							n++;
							ListviewSetColumnText(rec, n, GetFMode(&status, buffer, 256));
						}
						if (data->Config->ColumnUser)
						{
							n++;
							ListviewSetColumnText(rec, n, GetFUser(&status, buffer, 256, data));
						}
						ListviewInsertRecord(listview, rec);
					}
				}
			}
		}
		closedir (dirp);
	}
	ListviewAlphaSort(listview, 0, TRUE);
}



/* file helper functions */

/* ---------------------------------------------------------------------
*  FUNKTION: GetEntryStat(  )
*  return the status structure of entry
*  required: char *pftool_search_dir;
*  ---------------------------------------------------------------------
*/
static struct stat*
GetEntryStat(PROGRAM_CONFIG* config, const char *s, struct stat* status)
{
	char*   stmp;
	char*   search_dir = config->Path ? config->Path : "/tmp";
	int     len = strlen(search_dir) + strlen(s) + 3;

	stmp = (char*) malloc((len + 1) * sizeof(char));
	if (stmp)
	{
		strcpy(stmp, search_dir);
		strcat(stmp, "/");
		strcat(stmp, s);

		stat(stmp, status);

		free(stmp);
	}
	return (status);
}

/* ---------------------------------------------------------------------
 *  FUNKTION: GetmTime(  )
 *  return the time from stat structure of entry
 *  ---------------------------------------------------------------------
 */
static const wchar_t*
GetFTime(struct stat* st, wchar_t* buf, int buflen)
{
	struct tm *tm = gmtime(&st->st_mtime);

	swprintf(buf, buflen, _T(" %04i-%02i-%02i  %02i:%02i:%02i "),
		tm->tm_year + 1900,
		tm->tm_mon + 1,
		tm->tm_mday,
		tm->tm_hour,
		tm->tm_min,
		tm->tm_sec);

	buf[buflen] = 0;
	return buf;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: GetFSize(  )
 *  return the size from stat structure of entry
 *  ---------------------------------------------------------------------
 */
static const wchar_t*
GetFSize(struct stat* st, wchar_t* buf, int buflen)
{
	swprintf(buf, buflen, _T(" %7ld "), st->st_size ) ;
	buf[buflen] = 0;
	return buf;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: GetFMode(  )
 *  return the mode from stat structure of entry
 *  ---------------------------------------------------------------------
 */
static const wchar_t*
GetFMode(struct stat* st, wchar_t* buf, int buflen)
{
	int   stm;

	if (buflen < 13)
	{
		buf[0] = 0;
		return buf;
	}

	wcscpy(buf, _T("            \0"));

	stm = st->st_mode;
	switch (stm & S_IFMT)
	{
	/* type */
	case S_IFREG:
		buf[1]=_T('-');
		break;
	case S_IFDIR:
		buf[1]=_T('d');
		break;
	case S_IFLNK:
		buf[1]=_T('l');
		break;
	case S_IFCHR:
		buf[1]=_T('c');
		break;
	case S_IFBLK:
		buf[1]=_T('b');
		break;
	case S_IFIFO:
		buf[1]=_T('p');
		break;
	case S_IFSOCK:
		buf[1]=_T('s');
		break;
	default:
		buf[1]=_T('?');
	}
	/* user */
	if (stm & S_IRUSR) buf[2]=_T('r');  else buf[2]=_T('-');
	if (stm & S_IWUSR) buf[3]=_T('w');  else buf[3]=_T('-');
	if (stm & S_IXUSR) buf[4]=_T('x');  else buf[4]=_T('-');
	if (stm & S_ISUID) buf[4]=_T('s');
	/* group */
	if (stm & S_IRGRP) buf[5]=_T('r');  else buf[5]=_T('-');
	if (stm & S_IWGRP) buf[6]=_T('w');  else buf[6]=_T('-');
	if (stm & S_IXGRP) buf[7]=_T('x');  else buf[7]=_T('-');
	if (stm & S_ISGID) buf[7]=_T('s');
	/* others */
	if (stm & S_IROTH) buf[8]=_T('r');  else buf[8]=_T('-');
	if (stm & S_IWOTH) buf[9]=_T('w');  else buf[9]=_T('-');
	if (stm & S_IXOTH) buf[10]=_T('x'); else buf[10]=_T('-');
	if (stm & S_ISVTX) buf[10]=_T('t');
	return buf;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: GetFUser(  )
 *  return user and group from stat structure of entry
 *  ---------------------------------------------------------------------
 */
static const wchar_t*
GetFUser(struct stat* st, wchar_t* buf, int buflen, MAINWINDATA* data)
{
	swprintf( buf, buflen, _T(" %-8ls %-8ls "),
		GetFromId(data->CUidList, data->NUidList, data->NumUid, st->st_uid),
		GetFromId(data->CGidList, data->NGidList, data->NumGid, st->st_gid) );
	return buf;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: CheckFileExtension(  )
 *  required: *pftool_list_filter[MAX_ARGS];
 *  ---------------------------------------------------------------------
 */
static int
CheckFileExtension(PROGRAM_CONFIG* config, const char *s)
{
	int n = -1;
	int i;

	if (!config->Filter)
	{
		return -1;
	}

	for( i = 0; i < MAX_ARGS && config->Filter[i] != NULL ; i++ )
	{
		if (ToolsPmatch(config->Filter[i], (char *)s ) > 0 )
		n = i ;
	}
	return n;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: CheckEntryType(  )
 *  get type for entry: file, link, dir, socket
 *  required: char *pftool_search_dir;
 *  ---------------------------------------------------------------------
 */
static int
CheckEntryType(PROGRAM_CONFIG* config, const char *s)
{
	struct stat Status;
	char*  search_dir = config->Path ? config->Path : "/tmp";
	char*  stmp;
	int    n = 0;

	safe_copy( &stmp, search_dir, strlen( search_dir ) + strlen( s ) + 1 );
	strcat( stmp, "/" );
	strcat( stmp, s );

	lstat( stmp, &Status);
	/* file type and permissions */
	switch (Status.st_mode & S_IFMT)
	{
	case S_IFREG:  // file
		n = 1;
		break;
	case S_IFDIR:  // dir
		n = 2;
		break;
	case S_IFLNK:  // link
		n = 3;
		break;
	case S_IFSOCK: // socket
		n = 4;
		break;
	default:
		n = 0;
	}
	free( stmp );
	return n;
}

/* ---------------------------------------------------------------------
 *  FUNKTION: GetFromId(  )
 *  convert id to name
 *  ---------------------------------------------------------------------
 */
static const wchar_t*
GetFromId(wchar_t** cidlist, const int* nidlist, int maxid, int id)
{
	int i;
	for (i = 1; i < maxid; i++)
	{
		if (nidlist[i] == id)
		{
			return cidlist[i];
		}
	}
	return cidlist[0];
}
                    
