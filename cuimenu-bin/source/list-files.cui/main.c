/* ---------------------------------------------------------------------
 * File: main.c
 * (main program of file-list.cui)
 *
 * Copyright (C) 2007
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
 *
 * Last Update:  $Id: main.c 23498 2010-03-14 21:57:47Z dv $
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

static int NumErrors;
static int NumWarnings;
static int UseColors = TRUE;
static int UseMouse  = FALSE;

static PROGRAM_CONFIG Config;

/* what string */
const char what[] = "@(#) file-list.cui version " VERSIONSTR " " BUILDSTR;


/* ---------------------------------------------------------------------
 * FreeData
 * Free all config data
 * ---------------------------------------------------------------------
 */
static void
FreeData(void)
{
	int i;

	for (i = 0; i < MAX_ARGS; i++)
	{
		if (Config.Filter[i]) free(Config.Filter[i]);
	}
	if (Config.Title)        free(Config.Title);
	if (Config.Column)       free(Config.Column);
	if (Config.Path)         free(Config.Path);
	if (Config.Question)     free(Config.Question);
	if (Config.ScriptFile)   free(Config.ScriptFile);
	if (Config.HelpFile)     free(Config.HelpFile);
	if (Config.HelpName)     free(Config.HelpName);
	if (Config.ShellCommand) free(Config.ShellCommand);
}


/* ---------------------------------------------------------------------
 * quit
 * standard exit procedure
 * ---------------------------------------------------------------------
 */
static void quit(void)
{
	FreeData();
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
		"\t-t, --title=TITLE               set program title text\n"
		"\t-c  --column=TITLE              set column title\n"
		"  Listing options:\n"
		"\t-p, --path=/tmp                 searchpath\n"
		"\t-f, --filter=*.conf,*.cfg       optional filter\n"
		"\t-o, --only=1                    list files only,\n"
		"\t    --only=2                     \"   directories only,\n"
		"\t    --only=3                     \"   symlinks only\n"
		"\t    --only=4                     \"   sockets only\n"
		"\t-d  --date                      show date/time\n"
		"\t-m  --mode                      show mode\n"
		"\t-n  --size                      show size\n"
		"\t-u  --user                      show user and group\n"
		"\t-q, --quest='use file: %%s ?'    optional question\n"
		"\t-s, --script=/usr/sbin/run.sh   script, run after selection\n"
		"\t-w  --wait                      use anykey after script end\n"
		"\t    --helpfile=/etc/help        name of helpfile\n"
		"\t    --helpname=FILEDIALOG       XML-tag <help name=''>\n"
                "\t    --helpview                  show help after start\n"
		"\t    --color                     run program in color mode\n"
		"\t    --nocolor                   run program in black and white mode\n"
		"\t    --mouse                     capture mouse as input device\n"
		"\t    --nomouse                   don't use mouse as input device\n"
		"\t-v, --version                   show program version\n"
		"\t-h, --help                      show this help\n\n",
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
	printf ("Eisfair File Browser - V%i.%i.%i\n\n",VERSION,SUBVERSION,PATCHLEVEL);
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
	int numfilter = 0;

	static struct option long_options[] =
	{
		{"color",       no_argument, 0, 0},
		{"nocolor",     no_argument, 0, 0},
		{"mouse",       no_argument, 0, 0},
		{"nomouse",     no_argument, 0, 0},
		{"help",        no_argument, 0, 'h'},
		{"version",     no_argument, 0, 'v'},
		{"title",       required_argument, 0, 't'},
		{"column",      required_argument, 0, 'c'},
		{"path",        required_argument, 0, 'p'},
		{"filter",      required_argument, 0, 'f'},
		{"only",        required_argument, 0, 'o'},
		{"date",        no_argument, 0, 'd'},
		{"mode",        no_argument, 0, 'm'},
		{"size",        no_argument, 0, 'n'},
		{"user",        no_argument, 0, 'u'},
 		{"quest",       required_argument, 0, 'q'},
		{"script",      required_argument, 0, 's'},
		{"helpfile",    required_argument, 0, 0},
		{"helpname",    required_argument, 0, 0},
		{"wait",        no_argument, 0, 'w'},
		{"helpview",    no_argument, 0, 0},
		{0, 0, 0, 0}
	};

	while (1)
	{
		c = getopt_long (argc, argv, "c:hvt:p:f:o:dmnuq:s:w",
			long_options, &option_index);

		if (c == -1) break;

		switch (c)
		{
		case 0:
			if (long_options[option_index].flag != 0)
				break;

			if ((strcmp(long_options[option_index].name, "title") == 0)  && (optarg))
			{
				Config.Title = MbToTCharDup(optarg);
			}
			else if ((strcmp(long_options[option_index].name, "column") == 0)  && (optarg))
			{
				Config.Column = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "path") == 0 )
			{
				Config.Path = strdup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "filter") == 0 )
			{
				const char* p1 = optarg;
				const char* p2 = strchr(p1, ',');
				while (p1 && (numfilter < MAX_ARGS))
				{
					while (*p1 == ' ') { p1++; }

					if (p2)
					{
						Config.Filter[numfilter] = (char*) malloc((p2 - p1) + 1);
						strncpy(Config.Filter[numfilter], p1, (p2 - p1));
						Config.Filter[numfilter++][p2 - p1] = 0;

						p1 = p2 + 1;
						p2 = strchr(p1, ',');
					}
					else
					{
						Config.Filter[numfilter++] = strdup(p1);
						p1 = NULL;
					}
				}
			}
			else if (strcmp(long_options[option_index].name, "only") == 0 )
			{
				char* p;
				Config.FileTypeN = (int) strtol(optarg, &p, 10);
			}
			else if (strcmp(long_options[option_index].name, "date") == 0 )
			{
				Config.ColumnDate = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "mode") == 0 )
			{
				Config.ColumnMode = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "size") == 0 )
			{
				Config.ColumnSize = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "user") == 0 )
			{
				Config.ColumnUser = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "quest") == 0 )
			{
				Config.Question = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "script") == 0 )
			{
				Config.ScriptFile = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "helpfile") == 0 )
			{
				Config.HelpFile = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "helpname") == 0 )
			{
				Config.HelpName = MbToTCharDup(optarg);
			}
			else if (strcmp(long_options[option_index].name, "wait") == 0 )
			{
				Config.Wait = TRUE;
			}
			else if (strcmp(long_options[option_index].name, "helpview") == 0 )
			{
				Config.ShowHelp = TRUE;
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
		case 't':
			Config.Title = MbToTCharDup(optarg);
			break;
		case 'p':
			Config.Path = strdup(optarg);
			break;
		case 'f':
			{
				const char* p1 = optarg;
				const char* p2 = strchr(p1, ',');
				while (p1 && (numfilter < MAX_ARGS))
				{
					while (*p1 == ' ') { p1++; }

					if (p2)
					{
						Config.Filter[numfilter] = (char*) malloc((p2 - p1) + 1);
						strncpy(Config.Filter[numfilter], p1, (p2 - p1));
						Config.Filter[numfilter++][p2 - p1] = 0;

						p1 = p2 + 1;
						p2 = strchr(p1, ',');
					}
					else
					{
						Config.Filter[numfilter++] = strdup(p1);
						p1 = NULL;
					}
				}
			}
			break;
		case 'o':
			{
				char* p;
				Config.FileTypeN = (int) strtol(optarg, &p, 10);
			}
			break;
		case 'd':
			Config.ColumnDate = TRUE;
			break;
		case 'm':
			Config.ColumnMode = TRUE;
			break;
		case 'n':
			Config.ColumnSize = TRUE;
			break;
		case 'u':
			Config.ColumnUser = TRUE;
			break;
		case 'q':
			Config.Question = MbToTCharDup(optarg);
			break;
		case 's':
			Config.ScriptFile = MbToTCharDup(optarg);
			break;
		case 'w':
			Config.Wait = TRUE;
			break;
		case 'c':
			Config.Column = MbToTCharDup(optarg);
			break;
		case 'v':
			Config.Version = TRUE;
			return TRUE;
		case 'h':
			Config.Help = TRUE;
			return TRUE;
		case '?':
			fprintf(stderr,"%s: error reading command line!\n",
				GetBasename(argv[0]));
			Config.Help = TRUE;
			return FALSE;
		}
	}

	if (optind != argc)
	{
		fprintf(stderr,"%s: error reading command line!\n",
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

	if (!Config.Path)
	{
		  Config.Path = strdup("/tmp");
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
	int res;

	/* initialize program configuration */
	memset(&Config, sizeof(Config), 0);

	/* read config file */
	if (FileAccess(_T("/etc/cui.conf"), R_OK) == 0)
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

	if (Config.Filter[0] == NULL)
	{
		Config.Filter[0] = strdup("*");
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
	                    Config.Title ? Config.Title : _T("list-files.cui"),
	                    0, 0, 80, 25,
	                    CWS_MAXIMIZED, 0);

	MainwinSetConfig(window, &Config);

	WindowCreate(window);
	WindowSetFocus(window);

	/* run application */
	res = WindowRun();
	if ((res == EXIT_SUCCESS) && (Config.ShellCommand))
	{
		WindowLeaveCurses();
		ExecSysCmd(Config.ShellCommand);
		if (Config.Wait)
		{
			ExecSysCmd(_T("/var/install/bin/anykey"));
		}
	}
	return res;
}

