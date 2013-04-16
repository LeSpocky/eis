#include "cui.h"
#include "cui-util.h"

#define IDC_OK     1
#define IDC_CANCEL 2
#define IDC_EDIT1 100
#define IDC_EDIT2 101
#define IDC_EDIT3 102
#define IDC_RADIO1 103
#define IDC_RADIO2 104
#define IDC_CHKBOX1 105
#define IDC_LISTBOX1 106
#define IDC_PROGRESS 107
#define IDC_COMBO1 108
#define IDC_LISTBUT 109
#define IDC_LISTVIEW 200

void quit(void)
{
	WindowEnd();
} 


int ListKeyHook(void* w, void* c, int key)
{
	if (key == KEY_RETURN)
	{
		WindowClose(c, IDOK);
		return TRUE;
	}
	return FALSE;
}

void ListTimerHook(void* c, int id)
{
	static int loop = 0;
	wchar_t buffer[32 + 1];
	
	swprintf(buffer, 32, _T("Text%i"), loop);
	
	LISTREC* rec = ListviewCreateRecord(c);
	if (rec)
	{
		
		ListviewSetColumnText(rec, 0, buffer);
		ListviewSetColumnText(rec, 1, buffer);
		ListviewSetColumnText(rec, 2, buffer);
		ListviewSetColumnText(rec, 3, buffer);
		ListviewInsertRecord(c, rec);
		
		loop++;
	}
}


void OkButtonHook(void* w, void* c)
{
	MessageBox(w, _T("Exit Application!"), _T("Message"), MB_NORMAL);
	MessageBox(w, _T("Exit Application!"), _T("Info"), MB_INFO);
	MessageBox(w, _T("This is a multiline\nerror message!)"), _T("Error"), MB_ERROR);

	MessageBox(w, _T("Exit Application!"), _T("Message"), MB_YESNOCANCEL);
	MessageBox(w, _T("Exit Application!"), _T("Info"), MB_YESNO);
	MessageBox(w, _T("Exit Application!"), _T("Error"), MB_OK);

/*	WindowQuit(0);*/
}


void ListButtonHook(void* w, void* c)
{
	CUIWINDOW* list = ListviewNew(w, _T("Test"), 0, 0, 60, 15, 4, IDC_LISTVIEW, CWS_POPUP, CWS_NONE);
	ListviewAddColumn(list, 0, _T("Column 1"));
	ListviewAddColumn(list, 1, _T("Column 2"));
	ListviewAddColumn(list, 2, _T("Column 3"));
	ListviewAddColumn(list, 3, _T("Column 4"));
	ListviewSetPreKeyHook(list, ListKeyHook, w);
	WindowSetTimerHook(list, ListTimerHook);
	WindowSetTimer(list, 1111, 1000);
	WindowCreate(list);
	WindowModal(list);
	WindowDestroy(list);
}


void CancelButtonHook(void* w, void* c)
{
	WindowClose((CUIWINDOW*) w, 1);
}

void TimerHook(void* w, int id)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	wchar_t help[64];
	static int count = 0;

	swprintf(help, 63, _T("Timer %i"), count++);
	WindowSetText(win, help);
}

void MouseMoveHook(void* w, int x, int y)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = WindowGetCtrl((CUIWINDOW*) w, IDC_LISTBOX1);
	wchar_t help[64];
	if (ctrl)
	{
		swprintf(help, 63, _T("Position: %i, %i"), x, y);
		WindowSetText(win, help);
		ListboxAdd(ctrl, help);
	}
}

void MouseButtonHook(void* w, int x, int y, int state)
{
	CUIWINDOW* win = (CUIWINDOW*) w;
	CUIWINDOW* ctrl = WindowGetCtrl(win, IDC_LISTBOX1);
	if (ctrl)
	{
		int index = 0;
		wchar_t help[64];
		switch(state)
		{
		case BUTTON1_PRESSED:          index = ListboxAdd(ctrl, _T("mouse button 1 down")); break;
		case BUTTON1_RELEASED:         index = ListboxAdd(ctrl, _T("mouse button 1 up")); break;
		case BUTTON1_CLICKED:          index = ListboxAdd(ctrl, _T("mouse button 1 clicked")); break;
		case BUTTON1_DOUBLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 1 double clicked")); break;
		case BUTTON1_TRIPLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 1 triple clicked")); break;
		case BUTTON2_PRESSED:          index = ListboxAdd(ctrl, _T("mouse button 2 down")); break;
		case BUTTON2_RELEASED:         index = ListboxAdd(ctrl, _T("mouse button 2 up")); break;
		case BUTTON2_CLICKED:          index = ListboxAdd(ctrl, _T("mouse button 2 clicked")); break;
		case BUTTON2_DOUBLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 2 double clicked")); break;
		case BUTTON2_TRIPLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 2 triple clicked")); break;
		case BUTTON3_PRESSED:          index = ListboxAdd(ctrl, _T("mouse button 3 down")); break;
		case BUTTON3_RELEASED:         index = ListboxAdd(ctrl, _T("mouse button 3 up")); break;
		case BUTTON3_CLICKED:          index = ListboxAdd(ctrl, _T("mouse button 3 clicked")); break;
		case BUTTON3_DOUBLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 3 double clicked")); break;
		case BUTTON3_TRIPLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 3 triple clicked")); break;
		case BUTTON4_PRESSED:          index = ListboxAdd(ctrl, _T("mouse button 4 down")); break;
		case BUTTON4_RELEASED:         index = ListboxAdd(ctrl, _T("mouse button 4 up")); break;
		case BUTTON4_CLICKED:          index = ListboxAdd(ctrl, _T("mouse button 4 clicked")); break;
		case BUTTON4_DOUBLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 4 double clicked")); break;
		case BUTTON4_TRIPLE_CLICKED:   index = ListboxAdd(ctrl, _T("mouse button 4 triple clicked")); break;
		case BUTTON_SHIFT:             index = ListboxAdd(ctrl, _T("shift was down during button state change")); break;
		case BUTTON_CTRL:              index = ListboxAdd(ctrl, _T("control was down during button state change")); break;
		case BUTTON_ALT:               index = ListboxAdd(ctrl, _T("alt was down during button state change")); break;
		}
		if (index != 0)
		{
			ListboxSetSel(ctrl, index);
		}

		WindowReleaseCapture();
		if (state == BUTTON1_PRESSED)
		{
			WindowSetCapture(win);
		}

		swprintf(help, 63, _T("Position: %i, %i"), x, y);
		WindowSetText(win, help);
	}
}


#include <iconv.h>

int main(void)
{
	CUIWINDOW *window;
	CUIWINDOW *ctrl;
	CUIWINDOW *group;
	wchar_t    buffer[128 + 1];
	
	CuuSetStdCodec("ISO-8859-15");
	
	WindowStart(TRUE, TRUE);
	atexit(quit);
	
	window = WindowNew(WindowGetDesktop(), 10, 1, 60, 18, CWS_BORDER | CWS_POPUP);
	WindowSetText(window, CuuToUtf16(buffer, "Cünfig Options", sizeof(buffer)));
	WindowColScheme(window, _T("DIALOG"));
	WindowSetMButtonHook(window, MouseButtonHook);
	WindowSetMMoveHook(window, MouseMoveHook);	
	WindowSetTimerHook(window, TimerHook);
	WindowCreate(window);

	group = GroupboxNew(window, _T("Group Box 1"), 1, 1, 32, 6, CWS_NONE, CWS_NONE);
	WindowCreate(group);

	ctrl = LabelNew(group, _T("Label1:"), 1, 0, 8, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(group, _T("Hallo"), 11, 0, 18, 1, 40, IDC_EDIT1, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = LabelNew(group, _T("Label2:"), 1, 1, 8, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(group, _T("Hallo 2"), 11, 1, 18, 1, 40, IDC_EDIT2, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = LabelNew(group, _T("Label3:"), 1, 2, 8, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = EditNew(group, _T("Hallo 2"), 11, 2, 18, 1, 40, IDC_EDIT3, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = LabelNew(group, _T("Label4:"), 1, 3, 8, 1, 0, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = ComboboxNew(group, 11, 3, 18, 10, IDC_COMBO1, CWS_NONE, CWS_NONE);
	ComboboxAdd(ctrl, _T("Leer"));
	ComboboxAdd(ctrl, _T("Hallo"));
	ComboboxAdd(ctrl, _T("Welt!"));
	ComboboxAdd(ctrl, _T("Dies"));
	ComboboxAdd(ctrl, _T("ist"));
	ComboboxAdd(ctrl, _T("ein"));
	ComboboxAdd(ctrl, _T("Test"));
	ComboboxAdd(ctrl, _T("Hallo"));
	ComboboxAdd(ctrl, _T("Welt!"));
	ComboboxAdd(ctrl, _T("Dies"));
	ComboboxAdd(ctrl, _T("ist"));
	ComboboxAdd(ctrl, _T("ein"));
	ComboboxAdd(ctrl, _T("Test"));
	ComboboxSetSel(ctrl, 0);
	WindowCreate(ctrl);


	group = GroupboxNew(window, _T("Group Box 2"), 34, 1, 20, 6, CWS_NONE, CWS_NONE);
	WindowCreate(group);

	ctrl = RadioNew(group, _T("Click Me &1"), 1, 0, 18, 1, IDC_RADIO1, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = RadioNew(group, _T("Click Me &2"), 1, 1, 18, 1, IDC_RADIO2, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = CheckboxNew(group, _T("Check &Me 1"), 1, 3, 18, 1, IDC_CHKBOX1, CWS_NONE, CWS_NONE);
	WindowCreate(ctrl);

	ctrl = ListboxNew(window, _T("Listbox"), 1, 7, 34, 8, IDC_LISTBOX1, CWS_NONE, CWS_BORDER);
	WindowColScheme(ctrl, _T("MENU"));
	WindowCreate(ctrl);
/*	for (i = 0; i < 20; i++)
	{
		char itemtxt[64];
		sprintf(itemtxt, "Item %02i", i);
		ListboxAdd(ctrl, itemtxt);
	}
	ListboxSetSel(ctrl, 2);*/

	ctrl = ProgressbarNew(window, _T("Progress"), 37, 7, 17, 3, IDC_PROGRESS, CWS_NONE, CWS_NONE);
	ProgressbarSetPos(ctrl, 25);
	WindowCreate(ctrl);

	ctrl = ButtonNew(window, _T("&OK"), 38, 11, 11, 1, IDC_OK, CWS_DEFOK, CWS_NONE);
	ButtonSetClickedHook(ctrl, OkButtonHook, window);
	WindowCreate(ctrl);

	ctrl = ButtonNew(window, _T("&List"), 38, 12, 11, 1, IDC_LISTBUT, CWS_NONE, CWS_NONE);
	ButtonSetClickedHook(ctrl, ListButtonHook, window);
	WindowCreate(ctrl);

	ctrl = ButtonNew(window, _T("&Cancel"), 38, 13, 11, 1, IDC_CANCEL, CWS_DEFCANCEL, CWS_NONE);
	ButtonSetClickedHook(ctrl, CancelButtonHook, window);
	WindowCreate(ctrl);

	WindowSetTimer(window, 4444, 1000);
	
	ctrl = WindowGetCtrl(window, IDC_EDIT1);
	if (ctrl)
	{
		WindowSetFocus(ctrl);
	}

	return WindowRun();
}

