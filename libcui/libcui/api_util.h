/* ---------------------------------------------------------------------
 * File: api_util.h
 * (controls script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api_util.h 33397 2013-04-02 20:48:05Z dv $
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
#ifndef API_UTIL_H
#define API_UTIL_H

#include "cui-script.h"
#include "cui-util.h"

typedef int (*ModuleInitProc)         (MODULEINIT_T* modinit);
typedef int (*ModuleExecFunctionProc) (int func_nr, int argc, const wchar_t* argv[]);
typedef int (*ModuleCloseProc)        (void);

typedef struct
{
	void*                  ModuleHandle;
	ModuleInitProc         ModuleInit;
	ModuleExecFunctionProc ModuleExecFunction;
	ModuleCloseProc        ModuleClose;
	void*                  Next;
} ADDON_MODULE;


void          AddonInit(void);
void          AddonClear(void);
ADDON_MODULE* AddonGetModule(int nr);


#define API_XMLREADTAG 500

void ApiXmlReadTag(int argc, const wchar_t* argv[]);

#define API_LOADADDON  999

void ApiLoadAddon(int argc, const wchar_t* argv[]);

#endif
