/* ---------------------------------------------------------------------
 * File: pagerfile.c
 * (file IO routines for large files)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: pagerfile.c 33481 2013-04-15 17:48:41Z dv $
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

#include "pagerfile.h"

#define BUFHASH(blk) ((blk) & (BUFHASH_SIZE-1))

static int  PagerFileReadBlock(PAGERFILE* pfile);
static long PagerFileGetSize(PAGERFILE* pfile);
static int  PagerFileExpandLinebuf(PAGERFILE* pfile);

/* ---------------------------------------------------------------------
 * PagerFileOpen
 * Open a pager file
 * ---------------------------------------------------------------------
 */
PAGERFILE* 
PagerFileOpen(const wchar_t* filename, const wchar_t *encoding)
{
	FILE* in = FileOpen(filename, _T("rt"));
	if (in)
	{
		PAGERFILE* pfile = (PAGERFILE*) malloc(sizeof(PAGERFILE));
		if (pfile)
		{
			pfile->FileStream = in;
			pfile->FilePos = NOPOS;
			pfile->FileBlock = 0;
			pfile->FirstBlock = NULL;
			pfile->BlockOffset = 0;
			pfile->FileSize = PagerFileGetSize(pfile);
			pfile->LineBuffer = (char*) malloc((LINEBUFSIZE + 1) * sizeof(char));
			pfile->LineBufferSize = LINEBUFSIZE;
			pfile->WcLineBuffer = NULL;
			pfile->WcLineBufferSize = 0;
			pfile->IConvHandle = (iconv_t) -1;
			
			/* try to initialize codec for selected text encoding. If this fails,
			   the system default configuration is used, since iconv_open returns
			   NULL */
			if (wcslen(encoding) > 0)
			{
				char *tmpstr = TCharToMbDup(encoding);
				if (tmpstr)
				{
					pfile->IConvHandle = iconv_open ("UCS-4LE", tmpstr);
					free(tmpstr);
				}
			}

			if (pfile->FileSize < 0)
			{
				PagerFileClose(pfile);
				pfile = NULL;
			}
		}
		return pfile;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * PagerFileClose
 * Close a pager file and free data
 * ---------------------------------------------------------------------
 */
void 
PagerFileClose(PAGERFILE* pfile)
{
	PAGERBLOCK* pblock = pfile->FirstBlock;
	while (pblock)
	{
		pfile->FirstBlock = (PAGERBLOCK*) pblock->Next;
		free(pblock->Data);
		free(pblock);
		pblock = pfile->FirstBlock;
	}
	if (pfile->WcLineBuffer)
	{
		free(pfile->WcLineBuffer);
	}
	
	if (pfile->FileStream)
	{
		fclose(pfile->FileStream);
	}
	if ( pfile->IConvHandle != ((iconv_t)-1))
	{
		iconv_close(pfile->IConvHandle);
	}
	
	free(pfile->LineBuffer);
	free(pfile);
}

/* ---------------------------------------------------------------------
 * PagerFileGetF
 * Get a single character from the file stream. Don't use this 
 * function directly, use macro PagerFileGet instead
 * ---------------------------------------------------------------------
 */
int 
PagerFileGetF(PAGERFILE* pfile)
{
	PAGERBLOCK* pblock = pfile->FirstBlock;
	PAGERBLOCK* plast = NULL;
	int num = 0;

	while (pblock)
	{
		if (pfile->FileBlock == pblock->BlockNr)
		{
			if (pblock != pfile->FirstBlock)
			{
				if (pblock->Previous)
				{
					((PAGERBLOCK*) pblock->Previous)->Next = pblock->Next;
				}
				if (pblock->Next)
				{
					((PAGERBLOCK*) pblock->Next)->Previous = pblock->Previous;
				}
				pblock->Previous = NULL;
				pblock->Next = pfile->FirstBlock;

				pfile->FirstBlock->Previous = pblock;
				pfile->FirstBlock = pblock;
			}
			break;
		}
		num++;
		plast = pblock;
		pblock = (PAGERBLOCK*) pblock->Next;
	}
	if (!pblock)
	{
		if (num >= MAX_BLOCKS)
		{
			pblock = plast;
			if (pblock->Previous)
			{
				((PAGERBLOCK*) pblock->Previous)->Next = pblock->Next;
			}
		}
		else
		{
			pblock = (PAGERBLOCK*) malloc(sizeof(PAGERBLOCK));
			pblock->Data = (unsigned char*) malloc(PAGE_BLOCKSIZE);
		}

		pblock->BlockNr  = pfile->FileBlock;
		pblock->DataSize = 0;
		pblock->Previous = NULL;
		pblock->Next     = pfile->FirstBlock;

		if (pfile->FirstBlock)
		{
			pfile->FirstBlock->Previous = pblock;
		}
		pfile->FirstBlock = pblock;
	}

	if (pfile->FirstBlock->DataSize <= pfile->BlockOffset)
	{
		if (!PagerFileReadBlock(pfile))
		{
			return EOI;
		}
	}

	if (pfile->BlockOffset < pfile->FirstBlock->DataSize)
	{
		return pfile->FirstBlock->Data[pfile->BlockOffset];
	}
	else
	{
		return EOI;
	}
}

/* ---------------------------------------------------------------------
 * PagerFileForwGet
 * Get character and increment read location
 * ---------------------------------------------------------------------
 */
int 
PagerFileForwGet(PAGERFILE* pfile)
{
	register int c;

	c = PagerFileGet(pfile);
	if (c == EOI)
	{
		return (EOI);
	}
	if (pfile->BlockOffset < (PAGE_BLOCKSIZE - 1))
	{
		pfile->BlockOffset++;
	}
	else
	{
		pfile->FileBlock++;
		pfile->BlockOffset = 0;
	}
	return (c);
}

/* ---------------------------------------------------------------------
 * PagerFileBackGet
 * Decrement read location and get character
 * ---------------------------------------------------------------------
 */
int 
PagerFileBackGet(PAGERFILE* pfile)
{
	if (pfile->BlockOffset > 0)
	{
		pfile->BlockOffset--;
	}
	else
	{
		if (pfile->FileBlock <= 0)
		{
			return EOI;
		}
		pfile->FileBlock--;
		pfile->BlockOffset = PAGE_BLOCKSIZE - 1;
	}
	return (PagerFileGet(pfile));
}

/* ---------------------------------------------------------------------
 * PagerFilePos
 * Get current read location
 * ---------------------------------------------------------------------
 */
long 
PagerFilePos(PAGERFILE* pfile)
{
	return pfile->FileBlock * PAGE_BLOCKSIZE + pfile->BlockOffset;
}

/* ---------------------------------------------------------------------
 * PagerFileSeek
 * Set the current read location
 * ---------------------------------------------------------------------
 */
int
PagerFileSeek(PAGERFILE* pfile, long pos)
{
	if ((pos >= 0) && (pos <= pfile->FileSize))
	{
		pfile->FileBlock = pos / PAGE_BLOCKSIZE;
		pfile->BlockOffset = pos % PAGE_BLOCKSIZE;
		return 0;
	}
	return (-1);
}

/* ---------------------------------------------------------------------
 * PagerForwRawLine
 * Read a line of text (raw line ending with \n) in the forward direction
 * ---------------------------------------------------------------------
 */
long
PagerForwRawLine(PAGERFILE* pfile, long pos, wchar_t** lbuffer)
{
	register int n;
	register int c;
	long new_pos;

	if ((pos == NOPOS) || 
	    (PagerFileSeek(pfile, pos) != 0) ||
	    ((c = PagerFileForwGet(pfile)) == EOI))
	{
		return NOPOS;
	}

	n = 0;
	for (;;)
	{
		if (c == '\n' || c == EOI)
		{
			new_pos = PagerFilePos(pfile);
			break;
		}
		if (n >= pfile->LineBufferSize)
		{
			if (!PagerFileExpandLinebuf(pfile))
			{
				/*
				 * Overflowed the input buffer.
				 * Pretend the line ended here.
				 */
				new_pos = PagerFilePos(pfile) - 1;
				break;
			}
		}
		pfile->LineBuffer[n++] = c;
		c = PagerFileForwGet(pfile);
	}
	pfile->LineBuffer[n] = '\0';
	if (lbuffer != NULL)
	{
		int len = strlen(pfile->LineBuffer) + 1;

		/* check length of line buffer */
		if ((len > pfile->WcLineBufferSize) || (!pfile->WcLineBuffer))
		{
			if (pfile->WcLineBuffer)
			{
				free(pfile->WcLineBuffer);
			}
			pfile->WcLineBuffer = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
			pfile->WcLineBufferSize = len;
		}
		
		/* convert string ... */
		if (pfile->IConvHandle != (iconv_t)-1)
		{
			char  *in  = (char*) pfile->LineBuffer;
			char  *out = (char*) pfile->WcLineBuffer;
			size_t inlen  = len;
			size_t outlen = (pfile->WcLineBufferSize * sizeof(wchar_t));
			
			/* ... using iconv with a specified encoding*/
			pfile->WcLineBuffer[0] = 0;
			iconv (
				pfile->IConvHandle, 
				&in,  &inlen, 
				&out, &outlen);
			if (outlen >= sizeof(wchar_t))
			{
				*((wchar_t*)out) = 0;
			}
		}
		else
		{
			const char *s = pfile->LineBuffer;
			
			/* ... using system settings */
			mbsrtowcs(pfile->WcLineBuffer, &s, len, NULL);
		}
		*lbuffer = pfile->WcLineBuffer;
	}
	return (new_pos);
}

/* ---------------------------------------------------------------------
 * PagerBackRawLine
 * Read a line of text (raw line ending with \n) in the backward direction
 * ---------------------------------------------------------------------
 */
long
PagerBackRawLine(PAGERFILE* pfile, long pos, wchar_t** lbuffer)
{
	register int n;
	register int c;
	long new_pos;

	if ((pos == NOPOS) || 
	    (pos < ZEROPOS) ||
	    (PagerFileSeek(pfile, pos - 1) != 0))
	{
		return NOPOS;
	}

	n = pfile->LineBufferSize;
	pfile->LineBuffer[n] = '\0';
	for (;;)
	{
		c = PagerFileBackGet(pfile);
		if (c == '\n')
		{
			new_pos = PagerFilePos(pfile) + 1;
			break;
		}
		if (c == EOI)
		{
			new_pos = ZEROPOS;
			break;
		}
		if (n <= 0)
		{
			int old_size_linebuf = pfile->LineBufferSize;
			char *fm;
			char *to;
			if (!PagerFileExpandLinebuf(pfile))
			{
				/*
				 * Overflowed the input buffer.
				 * Pretend the line ended here.
				 */
				new_pos = PagerFilePos(pfile) + 1;
				break;
			}
			/*
			 * Shift the data to the end of the new linebuf.
			 */
			for (fm = pfile->LineBuffer + old_size_linebuf,
			     to = pfile->LineBuffer + pfile->LineBufferSize;
			     fm >= pfile->LineBuffer;  fm--, to--)
			{
				*to = *fm;
			}
			n = pfile->LineBufferSize - old_size_linebuf;
		}
		pfile->LineBuffer[--n] = c;
	}
	if (lbuffer != NULL)
	{
		const char* s = &pfile->LineBuffer[n];
		int len = MbStrLen(s);
		
		if (len > pfile->WcLineBufferSize)
		{
			if (pfile->WcLineBuffer)
			{
				free(pfile->WcLineBuffer);
			}
			pfile->WcLineBuffer = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
			pfile->WcLineBufferSize = len;
		}
		
		/* TODO: convert text using specific encoding */
		mbsrtowcs(pfile->WcLineBuffer, &s, len + 1, NULL);
		*lbuffer = pfile->WcLineBuffer;
	}
	return (new_pos);
}



/* local helper functions */

/* ---------------------------------------------------------------------
 * PagerFileReadBlock
 * Read a block of data from the file
 * ---------------------------------------------------------------------
 */
static int
PagerFileReadBlock(PAGERFILE* pfile)
{
	struct stat info;
    long pos = pfile->FileBlock * PAGE_BLOCKSIZE + pfile->FirstBlock->DataSize;
	int n;

	if (pos != pfile->FilePos)
	{
		if (fseek(pfile->FileStream, pos, SEEK_SET) != 0)
		{
			return FALSE;
		}
		pfile->FilePos = pos;
	} 

    /* compare file size and force position change if size has changed */
	fstat(fileno(pfile->FileStream), &info);
	if (info.st_size != pfile->FileSize)
	{
		fseek(pfile->FileStream, 0, SEEK_END);
		if (fseek(pfile->FileStream, pos, SEEK_SET) != 0)
		{
			return FALSE;
		}
		pfile->FileSize = info.st_size;
	} 
	n = fread(&pfile->FirstBlock->Data[pfile->FirstBlock->DataSize], 1,
		PAGE_BLOCKSIZE - pfile->FirstBlock->DataSize, 
		pfile->FileStream);
		
	if (n < 0)
	{
		return FALSE;
	}
	else
	{
		pfile->FirstBlock->DataSize += n;
		pfile->FilePos += n;

		if (pfile->FilePos > pfile->FileSize)
		{
			pfile->FileSize = pfile->FilePos;
		}
		return TRUE;
	}
}

/* ---------------------------------------------------------------------
 * PagerFileGetSize
 * Get the file's size
 * ---------------------------------------------------------------------
 */
static long
PagerFileGetSize(PAGERFILE* pfile)
{
	if (fseek(pfile->FileStream, 0, SEEK_END) == 0)
	{
		return ftell(pfile->FileStream);
	}
	return -1;
}

/* ---------------------------------------------------------------------
 * PagerFileExpandLinebuf
 * Expand the input buffer for line reading
 * ---------------------------------------------------------------------
 */
static int
PagerFileExpandLinebuf(PAGERFILE* pfile)
{
	char* newbuf;

	if (pfile->LineBufferSize + LINEBUFSIZE > MAX_LINEBUF)
	{
		return FALSE;
	}

	newbuf = (char*) malloc((pfile->LineBufferSize + LINEBUFSIZE + 1) * sizeof(char));
	if (!newbuf)
	{
		return FALSE;
	}

	memcpy(newbuf, pfile->LineBuffer, pfile->LineBufferSize);
	free(pfile->LineBuffer);

	pfile->LineBuffer = newbuf;
	pfile->LineBufferSize += LINEBUFSIZE;

	return TRUE;
}

