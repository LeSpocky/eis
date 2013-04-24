/* ---------------------------------------------------------------------
 * File: main.c
 * (main program of shellrun.cui)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: main.c 33480 2013-04-15 17:47:35Z dv $
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

typedef struct
{
	int            Color;
	int            NoColor;
	int            Mouse;
	int            NoMouse;
	int            Debug;
	int            Help;
	int            Version;
} PROGRAM_CONFIG;


static int NumErrors;
static int NumWarnings;
static int UseColors = TRUE;
static int UseMouse  = FALSE;

static PROGRAM_CONFIG Config;

static wchar_t* ScriptFile = NULL;
static wchar_t* ScriptArgs = NULL;
static wchar_t* Command = NULL;

/* what string */
const char what[] = "@(#) shellrun.cui version " VERSIONSTR " " BUILDSTR;


/* ---------------------------------------------------------------------
 * quit
 * standard exit procedure
 * ---------------------------------------------------------------------
 */
static void quit(void)
{
	if (ScriptFile) free(ScriptFile);
	if (ScriptArgs) free(ScriptArgs);
	if (Command) free(Command);
	BackendRemovePipes();
	ScriptingEnd();
	WindowEnd();
}


/* ---------------------------------------------------------------------
 * GetBasename
 * Get the basename of 'name'.
 * ---------------------------------------------------------------------
 */
static const char*
GetBasename(const char* name)
{
	const char* chr = strrchr(name,'/');

	if (!chr)
	{
		chr = name;
	}
	else
	{
		chr++;
	}
	return chr;
}


/* ---------------------------------------------------------------------
 * FileExists
 * Test if file 'filename' exists and can be opened in read mode
 * ---------------------------------------------------------------------
 */
static int
FileExists(const wchar_t* filename)
{
	char* mbfilename = TCharToMbDup(filename);
	if (mbfilename)
	{
		FILE* in = fopen(mbfilename,"rt");
		if (in)
		{
			fclose(in);
			free(mbfilename);
			return TRUE;
		}
		free(mbfilename);
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ErrorOut
 * Error callback function for config file scanner
 * ---------------------------------------------------------------------
 */
static void
ErrorOut(void* w, const wchar_t* errmsg, const wchar_t* filename,
             int linenr, int is_warning)
{
	char* mberror = TCharToMbDup(errmsg);
	
	CUI_USE_ARG(w);
	CUI_USE_ARG(filename);
	
	if (mberror)
	{
		if (is_warning)
		{
			printf("WARNING: (%i): %s\n", linenr, mberror);
			NumWarnings++;
		}
		else
		{
			printf("ERROR: (%i): %s\n", linenr, mberror);
			NumErrors++;
		}
		free(mberror);
	}
}


/* ---------------------------------------------------------------------
 * TranslateColor
 * Translates a string value to the corresponding color constant.
 * ---------------------------------------------------------------------
 */
static int
TranslateColor(CONFIG* cfg, const wchar_t* option, const wchar_t* defval)
{
	const wchar_t* color = ConfigGetString(cfg, NULL, option, OPTIONAL, defval, NULL);

	int col = BLACK;
	if (wcscasecmp(color, _T("BLACK")) == 0)             col = BLACK;
	else if (wcscasecmp(color, _T("RED")) == 0)          col = RED;
	else if (wcscasecmp(color, _T("GREEN")) == 0)        col = GREEN;
	else if (wcscasecmp(color, _T("BROWN")) == 0)        col = BROWN;
	else if (wcscasecmp(color, _T("BLUE")) == 0)         col = BLUE;
	else if (wcscasecmp(color, _T("MAGENTA")) == 0)      col = MAGENTA;
	else if (wcscasecmp(color, _T("CYAN")) == 0)         col = CYAN;
	else if (wcscasecmp(color, _T("LIGHTGRAY")) == 0)    col = LIGHTGRAY;
	else if (wcscasecmp(color, _T("DARKGRAY")) == 0)     col = DARKGRAY;
	else if (wcscasecmp(color, _T("LIGHTRED")) == 0)     col = LIGHTRED;
	else if (wcscasecmp(color, _T("LIGHTGREEN")) == 0)   col = LIGHTGREEN;
	else if (wcscasecmp(color, _T("YELLOW")) == 0)       col = YELLOW;
	else if (wcscasecmp(color, _T("LIGHTBLUE")) == 0)    col = LIGHTBLUE;
	else if (wcscasecmp(color, _T("LIGHTMAGENTA")) == 0) col = LIGHTMAGENTA;
	else if (wcscasecmp(color, _T("LIGHTCYAN")) == 0)    col = LIGHTCYAN;
	else if (wcscasecmp(color, _T("WHITE")) == 0)        col = WHITE;
	else
	{
		CONFENTRY* entry = ConfigGetEntry(cfg, NULL, option, NULL);
		if (entry)
		{
			ErrorOut(NULL, _T("invalid color definition"), _T(""), entry->LineNo, FALSE);
		}
		col = BLACK;
	}
	return col;
}


/* ---------------------------------------------------------------------
 * ReadColorRec
 * Read an user defined color record from config file
 * ---------------------------------------------------------------------
 */
static int
ReadColorRec(CONFIG* cfg, const wchar_t* name, CUIWINCOLOR* colrec)
{
	wchar_t option[128 + 1];

	swprintf(option, 128, _T("CUI_%ls_WND_COLOR"), name);
	if (ConfigGetEntry(cfg, NULL, option, NULL))
	{
		colrec->WndColor = TranslateColor(cfg, option, _T("BLUE"));

		swprintf(option, 128, _T("CUI_%ls_WND_SEL_COLOR"), name);
		colrec->WndSelColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		swprintf(option, 128, _T("CUI_%ls_WND_TXT_COLOR"), name);
		colrec->WndTxtColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		swprintf(option, 128, _T("CUI_%ls_SEL_TXT_COLOR"), name);
		colrec->SelTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		swprintf(option, 128, _T("CUI_%ls_INACT_TXT_COLOR"), name);
		colrec->InactTxtColor = TranslateColor(cfg, option, _T("DARKGRAY"));

		swprintf(option, 128, _T("CUI_%ls_HILIGHT_COLOR"), name);
		colrec->HilightColor = TranslateColor(cfg, option, _T("YELLOW"));

		swprintf(option, 128, _T("CUI_%ls_TITLE_TXT_COLOR"), name);
		colrec->TitleTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		swprintf(option, 128, _T("CUI_%ls_TITLE_BKG_COLOR"), name);
		colrec->TitleBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		swprintf(option, 128, _T("CUI_%ls_STATUS_TXT_COLOR"), name);
		colrec->StatusTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		swprintf(option, 128, _T("CUI_%ls_STATUS_BKG_COLOR"), name);
		colrec->StatusBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		swprintf(option, 128, _T("CUI_%ls_BORDER_COLOR"), name);
		colrec->BorderColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ReadConfig
 * Read file /etc/cui.conf
 * ---------------------------------------------------------------------
 */
static int
ReadConfig(const wchar_t* filename)
{
	CONFIG*     cfg;
	CUIWINCOLOR colrec;

	cfg = ConfigOpen(ErrorOut, NULL);

	NumErrors = 0;
	NumWarnings = 0;
	ConfigReadFile(cfg, filename);

	UseColors = ConfigGetBool(cfg, NULL, _T("CUI_USE_COLORS"), REQUIRED, _T("yes"), NULL);
	UseMouse  = ConfigGetBool(cfg, NULL, _T("CUI_USE_MOUSE"), REQUIRED, _T("no"), NULL);
	if (ReadColorRec(cfg, _T("WINDOW"), &colrec))
	{
		WindowAddColScheme(_T("WINDOW"), &colrec);
	}
	if (ReadColorRec(cfg, _T("DESKTOP"), &colrec))
	{
		WindowAddColScheme(_T("DESKTOP"), &colrec);
	}
	if (ReadColorRec(cfg, _T("DIALOG"), &colrec))
	{
		WindowAddColScheme(_T("DIALOG"), &colrec);
	}
	if (ReadColorRec(cfg, _T("MENU"), &colrec))
	{
		WindowAddColScheme(_T("MENU"), &colrec);
	}
	if (ReadColorRec(cfg, _T("TERMINAL"), &colrec))
	{
		WindowAddColScheme(_T("TERMINAL"), &colrec);
	}
	if (ReadColorRec(cfg, _T("HELP"), &colrec))
	{
		WindowAddColScheme(_T("HELP"), &colrec);
	}
	ConfigClose(cfg);

	if ((NumErrors != 0) || (NumWarnings != 0))
	{
		char tmp;

		printf("%i error(s), %i warning(s)\n", NumErrors, NumWarnings);
		printf("file: %s", "/etc/cui.conf\n");

		printf("\nPress ENTER to continue\n");
		scanf("%c", &tmp);
	}

	return (NumErrors == 0);
}


/* ---------------------------------------------------------------------
 * ShowProgramHelp
 * Show all available command line options and parameters
 * ---------------------------------------------------------------------
 */
static void
ShowProgramHelp(const char* progname)
{
	printf ("usage: %s [options] script-file\n"
		"\t-o  --args=<arguments>  arguments to pass to script file\n"
		"\t-c, --color             run program in color mode\n"
		"\t    --nocolor           run program in black and white mode\n"
		"\t-m, --mouse             capture mouse as input device\n"
		"\t    --nomouse           don't use mouse as input device\n"
		"\t    --debug             write script output to /tmp/cuiout.log\n"
		"\t-v, --version           show program version\n"
		"\t-h, --help              show this help\n\n",
		progname);
}


/* ---------------------------------------------------------------------
 * ShowProgramVersion
 * Show current version of this program
 * ---------------------------------------------------------------------
 */
static void
ShowProgramVersion(void)
{
	printf ("CUI Shell Runner - V%i.%i.%i\n\n",VERSION,SUBVERSION,PATCHLEVEL);
}


/* ---------------------------------------------------------------------
 * ReadCommandLine
 * Read switches and options from command line
 * ---------------------------------------------------------------------
 */
static int
ReadCommandLine(int argc, char *argv[])
{
	int c, option_index;

	static struct option long_options[] =
	{
		{"args",        required_argument, 0, 'o'},
		{"color",       no_argument, 0, 'c'},
		{"nocolor",     no_argument, 0, 0},
		{"mouse",       no_argument, 0, 'm'},
		{"nomouse",     no_argument, 0, 0},
		{"debug",       no_argument, 0, 0},
		{"help",        no_argument, 0, 'h'},
		{"version",     no_argument, 0, 'v'},
		{0, 0, 0, 0}
	};

	memset(&Config, sizeof(Config), 0);

	while (1)
	{
		c = getopt_long (argc, argv, "o:cmhv",
			long_options, &option_index);

		if (c == -1) break;

		switch (c)
		{
		case 0:
			if (long_options[option_index].flag != 0)
				break;
			if (strcmp(long_options[option_index].name, "args") == 0)
			{
				ScriptArgs = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "color") == 0)
			{
				Config.Color = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "nocolor") == 0)
			{
				Config.NoColor = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "mouse") == 0)
			{
				Config.Mouse = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "nomouse") == 0)
			{
				Config.NoMouse = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "debug") == 0)
			{
				Config.Debug = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "help") == 0)
			{
				Config.Help = TRUE;
				return TRUE;
			}
			else if (strcmp(long_options[option_index].name, "version") == 0)
			{
				Config.Version = TRUE;
				return TRUE;
			}
			else
			{
				fprintf(stderr,"%s: error reading command line!\n",
					GetBasename(argv[0]));
				Config.Help = TRUE;
				return FALSE;
			}
			break;
		case 'o':
			ScriptArgs = MbToTCharDup(optarg);
			break;
		case 'c':
			Config.Color = TRUE;
			break;
		case 'm':
			Config.Mouse = TRUE;
			break;
		case 'v':
			Config.Version = TRUE;
			return TRUE;
		case 'h':
			Config.Help = TRUE;
			return TRUE;
		case '?':
			fprintf(stderr, "%s: error reading command line!\n",
				GetBasename(argv[0]));
			Config.Help = TRUE;
			return FALSE;
		}
	}
	if ((optind == (argc - 1))&&(optind > 0))
	{
		ScriptFile = MbToTCharDup(argv[argc - 1]);
	}
	else
	{
		fprintf(stderr,"%s: missing parameter on command line!\n",
		        GetBasename(argv[0]));
		Config.Help = TRUE;
		return FALSE;
	}
	if (Config.Color && Config.NoColor)
	{
		fprintf(stderr,"%s: options --color and --nocolor can't be combined!\n",
			GetBasename(argv[0]));
		Config.Help = TRUE;
		return FALSE;
	}
	if (Config.Mouse && Config.NoMouse)
	{
		fprintf(stderr,"%s: options --mouse and --nomouse can't be combined!\n",
			GetBasename(argv[0]));
		Config.Help = TRUE;
		return FALSE;
	}
	if (ScriptArgs)
	{
		int len = wcslen(ScriptArgs);
		if ((ScriptArgs[0] == _T('\"')) && (ScriptArgs[len - 1] == _T('\"')))
		{
			ScriptArgs[len - 1] = _T('\0');
			wcscpy(ScriptArgs, ScriptArgs + 1);
		}
	}
	return TRUE;
}


/* ---------------------------------------------------------------------
 * main
 * main entry point for pg_admin.cui
 * ---------------------------------------------------------------------
 */
int
main(int argc, char* argv[])
{
	int  ecode;

	/* read config file */
	if (FileExists(_T("/etc/cui.conf")))
	{
		ReadConfig(_T("/etc/cui.conf"));
	}

	/* read command line */
	if (!ReadCommandLine(argc, argv))
	{
		ShowProgramHelp(GetBasename(argv[0]));
		return EXIT_FAILURE;
	}
	else if (Config.Help)
	{
		ShowProgramHelp(GetBasename(argv[0]));
		return EXIT_SUCCESS;
	}
	else if (Config.Version)
	{
		ShowProgramVersion();
		return EXIT_SUCCESS;
	}

	/* command line overwrites config options */
	if (Config.Color)   UseColors = TRUE;
	if (Config.NoColor) UseColors = FALSE;
	if (Config.Mouse)   UseMouse = TRUE;
	if (Config.NoMouse) UseMouse = FALSE;

	/* start cui subsystem */
	WindowStart(UseColors, UseMouse);
	ScriptingInit();
	atexit(quit);

	/* check script file */
	if (!FileExists(ScriptFile))
	{
		MessageBox(WindowGetDesktop(), _T("Script file not found!"), _T("ERROR"), MB_ERROR);
		exit(EXIT_FAILURE);
	}

	/* create pipes */
	if (BackendCreatePipes())
	{
		if (ScriptArgs)
		{
			int len = wcslen(ScriptFile) + wcslen(ScriptArgs) + 48;
			
			Command = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
			swprintf(Command, len, _T("%ls CUISHELL %i %ls"), ScriptFile, getpid(), ScriptArgs);
		}
		else
		{
			int len = wcslen(ScriptFile) + 48;

			Command = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
			swprintf(Command, len, _T("%ls CUISHELL %i"), ScriptFile, getpid());
		}

		if (BackendOpen(Command, Config.Debug))
		{
			ecode = BackendRun();
			BackendClose();
		}
		else
		{
			MessageBox(
				WindowGetDesktop(),
				_T("Unable to execute shell script"),
				_T("ERROR"),
				MB_ERROR
				);
			exit (EXIT_FAILURE);
		}
	}
	else
	{
		MessageBox(
			WindowGetDesktop(),
			_T("Error creating the named pipe"),
			_T("ERROR"),
			MB_ERROR
			);
		exit (EXIT_FAILURE);
	}
	return ecode;
}

