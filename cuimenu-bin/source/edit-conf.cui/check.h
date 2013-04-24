/* ---------------------------------------------------------------------
 * File: check.h
 * (read check files for Eis/Fair)
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

#ifndef CHECK_H
#define CHECK_H

#include "global.h"
#include "cui-char.h"

#define CHECK_IDENT           100
#define CHECK_STRING          101
#define CHECK_OPT_ELEM        102
#define CHECK_OPT_ARRAY_ELEM  103
#define CHECK_REGEXP          104
#define CHECK_HYPHEN          105
#define CHECK_INVERT          106
#define CHECK_EQUAL           107
#define CHECK_COLON           108
#define CHECK_EOF             109
#define CHECK_NL              110
#define CHECK_UNKNOWN         200

int  CheckFileOpen(const wchar_t* filename, ErrorCallback errout, void* instance);
int  CheckRead(void);
void CheckClose(void);

wchar_t*       CheckGetTextDup(void);
const wchar_t* CheckGetTextCpy(wchar_t* buffer, int buflen);
wchar_t*       CheckGetStringDup(void);
const wchar_t* CheckGetFileName(void);
int            CheckGetLineNumber(void);
int            CheckRecoverFromError(void);

#endif

