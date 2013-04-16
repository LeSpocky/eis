/* ---------------------------------------------------------------------
 * File: api_util.h
 * (script api for cui-utils)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: api_util.c 33402 2013-04-02 21:32:17Z dv $
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

#include "global.h"
#include "cui-script.h"
#include "api.h"
#include "api_util.h"

#define MAX_MODULES 32

static ADDON_MODULE* AddonModule[MAX_MODULES];
static int           AddonModuleNextNr = 1;

/* ---------------------------------------------------------------------
 * AddonInit
 * Init addon module variables
 * ---------------------------------------------------------------------
 */
void 
AddonInit(void)
{
	memset(AddonModule, 0, sizeof(ADDON_MODULE*) * MAX_MODULES);
	AddonModuleNextNr = 1;
}

/* ---------------------------------------------------------------------
 * AddonClear
 * Free addon modules
 * ---------------------------------------------------------------------
 */
void 
AddonClear(void)
{
	int i = 0;
	for (i = 0; i < AddonModuleNextNr; i++)
	{
		if (AddonModule[i] && (AddonModule[i]->ModuleHandle))
		{
			AddonModule[i]->ModuleClose();
			dlclose(AddonModule[i]->ModuleHandle);
		}
	}	
}

/* ---------------------------------------------------------------------
 * AddonGetModule
 * Lookup the addon module number nr
 * ---------------------------------------------------------------------
 */
ADDON_MODULE* 
AddonGetModule(int nr)
{
	if ((nr >= 1) && (nr < MAX_MODULES))
	{
		return AddonModule[nr - 1];
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ApiXmlReadTag
 * Read tag data from a xml-file
 * ---------------------------------------------------------------------
 */
void
ApiXmlReadTag(int argc, const wchar_t* argv[])
{
	if (argc == 2)
	{
		XMLFILE* data =  XmlCreate (argv[0]);
		if (data)
		{
			if (XmlReadFile(data))
			{
				XMLOBJECT* obj = XmlSearch(data, argv[1]);
				if (obj)
				{
					XMLNODE* node;
					int      len;
					wchar_t*   result;

					len = 0;
					node = obj->FirstNode;
					while (node)
					{
						if (node->Type == XML_DATANODE)
						{
							len += wcslen(node->Data) + 1;
						}
						node = (XMLNODE*) node->Next;
					}

					result = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
					if (result)
					{
						node = obj->FirstNode;
						while (node)
						{
							if (node->Type == XML_DATANODE)
							{
								wcscat(result, node->Data);
								wcscat(result, _T(" "));
							}
							node = (XMLNODE*) node->Next;
						}
						BackendStartFrame(_T('R'), len + 32);
						BackendInsertInt (ERROR_SUCCESS);
						BackendInsertStr (result);
						BackendSendFrame ();

						free(result);
					}
				}
				else
				{
					BackendWriteError(ERROR_FAILED);
				}
			}
			else
			{
				BackendWriteError(ERROR_FAILED);
			}
			XmlDelete(data);
		}
		else
		{
			BackendWriteError(ERROR_INVALID);
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}

/* ---------------------------------------------------------------------
 * ApiLoadAddon
 * Load an addon module
 * ---------------------------------------------------------------------
 */
void 
ApiLoadAddon(int argc, const wchar_t* argv[])
{
	if (argc == 1)
	{
		ADDON_MODULE* newaddon = NULL;
		void* handle = NULL;
		int   err = 0;

		if (AddonModuleNextNr < MAX_MODULES)
		{
			char* mbfilename = TCharToMbDup(argv[0]);
			if (mbfilename)
			{
				handle = dlopen(mbfilename, RTLD_NOW);
				if (handle)
				{
					err = 1;
					
					newaddon = (ADDON_MODULE*) malloc(sizeof(ADDON_MODULE));
					if (newaddon)
					{
						MODULEINIT_T init;
						
						err = 2;
						
						newaddon->ModuleHandle       = handle;
						newaddon->ModuleInit         = dlsym(handle, "ModuleInit");
						newaddon->ModuleExecFunction = dlsym(handle, "ModuleExecFunction");
						newaddon->ModuleClose        = dlsym(handle, "ModuleClose");
						
						init.StartFrame  = BackendStartFrame;
						init.InsertStr   = BackendInsertStr;
						init.InsertInt   = BackendInsertInt;
						init.InsertLong  = BackendInsertLong;
						init.SendFrame   = BackendSendFrame;
						init.ExecFrame   = BackendExecFrame;
						init.WriteError  = BackendWriteError;
						
						init.StubCreate  = StubCreate;
						init.StubCheck   = StubCheckStub;
						init.StubDelete  = StubDelete;
						init.StubSetHook = StubSetHook;
						init.StubSetProc = StubSetProc;
						init.StubFind    = StubFind;

						if (!newaddon->ModuleInit  || !newaddon->ModuleExecFunction ||
						    !newaddon->ModuleClose || !newaddon->ModuleInit(&init))
						{
							err = 3;
							
							free(newaddon);
							newaddon = NULL;
						}
					}
					else
					{
						err = 4;
					}
				}
				else
				{
					err = 5;
				}
				free(mbfilename);	
			}
		}

		if (newaddon)
		{
			AddonModule[AddonModuleNextNr - 1] = newaddon;

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (AddonModuleNextNr * 10000);
			BackendSendFrame ();

			AddonModuleNextNr++;
		}
		else
		{
			if (handle)
			{
				dlclose(handle);
			}

			BackendStartFrame(_T('R'), 48);
			BackendInsertInt (ERROR_SUCCESS);
			BackendInsertInt (0);             // 0 is error
			BackendSendFrame ();
		}
	}
	else
	{
		BackendWriteError(ERROR_ARGC);
	}
}
