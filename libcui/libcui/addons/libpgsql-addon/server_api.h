/* ---------------------------------------------------------------------
 * File: postgresql.h
 * (wrapper for postgresql client library)
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

#define PG_API_SERVERCONNECT         10
#define PG_API_SERVERDISCONNECT      20
#define PG_API_SERVERISCONNECTED     30
#define PG_API_SERVERGETERROR        40
#define PG_API_SERVERPASSWD          50
#define PG_API_SERVERUSER            60
#define PG_API_SERVERHOST            70
#define PG_API_SERVERPORT            80

#define PG_API_SERVERDUPTO          100
#define PG_API_QUERYSQL             110
#define PG_API_EXECSQL              120

#define PG_API_SERVERDEFAULT        200

#define PG_API_RESULTSTATUS         300
#define PG_API_RESULTNUMROWS        310
#define PG_API_RESULTNUMCOLUMNS     320
#define PG_API_RESULTCOLUMNNAME     330
#define PG_API_RESULTCOLUMNSIZE     340
#define PG_API_RESULTFETCH          350
#define PG_API_RESULTFIRST          351
#define PG_API_RESULTPREVIOUS       352
#define PG_API_RESULTNEXT           353
#define PG_API_RESULTLAST           354
#define PG_API_RESULTDATA           360
#define PG_API_RESULTISNULL         370
#define PG_API_RESULTRESET          380
#define PG_API_RESULTFREE           390

#define PG_API_RESULTTOLIST         400

void PgApiInit             (void);
void PgApiClear            (void);

void PgApiServerConnect    (int argc, const TCHAR* argv[]);
void PgApiServerDisconnect (int argc, const TCHAR* argv[]);
void PgApiServerIsConnected(int argc, const TCHAR* argv[]);
void PgApiServerGetError   (int argc, const TCHAR* argv[]);
void PgApiServerPasswd     (int argc, const TCHAR* argv[]);
void PgApiServerUser       (int argc, const TCHAR* argv[]);
void PgApiServerHost       (int argc, const TCHAR* argv[]);
void PgApiServerPort       (int argc, const TCHAR* argv[]);
void PgApiServerDupTo      (int argc, const TCHAR* argv[]);
void PgApiQuerySQL         (int argc, const TCHAR* argv[]);
void PgApiExecSQL          (int argc, const TCHAR* argv[]);
void PgApiServerDefault    (int argc, const TCHAR* argv[]);
void PgApiResultStatus     (int argc, const TCHAR* argv[]);
void PgApiResultNumRows    (int argc, const TCHAR* argv[]);
void PgApiResultNumColumns (int argc, const TCHAR* argv[]);
void PgApiResultColumnName (int argc, const TCHAR* argv[]);
void PgApiResultColumnSize (int argc, const TCHAR* argv[]);
void PgApiResultFetch      (int argc, const TCHAR* argv[]);
void PgApiResultFirst      (int argc, const TCHAR* argv[]);
void PgApiResultPrevious   (int argc, const TCHAR* argv[]);
void PgApiResultLast       (int argc, const TCHAR* argv[]);
void PgApiResultData       (int argc, const TCHAR* argv[]);
void PgApiResultIsNull     (int argc, const TCHAR* argv[]);
void PgApiResultReset      (int argc, const TCHAR* argv[]);
void PgApiResultFree       (int argc, const TCHAR* argv[]);
void PgApiResultToList     (int argc, const TCHAR* argv[]);

#endif
