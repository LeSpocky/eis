/* ---------------------------------------------------------------------
 * File: api_ctrl.h
 * (controls script cui api)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api_ctrl.h 33397 2013-04-02 20:48:05Z dv $
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
#ifndef API_CTRL_H
#define API_CTRL_H

#define API_EDITNEW 100
#define API_EDITSETCALLBACK 101
#define API_EDITSETTEXT 102
#define API_EDITGETTEXT 103

void ApiEditNew(int argc, const wchar_t* argv[]);
void ApiEditSetCallback(int argc, const wchar_t* argv[]);
void ApiEditSetText(int argc, const wchar_t* argv[]);
void ApiEditGetText(int argc, const wchar_t* argv[]);

#define API_LABELNEW 110
#define API_LABELSETCALLBACK 111

void ApiLabelNew(int argc, const wchar_t* argv[]);
void ApiLabelSetCallback(int argc, const wchar_t* argv[]);

#define API_BUTTONNEW 120
#define API_BUTTONSETCALLBACK 121

void ApiButtonNew(int argc, const wchar_t* argv[]);
void ApiButtonSetCallback(int argc, const wchar_t* argv[]);

#define API_GROUPBOXNEW 125

void ApiGroupboxNew(int argc, const wchar_t* argv[]);

#define API_RADIONEW 130
#define API_RADIOSETCALLBACK 131
#define API_RADIOSETCHECK 132
#define API_RADIOGETCHECK 133

void ApiRadioNew(int argc, const wchar_t* argv[]);
void ApiRadioSetCallback(int argc, const wchar_t* argv[]);
void ApiRadioSetCheck(int argc, const wchar_t* argv[]);
void ApiRadioGetCheck(int argc, const wchar_t* argv[]);

#define API_CHECKBOXNEW 135
#define API_CHECKBOXSETCALLBACK 136
#define API_CHECKBOXSETCHECK 137
#define API_CHECKBOXGETCHECK 138

void ApiCheckboxNew(int argc, const wchar_t* argv[]);
void ApiCheckboxSetCallback(int argc, const wchar_t* argv[]);
void ApiCheckboxSetCheck(int argc, const wchar_t* argv[]);
void ApiCheckboxGetCheck(int argc, const wchar_t* argv[]);

#define API_LISTBOXNEW 140
#define API_LISTBOXSETCALLBACK 141
#define API_LISTBOXADD 142
#define API_LISTBOXDELETE 143
#define API_LISTBOXGET 144
#define API_LISTBOXSETDATA 145
#define API_LISTBOXGETDATA 146
#define API_LISTBOXSETSEL 147
#define API_LISTBOXGETSEL 148
#define API_LISTBOXCLEAR 149
#define API_LISTBOXGETCOUNT 150
#define API_LISTBOXSELECT 151

void ApiListboxNew(int argc, const wchar_t* argv[]);
void ApiListboxSetCallback(int argc, const wchar_t* argv[]);
void ApiListboxAdd(int argc, const wchar_t* argv[]);
void ApiListboxDelete(int argc, const wchar_t* argv[]);
void ApiListboxGet(int argc, const wchar_t* argv[]);
void ApiListboxSetData(int argc, const wchar_t* argv[]);
void ApiListboxGetData(int argc, const wchar_t* argv[]);
void ApiListboxSetSel(int argc, const wchar_t* argv[]);
void ApiListboxGetSel(int argc, const wchar_t* argv[]);
void ApiListboxClear(int argc, const wchar_t* argv[]);
void ApiListboxGetCount(int argc, const wchar_t* argv[]);
void ApiListboxSelect(int argc, const wchar_t* argv[]);

#define API_COMBOBOXNEW 160
#define API_COMBOBOXSETCALLBACK 161
#define API_COMBOBOXADD 162
#define API_COMBOBOXDELETE 163
#define API_COMBOBOXGET 164
#define API_COMBOBOXSETDATA 165
#define API_COMBOBOXGETDATA 166
#define API_COMBOBOXSETSEL 167
#define API_COMBOBOXGETSEL 168
#define API_COMBOBOXCLEAR 169
#define API_COMBOBOXGETCOUNT 170
#define API_COMBOBOXSELECT 171

void ApiComboboxNew(int argc, const wchar_t* argv[]);
void ApiComboboxSetCallback(int argc, const wchar_t* argv[]);
void ApiComboboxAdd(int argc, const wchar_t* argv[]);
void ApiComboboxDelete(int argc, const wchar_t* argv[]);
void ApiComboboxGet(int argc, const wchar_t* argv[]);
void ApiComboboxSetData(int argc, const wchar_t* argv[]);
void ApiComboboxGetData(int argc, const wchar_t* argv[]);
void ApiComboboxSetSel(int argc, const wchar_t* argv[]);
void ApiComboboxGetSel(int argc, const wchar_t* argv[]);
void ApiComboboxClear(int argc, const wchar_t* argv[]);
void ApiComboboxGetCount(int argc, const wchar_t* argv[]);
void ApiComboboxSelect(int argc, const wchar_t* argv[]);

#define API_PROGRESSBARNEW 180
#define API_PROGRESSBARSETRANGE 181
#define API_PROGRESSBARSETPOS 182
#define API_PROGRESSBARGETRANGE 183
#define API_PROGRESSBARGETPOS 184

void ApiProgressbarNew(int argc, const wchar_t* argv[]);
void ApiProgressbarSetRange(int argc, const wchar_t* argv[]);
void ApiProgressbarSetPos(int argc, const wchar_t* argv[]);
void ApiProgressbarGetRange(int argc, const wchar_t* argv[]);
void ApiProgressbarGetPos(int argc, const wchar_t* argv[]);


#define API_TEXTVIEWNEW 200
#define API_TEXTVIEWSETCALLBACK 201
#define API_TEXTVIEWENABLEWORDWRAP 202
#define API_TEXTVIEWADD 203
#define API_TEXTVIEWCLEAR 204
#define API_TEXTVIEWREAD 205
#define API_TEXTVIEWSEARCH 206

void ApiTextviewNew(int argc, const wchar_t* argv[]);
void ApiTextviewSetCallback(int argc, const wchar_t* argv[]);
void ApiTextviewEnableWordWrap(int argc, const wchar_t* argv[]);
void ApiTextviewAdd(int argc, const wchar_t* argv[]);
void ApiTextviewClear(int argc, const wchar_t* argv[]);
void ApiTextviewRead(int argc, const wchar_t* argv[]);
void ApiTextviewSearch(int argc, const wchar_t* argv[]);


#define API_LISTVIEWNEW 210
#define API_LISTVIEWSETCALLBACK 211
#define API_LISTVIEWADDCOLUMN 212
#define API_LISTVIEWSETTITLEALIGNMENT 213
#define API_LISTVIEWCLEAR 214
#define API_LISTVIEWADD 215
#define API_LISTVIEWSETTEXT 216
#define API_LISTVIEWGETTEXT 217
#define API_LISTVIEWGETDATA 218
#define API_LISTVIEWSETDATA 219
#define API_LISTVIEWSETSEL 220
#define API_LISTVIEWGETSEL 221
#define API_LISTVIEWGETCOUNT 222
#define API_LISTVIEWUPDATE 223
#define API_LISTVIEWALPHASORT 224
#define API_LISTVIEWNUMERICSORT 225

void ApiListviewNew(int argc, const wchar_t* argv[]);
void ApiListviewSetCallback(int argc, const wchar_t* argv[]);
void ApiListviewAddColumn(int argc, const wchar_t* argv[]);
void ApiListviewSetTitleAlignment(int argc, const wchar_t* argv[]);
void ApiListviewClear(int argc, const wchar_t* argv[]);
void ApiListviewAdd(int argc, const wchar_t* argv[]);
void ApiListviewSetText(int argc, const wchar_t* argv[]);
void ApiListviewGetText(int argc, const wchar_t* argv[]);
void ApiListviewSetData(int argc, const wchar_t* argv[]);
void ApiListviewGetData(int argc, const wchar_t* argv[]);
void ApiListviewSetSel(int argc, const wchar_t* argv[]);
void ApiListviewGetSel(int argc, const wchar_t* argv[]);
void ApiListviewGetCount(int argc, const wchar_t* argv[]);
void ApiListviewUpdate(int argc, const wchar_t* argv[]);
void ApiListviewAlphaSort(int argc, const wchar_t* argv[]);
void ApiListviewNumericSort(int argc, const wchar_t* argv[]);


#define API_TERMINALNEW 230
#define API_TERMINALSETCALLBACK 231
#define API_TERMINALWRITE 232
#define API_TERMINALRUN 233
#define API_TERMINALPIPEDATA 234

void ApiTerminalNew(int argc, const wchar_t* argv[]);
void ApiTerminalSetCallback(int argc, const wchar_t* argv[]);
void ApiTerminalWrite(int argc, const wchar_t* argv[]);
void ApiTerminalRun(int argc, const wchar_t* argv[]);
void ApiTerminalPipeData(int argc, const wchar_t* argv[]);


#define API_MENUNEW 240
#define API_MENUSETCALLBACK 241
#define API_MENUADDITEM 242
#define API_MENUADDSEPARATOR 243
#define API_MENUSELECTITEM 244
#define API_MENUGETSELITEM 245
#define API_MENUCLEAR 246

void ApiMenuNew(int argc, const wchar_t* argv[]);
void ApiMenuSetCallback(int argc, const wchar_t* argv[]);
void ApiMenuAddItem(int argc, const wchar_t* argv[]);
void ApiMenuAddSeparator(int argc, const wchar_t* argv[]);
void ApiMenuSelectItem(int argc, const wchar_t* argv[]);
void ApiMenuGetSelectedItem(int argc, const wchar_t* argv[]);
void ApiMenuClear(int argc, const wchar_t* argv[]);


#endif
