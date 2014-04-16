/* ---------------------------------------------------------------------
 * File: pm_api.h
 *
 * Copyright (C) 2009 Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: pm_api.h 23987 2013-02-25 17:33:07Z jv $
 *   
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * ---------------------------------------------------------------------
 */
#ifndef PM_API_H
#define PM_API_H

#include <cui.h>

#include "apk_defines.h"
#include "apk_database.h"
#include "apk_applet.h"
#include "apk_blob.h"
#include "apk_print.h"
#include "apk_io.h"

enum
{
	PM_API_REPOSTOMENU         = 10,
	PM_API_GETREPOBYID         = 11,
	PM_API_PACKAGESTOLIST      = 12,
	PM_API_INFOTOTEXTVIEW      = 13,
	PM_API_INSTALLED_TOLIST    = 14,
	PM_API_DEL_PACKTOLIST      = 15,
};

void PMApiInit                   (void);
void PMApiClear                  (void);

void PMApiReposToMenu            (int argc, const wchar_t* argv[]);
void PMApiGetRepoById            (int argc, const wchar_t* argv[]);
void PMApiPackagesToList         (int argc, const wchar_t* argv[]);
void PMApiInfoToTextView         (int argc, const wchar_t* argv[]);
void PMApiListInstalledPackages  (int argc, const wchar_t* argv[]);
void PMApiDelPackagesList        (int argc, const wchar_t* argv[]);

/* local prototypes */
void PMWritePackageListEntry     (WINDOWSTUB *listview, int showall, struct apk_database *db, struct apk_package *pkg);
int  PMMatchNames                (apk_hash_item item, void *ctx);
int  PMInternalAddHashList       (char *name, char *version, char *description, int installed, int reponr, time_t buildtime);
void PMInternalClearHashList     (void);
int  PMIntNamecmp                (void *_a, void *_b);
void PMInternalSortHashList      (void);
void PMInternalHashToListview    (WINDOWSTUB *listview);

#endif
