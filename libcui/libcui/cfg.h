/* ---------------------------------------------------------------------
 * File: cfg.h
 * (read config files for Eis/Fair)
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

#ifndef CFG_H
#define CFG_H

#include "global.h"
#include "cui-char.h"

#define CFG_IDENT           100
#define CFG_LINE_COMMENT    103
#define CFG_COMMENT         104
#define CFG_STRING          105
#define CFG_EQUAL           106
#define CFG_EOF             108
#define CFG_NL              109
#define CFG_UNKNOWN         110

int  CfgFileOpen(const TCHAR* filename, ErrorCallback errout, void* instance);
int  CfgRead(void);
void CfgClose(void);

const TCHAR* CfgGetFileName(void);
const TCHAR* CfgGetComment(void);
TCHAR*       CfgGetTextDup(void);
TCHAR*       CfgGetStringDup(void);
int          CfgGetLineNumber(void);
int          CfgRecoverFromError(void);

#endif
