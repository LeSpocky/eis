/* ---------------------------------------------------------------------
 * File: pm_api.c   
 * pm = package manager
 *   
 * Copyright (C) 2013  Jens Vehlhaber, <jens@eisfair.org>
 *
 * Last Update:  $Id: pm_api.c 23987 2013-02-25 17:33:07Z jv $
 *   
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * ---------------------------------------------------------------------
 */

#include <cui.h>
#include <cui-script.h>
#include "chartools.h"
#include "pm_api.h"
#include "uthash.h"


#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#define PKNAMELEN 40
#define PKVERSLEN 22
#define PKDESCLEN 110

#if 0
#undef uthash_expand_fyi
#define uthash_expand_fyi(tbl) printf("expanding to %d buckets\n", tbl->num_buckets)
#endif

/* ---------------------------------------------------------------------
 * global data
 * ---------------------------------------------------------------------
 */
extern StartFrameProc    LibPMStartFrame;
extern InsertStrProc     LibPMInsertStr;
extern InsertIntProc     LibPMInsertInt;
extern InsertLongProc    LibPMInsertLong;
extern SendFrameProc     LibPMSendFrame;
extern ExecFrameProc     LibPMExecFrame;
extern WriteErrorProc    LibPMWriteError;

extern StubCreateProc    LibPMStubCreate;
extern StubCheckStubProc LibPMStubCheck;
extern StubDeleteProc    LibPMStubDelete;
extern StubSetHookProc   LibPMStubSetHook;
extern StubSetProcProc   LibPMStubSetProc;
extern StubFindProc      LibPMStubFind;

/* local structure */
struct search_ctx {
	int reponr;
	int search_description : 1;
	char searchtext[128];
};


typedef struct name_rec {
	char package_name[PKNAMELEN];
	char package_version[PKVERSLEN];
	char package_description[PKDESCLEN];
	int  package_installed;
	int  package_repo;
	time_t package_date;
	UT_hash_handle hh;
} name_rec;

struct name_rec *packlist = NULL;

enum {
	INSTALLED_PACKAGES,
	MARKED_PACKAGES,
};


/* ---------------------------------------------------------------------
 * local functions
 * ---------------------------------------------------------------------
 */
void
PMInternalClearHashList(void)
{
	struct name_rec *current_entry, *tmp; 
	HASH_ITER(hh, packlist, current_entry, tmp) {
		HASH_DEL(packlist,current_entry);
		free(current_entry);
	}
}

int
PMInternalAddHashList(char *name, char *version, char *description, int installed, int reponr, time_t buildtime)
{
	name_rec *entry=NULL;
	HASH_FIND_STR(packlist,name,entry);
	if (entry) return 0;
	if ((entry = (name_rec*)malloc(sizeof(name_rec))) == NULL) return 1;
	strncpy(entry->package_name, name, PKNAMELEN);
	strncpy(entry->package_version, version, PKVERSLEN);
	strncpy(entry->package_description, description, PKDESCLEN);
	entry->package_installed = installed;
	entry->package_repo = reponr;
	entry->package_date = buildtime;
	HASH_ADD_STR(packlist,package_name,entry);
	return 0;
}

void
PMInternalSortHashList(void)
{
	HASH_SORT(packlist, PMIntNamecmp);
}

int
PMIntNamecmp(void *_a, void *_b)
{
	name_rec *a = (name_rec*)_a;
	name_rec *b = (name_rec*)_b;
	return strcmp(a->package_name,b->package_name);
}

/* ---------------------------------------------------------------------
 * PMApiInit
 * Initialize API
 * ---------------------------------------------------------------------
 */
void
PMApiInit(void)
{
	/* nothing to do right now */
	apk_verbosity=0;
}


/* ---------------------------------------------------------------------
 * PMApiClear
 * Clear API
 * ---------------------------------------------------------------------
 */
void 
PMApiClear(void)
{
	/* nothing to do right now */
	PMInternalClearHashList();
}


/* ---------------------------------------------------------------------
 * API functions
 * ---------------------------------------------------------------------
 */

/* ---------------------------------------------------------------------
 * PMApiReposToMenu
 * Read repositories from database and transfer them into a menu window
 * $0 : menu window handle
 * ---------------------------------------------------------------------
 */
void 
PMApiReposToMenu(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		WINDOWSTUB*   menu;
		unsigned long tmplong;
		int           i, r;
		struct apk_database db;
		struct apk_database *pdb;
		struct apk_db_options dbopts;
		struct apk_repository *repo;
		
		swscanf(argv[0], _T("%ld"), &tmplong);
		menu = LibPMStubFind(tmplong);
		
		if (menu && menu->Window)
		{
			wchar_t buffer[16];

			memset(&dbopts, 0, sizeof(dbopts));
			list_init(&dbopts.repository_list);
			apk_atom_init();
			dbopts.open_flags |= APK_OPENF_READ ;
			r = apk_db_open(&db, &dbopts);
			if (r != 0) 
			{
				LibPMWriteError(ERROR_INVALID);
			}			
			pdb = &db;
			for (i = 0; i < pdb->num_repos; i++)
			{
				repo = &pdb->repos[i];
				if (APK_BLOB_IS_NULL(repo->description)) 
				{
					if ( repo->url == NULL )
						continue;
					swprintf(buffer, 14, _T("%s"),repo->url);
				}
				else
					swprintf(buffer, 14, _T("" BLOB_FMT), BLOB_PRINTF(repo->description));
				MenuAddItem(menu->Window, buffer, i +1, FALSE);	
			}
			apk_db_close(&db);
			LibPMStartFrame(_T('R'), 32);
			LibPMInsertInt (ERROR_SUCCESS);
			LibPMSendFrame ();
		}
		else
		{
			LibPMWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PMApiGetRepoById
 * resolve repository index to repositry name
 * $0 : index
 * return : name
 * ---------------------------------------------------------------------
 */
void
PMApiGetRepoById(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		unsigned long  index;
		int    r;
		struct apk_database db;
		struct apk_database *pdb;
		struct apk_db_options dbopts;
		struct apk_repository *repo;
		wchar_t buffer[16];
		
		swscanf(argv[0], _T("%ld"), &index);
		if (index == 0)
			return;
		memset(&dbopts, 0, sizeof(dbopts));
		list_init(&dbopts.repository_list);
		apk_atom_init();
		dbopts.open_flags |= APK_OPENF_READ;
		r = apk_db_open(&db, &dbopts);
		if (r != 0) 
		{
			LibPMWriteError(ERROR_INVALID);
			return;
		}			
		pdb = &db;
		repo = &pdb->repos[index -1];
		if (APK_BLOB_IS_NULL(repo->description)) 
			swprintf(buffer, 14, _T("%s"),repo->url);
		else
			swprintf(buffer, 14, _T("" BLOB_FMT), BLOB_PRINTF(repo->description));
		apk_db_close(&db);
		LibPMStartFrame(_T('R'), 32 + wcslen(buffer) * sizeof(wchar_t));
		LibPMInsertInt (ERROR_SUCCESS);
		LibPMInsertStr (buffer);
		LibPMSendFrame ();
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PMApiPackagesToList
 * Read read package list into list view control
 * $0 : list view window handle
 * $1 : repository, 0 = all
 * $2 : keyword (optional)
 * ---------------------------------------------------------------------
 */
void
PMApiPackagesToList(int argc, const wchar_t* argv[])
{
	WINDOWSTUB *listview;
	if (argc >= 2)
	{
		unsigned long  tmplong;
		struct search_ctx *ictx = (struct search_ctx *)malloc(sizeof(struct search_ctx)) ;
		
		swscanf(argv[0], _T("%ld"), &tmplong);
		listview = LibPMStubFind(tmplong);
		swscanf(argv[1], _T("%d"), &ictx->reponr);
		memset(ictx->searchtext, 0, sizeof(ictx->searchtext)); 
		if (argc >= 3)
			snprintf(ictx->searchtext, 127, "%ls", argv[2]);
		if (listview && listview->Window)
		{
			struct apk_database db;
			struct apk_database *pdb;
			struct apk_db_options dbopts;
			int r;

			memset(&dbopts, 0, sizeof(dbopts));
			list_init(&dbopts.repository_list);
			apk_atom_init();
			dbopts.open_flags |= APK_OPENF_READ ;
			r = apk_db_open(&db, &dbopts);
			if (r != 0) 
				LibPMWriteError(ERROR_INVALID);
			pdb = &db;
			apk_hash_foreach(&pdb->available.names, PMMatchNames, ictx);
			apk_db_close(&db);
			PMInternalSortHashList();
			PMInternalHashToListview(listview);
			LibPMStartFrame(_T('R'), 32);
			LibPMInsertInt (ERROR_SUCCESS);
			LibPMSendFrame ();
			PMInternalClearHashList();
		}
		else
		{
			LibPMWriteError(ERROR_INVALID);
		}
		free ( ictx );
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PMApiListInstalledPackages
 * Read read the local package list into list view control
 * $0 : list view window handle
 * $1 : section / repository
 * $2 : keyword (optional)
 * --------------------------------------------------------------------- 
 */ 
void
PMApiListInstalledPackages(int argc, const wchar_t* argv[])
{
	if (argc >= 2)
	{
		WINDOWSTUB    *listview;
		const wchar_t   *keyword = NULL;
		unsigned long  tmplong;
		char tmpname[64];
		int showall = APK_VERSION_EQUAL;

		swscanf(argv[0], _T("%ld"), &tmplong);
		listview = LibPMStubFind(tmplong);
		
		if (argc >= 3)
		{
			if ((argv[2][0] == '-') && (argv[2][1] == 'u'))
				showall = APK_VERSION_GREATER;
			else
				keyword = argv[2];
		}
		if (listview && listview->Window)
		{
			struct apk_database db;
			struct apk_database *pdb;
			struct apk_db_options dbopts;
			struct apk_installed_package *ipkg;
			struct apk_name *name;
			struct apk_package *pkg;
			int r;

			memset(&dbopts, 0, sizeof(dbopts));
			list_init(&dbopts.repository_list);
			apk_atom_init();
			dbopts.open_flags |= APK_OPENF_READ;
			r = apk_db_open(&db, &dbopts);
			if (r != 0)
			{
				LibPMWriteError(ERROR_INVALID);
			}
			pdb = &db;
			if (keyword == NULL)
			{
				list_for_each_entry(ipkg, &pdb->installed.packages, installed_pkgs_list)
					PMWritePackageListEntry(listview, showall, pdb, ipkg->pkg);
			} 
			else
			{
				snprintf(tmpname, 63, "%ls", keyword);
				name = apk_db_query_name(&db, APK_BLOB_STR( tmpname ));
				if (name != NULL)
				{
					pkg = apk_pkg_get_installed(name);
					if (pkg != NULL)
						PMWritePackageListEntry(listview, showall, pdb, pkg);
				}
			}
			apk_db_close(&db);
			LibPMStartFrame(_T('R'), 32);
			LibPMInsertInt (ERROR_SUCCESS);
			LibPMSendFrame ();
		}
		else
		{
			LibPMWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PMApiInfoToTextView
 * Read the package info from database and transfer them into a 
 * text view window
 * $0 : text view window handle
 * $1 : package name
 * ---------------------------------------------------------------------
 */ 
void 
PMApiInfoToTextView(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		WINDOWSTUB    *textview;
		const wchar_t   *package = NULL;
		unsigned long  tmplong;
		wchar_t buffer[512];
		char tmpname[64];

		swscanf(argv[0], _T("%ld"), &tmplong);
		textview = LibPMStubFind(tmplong);
		
		package = argv[1];
		
		if (textview && textview->Window)
		{
			struct apk_database db;
			struct apk_db_options dbopts;
			struct apk_name *name;
			struct apk_package *pkg; 
			struct tm *ts;
			char str[128];
			int r, i, j;

			TextviewClear(textview->Window);
			memset(&dbopts, 0, sizeof(dbopts));
			list_init(&dbopts.repository_list);
			apk_atom_init();
			dbopts.open_flags |= APK_OPENF_READ;
			r = apk_db_open(&db, &dbopts);
			if (r != 0)
			{
				swprintf(buffer, 127, _T("Failed to open apk database: %s "), apk_error_str(r));
				TextviewAdd  (textview->Window, buffer); 
			}
			if (r == 0)
			{
				snprintf(tmpname, 63, "%ls", package);
				name = apk_db_query_name(&db, APK_BLOB_STR( tmpname ));
				if ( name == NULL )
				{
					r = 1;
					swprintf(buffer, 127, _T("Package with name \"%s\" not found!"), tmpname);
					TextviewAdd  (textview->Window, buffer);
				}
			}
			if (r == 0)
			{
				pkg = apk_pkg_get_installed(name);
				if ( pkg == NULL )
				{
					for (i = 0; i < name->providers->num; i++)
					{
						pkg = name->providers->item[i].pkg;
						if (pkg)
							if ( pkg->name == name )
								break;
					}
				}
				if ( pkg == NULL )
				{
					r = 1;
					TextviewAdd  (textview->Window, _T("Failed to get package data"));  
				}
			}
			if (r == 0)
			{
				swprintf(buffer, 127, _T("%s"), pkg->description);
				TextviewAdd  (textview->Window, buffer);
				TextviewAdd  (textview->Window, 
					_T("--------------------------------------------------------"));
				swprintf(buffer, 127, _T("Version        : " BLOB_FMT ), BLOB_PRINTF(*pkg->version));
				TextviewAdd  (textview->Window, buffer);
				ts = localtime(&pkg->build_time);
				strftime(str, 25, "%Y-%m-%d %H:%M:%S", ts );
				swprintf(buffer, 127, _T("Build date     : %s"), str);
				TextviewAdd  (textview->Window, buffer);
				if (pkg->maintainer == NULL)
					TextviewAdd  (textview->Window, _T("Maintainer     : Team" ));
				else
				{
					swprintf(buffer, 127, _T("Maintainer     : " BLOB_FMT ), BLOB_PRINTF(*pkg->maintainer));
					TextviewAdd  (textview->Window, buffer);
				}
 				swprintf(buffer, 127, _T("URL            : %s"), pkg->url);
				TextviewAdd  (textview->Window, buffer);
 				swprintf(buffer, 127, _T("Licenses       : " BLOB_FMT ), BLOB_PRINTF(*pkg->license));
				TextviewAdd  (textview->Window, buffer);
 				swprintf(buffer, 127, _T("Download size  : %zu"), pkg->size);
				TextviewAdd  (textview->Window, buffer);
 				swprintf(buffer, 127, _T("Installed size : %zu"), pkg->installed_size);
				TextviewAdd  (textview->Window, buffer);
				for (i = 0; i < pkg->depends->num; i++) 
				{
					memset(str, 0, sizeof(str));
					apk_blob_t b = APK_BLOB_BUF(str);
					apk_blob_push_dep(&b, &db, &pkg->depends->item[i]);
					b = apk_blob_pushed(APK_BLOB_BUF(str), b);
					if ( i ==0 )
 						swprintf(buffer, 127, _T("Required       : %s"), b.ptr);
					else
 						swprintf(buffer, 127, _T("                 %s"), b.ptr);
					TextviewAdd  (textview->Window, buffer);
				}
				for (i = 0; i < pkg->provides->num; i++) 
				{
				memset(str, 0, sizeof(str));
					apk_blob_t b = APK_BLOB_BUF(str);
					apk_blob_push_dep(&b, &db, &pkg->provides->item[i]);
					b = apk_blob_pushed(APK_BLOB_BUF(str), b);
					if ( i ==0 )
 						swprintf(buffer, 127, _T("Provides       : %s"), b.ptr);
					else
 						swprintf(buffer, 127, _T("                 %s"), b.ptr);
					TextviewAdd  (textview->Window, buffer);
				}
				for (i = 0; i < pkg->name->rdepends->num; i++) 
				{
					struct apk_name *name0;
					struct apk_package *pkg0;
					name0 = pkg->name->rdepends->item[i];
					pkg0 = apk_pkg_get_installed(name0);
					if (pkg0 == NULL)
						continue;
					for (j = 0; j < pkg0->depends->num; j++) 
					{
						if (pkg0->depends->item[j].name != pkg->name)
							continue;
						if ( i ==0 )
 							swprintf(buffer, 127, _T("Required from  : %s"), pkg0->name->name);
						else
 							swprintf(buffer, 127, _T("                 %s"), pkg0->name->name);
						TextviewAdd  (textview->Window, buffer); 
						break;
					}
				}
				for (i = 0; i < pkg->install_if->num; i++) 
				{
					memset(str, 0, sizeof(str));
					apk_blob_t b = APK_BLOB_BUF(str);
					apk_blob_push_dep(&b, &db, &pkg->install_if->item[i]);
					b = apk_blob_pushed(APK_BLOB_BUF(str), b);
					if ( i ==0 )
 						swprintf(buffer, 127, _T("Install item   : %s"), b.ptr);
					else
 						swprintf(buffer, 127, _T("                 %s"), b.ptr);
					TextviewAdd  (textview->Window, buffer);
				}
				if (  pkg->ipkg != NULL )
				{
					for (i = 0; i < pkg->ipkg->triggers->num; i++) 
					{
						printf("%s ", pkg->ipkg->triggers->item[i]);
						if ( i ==0 )
							wprintf(buffer, 127, _T("Trigger:       : %s"), pkg->ipkg->triggers->item[i]);
						else
							swprintf(buffer, 127, _T("                 %s"), pkg->ipkg->triggers->item[i]);
						TextviewAdd  (textview->Window, buffer);
					}
				}
				if (  pkg->ipkg != NULL ) 
				{	
					for (i = 0; i < pkg->ipkg->replaces->num; i++) 
					{
						apk_blob_t b = APK_BLOB_BUF(str);
						apk_blob_push_dep(&b, &db, &pkg->ipkg->replaces->item[i]);
						b = apk_blob_pushed(APK_BLOB_BUF(str), b);
						if ( i ==0 )
 	  						swprintf(buffer, 127, _T("Replace        : %s"), b.ptr);
						else
 							swprintf(buffer, 127, _T("                 %s"), b.ptr);
						TextviewAdd  (textview->Window, buffer); 
					}
				}
				if ( pkg->ipkg != NULL ) 
				{
					struct apk_db_dir_instance *diri;
					struct apk_db_file *file;
					struct hlist_node *dc, *dn, *fc, *fn;
					i = 0;
					TextviewAdd         (textview->Window,
					  _T("--------------------------------------------------------"));
					hlist_for_each_entry_safe(diri, dc, dn, &pkg->ipkg->owned_dirs, pkg_dirs_list) 
					{
						hlist_for_each_entry_safe(file, fc, fn, &diri->owned_files, diri_files_list) 
						{
							if ( i == 0 )
 								swprintf(buffer, 127, _T("Installed files: %s/%s"), diri->dir->name, file->name);
							else
								swprintf(buffer, 127, _T("                 %s/%s"), diri->dir->name, file->name);
							TextviewAdd(textview->Window, buffer);
							i++;
						}
					}
				}
				TextviewAdd         (textview->Window, 
					_T("--------------------------------------------------------"));
				apk_db_close(&db);
			}
			LibPMStartFrame(_T('R'), 32);
			LibPMInsertInt (ERROR_SUCCESS);
			LibPMSendFrame ();
		}
		else
		{
			LibPMWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PMApiDelPackagesList
 * Read the package for delting from database and transfer them into a 
 * text view window
 * $0 : package name for delete
 * ---------------------------------------------------------------------
 */ 
void 
PMApiDelPackagesList(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		int    i, j, n, r;
		struct apk_database db;
		struct apk_db_options dbopts;
		struct apk_name *name;
		struct apk_package *pkg;
		char   tmpname[64];
		wchar_t  str[55];
		wchar_t  buffer[256];

		memset(&buffer, 0, 256 );
		memset(&dbopts, 0, sizeof(dbopts));
		list_init(&dbopts.repository_list);
		apk_atom_init();
		dbopts.open_flags |= APK_OPENF_READ;
		r = apk_db_open(&db, &dbopts);
		if (r != 0) 
		{
			LibPMWriteError(ERROR_INVALID);
			return;
		}
		if (r == 0)
		{
			snprintf(tmpname, 63, "%ls", argv[0]);
			name = apk_db_query_name(&db, APK_BLOB_STR( tmpname ));
			if ( name == NULL )
				r = 1;
		}
		if (r == 0)
		{
			pkg = apk_pkg_get_installed(name);
			if ( pkg == NULL )
			    r = 1;
		}       
		if (r == 0)
		{
			for (i = 0; i < pkg->name->rdepends->num; i++) 
			{
				struct apk_name *name0;
				struct apk_package *pkg0;
				name0 = pkg->name->rdepends->item[i];
				pkg0 = apk_pkg_get_installed(name0);
				if (pkg0 == NULL)
					continue;
				for (j = 0; j < pkg0->depends->num; j++) 
				{
					if (pkg0->depends->item[j].name != pkg->name)
						continue;
					swprintf(str, 54, _T("%s"), pkg0->name->name);
					n = wcslen(buffer);
					if (n < 200)
					{
						wcscat(buffer, str); 
						wcscat(buffer, _T(" ")); 
					}
					else
					{
						if ( n < 254 )
							wcscat(buffer, _T("."));
					}
				}
			}
			apk_db_close(&db);
			LibPMStartFrame(_T('R'), 32 + wcslen(buffer) * sizeof(wchar_t));
			LibPMInsertInt (ERROR_SUCCESS);
			LibPMInsertStr (buffer);
			LibPMSendFrame ();
		}
		else
		{
			LibPMWriteError(ERROR_INVALID);
		}
	}
	else
	{
		LibPMWriteError(ERROR_ARGC);
	}
}


/* ---------------------------------------------------------------------
 * PPMWritePackageListEntry
 * Print the latest version of installed packages on listview  
 * 1 list view window handle,
 * 2 show all or only upgradeable packages,
 * 3 pointer of package database,
 * 4 pointer of current package
 * --------------------------------------------------------------------- 
 */ 
void 
PMWritePackageListEntry(WINDOWSTUB *listview, int showall, struct apk_database *db, struct apk_package *pkg)
{
	wchar_t buffer[PKDESCLEN+1];
	struct apk_name *name;
	apk_blob_t *latest = apk_blob_atomize(APK_BLOB_STR(""));
	unsigned int latest_repos = 0;
	int i, r = -1;
	struct tm *ts;
	char str[12]; 

	name = pkg->name;
	for (i = 0; i < name->providers->num; i++) 
	{
		struct apk_package *pkg0 = name->providers->item[i].pkg;
		if (pkg0->name != name || pkg0->repos == 0)
			continue;
		r = apk_version_compare_blob(*pkg0->version, *latest);
		switch (r)
		{
			case APK_VERSION_GREATER:
				latest = pkg0->version;
				latest_repos = pkg0->repos;
				break;
			case APK_VERSION_EQUAL:
				latest_repos |= pkg0->repos;
				break;
		}
	}
	r = apk_version_compare_blob(*latest, *pkg->version);
	// show only upgradable packages
	if ((showall != APK_VERSION_EQUAL) && (r == APK_VERSION_EQUAL))
		return;
	if ( r != APK_VERSION_GREATER )
		latest = apk_blob_atomize(APK_BLOB_STR(" "));
	ts = localtime(&pkg->build_time);
	strftime(str, 11, "%Y-%m-%d", ts );	
	LISTREC* rec = ListviewCreateRecord (listview->Window);  
	if (rec)
	{
		swprintf(buffer, PKNAMELEN, _T("%s"), pkg->name->name);
		ListviewSetColumnText(rec, 0, buffer);
		swprintf(buffer, PKVERSLEN, _T("" BLOB_FMT), BLOB_PRINTF(*pkg->version));
		ListviewSetColumnText(rec, 1, buffer);		
		swprintf(buffer,        11, _T("%s"), str);
		ListviewSetColumnText(rec, 2, buffer);
		swprintf(buffer, PKVERSLEN, _T("" BLOB_FMT), BLOB_PRINTF(*latest));
		ListviewSetColumnText(rec, 3, buffer);
		swprintf(buffer, PKDESCLEN, _T("%s"), pkg->description);
		ListviewSetColumnText(rec, 4, buffer);
		ListviewInsertRecord(listview->Window, rec);
	}
}


/* ---------------------------------------------------------------------
 * PMMatchNames
 * get package name
 * ---------------------------------------------------------------------
 */ 
int 
PMMatchNames(apk_hash_item item, void *ctx)
{
	struct search_ctx *ictx = (struct search_ctx *) ctx;
	struct apk_name *name = (struct apk_name *) item;
	struct apk_package *pkg = NULL;
	struct apk_provider *p;
	int    ninst = 0;

	foreach_array_item(p, name->providers)
	{
		if (pkg == NULL || apk_version_compare_blob(*p->version, *pkg->version) == APK_VERSION_GREATER)
			pkg = p->pkg;
		if (p->pkg->name == name && p->pkg->ipkg != NULL)
			ninst = 1;
	}

	if ( pkg )
	{
/*
		if ( ictx->reponr > 0 ) {
			if (pkg->repos != ictx->reponr)
				return 0;
		}
*/
		if (ictx->searchtext)
		{
			if (strstr(ictx->searchtext, "cui-*"))
			{
				if (strncmp(pkg->name->name, "cui-", 4) != 0) 
					return 0;				
			}
			else
			{
				if ((strstr(pkg->description, ictx->searchtext) == NULL) && (strstr(pkg->name->name, ictx->searchtext) == NULL))
					return 0;
			}
		}
		PMInternalAddHashList( pkg->name->name, apk_blob_cstr(*pkg->version), pkg->description, ninst, pkg->repos, pkg->build_time );
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * PMInternalHashToListview
 * Copy all (sorted) internal hash list records to libcui list
 * ---------------------------------------------------------------------
 */
void
PMInternalHashToListview(WINDOWSTUB *listview)
{
	struct name_rec *entry;
	wchar_t buffer[PKDESCLEN+1];
	struct tm *ts;
	char str[12];

	for(entry=packlist; entry != NULL; entry=(struct name_rec*)(entry->hh.next))
	{
		ts = localtime(&entry->package_date);
		strftime(str, 11, "%Y-%m-%d", ts );
		LISTREC* rec = ListviewCreateRecord(listview->Window);
		if (rec)
		{
			swprintf(buffer, PKNAMELEN, _T("%s"), entry->package_name);
			ListviewSetColumnText(rec, 0, buffer);
			swprintf(buffer, PKVERSLEN, _T("%s"), entry->package_version);
			ListviewSetColumnText(rec, 1, buffer);
			swprintf(buffer,        11, _T("%s"), str);
			ListviewSetColumnText(rec, 2, buffer);
			if (entry->package_installed == 0)
			{
				swprintf(buffer,     2, _T(" " ));
			}
			else
			{
				swprintf(buffer,    10, _T("installed"));
			}
			ListviewSetColumnText(rec, 3, buffer);
			swprintf(buffer, PKDESCLEN, _T("%s"), entry->package_description);
			ListviewSetColumnText(rec, 4, buffer);
			swprintf(buffer,        12, _T("%d"), entry->package_repo);
			ListviewSetColumnText(rec, 5, buffer);
			ListviewInsertRecord(listview->Window, rec);
		}
	}
}

