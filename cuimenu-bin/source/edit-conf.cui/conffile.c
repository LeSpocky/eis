/* ----------------------------------------------------------------------
 * File: conffile.c
 * (reading and writing configuration files for Eis/Fair)
 *
 * Copyright (C) 2004
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
 * ----------------------------------------------------------------------
 */

#include "global.h"
#include "conffile.h"
#include "check.h"
#include "cfg.h"

#define COMMENT_COL 40

static void       ConfFileDeleteItemNode   (CONFITEM* item);
static void       ConfFileAddItemCheck     (CONFITEM* item, const wchar_t* chkname);
static int        ConfFileAddItemValue     (CONFITEM* item, const wchar_t* name, const wchar_t* value);
static int        ConfFileAddItemDefault   (CONFITEM* item, const wchar_t* name, const wchar_t* value);
static void       ConfFileAddItemComment   (CONFITEM* item, const wchar_t* name, const wchar_t* value);
static void       ConfFileUseFooterComment (CONFFILE* conf);
static void       ConfFileAddHeaderComment (CONFFILE* conf, const wchar_t* value);
static void       ConfFileReorderTree      (CONFFILE* conf);
static void       ConfFileReorderChildren  (CONFITEM* item);
static void       ConfFileWrite            (CONFFILE* conf, FILE* out);
static int        ConfFileWriteValueByIndex(CONFITEM* item, int level, short* index, FILE* out);
static int        ConfFileIsNodeName       (const wchar_t* nodename, const wchar_t* name);
static unsigned char ConfFileGetHash       (short* index, int numindex);
static CONFITEM*  ConfFileFindItemByName   (CONFITEM* item, const wchar_t* name);
static CONFITEM*  ConfFileFindItemByIndex  (CONFITEM* item, int level, int* line, int lineindex, short* index);
//static CONFITEM*  ConfFileFindItemByOptNode(CONFITEM* item, CONFITEM* optnode);
static int        ConfFileFindIndexByIndex (CONFITEM* item, int level, int* line, int lineindex, short* index);
static int        ConfFileFindLineIndex    (CONFITEM* item, CONFITEM* cmpitem, int level,
                                            int* line, short* cmpindex, short* index);
static CONFVALUE* ConfFileFindValueByIndex (CONFITEM* item, int level, int* line, int lineindex, short* index);
static CONFVALUE* ConfFileFindValueByName  (CONFITEM* item, int level, const wchar_t* name, short* index);
static void       ConfFileCreateValueByIndex(CONFITEM* item, int level, int* line, int lineindex,
                                            short* index, int expand);
static int        ConfFileDeleteValueByIndex(CONFITEM* item, int level, int* line, int lineindex,
                                            short* index);

static void       ConfFileRemoveValueFromTable(CONFITEM* item, short* index, int numindex);
static void       ConfFileInsertValueIntoTable(CONFITEM* item, int numindex, CONFVALUE* valptr);
static void       ConfFileSwapValueIndex   (CONFITEM* item, short* index1, short* index2);

static const wchar_t* ConfFileGetItemDefaultValue(CONFITEM* item);
static void       ConfFileWriteToFile(const wchar_t* text, FILE* out);

static int        ConfFileShowOptional = FALSE;


/* ----------------------------------------------------------------------
 * ConfFileSetOptionalOn
 * Enable or disable empty optional values
 * ----------------------------------------------------------------------
 */
void ConfFileSetOptionalOn(int on)
{ ConfFileShowOptional = on; }

int ConfFileGetOptionalOn(void)
{ return ConfFileShowOptional; }


/* ----------------------------------------------------------------------
 * ConfigFileCreate
 * Create the control structure for a config file
 * ----------------------------------------------------------------------
 */
CONFFILE*
ConfFileCreate(ErrorCallback errout, void* instance)
{
	CONFFILE*  conf;

	conf = (CONFFILE*) malloc(sizeof(CONFFILE));
	conf->FirstItem = NULL;
	conf->LastItem = NULL;
	conf->DragItem = NULL;
	conf->FirstHeaderComment = NULL;
	conf->LastHeaderComment = NULL;
	conf->FirstFooterComment = NULL;
	conf->FirstTreeComment = NULL;
	conf->LastTreeComment = NULL;
	conf->FirstTmpComment = NULL;
	conf->LastTmpComment = NULL;
	conf->IsModified = FALSE;
	conf->IsSchemeModified = FALSE;
	conf->ErrorOut = errout;
	conf->Instance = instance;
	conf->NumOptional = 0;
	return conf;
}

/* ----------------------------------------------------------------------
 * ConfigFileDelete
 * Delete the control structure of a config file
 * ----------------------------------------------------------------------
 */
void
ConfFileDelete(CONFFILE* conf)
{
	CONFITEM* workptr;
	CONFCOMMENT* workcmmt;

	if (conf)
	{
		workptr = conf->FirstItem;
		while (workptr)
		{
			conf->FirstItem = (CONFITEM*) workptr->Next;
			ConfFileDeleteItemNode(workptr);
			workptr = conf->FirstItem;
		}

		workcmmt = conf->FirstHeaderComment;
		while (workcmmt)
		{
			conf->FirstHeaderComment = (CONFCOMMENT*) workcmmt->Next;
			if (workcmmt->Name) free(workcmmt->Name);
			if (workcmmt->Text) free(workcmmt->Text);
			free(workcmmt);
			workcmmt = conf->FirstHeaderComment;
		}

		workcmmt = conf->FirstFooterComment;
		while (workcmmt)
		{
			conf->FirstFooterComment = (CONFCOMMENT*) workcmmt->Next;
			if (workcmmt->Name) free(workcmmt->Name);
			if (workcmmt->Text) free(workcmmt->Text);
			free(workcmmt);
			workcmmt = conf->FirstFooterComment;
		}

		workcmmt = conf->FirstTreeComment;
		while (workcmmt)
		{
			conf->FirstTreeComment = (CONFCOMMENT*) workcmmt->Next;
			if (workcmmt->Name) free(workcmmt->Name);
			if (workcmmt->Text) free(workcmmt->Text);
			free(workcmmt);
			workcmmt = conf->FirstTreeComment;
		}

		workcmmt = conf->FirstTmpComment;
		while (workcmmt)
		{
			conf->FirstTmpComment = (CONFCOMMENT*) workcmmt->Next;
			if (workcmmt->Name) free(workcmmt->Name);
			if (workcmmt->Text) free(workcmmt->Text);
			free(workcmmt);
			workcmmt = conf->FirstTmpComment;
		}
		free(conf);
	}
}


/* ----------------------------------------------------------------------
 * ConfFileNumOptional
 * Return number of optional items
 * ----------------------------------------------------------------------
 */
int 
ConfFileNumOptional(CONFFILE* conf)
{
	return conf->NumOptional;
}


/* ----------------------------------------------------------------------
 * ConfFileReadCheck
 * This function reads the check.d file, that containes the sceleton of
 * the config structure
 * ----------------------------------------------------------------------
 */
void
ConfFileReadCheck(CONFFILE* conf, const wchar_t* filename, EXPFILE* expfile)
{
	if (!conf || !conf->ErrorOut)
	{
		return;
	}

	if (!CheckFileOpen(filename, conf->ErrorOut, conf->Instance))
	{
		conf->ErrorOut(conf->Instance, _T("file not found"), filename, 0, FALSE);
	}
	else
	{
		int sym = CheckRead();

		/* read file data */
		while (sym != CHECK_EOF)
		{
			int type = TYPE_REQUIRED;

			/* read optional node type '+' or '++' */
			if (sym == CHECK_OPT_ELEM)
			{
				type = TYPE_OPTIONAL;
				sym = CheckRead();
			}
			else if (sym == CHECK_OPT_ARRAY_ELEM)
			{
				type = TYPE_OPTARRAY;
				sym = CheckRead();
			}

			/* read identifier */
			if (sym == CHECK_IDENT)
			{
				CONFITEM* nnode = NULL;
				CONFITEM* optnode = NULL;
				wchar_t  name  [128 + 1];
				wchar_t  optvar[128 + 1];
				wchar_t  nvar  [128 + 1];
				wchar_t  check [128 + 1];
				wchar_t* regex;
				int    invert = FALSE;

				CheckGetTextCpy(name, 128);

				/* depending options node */
				sym = CheckRead();
				if (sym == CHECK_INVERT)
				{
					invert = TRUE;
					sym = CheckRead();
				}

				if (sym == CHECK_HYPHEN)
				{
					optvar[0] = 0;
				}
				else if (sym == CHECK_IDENT)
				{
					CheckGetTextCpy(optvar, 128);
				}
				else
				{
					conf->ErrorOut(conf->Instance,
						_T("missing '-' or identifier"),
						CheckGetFileName(),
						CheckGetLineNumber(),
						FALSE);
					sym = CheckRecoverFromError();
					continue;
				}

				/* depending n node */
				sym = CheckRead();
				if (sym == CHECK_HYPHEN)
				{
					nvar[0] = 0;
				}
				else if (sym == CHECK_IDENT)
				{
					CheckGetTextCpy(nvar, 128);
				}
				else
				{
					conf->ErrorOut(conf->Instance,
						_T("missing '-' or identifier"),
						CheckGetFileName(),
						CheckGetLineNumber(),
						FALSE);
					sym = CheckRecoverFromError();
					continue;
				}

				/* check value */
				sym = CheckRead();
				if (sym == CHECK_REGEXP)
				{
					regex = CheckGetTextDup();
					if (regex)
					{
						ExpSetCurrentFileName(expfile,CheckGetFileName());
						ExpSetCurrentFilePos(expfile,CheckGetLineNumber());
						ExpAddSingleExpression(expfile,
							name,
							&regex[3],      /* Read from RE: to end of text */
							_T("invalid data entered"),
							FALSE,
							conf->ErrorOut,
							conf->Instance);
						ExpSetCurrentFileName(expfile,NULL);

						wcsncpy(check, name, 128);
						check[128] = 0;
						free(regex);
					}
				}
				else  if (sym == CHECK_IDENT)
				{
					CheckGetTextCpy(check, 128);
					if (!ExpHasExpression(expfile,check))
					{
						conf->ErrorOut(conf->Instance,
							_T("unable to resolve option type! unknown reg. expression!"),
							CheckGetFileName(),
							CheckGetLineNumber(),
							FALSE);
					}
				}
				else
				{
					conf->ErrorOut(conf->Instance,
						_T("missing identifier"),
						CheckGetFileName(),
						CheckGetLineNumber(),
						FALSE);
					sym = CheckRecoverFromError();
					continue;
				}

				if (name[0] != 0)
				{
					CONFITEM* item = ConfFileFindItem(conf, name);
					if (item)
					{
						/* add an additional reference to an existing item */
						ConfFileAddItemCheck(item,check);
					}
					else
					{
						/* create a new item */
						if (nvar[0] != 0)
						{
							nnode = ConfFileFindItem(conf, nvar);
							if (!nnode)
							{
								conf->ErrorOut(conf->Instance,
									_T("unable to resolve N-variable"),
									CheckGetFileName(),
									CheckGetLineNumber(),
									FALSE);
								sym = CheckRecoverFromError();
								continue;
							}
						}
						if (optvar[0] != 0)
						{
							optnode = ConfFileFindItem(conf, optvar);
							if (!optnode)
							{
								conf->ErrorOut(conf->Instance,
									_T("unable to resolve OPT-variable"),
									CheckGetFileName(),
									CheckGetLineNumber(),
									FALSE);
								sym = CheckRecoverFromError();
								continue;
							}
						}
						ConfFileAddItem(conf,name,check,nnode,optnode,invert,NULL,type,FALSE);
					}

					/* optionally the check file may contain a fifth column with a string value */
					/* this value is used as a default value for values associated with this item */
					/* and overwrites values read from default.d! This is a fli4l extention. */
					sym = CheckRead();
					if (sym == CHECK_STRING)
					{
						CONFITEM* item = ConfFileFindItem(conf, name);
						if (item)
						{
							item->DefaultValue = CheckGetStringDup();
						}
						sym = CheckRead();
					}
					else if ((sym != CHECK_NL) && (sym != CHECK_EOF))
					{
						conf->ErrorOut(conf->Instance,
							_T("missing end of line"),
							CheckGetFileName(),
							CheckGetLineNumber(),
							FALSE);
						sym = CheckRecoverFromError();
						continue;
					}
				}

				/* done! now consume the newline character and continue with next line */
				if ((sym != CHECK_NL) && (sym != CHECK_EOF))
				{
					if ((sym != CHECK_NL) && (sym != CHECK_EOF))
					{
						conf->ErrorOut(conf->Instance,
							_T("missing end of line"),
							CheckGetFileName(),
							CheckGetLineNumber(),
							FALSE);
						sym = CheckRecoverFromError();
						continue;
					}
				}
			}
			else if (sym != CHECK_NL)
			{
				conf->ErrorOut(conf->Instance,
					_T("syntax error"),
					CheckGetFileName(),
					CheckGetLineNumber(),
					FALSE);
				sym = CheckRecoverFromError();
				continue;
			}

			/* start with new line */
			sym = CheckRead();
		}
		CheckClose();
	}
}


/* -----------------------------------------------------------------------
 * ConfFileReadConfig
 * This function reads the config.d file that fills the sceleton of
 * the config structure with data entries
 * -----------------------------------------------------------------------
 */
void
ConfFileReadConfig(CONFFILE* conf, const wchar_t* filename,
                   const wchar_t* chkbase, int tolerant)
{
	if (!conf || !conf->ErrorOut)
	{
		return;
	}

	if (!CfgFileOpen(filename, conf->ErrorOut, conf->Instance))
	{
		conf->ErrorOut(conf->Instance, _T("file not found"), filename, 0, FALSE);
	}
	else
	{
		int sym = CfgRead();
		while (sym != CFG_EOF)
		{
			if (sym == CFG_IDENT)
			{
				wchar_t optname[128 + 1];

				CfgGetTextCpy(optname, 128);

				sym = CfgRead();

				if (sym != CFG_EQUAL)
				{
					conf->ErrorOut(conf->Instance,
						_T("missing '='"),
						CfgGetFileName(),
						CfgGetLineNumber(),
						FALSE);

					sym = CfgRecoverFromError();
				}
				else
				{
					sym = CfgRead();
					if (sym != CFG_STRING)
					{
						conf->ErrorOut(conf->Instance,
							_T("missing string constant"),
							CfgGetFileName(),
							CfgGetLineNumber(),
							FALSE);

						sym = CfgRecoverFromError();
					}
					else
					{
						CONFITEM* item = ConfFileFindItem(conf,optname);
						if (!item && tolerant)
						{
							ConfFileAddItem(conf,optname,_T("NONE"),NULL,NULL,FALSE,NULL,TYPE_REQUIRED,TRUE);

							item = ConfFileFindItem(conf,optname);
							if (item)
							{
								ConfFileAddBlockComment(conf,
									_T("#--------------------------------------")
									_T("---------------------------------------"));
								ConfFileAddBlockComment(conf,
									_T("# User variable (UNCHECKED)"));
								ConfFileAddBlockComment(conf,
									_T("#---------------------------------------")
									_T("--------------------------------------"));
								ConfFileUseBlockComment(conf, item, optname);
							}
						}
						if (item)
						{
							wchar_t* str = CfgGetStringDup();
							if (str)
							{
								if (!ConfFileAddItemValue(item,optname,str))
								{
									conf->ErrorOut(conf->Instance,
										_T("hierarchcal nesting error. ")
										_T("Not enough values in name"),
										CfgGetFileName(),
										CfgGetLineNumber(),
										FALSE);
								}
								free(str);
							}
						}
						else
						{
							wchar_t buffer[300 + 1];
							swprintf(buffer, 300, 
								_T("'%ls' not found in check file! ")
								_T("Every option needs to have a corresponding entry ")
								_T("within the file under '%ls'!"), 
								optname, chkbase);
							conf->ErrorOut(conf->Instance,
								buffer,
								CfgGetFileName(),
								CfgGetLineNumber(),
								FALSE);
						}
						sym = CfgRead();
					}
				}
			}
			if ((sym != CFG_COMMENT) && (sym != CFG_LINE_COMMENT) && (sym != CFG_NL) && (sym != CFG_EOF))
			{
				conf->ErrorOut(conf->Instance,
					_T("syntax error"),
					CfgGetFileName(),
					CfgGetLineNumber(),
					FALSE);
			}
			sym = CfgRead();
		}
		CfgClose();
	}
}

/* -----------------------------------------------------------------------
 * ReadDefaultFile
 * This function reads the default.d file that fills the sceleton of
 * the config structure with default data entries that are used when new
 * nodes are created
 * -----------------------------------------------------------------------
 */
void
ConfFileReadDefault(CONFFILE* conf, const wchar_t* filename,
                    const wchar_t* chkbase, int tolerant)
{
	if (!conf || !conf->ErrorOut)
	{
		return;
	}

	if (!CfgFileOpen(filename, conf->ErrorOut, conf->Instance))
	{
		conf->ErrorOut(conf->Instance, _T("file not found"), filename, 0, FALSE);
	}
	else
	{
		int sym = CfgRead();

		/* read file comment header */
		while (sym == CFG_LINE_COMMENT)
		{
			ConfFileAddHeaderComment(conf, CfgGetComment());
			sym = CfgRead();
		}

		/* read file data */
		while (sym != CFG_EOF)
		{
			if (sym == CFG_IDENT)
			{
				wchar_t optname[128 + 1];

				CfgGetTextCpy(optname, 128);

				sym = CfgRead();

				if (sym != CFG_EQUAL)
				{
					conf->ErrorOut(conf->Instance,
						_T("missing '='"),
						CfgGetFileName(),
						CfgGetLineNumber(),FALSE);

					sym = CfgRecoverFromError();
				}
				else
				{
					sym = CfgRead();
					if (sym != CFG_STRING)
					{
						conf->ErrorOut(conf->Instance,
							_T("missing string constant"),
							CfgGetFileName(),
							CfgGetLineNumber(),
							FALSE);
						sym = CfgRecoverFromError();
					}
					else
					{
						CONFITEM* item;
						int virt_item = FALSE;

						item  = ConfFileFindItem(conf,optname);
						if (!item && tolerant)
						{
							ConfFileAddItem(conf,optname,_T("NONE"),NULL,NULL,FALSE,NULL,TYPE_REQUIRED,FALSE);
							item = ConfFileFindItem(conf,optname);
							virt_item = TRUE;
						}
						if (item)
						{
							wchar_t* str = CfgGetStringDup();
							if (str)
							{
								if (!ConfFileAddItemDefault(item,optname,str))
								{
									conf->ErrorOut(conf->Instance,
										_T("hierarchcal nesting error. ")
										_T("Not enough values in name"),
										CfgGetFileName(),
										CfgGetLineNumber(),
										FALSE);
								}
								else if (!virt_item)
								{
									ConfFileUseBlockComment(conf,item,optname);
								}
								free(str);
							}
						}
						else
						{
							wchar_t buffer[300 + 1];
							swprintf(buffer, 300, 
								_T("'%ls' not found in check file! ")
								_T("Every option needs to have a corresponding entry ")
								_T("within the file under '%ls'!"),
								optname, chkbase);
							conf->ErrorOut(conf->Instance,
								buffer,
								CfgGetFileName(),
								CfgGetLineNumber(),
								FALSE);
						}
						sym = CfgRead();

						if ((sym != CFG_NL) && (sym != CFG_COMMENT) && (sym != CFG_EOF))
						{
							conf->ErrorOut(conf->Instance,
								_T("syntax error"),
								CfgGetFileName(),
								CfgGetLineNumber(),
								FALSE);
						}
						else
						{
							/* read the first NL that may separate the value and it's comment */
							if (sym == CFG_NL)
							{
								sym = CfgRead();
							}

							/* read values's assoc. comment */
							while (sym == CFG_COMMENT)
							{
								ConfFileAddItemComment(item,optname,CfgGetComment());
								sym = CfgRead();
							}
						}
					}
				}
			}
			else if (sym == CFG_LINE_COMMENT)
			{
				ConfFileAddBlockComment(conf,CfgGetComment());
				sym = CfgRead();
			}
			else if ((sym != CFG_COMMENT) && (sym != CFG_NL) && (sym != CFG_EOF))
			{
				conf->ErrorOut(conf->Instance,
					_T("syntax error"),
					CfgGetFileName(),
					CfgGetLineNumber(),
					FALSE);

				sym = CfgRecoverFromError();
			}
			else
			{
				sym = CfgRead();
			}
		}
		ConfFileUseFooterComment(conf);
		ConfFileReorderTree(conf);
		CfgClose();
	}
}

/* -----------------------------------------------------------------------
 * ConfFileWriteConfig
 * This function writes the contents of the confedit tree to the
 * file specified by 'filename'
 * -----------------------------------------------------------------------
 */
void
ConfFileWriteConfig(CONFFILE* conf, const wchar_t* filename)
{
	FILE* out;

	if (!conf || !conf->ErrorOut)
	{
		return;
	}

	out = FileOpen(filename, _T("wt"));
	if (!out)
	{
		conf->ErrorOut(conf->Instance,_T("unable to open file"),filename,0,FALSE);
	}
	else
	{
		ConfFileWrite(conf,out);
		if (ferror(out))
		{
			conf->ErrorOut(conf->Instance,_T("error writing file"),filename,0,FALSE);
		}
		FileClose(out);
	}
}

/* ---------------------------------------------------------------------
 * ConfFileAddItem
 * The sceleton of a config file (read from check.d) consists of items
 * that form a tree structure. With this function a new item is added
 * to the tree.
 * The parent item of the new item is 'nnode'. If the item shall be
 * added to the root node instead, pass NULL in 'nnode' parameter.
 * The 'optnode' parameter defines an other item, on which the visibility
 * of the new item depends on. If no dependency is required pass 'NULL'
 * in 'optnode' parameter.
 * If 'appnode' is set, the new item is appended to this node, if
 * possible.
 * ---------------------------------------------------------------------
 */
void
ConfFileAddItem(CONFFILE* conf, const wchar_t* name, const wchar_t* check, CONFITEM* nnode,
             CONFITEM* optnode, int invert, CONFITEM* appnode, int type, int isvirtual)
{
	CONFITEM* newitem;
	if (conf)
	{
		int count = 0;
		int pos = 0;
		int i;

		newitem = (CONFITEM*) malloc(sizeof(CONFITEM));

		newitem->Name = wcsdup(name);
		newitem->Type = type;
		newitem->Config = conf;
		newitem->OptNode = optnode;
		newitem->Parent = nnode;
		newitem->Next = NULL;
		newitem->Previous = NULL;
		newitem->Last = NULL;
		newitem->Child = NULL;
		newitem->FirstComment = NULL;
		newitem->LastComment = NULL;
		newitem->FirstBlockComment = NULL;
		newitem->LastBlockComment = NULL;
		newitem->NumBlockComments = 0;
		newitem->SequenceNr = 0;
		newitem->IsVirtual = isvirtual;
		newitem->IsMasked = (wcscasecmp(check, _T("PASSWD")) == 0);
		newitem->IsHidden = (wcscasecmp(check, _T("HIDDEN")) == 0);
		newitem->IsReadOnly = (wcscasecmp(check, _T("READONLY")) == 0);
		newitem->IsInvertOpt = invert;
		newitem->DefaultValue = NULL;

		/* init hash tables */
		for (i = 0; i < HASH_SIZE; i++)
		{
			newitem->Values[i] = NULL;
			newitem->Defaults[i] = NULL;
		}

		/* create check entry */
		newitem->FirstCheck = (CONFCHECK*) malloc(sizeof(CONFCHECK));
		newitem->FirstCheck->Name = wcsdup(check);
		newitem->FirstCheck->Next = NULL;
		newitem->LastCheck = newitem->FirstCheck;

		/* build mask value from name */
		for (i = 0; i < (int)wcslen(newitem->Name); i++)
		{
			if (newitem->Name[i] == '%') count++;
		}
		newitem->ReadMask = (wchar_t*) malloc((wcslen(newitem->Name) + count + 1) * sizeof(wchar_t));
		newitem->WriteMask = (wchar_t*) malloc((wcslen(newitem->Name) + count + 1) * sizeof(wchar_t));
		for (i = 0; i < (int)wcslen(newitem->Name); i++)
		{
			newitem->ReadMask[pos] = newitem->Name[i];
			newitem->WriteMask[pos] = newitem->Name[i];
			pos++;
			if (newitem->Name[i] == _T('%'))
			{
				newitem->WriteMask[pos] = _T('i');
				newitem->ReadMask[pos] = _T('d');
				pos++;
			}
			newitem->ReadMask[pos] = 0;
			newitem->WriteMask[pos] = 0;
		}

		if ((newitem->Type == TYPE_OPTIONAL) || (newitem->Type == TYPE_OPTARRAY))
		{
			conf->NumOptional++;
		}

		/* now add item to tree */
		if (nnode)
		{
			CONFITEM* workptr = NULL;
			if (appnode)
			{
				workptr = nnode->Child;
				while (workptr && (workptr != appnode))
				{
					workptr = (CONFITEM*) workptr->Next;
				}
			}
			if (workptr)
			{
				newitem->Next = workptr->Next;
				newitem->Previous = workptr;
				workptr->Next = newitem;
				if (nnode->Last == workptr)
				{
					nnode->Last = newitem;
				}
			}
			else
			{
				newitem->Level = nnode->Level + 1;
				if (nnode->Last)
				{
					((CONFITEM*)nnode->Last)->Next = (void*) newitem;
				}
				else
				{
					nnode->Child = newitem;
				}
				newitem->Previous = nnode->Last;
				nnode->Last = newitem;
			}
		}
		else
		{
			CONFITEM* workptr = NULL;
			if (appnode)
			{
				workptr = conf->FirstItem;
				while (workptr && workptr != appnode)
				{
					workptr = (CONFITEM*) workptr->Next;
				}
			}
			newitem->Level = 0;

			if (workptr)
			{
				newitem->Next = workptr->Next;
				workptr->Previous = workptr;
				workptr->Next = newitem;
				if (conf->LastItem == workptr)
				{
					conf->LastItem = newitem;
				}
			}
			else
			{
				if (conf->LastItem)
				{
					conf->LastItem->Next = (void*) newitem;
				}
				else
				{
					conf->FirstItem = newitem;
				}
				newitem->Previous = conf->LastItem;
				conf->LastItem = newitem;
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileDeleteItem
 * Delete 'item' from the item tree
 * ---------------------------------------------------------------------
 */
void
ConfFileDeleteItem(CONFFILE* conf, CONFITEM* item)
{
	if (conf && item)
	{
		if (item->Parent)
		{
			CONFITEM* workptr = ((CONFITEM*)item->Parent)->Child;
			if (workptr == item)
			{
				((CONFITEM*)item->Parent)->Child = (CONFITEM*) workptr->Next;
				if (((CONFITEM*)item->Parent)->Last == item)
				{
					((CONFITEM*)item->Parent)->Last = NULL;
				}
				ConfFileDeleteItemNode(item);
			}
			else
			{
				while (workptr && (workptr->Next != item))
				{
					workptr = (CONFITEM*) workptr->Next;
				}
				if (workptr)
				{
					workptr->Next = (CONFITEM*) item->Next;
					if (((CONFITEM*)item->Parent)->Last == item)
					{
						((CONFITEM*)item->Parent)->Last = workptr;
					}
					ConfFileDeleteItemNode(item);
				}
			}
		}
		else
		{
			CONFITEM* workptr = (CONFITEM*) conf->FirstItem;
			if (workptr == item)
			{
				conf->FirstItem = (CONFITEM*) workptr->Next;
				if (conf->LastItem == item)
				{
					conf->LastItem = NULL;
				}
				ConfFileDeleteItemNode(item);
			}
			else
			{
				while (workptr && (workptr->Next != item))
				{
					workptr = (CONFITEM*) workptr->Next;
				}
				if (workptr)
				{
					workptr->Next = (CONFITEM*) item->Next;
					if (conf->LastItem == item)
					{
						conf->LastItem = workptr;
					}
					ConfFileDeleteItemNode(item);
				}
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileFindItem
 * Seek the config item tree for an item with the name 'name'. This is
 * done by calling the recursive function 'FindItemByName'
 * ---------------------------------------------------------------------
 */
CONFITEM*
ConfFileFindItem(CONFFILE* conf, const wchar_t* name)
{
	if (conf)
	{
		CONFITEM* workptr = conf->FirstItem;
		while (workptr)
		{
			CONFITEM* ptr = ConfFileFindItemByName(workptr, name);
			if (ptr)
			{
				return ptr;
			}
			workptr = (CONFITEM*) workptr->Next;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileFindValue
 * Search a given value by it's name within the config file tree
 * It does not matter if the value is visible or not
 * ---------------------------------------------------------------------
 */
CONFVALUE*
ConfFileFindValue(CONFFILE* conf, const wchar_t* name)
{
	CONFITEM* workptr;
	CONFVALUE* result = NULL;
	short index[5];       /* only five hierarchy levels */

	workptr = conf->FirstItem;
	while (workptr)
	{
		result = ConfFileFindValueByName(workptr, 0, name, index);
		if (result) break;

		workptr = (CONFITEM*) workptr->Next;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ConfFileGetItem
 * Retreive the item specified by 'lineindex'. Note that 'lineindex'
 * has to be recursively translated into a tree position. Since
 * an item can contain multible values it can be in effect on multible
 * lines
 * ---------------------------------------------------------------------
 */
CONFITEM*
ConfFileGetItem (CONFFILE* conf, int lineindex)
{
	CONFITEM* workptr;
	CONFITEM* result = NULL;
	int   line = 0;
	short index[NUM_DIM];       /* only five hierarchy levels */

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr, index, 0))
		{
			result = ConfFileFindItemByIndex(workptr, 0, &line, lineindex, index);
			if (result) break;
		}
		workptr = (CONFITEM*) workptr->Next;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ConfFileGetValue
 * Retreive the value specified by 'lineindex'. Note that 'lineindex'
 * has to be recursively translated into a tree position. Since
 * a value can be optional, the result may be NULL.
 * ---------------------------------------------------------------------
 */
CONFVALUE*
ConfFileGetValue(CONFFILE* conf, int lineindex)
{
	CONFITEM* workptr;
	CONFVALUE* result = NULL;
	int   line = 0;
	short index[5];       /* only five hierarchy levels */

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr,index,0))
		{
			result = ConfFileFindValueByIndex(workptr, 0, &line, lineindex, index);
			if (result) break;
		}
		workptr = (CONFITEM*) workptr->Next;
	}
	return result;
}



/* ---------------------------------------------------------------------
 * ConfFileArrayLookupValue
 * Reads out an item's value with the array coordinates specified
 * within the int array 'index'.
 * ---------------------------------------------------------------------
 */
CONFVALUE*
ConfFileArrayLookupValue(CONFITEM* item, short* index, int numindex)
{
	CONFVALUE* workptr;

	if (item)
	{
		unsigned char hash;

		int factor = (item->Level < numindex) ? item->Level : numindex;
		int size = factor*sizeof(short);

		hash = ConfFileGetHash(index,factor);

		workptr = item->Values[hash];
		while (workptr)
		{
			if (memcmp(index,workptr->Index,size)==0)
			{
				return workptr;
			}
			workptr = (CONFVALUE*) workptr->Next;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileArrayLookupDefault
 * Reads out an item's default value with the array coordinates specified
 * within the int array 'index'.
 * ---------------------------------------------------------------------
 */
CONFVALUE*
ConfFileArrayLookupDefault(CONFITEM* item, short* index, int numindex)
{
	CONFVALUE* workptr;

	if (item)
	{
		unsigned char hash;

		int factor = (item->Level < numindex) ? item->Level : numindex;
		int size = factor * sizeof(short);

		hash = ConfFileGetHash(index,factor);

		workptr = item->Defaults[hash];
		while (workptr)
		{
			if (memcmp(index,workptr->Index,size)==0)
			{
				return workptr;
			}
			workptr = (CONFVALUE*) workptr->Next;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileArrayLookupComment
 * Reads out an item's comment with the array coordinates specified
 * within the int array 'index'.
 * ---------------------------------------------------------------------
 */
CONFCOMMENT*
ConfFileArrayLookupComment(CONFITEM* item, short* index, int numindex, CONFCOMMENT* last)
{
	CONFCOMMENT* workptr;

	if (item)
	{
		int factor = (item->Level < numindex) ? item->Level : numindex;
		int size = factor * sizeof(short);

		if (last) workptr = (CONFCOMMENT*) last->Next;
		else workptr = item->FirstComment;

		while (workptr)
		{
			if (memcmp(index,workptr->Index,size)==0)
			{
				return workptr;
			}
			workptr = (CONFCOMMENT*) workptr->Next;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileLookupBlockComment
 * Reads out an item's block comment with the array coordinates specified
 * within the int array 'index'.
 * ---------------------------------------------------------------------
 */
CONFCOMMENT*
ConfFileLookupBlockComment(CONFITEM* item, short* index, int numindex, CONFCOMMENT* last)
{
	CONFCOMMENT* workptr;

	if (item)
	{
		int factor = (item->Level < numindex) ? item->Level : numindex;
		int size = factor * sizeof(short);

		if (last) workptr = (CONFCOMMENT*) last->Next;
		else workptr = item->FirstBlockComment;

		while (workptr)
		{
			if (memcmp(index,workptr->Index,size)==0)
			{
				return workptr;
			}
			workptr = (CONFCOMMENT*) workptr->Next;
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileArrayLookupName
 * Use the the specified coordinates (index) to form the correct
 * value name from an item's 'Mask'. (instance name)
 * Note: Only five dimensions are implemented right now!
 * ---------------------------------------------------------------------
 */
const wchar_t*
ConfFileArrayLookupName(CONFITEM* item, short* index, int numindex, wchar_t* buffer, int len)
{
	CUI_USE_ARG(numindex);
	
	buffer[0] = 0;
	if (item)
	{
		swprintf(buffer, len, item->WriteMask, index[0], index[1], index[2], index[3], index[4]);
		buffer[len] = 0;
	}
	return buffer;
}

/* ---------------------------------------------------------------------
 * ConfFileArrayLookupVisible
 * Use the specified coordinates (index) to retrieve the visibility
 * state of a certain value by resolving the item's 'optnode'.
 * ---------------------------------------------------------------------
 */
int
ConfFileArrayLookupVisible(CONFITEM* item, short* index, int numindex)
{
	if (item && item->IsHidden)
	{
		return FALSE;
	}
	else if (item)
	{
		int invert = item->IsInvertOpt;
		CONFITEM* workptr;
		
		/* hide empty optional values */
		if ((!ConfFileShowOptional) &&
		    ((item->Type == TYPE_OPTIONAL) || (item->Type == TYPE_OPTARRAY)))
		{
			CONFVALUE* val = ConfFileArrayLookupValue(item, index, numindex);
			if (!val)
			{
				return FALSE;
			}
		}

		/* check if opt node is set to "yes" */
		workptr = item->OptNode;
		while (workptr)
		{
			CONFVALUE* val = ConfFileArrayLookupValue(workptr,index,numindex);
			if (val)
			{
				if (((!invert) && (wcscasecmp(val->Value, _T("no"))==0)) ||
				    ((invert) && (wcscasecmp(val->Value, _T("yes"))==0)))
				{
					return FALSE;
				}
			}
			invert = workptr->IsInvertOpt;
			workptr = (CONFITEM*) workptr->OptNode;
		}
	}
	return TRUE;
}

/* ---------------------------------------------------------------------
 * ConfFileArrayDeleteValue
 * Delete an item's value with the array coordinates specified
 * within the int array 'index'.
 * ---------------------------------------------------------------------
 */
void
ConfFileArrayDeleteValue(CONFITEM* item, short* index, int numindex)
{
	CONFVALUE* workptr;
	CONFVALUE* oldptr;

	if (item)
	{
		unsigned char hash;

		int factor = (item->Level < numindex) ? item->Level : numindex;
		int size = factor * sizeof(short);

		hash = ConfFileGetHash(index,factor);

		workptr = item->Values[hash];
		while (workptr)
		{
			if (memcmp(index,workptr->Index,size) == 0)
			{
				if (workptr == item->Values[hash])
				{
					item->Values[hash] = (CONFVALUE*) workptr->Next;
					free(workptr->Name);
					free(workptr->Value);
					free(workptr);
					workptr = item->Values[hash];
				}
				else
				{
					oldptr->Next = workptr->Next;
					free(workptr->Name);
					free(workptr->Value);
					free(workptr);
					workptr = (CONFVALUE*) oldptr->Next;
				}
			}
			else
			{
				oldptr = workptr;
				workptr = (CONFVALUE*) workptr->Next;
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileGetIndex
 * Retreive the index associated with 'lineindex'. Note that 'lineindex'
 * has to be recursively translated into a tree position. This works
 * even if value is NULL at 'lineindex'.
 * ---------------------------------------------------------------------
 */
int
ConfFileGetIndex(CONFFILE* conf, int lineindex, short* index)
{
	CONFITEM* workptr;
	int   result;
	int   line = 0;

	memset(index, 0, NUM_DIM * sizeof(short));

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr,index,0))
		{
			result = ConfFileFindIndexByIndex(workptr, 0, &line, lineindex, index);
			if (result) break;
		}
		workptr = (CONFITEM*) workptr->Next;
	}
	return result;
}


/* ---------------------------------------------------------------------
 * ConfFileStartDrag
 * Start drag operation
 * ---------------------------------------------------------------------
 */
int
ConfFileStartDrag(CONFFILE* conf, int lineindex)
{
	CONFITEM* item = ConfFileGetItem(conf, lineindex);

	conf->DragItem = NULL;
	if (item && item->Parent)
	{
		conf->DragItem = (CONFITEM*) item->Parent;
		ConfFileGetIndex(conf, lineindex, conf->DragIndex);
	}
	return (conf->DragItem != NULL);
}

/* ---------------------------------------------------------------------
 * ConfFileDragValueUp
 * Drag a value up (meaning move it to a lower array index)
 * ---------------------------------------------------------------------
 */
int
ConfFileDragValueUp(CONFFILE* conf, int* newlineindex)
{
	if (conf->DragItem)
	{
		int level = conf->DragItem->Level;

		CONFVALUE* val = ConfFileArrayLookupValue(conf->DragItem, conf->DragIndex, level);
		if (val)
		{
			int actindex;
			actindex = conf->DragIndex[level];

			if (actindex > 1)
			{
				short newindex[NUM_DIM];

				memcpy(newindex, conf->DragIndex, NUM_DIM * sizeof(short));
				newindex[level] = actindex - 1;

				ConfFileSwapValueIndex(conf->DragItem, conf->DragIndex, newindex);
				conf->DragIndex[level] = actindex - 1;

				conf->IsModified = TRUE;
				if (conf->DragItem->Child && newlineindex)
				{
					*newlineindex = ConfFileGetLineIndex(conf, conf->DragItem->Child, newindex);
				}
				return TRUE;
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileDragValueDown
 * Drag a value down (meaning move it to a higher array index)
 * ---------------------------------------------------------------------
 */
int
ConfFileDragValueDown(CONFFILE* conf, int* newlineindex)
{
	if (conf->DragItem)
	{
		int level = conf->DragItem->Level;

		CONFVALUE* val = ConfFileArrayLookupValue(conf->DragItem, conf->DragIndex, level);
		if (val)
		{
			int maxindex;
			int actindex;

			swscanf(val->Value, _T("%d"), &maxindex);
			actindex = conf->DragIndex[level];

			if (actindex < maxindex)
			{
				short newindex[NUM_DIM];

				memcpy(newindex, conf->DragIndex, NUM_DIM * sizeof(short));
				newindex[level] = actindex + 1;

				ConfFileSwapValueIndex(conf->DragItem, conf->DragIndex, newindex);
				conf->DragIndex[level] = actindex + 1;

				conf->IsModified = TRUE;
				if (conf->DragItem->Child && newlineindex)
				{
					CONFITEM* workptr = conf->DragItem->Child;
					while (workptr->Next)
					{
						workptr = (CONFITEM*) workptr->Next;
					}
					*newlineindex = ConfFileGetLineIndex(conf, workptr, newindex);
				}
				return TRUE;
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileEndDrag
 * End drag operation
 * ---------------------------------------------------------------------
 */
void
ConfFileEndDrag(CONFFILE* conf)
{
	conf->DragItem = NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileGetLineIndex
 * Search the tree to find the position of the first position matching
 * item and index
 * ---------------------------------------------------------------------
 */
int
ConfFileGetLineIndex(CONFFILE* conf, CONFITEM* item, short* cmpindex)
{
	CONFITEM* workptr;
	int   result = -1;
	int   line = 0;
	short index[NUM_DIM];

	memset(index, 0, NUM_DIM * sizeof(short));

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr,index,0))
		{
			result = ConfFileFindLineIndex(workptr,item,0,&line,cmpindex,index);
			if (result >= 0)
			{
				break;
			}
		}
		workptr = (CONFITEM*) workptr->Next;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * ConfFileCreateValue
 * Create  the value specified by 'lineindex' if necessary. If it is a N-Node
 * ensure that enough underlying values exist in the tree.
 * ---------------------------------------------------------------------
 */
void
ConfFileCreateValue(CONFFILE* conf, int lineindex)
{
	CONFITEM* workptr;
	int   line = 0;
	short index[5];       /* only five hierarchy levels */

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr, index, 0))
		{
			ConfFileCreateValueByIndex(workptr,
				0,
				&line,
				lineindex,
				index,
				(line == lineindex) && (workptr->Type!=TYPE_OPTIONAL));

			if (line > lineindex) break;
		}
		workptr = (CONFITEM*) workptr->Next;
	}
}

/* ---------------------------------------------------------------------
 * ConfFileDeleteValue
 * Delete the value specified by 'lineindex' if possible.
 * The value can only be deleted if it's type is TYPE_OPTIONAL.
 * ---------------------------------------------------------------------
 */
int
ConfFileDeleteValue(CONFFILE* conf, int lineindex)
{
	CONFITEM* workptr;
	int   line = 0;
	short index[5];       /* only five hierarchy levels */

	workptr = conf->FirstItem;
	while (workptr)
	{
		if (ConfFileArrayLookupVisible(workptr,index,0))
		{
			if (ConfFileDeleteValueByIndex(workptr, 0, &line, lineindex, index))
			{
				return TRUE;
			}
			if (line > lineindex) break;
		}
		workptr = (CONFITEM*) workptr->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileDeleteArrayElement
 * Delete the array element specified by 'lineindex' if possible
 * ---------------------------------------------------------------------
 */
int
ConfFileDeleteArrayElement(CONFFILE* conf, int lineindex, int* newlineindex)
{
	if (!conf->DragItem)
	{
		CONFITEM* item = ConfFileGetItem(conf, lineindex);
		if (item && item->Parent)
		{
			CONFVALUE* value;
			short index[5];

			ConfFileGetIndex(conf, lineindex, index);
			value = ConfFileArrayLookupValue(item->Parent, index, item->Level - 1);
			if (value)
			{
				int   cursor = lineindex;
				int   tmpval;
				wchar_t buffer[48 + 1];

				if (ConfFileStartDrag(conf, lineindex))
				{
					/* move sel item down as long as possible */
					while (ConfFileDragValueDown(conf, &lineindex));

					/* decrement parent value */
					swscanf(value->Value, _T("%d"), &tmpval);
					if (tmpval > 0)
					{
					        tmpval--;
					}
					swprintf(buffer, 48, _T("%i"), tmpval);
					free(value->Value);
					value->Value = wcsdup(buffer);

					/* ok, that's it. Now we need to know where to place the cursor */
					if (newlineindex)
					{
						if (tmpval == 0)
						{
							/* select parent node */
							*newlineindex = ConfFileGetLineIndex(conf, item->Parent, index);
						}
						else if (index[item->Level - 1] > tmpval)
						{
							/* move selection up */
							index[item->Level - 1] = tmpval;
							*newlineindex = ConfFileGetLineIndex(conf, item, index);
						}
						else
						{
							/* keep selection */
							*newlineindex = cursor;
						}
					}

					/* clean up */
					ConfFileEndDrag(conf);
				}
				return TRUE;
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileSetModified
 * Set or clear modified flag
 * ---------------------------------------------------------------------
 */
void
ConfFileSetModified(CONFFILE* conf, int modified)
{
	conf->IsModified = modified;
}

/* ---------------------------------------------------------------------
 * ConfFileIsModified
 * return if configuration has been modified
 * ---------------------------------------------------------------------
 */
int
ConfFileIsModified(CONFFILE* conf)
{
	return conf->IsModified;
}

/* ---------------------------------------------------------------------
 * ConfFileAddBlockComment
 * Add a line of text to the current temporary block comment. The stored
 * data is transferred to an item in the tree by TransferBlockComment
 * ---------------------------------------------------------------------
 */
void
ConfFileAddBlockComment(CONFFILE* conf, const wchar_t* value)
{
	CONFCOMMENT* newcomment;

	if (!conf) return;

	newcomment = (CONFCOMMENT*) malloc(sizeof(CONFCOMMENT));
	newcomment->Name = NULL;
	newcomment->Text = wcsdup(value);
	newcomment->Next = NULL;

	if (!conf->FirstTmpComment)
	{
		conf->FirstTmpComment = newcomment;
	}
	else
	{
		conf->LastTmpComment->Next = newcomment;
	}
	conf->LastTmpComment = newcomment;
}

/* ---------------------------------------------------------------------
 * ConfFileUseBlockComment
 * Transfer the previously stored block comment to the specified item
 * using the value name 'name'
 * New: An item can only carry one block comment. No more indexing is
 * done!
 * ---------------------------------------------------------------------
 */
void
ConfFileUseBlockComment(CONFFILE* conf, CONFITEM* item, const wchar_t* name)
{
	if (!conf||!item||!name) return;

	if (conf->FirstTmpComment)
	{
		if (!item->FirstBlockComment)
		{
			CONFCOMMENT* cntptr = conf->FirstTmpComment;
			while (cntptr)
			{
				item->NumBlockComments++;
				cntptr = (CONFCOMMENT*) cntptr->Next;
			}
			item->FirstBlockComment = conf->FirstTmpComment;
			item->LastBlockComment = conf->LastTmpComment;
			conf->FirstTmpComment = NULL;
		}
		else
		{
			CONFCOMMENT* delptr = conf->FirstTmpComment;
			while (delptr)
			{
				conf->FirstTmpComment = delptr->Next;
				if (delptr->Name) free(delptr->Name);
				if (delptr->Text) free(delptr->Text);
				free(delptr);
				delptr = conf->FirstTmpComment;
			}
		}
	}
}


/* helper functions */

/* ---------------------------------------------------------------------
 * ConfFileIsNodeName
 * Compares an item's name (that may contain place holders) with a
 * name specified in 'name'. In this comparison the place holders may
 * stand for any integer constant.
 * If the names are equal, than TRUE is returned.
 * ---------------------------------------------------------------------
 */
static int
ConfFileIsNodeName(const wchar_t* nodename, const wchar_t* name)
{
	int pos1, pos2;

	if (!name) return FALSE;
	if (!nodename) return FALSE;

	pos1 = 0;
	pos2 = 0;
	while (nodename[pos1] != 0)
	{
		if (name[pos2] == 0) return FALSE;

		if (nodename[pos1] == _T('%'))   /* place holder for numeric constant */
		{
			if ((name[pos2] == _T('%'))||(name[pos2] == _T('#')))
			{
				pos1++; pos2++;
			}
			else {
				if (isdigit(name[pos2])) /* ignore the number - not relevant for comparison */
				{
					pos2++;
					while (isdigit(name[pos2])) { pos2++; }
				}
				else return FALSE; /* place holder has no corresponding value */

				pos1++;
			}
		}
		else
		{
			if (toupper(nodename[pos1++])!=toupper(name[pos2++]))
			{
				return FALSE;
			}
		}
	}
	if (name[pos2] != 0) return FALSE; /* name is longer than nodename */

	return TRUE;
}

/* ---------------------------------------------------------------------
 * ConfFileGetHash
 * Calculate the hash value of the given string in 'text'
 * ---------------------------------------------------------------------
 */
static unsigned char
ConfFileGetHash(short* index, int numindex)
{
	unsigned char result = 0;
	int i;

	for (i = 0; i < numindex; i++)
	{
		result += (unsigned char) index[i];
	}
	return result & HASH_MASK;
}

/* ---------------------------------------------------------------------
 * ConfFileDeleteItemNode
 * Delete an item and all associated values. Since an item can contain
 * subitems (tree structure) the subitems are deleted too.
 * ---------------------------------------------------------------------
 */
void
ConfFileDeleteItemNode(CONFITEM* item)
{
	int i;

	if (item)
	{
		CONFITEM* workptr = item->Child;
		while (workptr)
		{
			item->Child = (CONFITEM*) workptr->Next;
			ConfFileDeleteItemNode(workptr);
			workptr = item->Child;
		}

		for (i = 0; i < HASH_SIZE; i++)
		{
			CONFVALUE* valptr = item->Values[i];
			while (valptr)
			{
				item->Values[i] = (CONFVALUE*) valptr->Next;
				free(valptr->Name);
				free(valptr->Value);
				free(valptr);
				valptr = item->Values[i];
			}
		}

		for (i = 0; i < HASH_SIZE; i++)
		{
			CONFVALUE* valptr = item->Defaults[i];
			while (valptr)
			{
				item->Defaults[i] = (CONFVALUE*) valptr->Next;
				free(valptr->Name);
				free(valptr->Value);
				free(valptr);
				valptr = item->Defaults[i];
			}
		}

		if (item->FirstComment)
		{
			CONFCOMMENT* valptr = item->FirstComment;
			while (valptr)
			{
				item->FirstComment = (CONFCOMMENT*) valptr->Next;
				if (valptr->Name) free(valptr->Name);
				if (valptr->Text) free(valptr->Text);
				free(valptr);
				valptr = item->FirstComment;
			}
		}

		if (item->FirstBlockComment)
		{
			CONFCOMMENT* valptr = item->FirstBlockComment;
			while (valptr)
			{
				item->FirstBlockComment = (CONFCOMMENT*) valptr->Next;
				if (valptr->Name) free(valptr->Name);
				if (valptr->Text) free(valptr->Text);
				free(valptr);
				valptr = item->FirstBlockComment;
			}
		}

		if (item->FirstCheck)
		{
			CONFCHECK* chkptr = item->FirstCheck;
			while (chkptr)
			{
				item->FirstCheck = (CONFCHECK*) chkptr->Next;
				if (chkptr->Name) free(chkptr->Name);
				free(chkptr);
				chkptr = item->FirstCheck;
			}
		}

		if (item->DefaultValue)
		{
			free(item->DefaultValue);
		}

		free(item->Name);
		free(item->WriteMask);
		free(item->ReadMask);
		free(item);
	}
}

/* ---------------------------------------------------------------------
 * ConfFileAddItemCheck
 * Add an additional reference to a regular expression used to validate
 * values related to an item
 * ---------------------------------------------------------------------
 */
static void
ConfFileAddItemCheck(CONFITEM* item, const wchar_t* chkname)
{
	if (!item) return;
	item->LastCheck->Next = (CONFCHECK*) malloc(sizeof(CONFCHECK));
	item->LastCheck = (CONFCHECK*) item->LastCheck->Next;
	item->LastCheck->Next = NULL;
	item->LastCheck->Name = wcsdup(chkname);

	if (wcscasecmp(chkname, _T("PASSWD")) == 0)
	{
		item->IsMasked = TRUE;
	}
	else if (wcscasecmp(chkname, _T("HIDDEN")) == 0)
	{
		item->IsHidden = TRUE;
	}
	else if (wcscasecmp(chkname, _T("READONLY")) == 0)
	{
		item->IsReadOnly = TRUE;
	}
}


/* ---------------------------------------------------------------------
 * ConfFileAddItemValue
 * Like leaves on a tree the item tree is populated with values that
 * are are read from 'config.d'. With this function a value is added to
 * the item specified by 'item'.
 * Note that an item can be filled with many values forming a multi-
 * dimensional array. The array coordinates are placed within the value's
 * name (i.e. OPTION_2_SUBOPTION_3) (look at item->Mask)
 * The function returns FALSE, if the value contains not enought
 * values according to the item hierarical level.
 * ---------------------------------------------------------------------
 */
static int
ConfFileAddItemValue(CONFITEM* item, const wchar_t* name, const wchar_t* value)
{
	if (item)
	{
		unsigned char hash;
		int num;

		CONFVALUE* newvalue = (CONFVALUE*) malloc(sizeof(CONFVALUE));
		newvalue->Value = wcsdup(value);
		newvalue->Name = wcsdup(name);

		num = swscanf(name,item->ReadMask,&newvalue->Index[0],
			&newvalue->Index[1],&newvalue->Index[2],
			&newvalue->Index[3],&newvalue->Index[4]);

		if (num == item->Level)
		{
			hash = ConfFileGetHash(newvalue->Index,num);
				newvalue->Next = item->Values[hash];
				item->Values[hash] = newvalue;

			return TRUE;
		}
		else
		{
			free (newvalue);
			return FALSE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileAddItemDefault
 * Workes like 'AddItemValue' except that the value is added to the
 * item's default list instead of the value list.
 * These values are normally read from 'default.d'
 * ---------------------------------------------------------------------
 */
static int
ConfFileAddItemDefault (CONFITEM* item, const wchar_t* name, const wchar_t* value)
{
	if (item)
	{
		unsigned char hash;
		int num;

		CONFVALUE* newvalue = (CONFVALUE*) malloc(sizeof(CONFVALUE));
		newvalue->Value = wcsdup(value);
		newvalue->Name = wcsdup(name);

		num = swscanf(name,item->ReadMask,&newvalue->Index[0],
			&newvalue->Index[1],&newvalue->Index[2],
			&newvalue->Index[3],&newvalue->Index[4]);

		if (num == item->Level)
		{
			hash = ConfFileGetHash(newvalue->Index,num);
			newvalue->Next = item->Defaults[hash];
			item->Defaults[hash] = newvalue;

			if (!item->SequenceNr)
			{
				int maxval = 0;
				CONFITEM* workptr;
				if (item->Parent)
				{
					workptr = ((CONFITEM*)item->Parent)->Child;
				}
				else
				{
					workptr = ((CONFFILE*)item->Config)->FirstItem;
				}

				while (workptr)
				{
					if (workptr->SequenceNr > maxval)
					{
						maxval = workptr->SequenceNr;
					}
					workptr = (CONFITEM*) workptr->Next;
				}
				item->SequenceNr = maxval + 1;
			}

			return TRUE;
		}
		else
		{
			free (newvalue);

			return FALSE;
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileAddItemComment
 * Workes like 'AddItemValue' except that the value is added as a comment
 * text related to a given config value, instead of a value itself.
 * Notice that there can be multiple comment lines per value
 * ---------------------------------------------------------------------
 */
static void
ConfFileAddItemComment (CONFITEM* item, const wchar_t* name, const wchar_t* value)
{
	if (item)
	{

		CONFCOMMENT* newcomment = (CONFCOMMENT*) malloc(sizeof(CONFCOMMENT));
		newcomment->Name = wcsdup(name);
		newcomment->Text = wcsdup(value);
		newcomment->Next = NULL;

		swscanf(name,item->ReadMask,&newcomment->Index[0],
			&newcomment->Index[1],&newcomment->Index[2],
			&newcomment->Index[3],&newcomment->Index[4]);

		if (!item->FirstComment) item->FirstComment = newcomment;
		else item->LastComment->Next = newcomment;
		item->LastComment = newcomment;
	}
}

/* ---------------------------------------------------------------------
 * ConfFileUseFooterComment
 * Transfer the previously stored block comment to the footer comment
 * of this config file
 * ---------------------------------------------------------------------
 */
static void
ConfFileUseFooterComment(CONFFILE* conf)
{
	if (!conf) return;

	if (conf->FirstTmpComment)
	{
		conf->FirstFooterComment = conf->FirstTmpComment;
		conf->FirstTmpComment = NULL;
		conf->LastTmpComment = NULL;
	}
}

/* ---------------------------------------------------------------------
 * ConfFileAddHeaderComment
 * Add a comment to the file header. This is necessary because the
 * header has to be restored when the file is saved
 * ---------------------------------------------------------------------
 */
static void
ConfFileAddHeaderComment(CONFFILE* conf, const wchar_t* value)
{
	CONFCOMMENT* newcomment;

	if (!conf) return;

	newcomment = (CONFCOMMENT*) malloc(sizeof(CONFCOMMENT));
	newcomment->Name = NULL;
	newcomment->Text = wcsdup(value);
	newcomment->Next = NULL;

	if (!conf->FirstHeaderComment)
	{
		conf->FirstHeaderComment = newcomment;
	}
	else
	{
		conf->LastHeaderComment->Next = newcomment;
	}
	conf->LastHeaderComment = newcomment;
}

/* ---------------------------------------------------------------------
 * ConfFileReorderTree
 * Perform a sequence check and reorder the item tree if values
 * have been assigned in a different order then the order in check.d
 * ---------------------------------------------------------------------
 */
static void
ConfFileReorderTree(CONFFILE* conf)
{
	if (conf)
	{
		CONFITEM* baseptr;
		CONFITEM* workptr;
		CONFITEM* lastptr;
		int numitems = 0;
		int lastvalue = 0;
		int n;

		/* First fix optional values */
		workptr = conf->FirstItem;
		while (workptr)
		{
			if (workptr->SequenceNr == 0)
			{
				workptr->SequenceNr = lastvalue;
			}
			lastvalue = workptr->SequenceNr;
			numitems++;

			/* Decent through the tree recursively */
			ConfFileReorderChildren(workptr);

			workptr = (CONFITEM*) workptr->Next;
		}

		/* Now reorganizing begins - bubble sort*/
		if (numitems > 1)
		{
			for (n = 0; n < (numitems-1); n++)
			{
				int index = numitems - n - 1;

				baseptr = conf->FirstItem;
				workptr = baseptr->Next;
				lastptr = NULL;

				while(workptr && (index >= 0))
				{
					if (baseptr->SequenceNr > workptr->SequenceNr)
					{
						if (lastptr)
						{
							lastptr->Next = workptr;
						}
						else
						{
							conf->FirstItem = workptr;
						}

						if (workptr->Next)
						{
							((CONFITEM*) workptr->Next)->Previous = baseptr;
						}
						workptr->Previous = lastptr;
						baseptr->Previous = workptr;

						baseptr->Next = workptr->Next;
						workptr->Next = baseptr;

						if (workptr == conf->LastItem)
						{
							conf->LastItem = baseptr;
						}

						lastptr = baseptr;
						baseptr = workptr;
						workptr = lastptr;
					}

					index--;
					lastptr = baseptr;
					baseptr = workptr;
					workptr = (CONFITEM*) workptr->Next;
				}
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileReorderChildren
 * Recursively walk through the tree and reorganize items using bubble
 * sort
 * ---------------------------------------------------------------------
 */
static void
ConfFileReorderChildren(CONFITEM* item)
{
	if (item)
	{
		CONFITEM* baseptr;
		CONFITEM* workptr;
		CONFITEM* lastptr;
		int numitems = 0;
		int lastvalue = 0;
		int n;

		/* First fix optional values */
		workptr = item->Child;
		while (workptr)
		{
			if (workptr->SequenceNr == 0)
			{
				workptr->SequenceNr = lastvalue;
			}
			lastvalue = workptr->SequenceNr;
			numitems++;

			/* Decent through the tree recursively */
			ConfFileReorderChildren(workptr);

			workptr = (CONFITEM*) workptr->Next;
		}

		/* Now reorganizing begins - bubble sort*/
		if (numitems > 1)
		{
			for (n = 0; n < (numitems-1); n++)
			{
				baseptr = item->Child;
				workptr = baseptr->Next;
				lastptr = NULL;

				while(workptr)
				{
					if (baseptr->SequenceNr > workptr->SequenceNr)
					{
						if (lastptr)
						{
							lastptr->Next = workptr;
						}
						else
						{
							item->Child = workptr;
						}

						if (workptr->Next)
						{
							((CONFITEM*) workptr->Next)->Previous = baseptr;
						}
						workptr->Previous = lastptr;
						baseptr->Previous = workptr;

						baseptr->Next = workptr->Next;
						workptr->Next = baseptr;

						if (workptr == item->Last)
						{
							item->Last = baseptr;
						}

						lastptr = baseptr;
						baseptr = workptr;
						workptr = lastptr;
					}

					lastptr = baseptr;
					baseptr = workptr;
					workptr = (CONFITEM*) workptr->Next;
				}
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileWriteToFile
 * Write string to file
 * ---------------------------------------------------------------------
 */
static void
ConfFileWriteToFile(const wchar_t* text, FILE* out)
{
	mbstate_t state;
	char      buffer[128 + 1];
	int       size = 0;
	
	memset(&state, 0, sizeof(state));

	do
	{
		size = wcsrtombs(buffer, &text, 128, &state);
		if (size > 0)
		{
			fwrite(buffer, 1, size, out);
		}
	}
	while ((size > 0) && (text != NULL));
}

/* ---------------------------------------------------------------------
 * ConfFileWrite
 * Write the entire data into the file stream 'out'
 * ---------------------------------------------------------------------
 */
static void
ConfFileWrite(CONFFILE* conf, FILE* out)
{
	CONFITEM* workptr;
	CONFCOMMENT* workcmmt;
	short index[NUM_DIM];       /* only five hierarchy levels */

	/* file comment header */
	workcmmt = conf->FirstHeaderComment;
	while (workcmmt)
	{
		ConfFileWriteToFile(workcmmt->Text,out);
		fputs("\n",out);
		workcmmt = (CONFCOMMENT*) workcmmt->Next;
	}
	fputs("\n",out);

	/* file data */
	workptr = conf->FirstItem;
	while (workptr)
	{
		ConfFileWriteValueByIndex(workptr,0,index,out);

		workptr = (CONFITEM*) workptr->Next;
	}

	/* footer comment */
	if (conf->FirstFooterComment) fputs("\n",out);

	workcmmt = conf->FirstFooterComment;
	while (workcmmt)
	{
		ConfFileWriteToFile(workcmmt->Text,out);
		fputs("\n",out);
		workcmmt = (CONFCOMMENT*) workcmmt->Next;
	}
}

/* ---------------------------------------------------------------------
 * ConfFileWriteValueByIndex
 * Write current value and all child values into file 'out'
 * ---------------------------------------------------------------------
 */
static int
ConfFileWriteValueByIndex(CONFITEM* item, int level, short* index, FILE* out)
{
	CONFVALUE*   valptr;
	CONFCOMMENT* valcomment;
	CONFITEM*    workptr;

	if (level > 4) return FALSE;              /* limit iteration depth */

	valptr = ConfFileArrayLookupValue(item,index,level);
	if (!valptr && (item->Type == TYPE_REQUIRED))
	{
		/* if there is no value available, use default instead */
		valptr = ConfFileArrayLookupDefault(item,index,level);
	}
	if (valptr)
	{
		int writepos = 0;

		/* block comment (trailing value)*/
		valcomment = item->FirstBlockComment;
		if (valcomment)
		{
			fputs("\n",out);

			while (valcomment)
			{
				wchar_t  buffer[128 + 1];

				swprintf(buffer, 128, valcomment->Text,
				         index[0],index[1],index[2],index[3],index[4]);
				buffer[128] = 0;

				ConfFileWriteToFile(buffer,out);
				fputs("\n",out);
				valcomment = (CONFCOMMENT*) valcomment->Next;
			}

			fputs("\n",out);
		}

		if (valptr->Name && valptr->Value)
		{
			writepos += wcslen(valptr->Name);
			writepos += wcslen(valptr->Value);
			writepos += 3;

			if (wcschr(valptr->Value,_T('\'')) != NULL)
			{
				ConfFileWriteToFile(valptr->Name, out);
				fputs("=\"",out);
				ConfFileWriteToFile(valptr->Value, out);
				fputs("\"",out);
			}
			else
			{
				ConfFileWriteToFile(valptr->Name, out);
				fputs("=\'",out);
				ConfFileWriteToFile(valptr->Value, out);
				fputs("\'",out);
			}

			if (writepos >= (COMMENT_COL - 1))
			{
				fputs("\n",out);
				writepos = 0;
			}
		}

		/* comment */
		valcomment = ConfFileArrayLookupComment(item,index,level,NULL);
		if (valcomment)
		{
			while (valcomment)
			{
				while (writepos < (COMMENT_COL - 1))
				{
					fputc(' ',out);
					writepos++;
				}

				ConfFileWriteToFile(valcomment->Text,out);
				fputs("\n",out);

				writepos = 0;
				valcomment = ConfFileArrayLookupComment(item,index,level,valcomment);
			}
		}
		else fputs("\n",out);
	}

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		/* we use count + 10 to preserve 10 additional values */
		/* that are possible used as sample entries without */
		/* beeing used */
		for (i = 1; i <= (count + 10); i++)
		{
			int hasvalues = FALSE;

			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileWriteValueByIndex(workptr,level+1,index,out))
				{
					hasvalues = TRUE;
				}
				workptr = (CONFITEM*) workptr->Next;
			}


			if ((((CONFITEM*)item->Child)->Next) && hasvalues)
			{
				fputs("\n",out);
			}
		}
	}
	if (valptr) return TRUE;

	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileFindItemByName
 * Searches the tree to find the items specified by the name 'name'
 * ---------------------------------------------------------------------
 */
static CONFITEM*
ConfFileFindItemByName(CONFITEM* item, const wchar_t* name)
{
	if (item)
	{
		if (ConfFileIsNodeName(item->Name, name))
		{
			return item;
		}
		else
		{
			CONFITEM* workptr = item->Child;
			while (workptr)
			{
				CONFITEM* ptr = ConfFileFindItemByName(workptr, name);
				if (ptr)
				{
					return ptr;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileFindItemByIndex
 * Searches the tree to find the item specified by line 'lineindex'
 * ---------------------------------------------------------------------
 */
static CONFITEM*
ConfFileFindItemByIndex(CONFITEM* item, int level, int* line, int lineindex, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return NULL;  /* limit iteration depth */

	if (*line == lineindex) return item;
	(*line)++;

	valptr = ConfFileArrayLookupValue(item,index,level);

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					CONFITEM* ptr = ConfFileFindItemByIndex(
						workptr, level+1, line, lineindex, index);
					if (ptr) return ptr;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileFindValueByIndex
 * Searches the tree to find the value specified by line 'lineindex'
 * ---------------------------------------------------------------------
 */
static CONFVALUE*
ConfFileFindValueByIndex(CONFITEM* item, int level, int* line, int lineindex, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return NULL;         /* limit iteration depth */
	if (*line > lineindex) return NULL;

	valptr = ConfFileArrayLookupValue(item, index, level);

	if (*line == lineindex)
	{
		(*line)++;
		return valptr;
	}
	(*line)++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					CONFVALUE* ptr = ConfFileFindValueByIndex(workptr, level+1, line, lineindex, index);
					if (ptr) return ptr;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileFindValueByName
 * Searches the tree to find a given value
 * ---------------------------------------------------------------------
 */
static CONFVALUE*
ConfFileFindValueByName(CONFITEM* item, int level, const wchar_t* name, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return NULL;         /* limit iteration depth */

	valptr = ConfFileArrayLookupValue(item, index, level);
	if (valptr && (wcscmp(valptr->Name, name) == 0))
	{
		return valptr;
	}

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				CONFVALUE* ptr = ConfFileFindValueByName(workptr, level+1, name, index);
				if (ptr) return ptr;

				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * ConfFileFindItemByOptNode
 * Searches the tree to find the first item using 'optnode' as OptNode
 * ---------------------------------------------------------------------
 
static CONFITEM*
ConfFileFindItemByOptNode(CONFITEM* item, CONFITEM* optnode)
{
	if (item)
	{
		if ((CONFITEM*)item->OptNode == optnode)
		{
			return item;
		}
		else
		{
			CONFITEM* workptr = item->Child;
			while (workptr)
			{
				CONFITEM* ptr = ConfFileFindItemByOptNode(workptr, optnode);
				if (ptr)
				{
					return ptr;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return NULL;
}
*/
/* ---------------------------------------------------------------------
 * ConfFileFindIndexByIndex
 * Searches the tree to fill the index array specified by line 'lineindex'
 * ---------------------------------------------------------------------
 */
static int
ConfFileFindIndexByIndex(CONFITEM* item, int level, int* line, int lineindex, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return FALSE;         /* limit iteration depth */
	if (*line > lineindex) return FALSE;

	valptr = ConfFileArrayLookupValue(item,index,level);

	if (*line == lineindex)
	{
		(*line)++;
		return TRUE;
	}
	(*line)++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"),&count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					int result = ConfFileFindIndexByIndex(workptr,level+1,line,lineindex,index);
					if (result) return TRUE;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * ConfFileFindLineIndex
 * Searches the tree to find the first position matchint the index
 * ---------------------------------------------------------------------
 */
static int
ConfFileFindLineIndex(CONFITEM* item, CONFITEM* cmpitem, int level,
                    int* line, short* cmpindex, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return FALSE;         /* limit iteration depth */

	valptr = ConfFileArrayLookupValue(item,index,level);
	if ((item == cmpitem) && (memcmp(index, cmpindex, level * sizeof(short)) == 0))
	{
		return *line;
	}
	(*line)++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1))
				{
					int result = ConfFileFindLineIndex(workptr,cmpitem,level+1,line,cmpindex,index);
					if (result >= 0) return result;
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
	return -1;
}

/* ---------------------------------------------------------------------
 * CreateValueByIndex
 * Searches the tree. A value that corresponds to a given lineindex and
 * does not exist in the tree is created (if not optional)
 * ---------------------------------------------------------------------
 */
static void
ConfFileCreateValueByIndex(CONFITEM* item, int level, int* line,
                   int lineindex, short* index, int expand)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return;                /* limit iteration depth */
	if (*line == lineindex) expand = TRUE;  /* turn on expand mode when line has been reached */

	valptr = ConfFileArrayLookupValue(item, index, level);
	if (expand && !valptr &&
		(((item->Type != TYPE_OPTIONAL) && (item->Type != TYPE_OPTARRAY)) ||
		(*line == lineindex)))
	{
		/* create and initialize */
		wchar_t        buffer[128 + 1];
		const wchar_t* value   = _T("");

		if (item->DefaultValue)
		{
			value = item->DefaultValue;
		}
		else if (item->Child)
		{
			value = _T("0");
		}
		else
		{
			CONFVALUE*  defptr  = ConfFileArrayLookupDefault(item, index, level);
			if (!defptr)
			{
				/* we haven't got a default value yet. Go back to find an other one */
				short tmpindex[NUM_DIM];
				int i;

				for (i = 0; i < NUM_DIM; i++) tmpindex[i] = index[i];

				i = level;
				while ((i > 0) && (!defptr))
				{
					tmpindex[--i] = 1;

					defptr  = ConfFileArrayLookupDefault(item, tmpindex, level);
				}
			}
			if (defptr)
			{
				value = defptr->Value;
			}
			else
			{
				value = ConfFileGetItemDefaultValue(item);
			}
		}

		ConfFileArrayLookupName(item, index, level, buffer, 128);
		ConfFileAddItemValue(item, buffer, value);

		valptr = ConfFileArrayLookupValue(item,index,level);
	}
	(*line)++;

	if (item->Child && valptr)   /* N-node */
	{
		int count;
		int i;
		swscanf(valptr->Value, _T("%d"), &count);

		for (i = 1; i <= count; i++)
		{
			index[level] = i;

			workptr = item->Child;
			while (workptr)
			{
				if (ConfFileArrayLookupVisible(workptr,index,level+1) || expand)
				{
					ConfFileCreateValueByIndex(workptr,
						level + 1,
						line,
						lineindex,
						index,
						expand && item->Type != TYPE_OPTARRAY);
				}
				workptr = (CONFITEM*) workptr->Next;
			}
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileDeleteValueByIndex
 * Searches the tree. A value that corresponds to a given lineindex and
 * has the type TYPE_OPTIONAL, is deleted.
 * ---------------------------------------------------------------------
 */
static int
ConfFileDeleteValueByIndex(CONFITEM* item, int level, int* line, int lineindex, short* index)
{
	CONFVALUE* valptr;
	CONFITEM*  workptr;

	if (level > 4) return FALSE;                /* limit iteration depth */
	if (!item) return FALSE;

	if (*line == lineindex)
	{
		(*line)++;

		if (level == 0)
		{
			if (item->Type == TYPE_OPTIONAL)
			{
				ConfFileArrayDeleteValue(item,index,level);
				return TRUE;
			}
			else
			{
				return FALSE;
			}
		}
		else
		{
			if (item->Type == TYPE_OPTARRAY)
			{
				ConfFileArrayDeleteValue(item,index,level);
				return TRUE;
			}
			else
			{
				return FALSE;
			}
		}
	}
	else
	{
		int result = FALSE;
		valptr = ConfFileArrayLookupValue(item,index,level);
		(*line)++;

		if (item->Child && valptr)   /* N-node */
		{
			int count;
			int i;
			swscanf(valptr->Value, _T("%d"), &count);

			for (i = 1; i <= count; i++)
			{
				index[level] = i;

				workptr = item->Child;
				while (workptr)
				{
					if (ConfFileArrayLookupVisible(workptr,index,level+1))
					{
						if (ConfFileDeleteValueByIndex(workptr,level+1,line,lineindex,index))
						{
							result = TRUE;
						}
						if (*line > lineindex) break;
					}
					workptr = (CONFITEM*) workptr->Next;
				}
			}
		}
		return result;
	}
}


/* ---------------------------------------------------------------------
 * ConfFileRemoveValueFromTable
 * Remove a value entry from an item's hash table
 * ---------------------------------------------------------------------
 */
static void
ConfFileRemoveValueFromTable(CONFITEM* item, short* index, int numindex)
{
	CONFVALUE* workptr;
	CONFVALUE* oldptr;

	unsigned char hash;
	int factor = (item->Level < numindex) ? item->Level : numindex;
	int size = factor*sizeof(short);

	hash = ConfFileGetHash(index,factor);
	workptr = item->Values[hash];
	while (workptr)
	{
		if (memcmp(index,workptr->Index,size) == 0)
		{
			if (workptr == item->Values[hash])
			{
				item->Values[hash] = (CONFVALUE*) workptr->Next;
				return;
			}
			else
			{
				oldptr->Next = workptr->Next;
				return;
			}
		}
		else
		{
			oldptr = workptr;
			workptr = (CONFVALUE*) workptr->Next;
		}
	}
}

/* ---------------------------------------------------------------------
 * ConfFileInsertValueIntoTable
 * Insert a value into an item's hash table
 * ---------------------------------------------------------------------
 */
static void
ConfFileInsertValueIntoTable(CONFITEM* item, int numindex, CONFVALUE* valptr)
{
	unsigned char hash;
	int factor = (item->Level < numindex) ? item->Level : numindex;

	hash = ConfFileGetHash(valptr->Index, factor);

	valptr->Next = item->Values[hash];
	item->Values[hash] = valptr;
}

/* ---------------------------------------------------------------------
 * ConfFileSwapValueIndex
 * Exchange array positions of the values at index positions index1 and
 * index2
 * ---------------------------------------------------------------------
 */
static void
ConfFileSwapValueIndex(CONFITEM* item, short* index1, short* index2)
{
	CONFITEM* childitem = item->Child;
	while (childitem)
	{
		CONFVALUE* valptr1 = ConfFileArrayLookupValue(childitem, index1, item->Level + 1);
		CONFVALUE* valptr2 = ConfFileArrayLookupValue(childitem, index2, item->Level + 1);

		ConfFileRemoveValueFromTable(childitem, index1, item->Level + 1);
		ConfFileRemoveValueFromTable(childitem, index2, item->Level + 1);

		if (valptr1)
		{
			int    len  = wcslen(valptr1->Name) + 1 + 5;
			wchar_t* name = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

			swprintf(name, len, childitem->WriteMask, index2[0], index2[1],
				index2[2], index2[3], index2[4]);

			free(valptr1->Name);
			valptr1->Name = name;

			memcpy(valptr1->Index, index2, NUM_DIM * sizeof(short));
			ConfFileInsertValueIntoTable(childitem, item->Level + 1, valptr1);
		}

		if (valptr2)
		{
			int    len  = wcslen(valptr2->Name) + 1 + 5;
			wchar_t* name = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));

			swprintf(name, len, childitem->WriteMask, index1[0], index1[1],
				index1[2], index1[3], index1[4]);

			free(valptr2->Name);
			valptr2->Name = name;

			memcpy(valptr2->Index, index1, NUM_DIM * sizeof(short));
			ConfFileInsertValueIntoTable(childitem, item->Level + 1, valptr2);
		}

		if ((childitem->Child) && (valptr1 || valptr2))
		{
			short tmpindex1[NUM_DIM];
			short tmpindex2[NUM_DIM];
			int count1 = 0;
			int count2 = 0;
			int i;
			int level = childitem->Level;

			memcpy(tmpindex1, index1, NUM_DIM * sizeof(short));
			memcpy(tmpindex2, index2, NUM_DIM * sizeof(short));

			if (valptr1)
			{
				swscanf(valptr1->Value, _T("%d"), &count1);
			}
			if (valptr2)
			{
				swscanf(valptr2->Value, _T("%d"), &count2);
			}
			if (count2 > count1)
			{
				count1 = count2;
			}

			for (i = 1; i <= count1; i++)
			{
				tmpindex1[level] = i;
				tmpindex2[level] = i;

				ConfFileSwapValueIndex(childitem, tmpindex1, tmpindex2);
			}
		}

		childitem = (CONFITEM*) childitem->Next;
	}
}

/* ---------------------------------------------------------------------
 * ConfFileGetItemDefaultValue
 * If there is no default-value available, we return a value
 * suitable for the related regular expression. Since there can be
 * more regular expresseions, it is still possible that the value
 * returned is invalid
 * ---------------------------------------------------------------------
 */
static const wchar_t*
ConfFileGetItemDefaultValue(CONFITEM* item)
{
	CONFCHECK* check = item->FirstCheck;
	if (check)
	{
		if (wcscasecmp(check->Name, _T("NONE"))==0)         return _T("");
		if (wcscasecmp(check->Name, _T("NOTEMPTY"))==0)     return _T("value");
		if (wcscasecmp(check->Name, _T("NOBLANK"))==0)      return _T("value");
		if (wcscasecmp(check->Name, _T("ENOBLANK"))==0)     return _T("");
		if (wcscasecmp(check->Name, _T("NUMERIC"))==0)      return _T("0");
		if (wcscasecmp(check->Name, _T("ENUMERIC"))==0)     return _T("");
		if (wcscasecmp(check->Name, _T("DOT_NUMERIC"))==0)  return _T("0.0");
		if (wcscasecmp(check->Name, _T("EDOT_NUMERIC"))==0) return _T("");
		if (wcscasecmp(check->Name, _T("NUM_HEX"))==0)      return _T("0x00");
		if (wcscasecmp(check->Name, _T("NUM_ANY"))==0)      return _T("0");
		if (wcscasecmp(check->Name, _T("YESNO"))==0)        return _T("no");
		if (wcscasecmp(check->Name, _T("MACADDR"))==0)      return _T("00:00:00:00:00:00");
		if (wcscasecmp(check->Name, _T("HOSTNAME"))==0)     return _T("host");
		if (wcscasecmp(check->Name, _T("DOMAIN"))==0)       return _T("domain.lan");
		if (wcscasecmp(check->Name, _T("EDOMAIN"))==0)      return _T("");
		if (wcscasecmp(check->Name, _T("FQDN"))==0)         return _T("host.domain.lan");
		if (wcscasecmp(check->Name, _T("EFQDN"))==0)        return _T("");
		if (wcscasecmp(check->Name, _T("OCTET"))==0)        return _T("000");
		if (wcscasecmp(check->Name, _T("IPADDR"))==0)       return _T("192.168.0.1");
		if (wcscasecmp(check->Name, _T("IPADDRESSES"))==0)  return _T("192.168.0.1 192.168.0.2");
		if (wcscasecmp(check->Name, _T("EIPADDR"))==0)      return _T("");
		if (wcscasecmp(check->Name, _T("EIPADDRESSES"))==0) return _T("");
		if (wcscasecmp(check->Name, _T("IP_ROUTE"))==0)     return _T("192.168.0.0 255.255.255.0 192.168.1.0");
		if (wcscasecmp(check->Name, _T("DNS_SPEC"))==0)     return _T("domain 192.168.0.1");
		if (wcscasecmp(check->Name, _T("MASK"))==0)         return _T("255.255.255.0");
		if (wcscasecmp(check->Name, _T("NETWORK"))==0)      return _T("192.168.0.0/24");
		if (wcscasecmp(check->Name, _T("NETWORKS"))==0)     return _T("192.168.0.0/24");
		if (wcscasecmp(check->Name, _T("ENETWORKS"))==0)    return _T("");
		if (wcscasecmp(check->Name, _T("MULTIPLE_NETWORKS"))==0)  return _T("192.168.0.0/24 192.168.1.0/24");
		if (wcscasecmp(check->Name, _T("EMULTIPLE_NETWORKS"))==0) return _T("");
		if (wcscasecmp(check->Name, _T("IPADDR_NETWORK"))==0)     return _T("192.168.0.1");
		if (wcscasecmp(check->Name, _T("EIPADDR_NETWORK"))==0)    return _T("");
		if (wcscasecmp(check->Name, _T("MAILADDR"))==0)     return _T("name@domain");
		if (wcscasecmp(check->Name, _T("EMAILADDR"))==0)    return _T("");
		if (wcscasecmp(check->Name, _T("CRONTAB"))==0)      return _T("3 5 * * *");
		if (wcscasecmp(check->Name, _T("REL_PATH"))==0)     return _T("../path");
		if (wcscasecmp(check->Name, _T("E_REL_PATH"))==0)   return _T("");
		if (wcscasecmp(check->Name, _T("ABS_PATH"))==0)     return _T("/path");
		if (wcscasecmp(check->Name, _T("E_ABS_PATH"))==0)   return _T("");
		if (wcscasecmp(check->Name, _T("LOG_INTERVAL"))==0) return _T("daily");
		if (wcscasecmp(check->Name, _T("PORT"))==0)         return _T("1024");
	}
	return _T("");
}

