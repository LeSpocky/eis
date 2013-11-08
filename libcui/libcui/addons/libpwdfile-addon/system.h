/* ---------------------------------------------------------------------
 * File: system.h
 *
 * Copyright (C) 2009
 * Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: system.h 33397 2013-04-02 20:48:05Z dv $
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

#ifndef SYSTEN_H
#define SYSTEM_H

#include "chartools.h"

typedef struct
{
	wchar_t* UserName;
	wchar_t* Password;
	void*  Next;
} PASSWD_T;

void             SysFreePasswdList (PASSWD_T* passwds);
PASSWD_T*        SysReadPasswdList (char* passwdfile );

#endif

