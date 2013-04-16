/* ---------------------------------------------------------------------
 * File: xmlparser.c
 * (almost xml compliant file parser)
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

#include "global.h"
#include "cui-util.h"
#include "xml.h"

#define DATAGROUTH  40

#ifndef FALSE
#define FALSE 0
#define TRUE  !FALSE
#endif

/* private prototypes */
static void XmlError(XMLFILE* xml, const wchar_t* errmsg, int is_warning);
static void XmlClosePreviousComment(XMLOBJECT* obj);
static void XmlFreeObject(XMLOBJECT* ob);
static void XmlFreeTypeHeader(XMLTYPEHEADER* type);
static void XmlFreeStyleSheet(XMLSTYLESHEET* sheet);
static void XmlReadObject(XMLFILE* xml, XMLOBJECT* parent);
static void XmlReadOpeningTag(XMLFILE* xml, int* shorttag, XMLOBJECT* ob);
static void XmlReadClosingTag(XMLFILE* xml, XMLOBJECT* ob);
static void XmlReadAttribute(XMLFILE* xml, XMLOBJECT* ob);
static void XmlRecover(XMLFILE* xml, int sym);
static int  XmlIsSingleTag(XMLFILE* xml, const wchar_t* name);
static void XmlWriteObject(XMLOBJECT* ob, int level, FILE* out);
static void XmlWriteSpace(int level, FILE* out);
static void XmlWriteToFile(const wchar_t* text, FILE* out);
static void XmlWriteLowcase(const wchar_t* text, FILE* out);
static void XmlWriteData(const wchar_t* text, int len, FILE* out);
static void XmlWriteTypeHeader(XMLTYPEHEADER* type, FILE* out);
static void XmlWriteStyleSheets(XMLSTYLESHEET* sheet, FILE* out);
static int  XmlDeleteChild(XMLOBJECT* ob, XMLOBJECT* childob);
static void XmlReadHeader(XMLFILE* xml);
static void XmlReadTypeHeader(XMLFILE* xml);
static void XmlReadStyleSheet(XMLFILE* xml);
static int  XmlMatchTag(XMLOBJECT* xmlobj, const wchar_t* attrspec, int* tagidx);
static XMLOBJECT* XmlFindNext(XMLOBJECT* xmlobj, const wchar_t* tagspec);

extern const char* EntityTable[][2];

/* public functions */

/* ---------------------------------------------------------------------
 * XmlCreate
 * Create a XMLFILE structure that will be used as a context handle
 * for all further parser functions
 * ---------------------------------------------------------------------
 */
XMLFILE*   
XmlCreate(const wchar_t* filename)
{
	XMLFILE*   xml;
	XMLOBJECT* ob;

	xml = (XMLFILE*) malloc(sizeof(XMLFILE));
	xml->FileName = wcsdup(filename);
	xml->ErrorOut = NULL;
	xml->FirstSingle = NULL;
	xml->PreserveNL = FALSE;
	xml->TypeHeader = NULL;
	xml->FirstSSheet = NULL;
	xml->LastSSheet = NULL;

	ob = (XMLOBJECT*) malloc(sizeof(XMLOBJECT));
	ob->Name = wcsdup(_T("$$ROOT$$"));
	ob->FirstNode = NULL;
	ob->LastNode = NULL;
	ob->FirstAttr = NULL;
	ob->LastAttr = NULL;

	xml->RootObj = ob;

	return xml;
}

/* ---------------------------------------------------------------------
 * XmlDelete
 * Delete the XMLFILE structure and all associated data
 * ---------------------------------------------------------------------
 */
void
XmlDelete(XMLFILE* xml)
{
	XMLSINGLETAG* stag;
	XMLSTYLESHEET* sheet;
	if (!xml) return;

	/* delete single tags - single tags are tags with not closing tag */
	stag = xml->FirstSingle;
	while (stag)
	{
		xml->FirstSingle = (XMLSINGLETAG*) stag->Next;
		if (stag->Name) free(stag->Name);
		free(stag);
		stag = xml->FirstSingle;
	}

	/* delete style sheets */
	sheet = xml->FirstSSheet;
	while (sheet)
	{
		xml->FirstSSheet = (XMLSTYLESHEET*) sheet->Next;
		XmlFreeStyleSheet(sheet);
		sheet = xml->FirstSSheet;
	}

	/* delete type header */
	if (xml->TypeHeader) XmlFreeTypeHeader(xml->TypeHeader);

	/* object tree */
	XmlFreeObject(xml->RootObj);

	/* structure */
	free(xml->FileName);
	free(xml);
}

/* ---------------------------------------------------------------------
 * XmlSetErrorHook
 * Assign a callback function that has to be called when an error
 * is encountered
 * ---------------------------------------------------------------------
 */
void
XmlSetErrorHook(XMLFILE* xml, ErrorCallback errout, void* instance)
{
	if (!xml) return;
	xml->ErrorOut = errout;
	xml->ErrorInst = instance;
}

/* ---------------------------------------------------------------------
 * XmlAddSingleTag
 * Add a tag name to the list of known tags that don't need a closing
 * tag to be complete. In this case <tagname> ist the same as <tagname/>
 * ---------------------------------------------------------------------
 */
void
XmlAddSingleTag(XMLFILE* xml, const wchar_t* name)
{
	XMLSINGLETAG* stag;
	if (!xml) return;

	stag = (XMLSINGLETAG*) malloc(sizeof(XMLSINGLETAG));
	stag->Name = wcsdup(name);
	stag->Next = xml->FirstSingle;
	xml->FirstSingle = stag;
}

/* ---------------------------------------------------------------------
 * XmlReadFile
 * Read the xml-data contained within the file specified by 'xml->FileName'
 * useing parser functions below
 * ---------------------------------------------------------------------
 */
int 
XmlReadFile(XMLFILE* xml)
{
	if (!xml) return TRUE;

	/* prepare scanner.... */
	xml->Errors = 0;
	if (!XmlFileOpen(xml->FileName, xml->ErrorOut, xml->ErrorInst))
	{
        	XmlError(xml,_T("file not found"),FALSE);
		return FALSE;
	}
                             
	XmlParseNL(FALSE);                                   
	if (xml->PreserveNL) XmlParseNL(TRUE);

	/* read file */
	xml->Sym = XmlRead();
	while (xml->Sym != XML_EOF) 
	{
		switch(xml->Sym)
		{
		case XML_TAGOPEN:
			XmlAddObjectData(xml->RootObj, XmlGetDataBuf());
			XmlClearData();
			xml->Sym = XmlRead();
			XmlReadObject(xml, NULL);
			break;
		case XML_HEADEROPEN:
			XmlAddObjectData(xml->RootObj, XmlGetDataBuf());
			XmlClearData();
			xml->Sym = XmlRead();
			XmlReadHeader(xml);
			break;
		case XML_COMMENTOPEN:
			XmlAddObjectData(xml->RootObj, XmlGetDataBuf());
			XmlClearData();
			xml->Sym = XmlRead();
			if (xml->Sym == XML_COMMENTCLOSE)
			{
				XmlClosePreviousComment(xml->RootObj);
				XmlAddObjectComment(xml->RootObj, XmlGetDataBuf());
				XmlClearData();
				xml->Sym = XmlRead();
			}
			break;
		default:
			XmlError(xml,_T("opening tag expected"),FALSE);
			XmlRecover(xml,XML_TAGOPEN);
			break;
		}
	}
	/* read data that still resides in the data buffer */
	XmlAddObjectData(xml->RootObj, XmlGetDataBuf());
	XmlClearData();

	/* remove scanner */
	XmlClose();
	return (xml->Errors == 0);
}

/* ---------------------------------------------------------------------
 * XmlWriteFile
 * Write the xml-data to the file specified by 'xml->FileName'
 * ---------------------------------------------------------------------
 */
int 
XmlWriteFile(XMLFILE* xml)
{
	char* mbfilename;
	int result = FALSE;
	FILE* out;

	if (!xml) return TRUE;

	mbfilename = TCharToMbDup(xml->FileName); 
	if (mbfilename)
	{
		out = fopen(mbfilename,"wt");
		if (out)
		{
			if (xml->TypeHeader)
			{
				XmlWriteTypeHeader(xml->TypeHeader, out);
			}
			if (xml->FirstSSheet)
			{
				XmlWriteStyleSheets(xml->FirstSSheet, out);
			}
			XmlWriteObject(xml->RootObj,-1,out);
			if (!ferror(out))
			{
				result = TRUE;
			}
			fclose(out);
		}
		free(mbfilename);
	}
	return result;
}

/* ---------------------------------------------------------------------
 * XmlGetObjectTree
 * Retreive the first object of the object tree
 * ---------------------------------------------------------------------
 */
XMLOBJECT* 
XmlGetObjectTree(XMLFILE* xml)
{
	if (!xml) return NULL;

	return xml->RootObj;
}

/* ---------------------------------------------------------------------
 * XmlSearch
 * Search an object within the current xml-Data using a search state-
 * ment that follows this format:
 *    tag:subtag:subtag... 
 * where tag and subtag consist of the following elements:
 *    name [ "(" attrib=value { "," attrib=value } ")" ]
 * ---------------------------------------------------------------------
 */
XMLOBJECT*
XmlSearch(XMLFILE* xml, const wchar_t* searchspec)
{
	const wchar_t* p = searchspec;
	XMLOBJECT* obj = xml->RootObj;
	
	while (p && obj)
	{

		obj = XmlFindNext(obj, p);
		if (obj)
		{
			p = wcschr(p, _T(':'));
			if (p)
			{
				p++;
			}
		}
	}
	return obj;
}

/* ---------------------------------------------------------------------
 * XmlPreserveNewline
 * If PreserveNewline is enabled, "\n" characters are added to the
 * objects data whenever a LEX_END_OF_LINE symbol is delivered by the
 * scanner. 
 * default: PerserveNewline = FALSE
 * ---------------------------------------------------------------------
 */
void
XmlPreserveNewline(XMLFILE* xml, int state)
{
	if (!xml) return;

	xml->PreserveNL = state;
}

/* ---------------------------------------------------------------------
 * XmlCreateObject
 * Manually create an xml-Object within the Object-Tree. If parent
 * is NULL, The object is appended to the root node, else it becomes
 * a child of the object passed in 'parent'
 * ---------------------------------------------------------------------
 */
XMLOBJECT*
XmlCreateObject(XMLFILE* xml, XMLOBJECT* parent)
{
	XMLOBJECT* ob;
	XMLNODE*   node;

	ob = (XMLOBJECT*) malloc(sizeof(XMLOBJECT));
	ob->Name = wcsdup(_T("noname"));
	ob->FirstNode = NULL;
	ob->LastNode = NULL;
	ob->FirstAttr = NULL;
	ob->LastAttr = NULL;

	node = (XMLNODE*) malloc(sizeof(XMLNODE));
	node->Type = XML_OBJNODE;
	node->Data = NULL;
	node->DataLen = 0;
	node->Object = (XMLOBJECT*) ob;	
	node->Next = NULL;
	
	if (!parent) parent = xml->RootObj;
	if (parent) 
	{
		if (parent->FirstNode) 
		{
			parent->LastNode->Next = node;
		}
		else 
		{
			parent->FirstNode = node;
		}
		parent->LastNode = node;
	}
	return ob;
}

/* ---------------------------------------------------------------------
 * XmlCreateComment
 * Manually create an xml-Comment within the Object-Tree. If parent
 * is NULL, The object is appended to the root node, else it becomes
 * a child of the object passed in 'parent'
 * ---------------------------------------------------------------------
 */
XMLOBJECT*
XmlCreateComment(XMLFILE* xml, XMLOBJECT* parent)
{
	XMLOBJECT* ob;
	XMLNODE*   node;

	ob = (XMLOBJECT*) malloc(sizeof(XMLOBJECT));
	ob->Name = wcsdup(_T("noname"));
	ob->FirstNode = NULL;
	ob->LastNode = NULL;
	ob->FirstAttr = NULL;
	ob->LastAttr = NULL;

	node = (XMLNODE*) malloc(sizeof(XMLNODE));
	node->Type = XML_COMMENTNODE;
	node->Data = NULL;
	node->DataLen = 0;
	node->Object = (XMLOBJECT*) ob;	
	node->Next = NULL;
	
	if (!parent) parent = xml->RootObj;
	if (parent) 
	{
		if (parent->FirstNode) 
		{
			parent->LastNode->Next = node;
		}
		else 
		{
			parent->FirstNode = node;
		}
		parent->LastNode = node;
	}
	return ob;
}

/* ---------------------------------------------------------------------
 * XmlSetObjectName
 * Redefine the name of an object
 * ---------------------------------------------------------------------
 */
void
XmlSetObjectName(XMLOBJECT* ob, const wchar_t* name)
{
	if (!ob) return;

	if (ob->Name) free(ob->Name);
	ob->Name = wcsdup(name);
}

/* ---------------------------------------------------------------------
 * XmlSetObjectData
 * Assigned data to object 'ob' replacing all existing data
 * ---------------------------------------------------------------------
 */
void
XmlSetObjectData(XMLOBJECT* ob, const wchar_t* data)
{
	XMLNODE* datnode;
	int newlen;

	if (!ob||!data) return;
	if (data[0]==0) return;

	if (ob->FirstNode)
	{
		if (ob->LastNode->Type != XML_DATANODE)
		{
			XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
			node->Type = XML_DATANODE;
			node->Data = NULL;
			node->DataLen = 0;
			node->Object = NULL;	
			node->Next = NULL;
	
			ob->LastNode->Next = node;
			ob->LastNode = node;
		}
	}
	else
	{
		XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
		node->Type = XML_DATANODE;
		node->Data = NULL;
		node->DataLen = 0;
		node->Object = NULL;	
		node->Next = NULL;
	
		ob->FirstNode = node;
		ob->LastNode = node;
	}
	datnode = ob->LastNode;

	if (datnode->Data) free(datnode->Data);
	
	newlen = (wcslen(data) + 1) / DATAGROUTH + 1;
	datnode->Data = (wchar_t*) malloc((newlen * DATAGROUTH) * sizeof(wchar_t));
	wcscpy(datnode->Data,data);

	datnode->DataLen = newlen * DATAGROUTH;
}

/* ---------------------------------------------------------------------
 * XmlAddObjectData
 * Add data to object 'ob' by appending it to the existing data
 * ---------------------------------------------------------------------
 */
void
XmlAddObjectData(XMLOBJECT* ob, const wchar_t* data)
{
	XMLNODE* datnode;

	if (!ob||!data) return;
	if (data[0]==0) return;

	if (ob->FirstNode)
	{
		if (ob->LastNode->Type != XML_DATANODE)
		{
			XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
			node->Type = XML_DATANODE;
			node->Data = NULL;
			node->DataLen = 0;
			node->Object = NULL;	
			node->Next = NULL;
	
			ob->LastNode->Next = node;
			ob->LastNode = node;
		}
	}
	else
	{
		XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
		node->Type = XML_DATANODE;
		node->Data = NULL;
		node->DataLen = 0;
		node->Object = NULL;	
		node->Next = NULL;
	
		ob->FirstNode = node;
		ob->LastNode = node;
	}
	datnode = ob->LastNode;
	
	if (!datnode->Data)
	{
		XmlSetObjectData(ob,data);
	}
	else 
	{
		int newlen = (wcslen(datnode->Data) + wcslen(data) + 2) / DATAGROUTH + 1;
		if (newlen * DATAGROUTH >= datnode->DataLen)
		{
			wchar_t* tmpbuf = (wchar_t*) malloc((newlen * DATAGROUTH) * sizeof(wchar_t));
			wcscpy(tmpbuf,datnode->Data);
			free(datnode->Data);
			datnode->Data = tmpbuf;
			datnode->DataLen = newlen * DATAGROUTH;
		}
		wcscat(datnode->Data,data);
	}
}

/* ---------------------------------------------------------------------
 * XmlSetObjectComment
 * Assign a comment to object 'ob' replacing all existing comment
 * ---------------------------------------------------------------------
 */
void
XmlSetObjectComment(XMLOBJECT* ob, const wchar_t* data)
{
	XMLNODE* datnode;
	int newlen;

	if (!ob||!data) return;
	if (data[0]==0) return;

	if (ob->FirstNode)
	{
		if (ob->LastNode->Type != XML_COMMENTNODE)
		{
			XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
			node->Type = XML_COMMENTNODE;
			node->Data = NULL;
			node->DataLen = 0;
			node->Object = NULL;	
			node->Next = NULL;
	
			ob->LastNode->Next = node;
			ob->LastNode = node;
		}
	}
	else
	{
		XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
		node->Type = XML_COMMENTNODE;
		node->Data = NULL;
		node->DataLen = 0;
		node->Object = NULL;	
		node->Next = NULL;
	
		ob->FirstNode = node;
		ob->LastNode = node;
	}
	datnode = ob->LastNode;

	if (datnode->Data) free(datnode->Data);
	
	newlen = (wcslen(data) + 1) / DATAGROUTH + 1;
	datnode->Data = (wchar_t*) malloc((newlen * DATAGROUTH) * sizeof(wchar_t));
	wcscpy(datnode->Data,data);

	datnode->DataLen = newlen * DATAGROUTH;
}

/* ---------------------------------------------------------------------
 * XmlAddObjectComment
 * Add a comment to object 'ob' by appending it to the existing data
 * ---------------------------------------------------------------------
 */
void
XmlAddObjectComment(XMLOBJECT* ob, const wchar_t* data)
{
	XMLNODE* datnode;

	if (!ob||!data) return;
	if (data[0]==0) return;

	if (ob->FirstNode)
	{
		if (ob->LastNode->Type != XML_COMMENTNODE)
		{
			XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
			node->Type = XML_COMMENTNODE;
			node->Data = NULL;
			node->DataLen = 0;
			node->Object = NULL;	
			node->Next = NULL;
	
			ob->LastNode->Next = node;
			ob->LastNode = node;
		}
	}
	else
	{
		XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
		node->Type = XML_COMMENTNODE;
		node->Data = NULL;
		node->DataLen = 0;
		node->Object = NULL;	
		node->Next = NULL;
	
		ob->FirstNode = node;
		ob->LastNode = node;
	}
	datnode = ob->LastNode;
	
	if (!datnode->Data)
	{
		XmlSetObjectComment(ob,data);
	}
	else 
	{
		int newlen = (wcslen(datnode->Data) + wcslen(data) + 2) / DATAGROUTH + 1;
		if (newlen * DATAGROUTH >= datnode->DataLen)
		{
			wchar_t* tmpbuf = (wchar_t*) malloc((newlen * DATAGROUTH) * sizeof(wchar_t));
			wcscpy(tmpbuf,datnode->Data);
			free(datnode->Data);
			datnode->Data = tmpbuf;
			datnode->DataLen = newlen * DATAGROUTH;
		}
		if (datnode->Data[0] != 0) 
		{
			wcscat(datnode->Data,_T(" "));
		}
		wcscat(datnode->Data,data);
	}
}

/* ---------------------------------------------------------------------
 * XmlCreateAttribute
 * Add an attribute 'name' to object 'ob'
 * ---------------------------------------------------------------------
 */
XMLATTRIBUTE*
XmlCreateAttribute(XMLOBJECT* ob, const wchar_t* name)
{
	XMLATTRIBUTE* attr;

	if (!ob) return NULL;

	attr = (XMLATTRIBUTE*) malloc(sizeof(XMLATTRIBUTE));
	attr->Name = wcsdup(name);
	attr->Value = NULL;
	attr->Next = NULL;

	if (ob->FirstAttr) ob->LastAttr->Next = attr;
	else ob->FirstAttr = attr;
	ob->LastAttr = attr;

	return attr;
}

/* ---------------------------------------------------------------------
 * XmlSetAttributeValue
 * Assign a value to attribute 'attr' (relacing existing value)
 * ---------------------------------------------------------------------
 */
void 
XmlSetAttributeValue(XMLATTRIBUTE* attr, const wchar_t* value)
{
	if (!attr) return;
	if (attr->Value) free(attr->Value);
	attr->Value = wcsdup(value);
}

/* ---------------------------------------------------------------------
 * XmlGetAttribute
 * Seek an attribute from a given object
 * ---------------------------------------------------------------------
 */
XMLATTRIBUTE*
XmlGetAttribute(XMLOBJECT* ob, const wchar_t* name)
{
	XMLATTRIBUTE* seekptr;

	if (!ob) return NULL;

	seekptr = ob->FirstAttr;
	while(seekptr)
	{
		if (wcscasecmp(seekptr->Name,name)==0)
		{
			return seekptr;
		}
		seekptr = (XMLATTRIBUTE*) seekptr->Next;
	}
	return NULL;
}

/* ---------------------------------------------------------------------
 * XmlDeleteObject
 * Unlink and delete the given object from the object tree
 * ---------------------------------------------------------------------
 */
void
XmlDeleteObject(XMLFILE* xml, XMLOBJECT* ob)
{
	if (!xml) return;
	XmlDeleteChild(xml->RootObj,ob);
}


/* internal functions */

/* ---------------------------------------------------------------------
 * XmlClosePreviousComment
 * Close the current comment node (if any) and create a new one
 * ---------------------------------------------------------------------
 */
static void
XmlClosePreviousComment(XMLOBJECT* ob)
{
	if (!ob) return;

	if (ob->FirstNode)
	{
		if (ob->LastNode->Type == XML_COMMENTNODE)
		{
			XMLNODE* node = (XMLNODE*) malloc(sizeof(XMLNODE));
			node->Type = XML_COMMENTNODE;
			node->Data = NULL;
			node->DataLen = 0;
			node->Object = NULL;	
			node->Next = NULL;
	
			ob->LastNode->Next = node;
			ob->LastNode = node;
		}
	}
}

/* ---------------------------------------------------------------------
 * XmlDeleteChild
 * Search the tree for the object 'childob', then unlink and delete it
 * ---------------------------------------------------------------------
 */
static int
XmlDeleteChild(XMLOBJECT* ob, XMLOBJECT* childob)
{
	XMLNODE* node;
	XMLNODE* oldnode = NULL;

	if (!ob) return FALSE;

	node = ob->FirstNode;
	while (node)
	{
		if (node->Type==XML_OBJNODE)
		{
			if (node->Object == childob)
			{
				if (oldnode)
				{
					oldnode->Next = node->Next;
				}
				else
				{
					ob->FirstNode = node->Next;
				}
				if (node == ob->LastNode)
				{
					ob->LastNode = oldnode;
				}
				XmlFreeObject(node->Object);
				free(node);
				return TRUE;
			}
			else if (XmlDeleteChild(node->Object, childob))
			{
				return TRUE;
			}
		}
		oldnode = node;
		node = (XMLNODE*) node->Next;
	}
	return FALSE;
}

/* ---------------------------------------------------------------------
 * XmlError
 * An error occured. Passing error to error handler.
 * ---------------------------------------------------------------------
 */
static void
XmlError(XMLFILE* xml, const wchar_t* errmsg, int is_warning)
{
	if (xml->ErrorOut)
	{
		int line = XmlGetLineNumber();
	
		xml->ErrorOut(xml->ErrorInst, errmsg,xml->FileName,line,is_warning);
	}
	xml->Errors++;
}

/* ---------------------------------------------------------------------
 * XmlFreeObject
 * Free an object and all child objects
 * ---------------------------------------------------------------------
 */
static void
XmlFreeObject(XMLOBJECT* ob)
{
	XMLATTRIBUTE* attr;
	XMLNODE* node;

	if (!ob) return;

	/* memove all child objects */
	node = ob->FirstNode;
	while (node)
	{
		ob->FirstNode = (XMLNODE*) node->Next;

		if ((node->Type==XML_DATANODE) || (node->Type==XML_COMMENTNODE))
		{
			if (node->Data) free(node->Data);
		}
		else
		{
			XmlFreeObject(node->Object);
		}
		free(node);
	
		node = ob->FirstNode;
	}

	/* remove objects data */
	attr = ob->FirstAttr;
	while (attr) 
	{
		ob->FirstAttr = (XMLATTRIBUTE*) attr->Next;
		if (attr->Name)  free(attr->Name);
		if (attr->Value) free(attr->Value);
		free(attr);
		attr = ob->FirstAttr;
	}
	if (ob->Name) free(ob->Name);
	free(ob);
}

/* ---------------------------------------------------------------------
 * XmlFreeTypeHeader
 * Free a type header structure
 * ---------------------------------------------------------------------
 */
static void 
XmlFreeTypeHeader(XMLTYPEHEADER* type)
{
	if (type)
	{
		if (type->Version) free(type->Version);
		if (type->Encoding) free(type->Encoding);
		if (type->Standalone) free(type->Standalone);
		free(type);
	}
}

/* ---------------------------------------------------------------------
 * XmlFreeStyleSheet
 * Free a style sheet structure
 * ---------------------------------------------------------------------
 */
static void 
XmlFreeStyleSheet(XMLSTYLESHEET* sheet)
{
	if (sheet)
	{
		if (sheet->HRef) free(sheet->HRef);
		if (sheet->Type) free(sheet->Type);
		if (sheet->Media) free(sheet->Media);
		if (sheet->CharSet) free(sheet->CharSet);
		if (sheet->Alternate) free(sheet->Alternate);
		free(sheet);
	}
}


/* ---------------------------------------------------------------------
 * XmlIsSingleTag
 * Check if parameter 'name' exists in the list of known single tags
 * ---------------------------------------------------------------------
 */
static int  
XmlIsSingleTag(XMLFILE* xml, const wchar_t* name)
{
	XMLSINGLETAG* stag = xml->FirstSingle;
	while(stag)
	{
		if (wcscasecmp(stag->Name,name)==0)
		{
			return TRUE;
		}
		stag = (XMLSINGLETAG*) stag->Next;
	}
	return FALSE;
}


/* parser functions */         

/* ---------------------------------------------------------------------
 * XmlReadHeader
 * Header := HeaderOpen ('xml' XmlTypeHeader | 'xml-stylesheet' XmlStyleSheet) 
 *           HeaderClose
 * ---------------------------------------------------------------------
 */
static void
XmlReadHeader(XMLFILE* xml)
{
	if (xml->Sym != XML_IDENT)
	{
		XmlError(xml, _T("invalid xml header"), FALSE);
		XmlRecover(xml, XML_HEADERCLOSE);
	}
	else
	{
		wchar_t* text = XmlGetTextDup();
		if (text)
		{
			if (wcscasecmp(_T("xml"), XmlGetTextDup()) == 0)
			{
				xml->Sym = XmlRead();
				XmlReadTypeHeader(xml);
			}
			else if (wcscasecmp(_T("xml-stylesheet"), XmlGetTextDup()) == 0)
			{
				xml->Sym = XmlRead();
				XmlReadStyleSheet(xml);
			}
			else
			{
				XmlError(xml, _T("unknown xml header"), TRUE);
				XmlRecover(xml, XML_HEADERCLOSE);
			}
			free(text);
		}
	}

	if (xml->Sym != XML_HEADERCLOSE)
	{
		XmlError(xml, _T("unclosed header, missing '?>'"), FALSE);
		return;
	}
	xml->Sym = XmlRead();
}


/* ---------------------------------------------------------------------
 * XmlReadTypeHeader
 * TypeHeader := 'version' '=' string 
 *               [ 'encoding' '=' string ]
 *               [ 'standalone' '=' string ]
 * ---------------------------------------------------------------------
 */
static void
XmlReadTypeHeader(XMLFILE* xml)
{
	XMLTYPEHEADER* type = (XMLTYPEHEADER*) malloc(sizeof(XMLTYPEHEADER));
	if (type)
	{
		type->Version = NULL;
		type->Encoding = NULL;
		type->Standalone = NULL;
	}

	while (xml->Sym == XML_IDENT)                     /* optional attributes */
	{
		wchar_t* attrname = NULL;
		wchar_t* attrvalue = NULL;

		attrname = XmlGetTextDup();
		xml->Sym = XmlRead();

		if (xml->Sym == XML_EQUAL)
		{
			xml->Sym = XmlRead();
			if (xml->Sym == XML_STRING)
			{
				attrvalue = XmlGetStringDup();
				xml->Sym = XmlRead();
			}
			else
			{
				XmlError(xml, _T("missing string value"), FALSE);
			}
		}
		else
		{
			XmlError(xml, _T("missing value assignment"), FALSE);
		}

		if (type && attrname && attrvalue)
		{
			if (wcscasecmp(attrname, _T("version")) == 0)
			{
				type->Version = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("encoding")) == 0)
			{
				type->Encoding = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("standalone")) == 0)
			{
				type->Standalone = attrvalue;
			}
			else
			{
				free(attrvalue);
			}
			free(attrname);
		}
		else
		{
			if (attrname) free(attrname);
			if (attrvalue) free(attrvalue);
		}
	}

	if (type)
	{
		if (!type->Version)
		{
			XmlError(xml, _T("missing \"version\" attribute"), FALSE);
			XmlFreeTypeHeader(type);
		}
		else
		{
			if (xml->TypeHeader) XmlFreeTypeHeader(xml->TypeHeader);
			xml->TypeHeader = type;
		}
	}
}


/* ---------------------------------------------------------------------
 * XmlReadStyleSheet
 * StyleSheet := 'href' '=' string 
 *               'type' '=' string
 *               [ 'title' '=' string ]
 *               [ 'media' '=' string ]
 *               [ 'charset' '=' string ]
 *               [ 'alternate' '=' string ]
 * ---------------------------------------------------------------------
 */
static void
XmlReadStyleSheet(XMLFILE* xml)
{
	XMLSTYLESHEET* sheet = (XMLSTYLESHEET*) malloc(sizeof(XMLSTYLESHEET));
	if (sheet)
	{
		sheet->HRef = NULL;
		sheet->Type = NULL;
		sheet->Title = NULL;
		sheet->Media = NULL;
		sheet->CharSet = NULL;
		sheet->Alternate = NULL;
		sheet->Next = NULL;
	}

	while (xml->Sym == XML_IDENT)                     /* optional attributes */
	{
		wchar_t* attrname = NULL;
		wchar_t* attrvalue = NULL;

		attrname = XmlGetTextDup();
		xml->Sym = XmlRead();

		if (xml->Sym == XML_EQUAL)
		{
			xml->Sym = XmlRead();
			if (xml->Sym == XML_STRING)
			{
				attrvalue = XmlGetStringDup();
				xml->Sym = XmlRead();
			}
			else
			{
				XmlError(xml, _T("missing string value"), FALSE);
			}
		}
		else
		{
			XmlError(xml, _T("missing value assignment"), FALSE);
		}

		if (sheet && attrname && attrvalue)
		{
			if (wcscasecmp(attrname, _T("href")) == 0)
			{
				sheet->HRef = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("type")) == 0)
			{
				sheet->Type = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("title")) == 0)
			{
				sheet->Title = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("media")) == 0)
			{
				sheet->Media = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("charset")) == 0)
			{
				sheet->CharSet = attrvalue;
			}
			else if (wcscasecmp(attrname, _T("alternate")) == 0)
			{
				sheet->Alternate = attrvalue;
			}
			else
			{
				free(attrvalue);
			}
			free(attrname);
		}
		else
		{
			if (attrname) free(attrname);
			if (attrvalue) free(attrvalue);
		}
	}

	if (sheet)
	{
		if (!sheet->HRef || !sheet->Type)
		{
			XmlError(xml, _T("missing \"href\" or \"type\" attribute"), FALSE);
			XmlFreeStyleSheet(sheet);
		}
		else
		{
			if (xml->FirstSSheet)
			{
				xml->LastSSheet->Next = sheet;
			}
			else
			{
				xml->FirstSSheet = sheet;
			}
			xml->LastSSheet = sheet;
		}
	}
}


/* ---------------------------------------------------------------------
 * XmlReadObject
 * Object := OpeningTag { Data | '<' Object } '<' '/' ClosingTag
 * ---------------------------------------------------------------------
 */
static void
XmlReadObject(XMLFILE* xml, XMLOBJECT* parent)
{
	XMLOBJECT* ob;
	int shorttag = FALSE;
	int readdata = TRUE;
	int closefound = FALSE;

	ob = XmlCreateObject(xml,parent);

	XmlReadOpeningTag(xml, &shorttag, ob);
	if (shorttag) return;

	/* read object data */
	while (readdata)
	{
		if (xml->Sym == XML_TAGOPEN) 
		{
			XmlAddObjectData(ob, XmlGetDataBuf());
			XmlClearData();

			xml->Sym = XmlRead();
			if (xml->Sym == XML_DIVIDE)             /* closing tag </tag> */
			{
				readdata = FALSE;
				closefound = TRUE;
				xml->Sym = XmlRead();
			}
			else 
			{
				XmlReadObject(xml,ob);          /* read child object */
			}
		}
		else if (xml->Sym == XML_COMMENTOPEN)
		{
			XmlAddObjectData(ob, XmlGetDataBuf());
			XmlClearData();
			xml->Sym = XmlRead();
			if (xml->Sym == XML_COMMENTCLOSE)
			{
				XmlClosePreviousComment(ob);
				XmlAddObjectComment(ob, XmlGetDataBuf());
				XmlClearData();
				xml->Sym = XmlRead();
			}
		}
		else if (xml->Sym == XML_EOF)                   /* did we reach the end? */
		{
			XmlError(xml, _T("unexpected end of file"),FALSE);
			readdata = FALSE;
		}
		else                                            /* some odd error */
		{
			XmlError(xml, _T("syntax error"),FALSE);
			XmlRecover(xml,XML_TAGOPEN);
			if (xml->Sym != XML_TAGOPEN) readdata = FALSE;
		}
	}

	/* read closing tag */
	if (closefound) 
	{
		XmlReadClosingTag(xml, ob);
	}
	else 
	{
		XmlError(xml, _T("missing closing tag"),FALSE);
	}
}

/* ---------------------------------------------------------------------
 * XmlReadOpeningTag
 * OpeningTag := Identifier { Attribute } '>'
 * ---------------------------------------------------------------------
 */
static void
XmlReadOpeningTag(XMLFILE* xml, int* shorttag, XMLOBJECT* ob)
{
	if (xml->Sym != XML_IDENT)                        /* identifier expected */
	{
		XmlError(xml, _T("tag identifier expected"),FALSE);
		XmlRecover(xml,XML_IDENT);
	}
	else 
	{
		wchar_t* text = XmlGetTextDup();
		if (text)
		{
			XmlSetObjectName(ob, text);
			if (XmlIsSingleTag(xml, text))    /* check if it is a single tag */
			{
				*shorttag = TRUE;
			}
			free(text);
		}
	}

	xml->Sym = XmlRead();
	while (xml->Sym == XML_IDENT)                     /* optional attributes */
	{
		XmlReadAttribute(xml, ob);
	}

	if (xml->Sym == XML_DIVIDE)                       /* short tag? <tag/> */
	{
		*shorttag = TRUE;
		xml->Sym = XmlRead();
	}

	if (xml->Sym != XML_TAGCLOSE)
	{
		XmlError(xml, _T("invalid tag definition"),FALSE);
		XmlRecover(xml, XML_TAGCLOSE);
	}

	xml->Sym = XmlRead();
}

/* ---------------------------------------------------------------------
 * XmlReadClosingTag
 * ClosingTag := Identifier '>'
 * ---------------------------------------------------------------------
 */
static void
XmlReadClosingTag(XMLFILE* xml, XMLOBJECT* ob)
{
	if (xml->Sym != XML_IDENT)                        /* identifier expected */
	{
		XmlError(xml, _T("tag identifier expected"),FALSE);
		XmlRecover(xml,XML_IDENT);
	}
	else 
	{
		wchar_t* text = XmlGetTextDup();
		if (text)
		{
			if (wcscasecmp(ob->Name, text) != 0)
			{
				XmlError(xml, _T("closing tag does not match opening tag"),FALSE);
			}
			free(text);
		}
	}
	xml->Sym = XmlRead();

	if (xml->Sym != XML_TAGCLOSE)
	{
		XmlError(xml, _T("invalid tag definition"),FALSE);
		XmlRecover(xml,XML_TAGCLOSE);
	}

	xml->Sym = XmlRead();
}

/* ---------------------------------------------------------------------
 * XmlReadAttribute
 * Attribute := Identifier [ '=' StringConstant ]
 * ---------------------------------------------------------------------
 */
static void
XmlReadAttribute(XMLFILE* xml, XMLOBJECT* ob)
{
	XMLATTRIBUTE* attr;
	wchar_t* text = XmlGetTextDup();
	if (text)
	{
		attr = XmlCreateAttribute(ob, text);

		xml->Sym = XmlRead();

		if (xml->Sym == XML_EQUAL)
		{
			xml->Sym = XmlRead();
	
			if (xml->Sym != XML_STRING) 
			{
				XmlError(xml, _T("string constant expected"),FALSE);
				XmlRecover(xml,XML_TAGCLOSE);
			}
			else
			{
				wchar_t* text = XmlGetStringDup();
				if (text)
				{
					XmlSetAttributeValue(attr, text);
					xml->Sym = XmlRead();
					free(text);
				}
			}
		}
		free(text);
	}
}                              

/* ---------------------------------------------------------------------
 * XmlRecover
 * Recover from error by consuming input until symbol 'sym' was found
 * ---------------------------------------------------------------------
 */
static void
XmlRecover(XMLFILE* xml, int sym)
{
	while ((xml->Sym != sym)&&(xml->Sym != XML_EOF))
	{
		xml->Sym = XmlRead();
	}
}

/* ---------------------------------------------------------------------
 * XmlWriteTypeHeader
 * Write a type header structure into a file
 * ---------------------------------------------------------------------
 */
static void
XmlWriteTypeHeader(XMLTYPEHEADER* type, FILE* out)
{
	if (type->Version)
	{
		fputs("<?xml version=\"", out);
		XmlWriteToFile(type->Version, out);
		fputs("\" ", out);

		if (type->Encoding)
		{
			fputs("encoding=\"", out);
			XmlWriteToFile(type->Encoding, out);
			fputs("\" ", out);
		}
		if (type->Standalone)
		{
			fputs("standalone=\"", out);
			XmlWriteToFile(type->Standalone, out);
			fputs("\" ", out);
		}
		fputs("?>\n", out);
	}
}

/* ---------------------------------------------------------------------
 * XmlWriteStyleSheets
 * Write style sheet header structures into a file
 * ---------------------------------------------------------------------
 */
static void
XmlWriteStyleSheets(XMLSTYLESHEET* sheet, FILE* out)
{
	while (sheet)
	{
		if (sheet->HRef && sheet->Type)
		{
			fputs("<?xml-stylesheet href=\"", out);
			XmlWriteToFile(sheet->HRef, out);
			fputs("\" type=\"", out);
			XmlWriteToFile(sheet->Type, out);
			fputs("\" ", out);

			if (sheet->Title)
			{
				fputs("title=\"", out);
				XmlWriteToFile(sheet->Title, out);
				fputs("\" ", out);
			}
			if (sheet->CharSet)
			{
				fputs("charset=\"", out);
				XmlWriteToFile(sheet->CharSet, out);
				fputs("\" ", out);
			}
			if (sheet->Media)
			{
				fputs("media=\"", out);
				XmlWriteToFile(sheet->Media, out);
				fputs("\" ", out);
			}
			if (sheet->Alternate)
			{
				fputs("alternate=\"", out);
				XmlWriteToFile(sheet->Alternate, out);
				fputs("\" ", out);
			}
			fputs("?>\n", out);
		}
		sheet = (XMLSTYLESHEET*) sheet->Next;
	}
}


/* ---------------------------------------------------------------------
 * XmlWriteObject
 * Write the data (and all child objects) of "ob" to file
 * ---------------------------------------------------------------------
 */
static void 
XmlWriteObject(XMLOBJECT* ob, int level, FILE* out)
{
	XMLATTRIBUTE* attrptr;
	XMLNODE*      nodeptr;
	wchar_t*        pos1;
	wchar_t*        pos2;
	int           total;

	if (level >= 0)
	{
		XmlWriteSpace(level, out);
		fputc('<', out);
		XmlWriteLowcase(ob->Name, out);

		attrptr = ob->FirstAttr;
		while (attrptr)
		{
			fputc(' ', out);
			XmlWriteLowcase(attrptr->Name, out);
			fputs("=\"", out);
			XmlWriteToFile(attrptr->Value, out);
			fputs("\" ", out);
			attrptr = attrptr->Next;
		}

		if (ob->FirstNode)
		{
			fputs(">\n", out);
		}
		else
		{
			fputs("/>\n", out);
			return;
		}
	}

	nodeptr = ob->FirstNode;
	while(nodeptr)
	{
		if (nodeptr->Type == XML_OBJNODE)
		{
			XmlWriteObject(nodeptr->Object,level + 1, out);
		}
		else if (nodeptr->Type == XML_COMMENTNODE)
		{
			fputs("<!-- ", out);
			XmlWriteToFile(nodeptr->Data, out);
			fputs("-->\n", out);
		}
		else
		{
			XmlWriteSpace(level + 1,out);	

			total = level + 1;
			pos1 = pos2 = nodeptr->Data;

			/* find first space */
			while (*pos2 == _T(' '))
			{
				pos2++;
			}  
			pos2 = wcschr(pos2,_T(' '));

			while (pos2)
			{
				int len = pos2 - pos1;

				/* write chunk of data */
				XmlWriteData(pos1,pos2 - pos1,out);
				fputc(' ', out);
				len += 2;

				/* shall we do a line break? */
				total += len;
				if (total > 78)
				{
					fputs("\n", out);
					XmlWriteSpace(level + 1,out);
					total = 0;
				}
	
				/* find next space character */
				pos1 = pos2 + 1;	
				while (*pos2 == _T(' '))
				{
					pos2++;
				}
				pos2 = wcschr(pos2,_T(' '));
			}
			XmlWriteData(pos1, wcslen(pos1), out);
			fputs("\n", out);
		}
		nodeptr = (XMLNODE*) nodeptr->Next;
	}
	if (level >= 0)
	{
		XmlWriteSpace(level,out);
		fputs("</", out);
		XmlWriteLowcase(ob->Name,out);
		fputs(">\n", out);
	}
}


/* ---------------------------------------------------------------------
 * XmlWriteSpace
 * Intend line before data is written, to visualize the hiearachical level
 * ---------------------------------------------------------------------
 */
static void
XmlWriteSpace(int level, FILE* out)
{
	int i;

	for (i = 0; i < level * 2; i++)
	{
		fputc(' ',out);
	}
}

/* ---------------------------------------------------------------------
 * XmlWriteLowcase
 * Write string in low-case letters
 * ---------------------------------------------------------------------
 */
static void
XmlWriteToFile(const wchar_t* text, FILE* out)
{
	mbstate_t state;
	char      buffer[128 + 1];
	int       size = 0;

	memset (&state, 0, sizeof(state));
	
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
 * XmlWriteLowcase
 * Write string in low-case letters
 * ---------------------------------------------------------------------
 */
static void
XmlWriteLowcase(const wchar_t* text, FILE* out)
{
	mbstate_t    state;
	char         buffer[8];
	int          size = 0;
	const wchar_t* p = text;
	
	memset (&state, 0, sizeof(state));

	while (*p != 0)
	{
		wchar_t c = towlower(*p);

		size = wcrtomb(buffer, c, &state);
		if (size > 0)
		{
			fwrite(buffer, 1, size, out);
		}
		p++;
	}
}

/* ---------------------------------------------------------------------
 * XmlWriteData
 * Write data replacing special characters with their entities
 * ---------------------------------------------------------------------
 */
static void
XmlWriteData(const wchar_t* text, int len, FILE* out)
{
	mbstate_t    state;
	int          size = 0;
	char         buffer[8];
	int          index;
	const wchar_t* p = text;
	
	memset (&state, 0, sizeof(state));

	while ((*p != 0) && (len > 0))
	{
		wchar_t c = towlower(*p);

		size = wcrtomb(buffer, c, &state);
		if (size > 0)
		{
			if (((c >= _T('A')) && (c <= _T('Z'))) ||
			    ((c >= _T('a')) && (c <= _T('z'))) ||
			    ((c >= _T('0')) && (c <= _T('9'))))
			{
				fwrite(buffer, 1, size, out);
			}
			else
			{
				index = 0;
				buffer[size] = 0;
				while (EntityTable[index][0] != NULL)
				{
					if (strcmp(buffer, EntityTable[index][1]) == 0)
					{
						fputs(EntityTable[index][0] ,out);
						break;
					}
					index++;
				}
				if (EntityTable[index][0] != NULL)
				{
					fwrite(buffer, 1, size, out);
				}
			}
		}
		p++;
		len--;
	}
}


/* ---------------------------------------------------------------------
 * XmlMatchTag
 * compare a tag's attributes with a given attrspec description
 * increment 'tagidx' if all other attributes (excluding index) match
 * ---------------------------------------------------------------------
 */
static int
XmlMatchTag(XMLOBJECT* xmlobj, const wchar_t* attrspec, int* tagidx)
{
	wchar_t attrname[64 + 1];
	wchar_t attrval[128 + 1];
	int index = 0;
	int result = TRUE;

	attrspec++;
	while ((*attrspec != _T('\0')) && (*attrspec != _T(')')))
	{
		index = 0;
		attrname[0] = 0;
		while (*attrspec == _T(' '))
		{
			attrspec++;
		}
		while ((*attrspec != _T(')')) && (*attrspec != _T('=')) && 
		       (*attrspec != _T('\0')) && (index < 64))
		{
			attrname[index++] = *(attrspec++);
		}
		attrname[index] = 0;

		index = 0;
		attrval[0] = 0;
		if (*attrspec == _T('='))
		{
			attrspec++;
			if (*attrspec == _T('\"'))
			{
				attrspec++;
				while ((*attrspec != _T('"')) && (*attrspec != _T('\0')) && 
				       (index < 128))
				{
					attrval[index++] = *(attrspec++);
				}
				if (*attrspec == _T('"'))
				{
					attrspec++;
				}
			}
			else
			{
				while ((*attrspec != _T(')')) && (*attrspec != _T(',')) && 
				       (*attrspec != _T('\0')) && (index < 128))
				{
					attrval[index++] = *(attrspec++);
				}
			}
			attrval[index] = 0;
		}
		
		if (wcscasecmp(attrname, _T("index")) == 0)
		{
			wchar_t indexattr[32 + 1];
			swprintf(indexattr, 32, _T("%i"), *tagidx);
			if (wcscmp(attrval, indexattr) != 0)
			{
				result = FALSE;
			}
		}
		else
		{
			XMLATTRIBUTE* attr = xmlobj->FirstAttr;
			while (attr)
			{
				if (wcscasecmp(attrname, attr->Name) == 0)
				{
					break;
				}
				attr = (XMLATTRIBUTE*) attr->Next;
			}
			if (!attr)
			{
				return FALSE;
			}
			if (wcscasecmp(attrval, attr->Value) != 0)
			{
				return FALSE;
			}
		}
		if (*attrspec == _T(','))
		{
			attrspec++;
		}
	}
	
	/* all attributes (excluding index) matched the criteria,
	   in this case we increment tagidx */
	(*tagidx)++;

	return result;
}

/* ---------------------------------------------------------------------
 * XmlFindNext
 * descent through the object tree to find the next XML-object that
 * matches the tag name and the criteria given in tagspec
 * ---------------------------------------------------------------------
 */
static XMLOBJECT*
XmlFindNext(XMLOBJECT* xmlobj, const wchar_t* tagspec)
{
	wchar_t tagname[64 + 1];
	int  index = 0;

	tagname[0] = 0;
	while (*tagspec == _T(' '))
	{
		tagspec++;
	}
	while ((*tagspec) && (*tagspec != _T('(')) && (*tagspec != _T(':')) && (index < 64))
	{
		tagname[index++] = *(tagspec++);
	}
	tagname[index] = 0;

	if (xmlobj && (index > 0))
	{
		XMLNODE* searchnode = xmlobj->FirstNode;
		int tagidx = 1;

		while (searchnode)
		{
			if (searchnode->Type == XML_OBJNODE)
			{
				XMLOBJECT* obj = (XMLOBJECT*) searchnode->Object;
				if (obj && (wcscasecmp(obj->Name, tagname) == 0))
				{
					if (*tagspec == _T('('))
					{
						if (XmlMatchTag(obj, tagspec, &tagidx))
						{
							return obj;
						}
					}
					else
					{
						return obj;
					}
				}
			}
			searchnode = (XMLNODE*) searchnode->Next;
		}
	}
	return NULL;
}


