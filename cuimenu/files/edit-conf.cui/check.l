/* ---------------------------------------------------------------------
 * File: check.l
 * (input file for flex - read check files for Eis/Fair)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
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

%option nounput

%{
#include "global.h"
#include "check.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#ifdef ECHO
#undef ECHO
#endif

#define YY_NO_UNPUT

ErrorCallback CheckError = NULL;
void*         CheckErrorInst = NULL;
int           CheckCurrentLine;
TCHAR*        CheckInputFile = NULL;

%}

IDENTIFIER      [A-Z][A-Z0-9_%]*
SQSTR_ELEM      \\\\|\\\'|[^'\n]
SQSTRING        \'{SQSTR_ELEM}*\'
DQSTR_ELEM      \\\\|\\\"|[^"\n]
DQSTRING        \"{DQSTR_ELEM}*\"
OPT_ELEM        \+
OPT_ARRAY_ELEM  \+\+
REGEXP          RE:[^[:space:]]+
NL              [\n]
HYPHEN          [-]
INVERT          [!]
SPACE           [ ]+
CR              [\r]
TAB             [\t]
COMMENT         [#]
ANYCHAR         .

%x COMMENT

%%
{COMMENT}		BEGIN(COMMENT);
<COMMENT>{NL}     	{
				CheckCurrentLine++;
				BEGIN(INITIAL);
			}
<COMMENT>{ANYCHAR}	/* */
{SQSTRING}|{DQSTRING}	{
				return CHECK_STRING;
			}
{OPT_ELEM}		{
				return CHECK_OPT_ELEM;
			}
{OPT_ARRAY_ELEM}	{
				return CHECK_OPT_ARRAY_ELEM;
			}
{HYPHEN}		{
				return CHECK_HYPHEN;
			}
{INVERT}                {
                                return CHECK_INVERT;
                        }
{IDENTIFIER}		{
				return CHECK_IDENT;
			}
{REGEXP}		{
				return CHECK_REGEXP;
			}
{NL}			{
				CheckCurrentLine++;
				return CHECK_NL;
			}
{CR}			/* */
{SPACE}|{TAB}           /* */

<<EOF>>                 {
                                return CHECK_EOF;
                        }
{ANYCHAR}		{
				if (CheckError) 
				{
					CheckError(
						CheckErrorInst,
						_T("Unrecognised input!"), 
						CheckInputFile, 
						CheckCurrentLine, 
						FALSE
						);
				}
			}
%%

/* -----------------------------------------------------------------------
 * CheckFileOpen
 * Open a file for reading and prepare the scanner
 * -----------------------------------------------------------------------
 */
int CheckFileOpen(const TCHAR* filename, ErrorCallback errout, void* instance)
{
	checkin = FileOpen(filename, _T("rt"));
	if (checkin)
	{
		CheckInputFile = tcsdup(filename);
		CheckCurrentLine = 1;
		CheckError = errout;
		CheckErrorInst = instance;
	}
	return checkin != NULL;
}


/* -----------------------------------------------------------------------
 * CheckRead
 * Read the next token from the file input
 * -----------------------------------------------------------------------
 */
int CheckRead(void)
{
	return yylex();
}


/* -----------------------------------------------------------------------
 * CheckClose
 * Close the file input
 * -----------------------------------------------------------------------
 */
void CheckClose()
{
	if (CheckInputFile)
	{
		free(CheckInputFile);
		CheckInputFile = NULL;
		CheckError = NULL;
		CheckErrorInst = NULL;
	}
	FileClose(checkin);
}


/* -----------------------------------------------------------------------
 * CheckGetTextDup
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
TCHAR* 
CheckGetTextDup(void)
{
	return MbToTCharDup(checktext); 
}

/* -----------------------------------------------------------------------
 * CheckGetTextCpy
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
const TCHAR* 
CheckGetTextCpy(TCHAR* buffer, int buflen)
{
#ifdef _UNICODE
	mbstowcs(buffer, checktext, buflen);
#else
	strncpy(buffer, checktext, buflen);
#endif
	buffer[buflen] = 0;
	return buffer;
}

/* -----------------------------------------------------------------------
 * CfgGetStringDup
 * Return the text read by the scanner yust after removing the quotes. 
 * -----------------------------------------------------------------------
 */
TCHAR* 
CheckGetStringDup(void)
{
	int len = strlen(checktext);
	if (len > 2)
	{
		checktext[len - 1] = 0;
		return MbToTCharDup(&checktext[1]); 
	}
	else
	{
		return tcsdup(_T(""));
	}
}

/* -----------------------------------------------------------------------
 * CheckGetFileName
 * Return the name of the file the scanner is processing
 * -----------------------------------------------------------------------
 */
const TCHAR* 
CheckGetFileName(void)
{
	return CheckInputFile;
}


/* -----------------------------------------------------------------------
 * CheckGetLineNumber
 * Return the current line number, the scanner input currently is on.
 * -----------------------------------------------------------------------
 */
int 
CheckGetLineNumber(void)
{
	return CheckCurrentLine;
}


/* -----------------------------------------------------------------------
 * CheckRecoverFromError 
 * Recover from a read error be consuming the rest of the line without
 * further action
 * -----------------------------------------------------------------------
 */
int 
CheckRecoverFromError(void)
{
	int sym = CheckRead();
	while ((sym != CHECK_NL)&&(sym != CHECK_EOF))
	{
		sym = CheckRead();
	}
	return sym;
}


/* -----------------------------------------------------------------------
 * checkwrap
 * Is called when the scanner reaches the end of the input stream. 
 * To activate the standard procedure it is necessary to return a value
 * != 0
 * -----------------------------------------------------------------------
 */
int 
checkwrap ()
{
	return 1;
}

