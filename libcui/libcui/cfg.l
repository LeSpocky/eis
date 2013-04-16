/* ---------------------------------------------------------------------
 * File: cfg.l
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
#include "cui-util.h"
#include "cfg.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#ifdef ECHO
#undef ECHO
#endif

#define YY_NO_UNPUT
#define COMMENT_BLOCK 128

ErrorCallback CfgError = NULL;
void*         CfgErrorInst = NULL;
int           CfgCurrentLine;
wchar_t*        CfgInputFile = NULL;
wchar_t*        CfgComment = NULL;
int           CfgCommentLen = 0;
int           CfgCommentPos = 0;

void CfgAddComment(const char* text,int len);

%}

IDENTIFIER      [A-Z][A-Z0-9_]*
SQSTR_ELEM      \\\\|\\\'|[^'\n]
SQSTRING        \'{SQSTR_ELEM}*\'
DQSTR_ELEM      \\\\|\\\"|[^"\n]
DQSTRING        \"{DQSTR_ELEM}*\"
NL              [\n]
EQUAL           [=]
SPACE           [ ]+
CR              [\r]
TAB             [\t]
LINE_COMMENT    ^[#]
VAL_COMMENT     [ \t]+[#]
ANYCHAR         .

%x VCOMMENT
%x LCOMMENT

%%

{VAL_COMMENT}		{
				CfgCommentPos = 0;
				CfgAddComment("#",1);
				BEGIN(VCOMMENT);
			}
<VCOMMENT>{NL}     	{
				CfgCurrentLine++;
				BEGIN(INITIAL);
				return CFG_COMMENT;
			}
<VCOMMENT>{CR}		/* */
<VCOMMENT>{ANYCHAR}	{
				cfgtext[cfgleng] = 0;
				CfgAddComment(cfgtext, MbStrLen(cfgtext));
			}
{LINE_COMMENT}		{
				CfgCommentPos = 0;
				CfgAddComment("#",1);
				BEGIN(LCOMMENT);
			}
<LCOMMENT>{NL}     	{
				CfgCurrentLine++;
				BEGIN(INITIAL);
				return CFG_LINE_COMMENT;
			}
<LCOMMENT>{CR}		/* */
<LCOMMENT>{ANYCHAR}	{
				cfgtext[cfgleng] = 0;
				CfgAddComment(cfgtext,MbStrLen(cfgtext));
			}
{SQSTRING}|{DQSTRING}	{
				return CFG_STRING;
			}
{EQUAL}			{
				return CFG_EQUAL;
			}
{IDENTIFIER}		{
				return CFG_IDENT;
			}
{NL}			{
				CfgCurrentLine++;
				return CFG_NL;
			}
{CR}			/* */
{SPACE}|{TAB}           /* */

{ANYCHAR}		{
				if (CfgError) 
				{
					CfgError(
						CfgErrorInst,
						_T("Unrecognised input!"), 
						CfgInputFile, 
						CfgCurrentLine, 
						FALSE
						);
				}
			}
<<EOF>>			{
				return CFG_EOF;
			}

%%

/* -----------------------------------------------------------------------
 * CfgFileOpen
 * Open a file for reading and prepare the scanner
 * -----------------------------------------------------------------------
 */
int CfgFileOpen(const wchar_t* filename, ErrorCallback errout, void* instance)
{
	char* mbfilename = TCharToMbDup(filename); 
	if (mbfilename)
	{
		cfgin = fopen(mbfilename, "rt");
		if (cfgin)
		{
			CfgInputFile = wcsdup(filename);
			CfgCurrentLine = 1;
			CfgError = errout;
			CfgErrorInst = instance;

			CfgComment = (wchar_t*) malloc((COMMENT_BLOCK + 1) * sizeof(wchar_t));
			CfgCommentLen = COMMENT_BLOCK;
			CfgCommentPos = 0;
		}
		free(mbfilename);
	}
	return cfgin != NULL;
}


/* -----------------------------------------------------------------------
 * CfgRead
 * Read the next token from the file input
 * -----------------------------------------------------------------------
 */
int CfgRead(void)
{
	return yylex();
}


/* -----------------------------------------------------------------------
 * CfgClose
 * Close the file input
 * -----------------------------------------------------------------------
 */
void CfgClose()
{
	if (CfgInputFile)
	{
		free(CfgInputFile);
		CfgInputFile = NULL;
	}
	if (CfgComment)
	{
		free(CfgComment);
		CfgComment = NULL;
		CfgCommentLen = 0;
	}
	CfgError = NULL;
	fclose(cfgin);
}


/* -----------------------------------------------------------------------
 * CfgGetTextDup
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
wchar_t* 
CfgGetTextDup(void)
{
	return MbToTCharDup(cfgtext); 
}


/* -----------------------------------------------------------------------
 * CfgGetStringDup
 * Return the text read by the scanner yust after removing the quotes. 
 * -----------------------------------------------------------------------
 */
wchar_t* 
CfgGetStringDup(void)
{
	int len = strlen(cfgtext);
	if (len > 2)
	{
		cfgtext[len - 1] = 0;
		return MbToTCharDup(&cfgtext[1]); 
	}
	else
	{
		return wcsdup(_T(""));
	}
}


/* -----------------------------------------------------------------------
 * CfgGetComment
 * Return the comment read by the scanner.
 * -----------------------------------------------------------------------
 */
const wchar_t* 
CfgGetComment(void)
{
	return CfgComment;
}


/* -----------------------------------------------------------------------
 * CfgGetFileName
 * Return the name of the file the scanner is processing
 * -----------------------------------------------------------------------
 */
const wchar_t* 
CfgGetFileName(void)
{
	return CfgInputFile;
}


/* -----------------------------------------------------------------------
 * CfgGetLineNumber
 * Return the current line number, the scanner input currently is on.
 * -----------------------------------------------------------------------
 */
int 
CfgGetLineNumber(void)
{
	return CfgCurrentLine;
}


/* -----------------------------------------------------------------------
 * CfgRecoverFromError 
 * Recover from a read error be consuming the rest of the line without
 * further action
 * -----------------------------------------------------------------------
 */
int 
CfgRecoverFromError(void)
{
	int sym = CfgRead();
	while ((sym != CFG_NL)&&(sym != CFG_EOF))
	{
		sym = CfgRead();
	}
	return sym;
}


/* -----------------------------------------------------------------------
 * cfgwrap
 * Is called when the scanner reaches the end of the input stream. 
 * To activate the standard procedure it is necessary to return a value
 * != 0
 * -----------------------------------------------------------------------
 */
int 
cfgwrap ()
{
	return 1;
}


/* -----------------------------------------------------------------------
 * CfgAddComment
 * Add a character or string to the comment buffer. Reallocate if the 
 * buffer is not large enought.
 * -----------------------------------------------------------------------
 */
void
CfgAddComment(const char* text, int len)
{
	if (len > 0)
	{
		if (CfgCommentPos + len >= CfgCommentLen)
		{
			int newlen = ((CfgCommentPos + len) / COMMENT_BLOCK + 1) * COMMENT_BLOCK;
			wchar_t* newcmt = (wchar_t*) malloc((newlen + 1) * sizeof(wchar_t));

			if (newcmt)
			{		
				wcscpy(newcmt, CfgComment);
				free(CfgComment);

				CfgComment = newcmt;
				CfgCommentLen = newlen;
			}
			else
			{
				return;
			}
		}
		mbsrtowcs(&CfgComment[CfgCommentPos], &text, len, NULL);
		
		CfgCommentPos += len;
		CfgComment[CfgCommentPos] = 0;
	}
}

