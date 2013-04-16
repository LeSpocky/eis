/* ---------------------------------------------------------------------
 * File: cui-char.h
 * (Header file for libcui - char definitions and macros)
 *
 * Copyright (C) 2007
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

#ifndef CUI_CHAR_H
#define CUI_CHAR_H

#include <wchar.h>
#include <wctype.h>
#define TEXT(s) L##s
#define _T(s) L##s

#define MOVEYX   wmove
#define PRINT    waddwstr
#define PRINTN   waddnwstr
#define PRINTC   wadd_wch
    
#endif


