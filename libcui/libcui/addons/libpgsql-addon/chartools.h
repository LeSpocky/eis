/* ---------------------------------------------------------------------
 * File: chartools.h
 * (helper routines for character string management)
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: chartools.h 23497 2010-03-14 21:53:08Z dv $
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

#ifndef CHARTOOLS_H
#define CHARTOOLS_H

#include <cui-char.h>

int    ModuleMbStrLen(const char* str);
int    ModuleMbByteLen(const TCHAR* str);
TCHAR* ModuleMbToTCharDup(const char*  str);
char*  ModuleTCharToMbDup(const TCHAR* str);

#endif
