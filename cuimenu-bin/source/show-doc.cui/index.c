/* ---------------------------------------------------------------------
 * File: index.c
 * (simple table of contents)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: index.c 30935 2012-05-27 14:32:42Z dv $
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

#include "index.h"


/* ---------------------------------------------------------------------
 * IndexReadFile
 * Read an index file
 * ---------------------------------------------------------------------
 */
INDEX* 
IndexReadFile(const TCHAR* filename, ErrorCallback errout, void* instance)
{
	INDEX* index = (INDEX*) malloc(sizeof(INDEX));
	if (index)
	{
		XMLFILE*  xml = XmlCreate(filename);

		index->FirstEntry = NULL;
		index->LastEntry  = NULL;
		index->Title      = NULL;

		if (xml)
		{
			XmlSetErrorHook(xml, errout, instance);

			if (XmlReadFile(xml))
			{
				XMLOBJECT* xmlobj = XmlSearch(xml, _T("index"));
				if (xmlobj)
				{
					XMLATTRIBUTE* title = XmlGetAttribute(xmlobj, _T("title"));
					XMLNODE*      node = xmlobj->FirstNode;
					
					if (title)
					{
						index->Title = tcsdup(title->Value);
					}
					while (node)
					{
						if (node->Type == XML_OBJNODE)
						{
							XMLOBJECT* entryobj = (XMLOBJECT*) node->Object;
							if (tcscasecmp(entryobj->Name, _T("entry")) == 0)
							{
								XMLATTRIBUTE* lineattr = XmlGetAttribute(entryobj, _T("line"));
								XMLATTRIBUTE* levelattr = XmlGetAttribute(entryobj, _T("level"));
								if (entryobj->FirstNode && (entryobj->FirstNode->Type == XML_DATANODE))
								{
									INDEXENTRY* newentry = (INDEXENTRY*) malloc(sizeof(INDEXENTRY));
									if (newentry)
									{
										if (entryobj->FirstNode->Data)
										{
											newentry->Description = tcsdup(entryobj->FirstNode->Data);
										}
										else
										{
											newentry->Description = tcsdup(_T(""));
										}
										if (lineattr && lineattr->Value)
										{
											stscanf(lineattr->Value, _T("%ld"), &newentry->LineNumber);
										}
										else
										{
											newentry->LineNumber = 1;
										}
										if (levelattr && levelattr->Value)
										{
											stscanf(levelattr->Value, _T("%d"), &newentry->Level);
										}
										else
										{
											newentry->Level = 1;
										}
										newentry->FilePosition = -1;
										newentry->Next = NULL;

										if (index->LastEntry)
										{
											newentry->Previous = index->LastEntry;
											index->LastEntry->Next = newentry;
										}
										else
										{
											newentry->Previous = NULL;
											index->FirstEntry = newentry;
										}
										index->LastEntry = newentry;
									}
								}
							}
						}
						node = (XMLNODE*) node->Next;
					}
				}
			}
			XmlDelete(xml);
		}
	}
	return index;
}


/* ---------------------------------------------------------------------
 * IndexDelete
 * Delete index data structures
 * ---------------------------------------------------------------------
 */
void 
IndexDelete(INDEX* index)
{
	INDEXENTRY* entry = index->FirstEntry;
	while (entry)
	{
		index->FirstEntry = (INDEXENTRY*) entry->Next;
		free(entry->Description);
		free(entry);
		entry = (INDEXENTRY*) index->FirstEntry;
	}
	if (index->Title)
	{
		free(index->Title);
	}
	free(index);
}

