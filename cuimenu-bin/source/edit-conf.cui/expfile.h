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
	TCHAR*  Name;            /* Name of the expression */
	TCHAR*  Expression;      /* Buffer containing the expression */
	TCHAR*  ErrorMsg;        /* Buffer containing the error message */
	int     Extentable;      /* Is this entry extentable? */
	void*   Next;
} EXPENTRY;


typedef struct EXPFILEStruct
{
	EXPENTRY*     FirstExp; /* First Expression in the list of expressions */
	ErrorCallback ErrorOut; /* Callback function for errors */
	void*         Instance; /* Instance handle for error callback */
	TCHAR*        CurrentFile;   /* Current filename or NULL */
	int           CurrentLineNo; /* Position within current file */
	int           Errors;   /* Number of errors found reading file */
} EXPFILE;


EXPFILE*   ExpCreate             (void);
void       ExpDelete             (EXPFILE* expfile);
void       ExpAddSingleExpression(EXPFILE* expfile, const TCHAR* name,
                                  const TCHAR* expr, const TCHAR* errmsg,
                                  int expcombine, ErrorCallback error,
                                  void* instance);
int        ExpAddFile            (EXPFILE* expfile, const TCHAR* filename,
                                  ErrorCallback error, void* instance);
int        ExpHasExpression      (EXPFILE* expfile, const TCHAR* name);
int        ExpGetExpressionSize  (EXPFILE* expfile, const TCHAR* name);
TCHAR*     ExpGetExpressionData  (EXPFILE* expfile, const TCHAR* name, TCHAR* buffer);
TCHAR*     ExpGetExpressionError (EXPFILE* expfile, const TCHAR* name);
int        ExpMatch              (EXPFILE* expfile, const TCHAR* name, const TCHAR* string);

void       ExpSetCurrentFileName (EXPFILE* expfile, const TCHAR* filename);
void       ExpSetCurrentFilePos  (EXPFILE* expfile, int lineno);

#endif
