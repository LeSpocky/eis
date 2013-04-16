/* ---------------------------------------------------------------------
 * File: combobox.c
 * ( control for dialog windows)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: combobox.c 33467 2013-04-14 16:23:14Z dv $
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

typedef struct COMBOBOXITEMStruct
{       
        wchar_t*      ItemText;
        unsigned long ItemData;
        void*         Next;
        void*         Previous;
} COMBOBOXITEM;

typedef struct COMBOBOXDATAStruct 
{
	int           NumItems;
	int           SelIndex;            /* selected item in dropdown listbox */
	int           CtrlSelIndex;        /* selected item in combobox control */
	int           Sorted;
	int           Descending;
	COMBOBOXITEM* FirstItem;
	COMBOBOXITEM* LastItem;
	int           Height;              /* height of the dropdown list */
	int           MouseDown;
	int           DropdownState;       /* dropdown window visible? */
	int           CloseKey;            /* the key that closed the control */
	CUIWINDOW*    Ctrl;                /* handle of combobox control */

	CustomHook1PtrProc      SetFocusHook;      /* Custom callback */
	CustomHookProc          KillFocusHook;     /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;        /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;       /* Custom callback */
	CustomHookProc          CbChangedHook;     /* Custom callback */
	CustomBoolHookProc      CbChangingHook;    /* Custom callback */

	CUIWINDOW*              SetFocusTarget;    /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;   /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;      /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;     /* Custom callback target */
	CUIWINDOW*              CbChangedTarget;   /* Custom callback target */
	CUIWINDOW*              CbChangingTarget;  /* Custom callback target */
} COMBOBOXDATA;


static void CbDropdownCalcPos(CUIWINDOW* win);
static void CbDropdownUpdate(CUIWINDOW* win);
static int  CbDropdownQueryChange(CUIWINDOW* win, COMBOBOXDATA* data);
static void CbDropdownNotifyChange(CUIWINDOW* win, COMBOBOXDATA* data);

static COMBOBOXITEM* ComboboxGetItem(COMBOBOXDATA* data, int index);
static void ComboboxUpdate(CUIWINDOW* win);
static int  ComboboxQueryChange(CUIWINDOW* win, COMBOBOXDATA* data);
static void ComboboxNotifyChange(CUIWINDOW* win, COMBOBOXDATA* data);
static void ComboboxShowDropdown(CUIWINDOW* win, COMBOBOXDATA* data, int capture);


/* ---------------------------------------------------------------------
 * Dropdown window
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * CbDropdownPaintHook
 * Handle PAINT events by redrawing the control
 * ---------------------------------------------------------------------
 */
static void
CbDropdownPaintHook(void* w)
{       
	CUIWINDOW*    win = (CUIWINDOW*) w;
	CUIRECT       rc;
	COMBOBOXDATA* data;
	COMBOBOXITEM* item;
	int           pos;
	int           cursor;
	int           index;
	int           len;
	int           x,y;
        
	data = (COMBOBOXDATA*) win->InstData;
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
			len = wcslen(item->ItemText);
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
		item = (COMBOBOXITEM*) item->Next;
	}
	WindowSetCursor(win, 0, cursor);
}


/* ---------------------------------------------------------------------
 * CbDropdownSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int
CbDropdownSizeHook(void* w)
{
	CbDropdownCalcPos((CUIWINDOW*) w);
	return TRUE;
}


/* ---------------------------------------------------------------------
 * CbDropdownKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
CbDropdownKeyHook(void* w, int key)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
	CUIRECT      rc;
        
	if (!data) return FALSE;
        
	if (win->IsEnabled)
	{
		switch(key)
		{
		case KEY_UP:
			if ((data->SelIndex > 0) && CbDropdownQueryChange(win, data))
			{
				data->SelIndex--;
				CbDropdownCalcPos(win);
				CbDropdownUpdate(win); 
				CbDropdownNotifyChange(win, data);
			}
			return TRUE;
		case KEY_DOWN:
			if ((data->SelIndex < (data->NumItems - 1)) && CbDropdownQueryChange(win, data))
			{
				data->SelIndex++;
				CbDropdownCalcPos(win);
				CbDropdownUpdate(win); 
				CbDropdownNotifyChange(win, data);
			}
			return TRUE;
		case KEY_PPAGE:
			if ((data->SelIndex > 0) && CbDropdownQueryChange(win, data))
			{
				WindowGetClientRect(win, &rc);
                                
				data->SelIndex -= rc.H - 1;
				if (data->SelIndex < 0)
				{
					data->SelIndex = 0;
				}
				CbDropdownCalcPos(win);
				CbDropdownUpdate(win); 
				CbDropdownNotifyChange(win, data);
			}
			return TRUE;
		case KEY_NPAGE:
			if ((data->SelIndex < (data->NumItems - 1)) && CbDropdownQueryChange(win, data))
			{
				WindowGetClientRect(win, &rc);
                                
				data->SelIndex += rc.H - 1;
				if (data->SelIndex >=  (data->NumItems - 1))
				{
					data->SelIndex = (data->NumItems - 1);
				}
				CbDropdownCalcPos(win);
				CbDropdownUpdate(win); 
				CbDropdownNotifyChange(win, data);
			}
			return TRUE;
		case KEY_SPACE:
		case KEY_RETURN:
			if (data->SelIndex != data->CtrlSelIndex)
			{
				if (ComboboxQueryChange(data->Ctrl, data))
				{
					data->CtrlSelIndex = data->SelIndex;
					ComboboxNotifyChange(data->Ctrl, data);
				}
			}
			data->CloseKey = key;
			WindowClose(win, IDOK);
			return TRUE;
		case KEY_LEFT:
		case KEY_RIGHT:
		case KEY_TAB:
		case KEY_ESC:
			data->CloseKey = key;
			WindowClose(win, IDCANCEL);
			return TRUE;
		}
	}
	return FALSE;
}


/* ---------------------------------------------------------------------
 * CbDropdownSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
CbDropdownSetFocusHook(void* w, void* lastfocus)
{
	CUI_USE_ARG(w);
	CUI_USE_ARG(lastfocus);
	
	WindowCursorOn();
}
 
 
/* ---------------------------------------------------------------------
 * CbDropdownKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
CbDropdownKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
        
	WindowCursorOff();
	WindowClose(win, IDCANCEL);                
}


/* ---------------------------------------------------------------------
 * CbDropdownMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
CbDropdownMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
	{
		int offsy = WindowGetVScrollPos(win);
		int nochange = FALSE;
		y += offsy;
                
		WindowReleaseCapture();
                
		if ((y != data->SelIndex) && (y < data->NumItems))
		{
			if (CbDropdownQueryChange(win, data))
			{
				data->SelIndex = y;
				CbDropdownUpdate(win);
				CbDropdownNotifyChange(win, data);
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
			if (data->SelIndex != data->CtrlSelIndex)
			{
				if (ComboboxQueryChange(data->Ctrl, data))
				{
					data->CtrlSelIndex = data->SelIndex;
					ComboboxNotifyChange(data->Ctrl, data);
				}
			}
			data->CloseKey = KEY_SPACE;
			WindowClose(win, IDOK);
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
		int nochange = FALSE;
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
				CbDropdownQueryChange(win, data);
				data->SelIndex = y;
				CbDropdownUpdate(win);
				CbDropdownNotifyChange(win, data);
			}
			else
			{
				nochange = TRUE;
			}
		}
		if (!nochange)
		{
			if (data->SelIndex != data->CtrlSelIndex)
			{
				if (ComboboxQueryChange(data->Ctrl, data))
				{
					data->CtrlSelIndex = data->SelIndex;
					ComboboxNotifyChange(data->Ctrl, data);
				}
			}
			data->CloseKey = KEY_SPACE;
			WindowClose(win, IDOK);
		}
	}
}


/* ---------------------------------------------------------------------
 * CbDropdownVScrollHook
 * Scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
CbDropdownVScrollHook(void* w, int sbcode, int pos)
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


/* local helper for CbDropdown */

/* ---------------------------------------------------------------------
 * CbDropdownCalcPos
 * Recalculate Listbox position
 * ---------------------------------------------------------------------
 */
static void
CbDropdownCalcPos(CUIWINDOW* win)
{
	CUIRECT      rc;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
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
 * CbDropdownUpdate
 * Update listbox view
 * ---------------------------------------------------------------------
 */
static void
CbDropdownUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}
 
 
/* ---------------------------------------------------------------------
 * CbDropdownQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int
CbDropdownQueryChange(CUIWINDOW* win, COMBOBOXDATA* data)
{
	CUI_USE_ARG(win);
	CUI_USE_ARG(data);
	return TRUE;
}
 
 
/* ---------------------------------------------------------------------
 * CbDropdownNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void
CbDropdownNotifyChange(CUIWINDOW* win, COMBOBOXDATA* data)
{
	CUI_USE_ARG(win);
	
	/* update parent window */
	ComboboxUpdate(data->Ctrl);
}





/* ---------------------------------------------------------------------
 * Combobox window
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * ComboboxPaintHook
 * Handle PAINT events by redrawing the edit control
 * ---------------------------------------------------------------------
 */
static void
ComboboxPaintHook(void* w)
{
	CUIWINDOW*     win = (CUIWINDOW*) w;
	CUIRECT        rc;
	COMBOBOXDATA*  data;
	int            x;
	int            len;
	int            index;
	const wchar_t*   text = _T("");

	data = win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if (rc.W <= 0) return;

	index = data->DropdownState ? data->SelIndex : data->CtrlSelIndex;
	if (index >= 0)
	{
		COMBOBOXITEM* item = ComboboxGetItem(data, index);
		if (item)
		{
			text = item->ItemText;
		}
	}

	len = wcslen(text);
	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndSelColor, TRUE);
	}

	MOVEYX(win->Win, 0, 0);
	for(x = 0; x < rc.W - 3; x++)
	{
		if (x < len)
		{
			PRINTN(win->Win, &text[x], 1);
		}
		else
		{
			PRINT(win->Win, _T(" "));
		}
	}

	if (win->IsEnabled)
	{
		SetColor(win->Win, win->Color.WndTxtColor, win->Color.WndColor, TRUE);
	}
	else
	{
		SetColor(win->Win, win->Color.InactTxtColor, win->Color.WndSelColor, TRUE);
	}
	if (rc.W > 3)
	{
		MOVEYX(win->Win, 0, x); PRINT(win->Win, _T("[v]"));
	}
	WindowSetCursor(win, 0, 0);
}

/* ---------------------------------------------------------------------
 * ComboboxKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
ComboboxKeyHook(void* w, int key)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;

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

		if ((key == KEY_DOWN) || (key == KEY_SPACE))
		{
			ComboboxShowDropdown(win, data, FALSE);
			return TRUE;
		}
		else if (data->PostKeyHook)
		{
			if (data->PostKeyHook(data->PostKeyTarget, win, key))
			{
				return TRUE;
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ComboboxDestroyHook
 * Handle EVENT_DELETE events by deleting control's data
 * ---------------------------------------------------------------------
 */
static void
ComboboxDestroyHook(void* w)
{
	CUIWINDOW*    win = (CUIWINDOW*) w;

	ComboboxClear(win);

	free(win->InstData);
}

/* ---------------------------------------------------------------------
 * ComboboxSetFocus
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ComboboxSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;

	if (data)
	{
		WindowSetCursor(win, 0, 0);
		WindowCursorOn();

		if (data->SetFocusHook)
		{
			data->SetFocusHook(data->SetFocusTarget, win, lastfocus);
		}
	}
}

/* ---------------------------------------------------------------------
 * ComboboxKillFocus
 * Handle EVENT_KILLFOCUS events
 * ---------------------------------------------------------------------
 */
static void
ComboboxKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;

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
 * ComboboxMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
ComboboxMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
	
	CUI_USE_ARG(x);
	CUI_USE_ARG(y);
	
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
	{
		ComboboxShowDropdown(win, data, FALSE);
	}
	else if (flags & BUTTON1_PRESSED)
	{
		ComboboxShowDropdown(win, data, TRUE);
	}
	else if ((flags & BUTTON1_RELEASED) && (data->MouseDown))
	{
		WindowReleaseCapture(); 
	}
}


/* ---------------------------------------------------------------------
 * ComboboxNew
 * Create the control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
ComboboxNew(CUIWINDOW* parent, int x, int y, int w, int h, int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* combobox;
		int flags = sflags | CWS_TABSTOP;
		flags &= ~(cflags);

		combobox = WindowNew(parent, x, y, w, 1, flags);
		combobox->Class = _T("COMBOBOX");
		WindowSetId(combobox, id);
		WindowSetPaintHook(combobox, ComboboxPaintHook);
		WindowSetKeyHook(combobox, ComboboxKeyHook);
		WindowSetDestroyHook(combobox, ComboboxDestroyHook);
		WindowSetSetFocusHook(combobox, ComboboxSetFocusHook);
		WindowSetKillFocusHook(combobox, ComboboxKillFocusHook);
		WindowSetMButtonHook(combobox, ComboboxMButtonHook);

		combobox->InstData = (COMBOBOXDATA*) malloc(sizeof(COMBOBOXDATA));
		((COMBOBOXDATA*)combobox->InstData)->Height = h;
		((COMBOBOXDATA*)combobox->InstData)->SetFocusHook    = NULL;
		((COMBOBOXDATA*)combobox->InstData)->KillFocusHook   = NULL;
		((COMBOBOXDATA*)combobox->InstData)->PreKeyHook      = NULL;
		((COMBOBOXDATA*)combobox->InstData)->PostKeyHook     = NULL;
		((COMBOBOXDATA*)combobox->InstData)->CbChangedHook   = NULL;
		((COMBOBOXDATA*)combobox->InstData)->CbChangingHook  = NULL;

		((COMBOBOXDATA*)combobox->InstData)->NumItems = 0;
		((COMBOBOXDATA*)combobox->InstData)->SelIndex = -1;
		((COMBOBOXDATA*)combobox->InstData)->CtrlSelIndex = -1;
		((COMBOBOXDATA*)combobox->InstData)->Sorted = ((flags & LB_SORTED) != 0);
		((COMBOBOXDATA*)combobox->InstData)->Descending = ((flags & LB_DESCENDING) != 0);
		((COMBOBOXDATA*)combobox->InstData)->FirstItem = NULL;
		((COMBOBOXDATA*)combobox->InstData)->LastItem = NULL;
		((COMBOBOXDATA*)combobox->InstData)->MouseDown = FALSE;
		((COMBOBOXDATA*)combobox->InstData)->DropdownState = FALSE;
		((COMBOBOXDATA*)combobox->InstData)->Ctrl = combobox;

		return combobox;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ComboboxSetSetFocusHook
 * Set custom callback 
 * ---------------------------------------------------------------------
 */
void 
ComboboxSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		((COMBOBOXDATA*)win->InstData)->SetFocusHook = proc;
		((COMBOBOXDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ComboboxSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
ComboboxSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		((COMBOBOXDATA*)win->InstData)->KillFocusHook = proc;
		((COMBOBOXDATA*)win->InstData)->KillFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ComboboxSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
ComboboxSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		((COMBOBOXDATA*)win->InstData)->PreKeyHook = proc;
		((COMBOBOXDATA*)win->InstData)->PreKeyTarget = target;
	}
}
 
 
/* ---------------------------------------------------------------------
 * ComboboxSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
ComboboxSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		((COMBOBOXDATA*)win->InstData)->PostKeyHook = proc;
		((COMBOBOXDATA*)win->InstData)->PostKeyTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * ComboboxSetCbChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */  
void 
ComboboxSetCbChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{       
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{                                               
		((COMBOBOXDATA*)win->InstData)->CbChangedHook = proc;
		((COMBOBOXDATA*)win->InstData)->CbChangedTarget = target;
	}
}
 
/* ---------------------------------------------------------------------
 * ComboboxSetCbChangingHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */  
void 
ComboboxSetCbChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target)
{       
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0)) 
	{                                                
		((COMBOBOXDATA*)win->InstData)->CbChangingHook = proc;
		((COMBOBOXDATA*)win->InstData)->CbChangingTarget = target;
	}
}
 
/* ---------------------------------------------------------------------
 * ComboboxAdd
 * Add an entry to the combo box control
 * ---------------------------------------------------------------------
 */
int
ComboboxAdd(CUIWINDOW* win, const wchar_t* text)
{       
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{       
		int index = 0;
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = (COMBOBOXITEM*) malloc(sizeof(COMBOBOXITEM));
                
		item->Next = NULL;
		item->Previous = NULL;
		item->ItemText = wcsdup(text);
		item->ItemData = 0;
                
		if (data->Sorted)
		{       
			COMBOBOXITEM* itemptr = (COMBOBOXITEM*) data->FirstItem;
			COMBOBOXITEM* previous = NULL;
			if (data->Descending)
			{       
				while (itemptr && (wcscmp(itemptr->ItemText, text) > 0))
				{       
					index++;
					previous = itemptr;
					itemptr = (COMBOBOXITEM*) itemptr->Next;
				}
			}
			else
			{       
				while (itemptr && (wcscmp(itemptr->ItemText, text) < 0))
				{       
					index++;
					previous = itemptr;
					itemptr = (COMBOBOXITEM*) itemptr->Next;
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
					((COMBOBOXITEM*) item->Next)->Previous = item;
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
					((COMBOBOXITEM*) item->Next)->Previous = item;
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
		return index;
	}
	return (-1);
}

/* ---------------------------------------------------------------------
 * ComboboxDelete
 * Delete an entry from the combo box control
 * ---------------------------------------------------------------------
 */
void
ComboboxDelete(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = ComboboxGetItem(data, index); 
		if (item)
		{
			data->NumItems--;
			if (data->LastItem == item)
			{
				data->LastItem = item->Previous;
			}
			if (data->CtrlSelIndex >= data->NumItems)
			{
				data->CtrlSelIndex--;
			}
                        
			if (item->Previous)
			{
				((COMBOBOXITEM*)item->Previous)->Next = item->Next;
			}
			else
			{   
				data->FirstItem = item->Next;
			}
			if (item->Next)
			{
				((COMBOBOXITEM*)item->Next)->Previous = item->Previous;
			}
			else
			{   
				data->LastItem = item->Previous;
			}
			free(item->ItemText);
			free(item);
		}
	}
}

/* ---------------------------------------------------------------------
 * ComboboxGet
 * Get item text of item 'index'
 * ---------------------------------------------------------------------
 */
const wchar_t*
ComboboxGet(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = ComboboxGetItem(data, index); 
		if (item)
		{
			return item->ItemText;
		}
	}
	return _T("");
}

/* ---------------------------------------------------------------------
 * ComboboxSetData
 * Associate data with an existing combo box entry
 * ---------------------------------------------------------------------
 */
void
ComboboxSetData(CUIWINDOW* win, int index, unsigned long udata)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = ComboboxGetItem(data, index); 
		if (item)
		{
			item->ItemData = udata;
		}
	}
}

/* ---------------------------------------------------------------------
 * ComboboxGetData
 * Read data from an existing list box entry
 * ---------------------------------------------------------------------
 */
unsigned long
ComboboxGetData(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = ComboboxGetItem(data, index); 
		if (item)
		{
			return item->ItemData;
		}
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * ComboboxSetSel
 * Set the selection (-1 == unselected)
 * ---------------------------------------------------------------------
 */
void
ComboboxSetSel(CUIWINDOW* win, int index)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		if ((index < data->NumItems) && (index >= (-1))) 
		{
			data->CtrlSelIndex = index;
			ComboboxUpdate(win);    
		}
	}
}

/* ---------------------------------------------------------------------
 * ListboxGetSel
 * Read the selection (-1 == unselected)
 * ---------------------------------------------------------------------
 */
int
ComboboxGetSel(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		return data->CtrlSelIndex;
	}
	return (-1);
}

/* ---------------------------------------------------------------------
 * ComboboxClear
 * Clear the entire list
 * ---------------------------------------------------------------------
 */
void
ComboboxClear(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = data->FirstItem;
		while (item)
		{
			data->FirstItem = (COMBOBOXITEM*) item->Next;
			free(item->ItemText);
			free(item);
			item = data->FirstItem;
		}
		data->NumItems = 0;
		data->CtrlSelIndex = (-1);
		data->LastItem = NULL;
                
		ComboboxUpdate(win); 
	}
}
  
/* ---------------------------------------------------------------------
 * ComboboxGetCount
 * Return the number of items in the list
 * ---------------------------------------------------------------------
 */
int
ComboboxGetCount(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		return data->NumItems;
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * ComboboxSelect
 * Select a specified string item
 * ---------------------------------------------------------------------
 */
int
ComboboxSelect(CUIWINDOW* win, const wchar_t* text)
{
	if (win && (wcscmp(win->Class, _T("COMBOBOX")) == 0))
	{
		COMBOBOXDATA* data = (COMBOBOXDATA*) win->InstData;
		COMBOBOXITEM* item = data->FirstItem;
		int index = 0;

		while (item)
		{
			if (wcscmp(item->ItemText, text) == 0)
			{
				data->CtrlSelIndex = index;
				ComboboxUpdate(win);
				return index;
			}
			index++;
			item = (COMBOBOXITEM*) item->Next;
		}
	}
	return -1;
}

/* local helper functions */

/* ---------------------------------------------------------------------
 * ComboboxGetItem
 * Get item of index
 * ---------------------------------------------------------------------
 */
static COMBOBOXITEM*
ComboboxGetItem(COMBOBOXDATA* data, int index)
{
	int i = 0;
	COMBOBOXITEM* result;
        
	if (index < 0)
	{
		return NULL;
	}
        
	result = data->FirstItem;
	while (result && (i < index))
	{
		i++;
		result = (COMBOBOXITEM*) result->Next;
	}
	return result;
}


/* ---------------------------------------------------------------------
 * ComboboxUpdate
 * Update combo view
 * ---------------------------------------------------------------------
 */
static void
ComboboxUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* ---------------------------------------------------------------------
 * ComboboxQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int
ComboboxQueryChange(CUIWINDOW* win, COMBOBOXDATA* data)
{
	if (data->CbChangingHook)
	{
		return data->CbChangingHook(data->CbChangingTarget, win);
	}
	return TRUE;
}
 
 
/* ---------------------------------------------------------------------
 * ComboboxNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void
ComboboxNotifyChange(CUIWINDOW* win, COMBOBOXDATA* data)
{
	if (data->CbChangedHook)
	{
		data->CbChangedHook(data->CbChangedTarget, win);
	}
}


/* ---------------------------------------------------------------------
 * ComboboxShowDropdown
 * Display dropdown window
 * ---------------------------------------------------------------------
 */
static void
ComboboxShowDropdown(CUIWINDOW* win, COMBOBOXDATA* data, int capture)
{
	CUIWINDOW* listbox;
	CUIRECT rc;
	int height;

	WindowGetWindowRect(win, &rc);

	height = ((data->NumItems + 2) > data->Height) ? data->Height : (data->NumItems + 2);
	if ((LINES - rc.Y) > height)
	{
		listbox = WindowNew(win, rc.X, rc.Y + 1, rc.W, height, 
			CWS_POPUP | CWS_BORDER | CWS_TABSTOP);
	}
	else if (rc.Y > (LINES / 2))
	{
		if (height > (rc.Y - 1))
		{
			height = rc.Y - 1;
		}
		listbox = WindowNew(win, rc.X, rc.Y - height - 1, rc.W, height, 
			CWS_POPUP | CWS_BORDER | CWS_TABSTOP);
	}
	else
	{
		if (height > (LINES - rc.Y - 1))
		{
			height = LINES - rc.Y - 1;
		}
		listbox = WindowNew(win, rc.X, rc.Y + 1, rc.W, height, 
			CWS_POPUP | CWS_BORDER | CWS_TABSTOP);
	}

	listbox->Class = _T("CBDROPDOWN");
	WindowSetPaintHook(listbox, CbDropdownPaintHook);
	WindowSetKeyHook(listbox, CbDropdownKeyHook);
	WindowSetMButtonHook(listbox, CbDropdownMButtonHook);
	WindowSetVScrollHook(listbox, CbDropdownVScrollHook);
	WindowSetSizeHook(listbox, CbDropdownSizeHook);
	WindowSetSetFocusHook(listbox, CbDropdownSetFocusHook);
	WindowSetKillFocusHook(listbox, CbDropdownKillFocusHook);
	WindowEnableVScroll(listbox, TRUE);

	listbox->InstData = (void*) data;
	data->SelIndex = data->CtrlSelIndex;
	data->MouseDown = capture;
	data->DropdownState = TRUE;
	data->CloseKey = 0;

	if (height > 0)
	{
		WindowCreate(listbox);
		if (capture)
		{
			WindowSetCapture(listbox);
		}
		WindowModal(listbox);
		WindowReleaseCapture();
	}
	WindowDestroy(listbox);

	data->DropdownState = FALSE;
	ComboboxUpdate(win);

	switch(data->CloseKey)
	{
	case KEY_TAB:
	case KEY_RIGHT:
		WindowFocusNext(win->Parent);
		break;
	case KEY_LEFT:
		WindowFocusPrevious(win->Parent);
		break;
	}
}

