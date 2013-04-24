/* ---------------------------------------------------------------------
 * File: exp.l
 * (input file for flex - read config files for Eis/Fair)
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
#include "exp.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#ifdef ECHO
#undef ECHO
#endif

#define YY_NO_UNPUT
#define STRING_BLOCK 128

ErrorCallback ExpError = NULL;
void*         ExpErrorInst = NULL;
int           ExpCurrentLine;
wchar_t*        ExpInputFile = NULL;
wchar_t*        ExpStringBuf = NULL;
int           ExpStringBufLen = 0;
int           ExpStringBufPos = 0;
int           ExpStringML = FALSE;
int           ExpStringNL = FALSE;

void ExpAddString(const char* text,int len);

%}

COND_IDENTIFIER [A-Z][A-Z0-9_]*\([A-Z][A-Z0-9_%]*(=~\'[^\']*\')?\)
IDENTIFIER      [A-Z][A-Z0-9_]*
STR_ELEM        \\\\|\\\'|[^'\n]
STRING          \'{STR_ELEM}*\'
MLSTR_ELEM      \\\\|\\\'|[^']
MLSTRING        \'({MLSTR_ELEM}*[\n])*\'
NL              [\n]
COLON           [:]
EQUAL           [=]
ADD             [+]
SPACE           [ ]+
CR              [\r]
TAB             [\t]
COMMENT         [#]
ANYCHAR         .

%x COMMENT
%x SQSTRING
%x DQSTRING

%%

{COMMENT}		{
				BEGIN(COMMENT);
			}
<COMMENT>{NL}     	{
				ExpCurrentLine++;
				BEGIN(INITIAL);
			}
<COMMENT>{ANYCHAR}	/*  */

\'			{
				BEGIN(SQSTRING);
				ExpStringBuf[0] = 0;
				ExpStringBufPos = 0;
				ExpStringML = FALSE;
				ExpStringNL = FALSE;
			}
<SQSTRING>\'		{
				BEGIN(INITIAL);
				return ExpStringML ? EXP_MLSTRING : EXP_STRING;
			}
<SQSTRING>{CR}		/* */
<SQSTRING>{NL}          {
				ExpCurrentLine++;
				ExpStringML = TRUE;
				ExpStringNL = TRUE;
				ExpAddString(" ",1);
			}
<SQSTRING>{SPACE}|{TAB} {
				if (!ExpStringNL)
				{
					exptext[expleng] = 0;
					ExpAddString(exptext, MbStrLen(exptext));
				}
			}
<SQSTRING>[^'\n\r\t ]+	{
				exptext[expleng] = 0;
				ExpAddString(exptext, MbStrLen(exptext));
				ExpStringNL = FALSE;
			}
<SQSTRING><<EOF>>	{
				BEGIN(INITIAL);
				if (ExpError)
				{
					ExpError(
						ExpErrorInst,
						_T("Unterminated string constant!"),
						ExpInputFile,
						ExpCurrentLine,
						FALSE
						);
				}
				return EXP_EOF;
			}
\"			{
				BEGIN(DQSTRING);
				ExpStringBuf[0] = 0;
				ExpStringBufPos = 0;
				ExpStringML = FALSE;
				ExpStringNL = FALSE;
			}
<DQSTRING>\"		{
				BEGIN(INITIAL);
				return ExpStringML ? EXP_MLSTRING : EXP_STRING;
			}
<DQSTRING>{CR}		/* */
<DQSTRING>{NL}		{
				ExpCurrentLine++;
				ExpStringML = TRUE;
				ExpStringNL = TRUE;
				ExpAddString(" ",1);
			}
<DQSTRING>{SPACE}|{TAB} {
				if (!ExpStringNL)
				{
					exptext[expleng] = 0;
					ExpAddString(exptext, MbStrLen(exptext));
				}
			}
<DQSTRING>\\.		{
				exptext[expleng] = 0;
				ExpAddString(exptext, MbStrLen(exptext));
				ExpStringNL = FALSE;
			}
<DQSTRING>[^"\\\n\r\t ]+	{
				exptext[expleng] = 0;
				ExpAddString(exptext, MbStrLen(exptext));
				ExpStringNL = FALSE;
			}
<DQSTRING><<EOF>>	{
				BEGIN(INITIAL);
				if (ExpError)
				{
					ExpError(
						ExpErrorInst,
						_T("Unterminated string constant!"),
						ExpInputFile,
						ExpCurrentLine,
						FALSE
						);
				}
				return EXP_EOF;
			}
{COLON}			{
				return EXP_COLON;
			}
{EQUAL}			{
				return EXP_EQUAL;
			}
{ADD}			{
				return EXP_ADD;
			}
{IDENTIFIER}		{
				return EXP_IDENT;
			}
{COND_IDENTIFIER}	{
				char * p = strchr(exptext, '(');
				if (p) *p = 0;
				return EXP_IDENT;
			}
{NL}			{
				ExpCurrentLine++;
				/* return EXP_NL;*/
			}
{CR}			/* */
{SPACE}|{TAB}           /* */

{ANYCHAR}		{
				if (ExpError)
				{
					ExpError(
						ExpErrorInst,
						_T("Unrecognised input!"),
						ExpInputFile,
						ExpCurrentLine,
						FALSE
						);
				}
			}
<<EOF>>			{
				return EXP_EOF;
			}

%%

/* -----------------------------------------------------------------------
 * ExpFileOpen
 * Open a file for reading and prepare the scanner
 * -----------------------------------------------------------------------
 */
int ExpFileOpen(const wchar_t* filename, ErrorCallback errout, void* instance)
{
	expin = FileOpen(filename, _T("rt"));
	if (expin)
	{
		ExpInputFile = wcsdup(filename);
		ExpCurrentLine = 1;
		ExpError = errout;
		ExpErrorInst = instance;

		ExpStringBuf = (wchar_t*) malloc((STRING_BLOCK + 1) * sizeof(wchar_t));
		ExpStringBufLen = STRING_BLOCK;
		ExpStringBufPos = 0;
	}
	return expin != NULL;
}


/* -----------------------------------------------------------------------
 * ExpRead
 * Read the next token from the file input
 * -----------------------------------------------------------------------
 */
int ExpRead(void)
{
	return yylex();
}


/* -----------------------------------------------------------------------
 * ExpClose
 * Close the file input
 * -----------------------------------------------------------------------
 */
void ExpClose()
{
	if (ExpInputFile)
	{
		free(ExpInputFile);
		ExpInputFile = NULL;
	}
	if (ExpStringBuf)
	{
		free(ExpStringBuf);
		ExpStringBuf = NULL;
		ExpStringBufLen = 0;
	}
	ExpError = NULL;
	ExpErrorInst = NULL;
	fclose(expin);
}


/* -----------------------------------------------------------------------
 * ExpGetTextDup
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
wchar_t*
ExpGetTextDup(void)
{
	return MbToTCharDup(exptext);
}


/* -----------------------------------------------------------------------
 * ExpGetTextCpy
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
const wchar_t*
ExpGetTextCpy(wchar_t* buffer, int buflen)
{
	mbstowcs(buffer, exptext, buflen);
	buffer[buflen] = 0;
	return buffer;
}


/* -----------------------------------------------------------------------
 * ExpGetString
 * Return the text read by the scanner yust after removing the quotes.
 * -----------------------------------------------------------------------
 */
const wchar_t*
ExpGetString(void)
{
	if (ExpStringBufLen > 0)
	{
		return ExpStringBuf;
	}
	else
	{
		return _T("");
	}
}


/* -----------------------------------------------------------------------
 * ExpGetFileName
 * Return the name of the file the scanner is processing
 * -----------------------------------------------------------------------
 */
const wchar_t*
ExpGetFileName(void)
{
	return ExpInputFile;
}


/* -----------------------------------------------------------------------
 * ExpGetLineNumber
 * Return the current line number, the scanner input currently is on.
 * -----------------------------------------------------------------------
 */
int
ExpGetLineNumber(void)
{
	return ExpCurrentLine;
}


/* -----------------------------------------------------------------------
 * ExpRecoverFromError
 * Recover from a read error be consuming the rest of the line without
 * further action
 * -----------------------------------------------------------------------
 */
int
ExpRecoverFromError(void)
{
	int sym = ExpRead();
	while ((sym != EXP_IDENT)&&(sym != EXP_EOF))
	{
		sym = ExpRead();
	}
	return sym;
}


/* -----------------------------------------------------------------------
 * expwrap
 * Is called when the scanner reaches the end of the input stream.
 * To activate the standard procedure it is necessary to return a value
 * != 0
 * -----------------------------------------------------------------------
 */
int
expwrap ()
{
	return 1;
}


/* -----------------------------------------------------------------------
 * CfgAddString
 * Add a character or string to the string buffer. Reallocate if the
 * buffer is not large enought.
 * -----------------------------------------------------------------------
 */
void
ExpAddString(const char* text,int len)
{
	if (len > 0)
	{
		if (ExpStringBufPos + len >= ExpStringBufLen)
		{
			int newlen = ((ExpStringBufPos + len) / STRING_BLOCK + 1) * STRING_BLOCK;
			wchar_t* newstr = (wchar_t*) malloc((newlen + 1) * sizeof(wchar_t));

			if (newstr)
			{
				wcscpy(newstr, ExpStringBuf);
				free(ExpStringBuf);

				ExpStringBuf = newstr;
				ExpStringBufLen = newlen;
			}
			else
			{
				return;
			}
		}
		mbsrtowcs(&ExpStringBuf[ExpStringBufPos], &text, len, NULL);
		ExpStringBufPos += len;
		ExpStringBuf[ExpStringBufPos] = 0;
	}
}

