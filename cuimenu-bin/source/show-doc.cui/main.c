/* ---------------------------------------------------------------------
 * File: main.c
 * (main program of show-doc.cui)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: main.c 28346 2011-05-10 19:25:49Z dv $
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
#include "pagerfile.h"


static int NumErrors;
static int NumWarnings;
static int UseColors = TRUE;
static int UseMouse  = FALSE;

static PROGRAM_CONFIG Config;

/* what string */
const char what[] = "@(#) show-doc.cui version " VERSIONSTR " " BUILDSTR;


/* ---------------------------------------------------------------------
 * quit
 * standard exit procedure
 * ---------------------------------------------------------------------
 */
static void quit(void)
{
	WindowEnd();
	if (Config.Title)     free(Config.Title);
	if (Config.Filename)  free(Config.Filename);
	if (Config.Indexfile) free(Config.Indexfile);
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
FileExists(const char* filename)
{
	FILE* in = fopen(filename,"rt");
	if (in)
	{
		fclose(in);
		return TRUE;
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ErrorOut
 * Error callback function for config file scanner
 * ---------------------------------------------------------------------
 */
static void
ErrorOut(void* w, const TCHAR* errmsg, const TCHAR* filename,
             int linenr, int is_warning)
{
	char* mberror = TCharToMbDup(errmsg);
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
TranslateColor(CONFIG* cfg, const TCHAR* option, const TCHAR* defval)
{
	const TCHAR* color = ConfigGetString(cfg, NULL, option, OPTIONAL, defval, NULL);

	int col = BLACK;
	if (tcscasecmp(color, _T("BLACK")) == 0)             col = BLACK;
	else if (tcscasecmp(color, _T("RED")) == 0)          col = RED;
	else if (tcscasecmp(color, _T("GREEN")) == 0)        col = GREEN;
	else if (tcscasecmp(color, _T("BROWN")) == 0)        col = BROWN;
	else if (tcscasecmp(color, _T("BLUE")) == 0)         col = BLUE;
	else if (tcscasecmp(color, _T("MAGENTA")) == 0)      col = MAGENTA;
	else if (tcscasecmp(color, _T("CYAN")) == 0)         col = CYAN;
	else if (tcscasecmp(color, _T("LIGHTGRAY")) == 0)    col = LIGHTGRAY;
	else if (tcscasecmp(color, _T("DARKGRAY")) == 0)     col = DARKGRAY;
	else if (tcscasecmp(color, _T("LIGHTRED")) == 0)     col = LIGHTRED;
	else if (tcscasecmp(color, _T("LIGHTGREEN")) == 0)   col = LIGHTGREEN;
	else if (tcscasecmp(color, _T("YELLOW")) == 0)       col = YELLOW;
	else if (tcscasecmp(color, _T("LIGHTBLUE")) == 0)    col = LIGHTBLUE;
	else if (tcscasecmp(color, _T("LIGHTMAGENTA")) == 0) col = LIGHTMAGENTA;
	else if (tcscasecmp(color, _T("LIGHTCYAN")) == 0)    col = LIGHTCYAN;
	else if (tcscasecmp(color, _T("WHITE")) == 0)        col = WHITE;
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
ReadColorRec(CONFIG* cfg, const TCHAR* name, CUIWINCOLOR* colrec)
{
	TCHAR option[128 + 1];

#ifdef _UNICODE
	stprintf(option, 128, _T("CUI_%ls_WND_COLOR"), name);
	if (ConfigGetEntry(cfg, NULL, option, NULL))
	{
		colrec->WndColor = TranslateColor(cfg, option, _T("BLUE"));

		stprintf(option, 128, _T("CUI_%ls_WND_SEL_COLOR"), name);
		colrec->WndSelColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%ls_WND_TXT_COLOR"), name);
		colrec->WndTxtColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%ls_SEL_TXT_COLOR"), name);
		colrec->SelTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option, 128, _T("CUI_%ls_INACT_TXT_COLOR"), name);
		colrec->InactTxtColor = TranslateColor(cfg, option, _T("DARKGRAY"));

		stprintf(option, 128, _T("CUI_%ls_HILIGHT_COLOR"), name);
		colrec->HilightColor = TranslateColor(cfg, option, _T("YELLOW"));

		stprintf(option,128,  _T("CUI_%ls_TITLE_TXT_COLOR"), name);
		colrec->TitleTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option,128,  _T("CUI_%ls_TITLE_BKG_COLOR"), name);
		colrec->TitleBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%ls_STATUS_TXT_COLOR"), name);
		colrec->StatusTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option, 128, _T("CUI_%ls_STATUS_BKG_COLOR"), name);
		colrec->StatusBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%ls_BORDER_COLOR"), name);
		colrec->BorderColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		return TRUE;
	}
#else
	stprintf(option, 128, _T("CUI_%s_WND_COLOR"), name);
	if (ConfigGetEntry(cfg, NULL, option, NULL))
	{
		colrec->WndColor = TranslateColor(cfg, option, _T("BLUE"));

		stprintf(option, 128, _T("CUI_%s_WND_SEL_COLOR"), name);
		colrec->WndSelColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%s_WND_TXT_COLOR"), name);
		colrec->WndTxtColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%s_SEL_TXT_COLOR"), name);
		colrec->SelTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option, 128, _T("CUI_%s_INACT_TXT_COLOR"), name);
		colrec->InactTxtColor = TranslateColor(cfg, option, _T("DARKGRAY"));

		stprintf(option, 128, _T("CUI_%s_HILIGHT_COLOR"), name);
		colrec->HilightColor = TranslateColor(cfg, option, _T("YELLOW"));

		stprintf(option,128,  _T("CUI_%s_TITLE_TXT_COLOR"), name);
		colrec->TitleTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option,128,  _T("CUI_%s_TITLE_BKG_COLOR"), name);
		colrec->TitleBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%s_STATUS_TXT_COLOR"), name);
		colrec->StatusTxtColor = TranslateColor(cfg, option, _T("BLACK"));

		stprintf(option, 128, _T("CUI_%s_STATUS_BKG_COLOR"), name);
		colrec->StatusBkgndColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		stprintf(option, 128, _T("CUI_%s_BORDER_COLOR"), name);
		colrec->BorderColor = TranslateColor(cfg, option, _T("LIGHTGRAY"));

		return TRUE;
	}
#endif
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ReadConfig
 * Read file /etc/cui.conf
 * ---------------------------------------------------------------------
 */
static int
ReadConfig(const TCHAR* filename)
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
	printf ("usage: %s [options]\n"
		"\t-c, --color             run program in color mode\n"
		"\t    --nocolor           run program in black and white mode\n"
		"\t    --noframe           show textwindow without frame\n"
		"\t-m, --mouse             capture mouse as input device\n"
		"\t    --nomouse           don't use mouse as input device\n"
		"\t-v, --version           show program version\n"
		"\t-t, --title=<title>     program title instead of file name\n"
		"\t-f, --follow            enable tail function\n"
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
	printf ("Eisfair Documentation Viewer - V%i.%i.%i\n\n",VERSION,SUBVERSION,PATCHLEVEL);
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
		{"color",       no_argument, 0, 'c'},
		{"nocolor",     no_argument, 0, 0},
		{"noframe",     no_argument, 0, 0},
		{"mouse",       no_argument, 0, 'm'},
		{"nomouse",     no_argument, 0, 0},
		{"help",        no_argument, 0, 'h'},
		{"version",     no_argument, 0, 'v'},
		{"follow",      no_argument, 0, 'f'},
		{"title",       required_argument, 0, 't'},
		{0, 0, 0, 0}
	};

	while (1)
	{
		c = getopt_long (argc, argv, "cmhvt:f",
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
			else if (strcmp(long_options[option_index].name, "noframe") == 0)
			{
				Config.NoFrame = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "mouse") == 0)
			{
				Config.Mouse = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "nomouse") == 0)
			{
				Config.NoMouse = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "follow") == 0)
			{
				Config.Follow = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "title") == 0)
			{
				Config.Title = MbToTCharDup(optarg);
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
		case 'f':
			Config.Follow = TRUE;
			break;
		case 't':
			Config.Title = MbToTCharDup(optarg);
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
		Config.Filename = MbToTCharDup(argv[argc - 1]);
	}
	else
	{
		fprintf(stderr,"%s: missing parameter on command line!\n",
			GetBasename(argv[0]));
		Config.Help = TRUE;
		return FALSE;
        }
	if ((Config.Indexfile == NULL) && (Config.Filename[0] != 0))
	{
		Config.Indexfile = MainwinMakeIndexFile(Config.Filename);
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
	return TRUE;
}


/* ---------------------------------------------------------------------
 * main
 * main entry point for show-doc.cui
 * ---------------------------------------------------------------------
 */
int
main(int argc, char* argv[])
{
	CUIWINDOW* window;

	memset(&Config, sizeof(Config), 0);

	/* read config file */
	if (FileExists("/etc/cui.conf"))
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
	atexit(quit);

	/* initialize main window */
	window = MainwinNew(WindowGetDesktop(),
	                    Config.Title != 0 ? Config.Title : Config.Filename,
	                    0, 0, 80, 25,
	                    CWS_MAXIMIZED, 0);

	MainwinSetConfig(window, &Config);

	WindowCreate(window);
	WindowSetFocus(window);

	/* run application */
	return WindowRun();
}

