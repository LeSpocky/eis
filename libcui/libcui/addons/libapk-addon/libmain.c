/* ---------------------------------------------------------------------
 * File: libmain.c 
 * main file of cui script module 
 *
 * Copyright (C) 2009  Daniel Vogel, <daniel@eisfair.org>
 *
 * Last Update:  $Id: libmain.c 4015 2013-02-25 17:33:07Z jv $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * ---------------------------------------------------------------------
 */

#include <cui.h>
#include <cui-script.h>
#include "pm_api.h"

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

#include <openssl/ssl.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/engine.h>

#include "apk_defines.h"
#include "apk_database.h"
#include "apk_applet.h"
#include "apk_blob.h"
#include "apk_print.h"
#include "apk_io.h"


StartFrameProc    LibPMStartFrame;
InsertStrProc     LibPMInsertStr;
InsertIntProc     LibPMInsertInt;
InsertLongProc    LibPMInsertLong;
SendFrameProc     LibPMSendFrame;
ExecFrameProc     LibPMExecFrame;
WriteErrorProc    LibPMWriteError;

StubCreateProc    LibPMStubCreate;
StubCheckStubProc LibPMStubCheck;
StubDeleteProc    LibPMStubDelete;
StubSetHookProc   LibPMStubSetHook;
StubSetProcProc   LibPMStubSetProc;
StubFindProc      LibPMStubFind;


static void fini_openssl(void)
{
	EVP_cleanup();
	ENGINE_cleanup();
	CRYPTO_cleanup_all_ex_data();
}

static void init_openssl(void)
{
	atexit(fini_openssl);
	OpenSSL_add_all_algorithms();
	ENGINE_load_builtin_engines();
	ENGINE_register_all_complete();
}


/* ---------------------------------------------------------------------
 * ModuleInit
 * Initialize module
 * ---------------------------------------------------------------------
 */
int
ModuleInit(MODULEINIT_T* modinit)
{
	LibPMStartFrame  = modinit->StartFrame;
	LibPMInsertStr   = modinit->InsertStr;
	LibPMInsertInt   = modinit->InsertInt;
	LibPMInsertLong  = modinit->InsertLong;
	LibPMSendFrame   = modinit->SendFrame;
	LibPMExecFrame   = modinit->ExecFrame;
	LibPMWriteError  = modinit->WriteError;
	
	LibPMStubCreate  = modinit->StubCreate;
	LibPMStubCheck   = modinit->StubCheck;
	LibPMStubDelete  = modinit->StubDelete;
	LibPMStubSetHook = modinit->StubSetHook;
	LibPMStubSetProc = modinit->StubSetProc;
	LibPMStubFind    = modinit->StubFind;

	init_openssl();
	
	PMApiInit();
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ModuleExecFunction
 * Execute the function that corresponds to the function number passed
 * in func_nr.
 * ---------------------------------------------------------------------
 */
int
ModuleExecFunction(int func_nr, int argc, const wchar_t* argv[])
{
	switch (func_nr)
	{
	case PM_API_REPOSTOMENU:
		PMApiReposToMenu(argc, argv);
		return TRUE;
	case PM_API_GETREPOBYID:
		PMApiGetRepoById(argc, argv);
		return TRUE;
	case PM_API_PACKAGESTOLIST:
		PMApiPackagesToList(argc, argv);
		return TRUE;
	case PM_API_INFOTOTEXTVIEW:
		PMApiInfoToTextView(argc, argv);
		return TRUE;	
	case PM_API_INSTALLED_TOLIST:		
		PMApiListInstalledPackages(argc, argv);	
		return TRUE;
	case PM_API_DEL_PACKTOLIST:		
		PMApiDelPackagesList(argc, argv);	
		return TRUE;		
	}

	return FALSE;	
}

/* ---------------------------------------------------------------------
 * ModuleClose
 * Free all data associated to this module
 * ---------------------------------------------------------------------
 */
int
ModuleClose(void)
{
	PMApiClear();
	return TRUE;
}

