/* ---------------------------------------------------------------------
 * File: expfile.c
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

#include "global.h"
#include "expfile.h"
#include "exp.h"

#define DATAGROUTH  40

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

/* private prototypes */
static void ExpErrorMsg   (EXPFILE* expfile, const wchar_t* errmsg,
                           int is_warning);
static int  ExpValidateExpression(EXPFILE* expfile, const wchar_t* expr);
static int  ExpTestCompile       (EXPFILE* expfile, const wchar_t* name);
static EXPENTRY* ExpGetEntry     (EXPFILE* expfile, const wchar_t* name);
static void ExpGetReferenceName  (const wchar_t* expr, wchar_t* buffer, int bufsize);


/* public functions */

/* ---------------------------------------------------------------------
 * ExpCreate
 * Create a EXPFILE structure that will be used as a context handle
 * for all further parser functions
 * ---------------------------------------------------------------------
 */
EXPFILE*
ExpCreate()
{
	EXPFILE* expfile = (EXPFILE*) malloc(sizeof(EXPFILE));
	expfile->FirstExp = NULL;
	expfile->ErrorOut = NULL;
	expfile->Instance = NULL;
	expfile->CurrentFile = NULL;
	expfile->Errors = 0;

	return expfile;
}

/* ---------------------------------------------------------------------
 * ExpDelete
 * Delete the EXPFILE structure and all associated data
 * ---------------------------------------------------------------------
 */
void
ExpDelete(EXPFILE* expfile)
{
	EXPENTRY* workptr;

	if (!expfile) return;

	workptr = expfile->FirstExp;
	while (workptr)
	{
		expfile->FirstExp = workptr->Next;
		if (workptr->Name)       free (workptr->Name);
		if (workptr->Expression) free (workptr->Expression);
		if (workptr->ErrorMsg)   free (workptr->ErrorMsg);
		free (workptr);
		workptr = expfile->FirstExp;
	}
	free (expfile);
}

/* ---------------------------------------------------------------------
 * ExpAddSingleExpression
 * Verify and add an expression 'expr' to the expression list. Note
 * that 'errmsg' will be used as a message for the user when his data
 * violates the expression test
 * ---------------------------------------------------------------------
 */
void
ExpAddSingleExpression(EXPFILE* expfile, const wchar_t* name,
                       const wchar_t* expr, const wchar_t* errmsg,
                       int expcombine, ErrorCallback error,
                       void* instance)
{
	int replace = FALSE;
	EXPENTRY* newexp;
	EXPENTRY* orgexp;

	if (!expfile) return;

	if (!expfile->ErrorOut)
	{
		expfile->ErrorOut = error; /* assign error handler if necessary */
		expfile->Instance = instance;
		replace = TRUE;
	}

	/* verify expression */
	if (!ExpValidateExpression(expfile,expr))
	{
		if (replace)
		{
			expfile->ErrorOut = NULL;
			expfile->Instance = NULL;
		}
		return;
	}

	orgexp = ExpGetEntry(expfile, name);
	if (orgexp && !expcombine && !orgexp->Extentable)
	{
		ExpErrorMsg(expfile,_T("duplicate expression definition"),FALSE);
		if (replace)
		{
			expfile->ErrorOut = NULL;
			expfile->Instance = NULL;
		}
		return;
	}
	else if (orgexp)
	{
		wchar_t* oldexpr = orgexp->Expression;
		wchar_t* olderrmsg = orgexp->ErrorMsg;
		int   len = wcslen(oldexpr) + wcslen(expr) + 6;

		orgexp->Expression = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		swprintf(orgexp->Expression, len, _T("(%ls)|(%ls)"), oldexpr, expr);
		free(oldexpr);

		if (wcslen(errmsg) > 0)
		{
			len = wcslen(olderrmsg) + wcslen(errmsg) + 2;

			orgexp->ErrorMsg = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

			if (orgexp->Extentable && !expcombine)
			{
				swprintf(orgexp->ErrorMsg, len, _T("%ls %ls"), errmsg, olderrmsg);
			}
			else
			{
				swprintf(orgexp->ErrorMsg, len, _T("%ls %ls"), olderrmsg, errmsg);
			}
			free(olderrmsg);
		}

		if (orgexp->Extentable && !expcombine)
		{
			orgexp->Extentable = FALSE;
		}
	}
	else
	{
		/* add expression */
		newexp = (EXPENTRY*) malloc(sizeof(EXPENTRY));
		newexp->Name = wcsdup(name);
		newexp->Expression = wcsdup(expr);
		newexp->ErrorMsg = wcsdup(errmsg);
		newexp->Next = expfile->FirstExp;
		newexp->Extentable = expcombine;

		expfile->FirstExp = newexp;
	}

	/* test compile */
	ExpTestCompile(expfile, name);

	if (replace)
	{
		expfile->ErrorOut = NULL;
		expfile->Instance = NULL;
	}
}

/* ---------------------------------------------------------------------
 * ExpAddFile
 * Read the data from file 'filename' and add the found expressions to
 * the expression list in 'expfile'
 * ---------------------------------------------------------------------
 */
int
ExpAddFile(EXPFILE* expfile, const wchar_t* filename,
           ErrorCallback error, void * instance)
{
	int sym;

	if (!expfile) return FALSE;

	/* prepare scanner.... */
	expfile->ErrorOut = error;
	expfile->Instance = instance;

	/* set info data */
	ExpSetCurrentFileName(expfile, filename);
	ExpSetCurrentFilePos(expfile, 0);

	if (!ExpFileOpen(filename, error, instance))
	{
		ExpErrorMsg(expfile, _T("file not found"), FALSE);
		ExpSetCurrentFileName(expfile,NULL);
		expfile->ErrorOut = NULL;
		return FALSE;
	}

	/* read file */
	sym = ExpRead();
	while (sym != EXP_EOF)
	{
		int expcombine = FALSE;

		if (sym == EXP_ADD)
		{
			expcombine = TRUE;
			sym = ExpRead();
		}

		if (sym == EXP_IDENT)
		{
			wchar_t  expname[128 + 1];
			wchar_t* expr = NULL;
			wchar_t* errmsg = NULL;

			ExpGetTextCpy(expname, 128);

			sym = ExpRead();

			if (sym != EXP_EQUAL)
			{
				ExpErrorMsg(expfile, _T("missing '='"), FALSE);
				sym = ExpRecoverFromError();
			}
			else
			{
				sym = ExpRead();
				if (sym != EXP_STRING)
				{
					ExpErrorMsg(expfile, _T("missing string entry '''"),FALSE);
					sym = ExpRecoverFromError();
				}
				else
				{
					expr = wcsdup(ExpGetString());

					sym = ExpRead();
					if (sym != EXP_COLON)
					{
						ExpErrorMsg(expfile, _T("missing '''"),FALSE);
						sym = ExpRecoverFromError();
					}
					else
					{
						sym = ExpRead();
						if ((sym != EXP_STRING)&&(sym != EXP_MLSTRING))
						{
							ExpErrorMsg(expfile, _T("missing string entry '''"),FALSE);
							sym = ExpRecoverFromError();
						}
						else
						{
							errmsg = wcsdup(ExpGetString());

							ExpSetCurrentFilePos(expfile,ExpGetLineNumber());

							ExpAddSingleExpression(expfile,
							                       expname,
							                       expr,
							                       errmsg,
							                       expcombine,
							                       expfile->ErrorOut,
							                       expfile->Instance);

							sym = ExpRead();
						}
					}
				}
			}

			if (expr) free(expr);
			if (errmsg) free(errmsg);
		}
		else
		{
			ExpErrorMsg(expfile, _T("syntax error"), FALSE);
			sym = ExpRecoverFromError();
		}
	}

	ExpClose();
	ExpSetCurrentFileName(expfile,NULL);
	expfile->ErrorOut = NULL;

	return (expfile->Errors == 0);
}

/* ---------------------------------------------------------------------
 * ExpHasExpression
 * Does expression 'name' exist in the expression list?
 * ---------------------------------------------------------------------
 */
int
ExpHasExpression(EXPFILE* expfile, const wchar_t* name)
{
	return (ExpGetEntry(expfile, name) != NULL);
}

/* ---------------------------------------------------------------------
 * ExpGetExpressionSize
 * Calculate the buffer size needed to store the entire expression
 * with all RE:XXXX references recursively resolved
 * ---------------------------------------------------------------------
 */
int
ExpGetExpressionSize(EXPFILE* expfile, const wchar_t* name)
{
	int       size = 0;
	wchar_t*    pos;
	wchar_t*    oldpos = NULL;
	EXPENTRY* entry;

	if (!expfile) return 0;

	entry = ExpGetEntry(expfile,name);
	if (!entry) return 0;

	pos = wcsstr(entry->Expression, _T("RE:"));
	oldpos = entry->Expression;

	while (pos)
	{
		wchar_t tmpname[64 + 1];

		ExpGetReferenceName(pos + 3, tmpname, 64);

		size += (pos - oldpos);
		size += ExpGetExpressionSize(expfile, tmpname);

		pos += wcslen(tmpname) + 3;
		oldpos = pos;
		pos = wcsstr(pos, _T("RE:"));
	}
	size += wcslen(oldpos);

	return size;
}

/* ---------------------------------------------------------------------
 * ExpGetExpressionData
 * Store the data of an entire expression into 'buffer ' with all
 * RE:XXXX references recursively resolved. Notice that the buffer must
 * be large enought to take the data. Use 'ExpGetExpressionSize' to
 * calculate the size needed.
 * The function returns a pointer to the position in the buffer just
 * behind the last inserted character.
 * ---------------------------------------------------------------------
 */
wchar_t*
ExpGetExpressionData(EXPFILE* expfile, const wchar_t* name, wchar_t* buffer)
{
	wchar_t* pos;
	wchar_t* oldpos = NULL;
	wchar_t* bufpos = buffer;
	EXPENTRY* entry;

	if (!expfile) return bufpos;

	entry = ExpGetEntry(expfile,name);
	if (!entry) return bufpos;

	pos = wcsstr(entry->Expression, _T("RE:"));
	oldpos = entry->Expression;

	bufpos[0] = 0;
	while (pos)
	{
		wchar_t tmpname[64 + 1];

		ExpGetReferenceName(pos + 3, tmpname, 64);

		wcsncpy(bufpos, oldpos, (pos - oldpos));
		bufpos += (pos - oldpos);

		*bufpos = 0;

		bufpos = ExpGetExpressionData(expfile,tmpname,bufpos);

		pos += (wcslen(tmpname) + 3);
		oldpos = pos;
		pos = wcsstr(pos,_T("RE:"));
	}
	wcscat(bufpos,oldpos);
	bufpos += wcslen(oldpos);

	return bufpos;
}

/* ---------------------------------------------------------------------
 * ExpMatch
 * This function performs a test with the data in parameter 'string'
 * and returns REG_MATCH if 'string' matches the regular expression specified
 * with 'name'
 * ---------------------------------------------------------------------
 */
int
ExpMatch(EXPFILE* expfile, const wchar_t* name, const wchar_t* string)
{
	int result = EXP_ERROR;
	int size = ExpGetExpressionSize(expfile, name);
	if (size > 0)
	{
		regex_t expr;
		int     res;
		wchar_t*  data = (wchar_t*) malloc((size + 1 + 4) * sizeof(wchar_t));
		if (data)
		{
			wcscpy(data,_T("^("));
	                ExpGetExpressionData(expfile, name, &data[2]);
	                wcscat(data, _T(")$"));

			res = RegCompile(&expr, data, REG_EXTENDED | REG_NOSUB | REG_NEWLINE); 
			if (res == 0)
			{
				res = RegExec (&expr, string, 0, NULL, 0);
				result = (res != 0) ? EXP_NOMATCH : EXP_MATCH;
			}
			else
			{
				result = EXP_ERROR;
			}

			RegFree(&expr);
			free(data);
		}
	}
	return result;
}


/* ---------------------------------------------------------------------
 * ExpGetExpressionData
 * Store the data of an entire expression into 'buffer ' with all
 * RE:XXXX references recursively resolved. Notice that the buffer must
 * be large enought to take the data. Use 'ExpGetExpressionSize' to
 * calculate the size needed.
 * The function returns a pointer to the position in the buffer just
 * behind the last inserted character.
 * ---------------------------------------------------------------------
 */
wchar_t*
ExpGetExpressionError(EXPFILE* expfile, const wchar_t* name)
{
	EXPENTRY* entry;

	if (!expfile) return _T("");

	entry = ExpGetEntry(expfile,name);
	if (!entry)
	{
		return _T("");
	}
	else
	{
		return entry->ErrorMsg;
	}
}


/* ---------------------------------------------------------------------
 * ExpSetCurrentFileName
 * Assign the name of the file that is currently processed
 * ---------------------------------------------------------------------
 */
void
ExpSetCurrentFileName(EXPFILE* expfile, const wchar_t* filename)
{
	if (expfile->CurrentFile)
	{
		free(expfile->CurrentFile);
	}
	expfile->CurrentFile = filename ? wcsdup(filename) : NULL;
}


/* ---------------------------------------------------------------------
 * ExpSetCurrentFilePos
 * Update the line counter for the currently processed file (for error
 * messages)
 * ---------------------------------------------------------------------
 */
void
ExpSetCurrentFilePos(EXPFILE* expfile, int lineno)
{
	expfile->CurrentLineNo = lineno;
}



/* helper functions */

/* ---------------------------------------------------------------------
 * ExpErrorMsg
 * Is called whenever an error is encountered reading expression files
 * ---------------------------------------------------------------------
 */
static void
ExpErrorMsg(EXPFILE* expfile, const wchar_t* errmsg, int is_warning)
{
	if (expfile->ErrorOut)
	{
		if (expfile->CurrentFile)
		{
			expfile->ErrorOut(
				expfile->Instance,
				errmsg,
				expfile->CurrentFile,
				expfile->CurrentLineNo,
				is_warning);
		}
		else
		{
			expfile->ErrorOut(
				expfile->Instance,
				errmsg,
				_T(""),
				0,
				is_warning);
		}
	}
	expfile->Errors++;
}


/* ---------------------------------------------------------------------
 * ExpValidateExpression
 * Checks if expression 'expr' is valid and can be completely resolved.
 * ---------------------------------------------------------------------
 */
static int
ExpValidateExpression(EXPFILE* expfile, const wchar_t* expr)
{
	wchar_t* pos;

	/* resolve expression */
	pos = wcsstr(expr, _T("RE:"));
	while(pos)
	{
		wchar_t tmpname[64 + 1];
		ExpGetReferenceName(pos + 3, tmpname, 64);
		if (!ExpHasExpression(expfile, tmpname))
		{
			wchar_t errmsg[128 + 1];

			swprintf(errmsg, 128, _T("unable to resolve reference '%ls'"), tmpname);
			ExpErrorMsg(expfile, errmsg, FALSE);
			return FALSE;
		}

		pos += wcslen(tmpname) + 3;
		pos = wcsstr(pos, _T("RE:"));
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ExpTextCompile
 * Calls regcomp() to perform a syntax check of the regular expression
 * ---------------------------------------------------------------------
 */
static int
ExpTestCompile(EXPFILE* expfile, const wchar_t* name)
{
	int result = TRUE;

	/* compile an test */
	int size = ExpGetExpressionSize(expfile, name);
	if (size > 0)
	{
		regex_t expr;
		int     res;
		int     len = size + 1 + 4;

		wchar_t*  data = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
		if (data)
		{
			wcscpy(data, _T("^("));
	                ExpGetExpressionData(expfile, name, &data[2]);
	                wcscat(data, _T(")$"));

			res = RegCompile(&expr, data, REG_EXTENDED | REG_NOSUB | REG_NEWLINE);
			if (res != 0)
			{
				char   err_buf[256];
				wchar_t* err_msg;

				regerror (res, &expr, err_buf, 255);

				err_msg = MbToTCharDup(err_buf);
				if (err_msg)
				{
					ExpErrorMsg(expfile, err_msg, FALSE);
					free(err_msg);
				}
				result = FALSE;
			}

			RegFree(&expr);
			free(data);
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ExpGetEntry
 * Searches the list for an entry with the name 'name'. If the entry
 * can't be found, NULL is returned.
 * ---------------------------------------------------------------------
 */
static EXPENTRY*
ExpGetEntry   (EXPFILE* expfile, const wchar_t* name)
{
	EXPENTRY* workptr = expfile->FirstExp;

	const wchar_t* cmpname = name;

	if (wcsstr(name, _T("WARN_")) == name) cmpname += 5;  /* ignore "WARN_" prefix */

	while (workptr)
	{
		if (wcscasecmp(workptr->Name, cmpname) == 0)
		{
			return workptr;
		}
		workptr = (EXPENTRY*) workptr->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ExpGetReferenceName
 * Reads the name of the regular expression following "RE:"
 * ---------------------------------------------------------------------
 */
static void
ExpGetReferenceName(const wchar_t* expr, wchar_t* buffer, int bufsize)
{
	int len = 0;

	buffer[0] = 0;
	while ((*expr != 0) && (iswalpha(*expr) || iswdigit(*expr) || (*expr == _T('_'))))
	{
		if (len < (bufsize-1))
		{
			buffer[len++] = *expr;
			buffer[len] = 0;
		}
		expr++;
	}
}

