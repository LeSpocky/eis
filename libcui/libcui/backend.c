/* ---------------------------------------------------------------------
 * File: backend.c
 * (interface to shell backend process)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: backend.c 33467 2013-04-14 16:23:14Z dv $
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
#include "api.h"
#include "api_ctrl.h"
#include "api_util.h"
#include "cui-script.h"

#define MAX_ARG            32
#define BUFFER_BLOCK_SIZE  512

typedef struct
{
	wchar_t* BufPtr;
	int    BufSize;
	void*  Previous;
	void*  Next;
} EXECBUFFER;

/* external prototypes */
void StubInit(void);
void StubClear(void);

/* local prototypes */
static const wchar_t* BackendGetParameter(wchar_t** pbuf);
static int          BackendMakePipePath(void);
static void         BackendPushBuffer(void);
static void         BackendPopBuffer(void);
static void         BackendGrowBuffer(EXECBUFFER* buf);

/* data */
static int          PipeR = 0;
static int          PipeW = 0;
static COPROC*      Shell = NULL;
static const wchar_t* Params[MAX_ARG];
static int          NumParams;
static char         PipePath[128 + 1];
static EXECBUFFER*  FirstBuffer = NULL;
static EXECBUFFER*  LastBuffer = NULL;
static ApiProc      ExternalApi = NULL;
static FILE*        DebugOut = NULL;

static wchar_t*       BackendFrame = NULL;
static int          BackendFPos = 0;
static int          BackendFSize = 0;

/* ---------------------------------------------------------------------
 * ScriptingInit
 * Initialize scripting module
 * ---------------------------------------------------------------------
 */
void
ScriptingInit(void)
{
	StubInit();
	AddonInit();

	FirstBuffer = (EXECBUFFER*) malloc(sizeof(EXECBUFFER));
	FirstBuffer->BufPtr   = (wchar_t*) malloc((BUFFER_BLOCK_SIZE + 1) * sizeof(wchar_t));
	FirstBuffer->BufSize  = BUFFER_BLOCK_SIZE;
	FirstBuffer->Previous = NULL;
	FirstBuffer->Next     = NULL;
	LastBuffer            = FirstBuffer;
}

/* ---------------------------------------------------------------------
 * ScriptingEnd  
 * Free associated data of this module   
 * ---------------------------------------------------------------------
 */
void
ScriptingEnd(void)
{
	EXECBUFFER* clrptr = FirstBuffer;
	while (clrptr)
	{
		FirstBuffer = (EXECBUFFER*) clrptr->Next;
		free(clrptr->BufPtr);
		free(clrptr);
		clrptr = FirstBuffer;
	}
	LastBuffer = NULL;
	AddonClear();
	StubClear();
}

/* ---------------------------------------------------------------------
 * BackendCreatePipes 
 * Create pipes for backend to frontend communication   
 * ---------------------------------------------------------------------
 */ 
int
BackendCreatePipes(void)
{
	char    pipe1[128 + 32 + 1];
	char    pipe2[128 + 32 + 1];
	int     r;

	if (BackendMakePipePath())
	{
		sprintf(pipe1, "/%s/cui%iwp", PipePath, getpid());
		sprintf(pipe2, "/%s/cui%irp", PipePath, getpid());

		r = mkfifo(pipe1, 0700);
		if ((r == -1) && (errno != EEXIST))
		{
			return FALSE;
		}

		r = mkfifo(pipe2, 0700);
		if ((r == -1) && (errno != EEXIST))
		{
			unlink(pipe1);
			return FALSE;
		}
		return TRUE;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * BackendRemovePipes 
 * Remove used pipes for backend to frontend communication   
 * ---------------------------------------------------------------------
 */ 
void
BackendRemovePipes(void)
{
	char    pipe1[128 + 32 + 1];
	char    pipe2[128 + 32 + 1];

	if (BackendMakePipePath())
	{
		sprintf(pipe1, "/%s/cui%iwp", PipePath, getpid());
		sprintf(pipe2, "/%s/cui%irp", PipePath, getpid());
		unlink(pipe1);
		unlink(pipe2);
	}
}

/* ---------------------------------------------------------------------
 * BackendOpen 
 * Launch Co-Process and establish communication   
 * ---------------------------------------------------------------------
 */ 
int
BackendOpen(const wchar_t* command, int debug)
{
	char    pipe1[128 + 32 + 1];
	char    pipe2[128 + 32 + 1];

	if (BackendMakePipePath())
	{
		int code;

		sprintf(pipe1, "/%s/cui%iwp", PipePath, getpid());
		sprintf(pipe2, "/%s/cui%irp", PipePath, getpid());

		Shell = CoProcCreate(command);
		if (!Shell)
		{
			return FALSE;
		}

		/* it is important now, that the co-process really
		   could be launched successfully! so we wait for a short
		   time and then check if it is still there.
		   This is an ugly hack... still looking for a better
		   idea! */
		usleep(10);
		if (!CoProcIsRunning(Shell, &code))
		{
			CoProcDelete(Shell);
			Shell = NULL;
			return FALSE;
		}

		PipeW = open(pipe2, O_WRONLY);
		PipeR = open(pipe1, O_RDONLY);
		if ((PipeR >= 0) && (PipeW >= 0))
		{
			if (debug)
			{
				DebugOut = fopen("/tmp/outcui.log", "at");
			}
			return TRUE;
		}
		BackendClose();
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * BackendClose 
 * Wait for the backend process to terminate and close pipes afterwards   
 * ---------------------------------------------------------------------
 */ 
int
BackendClose(void)
{
	int code = 0;
	if (Shell)
	{
		int i;
		for (i = 0; i < 50; i++)
		{
			while (CoProcIsRunning(Shell, &code))
			{
				usleep(10);
			}
		}
		if (i == 50)
		{
			kill(Shell->Pid, SIGTERM);
		}
		CoProcDelete(Shell);
		Shell = NULL;
	}
	if (PipeR >= 0)
	{
		close(PipeR);
	}
	if (PipeW >= 0)
	{
		close(PipeW);
	}
	if (DebugOut)
	{
		fclose(DebugOut);
		DebugOut = NULL;
	}
	return code;
}

/* ---------------------------------------------------------------------
 * BackendStartFrame 
 * Start a new protocal call frame. Types for call frames:
 * 'H' : Call of a backend hook procedure (must be implemented there)
 * 'R' : Result of an API call (carries the API-function's return value(s)) 
 * ---------------------------------------------------------------------
 */
void
BackendStartFrame(wchar_t ctype, int size)
{
	if (BackendFrame)
	{
		free(BackendFrame);
	}
	BackendFrame = (wchar_t*) malloc((size + 8) * sizeof(wchar_t));
	if (BackendFrame)
	{
		BackendFrame[0] = _T(':');
		BackendFrame[1] = ctype;
		BackendFrame[2] = 0;
		BackendFPos     = 2;
		BackendFSize    = size;
	}
}

/* ---------------------------------------------------------------------
 * BackendInsertStr 
 * Insert a character string into the call frame (escape special characters)
 * ---------------------------------------------------------------------
 */
void
BackendInsertStr(const wchar_t* str)
{
	if (BackendFrame)
	{
		wchar_t* p;
		int size;

		BackendFrame[BackendFPos++] = _T('\t');
		BackendFrame[BackendFPos++] = _T(':');

		p    = &BackendFrame[BackendFPos];
		size = BackendFSize - BackendFPos;

		while (*str && (size > 0))
		{
			switch (*str)
			{
			case _T('\n'): 
				*(p++) = _T('\\');
				*(p++) = _T('n');
				size -= 2;
				str++;
				break;
			case _T('\t'):
				*(p++) = _T('\\');
				*(p++) = _T('t');
				size -= 2;
				str++;
				break;
			case _T('\\'):
				*(p++) = _T('\\');
				*(p++) = _T('s');
				size -= 2;
				str++;
				break;
			default:
				*(p++) = *(str++);
				size--;
				break;
			}
		}
		*p = _T('\0');

		BackendFPos += wcslen(&BackendFrame[BackendFPos]);
	}
}

/* ---------------------------------------------------------------------
 * BackendInsertInt 
 * Insert an integer value into the call frame
 * ---------------------------------------------------------------------
 */ 
void
BackendInsertInt(int val)
{
	if (BackendFrame)
	{
		BackendFrame[BackendFPos++] = _T('\t');
		BackendFrame[BackendFPos++] = _T(':');

		swprintf(&BackendFrame[BackendFPos], 
			BackendFSize - BackendFPos,
			_T("%i"), 
			val);

		BackendFPos += wcslen(&BackendFrame[BackendFPos]);
		BackendFrame[BackendFPos] = 0;
	}
}

/* ---------------------------------------------------------------------
 * BackendInsertLong 
 * Insert a long value into the call frame
 * ---------------------------------------------------------------------
 */ 
void
BackendInsertLong(unsigned long val)
{
	if (BackendFrame)
	{
		BackendFrame[BackendFPos++] = _T('\t');
		BackendFrame[BackendFPos++] = _T(':');

		swprintf(&BackendFrame[BackendFPos], 
			BackendFSize - BackendFPos,
			_T("%lu"), 
			val);

		BackendFPos += wcslen(&BackendFrame[BackendFPos]);
		BackendFrame[BackendFPos] = 0;
	}
}


/* ---------------------------------------------------------------------
 * BackendSendFrame 
 * Transmit a complete call frame to the backend process. This is
 * called directly by API functions to return the result set, or by
 * the function BackendExecFrame to compelete a hook call.
 * ---------------------------------------------------------------------
 */ 
void
BackendSendFrame(void)
{
	if (BackendFrame)
	{
		char         mbbuf[128 + 1];
		mbstate_t    state;
		int          size = 0;
		const wchar_t* p = BackendFrame;
		
		memset (&state, 0, sizeof(state));

		wcscat(BackendFrame, _T("\n"));

		if (DebugOut)
		{
			fputs("-> ", DebugOut);
		}
                                                        
		do
		{
			size = wcsrtombs(mbbuf, &p, 128, &state);
			if (size > 0)
			{
				write(PipeW, mbbuf, size);
				if (DebugOut)
				{
					fwrite(mbbuf, 1, size, DebugOut);
				}
			}
		}
		while ((size > 0) && (p != NULL));
		
		if (DebugOut)
		{
			fflush(DebugOut);
		}
		free(BackendFrame);
		BackendFrame = NULL;
	}
}

/* ---------------------------------------------------------------------
 * BackendRun  
 * Command sequence to run a "normal" backend program. Applications
 * using the scripting module may overwrite this behavior.
 * ---------------------------------------------------------------------
 */ 
int
BackendRun(void)
{
	int ecode;

	/* Init script application */
	BackendStartFrame(_T('H'), 32);
	BackendInsertStr (_T("init"));
	BackendExecFrame ();

	/* run application */
	ecode = WindowRun();

	/* Exit script application */
	BackendStartFrame(_T('H'), 32);
	BackendInsertStr (_T("exit"));
	BackendExecFrame ();

	return ecode;
}

/* ---------------------------------------------------------------------
 * BackendExecFrame  
 * Execute a hook call frame and wait for the result. If the received
 * answer is an API-call, call the API function and then wait again for
 * the backend function to complete.
 * ---------------------------------------------------------------------
 */
int
BackendExecFrame(void)
{
	EXECBUFFER* execbuf;
	char   mbbuf[128 + 1];

	if (!LastBuffer)
	{
		return FALSE;
	}
	else
	{
		execbuf = LastBuffer;
		BackendPushBuffer();
	}

	BackendSendFrame();

	for (;;)
	{
		int c;

		if (DebugOut)
		{
			c = CoProcRead(Shell, execbuf->BufPtr, BUFFER_BLOCK_SIZE);
			while (c > 0)
			{
				char* mbdata;

				execbuf->BufPtr[c] = 0;
				mbdata = TCharToMbDup(execbuf->BufPtr);
				if (mbdata)
				{
					fputs(mbdata, DebugOut);
					free(mbdata);
				}
				c = CoProcRead(Shell, execbuf->BufPtr, 512);
			}
			fflush(DebugOut);
		}
		
		execbuf->BufPtr[0] = 0;
		
		{
			mbstate_t   state;
			wchar_t*      t = execbuf->BufPtr;
			int         s;
			const char* p;
			c = 0;
			
			memset (&state, 0, sizeof(state));
			
			/* trace backend communication into file */
			if (DebugOut)
			{
				fputs("<- ", DebugOut);
			}
			
			for(;;)
			{
				s = read(PipeR, mbbuf, 128);
				p = mbbuf;
				if (s > 0)
				{
					int num = s;
					do
					{
						int size = mbrtowc(t, p, num, &state);
						if (size > 0)
						{
							t++;
							num -= size;
							p   += size;
							c++;
						}
						else if (size == -2)
						{
							break; /* character incompelte */
						}
						else
						{
							*(t++) = L'?';
							num--;
							p++;
							c++;
						}
					}
					while (num > 0);
					
					/* trace backend communication into file */
					if (DebugOut)
					{
						fwrite(mbbuf, 1, s, DebugOut);
					}
				}
				
				/* resize target buffer if necessary */
				if (c >= execbuf->BufSize)
				{
					BackendGrowBuffer(execbuf);
					t = &execbuf->BufPtr[c];
				}
				
				/* really wait until complete data has been received */
				if ((c > 0) && (execbuf->BufPtr[c - 1] == _T('\n')))
				{
					break;
				}				
			}
			*t = _T('\0');

			/* flush debug file */			
			if (DebugOut)
			{
				fflush(DebugOut);
			}
		}
		if (c > 0)
		{
			const wchar_t* frm;
			wchar_t* rp = &execbuf->BufPtr[0];

			execbuf->BufPtr[c] = 0;
			frm = BackendGetParameter(&rp);

			if (frm && (frm[0] == _T('H')))
			{
				NumParams = 0;

				Params[NumParams] = BackendGetParameter(&rp);
				while (Params[NumParams])
				{
					NumParams++;
					Params[NumParams] = BackendGetParameter(&rp);
				}

				BackendPopBuffer();

				return TRUE;
			}
			else if (frm && (frm[0] == _T('C')))
			{
				int    func_nr;
				int    argc = 0;
				const  wchar_t* p[MAX_ARG];

				p[0] = BackendGetParameter(&rp);
				argc = 0;

				if (p[0] && (swscanf(p[0], _T("%d"), &func_nr) == 1))
				{
					int module = func_nr / 10000;

					p[argc] = BackendGetParameter(&rp);
					while (p[argc])
					{
						argc++;
						p[argc] = BackendGetParameter(&rp);
					}
					
					if (module == 0)
					{
						switch(func_nr)
						{
						case API_MESSAGEBOX:
							ApiMessageBox(argc, p); break;
						case API_WINDOWNEW:
							ApiWindowNew(argc, p); break;
						case API_WINDOWCREATE:
							ApiWindowCreate(argc, p); break;
						case API_WINDOWDESTROY:
							ApiWindowDestroy(argc, p); break;
						case API_WINDOWQUIT:
							ApiWindowQuit(argc, p); break;
						case API_WINDOWMODAL:
							ApiWindowModal(argc, p); break;
						case API_WINDOWCLOSE:
							ApiWindowClose(argc, p); break;
						case API_WINDOWSETHOOK:
							ApiWindowSetHook(argc, p); break;
						case API_WINDOWGETCTRL:
							ApiWindowGetCtrl(argc, p); break;
						case API_WINDOWGETDESKTOP:
							ApiWindowGetDesktop(argc, p); break;
						case API_WINDOWMOVE:
							ApiWindowMove(argc, p); break;
						case API_WINDOWGETWINDOWRECT:
							ApiWindowGetWindowRect(argc, p); break;
						case API_WINDOWGETCLIENTRECT:
							ApiWindowGetClientRect(argc, p); break;
						case API_WINDOWSETTIMER:
							ApiWindowSetTimer(argc, p); break;
						case API_WINDOWKILLTIMER:
							ApiWindowKillTimer(argc, p); break;
						case API_WINDOWADDCOLSCHEME:
							ApiWindowAddColScheme(argc, p); break;
						case API_WINDOWHASCOLSCHEME:
							ApiWindowHasColScheme(argc, p); break;
						case API_WINDOWCOLSCHEME:
							ApiWindowColScheme(argc, p); break;
						case API_WINDOWSETTEXT:
							ApiWindowSetText(argc, p); break;
						case API_WINDOWSETLTEXT:
							ApiWindowSetLText(argc, p); break;
						case API_WINDOWSETRTEXT:
							ApiWindowSetRText(argc, p); break;
						case API_WINDOWSETSTATUSTEXT:
							ApiWindowSetStatusText(argc, p); break;
						case API_WINDOWSETLSTATUSTEXT:
							ApiWindowSetLStatusText(argc, p); break;
						case API_WINDOWSETRSTATUSTEXT:
							ApiWindowSetRStatusText(argc, p); break;
						case API_WINDOWGETTEXT:
							ApiWindowGetText(argc, p); break;
						case API_WINDOWTOTOP:
							ApiWindowToTop(argc, p); break;
						case API_WINDOWMAXIMIZE:
							ApiWindowMaximize(argc, p); break;
						case API_WINDOWMINIMIZE:
							ApiWindowMinimize(argc, p); break;
						case API_WINDOWHIDE:
							ApiWindowHide(argc, p); break;
						case API_WINDOWENABLE:
							ApiWindowEnable(argc, p); break;
						case API_WINDOWSETFOCUS:
							ApiWindowSetFocus(argc, p); break;
						case API_WINDOWGETFOCUS:
							ApiWindowGetFocus(argc, p); break;
						case API_WINDOWINVALIDATE:
							ApiWindowInvalidate(argc, p); break;
						case API_WINDOWINVALIDATELAYOUT:
							ApiWindowInvalidateLayout(argc, p); break;
						case API_WINDOWUPDATE:
							ApiWindowUpdate(argc, p); break;
								
						case API_WINDOW_CURSES_LEAVE:
							ApiWindowCursesLeave(argc, p); break;
						case API_WINDOW_CURSES_RESUME:
							ApiWindowCursesResume(argc, p); break;
						case API_WINDOW_SHELL_EXECUTE:
							ApiWindowShellExecute(argc, p); break;

						case API_EDITNEW:
							ApiEditNew(argc, p); break;
						case API_EDITSETCALLBACK:
							ApiEditSetCallback(argc, p); break;
						case API_EDITSETTEXT:
							ApiEditSetText(argc, p); break;
						case API_EDITGETTEXT:
							ApiEditGetText(argc, p); break;

						case API_LABELNEW:
							ApiLabelNew(argc, p); break;
						case API_LABELSETCALLBACK:
							ApiEditSetCallback(argc, p); break;

						case API_BUTTONNEW:
							ApiButtonNew(argc, p); break;
						case API_BUTTONSETCALLBACK:
							ApiButtonSetCallback(argc, p); break;

						case API_GROUPBOXNEW:
							ApiGroupboxNew(argc, p); break;

						case API_RADIONEW:
							ApiRadioNew(argc, p); break;
						case API_RADIOSETCALLBACK:
							ApiRadioSetCallback(argc, p); break;
						case API_RADIOSETCHECK:
							ApiRadioSetCheck(argc, p); break;
						case API_RADIOGETCHECK:
							ApiRadioGetCheck(argc, p); break;

						case API_CHECKBOXNEW:
							ApiCheckboxNew(argc, p); break;
						case API_CHECKBOXSETCALLBACK:
							ApiCheckboxSetCallback(argc, p); break;
						case API_CHECKBOXSETCHECK:
							ApiCheckboxSetCheck(argc, p); break;
						case API_CHECKBOXGETCHECK:
							ApiCheckboxGetCheck(argc, p); break;

						case API_LISTBOXNEW:
							ApiListboxNew(argc, p); break;
						case API_LISTBOXSETCALLBACK:
							ApiListboxSetCallback(argc, p); break;
						case API_LISTBOXADD:
							ApiListboxAdd(argc, p); break;
						case API_LISTBOXDELETE:
							ApiListboxDelete(argc, p); break;
						case API_LISTBOXGET:
							ApiListboxGet(argc, p); break;
						case API_LISTBOXSETDATA:
							ApiListboxSetData(argc, p); break;
						case API_LISTBOXGETDATA:
							ApiListboxGetData(argc, p); break;
						case API_LISTBOXSETSEL:
							ApiListboxSetSel(argc, p); break;
						case API_LISTBOXGETSEL:
							ApiListboxGetSel(argc, p); break;
						case API_LISTBOXCLEAR:
							ApiListboxClear(argc, p); break;
						case API_LISTBOXGETCOUNT:
							ApiListboxGetCount(argc, p); break;
						case API_LISTBOXSELECT:
							ApiListboxSelect(argc, p); break;

						case API_COMBOBOXNEW:
							ApiComboboxNew(argc, p); break;
						case API_COMBOBOXSETCALLBACK:
							ApiComboboxSetCallback(argc, p); break;
						case API_COMBOBOXADD:
							ApiComboboxAdd(argc, p); break;
						case API_COMBOBOXDELETE:
							ApiComboboxDelete(argc, p); break;
						case API_COMBOBOXGET:
							ApiComboboxGet(argc, p); break;
						case API_COMBOBOXSETDATA:
							ApiComboboxSetData(argc, p); break;
						case API_COMBOBOXGETDATA:
							ApiComboboxGetData(argc, p); break;
						case API_COMBOBOXSETSEL:
							ApiComboboxSetSel(argc, p); break;
						case API_COMBOBOXGETSEL:
							ApiComboboxGetSel(argc, p); break;
						case API_COMBOBOXCLEAR:
							ApiComboboxClear(argc, p); break;
						case API_COMBOBOXGETCOUNT:
							ApiComboboxGetCount(argc, p); break;
						case API_COMBOBOXSELECT:
						        ApiComboboxSelect(argc, p); break;

						case API_PROGRESSBARNEW:
							ApiProgressbarNew(argc, p); break;
						case API_PROGRESSBARSETRANGE:
							ApiProgressbarSetRange(argc, p); break;
						case API_PROGRESSBARSETPOS:
							ApiProgressbarSetPos(argc, p); break;
						case API_PROGRESSBARGETRANGE:
							ApiProgressbarGetRange(argc, p); break;
						case API_PROGRESSBARGETPOS:
							ApiProgressbarGetPos(argc, p); break;

						case API_TEXTVIEWNEW:
							ApiTextviewNew(argc, p); break;
						case API_TEXTVIEWSETCALLBACK:
							ApiTextviewSetCallback(argc, p); break;
						case API_TEXTVIEWENABLEWORDWRAP:
							ApiTextviewEnableWordWrap(argc, p); break;
						case API_TEXTVIEWADD:
							ApiTextviewAdd(argc, p); break;
						case API_TEXTVIEWCLEAR:
							ApiTextviewClear(argc, p); break;
						case API_TEXTVIEWREAD:
							ApiTextviewRead(argc, p); break;
						case API_TEXTVIEWSEARCH:
							ApiTextviewSearch(argc, p); break;

						case API_LISTVIEWNEW:
							ApiListviewNew(argc, p); break;
						case API_LISTVIEWSETCALLBACK:
							ApiListviewSetCallback(argc, p); break;
						case API_LISTVIEWADDCOLUMN:
							ApiListviewAddColumn(argc, p); break;
						case API_LISTVIEWSETTITLEALIGNMENT:
							ApiListviewSetTitleAlignment(argc, p); break;
						case API_LISTVIEWCLEAR:
							ApiListviewClear(argc, p); break;
						case API_LISTVIEWADD:
							ApiListviewAdd(argc, p); break;
						case API_LISTVIEWSETTEXT:
							ApiListviewSetText(argc, p); break;
						case API_LISTVIEWGETTEXT:
							ApiListviewGetText(argc, p); break;
						case API_LISTVIEWGETDATA:
							ApiListviewGetData(argc, p); break;
						case API_LISTVIEWSETDATA:
							ApiListviewSetData(argc, p); break;
						case API_LISTVIEWSETSEL:
							ApiListviewSetSel(argc, p); break;
						case API_LISTVIEWGETSEL:
							ApiListviewGetSel(argc, p); break;
						case API_LISTVIEWGETCOUNT:
							ApiListviewGetCount(argc, p); break;
						case API_LISTVIEWUPDATE:
							ApiListviewUpdate(argc, p); break;
						case API_LISTVIEWALPHASORT:
							ApiListviewAlphaSort(argc, p); break;
						case API_LISTVIEWNUMERICSORT:
							ApiListviewNumericSort(argc, p); break;

						case API_TERMINALNEW:
							ApiTerminalNew(argc, p); break;
						case API_TERMINALSETCALLBACK:
							ApiTerminalSetCallback(argc, p); break;
						case API_TERMINALWRITE:
							ApiTerminalWrite(argc, p); break;
						case API_TERMINALRUN:
							ApiTerminalRun(argc, p); break;
						case API_TERMINALPIPEDATA:
							ApiTerminalPipeData(argc, p); break;

						case API_MENUNEW:
							ApiMenuNew(argc, p); break;
						case API_MENUSETCALLBACK:
							ApiMenuSetCallback(argc, p); break;
						case API_MENUADDITEM:
							ApiMenuAddItem(argc, p); break;
						case API_MENUADDSEPARATOR:
							ApiMenuAddSeparator(argc, p); break;
						case API_MENUSELECTITEM:
							ApiMenuSelectItem(argc, p); break;
						case API_MENUGETSELITEM:
							ApiMenuGetSelectedItem(argc, p); break;
						case API_MENUCLEAR:
							ApiMenuClear(argc, p); break;

						case API_XMLREADTAG:
							ApiXmlReadTag(argc, p); break;
						case API_LOADADDON:
							ApiLoadAddon(argc, p); break;

						default:
							if (!ExternalApi || !ExternalApi(func_nr, argc, p))
							{
								BackendWriteError(ERROR_UNKNWN);
							}
							break;
						}
					}
					else
					{
						ADDON_MODULE* addon = AddonGetModule(module);
						if (!addon || !addon->ModuleExecFunction(func_nr % 10000, argc, p))
						{
							BackendWriteError(ERROR_UNKNWN);
						}
					}
				}
				else
				{
					BackendWriteError(ERROR_PROTO);
				}
			}
			else
			{
				MessageBox(WindowGetDesktop(),
					_T("Protocol error"),
					_T("ERROR"),
					MB_ERROR
					);

				BackendPopBuffer();

				return FALSE;
			}
		}
		else
		{
			MessageBox(WindowGetDesktop(),
				_T("Backend terminated"),
				_T("ERROR"),
				MB_ERROR
				);

			BackendPopBuffer();

			return FALSE;
		}
	}
}

/* ---------------------------------------------------------------------
 * BackendWriteError
 * Report a protocol error to the backend process  
 * ---------------------------------------------------------------------
 */
void
BackendWriteError(int code)
{
	BackendStartFrame(_T('R'), 32);
	BackendInsertInt (code);
	BackendSendFrame ();
}

/* ---------------------------------------------------------------------
 * BackendNumResultParams  
 * Return number of result parameters received  
 * ---------------------------------------------------------------------
 */
int
BackendNumResultParams(void)
{
	return NumParams;
}

/* ---------------------------------------------------------------------
 * BackendResultParam  
 * Return a result parameter  
 * ---------------------------------------------------------------------
 */
const wchar_t*
BackendResultParam(int nr)
{
	return Params[nr];
}

/* ---------------------------------------------------------------------
 * BackendSetExternamApi  
 * Extend the standard API with some application specific functions  
 * ---------------------------------------------------------------------
 */
void
BackendSetExternalApi(ApiProc api)
{
	ExternalApi = api;
}

/* helper functions */

/* ---------------------------------------------------------------------
 * BackendGetParameter  
 * Return the next parameter from the result string     
 * ---------------------------------------------------------------------
 */ 
static const wchar_t*
BackendGetParameter(wchar_t** pbuf)
{
	wchar_t* p = *pbuf;
	const wchar_t* result;

	if (!p || (*p == _T('\0')))
	{
		return NULL;
	}

	result = p;
	while ((*p != _T('\0')) && (*p != _T('\t')) && (*p != _T('\n')))
	{
		if (*p == _T('\\'))
		{
			wcscpy(p, p + 1);
			switch(*p)
			{
			case _T('n'): *p = _T('\n'); break;
			case _T('t'): *p = _T('\t'); break;
			case _T('s'): *p = _T('\\'); break;
			}
		}
		p++;
	}
	if ((*p != _T('\0')) && (*p != _T('\0')))
	{
		*(p++) = _T('\0');
		*pbuf = p;
	}
	else
	{
		*pbuf = NULL;
	}
	if (*result == _T(':'))
	{
		result++;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * BackendMakePipePath  
 * Build the path for the named pipes and create this path if necessary     
 * ---------------------------------------------------------------------
 */ 
static int
BackendMakePipePath(void)
{
	int    result;
	mode_t oldmask;

	/* pipe path is in tmp directory */
	strcpy(PipePath, "/var/run/cui");

	/* make sure that the pipe path exists */
	oldmask = umask(0);
	result  = mkdir(PipePath, 0777);

	/* check for path and premissions */	
	if (result == -1)
	{
		if (errno == EEXIST)
		{
			if (access(PipePath, X_OK) != 0)
			{
				result = (chmod(PipePath, 0777) == 0);
				umask(oldmask);
				return result;
			}
		}
		else
		{
			umask(oldmask);
			return FALSE;
		}
	}
	umask(oldmask);
	return TRUE;
}

/* ---------------------------------------------------------------------
 * BackendPushBuffer  
 * Push a transfer buffer onto the call stack
 * ---------------------------------------------------------------------
 */ 
static void
BackendPushBuffer(void)
{
	if (LastBuffer->Next == NULL)
	{
		EXECBUFFER* newbuf = (EXECBUFFER*) malloc(sizeof(EXECBUFFER));
		newbuf->BufPtr   = (wchar_t*) malloc((BUFFER_BLOCK_SIZE + 1) * sizeof(wchar_t));
		newbuf->BufSize  = BUFFER_BLOCK_SIZE;
		newbuf->Previous = LastBuffer;
		newbuf->Next = NULL;
		LastBuffer->Next = newbuf;
		LastBuffer = newbuf;
	}
	else
	{
		LastBuffer = (EXECBUFFER*) LastBuffer->Next;
	}
}

/* ---------------------------------------------------------------------
 * BackendPopBuffer  
 * Recall a buffer from the call stack
 * ---------------------------------------------------------------------
 */ 
static void
BackendPopBuffer(void)
{
	if (LastBuffer && LastBuffer->Previous)
	{
		LastBuffer = (EXECBUFFER*) LastBuffer->Previous;
	}
}

/* ---------------------------------------------------------------------
 * BackendGrowBuffer  
 * Enlarge buffer by BUFFER_BLOCK_SIZE byte
 * ---------------------------------------------------------------------
 */ 
static void
BackendGrowBuffer(EXECBUFFER* buf)
{
	wchar_t* oldbuf  = buf->BufPtr;
	int    newsize = buf->BufSize + BUFFER_BLOCK_SIZE;
	
	buf->BufPtr  = (wchar_t*) malloc((newsize + 1) * sizeof(wchar_t));
	
	memcpy(buf->BufPtr, oldbuf, buf->BufSize * sizeof(wchar_t));
	buf->BufSize = newsize;
	
	free(oldbuf);
}
