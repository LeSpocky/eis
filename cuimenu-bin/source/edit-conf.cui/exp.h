/* ---------------------------------------------------------------------
 * File: exp.h
 * (read regular expressions Eis/Fair)
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

#ifndef EXP_H
#define EXP_H

#include "global.h"
#include "cui-char.h"

#define EXP_IDENT           100
#define EXP_STRING          101
#define EXP_MLSTRING        102
#define EXP_COLON           103
#define EXP_ADD             104
#define EXP_EQUAL           106
#define EXP_EOF             108
#define EXP_NL              109
#define EXP_UNKNOWN         110

int  ExpFileOpen(const TCHAR* filename, ErrorCallback errout, void* instance);
int  ExpRead(void);
void ExpClose(void);

TCHAR*       ExpGetTextDup(void);
const TCHAR* ExpGetTextCpy(TCHAR* buffer, int buflen);
const TCHAR* ExpGetFileName(void);
const TCHAR* ExpGetString(void);
int          ExpGetLineNumber(void);
int          ExpRecoverFromError(void);

#endif
