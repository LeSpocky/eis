/* ---------------------------------------------------------------------
 * File: pagerview.c
 * (pager view window)
 *
 * Copyright (C) 2004
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

#ifndef PAGERVIEW_H
#define PAGERVIEW_H

#include <cui.h>

CUIWINDOW* PagerviewNew(CUIWINDOW *parent, const wchar_t *text,
                   int x, int y, int w, int h, int id, int sflags, int cflags);
void PagerviewSetSetFocusHook  (CUIWINDOW *win, CustomHook1PtrProc proc, CUIWINDOW *target);
void PagerviewSetKillFocusHook (CUIWINDOW *win, CustomHookProc proc, CUIWINDOW *target);
void PagerviewSetPreKeyHook    (CUIWINDOW *win, CustomBoolHook1IntProc proc, CUIWINDOW *target);
void PagerviewSetPostKeyHook   (CUIWINDOW *win, CustomBoolHook1IntProc proc, CUIWINDOW *target);
void PagerviewClear            (CUIWINDOW *win);
int  PagerviewSetFile          (CUIWINDOW *win, const wchar_t *filename, const wchar_t *encoding);
int  PagerviewSearch           (CUIWINDOW *win, const wchar_t *text, int wholeword, int casesens, int down);
void PagerviewResetSearch      (CUIWINDOW *win, int at_bottom);
void PagerviewEnableTail       (CUIWINDOW *win, int enable);
long PagerviewResolveLine      (CUIWINDOW *win, int linenr);
void PagerviewJumpTo           (CUIWINDOW *win, long filepos);
void PagerviewSetFilter        (CUIWINDOW *win, const wchar_t *filter);

#endif
