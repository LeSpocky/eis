/* ---------------------------------------------------------------------
 * File: filetools.h
 * (file and directory lsiting tools)
 *
 * Copyright (C) 2004
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
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

#ifndef FILETOOLS_H
#define FILETOOLS_H

int         ToolsPmatch(char *express, char *text);

int         safe_copy( char **dest, const char *source, int nsize);

int         ToolsFileExists(const char* filename);
const char* ToolsGetBasename(const char* name);
const char* ToolsGetDirname(const char* name);
int         ToolsCreateFile( char* filename, char* sdata );
int         ToolsAppendFile( char* filename, char* sdata );
char*       ToolStrCat(char* pstr, char* pstr2);

#endif
