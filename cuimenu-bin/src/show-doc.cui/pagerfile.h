/* ---------------------------------------------------------------------
 * File: pagerfile.h
 * (file IO routines for large files)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: pagerfile.h 23498 2010-03-14 21:57:47Z dv $
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

#ifndef PAGERFILE_H
#define PAGERFILE_H

#include "global.h"

#define	MAX_BLOCKS	32
#define PAGE_BLOCKSIZE  8192
#define MAX_LINEBUF     8192
#define LINEBUFSIZE     256
#define	EOI		(-1)
#define NOPOS           (-1)
#define ZEROPOS         (long)0

typedef struct
{
	unsigned char* Data;
	long           DataSize;
	long           BlockNr;
	void*          Next;
	void*          Previous;
} PAGERBLOCK;


typedef struct
{
	FILE*          FileStream;
	long           FileSize;
	long           FilePos;
	long           FileBlock;
	int            BlockOffset;
	PAGERBLOCK*    FirstBlock;
	TCHAR*         WcLineBuffer;
	int            WcLineBufferSize;
	char*          LineBuffer;
	int            LineBufferSize;
} PAGERFILE;


#define	PagerFileGet(pfile) \
	((pfile->FirstBlock && (pfile->FileBlock == pfile->FirstBlock->BlockNr) && \
	  pfile->BlockOffset < pfile->FirstBlock->DataSize) ? \
	  pfile->FirstBlock->Data[pfile->BlockOffset] : PagerFileGetF(pfile))

PAGERFILE* PagerFileOpen(const TCHAR* filename);
void       PagerFileClose(PAGERFILE* pfile);
int        PagerFileGetF(PAGERFILE* pfile);
int        PagerFileForwGet(PAGERFILE* pfile);
int        PagerFileBackGet(PAGERFILE* pfile);
long       PagerFilePos(PAGERFILE* pfile);
int        PagerFileSeek(PAGERFILE* pfile, long pos);
long       PagerForwRawLine(PAGERFILE* pfile, long pos, TCHAR** lbuffer);
long       PagerBackRawLine(PAGERFILE* pfile, long pos, TCHAR** lbuffer);

#endif
