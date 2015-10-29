#include "cui.h"
#include "global.h"

#define BUTWIDTH 10
#define BUTSPACE 11


typedef struct MSGDATAStruct
{
	const wchar_t* Text;          /* text to be displayed */
	int          TextWidth;
	int          TextHeight;
	int          Flags;
} MSGDATA;


/* ---------------------------------------------------------------------
 * YesNoDlgTextSize
 * Calculate required text size
 * ---------------------------------------------------------------------
 */
void
MsgCalcTextSize(const wchar_t* text, int max, int* w, int* h)
{
	int x = 0;
	int y = 0;
	int i, len;

	*w = 0;
	*h = 0;
	len = wcslen(text);

	for (i = 0; i < len; i++)
	{
		if (text[i] == _T('\n'))
		{
			if (x > *w)
			{
				*w = x;
			}
			x = 0;
			y++;
		}
		else
		{
			if ((x > max) && (max > 0))
			{
				if (x > *w)
				{
					*w = x;
				}
				x = 0;
				y++;
			}
			x++;
		}
	}
	if (x > *w)
	{
		*w = x;
	}
	*h = (y + 1);
}



void
MsgButtonHook(void* w, void* c)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = (CUIWINDOW*) c;

	WindowClose(win, ctrl->Id);
}


void
MsgCreateHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl;
	MSGDATA*   data = (MSGDATA*) win->InstData;
	int        x, y;
	int        defbutton = 1;

	x = win->Position.W / 2 - 1;
	y = win->Position.H - 3;
	
	ctrl = LabelNew(win, data->Text, 2, 1, data->TextWidth, data->TextHeight, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	if (data->Flags & MB_DEFBUTTON1)
	{
		defbutton = 2;
	}
	else if (data->Flags & MB_DEFBUTTON2)
	{
		defbutton = 3;
	}

	if (data->Flags & MB_YESNOCANCEL)
	{
		ctrl =  ButtonNew(win, _T("&Yes"), x - (3 * BUTSPACE) / 2, y, BUTWIDTH, 1, IDYES, 
			(defbutton == 1) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 1)
		{
			WindowSetFocus(ctrl);
		}

		ctrl =  ButtonNew(win, _T("&No"), x - BUTSPACE / 2, y, BUTWIDTH, 1, IDNO, 
			(defbutton == 2) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 2)
		{
			WindowSetFocus(ctrl);
		}

		ctrl =  ButtonNew(win, _T("&Cancel"), x + BUTSPACE / 2, y, BUTWIDTH, 1, IDCANCEL, 
			(defbutton == 3) ? CWS_DEFOK : CWS_DEFCANCEL, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 3)
		{
			WindowSetFocus(ctrl);
		}
	}
	else if (data->Flags & MB_YESNO)
	{
		ctrl =  ButtonNew(win, _T("&Yes"), x - BUTSPACE, y, BUTWIDTH, 1, IDYES, 
			(defbutton == 1) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 1)
		{
			WindowSetFocus(ctrl);
		}

		ctrl =  ButtonNew(win, _T("&No"), x, y, BUTWIDTH, 1, IDNO, 
			(defbutton == 2) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 2)
		{
			WindowSetFocus(ctrl);
		}
	}
	else if (data->Flags & MB_RETRYCANCEL)
	{
		ctrl =  ButtonNew(win, _T("&Retry"), x - BUTSPACE, y, BUTWIDTH, 1, IDRETRY, 
			(defbutton == 1) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 1)
		{
			WindowSetFocus(ctrl);
		}

		ctrl =  ButtonNew(win, _T("&Cancel"), x, y, BUTWIDTH, 1, IDCANCEL, 
			(defbutton == 2) ? CWS_DEFOK : CWS_DEFCANCEL, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 2)
		{
			WindowSetFocus(ctrl);
		}
	}
	else if (data->Flags & MB_OKCANCEL)
	{
		ctrl =  ButtonNew(win, _T("&Ok"), x - BUTSPACE, y, BUTWIDTH, 1, IDOK, 
			(defbutton == 1) ? CWS_DEFOK : CWS_NONE, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 1)
		{
			WindowSetFocus(ctrl);
		}

		ctrl =  ButtonNew(win, _T("&Cancel"), x, y, BUTWIDTH, 1, IDCANCEL, 
			(defbutton == 2) ? CWS_DEFOK : CWS_DEFCANCEL, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		if (defbutton == 2)
		{
			WindowSetFocus(ctrl);
		}
	}
	else
	{
		ctrl =  ButtonNew(win, _T("&OK"), x - BUTWIDTH / 2, y, BUTWIDTH, 1, IDOK, CWS_DEFOK, CWS_NONE);
		ButtonSetClickedHook(ctrl, MsgButtonHook, win);
		WindowCreate(ctrl);
		WindowSetFocus(ctrl);
	}
}


void
MsgDestroyHook(void* w)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	free(win->InstData);
}


int 
MessageBox(CUIWINDOW* parent, const wchar_t* text, const wchar_t* title, int flags)
{
	CUIWINDOW* msgwin;
	int result = 0;
	int fcolor = BLACK;
	int bcolor = LIGHTGRAY;
	int w, h;
	int buttons = 1;

	if (flags & MB_ERROR)
	{
		fcolor = WHITE;
		bcolor = RED;
	}
	else if (flags & MB_INFO)
	{
		fcolor = BLACK;
		bcolor = CYAN;
	}

	if (flags & MB_YESNO) buttons = 2;
	if (flags & MB_RETRYCANCEL) buttons = 2;
	if (flags & MB_YESNOCANCEL) buttons = 3;

	MsgCalcTextSize(text, COLS - 6, &w, &h);

	if (w < (buttons * 12 + 4))
	{
		w = buttons * 12 + 4;
	}

	msgwin = WindowNew(parent, 10, 10, w + 6, h + 5, CWS_POPUP | CWS_BORDER | CWS_CENTERED);
	msgwin->Color.WndTxtColor = fcolor;
	msgwin->Color.BorderColor = fcolor;
	msgwin->Color.WndColor = bcolor;

	msgwin->InstData = (MSGDATA*) malloc(sizeof(MSGDATA));
	((MSGDATA*)msgwin->InstData)->Text = text;
	((MSGDATA*)msgwin->InstData)->TextWidth = w;
	((MSGDATA*)msgwin->InstData)->TextHeight = h;
	((MSGDATA*)msgwin->InstData)->Flags = flags;

	WindowSetCreateHook(msgwin, MsgCreateHook);
	WindowSetDestroyHook(msgwin, MsgDestroyHook);
	WindowSetText(msgwin, title);

	WindowCreate(msgwin);
	result = WindowModal(msgwin);
	WindowDestroy(msgwin);

	WindowUpdate();

	return result;
}

