/* ---------------------------------------------------------------------
 * File: exp.l
 * (input file for flex - read config files for Eis/Fair)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 * 
 * Last Update:  $Id: xml.l 24973 2010-07-11 11:53:27Z dv $
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
#include "cui-util.h"
#include "xml.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#ifdef ECHO
#undef ECHO
#endif

#define YY_NO_UNPUT
#define DATA_BLOCK 128

ErrorCallback XmlErrorHook = NULL;
void*         XmlErrorInst = NULL;
int           XmlCurrentLine;
TCHAR*        XmlInputFile = NULL;
TCHAR*        XmlDataBuf = NULL;
int           XmlDataBufLen = 0;
int           XmlDataBufPos = 0;
int           XmlSpace = FALSE;
int           XmlProcessNL = FALSE;

void XmlAddData(const char* text, int len);
void XmlAddEntity(const char* text);

const char* EntityTable[][2] = {
#ifdef _UNICODE
		{"&auml;", "\xC3\xA4"},
		{"&Auml;", "\xC3\x84"},
		{"&ouml;", "\xC3\xB6"},
		{"&Ouml;", "\xC3\x96"},
		{"&uuml;", "\xC3\xBC"},
		{"&Uuml;", "\xC3\x9C"},
		{"&szligl;", "\xC3\x9F"},
#else
		{"&auml;", "ä"},
		{"&Auml;", "Ä"},
		{"&ouml;", "ö"},
		{"&Ouml;", "Ö"},
		{"&uuml;", "ü"},
		{"&Uuml;", "Ü"},
		{"&szligl;", "ß"},
#endif
		{"&lt;", "<"},
		{"&gt;", ">"},
		{"&amp;", "&"},
		{"&quot;", "\""},
		{"&nbsp;", " "},
		{0, ""},
	};

%}

IDENTIFIER      [A-Za-z][A-Za-z0-9_-]*
STR_ELEM        \\\\|\\\"|[^"\n]
STRING          \"{STR_ELEM}*\"
SQSTR_ELEM      \\\\|\\\'|[^'\n]
SQSTRING        \'{SQSTR_ELEM}*\'
ENTITY          \&[a-zA-Z]+\;
COMMENTOPEN     <!--
COMMENTCLOSE    -->
HEADEROPEN      \<\?
HEADERCLOSE     \?\>
TAGOPEN         [<]
TAGCLOSE        [>]
NL              [\n]
EQUAL           [=]
AMPERSAND       [&]
DIVIDE          [/]
DASH            [-]
SPACE           [ ]+
CR              [\r]
TAB             [\t]
LINE_COMMENT    ^[#]
DATA            [^ \n\r\t<&]+
COMMENTDATA     [^ \n\r\t-]
ANYCHAR         .

%x LCOMMENT
%x COMMENT
%x TAG

%%
{LINE_COMMENT}		{
				BEGIN(LCOMMENT);
			}
<LCOMMENT>{NL}		{
				XmlCurrentLine++;
				BEGIN(INITIAL);
			}
<LCOMMENT>{ANYCHAR}	/*  */


{COMMENTOPEN}		{
				BEGIN(COMMENT);
				return XML_COMMENTOPEN;
			}
<COMMENT>{COMMENTCLOSE}	{
				BEGIN(INITIAL);
				return XML_COMMENTCLOSE;
			}
<COMMENT>{CR}           /* ignore CR's in DOS files */
<COMMENT>{NL}		{
				XmlCurrentLine++;
				XmlAddData("\n",1);
				XmlSpace = FALSE;
			}
<COMMENT>{SPACE}|{TAB}	{
				if (!XmlSpace && (XmlDataBufPos != 0))
				{
					XmlSpace = TRUE;
				}
			}
<COMMENT>{COMMENTDATA}	{
				if (XmlSpace)
				{
					XmlAddData(" ",1);
					XmlSpace = FALSE;
				}
				xmltext[xmlleng] = 0;
				XmlAddData(xmltext, MbStrLen(xmltext));		
			}
<COMMENT>{DASH}		{
				if (XmlSpace)
				{
					XmlAddData(" ",1);
					XmlSpace = FALSE;
				}
				XmlAddData("-",1);
			}

<COMMENT><<EOF>>	{
				XmlErrorHook(
					XmlErrorInst,
					_T("Unterminated comment block!"), 
					XmlInputFile, 
					XmlCurrentLine, 
					FALSE
					);
			}

{HEADEROPEN}		{
				BEGIN(TAG);
				return XML_HEADEROPEN;
			}
{TAGOPEN}		{
				BEGIN(TAG);
				return XML_TAGOPEN;
			}
<TAG>{IDENTIFIER}	{
				return XML_IDENT;
			}
<TAG>{TAGCLOSE}		{
				BEGIN(INITIAL);
				return XML_TAGCLOSE;
			}
<TAG>{HEADERCLOSE}	{
				BEGIN(INITIAL);
				return XML_HEADERCLOSE;
			}
<TAG>{EQUAL}		{
				return XML_EQUAL;
			}
<TAG>{DIVIDE}		{
				return XML_DIVIDE;
			}
<TAG>{STRING}|{SQSTRING}	{
				return XML_STRING;
			}
<TAG>{NL}		{
				XmlCurrentLine++;
			}
<TAG>{CR}               /* */
<TAG>{SPACE}|{TAB}	/* */

<TAG>{ANYCHAR}		{
				if (XmlErrorHook) 
				{
					XmlErrorHook(
						XmlErrorInst,
						_T("Unrecognised input within tag definition!"), 
						XmlInputFile, 
						XmlCurrentLine, 
						FALSE
						);
				}
			}
<TAG><<EOF>>		{
				XmlErrorHook(
					XmlErrorInst,
					_T("Unclosed tag!"), 
					XmlInputFile, 
					XmlCurrentLine, 
					FALSE
					);
			}
{CR}                    /* ignore CR's in DOS files */
{NL}			{
				XmlCurrentLine++;
				if (XmlProcessNL)
				{
					XmlAddData("\n",1);
					XmlSpace = FALSE;
				}
				else if (XmlDataBufPos != 0)
				{
					XmlSpace = TRUE;
				}
			}
{SPACE}|{TAB}		{
				if (!XmlSpace && (XmlDataBufPos != 0))
				{
					XmlSpace = TRUE;
				}
			}
{ENTITY}		{
				if (XmlSpace)
                                {
                                        XmlAddData(" ",1);
                                        XmlSpace = FALSE;
                                }
				xmltext[xmlleng] = 0;
				XmlAddEntity(xmltext);
			}
{DATA}			{
				if (XmlSpace)
				{
					XmlAddData(" ",1);
					XmlSpace = FALSE;
				}
				xmltext[xmlleng] = 0;
				XmlAddData(xmltext, MbStrLen(xmltext));		
			}
{AMPERSAND}		{
				if (XmlSpace)
				{
					XmlAddData(" ",1);
					XmlSpace = FALSE;
				}
				XmlAddData("&", 1);
			}
<<EOF>>			{
				return XML_EOF;
			}

%%

/* -----------------------------------------------------------------------
 * XmlFileOpen
 * Open a file for reading and prepare the scanner
 * -----------------------------------------------------------------------
 */
int XmlFileOpen(const TCHAR* filename, ErrorCallback errout, void* instance)
{
	char* mbfilename = TCharToMbDup(filename); 
	if (mbfilename)
	{
		xmlin = fopen(mbfilename, "rt");
		if (xmlin)
		{
			XmlInputFile = tcsdup(filename);
			XmlCurrentLine = 1;
			XmlErrorHook = errout;
			XmlErrorInst = instance;

			XmlDataBuf = (TCHAR*) malloc((DATA_BLOCK + 1) * sizeof(TCHAR));
			XmlDataBufLen = DATA_BLOCK;
			XmlDataBufPos = 0;
			XmlClearData();
		}
		free(mbfilename);
	}
	return xmlin != NULL;
}


/* -----------------------------------------------------------------------
 * XmlRead
 * Read the next token from the file input
 * -----------------------------------------------------------------------
 */
int XmlRead(void)
{
	return yylex();
}


/* -----------------------------------------------------------------------
 * XmlClose
 * Close the file input
 * -----------------------------------------------------------------------
 */
void XmlClose()
{
	if (XmlInputFile)
	{
		free(XmlInputFile);
		XmlInputFile = NULL;
	}
	if (XmlDataBuf)
	{
		free(XmlDataBuf);
		XmlDataBuf = NULL;
		XmlDataBufLen = 0;
	}
	XmlErrorHook = NULL;
	fclose(xmlin);
}


/* -----------------------------------------------------------------------
 * XmlParseNL
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
void 
XmlParseNL(int state)
{
	XmlProcessNL = state;
}


/* -----------------------------------------------------------------------
 * XmlGetTextDup
 * Return the text read by the scanner. This can be an idetifier or an
 * regular expression
 * -----------------------------------------------------------------------
 */
TCHAR* 
XmlGetTextDup(void)
{
	return MbToTCharDup(xmltext); 
}


/* -----------------------------------------------------------------------
 * XmlGetStringDup
 * Return the text read by the scanner yust after removing the quotes.
 * -----------------------------------------------------------------------
 */
TCHAR*
XmlGetStringDup(void)
{
        int len = strlen(xmltext);
        if (len > 2)
        {
                xmltext[len - 1] = 0;
                return MbToTCharDup(&xmltext[1]); 
        }
        else
        {
                return tcsdup(_T(""));
        }
}


/* -----------------------------------------------------------------------
 * ExpGetDataBuf
 * Return the data read by the scanner. 
 * -----------------------------------------------------------------------
 */
const TCHAR* 
XmlGetDataBuf(void)
{
	if (XmlDataBufLen > 0)
	{
		return XmlDataBuf; 
	}
	else
	{
		return _T("");
	}
}


/* -----------------------------------------------------------------------
 * XmlClearData
 * Clear the data buffer
 * -----------------------------------------------------------------------
 */
void
XmlClearData(void)
{
	XmlSpace = FALSE;
	XmlDataBuf[0] = 0;
	XmlDataBufPos = 0;
}


/* -----------------------------------------------------------------------
 * XmlGetFileName
 * Return the name of the file the scanner is processing
 * -----------------------------------------------------------------------
 */
const TCHAR* 
XmlGetFileName(void)
{
	return XmlInputFile;
}


/* -----------------------------------------------------------------------
 * XmlGetLineNumber
 * Return the current line number, the scanner input currently is on.
 * -----------------------------------------------------------------------
 */
int 
XmlGetLineNumber(void)
{
	return XmlCurrentLine;
}


/* -----------------------------------------------------------------------
 * XmlRecoverFromError 
 * Recover from a read error be consuming the rest of the line without
 * further action
 * -----------------------------------------------------------------------
 */
int 
XmlRecoverFromError(int nextsym)
{
	int sym = XmlRead();
	while ((sym != nextsym)&&(sym != XML_EOF))
	{
		sym = XmlRead();
	}
	return sym;
}


/* -----------------------------------------------------------------------
 * xmlwrap
 * Is called when the scanner reaches the end of the input stream. 
 * To activate the standard procedure it is necessary to return a value
 * != 0
 * -----------------------------------------------------------------------
 */
int 
xmlwrap ()
{
	return 1;
}


/* -----------------------------------------------------------------------
 * XmlAddData
 * Add a character or string to the data buffer. Reallocate if the
 * buffer is not large enought.
 * -----------------------------------------------------------------------
 */
void
XmlAddData(const char* text,int len)
{
	if (len > 0)
	{
		if (XmlDataBufPos + len >= XmlDataBufLen)
		{
			int newlen = ((XmlDataBufPos + len) / DATA_BLOCK + 1) * DATA_BLOCK;
			TCHAR* newstr = (TCHAR*) malloc((newlen + 1) * sizeof(TCHAR));

			if (newstr)
			{
				tcscpy(newstr, XmlDataBuf);
				free(XmlDataBuf);

				XmlDataBuf = newstr;
				XmlDataBufLen = newlen;
			}
			else
			{
				return;
			}
		}
#ifdef _UNICODE
		mbsrtowcs(&XmlDataBuf[XmlDataBufPos], &text, len, NULL);
#else
		strncpy(&XmlDataBuf[XmlDataBufPos], text, len);
#endif
		XmlDataBufPos += len;
		XmlDataBuf[XmlDataBufPos] = 0;
	}
}


/* -----------------------------------------------------------------------
 * XmlAddEntity
 * Add a xml entity to the current data block
 * -----------------------------------------------------------------------
 */
void
XmlAddEntity(const char* text)
{
	int index = 0;
	while (EntityTable[index][0] != NULL)
	{
		if (strcmp(text, EntityTable[index][0]) == 0)
		{
			XmlAddData(EntityTable[index][1], 1);
			return;
		}
		index++;
	}

	XmlAddData(text, MbStrLen(text));
}

