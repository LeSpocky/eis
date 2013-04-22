/* ---------------------------------------------------------------------
 * File: confview.h
 * (config edit view)
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

#ifndef CONFVIEW_H
#define CONFVIEW_H

#include <cui.h>
#include "conffile.h"

CUIWINDOW* ConfviewNew(CUIWINDOW* parent, const TCHAR* text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void ConfviewSetSetFocusHook  (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target);
void ConfviewSetKillFocusHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ConfviewSetPreKeyHook    (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ConfviewSetPostKeyHook   (CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target);
void ConfviewSetLbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);
void ConfviewSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target);
void ConfviewSetLbClickedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target);

void ConfviewSetData          (CUIWINDOW* win, CONFFILE* confdata);
void ConfviewUpdateData       (CUIWINDOW* win);
int  ConfviewGetSel           (CUIWINDOW* win);
void ConfviewSetSel           (CUIWINDOW* win, int selindex);
void ConfviewToggleDrag       (CUIWINDOW* win);
void ConfviewToggleOptView    (CUIWINDOW* win);
int  ConfviewIsInDrag         (CUIWINDOW* win);

int  ConfviewSearch(CUIWINDOW* win, const TCHAR* text, int wholeword, int casesens, int down);


#endif

