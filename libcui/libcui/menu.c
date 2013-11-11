/* ---------------------------------------------------------------------
 * File: menu.c
 * (menu control with keyboard input)
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

#define INPUT_SIZE 3

typedef struct MENUDATAStruct
{
	MENUITEM*     FirstItem;
	MENUITEM*     LastItem;
	MENUITEM*     SelItem;
	int           NumItems; 
	int           DragMode;
	wchar_t         InputBuffer[INPUT_SIZE + 1];
	int           InputPos;
	
	CustomHook1PtrProc      SetFocusHook;        /* Custom callback */
	CustomHookProc          KillFocusHook;       /* Custom callback */
	CustomBoolHook1IntProc  PreKeyHook;          /* Custom callback */
	CustomBoolHook1IntProc  PostKeyHook;         /* Custom callback */
	CustomHookProc          MenuChangedHook;     /* Custom callback */
	CustomBoolHookProc      MenuChangingHook;    /* Custom callback */
	CustomHookProc          MenuClickedHook;     /* Custom callback */
	CustomHookProc          MenuEscapeHook;      /* Custom callback */
	CUIWINDOW*              SetFocusTarget;      /* Custom callback target */
	CUIWINDOW*              KillFocusTarget;     /* Custom callback target */
	CUIWINDOW*              PreKeyTarget;        /* Custom callback target */
	CUIWINDOW*              PostKeyTarget;       /* Custom callback target */
	CUIWINDOW*              MenuChangedTarget;   /* Custom callback target */
	CUIWINDOW*              MenuChangingTarget;  /* Custom callback target */
	CUIWINDOW*              MenuClickedTarget;   /* Custom callback target */
	CUIWINDOW*              MenuEscapeTarget;    /* Custom callback target */
	int                     MouseDown;           /* Mouse button down */
} MENUDATA;


static int       MenuMoveItems(MENUITEM* target, MENUITEM* source);
static MENUITEM* MenuGetItemById(CUIWINDOW* win, unsigned long id);
static MENUITEM* MenuGetItemByIndex(CUIWINDOW* win, int index);
static void      MenuClearInputBuffer(CUIWINDOW* win);
static void      MenuShowLine(CUIWINDOW* win, MENUITEM* item, int ypos, CUIRECT* rc);
static void      MenuShowInputField(CUIWINDOW* win, CUIRECT* rc);
static void      MenuCalcPos(CUIWINDOW* win);
static void      MenuUpdate(CUIWINDOW* win);
static int       MenuQueryChange(CUIWINDOW* win, MENUDATA* data);
static void      MenuNotifyChange(CUIWINDOW* win, MENUDATA* data);


/* ---------------------------------------------------------------------
 * MenuNcPaintHook
 * Handle PAINT events by redrawing the control
 * ---------------------------------------------------------------------
 */
static void
MenuNcPaintHook(void* w, int size_x, int size_y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIRECT    rc;

	rc.W = size_x;
	rc.H = size_y;
	rc.X = 0;
	rc.Y = 0;

	if ((rc.W <= 0)||(rc.H <= 0)) return;
	box(win->Frame, 0, 0);

	if (rc.H > 2)
	{
		mvwaddch(win->Frame, 2, 0, ACS_LTEE);
		mvwaddch(win->Frame, 2, rc.W - 1, ACS_RTEE);
	}

	if (win->HasVScroll && (size_y > 2))
	{
		WindowPaintVScroll(win, 1, size_y - 2);
	}
}


/* ---------------------------------------------------------------------
 * MenuPaintHook
 * Handle PAINT events by redrawing the control
 * ---------------------------------------------------------------------
 */
static void
MenuPaintHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	CUIRECT      rc;
	MENUDATA*    data;
	MENUITEM*    item;
	int          pos;
	int          index;
	int          y;

	data = (MENUDATA*) win->InstData;
	if (!data) return;

	WindowGetClientRect(win, &rc);
	if ((rc.W <= 0)||(rc.H <= 0)) return;

	pos = WindowGetVScrollPos(win);
	index  = 0;
	y      = 2;

	item = data->FirstItem;
	while (item && (y < rc.H)) 
	{
		if (index >= pos) 
		{
			MenuShowLine(win, item, y, &rc);
			y++;
		}
		index++;
		item = (MENUITEM*) item->Next;
	}
        MenuShowInputField(win, &rc);
}


/* ---------------------------------------------------------------------
 * MenuSizeHook
 * Handle EVENT_SIZE events
 * ---------------------------------------------------------------------
 */
static int 
MenuSizeHook(void* w)
{
	MenuCalcPos((CUIWINDOW*) w);
	return TRUE;
}


/* ---------------------------------------------------------------------
 * MenuKeyHook
 * Handle EVENT_KEY events
 * ---------------------------------------------------------------------
 */
static int
MenuKeyHook(void* w, int key)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;
	MENUDATA*    data = (MENUDATA*) win->InstData;
	CUIRECT      rc;
	MENUITEM*    olditem;

        if (!data) return FALSE;

	if (win->IsEnabled)
	{
		int count;

		/* if the key is processed by the custom callback hook, we
		   are over and done with it, else processing continues */
		if (data->PreKeyHook)
		{
			if (data->PreKeyHook(data->PreKeyTarget, win, key))
			{
				return TRUE;
			}
		}

		olditem = data->SelItem;
		switch(key)
		{
		case KEY_UP:
			if (data->SelItem)
			{
				MENUITEM* oldselect = data->SelItem;
				do
				{
					if (data->SelItem->Previous)
					{
						data->SelItem = (MENUITEM*) data->SelItem->Previous;
					}
					else
					{
						data->SelItem = oldselect;
						break;
					}
				}
				while (data->SelItem->IsSeparator != 0);
			}
			else
			{
				data->SelItem = data->FirstItem;
				while (data->SelItem && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Next;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_DOWN:
			if (data->SelItem)
			{
				MENUITEM* oldselect = data->SelItem;
				do
				{
					if (data->SelItem->Next)
					{
						data->SelItem = (MENUITEM*) data->SelItem->Next;
					}
					else
					{
						data->SelItem = oldselect;
						break;
					}
				}
				while (data->SelItem->IsSeparator != 0);
			}
			else
			{
				data->SelItem = data->FirstItem;
				while (data->SelItem && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Next;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_PPAGE:
			count = rc.H - 2;
			if (data->SelItem)
			{
				MENUITEM* oldselect = data->SelItem;
				do
				{
					if (data->SelItem->Previous)
					{
						data->SelItem = (MENUITEM*) data->SelItem->Previous;
					}
					else
					{
						data->SelItem = oldselect;
						break;
					}
					if (data->SelItem->IsSeparator == 0)
					{
						oldselect = data->SelItem;
					}
					count--;
				}
				while ((data->SelItem->IsSeparator != 0)||(count > 0));
			}
			else
			{
				data->SelItem = data->FirstItem;
				while (data->SelItem && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Next;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_NPAGE:
			count = rc.H - 2;
			if (data->SelItem)
			{
				MENUITEM* oldselect = data->SelItem;
				do
				{
					if (data->SelItem->Next)
					{
						data->SelItem = (MENUITEM*) data->SelItem->Next;
					}
					else
					{
						data->SelItem = oldselect;
						break;
					}
					if (data->SelItem->IsSeparator == 0)
					{
						oldselect = data->SelItem;
					}
					count--;
				}
				while ((data->SelItem->IsSeparator != 0) || (count > 0));
			}
			else
			{
				data->SelItem = data->FirstItem;
				while (data->SelItem && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Next;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_HOME:
			data->SelItem = data->FirstItem;
			if (data->SelItem)
			{
				while (data->SelItem->Next && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Next;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}			
			return TRUE;
		case KEY_END:
			data->SelItem = data->LastItem;
			if (data->SelItem)
			{
				while (data->SelItem->Previous && data->SelItem->IsSeparator)
				{
					data->SelItem = (MENUITEM*) data->SelItem->Previous;
				}
			}
			if (data->DragMode)
			{
				if (!MenuMoveItems(data->SelItem, olditem))
				{
					data->SelItem = olditem;
				}
			}
			else if ((olditem) && (data->SelItem != olditem))
			{
				if (!MenuQueryChange(win, data))
				{
					data->SelItem = olditem;
				}
			}
			if (data->SelItem != olditem)
			{
				MenuClearInputBuffer(win);
				MenuCalcPos(win);
				MenuUpdate(win);
				if (!data->DragMode)
				{
					MenuNotifyChange(win, data);
				}
			}
			return TRUE;
		case KEY_BACKSPACE:
			if (data->InputPos > 0)
			{
				int   itemid;
				wchar_t oldch;
				MENUITEM* newsel;

				data->InputPos--;
				oldch = data->InputBuffer[data->InputPos];
				data->InputBuffer[data->InputPos] = 0;
				if (data->InputPos > 0)
				{
					swscanf(data->InputBuffer,_T("%d"),&itemid);
					newsel = MenuGetItemById(win, itemid);
					if (newsel)
					{
						data->SelItem = newsel;
					}
				}
				else data->SelItem = data->FirstItem;

				if (data->DragMode)
				{
					if (!MenuMoveItems(data->SelItem, olditem))
					{
						data->SelItem = olditem;
					}
				}
				else if ((olditem) && (data->SelItem != olditem))
				{
					if (!MenuQueryChange(win, data))
					{
						data->SelItem = olditem;
					}
				}
				if (data->SelItem != olditem)
				{
					MenuCalcPos(win);
					MenuUpdate(win);
					if (!data->DragMode)
					{
						MenuNotifyChange(win, data);
					}
				}
				else
				{
					data->InputBuffer[data->InputPos] = oldch;
					data->InputPos++;
				}
			}
			return TRUE;
		case KEY_SPACE:
		case KEY_RETURN:
			if (data->SelItem && data->MenuClickedHook)
			{
				data->MenuClickedHook(data->MenuClickedTarget, win);
			}
			MenuClearInputBuffer(win);
			return TRUE;
		case KEY_ESC:
			if (data->SelItem && data->MenuEscapeHook)
			{
				data->MenuEscapeHook(data->MenuEscapeTarget, win);
			}
			MenuClearInputBuffer(win);
			return TRUE;
		default:
			if ((key >= _T('0')) && (key <= _T('9')))
			{
				int itemid;
				MENUITEM* newsel;

				data->InputBuffer[data->InputPos++] = key;
				data->InputBuffer[data->InputPos] = 0;

				swscanf(data->InputBuffer,_T("%d"),&itemid);

				newsel = MenuGetItemById(win, itemid);
				if (newsel)
				{
					if (newsel != data->SelItem)
					{
						data->SelItem = newsel;
						if (data->DragMode)
						{
							if (!MenuMoveItems(data->SelItem, olditem))
							{
								data->SelItem = olditem;
							}
						}
						else if ((olditem) && (data->SelItem != olditem))
						{
							if (!MenuQueryChange(win, data))
							{
								data->SelItem = olditem;
							}
						}
						if (data->SelItem != olditem)
						{
							MenuCalcPos(win);
							MenuUpdate(win);
							if (!data->DragMode)
							{
								MenuNotifyChange(win, data);
							}
						}
						else
						{
							data->InputPos--;
							data->InputBuffer[data->InputPos] = 0;
						}
					}
				}
				else
				{
					data->InputPos--;
					data->InputBuffer[data->InputPos] = 0;
				}
				return TRUE;
			}
			else if (data->PostKeyHook)
			{
				if (data->PostKeyHook(data->PostKeyTarget, win, key))
				{
					return TRUE;
				}   
			}
			break;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * MenuMButtonHook
 * Button mouse click hook
 * ---------------------------------------------------------------------
 */
static void
MenuMButtonHook(void* w, int x, int y, int flags)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MENUDATA* data = (MENUDATA*) win->InstData;
	if ((flags & BUTTON1_CLICKED) || (flags & BUTTON1_DOUBLE_CLICKED))
	{
		MENUITEM* newitem;
		int offsy = WindowGetVScrollPos(win);
		int nochange = FALSE;

		y += offsy - 2;

		WindowReleaseCapture();

		newitem = MenuGetItemByIndex(win, y);
		if (newitem && !newitem->IsSeparator && !data->DragMode)
		{
			if (data->SelItem != newitem)
			{
				if (MenuQueryChange(win, data))
				{
					data->SelItem = newitem;
					MenuUpdate(win);
					MenuNotifyChange(win, data);
				}
				else
				{
					nochange = TRUE;
				}
			}
			if (!nochange && data->MenuClickedHook)
			{
				data->MenuClickedHook(data->MenuClickedTarget, win);
			}
		}
	}
	else if (flags & BUTTON1_PRESSED)
	{
		CUIRECT rc;
		WindowGetClientRect(win, &rc);

		data->MouseDown = TRUE;
		WindowSetCapture(win);

		if ((x >= rc.X) && (x < (rc.X + rc.W)) &&
		    (y >= rc.Y) && (y < (rc.Y + rc.H)))
		{
			MENUITEM* newitem;
			int offsy = WindowGetVScrollPos(win);

			y += offsy - 2;

			newitem = MenuGetItemByIndex(win, y);
			if (newitem && !newitem->IsSeparator && !data->DragMode)
			{
				if (data->SelItem != newitem)
				{
					if (MenuQueryChange(win, data))
					{
						data->SelItem = newitem;
						MenuUpdate(win);
						MenuNotifyChange(win, data);
					}
				}
			}
		}
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
			MENUITEM* newitem;
			int offsy = WindowGetVScrollPos(win);

			y += offsy - 2;

			newitem = MenuGetItemByIndex(win, y);
			if (newitem == data->SelItem)
			{
				data->MenuClickedHook(data->MenuClickedTarget, win);
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * MenuVScrollHook
 * Menu scroll bar mouse hook
 * ---------------------------------------------------------------------
 */
static void
MenuVScrollHook(void* w, int sbcode, int pos)
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
			sbpos -= (rc.H - 3);
			sbpos = (sbpos < 0) ? 0 : sbpos;
			WindowSetVScrollPos(win, sbpos);
			WindowInvalidate(win);
		}
		break;
	case SB_PAGEDOWN:
		if (sbpos < range)
		{
			sbpos += (rc.H - 3);
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
 * MenuDestroyHook
 * Handle EVENT_DELETE events by deleting the control's data
 * ---------------------------------------------------------------------
 */
static void
MenuDestroyHook(void* w)
{
	CUIWINDOW*   win = (CUIWINDOW*) w;

	MenuClear(win);

	free (win->InstData);
}


/* ---------------------------------------------------------------------
 * MenuSetFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
MenuSetFocusHook(void* w, void* lastfocus)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MENUDATA* data = (MENUDATA*) win->InstData;

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
 * MenuKillFocusHook
 * Handle EVENT_SETFOCUS events
 * ---------------------------------------------------------------------
 */
static void
MenuKillFocusHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	MENUDATA* data = (MENUDATA*) win->InstData;

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
 * MenuNew
 * Create a new menu control
 * ---------------------------------------------------------------------
 */
CUIWINDOW*
MenuNew(CUIWINDOW* parent, const wchar_t* text, int x, int y, int w, int h, 
           int id, int sflags, int cflags)
{
	if (parent)
	{
		CUIWINDOW* menu;
		int flags = sflags | CWS_TABSTOP | CWS_BORDER;
		flags &= ~(cflags);

		menu = WindowNew(parent, x, y, w, h, flags);
		menu->Class = _T("MENU");
		WindowColScheme(menu, _T("MENU"));
		WindowSetId(menu, id);
		WindowSetNcPaintHook(menu, MenuNcPaintHook);
		WindowSetPaintHook(menu, MenuPaintHook);
		WindowSetKeyHook(menu, MenuKeyHook);
		WindowSetSetFocusHook(menu, MenuSetFocusHook);
		WindowSetKillFocusHook(menu, MenuKillFocusHook);
		WindowSetSizeHook(menu, MenuSizeHook);
		WindowSetDestroyHook(menu, MenuDestroyHook);
		WindowSetMButtonHook(menu, MenuMButtonHook);
		WindowSetVScrollHook(menu, MenuVScrollHook);

		menu->InstData = (MENUDATA*) malloc(sizeof(MENUDATA));
		((MENUDATA*)menu->InstData)->SetFocusHook    = NULL;
		((MENUDATA*)menu->InstData)->KillFocusHook   = NULL;
		((MENUDATA*)menu->InstData)->PreKeyHook      = NULL;   
		((MENUDATA*)menu->InstData)->PostKeyHook     = NULL; 
		((MENUDATA*)menu->InstData)->MenuChangedHook   = NULL;
		((MENUDATA*)menu->InstData)->MenuChangingHook  = NULL;
		((MENUDATA*)menu->InstData)->MenuClickedHook   = NULL;
		((MENUDATA*)menu->InstData)->MenuEscapeHook   = NULL;

		((MENUDATA*)menu->InstData)->FirstItem = NULL;
		((MENUDATA*)menu->InstData)->LastItem = NULL;
		((MENUDATA*)menu->InstData)->SelItem = NULL;
		((MENUDATA*)menu->InstData)->NumItems = 0;
		((MENUDATA*)menu->InstData)->DragMode = FALSE;
		((MENUDATA*)menu->InstData)->InputBuffer[0] = 0;
		((MENUDATA*)menu->InstData)->InputPos = 0;
		((MENUDATA*)menu->InstData)->MouseDown = FALSE;

		WindowSetText(menu, text);

		return menu;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * MenuSetSetFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
MenuSetSetFocusHook (CUIWINDOW* win, CustomHook1PtrProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->SetFocusHook = proc;
		((MENUDATA*)win->InstData)->SetFocusTarget = target;
	}
}

/* ---------------------------------------------------------------------
 * MenuSetKillFocusHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
MenuSetKillFocusHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->KillFocusHook = proc;
		((MENUDATA*)win->InstData)->KillFocusTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuSetPreKeyHook
 * Set custom callback  
 * ---------------------------------------------------------------------
 */
void
MenuSetPreKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->PreKeyHook = proc;
		((MENUDATA*)win->InstData)->PreKeyTarget = target;
	}
}
 
 
/* ---------------------------------------------------------------------
 * MenuSetPostKeyHook
 * Set custom callback   
 * ---------------------------------------------------------------------
 */
void
MenuSetPostKeyHook(CUIWINDOW* win, CustomBoolHook1IntProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->PostKeyHook = proc;
		((MENUDATA*)win->InstData)->PostKeyTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuSetMenuChangedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
MenuSetMenuChangedHook (CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->MenuChangedHook = proc;
		((MENUDATA*)win->InstData)->MenuChangedTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuSetMenuChangingHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
MenuSetMenuChangingHook(CUIWINDOW* win, CustomBoolHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->MenuChangingHook = proc;
		((MENUDATA*)win->InstData)->MenuChangingTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuSetMenuClickedHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void
MenuSetMenuClickedHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->MenuClickedHook = proc;
		((MENUDATA*)win->InstData)->MenuClickedTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuSetMenuEscapeHook
 * Set custom callback
 * ---------------------------------------------------------------------
 */
void 
MenuSetMenuEscapeHook(CUIWINDOW* win, CustomHookProc proc, CUIWINDOW* target)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		((MENUDATA*)win->InstData)->MenuEscapeHook = proc;
		((MENUDATA*)win->InstData)->MenuEscapeTarget = target;
	}
}


/* ---------------------------------------------------------------------
 * MenuAddItem
 * Add an item to the menu
 * ---------------------------------------------------------------------
 */
void 
MenuAddItem(CUIWINDOW* win, const wchar_t* text, unsigned long id, int moveable)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		MENUITEM* newitem = (MENUITEM*) malloc(sizeof(MENUITEM));

		newitem->ItemText = wcsdup(text);
		newitem->IsSeparator = FALSE;
		newitem->IsMoveable = moveable;
		newitem->Next = NULL;
		newitem->Previous = NULL;
		newitem->ItemId = id;

		if (data->LastItem)
                {
			data->LastItem->Next = (void*) newitem;
			newitem->Previous = (void*) data->LastItem;
		}
		else
		{
			data->FirstItem = newitem;
		}
		data->LastItem = newitem;
		data->NumItems++;

		MenuCalcPos(win);
		MenuUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * MenuAddSeparator
 * Add a seperator to the menu
 * ---------------------------------------------------------------------
 */
void 
MenuAddSeparator(CUIWINDOW* win, int moveable)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		MENUITEM* newitem = (MENUITEM*) malloc(sizeof(MENUITEM));

		newitem->ItemText = NULL;
		newitem->IsSeparator = TRUE;
		newitem->IsMoveable = moveable;
		newitem->Next = NULL;
		newitem->Previous = NULL;
		newitem->ItemId = 0;

		if (data->LastItem)
                {
			data->LastItem->Next = (void*) newitem;
			newitem->Previous = (void*) data->LastItem;
		}
		else
		{
			data->FirstItem = newitem;
		}
		data->LastItem = newitem;
		data->NumItems++;

		MenuCalcPos(win);
		MenuUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * MenuSelectItem
 * Select an item within the menu by it's id
 * ---------------------------------------------------------------------
 */
void
MenuSelectItem(CUIWINDOW* win, unsigned long id)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;

		data->SelItem = MenuGetItemById(win, id);
		if (!data->SelItem)
		{
			data->SelItem = data->FirstItem;
			while (data->SelItem && data->SelItem->IsSeparator)
			{
				data->SelItem = (MENUITEM*) data->SelItem->Next;
			}
		}
		MenuCalcPos(win);
		MenuUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * MenuGetSelectedItem
 * Return the currently selected item. If no item is selected, NULL is
 * returned
 * ---------------------------------------------------------------------
 */
MENUITEM*
MenuGetSelectedItem(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		if (data->SelItem)
		{
			return data->SelItem;
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MenuGetItems
 * Return the first menu item 
 * ---------------------------------------------------------------------
 */
MENUITEM* 
MenuGetItems(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		return data->FirstItem;
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MenuSetDragMode
 * Switch drag mode on or off. In drag mode, the menu items can be
 * rearranged by the user
 * ---------------------------------------------------------------------
 */
void 
MenuSetDragMode(CUIWINDOW* win, int state)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		data->DragMode = state;
		MenuUpdate(win);
	}
}


/* ---------------------------------------------------------------------
 * MenuClear
 * Remove all menu items from the menu
 * ---------------------------------------------------------------------
 */
void 
MenuClear(CUIWINDOW* win)
{
	if (win && (wcscmp(win->Class, _T("MENU")) == 0))
	{
		MENUDATA* data = (MENUDATA*) win->InstData;
		MENUITEM* item = data->FirstItem;
		while (item)
		{
			data->FirstItem = (MENUITEM*) item->Next;
			if (!item->IsSeparator) free(item->ItemText);
			free(item);
			item = data->FirstItem;
		}
		data->LastItem = NULL;
		data->SelItem = NULL;

		MenuCalcPos(win);
		MenuUpdate(win);
	}
}




/* helper functions */

/* ---------------------------------------------------------------------
 * MenuMoveItems
 * Move items up or down when in drag mode
 * ---------------------------------------------------------------------
 */
static int 
MenuMoveItems(MENUITEM* target, MENUITEM* source)
{
	if (target && source && (target != source))
	{
		if (!target->IsMoveable || !target->IsMoveable)
		{
			return FALSE;
		}
		else
		{
			MENUITEM* workptr;
			wchar_t* sourcetext = source->ItemText;
			int   sourcetyp  = source->IsSeparator;
			int   down = FALSE;

			/* check if we have to move up or down */
			workptr = source;
			while (workptr)
			{
				if (workptr == target)
				{
					down = TRUE;
					break;
				}
				workptr = (MENUITEM*) workptr->Next;
			}

			if (down)
			{
				workptr = source;
				do
				{
					workptr->ItemText = ((MENUITEM*)workptr->Next)->ItemText;
					workptr->IsSeparator = ((MENUITEM*)workptr->Next)->IsSeparator;

					workptr = (MENUITEM*) workptr->Next;
				}
				while (workptr != target);

				workptr->ItemText = sourcetext;
				workptr->IsSeparator = sourcetyp;
			}
			else
			{
				workptr = source;
				do
				{
					workptr->ItemText = ((MENUITEM*)workptr->Previous)->ItemText;
					workptr->IsSeparator = ((MENUITEM*)workptr->Previous)->IsSeparator;

					workptr = (MENUITEM*) workptr->Previous;
				}
				while (workptr != target);

				workptr->ItemText = sourcetext;
				workptr->IsSeparator = sourcetyp;
			}
                }
        }
        return TRUE;
}


/* ---------------------------------------------------------------------
 * MenuClearInputBuffer
 * The buffer for number input is cleared.
 * ---------------------------------------------------------------------
 */
static void
MenuClearInputBuffer(CUIWINDOW* win)
{
	MENUDATA* data = (MENUDATA*) win->InstData;
	if (data)
	{
		data->InputBuffer[0] = 0;
		data->InputPos = 0;
	}
}


/* ---------------------------------------------------------------------
 * MenuGetItemById
 * Search for a menu item that has the given value (parameter id) stored
 * in it's 'ItemId' member.
 * ---------------------------------------------------------------------
 */
static MENUITEM*
MenuGetItemById(CUIWINDOW* win, unsigned long id)
{
	MENUDATA* data = (MENUDATA*) win->InstData;
	MENUITEM* workptr = NULL;
	if (data)
	{
		workptr = data->FirstItem;
		while (workptr)
		{
			if ((workptr->IsSeparator == 0) && (workptr->ItemId == id))
			{
				return workptr;
			}
			workptr = workptr->Next;
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MenuGetItemByIndex
 * Search for a menu item by it's line index. Separators are handeled
 * like menu items here.
 * ---------------------------------------------------------------------
 */
static MENUITEM*
MenuGetItemByIndex(CUIWINDOW* win, int index)
{
	MENUDATA* data = (MENUDATA*) win->InstData;
	MENUITEM* workptr = NULL;
	if (data)
	{
		int i = 0;

		workptr = data->FirstItem;
		while (workptr)
		{
			if (i == index)
			{
				return workptr;
			}
			i++;
			workptr = workptr->Next;
		}
	}
	return NULL;
}


/* ---------------------------------------------------------------------
 * MenuShowLine (display helper)
 * Print a menu item at the position 'ypos' on the screen clipped by
 * the area specified by the 'menu'-structure
 * ---------------------------------------------------------------------
 */
static void
MenuShowLine(CUIWINDOW* win, MENUITEM* item, int ypos, CUIRECT* rc)
{
	MENUDATA* data = (MENUDATA*) win->InstData;
	WINDOW*   w = win->Win;
	int       len, x;
	wchar_t     id[INPUT_SIZE + 8 + 1];

	if (item->IsSeparator) return;

	len = wcslen(item->ItemText);

	SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	if (item == data->SelItem)
	{
		SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
	}

	swprintf(id, INPUT_SIZE + 8, _T("%lu"), item->ItemId);

	if ((data->DragMode) && (item == data->SelItem))
	{
		MOVEYX(w, ypos, 0);
		for (x = 0; x < rc->W; x++)
		{
			if (x == 1)
			{
				SetColor(w, win->Color.HilightColor, win->Color.WndSelColor, TRUE);
				PRINT(w, _T(">"));
			}
			else if ((x > 2) && (x <= (len + 2)) && (x < (rc->W - 2)))
			{
				SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor, TRUE);
				PRINTN(w, &item->ItemText[x - 3], 1);
			}
			else if (x == (rc->W - 2))
			{
				SetColor(w, win->Color.HilightColor, win->Color.WndSelColor, TRUE);
				PRINT(w, _T("<"));
			}
			else
			{
				PRINT(w, _T(" "));
			}
		}
	}
	else
	{
		MOVEYX(w, ypos, 0);
		for (x = 0; x < rc->W; x++)
		{
			if ((x > 0) && (x <= INPUT_SIZE))
			{
				if ((x - 1) < (int)wcslen(id))
				{
					SetColor(w, win->Color.HilightColor, win->Color.WndColor, FALSE);
					if (item == data->SelItem)
					{
						SetColor(w, win->Color.HilightColor, win->Color.WndSelColor, TRUE);
					}
					PRINTN(w, &id[x - 1], 1);
				}
				else
				{
					PRINT(w, _T(" "));
				}
			}
			else if ((x >= INPUT_SIZE + 2) && (x < (len + INPUT_SIZE + 2)))
			{
				SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
				if (item == data->SelItem)
				{
					SetColor(w, win->Color.SelTxtColor, win->Color.WndSelColor,TRUE);
				}
				PRINTN(w, &item->ItemText[x - (INPUT_SIZE + 2)], 1);
			}
			else 
			{
				PRINT(w, _T(" "));
			}
		}
	}
}


/* ---------------------------------------------------------------------
 * MenuShowInputField (display helper)
 * Print the 'edit'-field on the top of the menu, where the user's
 * keyboard input (id-selection) is displayed
 * ---------------------------------------------------------------------
 */
static void
MenuShowInputField(CUIWINDOW* win, CUIRECT* rc)
{
	MENUDATA* data = (MENUDATA*) win->InstData;
	WINDOW*   w = win->Win;
	wchar_t     id[INPUT_SIZE + 8];
	int       len;
	int       x;
	int       offset = wcslen(win->Text) + 3;

	/* show title */
	len = wcslen(win->Text);
	if (len > (rc->W - 2))
	{
		len = rc->W - 2;
	}
	if (win->IsEnabled)
	{
		SetColor(w, win->Color.WndTxtColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}

	MOVEYX(w, 0, 1); PRINTN(w, win->Text, len);

	/* show field separator */
	if (win->IsEnabled)
	{
		SetColor(w, win->Color.BorderColor, win->Color.WndColor, FALSE);
	}
	else
	{
		SetColor(w, win->Color.InactTxtColor, win->Color.WndColor, FALSE);
	}
	if (rc->H > 1)
	{
		MOVEYX(w, 1, 0);
		for (x = 0; x < rc->W; x++)
		{
			waddch(w, ACS_HLINE);
		}
	}

	/* show number */
	if (data->SelItem)
	{
		swprintf(id, INPUT_SIZE + 8, _T("%lu"), data->SelItem->ItemId);
	}
	else id[0] = 0;

	len = wcslen(id);

	SetColor(w, win->Color.HilightColor, win->Color.WndColor, FALSE);

	MOVEYX(w, 0, offset);
	for (x = offset; x < offset + INPUT_SIZE; x++)
	{
		if (x < rc->W)
		{
			if (x - offset < len)
			{
				PRINTN(w, &id[x - offset], 1);
			}
			else 
			{
				PRINT(w, _T("."));
			}
		}
	}
	WindowSetCursor(win, offset + data->InputPos, 0);
}


/* ---------------------------------------------------------------------
 * MenuCalcPos
 * Recalculate menu position
 * ---------------------------------------------------------------------
 */
static void
MenuCalcPos(CUIWINDOW* win)
{
	CUIRECT      rc;
	MENUDATA*    data = (MENUDATA*) win->InstData;
	int          range;
	int          pos;
	int          height;

	if (!data) return;
	if (win->IsCreated)
	{
		WindowGetClientRect(win, &rc);

		height = rc.H - 2;
		range = (data->NumItems - height);
		if (range <= 0)
		{
			WindowEnableVScroll(win, FALSE);
			WindowSetVScrollRange(win, 0);
			WindowSetVScrollPos(win, 0);
		}
		else
		{
			int index = 0;
			if (data->SelItem)
			{
				MENUITEM* seekptr = data->FirstItem;
				while (seekptr)
				{
					if (seekptr == data->SelItem)
					{
						break;
					}
					index++;
					seekptr = (MENUITEM*) seekptr->Next;
				}
			}

			WindowSetVScrollRange(win, range);

			pos = WindowGetVScrollPos(win);
			if (index < 0)
			{
				WindowSetVScrollPos(win, 0);
			}
			else if (index - pos >= height)
			{
				WindowSetVScrollPos(win, index - height + 1);
			}
			else if (index - pos < 0)
			{
				WindowSetVScrollPos(win, index);
			}
			WindowEnableVScroll(win, TRUE);
		}
	}
}


/* ---------------------------------------------------------------------
 * MenuUpdate
 * Update listbox view
 * ---------------------------------------------------------------------
 */
static void
MenuUpdate(CUIWINDOW* win)
{
	if (win->IsCreated)
	{
		WindowInvalidate(win);
	}
}


/* ---------------------------------------------------------------------
 * MenuQueryChange
 * May the selection be changed?
 * ---------------------------------------------------------------------
 */
static int  
MenuQueryChange(CUIWINDOW* win, MENUDATA* data)
{
	if (data->MenuChangingHook)
	{
		return data->MenuChangingHook(data->MenuChangingTarget, win);
	}
	return TRUE;
}


/* ---------------------------------------------------------------------
 * MenuNotifyChange
 * Notify application about a selection change
 * ---------------------------------------------------------------------
 */
static void 
MenuNotifyChange(CUIWINDOW* win, MENUDATA* data)
{
	if (data->MenuChangedHook)
	{
		data->MenuChangedHook(data->MenuChangedTarget, win);
	}
}


