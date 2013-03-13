/* ---------------------------------------------------------------------
 * File: index.h
 * (simple table of contents)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: index.h 30935 2012-05-27 14:32:42Z dv $
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

#ifndef INDEX_H
#define INDEX_H

#include "global.h"


typedef struct
{
	TCHAR*         Description;
	int            Level;
	long           LineNumber;
	long           FilePosition;
	void*          Next;
	void*          Previous;
} INDEXENTRY;


typedef struct
{
	TCHAR         *Title;
	INDEXENTRY    *FirstEntry;
	INDEXENTRY    *LastEntry;
} INDEX;


INDEX*     IndexReadFile(const TCHAR* filename, ErrorCallback errout, void* instance);
void       IndexDelete(INDEX* index);

#endif
