/* ---------------------------------------------------------------------
 * File: main.c
 * (main program of edit-conf.cui)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: main.c 33469 2013-04-14 17:32:04Z dv $
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

static int UseColors = TRUE;
static int UseMouse  = FALSE;

static PROGRAM_CONFIG Config;

/* what string */
const char what[] = "@(#) edit-conf.cui version " VERSIONSTR " " BUILDSTR;


/* ---------------------------------------------------------------------
 * FreeData
 * Free all config data
 * ---------------------------------------------------------------------
 */
static void
FreeData(void)
{
	if (Config.ConfigName) free(Config.ConfigName);
	if (Config.CheckFileName) free(Config.CheckFileName);
	if (Config.ExpFileName) free(Config.ExpFileName);
	if (Config.ConfFileName) free(Config.ConfFileName);
	if (Config.TempConfFileName) free(Config.TempConfFileName);
	if (Config.DefaultFileName) free(Config.DefaultFileName);
	if (Config.HelpFileName) free(Config.HelpFileName);
	if (Config.LogFileName) free(Config.LogFileName);

	if (Config.ConfigFileBase) free(Config.ConfigFileBase);
	if (Config.CheckFileBase) free(Config.CheckFileBase);
	if (Config.DefaultFileBase) free(Config.DefaultFileBase);
	if (Config.HelpFileBase) free(Config.HelpFileBase);
	if (Config.DefaultExtention) free(Config.DefaultExtention);
	if (Config.MenuConfigFile) free(Config.MenuConfigFile);
	if (Config.DialogPath) free(Config.DialogPath);

	if (Config.RegExpData) ExpDelete(Config.RegExpData);
	if (Config.ConfData) ConfFileDelete(Config.ConfData);
}


/* ---------------------------------------------------------------------
 * quit
 * standard exit procedure
 * ---------------------------------------------------------------------
 */
static
void quit(void)
{
	FreeData();
	BackendRemovePipes();
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
			Config.NumWarnings++;
		}
		else
		{
			printf("ERROR: (%i): %s\n", linenr, mberror);
			Config.NumErrors++;
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

		swprintf(option,128,  _T("CUI_%ls_TITLE_TXT_COLOR"), name);
		colrec->TitleTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		swprintf(option,128,  _T("CUI_%ls_TITLE_BKG_COLOR"), name);
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

	Config.NumErrors = 0;
	Config.NumWarnings = 0;
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

	if ((Config.NumErrors != 0) || (Config.NumWarnings != 0))
	{
		char tmp;

		printf("%i error(s), %i warning(s)\n", Config.NumErrors, Config.NumWarnings);
		printf("file: %s", "/etc/cui.conf\n");

		printf("\nPress ENTER to continue\n");
		scanf("%c", &tmp);
	}

	return (Config.NumErrors == 0);
}


/* ---------------------------------------------------------------------
 * ShowProgramHelp
 * Show all available command line options and parameters
 * ---------------------------------------------------------------------
 */
static void
ShowProgramHelp(const char* progname)
{
	printf ("usage: %s [options] package\n"
		"\t-c, --color             run program in color mode\n"
		"\t    --nocolor           run program in black and white mode\n"
		"\t-m, --mouse             capture mouse as input device\n"
		"\t    --nomouse           don't use mouse as input device\n"
		"\t    --debug             write script output to /tmp/cuiout.log\n"
		"\t-x, --check             check config files for errors and exit\n"
		"\t-l  --logfile=FILE      redirect error messages to log file\n"
		"\t-t, --tolerant          tolerant edit mode\n"
		"\t-f, --mkfli4l           verify file with mkfli4l instead of eischk\n"
		"\t    --config-file=FILE  name of config file other than '/etc/menu.conf'\n"
		"\t    --config-base=DIR   base directory for config files\n"
		"\t    --check-base=DIR    base directory for check files\n"
		"\t    --default-base=DIR  base directory for default files\n"
		"\t    --help-base=DIR     base directory for help files\n"
		"\t    --default-ext=EXT   default extention for config files\n"
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
	printf ("Eisfair Configuration Editor - V%i.%i.%i\n\n",VERSION,SUBVERSION,PATCHLEVEL);
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
	int len;

	static struct option long_options[] =
	{
		{"color",       no_argument, 0, 'c'},
		{"nocolor",     no_argument, 0, 0},
		{"mouse",       no_argument, 0, 'm'},
		{"nomouse",     no_argument, 0, 0},
		{"help",        no_argument, 0, 'h'},
		{"version",     no_argument, 0, 'v'},
		{"check",       no_argument, 0, 'x'},
		{"tolerant",    no_argument, 0, 't'},
		{"mkfli4l",     no_argument, 0, 'f'},
		{"debug",       no_argument, 0, 0},
		{"logfile",     required_argument, 0, 0},
		{"config-file", required_argument, 0, 0},
		{"config-base", required_argument, 0, 0},
		{"check-base",  required_argument, 0, 0},
		{"default-base",required_argument, 0, 0},
		{"help-base",   required_argument, 0, 0},
		{"default-ext", required_argument, 0, 0},
		{"dlg-path",    required_argument, 0, 0},
		{0, 0, 0, 0}
	};

	while (1)
	{
		c = getopt_long (argc, argv, "cmhvftxml:",
			long_options, &option_index);

		if (c == -1) break;

		switch (c)
		{
		case 0:
			if (long_options[option_index].flag != 0)
				break;

			if (strcmp(long_options[option_index].name, "color") == 0)
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
			else if (strcmp(long_options[option_index].name, "config-file") == 0)
			{
				if (Config.MenuConfigFile) free(Config.MenuConfigFile);
				Config.MenuConfigFile = NULL;
				if (optarg)
				{
					Config.MenuConfigFile = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "config-base") == 0)
			{
				if (Config.ConfigFileBase) free(Config.ConfigFileBase);
				Config.ConfigFileBase = NULL;
				if (optarg)
				{
					Config.ConfigFileBase = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "check-base") == 0)
			{
				if (Config.CheckFileBase) free(Config.CheckFileBase);
				Config.CheckFileBase = NULL;
				if (optarg)
				{
					Config.CheckFileBase = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "default-base") == 0)
			{
				if (Config.DefaultFileBase) free(Config.DefaultFileBase);
				Config.DefaultFileBase = NULL;
				if (optarg)
				{
					Config.DefaultFileBase = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "help-base") == 0)
			{
				if (Config.HelpFileBase) free(Config.HelpFileBase);
				Config.HelpFileBase = NULL;
				if (optarg)
				{
					Config.HelpFileBase = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "default-ext") == 0)
			{
				if (Config.DefaultExtention) free(Config.DefaultExtention);
				Config.DefaultExtention = NULL;
				if (optarg)
				{
					Config.DefaultExtention = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "dlg-path") == 0)
			{
				if (Config.DialogPath) free(Config.DialogPath);
				Config.DialogPath = NULL;
				if (optarg)
				{
					Config.DialogPath = MbToTCharDup(optarg);
				}
			}
			else if (strcmp(long_options[option_index].name, "debug") == 0)
			{
				Config.Debug = TRUE;
			}			
			else
			{
				fprintf(stderr,"%s: error reading command line!\n",
					GetBasename(argv[0]));
				Config.Help = TRUE;
				return FALSE;
			}
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
		case 't':
			Config.BeTolerant = TRUE;
			break;
		case 'x':
			Config.CheckOnly = TRUE;
			break;
		case 'f':
			Config.RunMkfli4l = TRUE;
			break;
		case 'l':
			Config.LogFileName = MbToTCharDup(optarg);
			break;
		case '?':
			fprintf(stderr,"%s: error reading command line!\n",
				GetBasename(argv[0]));
			Config.Help = TRUE;
			return FALSE;
		}
	}
	if ((optind == (argc - 1))&&(optind > 0))
	{
		Config.ConfigName = MbToTCharDup(GetBasename(argv[argc - 1]));
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

	if (!Config.MenuConfigFile)
	{
		Config.MenuConfigFile = MbToTCharDup("/etc/menu.conf");
	}
	if (!Config.ConfigFileBase)
	{
		Config.ConfigFileBase = MbToTCharDup("/etc/config.d");
	}
	if (!Config.CheckFileBase)
	{
		Config.CheckFileBase = MbToTCharDup("/etc/check.d");
	}
	if (!Config.DefaultFileBase)
	{
		Config.DefaultFileBase = MbToTCharDup("/etc/default.d");
	}
	if (!Config.HelpFileBase)
	{
		Config.HelpFileBase = MbToTCharDup("/var/install/help");
	}
	if (!Config.DialogPath)
	{
		Config.DialogPath = MbToTCharDup("/var/install/dialog.d");
	}

	if (Config.DefaultExtention)
	{
		len = wcslen(Config.CheckFileBase)  +
			wcslen(Config.ConfigName) +
			wcslen(Config.DefaultExtention) + 3;

		Config.CheckFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.CheckFileName,
			len,
			_T("%ls/%ls.%ls"),
			Config.CheckFileBase,
			Config.ConfigName,
			Config.DefaultExtention);

		len = wcslen(Config.ConfigFileBase) +
			wcslen(Config.ConfigName) +
			wcslen(Config.DefaultExtention) + 3;

		Config.ConfFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.ConfFileName,
			len,
			_T("%ls/%ls.%ls"),
			Config.ConfigFileBase,
			Config.ConfigName,
			Config.DefaultExtention);

		len = wcslen(Config.DefaultFileBase) +
			wcslen(Config.ConfigName) +
			wcslen(Config.DefaultExtention) + 3;

		Config.DefaultFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.DefaultFileName,
			len,
			_T("%ls/%ls.%ls"),
			Config.DefaultFileBase,
			Config.ConfigName,
			Config.DefaultExtention);

		len = wcslen(Config.HelpFileBase) +
			wcslen(Config.ConfigName) +
			wcslen(Config.DefaultExtention) + 3;

		Config.HelpFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.HelpFileName,
			len,
			_T("%ls/%ls.%ls"),
			Config.HelpFileBase,
			Config.ConfigName,
			Config.DefaultExtention);

		len = wcslen(_T("/tmp/")) +
			wcslen(Config.ConfigName) +
			wcslen(Config.DefaultExtention) + 3 + 32;

		Config.TempConfFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.TempConfFileName,
			len,
			_T("/tmp/ece%li/%ls.%ls"),
			(unsigned long)getpid(),
			Config.ConfigName,
			Config.DefaultExtention);
        }
	else
	{
		len = wcslen(Config.CheckFileBase) +
			wcslen(Config.ConfigName) + 2;

		Config.CheckFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.CheckFileName,
			len,
			_T("%ls/%ls"),
			Config.CheckFileBase,
			Config.ConfigName);

		len = wcslen(Config.ConfigFileBase) +
			wcslen(Config.ConfigName) + 2;

		Config.ConfFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.ConfFileName,
			len,
			_T("%ls/%ls"),
			Config.ConfigFileBase,
			Config.ConfigName);

		len = wcslen(Config.DefaultFileBase) +
			wcslen(Config.ConfigName) + 2;

		Config.DefaultFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.DefaultFileName,
			len,
			_T("%ls/%ls"),
			Config.DefaultFileBase,
			Config.ConfigName);

		len = wcslen(Config.HelpFileBase) +
			wcslen(Config.ConfigName) + 2;

		Config.HelpFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.HelpFileName,
			len,
			_T("%ls/%ls"),
			Config.HelpFileBase,
			Config.ConfigName);

		len = wcslen(_T("/tmp/")) +
			wcslen(Config.ConfigName) + 1 + 32;

		Config.TempConfFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(Config.TempConfFileName,
			len,
			_T("/tmp/ece%li/%ls"),
			(unsigned long)getpid(),Config.ConfigName);
        }

	len = wcslen(Config.CheckFileBase) +
		wcslen(Config.ConfigName) + 2 + 4;

	Config.ExpFileName = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
	swprintf(Config.ExpFileName,
		len,
		_T("%ls/%ls.exp"),
		Config.CheckFileBase,
		Config.ConfigName);

	if (wcscasecmp(Config.ConfigName, _T("environment")) == 0)
	{
		Config.BeTolerant = TRUE;
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
	CUIWINDOW* window;

	/* initialize config */
	memset(&Config, 0, sizeof(PROGRAM_CONFIG));

	/* read config file */
	if (FileAccess(_T("/etc/cui.conf"), F_OK) == 0)
	{
		ReadConfig(_T("/etc/cui.conf"));
	}

	/* read command line */
	if (!ReadCommandLine(argc, argv))
	{
		ShowProgramHelp(GetBasename(argv[0]));
		FreeData();
		return EXIT_FAILURE;
	}
	else if (Config.Help)
	{
		ShowProgramHelp(GetBasename(argv[0]));
		FreeData();
		return EXIT_SUCCESS;
	}
	else if (Config.Version)
	{
		ShowProgramVersion();
		FreeData();
		return EXIT_SUCCESS;
	}
	else if (Config.CheckOnly)
	{
		Config.NumErrors = 0;
		Config.NumWarnings = 0;

		if (MainwinReadExpressions(NULL, &Config, ErrorOut))
		{
			MainwinReadConfig(NULL, &Config, ErrorOut);
		}

		FreeData();
		return (Config.NumErrors == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
	}

	/* command line overwrites config options */
	if (Config.Color)   UseColors = TRUE;
	if (Config.NoColor) UseColors = FALSE;
	if (Config.Mouse)   UseMouse = TRUE;
	if (Config.NoMouse) UseMouse = FALSE;

	/* start cui subsystem */
	WindowStart(UseColors, UseMouse);
	atexit(quit);

	/* initialize main window */
	window = MainwinNew(WindowGetDesktop(),
	                    Config.ConfFileName,
	                    0, 0, 80, 25,
	                    CWS_MAXIMIZED, 0);

	MainwinSetConfig(window, &Config);

	WindowCreate(window);
	WindowSetFocus(window);

	/* run application */
	return WindowRun();
}

