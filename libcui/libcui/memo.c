/* ---------------------------------------------------------------------
 * File: memo.c
 * (multi line edit control for dialog windows)
 *
 * Copyright (C) 2006
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: edit.c 33402 2013-04-02 21:32:17Z dv $
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

#include "cui.h"
#include "global.h"

/* general options */
#define INCREMENT_SIZE   32                    /* text buffer increments */
#define WRAPLIMIT_MAX    512                   /* max/default word wrap limit */
#define SCROLL_STEP_X    8                     /* vertical scrolling increments */

/* flags for MemoUpdateVisCursor */
#define UF_NONE          0x00                  /* empty flag for cursor updates */
#define UF_SET_V_COLUMN  0x01                  /* move virtual column upon cursor updates */

/* struct holding a single paragraph that might extend over multiple lines */
typedef struct PARAStruct
{
	wchar_t                *pText;             /* pointer to text data */
	int                     Length;            /* number of characters in buffer */
	int                     BufferSize;        /* current buffer size */
	int                     NumLines;          /* number of visual lines */
	struct PARAStruct      *pPrev;             /* pointer to previous list item */
	struct PARAStruct      *pNext;             /* pointer to next list item */
} PARAGRAPH;

/* struct holding of data of a memo control instance */
typedef struct MEMODATAStruct
{
	int                     WordWrapLimit;     /* char limit for word wrap */
	int                     DoAutoWordWrap;    /* is word wrapping enabled */	
	CUISIZE                 VirtualSize;       /* virtual window rectangle */
	CUISIZE                 VisualSize;        /* visual window rectangle */
	CUIPOINT                LogicalCursor;     /* row / column position */
	int                     VirtualColumn;     /* virtual column position used */
	                                           /* for vertical scrolling */
	
	unsigned int            NumPara;           /* number of text paragraphs */
	PARAGRAPH              *pFirst;            /* pointer to first edit line */
	PARAGRAPH              *pLast;             /* pointer to first edit line */

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CustomHookProc          MemoChangedHook;   /* Custom callback */
	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*              MemoChangedTarget; /* Custom callback target */
} MEMODATA;


/* prototypes of local functions */
static wchar_t *wcsrcpy(wchar_t *dest, const wchar_t *source);

static void       MemoCalcTextPos      (CUIWINDOW* win);
static void       MemoAppendText       (MEMODATA  *data, const wchar_t *text, int len);
static void       MemoClearAllText     (MEMODATA  *data);
static void       MemoGetVisualCursor  (MEMODATA  *data, CUIPOINT *pCursor);
static void       MemoSetLogicalCursor (MEMODATA  *data, const CUIPOINT *pCursor);
static void       MemoUpdateScrollRange(CUIWINDOW *win);
static void       MemoUpdateScrollPos  (CUIWINDOW *win, CUIPOINT cursor);
static PARAGRAPH* MemoFindParagraph    (MEMODATA  *data, int index);
static void       MemoUpdateVisCursor  (CUIWINDOW *win, unsigned int flags);
static void       MemoAppendPara       (MEMODATA  *data, PARAGRAPH *para);
static void       MemoModify           (CUIWINDOW *win);

static PARAGRAPH* ParaNew              (void);
static void       ParaDelete           (PARAGRAPH *para);
static void       ParaLink             (PARAGRAPH *para, PARAGRAPH *insertpos);
static void       ParaUnlink           (PARAGRAPH *para);
static void       ParaInsertText       (PARAGRAPH *para, int pos, const wchar_t *text, int len);
static void       ParaAppendPara       (PARAGRAPH *para, PARAGRAPH *pappend);
static PARAGRAPH *ParaSplitPara        (PARAGRAPH *para, int pos);
static void       ParaDeleteText       (PARAGRAPH *para, int pos, int len);
static void       ParaRenderText       (PARAGRAPH *para, int width, CUISIZE *virtualSize);
static CUIPOINT   ParaGetVisualPos     (PARAGRAPH *para, int width, int colpos);
static int        ParaGetLogicalPos    (PARAGRAPH *para, int width, const CUIPOINT *pt);
static void       ParaShowText         (PARAGRAPH *para, CUIWINDOW *win, int offsX, int offsY, int widthX, int limit);
static void       ParaShowLine         (CUIWINDOW *win, const wchar_t *pText, int len, int width, int offs);


/* ---------------------------------------------------------------------
 * MemoNcPaintHook
 * Handle PAINT events by redrawing the non client area of memo control
 * ---------------------------------------------------------------------
 */
static void
MemoNcPaintHook(void* w, int size_x, int size_y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	int len;

	rc.W = size_x;
	rc.H = size_y;
	rc.X = 0;
	rc.Y = 0;

	if ((rc.W <= 0)||(rc.H <= 0)) 
	{
		return;
	}

	if (win->HasBorder)
	{
		box(win->Frame, 0, 0);
		if (win->HasVScroll && (size_y > 2))
		{
			WindowPaintVScroll(win, 1, size_y - 2);
		}
		if (win->HasHScroll && (size_x > 2))
		{
			WindowPaintHScroll(win, 1, size_x - 2);
		}
	}
	else 
	{
		if (win->HasVScroll && win->HasHScroll)
		{
			WindowPaintVScroll(win, 0, size_y - 2);
			WindowPaintHScroll(win, 0, size_x - 2);
			
			MOVEYX(win->Frame, size_y - 1, size_x - 1); 
			PRINT (win->Frame, _T(" "));		
		}
		else if (win->HasVScroll)
		{
			WindowPaintVScroll(win, 0, size_y - 1);
		}
		else if (win->HasHScroll)
		{
			WindowPaintHScroll(win, 0, size_x - 1);
		}
	}

	if (win->IsEnabled)
	{
		SetColor(win->Frame, win->Color.HilightColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Frame, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	if (!win->Text || (win->Text[0] == 0) || (!win->HasBorder)) 
	{
		return;
	}

	len = wcslen(win->Text);
	if (len > rc.W - 4)
	{
		len = rc.W - 4;
	}

	MOVEYX(win->Frame, 0, 2); PRINTN(win->Frame, win->Text, len);
	if (rc.W > 2)
	{
		MOVEYX(win->Frame, 0, 1);       PRINT(win->Frame, _T(" "));
		MOVEYX(win->Frame, 0, len + 2); PRINT(win->Frame, _T(" "));
	}
}


/* ---------------------------------------------------------------------
 * MemoPaintHook
 * Handle PAINT events by redrawing the edit control
 * ---------------------------------------------------------------------
 */
static void
MemoPaintHook(void* w)
{
	CUIWINDOW *win = (CUIWINDOW*) w;
	CUIRECT    rc;
	CUIPOINT   pt;
	MEMODATA  *data;
	PARAGRAPH *para;
	int        y;
	int        scrollX;
	int        scrollY;
		
	data = win->InstData;
	if (!data) 
	{
		return;
	}

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) 
	{
		return;
	}
	
	/* get scroll position */
	scrollX = WindowGetHScrollPos(win);
	scrollY = WindowGetVScrollPos(win);

	/* setup colors */
	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndSelColor, TRUE);
	}
	
	y    = 0;
	para = data->pFirst;
	while (para)
	{
		if (((y + para->NumLines) > scrollY) && 
		    (y < scrollY + data->VisualSize.Y))
		{
			ParaShowText(para, 
				win,
				scrollX, 
				y - scrollY, 
				data->VisualSize.X,
				data->WordWrapLimit);
		}
		
		y   += para->NumLines;
		para = para->pNext;
	}
	
	y -= scrollY;
	while (y < rc.H)
	{
		if (y >= 0)
		{
			MOVEYX(win->Win, y, 0);
			ParaShowLine(win, L"", 0, rc.W, 0);
		}
		y++;
	}
		
	MemoGetVisualCursor(data, &pt);
	WindowSetCursor(win, pt.X - scrollX, pt.Y - scrollY);
}

/* ---------------------------------------------------------------------
 * MemoSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int 
MemoSizeHook(void* w)
{
	MemoCalcTextPos((CUIWINDOW*) w);
	return TRUE;
}

/* ---------------------------------------------------------------------
 * MemoKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
MemoKeyHook(void* w, int key)
{
	CUIWINDOW *win = (CUIWINDOW*) w;
	MEMODATA  *data = (MEMODATA*) win->InstData;
	PARAGRAPH *para;
	CUIPOINT   cursor;
	
	if (!data) 
	{
		return FALSE;
	}
	
	if (win->IsEnabled)
	{
		/* if the key is processed by the custom callback hook, we
		   are over and done with it, else processing continues */
		if (data->PreKeyHook)
		{
			if (data->PreKeyHook(data->PreKeyTarget, win, key))
			{
				return TRUE;
			}
		}
	
		/* do key processing only if current cursor position is valid */
		para = MemoFindParagraph(data, data->LogicalCursor.Y);
		if (para)
		{
			switch(key)
			{
			case KEY_RIGHT:
				if (data->LogicalCursor.X < para->Length)
				{
					data->LogicalCursor.X++;
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
				}
				else if (para->pNext)
				{
					data->LogicalCursor.Y++;
					data->LogicalCursor.X = 0;

					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
				}
				return TRUE;
				
			case KEY_LEFT:
				if ((data->LogicalCursor.X > 0) && (para->Length > 0))
				{
					if (data->LogicalCursor.X >= para->Length)
					{
						data->LogicalCursor.X = para->Length;
					}
					data->LogicalCursor.X--;
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);					
				}
				else if (para->pPrev)
				{
					data->LogicalCursor.Y--;
					data->LogicalCursor.X = para->pPrev->Length;
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
				}
				return TRUE;

			case KEY_UP:
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
				if (cursor.Y > 0)
				{
					cursor.Y -= 1;
					cursor.X  = data->VirtualColumn;
					
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
					
					MemoUpdateVisCursor(win, UF_NONE);
				}
				else if (para->pPrev)
				{
					para = para->pPrev;
					
					cursor.Y  = para->NumLines - 1;
					cursor.X  = data->VirtualColumn;
					
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);	
					data->LogicalCursor.Y--;
					
					MemoUpdateVisCursor(win, UF_NONE);
				}
				return TRUE;

			case KEY_DOWN:
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
				if ((cursor.Y + 1) < para->NumLines)
				{
					cursor.Y += 1;
					cursor.X  = data->VirtualColumn;
					
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
					
					MemoUpdateVisCursor(win, UF_NONE);
				}
				else if (para->pNext)
				{
					para = para->pNext;

					cursor.Y  = 0;
					cursor.X  = data->VirtualColumn;
					
					data->LogicalCursor.Y++;
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
					
					MemoUpdateVisCursor(win, UF_NONE);
				}
				return TRUE;
				
			case KEY_HOME:
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
				if (cursor.X > 0)
				{
					cursor.X = 0;
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
										
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
				}
				return TRUE;
				
			case KEY_END:
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
				if (cursor.X < para->Length)
				{
					cursor.X = para->Length;
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);

					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
				}
				return TRUE;
				
			case KEY_PPAGE:
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
				if ((data->LogicalCursor.Y > 0) || (cursor.Y > 0))
				{
					int lines = data->VisualSize.Y;
					int scrollY = WindowGetVScrollPos(win);
					
					if ((para->pPrev) && ((lines - cursor.Y) >= 0))
					{
						lines -= cursor.Y + 1;
						para   = para->pPrev;
						data->LogicalCursor.Y--;
											
						while ((para->pPrev) && (lines >= para->NumLines))
						{
							data->LogicalCursor.Y--;
							lines -= para->NumLines;
							para   = para->pPrev;
						}
						
						cursor.Y = 0;
					}
					
					cursor.Y -= lines;
					cursor.X  = data->VirtualColumn;
					if (cursor.Y < 0)
					{
						cursor.Y = 0;
					}
				
					scrollY -= data->VisualSize.Y;
					if (scrollY < 0)
					{
						scrollY = 0;
						WindowSetVScrollPos(win, scrollY);
					}
					
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
					MemoUpdateVisCursor(win, UF_NONE);
				}
				return TRUE;

			case KEY_NPAGE:	
				cursor = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);				
				if (data->LogicalCursor.Y + 1 < (int)data->NumPara)
				{
					int lines   = data->VisualSize.Y;
					int scrollY = WindowGetVScrollPos(win);
					
					if ((para->pNext) && ((lines + cursor.Y) >= para->NumLines))
					{
						lines -= (para->NumLines - cursor.Y);
						para   = para->pNext;
						data->LogicalCursor.Y++;
						
						cursor.Y = 0;
											
						while ((para->pNext) && (lines >= para->NumLines))
						{
							data->LogicalCursor.Y++;
							lines -= para->NumLines;
							para   = para->pNext;
						}
					}
					
					cursor.Y += lines;
					cursor.X  = data->VirtualColumn;
					if (cursor.Y >= para->NumLines)
					{
						cursor.Y = (para->NumLines - 1);
					}
				
					scrollY += data->VisualSize.Y;
					if (scrollY > (data->VirtualSize.Y - data->VisualSize.Y))
					{
						scrollY = data->VirtualSize.Y - data->VisualSize.Y;
						WindowSetVScrollPos(win, scrollY);
					}
					
					data->LogicalCursor.X = ParaGetLogicalPos(para, data->WordWrapLimit, &cursor);
					MemoUpdateVisCursor(win, UF_NONE);
				}
				return TRUE;

			case KEY_BACKSPACE:
				if ((data->LogicalCursor.X > 0) && (para->Length > 0))
				{
					int lines = para->NumLines;
					CUISIZE virtualSize;
					
					/* limit cursor pos */
					if (data->LogicalCursor.X >= para->Length)
					{
						data->LogicalCursor.X = para->Length;
					}

					/* update logical cursor */
					data->LogicalCursor.X--;
					
					/* modify paragraph and re-render text */
					ParaDeleteText(para, data->LogicalCursor.X, 1);
					ParaRenderText(para, data->WordWrapLimit, &virtualSize);
					
					/* if lines did change, update total visual range */
					if (lines != para->NumLines)
					{
						data->VirtualSize.Y += (para->NumLines - lines);
						MemoUpdateScrollRange(win);
					}
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
					WindowInvalidate   (win);
					MemoModify         (win);
				}
				else if (para->pPrev)
				{
					CUISIZE    virtualSize;
					PARAGRAPH *prevpara;
					int        lines  = para->pPrev->NumLines;
					int        length = para->pPrev->Length;

					/* memorize prev paragraph */
					prevpara = para->pPrev;
					
					/* unlink paragraph and append*/
					ParaUnlink    (para);					
					ParaAppendPara(prevpara, para);

					/* update logical cursor */
					data->LogicalCursor.Y--;
					data->LogicalCursor.X = length;

					ParaRenderText(prevpara, data->WordWrapLimit, &virtualSize);					
					if (lines != prevpara->NumLines)
					{
						data->VirtualSize.Y += (prevpara->NumLines - lines);
						data->VirtualSize.Y -= para->NumLines;
						MemoUpdateScrollRange(win);
					}
					
					/* delete para */
					ParaDelete(para);
					data->NumPara--;
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
					WindowInvalidate   (win);
					MemoModify         (win);
				}
				return TRUE;
				
			case KEY_DC:
				if ((data->LogicalCursor.X < para->Length) && (para->Length > 0))
				{
					CUISIZE    virtualSize;
					int lines = para->NumLines;
					
					/* limit cursor pos */
					if (data->LogicalCursor.X >= para->Length)
					{
						data->LogicalCursor.X = para->Length;
					}

					/* modify paragraph and re-render text */
					ParaDeleteText(para, data->LogicalCursor.X, 1);
					ParaRenderText(para, data->WordWrapLimit, &virtualSize);
					
					/* if lines did change, update total visual range */
					if (lines != para->NumLines)
					{
						data->VirtualSize.Y += (para->NumLines - lines);
						MemoUpdateScrollRange(win);
					}
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
					WindowInvalidate   (win);
					MemoModify         (win);
				}
				else if (para->pNext)
				{
					PARAGRAPH *delpara;
					CUISIZE    virtualSize;
					int        lines  = para->NumLines;
					int        length = para->Length;
					
					/* memorize paragraph */
					delpara = para->pNext;

					/* unlink paragraph and append*/
					ParaUnlink    (delpara);
					ParaAppendPara(para, delpara);

					/* update logical cursor */
					data->LogicalCursor.X = length;

					ParaRenderText(para, data->WordWrapLimit, &virtualSize);
					if (lines != para->NumLines)
					{
						data->VirtualSize.Y += (para->NumLines - lines);
						data->VirtualSize.Y -= delpara->NumLines;
						MemoUpdateScrollRange(win);
					}
					
					/* delete para */
					ParaDelete(delpara);
					data->NumPara--;
					
					MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
					WindowInvalidate   (win);
					MemoModify         (win);
				}
				return TRUE;
				
			case KEY_RETURN:
				{
					int        lines = para->NumLines;
					PARAGRAPH *newpara;
					CUISIZE    virtualSize;
					
					/* limit cursor pos */
					if (data->LogicalCursor.X >= para->Length)
					{
						data->LogicalCursor.X = para->Length;
					}
					
					newpara = ParaSplitPara(para, data->LogicalCursor.X);
					if (newpara)
					{
						ParaLink(newpara, para);
						
						ParaRenderText(para, data->WordWrapLimit, &virtualSize);
						data->VirtualSize.Y += (para->NumLines - lines);
						
						ParaRenderText(newpara, data->WordWrapLimit, &virtualSize);
						data->VirtualSize.Y += newpara->NumLines;
						
						data->LogicalCursor.X = 0;
						data->LogicalCursor.Y++;
						
						MemoUpdateScrollRange(win);
						
						data->NumPara++;
						
						MemoUpdateVisCursor(win, UF_SET_V_COLUMN);
						WindowInvalidate   (win);
					}
					MemoModify(win);
				}
				return TRUE;

			default:
				if ((key >= ' ')&&(key <= 255))
				{
					CUISIZE virtualSize;
					int     lines   = para->NumLines;
					wchar_t text[2] = { L'\0', L'\0' };
					
					text[0] = key;
					ParaInsertText(para, data->LogicalCursor.X++, text, 1);
					ParaRenderText(para, data->WordWrapLimit, &virtualSize);
					
					if (lines != para->NumLines)
					{
						data->VirtualSize.Y += (para->NumLines - lines);
					}
					
					MemoUpdateScrollRange(win);
					MemoUpdateVisCursor  (win, UF_SET_V_COLUMN);
					WindowInvalidate     (win);
					MemoModify           (win);

					return TRUE;
				}

				if (data->PostKeyHook)
				{
					if (data->PostKeyHook(data->PostKeyTarget, win, key))
					{
						return TRUE;
					}
				}
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MemoMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
MemoMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW *win = (CUIWINDOW*) w;
	MEMODATA  *data = (MEMODATA*) win->InstData;
	CUIPOINT   pt;
	
	CUI_USE_ARG(flags);
	
	pt.X = x;
	pt.Y = y;
	
	MemoSetLogicalCursor(data, &pt);
	MemoUpdateVisCursor (win, UF_NONE);
}

/* ---------------------------------------------------------------------
 * MemoHScrollHook
 * Memo scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
MemoHScrollHook(void* w, int sbcode, int pos)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT rc;
	int sbpos, range;
	
	CUI_USE_ARG(pos);

	WindowGetClientRect(win, &rc);
	sbpos = WindowGetHScrollPos(win);
	range = WindowGetHScrollRange(win);

	switch(sbcode)
	{
	case SB_LINEUP:
		if (sbpos > 0)
		{
			WindowSetHScrollPos(win, sbpos - 1);
			WindowInvalidate(win);
		}
		break;
	case SB_LINEDOWN:
		if (sbpos < range)
		{
			WindowSetHScrollPos(win, sbpos + 1);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEUP:
		if (sbpos > 0)
		{
			sbpos -= (rc.W - 1);
			sbpos  = (sbpos < 0) ? 0 : sbpos;
			WindowSetHScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.W - 1);
			sbpos  = (sbpos > range) ? range : sbpos;
			WindowSetHScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_THUMBTRACK:
		WindowInvalidate(win);
		break;
	}
}

/* ---------------------------------------------------------------------
 * MemoVScrollHook
 * Memo scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
MemoVScrollHook(void* w, int sbcode, int pos)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT rc;
	int sbpos, range;
	
	CUI_USE_ARG(pos);

	WindowGetClientRect(win, &rc);
	sbpos = WindowGetVScrollPos(win);
	range = WindowGetVScrollRange(win);

	switch(sbcode)
	{
	case SB_LINEUP:
		if (sbpos > 0)
		{
			WindowSetVScrollPos(win, sbpos - 1);
			WindowInvalidate(win);
		}
		break;
	case SB_LINEDOWN:
		if (sbpos < range)
		{
			WindowSetVScrollPos(win, sbpos + 1);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEUP:
		if (sbpos > 0)
		{
			sbpos -= (rc.H - 1);
			sbpos  = (sbpos < 0) ? 0 : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.H - 1);
			sbpos  = (sbpos > range) ? range : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_THUMBTRACK:
		WindowInvalidate(win);
		break;
	}
}

/* ---------------------------------------------------------------------
 * DestroyMemoHook
 * Handle EVENT_DELETE events by deleting the edit's control data
 * ---------------------------------------------------------------------
 */
static void
MemoDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MEMODATA* data = (MEMODATA*) win->InstData;
	
	/* free paragraph data */
	MemoClearAllText(data);
	
	free(data);
}

/* ---------------------------------------------------------------------
 * MemoCreateHook
 * Handle EVENT_CREATE events
 * ---------------------------------------------------------------------
 */
static void
MemoCreateHook(void *w)
{
	MemoCalcTextPos((CUIWINDOW*) w);
}

/* ---------------------------------------------------------------------
 * MemoSetFocus
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
MemoSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MEMODATA*  data = (MEMODATA*) win->InstData;
	CUIPOINT   pt;

	if (data)
	{
		int scrollX = WindowGetHScrollPos(win);
		int scrollY = WindowGetVScrollPos(win);
		
		MemoGetVisualCursor(data, &pt);
		WindowSetCursor    (win, pt.X - scrollX, pt.Y - scrollY);	
		WindowCursorOn     ();

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * MemoKillFocus
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
MemoKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MEMODATA* data = (MEMODATA*) win->InstData;

	if (data)
	{
		WindowCursorOff();
		if (data->KillFocusHook)
		{
			data->KillFocusHook(data->KillFocusTarget, win);
		}
	}
}

/* ---------------------------------------------------------------------
 * MemoNew
 * Create a memo dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
MemoNew(CUIWINDOW* parent, const wchar_t* text,
	int x, int y, int w, int h,
	int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* memo;
		int flags = sflags | CWS_TABSTOP; // | CWS_BORDER;
		flags &= ~(cflags);

		memo = WindowNew(parent, x, y, w, h, flags);
		memo->Class = _T("MEMO");
		WindowSetId(memo, id);
		WindowSetNcPaintHook  (memo, MemoNcPaintHook);		
		WindowSetPaintHook    (memo, MemoPaintHook);
		WindowSetKeyHook      (memo, MemoKeyHook);
		WindowSetCreateHook   (memo, MemoCreateHook);
		WindowSetDestroyHook  (memo, MemoDestroyHook);
		WindowSetSetFocusHook (memo, MemoSetFocusHook);
		WindowSetKillFocusHook(memo, MemoKillFocusHook);
		WindowSetMButtonHook  (memo, MemoMButtonHook);
		WindowSetVScrollHook  (memo, MemoVScrollHook);
		WindowSetHScrollHook  (memo, MemoHScrollHook);
		WindowSetSizeHook     (memo, MemoSizeHook);
		

		WindowEnableVScroll(memo, TRUE);
		if ((flags & MF_AUTOWORDWRAP) == 0)
		{
			WindowEnableHScroll(memo, TRUE);
		}

		memo->InstData = (MEMODATA*) malloc(sizeof(MEMODATA));
		memset(memo->InstData, 0, sizeof(MEMODATA));
	
		if (flags & MF_AUTOWORDWRAP)
		{
			((MEMODATA*)memo->InstData)->DoAutoWordWrap = TRUE;
			((MEMODATA*)memo->InstData)->WordWrapLimit  = w;
		}
		else
		{
			((MEMODATA*)memo->InstData)->DoAutoWordWrap = FALSE;
			((MEMODATA*)memo->InstData)->WordWrapLimit  = WRAPLIMIT_MAX;
		}
		
		((MEMODATA*)memo->InstData)->LogicalCursor.X = 0;
		((MEMODATA*)memo->InstData)->LogicalCursor.Y = 0;
		((MEMODATA*)memo->InstData)->VirtualColumn   = 0;
		((MEMODATA*)memo->InstData)->SetFocusHook    = NULL;
		((MEMODATA*)memo->InstData)->KillFocusHook   = NULL;
		((MEMODATA*)memo->InstData)->PreKeyHook      = NULL;
		((MEMODATA*)memo->InstData)->PostKeyHook     = NULL;
		((MEMODATA*)memo->InstData)->MemoChangedHook = NULL;
		
		/* initialized empty editor window */
		((MEMODATA*)memo->InstData)->pFirst  = ParaNew();
		((MEMODATA*)memo->InstData)->pLast   = ((MEMODATA*)memo->InstData)->pFirst;
		((MEMODATA*)memo->InstData)->NumPara = 1;

		WindowSetText  (memo, text);
		MemoCalcTextPos(memo);

		return memo;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * MemoSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MemoSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		((MEMODATA*)win->InstData)->SetFocusHook   = proc;
		((MEMODATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MemoSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		((MEMODATA*)win->InstData)->KillFocusHook   = proc;
		((MEMODATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetPreKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MemoSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		((MEMODATA*)win->InstData)->PreKeyHook   = proc;
		((MEMODATA*)win->InstData)->PreKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetPostKeyHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MemoSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		((MEMODATA*)win->InstData)->PostKeyHook   = proc;
		((MEMODATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MemoSetChangedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		((MEMODATA*)win->InstData)->MemoChangedHook   = proc;
		((MEMODATA*)win->InstData)->MemoChangedTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetText
 * Set edit text
 * ---------------------------------------------------------------------
 */
void
MemoSetText(CUIWINDOW* win, const wchar_t* text)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		MEMODATA      *data = (MEMODATA*) win->InstData;
		const wchar_t *p1;
		const wchar_t *p2;
		
		/* first clear all existing text lines */
		MemoClearAllText(data);
		
		/* add new text lines line by line */
		p1 = text;
		p2 = wcschr(p1, _T('\n'));
		while (p2)
		{
			MemoAppendText(data, p1, p2 - p1);
			
			p1 = p2 + 1;
			p2 = wcschr(p1, _T('\n'));
		}
		
		MemoAppendText(data, p1, wcslen(p1));
				
		data->LogicalCursor.X = 0;
		data->LogicalCursor.Y = 0;
		data->VirtualColumn = 0;
		
		WindowSetHScrollPos(win, 0);
		WindowSetVScrollPos(win, 0);

		if (win->IsCreated)
		{
			MemoCalcTextPos(win);
			WindowInvalidate(win);
		}
	}
}

/* ---------------------------------------------------------------------
 * MemoGetText
 * Get edit text
 * ---------------------------------------------------------------------
 */
const wchar_t*
MemoGetText(CUIWINDOW* win, wchar_t* text, int len)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		MEMODATA  *data = (MEMODATA*) win->InstData;
		PARAGRAPH *para = data->pFirst;
		
		while (para && (len > 0))
		{
			if (para->pText)
			{
				int plen = para->Length;
				if (plen > len)
				{
					plen = len;
				}
				
				memcpy(text, para->pText, plen * sizeof(wchar_t));
				
				len  -= plen;
				text += plen;
			}
			
			if ((para->pNext) && (len > 0))
			{
				*(text++) = '\n';
				len--;
			}
			
			para = para->pNext;
		}
		
		if (len > 0)
		{
			*(text++) = '\0';
		}
		return text;
	}
	return _T("");
}

/* ---------------------------------------------------------------------
 * MemoGetTextBufSize
 * Return required size of text buffer to store text data in
 * ---------------------------------------------------------------------
 */
int MemoGetTextBufSize(CUIWINDOW* win)
{
	int result = 0;
	
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		MEMODATA  *data = (MEMODATA*) win->InstData;
		PARAGRAPH *para = data->pFirst;
		
		while (para)
		{
			result += (para->Length + 1);
			para = para->pNext;
		}
		
		/* zero termination */
		result++;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * MemoSetWrapColumns
 * Set limit for word wrapping if auto word wrap is not set!
 * ---------------------------------------------------------------------
 */
void MemoSetWrapColumns(CUIWINDOW* win, int cols)
{
	if (win && (wcscmp(win->Class, _T("MEMO")) == 0))
	{
		MEMODATA *data = (MEMODATA*) win->InstData;
		
		if (!data->DoAutoWordWrap)
		{
			data->WordWrapLimit = cols;

			if (win->IsCreated)
			{
				MemoCalcTextPos(win);
				WindowInvalidate(win);
			}
		}
	}
}


/* local helper functions */

/* ---------------------------------------------------------------------
 * MemoCalcTextPos
 * Recalculate scrolling area and text positions
 * ---------------------------------------------------------------------
 */
static void
MemoCalcTextPos(CUIWINDOW* win)
{
	MEMODATA  *data = (MEMODATA*) win->InstData;
	PARAGRAPH *para;
	CUIRECT    rc;
	CUIPOINT   cursor;

	if (!data) 
	{
		return;
	}
	
	if (win->IsCreated)
	{
		WindowGetClientRect(win, &rc);
		data->VisualSize.X = rc.W;
		data->VisualSize.Y = rc.H;
		
		if (data->DoAutoWordWrap)
		{
			data->WordWrapLimit = (data->VisualSize.X - 1);
		}

		/* initialize dimensions to zero */
		memset(&data->VirtualSize, 0, sizeof(data->VirtualSize));
		
		/* render text according to current control metrics */
		para = data->pFirst;
		while (para)
		{
			CUISIZE size;
			
			ParaRenderText(para, data->WordWrapLimit, &size);
			if (size.X > data->VirtualSize.X)
			{
				data->VirtualSize.X = size.X;
			}
			
			data->VirtualSize.Y += size.Y;
			
			para    = para->pNext;
		}
		
		data->VirtualSize.X = data->WordWrapLimit;

		MemoGetVisualCursor  (data, &cursor);		
		MemoUpdateScrollRange(win);
		MemoUpdateScrollPos  (win, cursor);
	}
}

/* ---------------------------------------------------------------------
 * MemoUpdateScrollRange
 * Check if virtual text size is larger than the visual text size and
 * update scroll ranges accordingly
 * ---------------------------------------------------------------------
 */
static void
MemoUpdateScrollRange(CUIWINDOW* win)
{
	MEMODATA  *data = (MEMODATA*) win->InstData;
	int        range;

	/* adjust vertical scroll bar range */
	range = data->VirtualSize.Y - data->VisualSize.Y;
	if (range < 0)
	{
		WindowSetVScrollRange(win, 0);
		WindowSetVScrollPos(win, 0);
	}
	else
	{
		WindowSetVScrollRange(win, range);
	}
	
	/* adjust horizontal scroll bar range */
	range = data->VirtualSize.X - data->VisualSize.X;
	if (range < 0)
	{
		WindowSetHScrollRange(win, 0);
		WindowSetHScrollPos(win, 0);
	}
	else
	{
		WindowSetHScrollRange(win, range);
	}	
}

/* ---------------------------------------------------------------------
 * MemoUpdateScrollPos
 * Check if the visual cursor is outside of the visual area of the window
 * and change scroll position to bring it back into the visual range if 
 * necessary.
 * ---------------------------------------------------------------------
 */
static void
MemoUpdateScrollPos(CUIWINDOW* win, CUIPOINT cursor)
{
	MEMODATA *data    = (MEMODATA*) win->InstData;
	int       scrollX = WindowGetHScrollPos(win);
	int       scrollY = WindowGetVScrollPos(win);
	
	if (data->VirtualSize.Y >= data->VisualSize.Y)
	{
		if (cursor.Y < scrollY)
		{
			scrollY = cursor.Y;
		}
		if (cursor.Y >= (scrollY + data->VisualSize.Y))
		{
			scrollY = (cursor.Y - data->VisualSize.Y + 1);
		}
	}
	else
	{
		scrollY = 0;		
	}	
	if (WindowGetVScrollPos(win) != scrollY)
	{
		WindowSetVScrollPos(win, scrollY);
		WindowInvalidate   (win);
	}	

	if (data->VirtualSize.X >= data->VisualSize.X)
	{
		if (cursor.X < scrollX)
		{
			scrollX = (cursor.X / SCROLL_STEP_X) * SCROLL_STEP_X;
			if (scrollX < 0)
			{
				scrollX = 0;
			}
		}
		if (cursor.X >= scrollX + data->VisualSize.X)
		{
			scrollX = ((cursor.X - data->VisualSize.X) / SCROLL_STEP_X + 1) * SCROLL_STEP_X;
			if (scrollX > data->VirtualSize.X)
			{
				scrollX = (cursor.X - data->VisualSize.X);
			}
		}		
	}
	else
	{
		scrollX = 0;
	}
	if (WindowGetHScrollPos(win) != scrollX)
	{
		WindowSetHScrollPos(win, scrollX);
		WindowInvalidate   (win);
	}
#if 0
	{
		FILE *out = fopen("/tmp/test.log", "at");
		if (out)
		{
			fprintf(out, "--------------------------------------------------\n");
			fprintf(out, "VirtSize (%d,%d) VisSize (%d,%d) LogCurs (%d,%d) VisCurs (%d,%d) Scroll (%d,%d / %d,%d) VirtCol %d\n", 
				data->VirtualSize.X, data->VirtualSize.Y,
				data->VisualSize.X, data->VisualSize.Y,
				data->LogicalCursor.X, data->LogicalCursor.Y,
				cursor.X, cursor.Y,
				data->ScrollPosX, data->ScrollPosY,
				WindowGetHScrollRange(win), WindowGetVScrollRange(win),
				data->VirtualColumn);
			fclose(out);
		}
	}
#endif
}

/* ---------------------------------------------------------------------
 * Append Paragraph
 * Append a single paragraph to 
 * ---------------------------------------------------------------------
 */
static void
MemoAppendText(MEMODATA* data, const wchar_t *text, int len)
{
	PARAGRAPH *para = ParaNew();
	if (para)
	{
		ParaInsertText(para, 0, text, len);
		MemoAppendPara(data, para);
	}
}

/* ---------------------------------------------------------------------
 * MemoGetVisualCursor
 * Take to logical cursor position and render it into a visual cursor.
 * The visual cursor is then returned within the parameter "pCursor"
 * ---------------------------------------------------------------------
 */
static void
MemoGetVisualCursor(MEMODATA* data, CUIPOINT *pCursor)
{
	PARAGRAPH *para = data->pFirst;
	int i;
	
	pCursor->Y = 0;
	
	for (i = 0; i < data->LogicalCursor.Y; i++)
	{
		if (para)
		{
			pCursor->Y += para->NumLines;
			para = para->pNext;
		}
	}
	
	if (para)
	{
		CUIPOINT pt;
		pt = ParaGetVisualPos(para, data->WordWrapLimit, data->LogicalCursor.X);
		
		pCursor->Y += pt.Y;
		pCursor->X  = pt.X;
	}
	else
	{
		pCursor->X = 0;
	}
}

/* ---------------------------------------------------------------------
 * MemoSetLogicalCursor
 * Take a visual cursor position and convert it into a logical cursor.
 * The logical cursor is then applied to the control
 * ---------------------------------------------------------------------
 */
static void
MemoSetLogicalCursor(MEMODATA *data, const CUIPOINT *pCursor)
{
	PARAGRAPH *para = data->pFirst;
	int y;
	
	data->LogicalCursor.Y = 0;
	data->LogicalCursor.X = 0;
	
	y = 0;
	while (para && (y + para->NumLines <= pCursor->Y))
	{
		data->LogicalCursor.Y++;
		y += para->NumLines;
		
		para = para->pNext;
	}
	
	if (para)
	{
		CUIPOINT pt;
		
		pt.X = pCursor->X;
		pt.Y = pCursor->Y - y;
			
		data->LogicalCursor.X = 
			ParaGetLogicalPos(para, data->WordWrapLimit, &pt);			
	}
	else
	{
		if (data->LogicalCursor.Y > 0)
		{
			data->LogicalCursor.Y -= 1;
		}
		data->LogicalCursor.X = 0;
	}
}

/* ---------------------------------------------------------------------
 * MemoClearAllText
 * Free all paragraphs actually present in the list of paragraphs and
 * initialized pointers to NULL
 * ---------------------------------------------------------------------
 */
static void
MemoClearAllText(MEMODATA* data)
{
	PARAGRAPH* para = data->pFirst;
	while (para)
	{
		PARAGRAPH* next = para->pNext;
		
		ParaDelete(para);
		
		para = next;
	}
	data->pFirst  = NULL;
	data->pLast   = NULL;
	data->NumPara = 0;
}

/* ---------------------------------------------------------------------
 * MemoFindParagraph
 * Take a logical paragraph index and deliver the correspondent paragraph
 * struct in return
 * ---------------------------------------------------------------------
 */
static PARAGRAPH*
MemoFindParagraph(MEMODATA* data, int index)
{
	PARAGRAPH* para = data->pFirst;
	int i = 0;
	
	while (para)
	{
		if (i == index)
		{
			return para;
		}
		i++;
		para = para->pNext;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * MemoUpdateVisCursor
 * This converts the logical cursor into a visual cursor and checks
 * scroll positions. Then the cursor is placed inside of the visual
 * window area according to the previously calculated results.
 * ---------------------------------------------------------------------
 */
static void
MemoUpdateVisCursor(CUIWINDOW *win, unsigned int flags)
{
	CUIPOINT   cursor;
	MEMODATA  *data = (MEMODATA*) win->InstData;
	
	MemoGetVisualCursor(data, &cursor);	
	MemoUpdateScrollPos(win, cursor);
	
	WindowSetCursor(win, 
		cursor.X - WindowGetHScrollPos(win), 
		cursor.Y - WindowGetVScrollPos(win));
		
	if (flags & UF_SET_V_COLUMN)
	{
		data->VirtualColumn = cursor.X;
	}
}

/* ---------------------------------------------------------------------
 * MemoAppendPara
 * Append a paragraph to the end of the list
 * ---------------------------------------------------------------------
 */
static void
MemoAppendPara(MEMODATA* data, PARAGRAPH *para)
{
	if (data->pLast)
	{
		para->pPrev = data->pLast;
		para->pNext = NULL;
		data->pLast->pNext = para;
	}
	else
	{
		para->pPrev = NULL;
		para->pNext = NULL;
		data->pFirst = para;
	}
	data->pLast = para;
	data->NumPara++;
}

/* ---------------------------------------------------------------------
 * MemoAppendPara
 * Append a paragraph to the end of the list
 * ---------------------------------------------------------------------
 */
static void 
MemoModify(CUIWINDOW *win)
{
	MEMODATA *data = (MEMODATA*) win->InstData;
	if (data->MemoChangedHook)
	{
		data->MemoChangedHook(data->MemoChangedTarget, win);
	}
}

/* paragraph routines */

/* ---------------------------------------------------------------------
 * ParaNew
 * Create a new empty paragraph and return a pointer. The new paragraph is 
 * not attached to the linked list of paragraphs yet
 * ---------------------------------------------------------------------
 */
static PARAGRAPH* 
ParaNew(void)
{
	PARAGRAPH *result = (PARAGRAPH*) malloc(sizeof(PARAGRAPH));
	if (result)
	{
		memset(result, 0, sizeof(PARAGRAPH));
		result->NumLines = 1;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ParaDelete
 * Delete a paragraph and free text data
 * ---------------------------------------------------------------------
 */
static void
ParaDelete(PARAGRAPH *para)
{
	if (para->pText)
	{
		free(para->pText);
	}
	free(para);
}

/* ---------------------------------------------------------------------
 * ParaLink
 * Place a paragraph into the linked list next to the list item pointed
 * to by "insertpos"
 * ---------------------------------------------------------------------
 */
static void
ParaLink(PARAGRAPH *para, PARAGRAPH *insertpos)
{
	para->pNext      = insertpos->pNext;
	para->pPrev      = insertpos;
	insertpos->pNext = para;
	
	if (para->pNext)
	{
		para->pNext->pPrev = para;
	}
}

/* ---------------------------------------------------------------------
 * ParaUnlink
 * Unlinks a given paragraph from the linked list
 * ---------------------------------------------------------------------
 */
static void
ParaUnlink(PARAGRAPH *para)
{
	if (para->pPrev)
	{
		para->pPrev->pNext = para->pNext;
	}
	if (para->pNext)
	{
		para->pNext->pPrev = para->pPrev;
	}
}

/* ---------------------------------------------------------------------
 * ParaInsertText
 * Insert text into a paragraph
 * ---------------------------------------------------------------------
 */
static void 
ParaInsertText(PARAGRAPH *para, int pos, const wchar_t *text, int len)
{
	if ((para->Length + len) >= para->BufferSize)
	{
		para->BufferSize = (((para->Length + len) / INCREMENT_SIZE) + 1) * INCREMENT_SIZE;
		if (para->pText)
		{
			para->pText    = (wchar_t*) realloc(para->pText, (para->BufferSize + 1) * sizeof(wchar_t));
		}
		else
		{
			para->pText    = (wchar_t*) malloc((para->BufferSize + 1) * sizeof(wchar_t));
			para->pText[0] = _T('\0');
		}
	}
	if (len > 0)
	{
		if (pos >= para->Length)
		{
			wcsncat(para->pText, text, len);
		}
		else
		{
			wcsrcpy(para->pText + len + pos, para->pText + pos);
			wcsncpy(para->pText + pos, text, len);
		}
		para->Length += len;
	}
}

/* ---------------------------------------------------------------------
 * ParaSplitPara
 * Split a given paragraph at a specified position and return a yet
 * unlinked new paragraph with the text data following "pos".
 * ---------------------------------------------------------------------
 */
static PARAGRAPH *ParaSplitPara(PARAGRAPH *para, int pos)
{
	PARAGRAPH *result = ParaNew();
	if (result)
	{
		if ((para->pText) && (pos < para->Length))
		{
			ParaInsertText(result, 0,   para->pText + pos, para->Length - pos);
			ParaDeleteText(para,   pos, para->Length - pos);
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ParaAppendPara
 * Append a paragraph's text at the end of an other paragraph
 * ---------------------------------------------------------------------
 */
static void
ParaAppendPara(PARAGRAPH *para, PARAGRAPH *pappend)
{
	if (pappend->pText)
	{
		ParaInsertText(para, para->Length, pappend->pText, pappend->Length);
	}
}

/* ---------------------------------------------------------------------
 * ParaDeleteText
 * Delete text from the text buffer of a paragraph
 * ---------------------------------------------------------------------
 */
static void
ParaDeleteText(PARAGRAPH *para, int pos, int len)
{
	if (para->pText && (para->Length > pos) && (pos >= 0))
	{
		if (pos + len > para->Length)
		{
			len = para->Length - pos;
		}
		wcscpy(para->pText + pos, para->pText + pos + len);
		
		para->Length -= len;
	}
}

/* ---------------------------------------------------------------------
 * ParaRenderText
 * Calculate text positions according to the width of the available
 * space on the display. This function returns the sizes of the paragraph's
 * width and height within the struct "virtualSize"
 * ---------------------------------------------------------------------
 */
static void
ParaRenderText(PARAGRAPH *para, int width, CUISIZE *virtualSize)
{
	virtualSize->X = 0;
	virtualSize->Y = 1;
	
	if (width > 0)
	{
		if (para->pText)
		{
			const wchar_t *pLineStart = para->pText;
			const wchar_t *pSpaceChar = para->pText;
			const wchar_t *pChar      = pLineStart;
			int   length      = 0;

			/* iterate all characters in line */
			while (*pChar != L'\0')
			{
				length++;
				if (length > width)
				{
					if (pSpaceChar != pLineStart)
					{
						/* use line from pLineStart to pSpaceChar (inc) */
						if ((pSpaceChar - pLineStart + 1) > virtualSize->X)
						{
							virtualSize->X = (pSpaceChar - pLineStart + 1);
						}
						length     = pChar - pSpaceChar;	
						pLineStart = pSpaceChar + 1;
						pSpaceChar = pLineStart;	
					}
					else
					{
						/* use line from pLineStart to (pChar - 1) */
						if ((pChar - pLineStart) > virtualSize->X)
						{
							virtualSize->X = (pChar - pLineStart);
						}
						length     = 0;
						pLineStart = pChar;
						pSpaceChar = pChar;	
					}
					
					virtualSize->Y++;
				}
				if ((*pChar == L' ') || (*pChar == L'-'))
				{
					pSpaceChar = pChar;
				}				
				
				pChar++;
			}
			
			/* use remaining line */
			if (pChar != pLineStart)
			{
				if ((pChar - pLineStart) > virtualSize->X)
				{
					virtualSize->X = (pChar - pLineStart);
				}
			}
		}
	}
	para->NumLines = virtualSize->Y;
}

/* ---------------------------------------------------------------------
 * ParaShowText
 * Like ParaRenderText, but does text output instead of calculation
 * of dimensions.
 * The function honors the X and Y offset that is related to the window's
 * scroll position and fills the remaining available window width 'widthX' with
 * spaces. The parameter 'limit' is the word wrapping limit.
 * ---------------------------------------------------------------------
 */
static void
ParaShowText(PARAGRAPH *para, CUIWINDOW *win, int offsX, int offsY, int widthX, int limit)
{
	int y = offsY;
	
	if (widthX > 0)
	{
		if (para->pText)
		{
			const wchar_t *pLineStart = para->pText;
			const wchar_t *pSpaceChar = para->pText;
			const wchar_t *pChar      = pLineStart;
			int   length      = 0;

			/* iterate all characters in line */
			while (*pChar != L'\0')
			{
				length++;
				if (length > limit)
				{
					if (pSpaceChar != pLineStart)
					{
						/* use line from pLineStart to pSpaceChar (inc) */
						if (y >= 0)
						{
							MOVEYX(win->Win, y, 0);
							ParaShowLine(win, 
								pLineStart, 
								pSpaceChar - pLineStart + 1, 
								widthX, 
								offsX);
						}
						
						length     = pChar - pSpaceChar;	
						pLineStart = pSpaceChar + 1;
						pSpaceChar = pLineStart;	
					}
					else
					{
						if (y >= 0)
						{
							MOVEYX(win->Win, y, 0);
							ParaShowLine(win, 
								pLineStart, 
								pChar - pLineStart, 
								widthX,
								offsX);
						}

						length     = 0;
						pLineStart = pChar;
						pSpaceChar = pChar;	
					}
					
					y++;
				}
				if ((*pChar == L' ') || (*pChar == L'-'))
				{
					pSpaceChar = pChar;
				}				
				
				pChar++;
			}
			
			/* use remaining line */
			if (y >= 0)
			{
				MOVEYX(win->Win, y, 0);
				ParaShowLine(win, 
					pLineStart, 
					pChar - pLineStart, 
					widthX,
					offsX);
			}
		}
		else if (y >= 0)
		{
			MOVEYX(win->Win, y, 0);
			ParaShowLine(win, 
				L"", 
				0, 
				widthX,
				offsX);
		}
	}
}

/* ---------------------------------------------------------------------
 * ParaGetVisualPos
 * Take a logical column position and return the according visual cursor
 * relative to the text dimensions of the paragraphs text area. The parameter
 * 'width' is the limit for word wrapping
 * ---------------------------------------------------------------------
 */
static CUIPOINT 
ParaGetVisualPos(PARAGRAPH *para, int width, int colpos)
{
	CUIPOINT result;
	
	result.X = 0;
	result.Y = 0;
	
	if (width > 0)
	{
		if (para->pText)
		{
			const wchar_t *pLineStart = para->pText;
			const wchar_t *pSpaceChar = para->pText;
			const wchar_t *pChar      = pLineStart;
			int   length      = 0;
			
			/* limit column position */
			if (colpos > para->Length)
			{
				colpos = para->Length;
			}

			/* iterate all characters in line */
			while (*pChar != L'\0')
			{
				length++;
				if (length > width)
				{
					if (pSpaceChar != pLineStart)
					{
						/* use line from pLineStart to pSpaceChar (inc) */
						if ((colpos >= (pLineStart - para->pText)) && 
							(colpos <= (pSpaceChar - para->pText)))
						{
							result.X = colpos - (pLineStart - para->pText);
							return result;
						}
						length     = pChar - pSpaceChar;	
						pLineStart = pSpaceChar + 1;
						pSpaceChar = pLineStart;	
					}
					else
					{
						/* use line from pLineStart to (pChar - 1) */
						if ((colpos >= (pLineStart - para->pText)) && 
							(colpos <  (pChar - para->pText)))
						{
							result.X = colpos - (pLineStart - para->pText);
							return result;
						}
						length     = 0;
						pLineStart = pChar;
						pSpaceChar = pChar;	
					}
					
					result.Y++;
				}
				if ((*pChar == L' ') || (*pChar == L'-'))
				{
					pSpaceChar = pChar;
				}				
				
				pChar++;
			}
			
			/* use remaining line */
			if (pChar != pLineStart)
			{
				result.X = colpos - (pLineStart - para->pText);
			}
		}
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ParaGetLogicalPos
 * Take a visual position (relative to the dimensions of the paragraph's
 * text area and return the according logical column position.
 * ---------------------------------------------------------------------
 */
static int 
ParaGetLogicalPos(PARAGRAPH *para, int width, const CUIPOINT *pt)
{
	int y = 0;
	
	if (width > 0)
	{
		if (para->pText)
		{
			const wchar_t *pLineStart = para->pText;
			const wchar_t *pSpaceChar = para->pText;
			const wchar_t *pChar      = pLineStart;
			int   length      = 0;

			/* iterate all characters in line */
			while (*pChar != L'\0')
			{
				length++;
				if (length > width)
				{
					if (pSpaceChar != pLineStart)
					{
						/* use line from pLineStart to pSpaceChar (inc) */
						if (pt->Y == y)
						{
							if (pt->X >= (pSpaceChar - pLineStart + 1))
							{
								return (pSpaceChar - para->pText);
							}
							else
							{
								return (pLineStart - para->pText) + pt->X;
							}
						}
						length     = pChar - pSpaceChar;	
						pLineStart = pSpaceChar + 1;
						pSpaceChar = pLineStart;	
					}
					else
					{
						/* use line from pLineStart to (pChar - 1) */
						if (pt->Y == y)
						{
							if (pt->X >= (pChar - pLineStart))
							{
								return (pChar - para->pText - 1);
							}
							else
							{
								return (pLineStart - para->pText) + pt->X;
							}
						}
						length     = 0;
						pLineStart = pChar;
						pSpaceChar = pChar;	
					}
					
					y++;
				}
				if ((*pChar == L' ') || (*pChar == L'-'))
				{
					pSpaceChar = pChar;
				}				
				
				pChar++;
			}
			
			/* use remaining line */
			if (pChar != pLineStart)
			{
				if (pt->X + (pLineStart - para->pText) > para->Length)
				{
					return para->Length;
				}
				else
				{
					return pt->X + (pLineStart - para->pText);
				}
			}
		}
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * ParaShowLine
 * Show a single line of text and fill end of line with spaces. 
 * ---------------------------------------------------------------------
 */
static void
ParaShowLine(CUIWINDOW *win, const wchar_t *pText, int len, int width, int offs)
{
	int pos = 0;
	
	if (len > offs)
	{
		if (len - offs > width)
		{
			PRINTN(win->Win, &pText[offs], width);
		}
		else
		{
			PRINTN(win->Win, &pText[offs], len - offs);
		}
		
		pos = len - offs;
	}
	
	while (pos < width)
	{
		int block = 32;
		
		if (pos + block > width)
		{
			block = width - pos;
		}
		PRINTN(win->Win, L"                                ", block);
		
		pos += block;
	}
}

/* ---------------------------------------------------------------------
 * wcsrcpy
 * Helper function used to copy a character string in reversed order
 * ---------------------------------------------------------------------
 */
static wchar_t *
wcsrcpy(wchar_t *dest, const wchar_t *source)
{
	int len;

	len = wcslen(source) + 1;
	dest   += len;
	source += len;

	while(len-- >= 0)
	{
		*(dest--) = *(source--);
	}
	return(dest);
}

