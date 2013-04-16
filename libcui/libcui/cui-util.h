/* ---------------------------------------------------------------------
 * File: cui-util.h
 * (Header file for libcui-util - a helper library for libcui)
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
#ifndef CUIUTIL_H
#define CUIUTIL_H

#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <regex.h>
#include <stdio.h>
#include "cui-char.h"

typedef void (*ErrorCallback)(void* instance,
                              const wchar_t* errmsg, 
                              const wchar_t* filename,
                              int line, 
                              int is_warning);


/* ---------------------------------------------------------------------
 * char help routines
 * ---------------------------------------------------------------------
 */
int      MbStrLen(const char *str);
int      MbByteLen(const wchar_t *str);
wchar_t *MbToTCharDup(const char *str);
char    *TCharToMbDup(const wchar_t *str);

void     CuuSetStdCodec  (const char *encoding);
wchar_t *CuuToUtf16      (wchar_t *buffer, const char *str, int bufsize);
char    *CuuFromUtf16    (char *buffer, const wchar_t *str, int bufsize);
wchar_t *CuuEncToUtf16   (const char *encoding, wchar_t *buffer, const char *str, int bufsize);
char    *CuuEncFromUtf16 (const char *encoding, char *buffer, const wchar_t *str, int bufsize);


/* ---------------------------------------------------------------------
 * wrappers for unicode support
 * ---------------------------------------------------------------------
 */
FILE*   FileOpen       (const wchar_t *filename, const wchar_t *mode);
int     FileStat       (const wchar_t *path, struct stat *buf);
int     FileAccess     (const wchar_t *filename, int mode); /* R_OK, W_OK, X_OK and F_OK. */
int     FileRemove     (const wchar_t *filename);
#define FileClose fclose

DIR*    OpenDirectory  (const wchar_t *name);
#define ReadDirectory readdir
#define CloseDirectory closedir

int     CreateDirectory(const wchar_t *name, mode_t mode);
int     RemoveDirectory(const wchar_t *name);
int     ExecSysCmd     (const wchar_t *cmd);

int     RegCompile     (regex_t *preg, const wchar_t *regex, int cflags); 
int     RegExec        (const regex_t *preg, const wchar_t *string, size_t nmatch, regmatch_t pmatch[], int eflags); 
/* size_t regerror(int errcode, const regex_t *preg, char *errbuf, size_t errbuf_size);  */
#define RegFree regfree

/* ---------------------------------------------------------------------
 * co-process routines
 * ---------------------------------------------------------------------
 */

#define PIPE_STDOUT 0
#define PIPE_STDERR 1

typedef void (*TextCall) (const char* buffer, int source, void* instance);

typedef struct
{
	char*    Command;
	char*    ReadBuf;
	int      ReadPos;
	int      ReadSize;
	int      Terminated;
	int      FdStdin;              /* stdin, stdout, stderr */
	int      FdStdout;
	int      FdStderr;
	int      StdoutOpen;
	int      StderrOpen;
	int      Pid;                  /* PID of child process */
} COPROC;

/* background co-process */
COPROC* CoProcCreate(const wchar_t* cmd);
int     CoProcRead(COPROC* coproc, wchar_t *buf, int count);
int     CoProcWrite(COPROC* coproc, const wchar_t *buf, int count);
void    CoProcDelete(COPROC* coproc);
int     CoProcIsRunning(COPROC* coproc, int *exitcode);

/* foreground co-process */
int     RunCoProcess(const wchar_t* filename,
                     wchar_t* const parameters[],
                     TextCall callback,
                     void* instance,
                     int* exitcode);

/* ---------------------------------------------------------------------
 * XML file handling
 * ---------------------------------------------------------------------
 */

#define XML_DATANODE    0
#define XML_OBJNODE     1
#define XML_COMMENTNODE 2

typedef struct
{
	wchar_t* Name;              /* name of XML attribute */
	wchar_t* Value;             /* name of attribute value */
	void*    Next;              /* next XML attribute */
} XMLATTRIBUTE;

typedef struct
{
	int      Type;              /* Type of node: data or child object */
	wchar_t* Data;              /* Data (if node is a data node) */
	int      DataLen;           /* Size of current data buffer */
	void*    Object;            /* Pointer to child object (if object node) */

	void*    Next;
} XMLNODE;

typedef struct
{
	wchar_t*       Name;         /* Name of XML object */

	XMLNODE*       FirstNode;    /* The first node containing data or a child object */
	XMLNODE*       LastNode;     /* The last node containing data or a child object */
	XMLATTRIBUTE*  FirstAttr;    /* Pointer to first object attribute */
	XMLATTRIBUTE*  LastAttr;     /* Pointer to last object attribute */
} XMLOBJECT;

typedef struct
{
	wchar_t*       Name;         /* Name of single tag */
	void*          Next;         /* Next single tag */
} XMLSINGLETAG;

typedef struct
{
	wchar_t*       Version;      /* XML format version */
	wchar_t*       Encoding;     /* Character encoding */
	wchar_t*       Standalone;   /* No external markups / no external DTD */
} XMLTYPEHEADER;

typedef struct
{
	wchar_t*       HRef;         /* URi of CSS file */
	wchar_t*       Type;         /* Mime type of stylesheet */
	wchar_t*       Title;        /* Title of stylesheet */
	wchar_t*       Media;        /* Media of stylesheet appliance */
	wchar_t*       CharSet;      /* Character encoding of stylesheet */
	wchar_t*       Alternate;    /* Is there an alternate? default = no */
	void*          Next;         /* Next stylesheet */
} XMLSTYLESHEET;

typedef struct
{
	wchar_t*       FileName;     /* Name of XML file */
	XMLOBJECT*     RootObj;      /* Pointer to first object */
	ErrorCallback  ErrorOut;     /* Callback function for errors */
	void*          ErrorInst;    /* Instance handle */
	int            Sym;          /* Symbol code delivered from scanner */
	int            Errors;       /* Number of errors during parsing */
	int            PreserveNL;   /* Shall newline characters be preserved? */
	XMLSINGLETAG*  FirstSingle;  /* List of tags without closing tag */
	XMLTYPEHEADER* TypeHeader;   /* Optional type header */
	XMLSTYLESHEET* FirstSSheet;  /* First style sheet definition */
	XMLSTYLESHEET* LastSSheet;   /* Last style sheet definition */
} XMLFILE;

XMLFILE*      XmlCreate            (const wchar_t* filename);
void          XmlDelete            (XMLFILE* xml);
void          XmlSetErrorHook      (XMLFILE* xml, ErrorCallback errout, 
                                    void* instance);
void          XmlAddSingleTag      (XMLFILE* xml, const wchar_t* name);
int           XmlReadFile          (XMLFILE* xml);
int           XmlWriteFile         (XMLFILE* xml);
XMLOBJECT*    XmlGetObjectTree     (XMLFILE* xml);

XMLOBJECT*    XmlSearch(XMLFILE* xml, const wchar_t* searchspec);

void          XmlPreserveNewline   (XMLFILE* xml, int state);

XMLOBJECT*    XmlCreateObject      (XMLFILE* xml, XMLOBJECT* parent);
void          XmlDeleteObject      (XMLFILE* xml, XMLOBJECT* ob);
void          XmlSetObjectName     (XMLOBJECT* ob, const wchar_t* name);
void          XmlSetObjectData     (XMLOBJECT* ob, const wchar_t* data);
void          XmlAddObjectData     (XMLOBJECT* ob, const wchar_t* data);
void          XmlSetObjectComment  (XMLOBJECT* ob, const wchar_t* data);
void          XmlAddObjectComment  (XMLOBJECT* ob, const wchar_t* data);

XMLATTRIBUTE* XmlCreateAttribute   (XMLOBJECT* ob, const wchar_t* name);
void          XmlSetAttributeValue (XMLATTRIBUTE* attr, const wchar_t* name);
XMLATTRIBUTE* XmlGetAttribute      (XMLOBJECT* ob, const wchar_t* name);


/* ---------------------------------------------------------------------
 * (simple and strait forward) config file handling
 * with this routines it is possible to read structured eisfair-style 
 * config files without reading additional files like check.d etc.
 * ---------------------------------------------------------------------
 */

typedef enum {
	REQUIRED,
	OPTIONAL
} OPT_TYPE;

typedef struct {
	wchar_t*      Name;            /* option name */
	wchar_t*      Value;           /* option value */
	int           LineNo;          /* line number of option in source file */
	void*         FirstChild;      /* first child entry (in case of N_NODE) */
	void*         LastChild;       /* last child entry */
	void*         Next;            /* next option */
} CONFENTRY;


typedef struct {
	wchar_t*      NNode;           /* name of parent node (FOO_N) */
	wchar_t*      Mask;            /* match mask for config node  FOO_%_NAME */
	void*         Next;            /* next node */
} CONFNODE;


typedef struct {
	CONFENTRY*    FirstEntry;      /* first config option */
	CONFENTRY*    LastEntry;       /* last config option */
	CONFNODE*     FirstNode;       /* first n-node */
	wchar_t*      FileName;        /* name of config file */
	ErrorCallback ErrOut;          /* error callback */
	void*         ErrInst;         /* callback instance */
} CONFIG;


CONFIG*     ConfigOpen     (ErrorCallback errout, void* instance);
void        ConfigAddNode  (CONFIG* cfg, const wchar_t* n_node, const wchar_t* mask);
void        ConfigReadFile (CONFIG* cfg, const wchar_t* filename);

CONFENTRY*  ConfigGetEntry (CONFIG* cfg, CONFENTRY* parent, const wchar_t* name, int * index);
const wchar_t* ConfigGetString(CONFIG* cfg, CONFENTRY* parent, const wchar_t* name, 
                            OPT_TYPE type, const wchar_t* defval, int * index);
int         ConfigGetBool  (CONFIG* cfg, CONFENTRY* parent, const wchar_t* name, 
                            OPT_TYPE type, const wchar_t* defval, int * index);
int         ConfigGetNum   (CONFIG* cfg, CONFENTRY* parent, const wchar_t* name,
                            OPT_TYPE type, const wchar_t* defval, int * index);

void        ConfigClose    (CONFIG* clg);

#endif

