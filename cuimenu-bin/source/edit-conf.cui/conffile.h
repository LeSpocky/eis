/* ---------------------------------------------------------------------
 * File: conffile.h
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
 * ---------------------------------------------------------------------
 */

#ifndef CONFFILE_H
#define CONFFILE_H

#include "global.h"
#include "expfile.h"

#define HASH_SIZE 32
#define HASH_MASK 0x1F
#define NUM_DIM   5

#define TYPE_REQUIRED 0
#define TYPE_OPTIONAL 1
#define TYPE_OPTARRAY 2

typedef struct
{
	short         Index[NUM_DIM];    /* Multidimensional index */
	wchar_t*      Name;              /* Name of config variable this comment is related to */
	wchar_t*      Text;              /* Textline */

	void*         Next;
} CONFCOMMENT;


typedef struct
{
	short         Index[NUM_DIM];    /* Multidimensional index */
	wchar_t*      Name;              /* associated name */
	wchar_t*      Value;             /* associated value */

	void*         Next;              /* next array value */
} CONFVALUE;


typedef struct
{
	wchar_t*      Name;              /* Name of regular expression used for data validation */

	void*         Next;              /* next entry for data validation */
} CONFCHECK;


typedef struct
{
	wchar_t*      Name;              /* Name of config variable i.e. START_XYZ (from check.d) */
	wchar_t*      WriteMask;         /* printf format string: i.e. OPTION_% -> OPTION_%i */
	wchar_t*      ReadMask;          /* sscanf format string */
	wchar_t*      DefaultValue;      /* default value read from check file (fli4l) */
	int           Type;              /* TYPE_REQUIRED / TYPE_OPTIONAL / TYPE_OPTARRAY */
	int           SequenceNr;        /* sequence number for item order correction */
	int           Level;             /* Hierarchical level the item is placed on */
	int           IsVirtual;         /* Virtual item for user defined variable? */
	int           IsMasked;          /* Visible or hidden by '*' characters */
	int           IsHidden;          /* Entirely hidden or visible? */
	int           IsReadOnly;        /* Can be modified or is protected? */
	int           IsInvertOpt;       /* invert opt criteria (visible if opt == "no") */

	CONFVALUE*    Values[HASH_SIZE];   /* hash table of associated values */
	CONFVALUE*    Defaults[HASH_SIZE]; /* hash table of associated def. values */

	CONFCOMMENT*  FirstComment;      /* first associated comment */
	CONFCOMMENT*  LastComment;       /* last associated comment */

	CONFCHECK*    FirstCheck;        /* first entry for data validation */
	CONFCHECK*    LastCheck;         /* last entry for data validation */

	CONFCOMMENT*  FirstBlockComment; /* trailing block comment */
	CONFCOMMENT*  LastBlockComment;  /* end of trailing block comment */
	int           NumBlockComments;  /* number of comment lines */

	void*         Config;            /* The config context we belong to */
	void*         OptNode;           /* Node to decide if this one is visible or not */
	void*         Parent;            /* Pointer to parent node, if available */
	void*         Next;              /* Next tree item */
	void*         Previous;          /* Previous tree item */
	void*         Last;              /* Last tree item */
	void*         Child;             /* Child tree item */
} CONFITEM;

typedef struct
{
	int            IsModified;         /* Signals the modified state of the current config */
	int            IsSchemeModified;   /* Signals the modified state of the current config file scheme */
	int            NumOptional;        /* Number of optional options */

	CONFITEM*      FirstItem;          /* First item in item tree */
	CONFITEM*      LastItem;           /* Last root item */

	CONFITEM*      DragItem;
	short          DragIndex[NUM_DIM];

	CONFCOMMENT*   FirstHeaderComment; /* First file header comment */
	CONFCOMMENT*   LastHeaderComment;  /* Last file header comment */

	CONFCOMMENT*   FirstFooterComment; /* First file footer comment */

	CONFCOMMENT*   FirstTreeComment;   /* First tree file header comment (check.d)*/
	CONFCOMMENT*   LastTreeComment;    /* Last tree file header comment (check.d)*/

	CONFCOMMENT*   FirstTmpComment;    /* Pointer to first temporary stored block comment... */
	CONFCOMMENT*   LastTmpComment;     /* ...will by assigned to an item when the  next value is added */

	ErrorCallback  ErrorOut;           /* For error reporting */
	void*          Instance;           /* instance handle for error reporting */
} CONFFILE;


void ConfFileSetOptionalOn(int on);   
int  ConfFileGetOptionalOn(void);


CONFFILE* ConfFileCreate (ErrorCallback errout, void* instance);
void  ConfFileDelete     (CONFFILE* conf);

void  ConfFileReadCheck  (CONFFILE* conf,
                          const wchar_t* filename,
                          EXPFILE* expfile);
void  ConfFileReadConfig (CONFFILE* conf,
                          const wchar_t* filename,
                          const wchar_t* chkbase,
                          int tolerant);
void  ConfFileReadDefault(CONFFILE* conf,
                          const wchar_t* filename,
                          const wchar_t* chkbase,
                          int tolerant);
void  ConfFileWriteConfig(CONFFILE* conf,
                          const wchar_t* filename);




void         ConfFileAddItem(CONFFILE* conf,
                          const wchar_t* name,
                          const wchar_t* check,
                          CONFITEM* nnode,
                          CONFITEM* optnode,
                          int invert,
                          CONFITEM* appnode,
                          int type,
                          int isvirtual);
void         ConfFileDeleteItem        (CONFFILE* conf, CONFITEM* item);
CONFITEM*    ConfFileFindItem          (CONFFILE* conf, const wchar_t* name);
CONFVALUE*   ConfFileFindValue         (CONFFILE* conf, const wchar_t* name);
CONFITEM*    ConfFileGetItem           (CONFFILE* conf, int lineindex);
CONFVALUE*   ConfFileGetValue          (CONFFILE* conf, int lineindex);
int          ConfFileGetIndex          (CONFFILE* conf, int lineindex, short* index);
int          ConfFileGetLineIndex      (CONFFILE* conf, CONFITEM* item, short* cmpindex);
void         ConfFileCreateValue       (CONFFILE* conf, int lineindex);
int          ConfFileDeleteValue       (CONFFILE* conf, int lineindex);
int          ConfFileDeleteArrayElement(CONFFILE* conf, int lineindex, int* newlineindex);
void         ConfFileSetModified       (CONFFILE* conf, int modified);
int          ConfFileIsModified        (CONFFILE* conf);

CONFVALUE*   ConfFileArrayLookupValue  (CONFITEM* item, short* index, int numindex);
CONFVALUE*   ConfFileArrayLookupDefault(CONFITEM* item, short* index, int numindex);
CONFCOMMENT* ConfFileArrayLookupComment(CONFITEM* item, short* index, int numindex, CONFCOMMENT* last);
CONFCOMMENT* ConfFileLookupBlockComment(CONFITEM* item, short* index, int numindex, CONFCOMMENT* last);
const wchar_t* ConfFileArrayLookupName   (CONFITEM* item, short* index, int numindex, wchar_t* buffer, int len);
int          ConfFileArrayLookupVisible(CONFITEM* item, short* index, int numindex);
void         ConfFileArrayDeleteValue  (CONFITEM* item, short* index, int numindex);

int          ConfFileStartDrag         (CONFFILE* conf, int lineindex);
int          ConfFileDragValueUp       (CONFFILE* conf, int* newlineindex);
int          ConfFileDragValueDown     (CONFFILE* conf, int* newlineindex);
void         ConfFileEndDrag           (CONFFILE* conf);

void         ConfFileAddBlockComment   (CONFFILE* conf, const wchar_t* value);
void         ConfFileUseBlockComment   (CONFFILE* conf, CONFITEM* item, const wchar_t* name);

int          ConfFileNumOptional       (CONFFILE* conf);

#endif

