/* ---------------------------------------------------------------------
 * File: createdlg.h
 * (create dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: createdlg.h 23498 2010-03-14 21:57:47Z dv $
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

#ifndef CREATEDLG_H
#define CREATEDLG_H

#include <cui.h>
#include "conffile.h"

#define MAX_ITEM_SIZE 128

typedef struct
{
	TCHAR     Name[MAX_ITEM_SIZE + 1];
	CONFFILE* ConfData;
} CREATEDLGDATA;

CUIWINDOW* CreatedlgNew(CUIWINDOW* parent, const TCHAR* title, int sflags, int cflags);
CREATEDLGDATA* CreatedlgGetData(CUIWINDOW* win);

#endif
