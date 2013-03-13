/* ---------------------------------------------------------------------
 * File: listbox.c
 * (listbox control for dialog windows)
 *   
 * Copyright (C) 2006
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

#include "cui.h"

typedef struct LISTBOXITEMStruct
{
	TCHAR*        ItemText;
	unsigned long ItemData;
	void*         Next;
	void*         Previous;
} LISTBOXITEM;

typedef struct LISTBOXDATAStruct
{
	int           NumItems; 
	int           SelIndex;
	int           Sorted;
	int           Descending;
	LISTBOXITEM*  FirstItem;
	LISTBOXITEM*  LastItem;
	
	CustomHook1PtrProc         SetFocusHook;      /* Custom callback */
	CustomHookProc             KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc     PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc     PostKeyHook;       /* Custom callback */
	CustomHookProc             LbChangedHook;     /* Custom callback */
	CustomBoolHookProc         LbChangingHook;    /* Custom callback */
	CustomHookProc             LbClickedHook;     /* Custom callback */
	CUIWINDOW*                 SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*                 KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*                 PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*                 PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*                 LbChangedTarget;   /* Custom callback target */
	CUIWINDOW*                 LbChangingTarget;  /* Custom callback target */
	CUIWINDOW*                 LbClickedTarget;   /* Custom callback target */
	int                        MouseDown;         /* Mouse button down */
} LISTBOXDATA;


static LISTBOXITEM* ListboxGetItem(LISTBOXDATA* data, int index);
static void ListboxCalcPos(CUIWINDOW* win);
static void ListboxUpdate(CUIWINDOW* win);
static int  ListboxQueryChange(CUIWINDOW* win, LISTBOXDATA* data);
static void ListboxNotifyChange(CUIWINDOW* win, LISTBOXDATA* data);

/* ---------------------------------------------------------------------
 * ListboxNcPaintHook
 * Handle PAINT events by redrawing the groupbox control
 * ---------------------------------------------------------------------
 */
static void
ListboxNcPaintHook(void* w, int size_x, int size_y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;
	int len;

	rc.W = size_x;
	rc.H = size_y;
	rc.X = 0;
	rc.Y = 0;

	if ((rc.W <= 0)||(rc.H <= 0)) return;

	if (win->HasBorder)
	{
		box(win->Frame, 0, 0);
		if (win->HasVScroll && (size_y > 2))
		{
			WindowPaintVScroll(win, 1, size_y - 2);
		}
	}
	else if (win->HasVScroll)
	{
		WindowPaintVScroll(win, 0, size_y - 1);
	}

	if (win->IsEnabled)
	{
		SetColor(win->Frame, win->Color.HilightColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(win->Frame, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	if (!win->Text || (win->Text[0] == 0) || (!win->HasBorder)) return;

	len = tcslen(win->Text);
	if (len > rc.W - 4)
	{
		len = rc.W - 4;
	}

	MOVEYX(win->Frame, 0, 2); PRINTN(win->Frame, win->Text, len);
	if (rc.W > 2)
	{
		MOVEYX(win->Frame, 0, 1); PRINT(win->Frame, _T(" "));
		MOVEYX(win->Frame, 0, len + 2); PRINT(win->Frame, _T(" "));
	}
}


/* ---------------------------------------------------------------------
 * ListboxPaintHook
 * Handle PAINT events by redrawing the groupbox control
 * ---------------------------------------------------------------------
 */
static void
ListboxPaintHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	CUIRECT      rc;
	LISTBOXDATA* data;
	LISTBOXITEM* item;
	int          pos;
	int          cursor;
	int          index;
	int          len;
	int          x,y;

	data = (LISTBOXDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	pos = WindowGetVScrollPos(win);
	index = 0;
	y = 0;
	cursor = 0;

	item = data->FirstItem;
	while(item)
	{
		if ((index >= pos) && (index < pos + rc.H))
		{
			len = tcslen(item->ItemText);
			if (index == data->SelIndex)
			{
				SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
				cursor = y;
			}
			else
			{
				if (win->IsEnabled)
				{
					SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
				}
				else
				{
					SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
				}
			}
			MOVEYX(win->Win, y, 0);
			for (x = 0; x < rc.W; x++)
			{
				if ((x > 0) && (x <= len))
				{
					PRINTN(win->Win, &item->ItemText[x - 1], 1);
				}
				else
				{
					PRINT(win->Win, _T(" "));
				}
			}
			y ++;
		}
		else if (index >= pos + rc.H)
		{
			break;
		}
		index++;
		item = (LISTBOXITEM*) item->Next;
	}
	WindowSetCursor(win, 0, cursor);	
}


/* ---------------------------------------------------------------------
 * ListboxSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int 
ListboxSizeHook(void* w)
{
	ListboxCalcPos((CUIWINDOW*) w);
	return TRUE;
}


/* ---------------------------------------------------------------------
 * ListboxKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
ListboxKeyHook(void* w, int key)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
	CUIRECT      rc;

        if (!data) return FALSE;

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

		switch(key)
		{
		case KEY_UP:
			if ((data->SelIndex > 0) && ListboxQueryChange(win, data))
			{
				data->SelIndex--;
				ListboxCalcPos(win);
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
			return TRUE;
		case KEY_DOWN:
			if ((data->SelIndex < (data->NumItems - 1)) && ListboxQueryChange(win, data))
			{
				data->SelIndex++;
				ListboxCalcPos(win);
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
			return TRUE;
		case KEY_PPAGE:
			if ((data->SelIndex > 0) && ListboxQueryChange(win, data))
			{
				WindowGetClientRect(win, &rc);

				data->SelIndex -= rc.H - 1;
				if (data->SelIndex < 0)
				{
					data->SelIndex = 0;
				}
				ListboxCalcPos(win);
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
			return TRUE;
		case KEY_NPAGE:
			if ((data->SelIndex < (data->NumItems - 1)) && ListboxQueryChange(win, data))
			{
				WindowGetClientRect(win, &rc);

				data->SelIndex += rc.H - 1;
				if (data->SelIndex >=  (data->NumItems - 1))
				{
					data->SelIndex = (data->NumItems - 1);
				}
				ListboxCalcPos(win);
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
			return TRUE;
		case KEY_SPACE:
			if (data->LbClickedHook)
			{
				data->LbClickedHook(data->LbClickedTarget, win);
			}
			return TRUE;
		default:
			if (data->PostKeyHook)
			{
				if (data->PostKeyHook(data->PostKeyTarget, win, key))
				{
					return TRUE;
				}   
			}
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * ListboxMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
ListboxMButtonHook(void* w, int x, int y, int flags)
{
        CUIWINDOW* win = (CUIWINDOW*) w;
        LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
        if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
        {
		int offsy = WindowGetVScrollPos(win);
		int nochange = FALSE;
		y += offsy;

		WindowReleaseCapture();

		if ((y != data->SelIndex) && (y < data->NumItems))
		{
			if (ListboxQueryChange(win, data))
			{
				data->SelIndex = y;
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
			else
			{
				nochange = TRUE;
			}
		}
		/* only execute clicked hook, if change was not rejected
		   by the application */
		if (!nochange)
		{
	                if ((flags & BUTTON1_DOUBLE_CLICKED) && 
			    (data->LbClickedHook))
                	{
	                        data->LbClickedHook(data->LbClickedTarget, win);
        	        }
		}
        }
        else if (flags & BUTTON1_PRESSED)
        {
                data->MouseDown = TRUE;
                WindowSetCapture(win);
        }
        else if ((flags & BUTTON1_RELEASED) && (data->MouseDown))
        {
                CUIRECT rc;
                WindowGetClientRect(win, &rc);

                data->MouseDown = FALSE;
                WindowReleaseCapture();

                if ((x >= rc.X) && (x < (rc.X + rc.W)) &&
                    (y >= rc.Y) && (y < (rc.Y + rc.H)))
                {
			int offsy = WindowGetVScrollPos(win);

			y += offsy;

			if ((y != data->SelIndex) && (y < data->NumItems))
			{
				ListboxQueryChange(win, data);
				data->SelIndex = y;
				ListboxUpdate(win);
				ListboxNotifyChange(win, data);
			}
                }
        }
}


/* ---------------------------------------------------------------------
 * ListboxVScrollHook
 * Listbox scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
ListboxVScrollHook(void* w, int sbcode, int pos)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT rc;
	int sbpos, range;

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
			sbpos = (sbpos < 0) ? 0 : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.H - 1);
			sbpos = (sbpos > range) ? range : sbpos;
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
 * ListboxDestroyHook
 * Handle EVENT_DELETE events by deleting the edit's control data
 * ---------------------------------------------------------------------
 */
static void
ListboxDestroyHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	ListboxClear(win);

	free (win->InstData);
}


/* ---------------------------------------------------------------------
 * ListboxSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ListboxSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;

	if (data)
	{
		WindowCursorOn();

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}


/* ---------------------------------------------------------------------
 * ListboxKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ListboxKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;

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
 * ListviewLayoutHook
 * Handle EVENT_UPDATELAYOUT Events
 * ---------------------------------------------------------------------
 */
static void
ListboxLayoutHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	
	ListboxCalcPos(win);
	ListboxUpdate(win);
}

/* ---------------------------------------------------------------------
 * ListboxNew
 * Create a list box dialog control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ListboxNew(CUIWINDOW* parent, const TCHAR* text, int x, int y, int w, int h, 
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* listbox;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		listbox = WindowNew(parent, x, y, w, h, flags);
		listbox->Class = _T("LISTBOX");
		WindowSetId(listbox, id);
		WindowSetNcPaintHook(listbox, ListboxNcPaintHook);
		WindowSetPaintHook(listbox, ListboxPaintHook);
		WindowSetKeyHook(listbox, ListboxKeyHook);
		WindowSetSetFocusHook(listbox, ListboxSetFocusHook);
		WindowSetKillFocusHook(listbox, ListboxKillFocusHook);
		WindowSetMButtonHook(listbox, ListboxMButtonHook);
		WindowSetVScrollHook(listbox, ListboxVScrollHook);
		WindowSetSizeHook(listbox, ListboxSizeHook);
		WindowSetDestroyHook(listbox, ListboxDestroyHook);
		WindowEnableVScroll(listbox, TRUE);
		WindowSetLayoutHook(listbox, ListboxLayoutHook);

		listbox->InstData = (LISTBOXDATA*) malloc(sizeof(LISTBOXDATA));
		((LISTBOXDATA*)listbox->InstData)->SetFocusHook    = NULL;
		((LISTBOXDATA*)listbox->InstData)->KillFocusHook   = NULL;
		((LISTBOXDATA*)listbox->InstData)->PreKeyHook      = NULL;   
		((LISTBOXDATA*)listbox->InstData)->PostKeyHook     = NULL; 
		((LISTBOXDATA*)listbox->InstData)->LbChangedHook   = NULL;
		((LISTBOXDATA*)listbox->InstData)->LbChangingHook  = NULL;
		((LISTBOXDATA*)listbox->InstData)->LbClickedHook   = NULL;

		((LISTBOXDATA*)listbox->InstData)->NumItems = 0;
		((LISTBOXDATA*)listbox->InstData)->SelIndex = -1;
		((LISTBOXDATA*)listbox->InstData)->Sorted = ((flags & LB_SORTED) != 0);
		((LISTBOXDATA*)listbox->InstData)->Descending = ((flags & LB_DESCENDING) != 0);
		((LISTBOXDATA*)listbox->InstData)->FirstItem = NULL;
		((LISTBOXDATA*)listbox->InstData)->LastItem = NULL;
		((LISTBOXDATA*)listbox->InstData)->MouseDown = FALSE;

		WindowSetText(listbox, text);

		return listbox;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ListboxSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ListboxSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->SetFocusHook = proc;
		((LISTBOXDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListboxSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ListboxSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->KillFocusHook = proc;
		((LISTBOXDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ListboxSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
ListboxSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->PreKeyHook = proc;
		((LISTBOXDATA*)win->InstData)->PreKeyTarget = target;
	}
}
 
 
/* ---------------------------------------------------------------------
 * ListboxSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
ListboxSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->PostKeyHook = proc;
		((LISTBOXDATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ListboxSetLbChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ListboxSetLbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->LbChangedHook = proc;
		((LISTBOXDATA*)win->InstData)->LbChangedTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ListboxSetLbChangingHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ListboxSetLbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->LbChangingHook = proc;
		((LISTBOXDATA*)win->InstData)->LbChangingTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ListviewSetLbClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
ListboxSetLbClickedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		((LISTBOXDATA*)win->InstData)->LbClickedHook = proc;
		((LISTBOXDATA*)win->InstData)->LbClickedTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * ListboxAdd
 * Add an entry to the list box control
 * ---------------------------------------------------------------------
 */
int  
ListboxAdd(CUIWINDOW* win, const TCHAR* text)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		int index = 0;
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = (LISTBOXITEM*) malloc(sizeof(LISTBOXITEM));

		item->Next = NULL;
		item->Previous = NULL;
		item->ItemText = tcsdup(text);
		item->ItemData = 0;

		if (data->Sorted)
		{
			LISTBOXITEM* itemptr = (LISTBOXITEM*) data->FirstItem;
			LISTBOXITEM* previous = NULL;
			if (data->Descending)
			{
				while (itemptr && (tcscmp(itemptr->ItemText, text) > 0))
				{
					index++;
					previous = itemptr;
					itemptr = (LISTBOXITEM*) itemptr->Next;
				}
			}
			else
			{
				while (itemptr && (tcscmp(itemptr->ItemText, text) < 0))
				{
					index++;
					previous = itemptr;
					itemptr = (LISTBOXITEM*) itemptr->Next;
				}
			}
			if (previous)
			{
				/* insert in the middle of the list */
				item->Next = itemptr;
				item->Previous = previous;
				previous->Next = item;
				
				if (item->Next)
				{
					((LISTBOXITEM*) item->Next)->Previous = item;
				}
				else
				{
					data->LastItem = item;
				}
			}
			else
			{
				/* insert at the beginning of the list */
				item->Next = data->FirstItem;
				if (item->Next)
				{
					((LISTBOXITEM*) item->Next)->Previous = item;
				}
				else
				{
					data->LastItem = item;
				}
				data->FirstItem = item;
			}
			data->NumItems++;
		}
		else
		{
			if (data->LastItem)
			{
				data->LastItem->Next = item;
			}
			else
			{
				data->FirstItem = item;
			}
			item->Previous = data->LastItem;
			data->LastItem = item;

			index = (data->NumItems++);
		}
		
		WindowInvalidateLayout(win);
		
		return index;
	}
	return (-1);
}


/* ---------------------------------------------------------------------
 * ListboxDelete
 * Delete an entry from the list box control
 * ---------------------------------------------------------------------
 */
void 
ListboxDelete(CUIWINDOW* win, int index)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = ListboxGetItem(data, index);
		if (item)
		{
			data->NumItems--;
			if (data->LastItem == item)
			{
				data->LastItem = item->Previous;
			}
			if (data->SelIndex >= data->NumItems)
			{
				data->SelIndex--;
			}

			if (item->Previous)
			{
				((LISTBOXITEM*)item->Previous)->Next = item->Next;
			}
			else
			{
				data->FirstItem = item->Next;
			}
			if (item->Next)
			{
				((LISTBOXITEM*)item->Next)->Previous = item->Previous;
			}
			else
			{
				data->LastItem = item->Previous;
			}
			free(item->ItemText);
			free(item);
		}
		
		WindowInvalidateLayout(win);
	}
}


/* ---------------------------------------------------------------------
 * ListboxGet
 * Get item text of item 'index'
 * ---------------------------------------------------------------------
 */
const TCHAR* 
ListboxGet(CUIWINDOW* win, int index)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = ListboxGetItem(data, index);
		if (item)
		{
			return item->ItemText;
		}
	}
	return _T("");
}


/* ---------------------------------------------------------------------
 * ListboxSetData
 * Associate data with an existing list box entry
 * ---------------------------------------------------------------------
 */
void 
ListboxSetData(CUIWINDOW* win, int index, unsigned long udata)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = ListboxGetItem(data, index);
		if (item)
		{
			item->ItemData = udata;
		}
	}
}


/* ---------------------------------------------------------------------
 * ListboxGetData
 * Read data from an existing list box entry
 * ---------------------------------------------------------------------
 */
unsigned long 
ListboxGetData(CUIWINDOW* win, int index)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = ListboxGetItem(data, index);
		if (item)
		{
			return item->ItemData;
		}
	}
	return 0;
}


/* ---------------------------------------------------------------------
 * ListboxSetSel
 * Set the selection (-1 == unselected)
 * ---------------------------------------------------------------------
 */
void 
ListboxSetSel(CUIWINDOW* win, int index)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		if ((index < data->NumItems) && (index >= (-1)))
		{
			data->SelIndex = index;
			ListboxCalcPos(win);
			ListboxUpdate(win);
		}
	}
}


/* ---------------------------------------------------------------------
 * ListboxGetSel
 * Read the selection (-1 == unselected)
 * ---------------------------------------------------------------------
 */
int  
ListboxGetSel(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		return data->SelIndex;
	}
	return (-1);
}


/* ---------------------------------------------------------------------
 * ListboxClear
 * Clear the entire list
 * ---------------------------------------------------------------------
 */
void
ListboxClear(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = data->FirstItem;
		while (item)
		{
			data->FirstItem = (LISTBOXITEM*) item->Next;
			free(item->ItemText);
			free(item);
			item = data->FirstItem;
		}
		data->NumItems = 0;
		data->SelIndex = (-1);
		data->LastItem = NULL;

		WindowInvalidateLayout(win);
	}
}


/* ---------------------------------------------------------------------
 * ListboxGetCount
 * Return the number of items in the list
 * ---------------------------------------------------------------------
 */
int  
ListboxGetCount(CUIWINDOW* win)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		return data->NumItems;
	}
	return 0;
}


/* ---------------------------------------------------------------------
 * ListboxSelect
 * Select a specified string item
 * ---------------------------------------------------------------------
 */
int
ListboxSelect(CUIWINDOW* win, const TCHAR* text)
{
	if (win && (tcscmp(win->Class, _T("LISTBOX")) == 0))
	{
		LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
		LISTBOXITEM* item = data->FirstItem;
		int index = 0;

		while (item)
		{
			if (tcscmp(item->ItemText, text) == 0)
			{
				data->SelIndex = index;
				ListboxCalcPos(win);
				ListboxUpdate(win);
				return index;
			}
			index++;
			item = (LISTBOXITEM*) item->Next;
		}
	}
	return -1;
}


/* local helper functions */

/* ---------------------------------------------------------------------
 * ListboxGetItem
 * Get item of index
 * ---------------------------------------------------------------------
 */
static LISTBOXITEM* 
ListboxGetItem(LISTBOXDATA* data, int index)
{
	int i = 0;
	LISTBOXITEM* result;

	if (index < 0)
	{
		return NULL;
	}

	result = data->FirstItem;
	while (result && (i < index))
	{
		i++;
		result = (LISTBOXITEM*) result->Next;
	}
	return result;
}


/* ---------------------------------------------------------------------
 * ListboxCalcPos
 * Recalculate Listbox position
 * ---------------------------------------------------------------------
 */
static void
ListboxCalcPos(CUIWINDOW* win)
{
	CUIRECT      rc;
	LISTBOXDATA* data = (LISTBOXDATA*) win->InstData;
	int          range;
	int          pos;

	if (!data) return;
	if (win->IsCreated)
	{
		WindowGetClientRect(win, &rc);

		range = data->NumItems - rc.H;
		if (range < 0)
		{
			WindowSetVScrollRange(win, 0);
			WindowSetVScrollPos(win, 0);
		}
		else
		{
			WindowSetVScrollRange(win, range);

			pos = WindowGetVScrollPos(win);
			if (data->SelIndex < 0)
			{
				WindowSetVScrollPos(win, 0);
			}
			else if (data->SelIndex - pos >= rc.H)
			{
				WindowSetVScrollPos(win, data->SelIndex - rc.H + 1);
			}
			else if (data->SelIndex - pos < 0)
			{
				WindowSetVScrollPos(win, data->SelIndex);
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * ListboxUpdate
 * Update listbox view
 * ---------------------------------------------------------------------
 */
static void
ListboxUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* ---------------------------------------------------------------------
 * ListboxQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int  
ListboxQueryChange(CUIWINDOW* win, LISTBOXDATA* data)
{
	if (data->LbChangingHook)
	{
		return data->LbChangingHook(data->LbChangingTarget, win);
	}
	return TRUE;
}


/* ---------------------------------------------------------------------
 * ListboxNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void 
ListboxNotifyChange(CUIWINDOW* win, LISTBOXDATA* data)
{
	if (data->LbChangedHook)
	{
		data->LbChangedHook(data->LbChangedTarget, win);
	}
}


