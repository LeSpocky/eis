/* ---------------------------------------------------------------------
 * File: expfile.h
 * (reading and processing regular expressions)
 *
 * Copyright (C) 2004
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

#ifndef EXPFILE_H
#define EXPFILE_H

#include "global.h"

/* return values of ExpMatch */
#define EXP_ERROR  -1           /* Error compiling expression */
#define EXP_MATCH   0           /* String matches expression */
#define EXP_NOMATCH 1           /* String doesn't macht */

typedef struct EXPENTRYStruct
{
	wchar_t*  Name;            /* Name of the expression */
	wchar_t*  Expression;      /* Buffer containing the expression */
	wchar_t*  ErrorMsg;        /* Buffer containing the error message */
	int       Extentable;      /* Is this entry extentable? */
	void*     Next;
} EXPENTRY;


typedef struct EXPFILEStruct
{
	EXPENTRY*     FirstExp; /* First Expression in the list of expressions */
	ErrorCallback ErrorOut; /* Callback function for errors */
	void*         Instance; /* Instance handle for error callback */
	wchar_t*      CurrentFile;   /* Current filename or NULL */
	int           CurrentLineNo; /* Position within current file */
	int           Errors;   /* Number of errors found reading file */
} EXPFILE;


EXPFILE*   ExpCreate             (void);
void       ExpDelete             (EXPFILE* expfile);
void       ExpAddSingleExpression(EXPFILE* expfile, const wchar_t* name,
                                  const wchar_t* expr, const wchar_t* errmsg,
                                  int expcombine, ErrorCallback error,
                                  void* instance);
int        ExpAddFile            (EXPFILE* expfile, const wchar_t* filename,
                                  ErrorCallback error, void* instance);
int        ExpHasExpression      (EXPFILE* expfile, const wchar_t* name);
int        ExpGetExpressionSize  (EXPFILE* expfile, const wchar_t* name);
wchar_t*   ExpGetExpressionData  (EXPFILE* expfile, const wchar_t* name, wchar_t* buffer);
wchar_t*   ExpGetExpressionError (EXPFILE* expfile, const wchar_t* name);
int        ExpMatch              (EXPFILE* expfile, const wchar_t* name, const wchar_t* string);

void       ExpSetCurrentFileName (EXPFILE* expfile, const wchar_t* filename);
void       ExpSetCurrentFilePos  (EXPFILE* expfile, int lineno);

#endif
