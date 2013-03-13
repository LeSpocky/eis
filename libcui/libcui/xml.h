/* ---------------------------------------------------------------------
 * File: xml.h
 * (read Eis/Fair xml like files)
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

#ifndef XML_H
#define XML_H

#include "global.h"


#define XML_IDENT           100
#define XML_STRING          101
#define XML_EQUAL           102
#define XML_TAGOPEN         103
#define XML_TAGCLOSE        104
#define XML_COMMENTOPEN     105
#define XML_COMMENTCLOSE    106
#define XML_HEADEROPEN      107
#define XML_HEADERCLOSE     108
#define XML_DIVIDE          109
#define XML_EOF             110
#define XML_UNKNOWN         111


int  XmlFileOpen(const TCHAR* filename, ErrorCallback errout, void* instance);
int  XmlRead(void);
void XmlClose(void);
void XmlParseNL(int state);

const TCHAR* XmlGetFileName(void);
TCHAR*       XmlGetTextDup(void);
TCHAR*       XmlGetStringDup(void);
const TCHAR* XmlGetDataBuf(void);
void         XmlClearData(void);
int          XmlGetLineNumber(void);
int          XmlRecoverFromError(int nextsym);

#endif
