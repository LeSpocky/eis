/* ---------------------------------------------------------------------
 * File: shelldlg.h
 * (shell execution dialog)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: shelldlg.h 42959 2016-08-22 07:50:22Z dv $
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

#ifndef SHELLDLG_H
#define SHELLDLG_H

#include "global.h"

typedef struct
{
	wchar_t *pCommand;
	wchar_t *pTitle;
	int      DoAutoClose;
	int      ExitCode;
} SHELLDLGDATA;


CUIWINDOW* ShellDlgNew(CUIWINDOW* parent, CUIRECT* rc, int sflags, int cflags);
SHELLDLGDATA* ShellDlgGetData(CUIWINDOW* win);

#endif

