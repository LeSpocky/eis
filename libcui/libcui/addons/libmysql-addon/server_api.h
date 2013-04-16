/* ---------------------------------------------------------------------
 * File: server_api.h
 * (wrapper for mysql client library)
 *
 * Copyright (C) 2008
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
#ifndef SERVER_API_H
#define SERVER_API_H

#include <cui.h>
#include "server.h"

#define MY_API_SERVERCONNECT         10
#define MY_API_SERVERDISCONNECT      20
#define MY_API_SERVERISCONNECTED     30
#define MY_API_SERVERGETERROR        40
#define MY_API_SERVERPASSWD          50
#define MY_API_SERVERUSER            60
#define MY_API_SERVERHOST            70
#define MY_API_SERVERPORT            80

#define MY_API_SERVERDUPTO          100
#define MY_API_QUERYSQL             110
#define MY_API_EXECSQL              120

#define MY_API_SERVERDEFAULT        200

#define MY_API_RESULTSTATUS         300
#define MY_API_RESULTNUMROWS        310
#define MY_API_RESULTNUMCOLUMNS     320
#define MY_API_RESULTCOLUMNNAME     330
#define MY_API_RESULTCOLUMNSIZE     340
#define MY_API_RESULTFETCH          350
#define MY_API_RESULTDATA           360
#define MY_API_RESULTISNULL         370
#define MY_API_RESULTRESET          380
#define MY_API_RESULTFREE           390

#define MY_API_RESULTTOLIST         400

void MyApiInit             (void);
void MyApiClear            (void);

void MyApiServerConnect    (int argc, const wchar_t* argv[]);
void MyApiServerDisconnect (int argc, const wchar_t* argv[]);
void MyApiServerIsConnected(int argc, const wchar_t* argv[]);
void MyApiServerGetError   (int argc, const wchar_t* argv[]);
void MyApiServerPasswd     (int argc, const wchar_t* argv[]);
void MyApiServerUser       (int argc, const wchar_t* argv[]);
void MyApiServerHost       (int argc, const wchar_t* argv[]);
void MyApiServerPort       (int argc, const wchar_t* argv[]);
void MyApiServerDupTo      (int argc, const wchar_t* argv[]);
void MyApiQuerySQL         (int argc, const wchar_t* argv[]);
void MyApiExecSQL          (int argc, const wchar_t* argv[]);
void MyApiServerDefault    (int argc, const wchar_t* argv[]);
void MyApiResultStatus     (int argc, const wchar_t* argv[]);
void MyApiResultNumRows    (int argc, const wchar_t* argv[]);
void MyApiResultNumColumns (int argc, const wchar_t* argv[]);
void MyApiResultColumnName (int argc, const wchar_t* argv[]);
void MyApiResultColumnSize (int argc, const wchar_t* argv[]);
void MyApiResultFetch      (int argc, const wchar_t* argv[]);
void MyApiResultData       (int argc, const wchar_t* argv[]);
void MyApiResultIsNull     (int argc, const wchar_t* argv[]);
void MyApiResultReset      (int argc, const wchar_t* argv[]);
void MyApiResultFree       (int argc, const wchar_t* argv[]);
void MyApiResultToList     (int argc, const wchar_t* argv[]);

#endif
