/* ---------------------------------------------------------------------
 * File: filestools.c
 * (list-files for the EisFair-Server project)
 *
 * Copyright (C) 2004
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "global.h"
#include "mainwin.h"

/* ---------------------------------------------------------------------
* ToolsPmatch( **expression, **text)  function for placeholder
*****************************************************************
*  0  if *expression does not match *text
*  1  if *expression matches *text
*  ?  1 Zeichen
*  *  beliebige Zeichenanzahl
*  [0-9] Zeichenmenge
*  ---------------------------------------------------------------------
*/
int set(char **express, char **text);
int asterisk(char **express, char **text);

int
ToolsPmatch(char *express, char *text)
{
    int nret = 1;

    for (; ('\0' != *express) && (1 == nret) && ('\0' != *text); express++)
    {
        switch (*express)
        {
            case '[':
                express++;
                nret = set (&express, &text);
                break;
            case '?':
                text++;
                break;
            case '*':
                nret = asterisk (&express, &text);
                express--;
                break;
            default:
                nret = (int) (*express == *text);
                text++;
        }
    }   while ((*express == '*') && (1 == nret))
    express++;
    return (int) ((1 == nret) && ('\0' == *text) && ('\0' == *express));
}

int
set(char **express, char **text)
{
    int nret = 0;
    int negation = 0;
    int at_beginning = 1;

    if ('!' == **express)
    {
        negation = 1;
        (*express)++;
    }
    while ( (**express != '\0') && ((']' != **express) || (1 == at_beginning)) )
    {
        if (0 == nret)
        {
            if (('-' == **express)
              && ((*(*express - 1)) < (*(*express + 1)))
              && (']' != *(*express + 1))
              && (0 == at_beginning))
            {
                if (((**text) >= (*(*express - 1)))
                  && ((**text) <= (*(*express + 1))))
                {
                    nret = 1;
                    (*express)++;
                }
            }
            else if ((**express) == (**text))
                nret = 1;
        }
        (*express)++;
        at_beginning = 0;
    }
    if (1 == negation)
        nret = 1 - nret;
    if (1 == nret)
        (*text)++;

    return (nret);
}

int
asterisk(char **express, char **text)
{
    int nret = 1;

    (*express)++;
    while (('\0' != (**text)) && (('?' == **express) || ('*' == **express)))
    {
        if ('?' == **express)
            (*text)++;
        (*express)++;
    }
    while ('*' == (**express))
        (*express)++;

    if (('\0' == (**text)) && ('\0' != (**express)))
        return (nret = 0);
    if (('\0' == (**text)) && ('\0' == (**express)))
        return (nret = 1);
    else
    {
        if (0 == ToolsPmatch(*express, (*text)))
        {
            do
            {
                (*text)++;
                while (((**express) != (**text)) && ('['  != (**express))  && ('\0' != (**text)))
                    (*text)++;
            }
            while ((('\0' != **text))?
            (0 == ToolsPmatch(*express, (*text)))
                : (0 != (nret = 0)));
        }
        if (('\0' == **text) && ('\0' == **express))
             nret = 1;
        return (nret);
    }
}



/****************************************************************
* safe_copy()                                                   *
* create var with value                                         *
*****************************************************************/
int
safe_copy( char **dest, const char *source, int nsize)
{
    if (( *dest=(char *)malloc( nsize + 1 ))==NULL)
    {
        printf( "Error: Not enough memory!\n" );
        return 0;
    }
    memset( *dest, 0, sizeof( *dest ) );
    strncat(*dest, source, nsize );
    return nsize;
}


/* ---------------------------------------------------------------------
 * ToolsGetBasename
 * Get the basename of 'name'.
 * ---------------------------------------------------------------------
 */
const char*
ToolsGetBasename(const char* name)
{
    const char* chr = strrchr(name,'/');

    if (!chr)
    {
        chr = name;
    }
    else
    {
        chr++;
    }
    return chr;
}


/* ---------------------------------------------------------------------
 * ToolsGetDirname
 * Get the dirname of 'name'.
 * ---------------------------------------------------------------------
 */
const char*
ToolsGetDirname(const char* name)
{
    char *s = strdup(name);
    char *f;

    f = s + strlen(s) - 1;
    while(f > s && *f == '/')
        f--;
    *++f = 0;

    for(; f >= s; f--)
        if (*f == '/')
        {
            f++;
            break;
        }

    if(f < s)
    {
            *s = '.';
            s[1] = 0;
    }
    else
    {
        --f;
        while(f > s && *f == '/')
            f--;
        f[1] = 0;
    }
    return (s);
}


/* ---------------------------------------------------------------------
 * FileExists
 * Test if file 'filename' exists and can be opened in read mode
 * ---------------------------------------------------------------------
 */
int
ToolsFileExists(const char* filename)
{
    FILE* in = fopen(filename,"rt");
    if (in)
    {
        fclose(in);
        return TRUE;
    }
    return FALSE;
}


/* ---------------------------------------------------------------------
 * ToolsCreateFile
 * ---------------------------------------------------------------------
 */
int
ToolsCreateFile( char* filename, char* sdata )
{
    FILE* out;
    out = fopen(filename,"wt");
    if (out)
    {
        fprintf(out,"%s\n",sdata);
        fclose(out);
    }
    return TRUE;
}


/* ---------------------------------------------------------------------
 * ToolsAppendFile
 * ---------------------------------------------------------------------
 */
int
ToolsAppendFile( char* filename, char* sdata )
{
    FILE* out;
    out = fopen(filename,"a+t");
    if (out)
    {
        fprintf(out,"%s\n",sdata);
        fclose(out);
    }
    return TRUE;
}


/* ---------------------------------------------------------------------
 * ToolStrCat
 * Internal strcat
 * ---------------------------------------------------------------------
 */
char*
ToolStrCat(char* pstr, char* pstr2)
{
    char* result = NULL;
    int size;
    if((pstr != NULL) && (pstr2 != NULL))
    {
        size = strlen(pstr) + strlen(pstr2) + 1;
        if(size > 1)
        {
            result = malloc(size);
            if(result != NULL)
            {
                result[0] = '\0';
                result = strcat(result, pstr);
                result = strcat(result, pstr2);
                result[size-1] = '\0';
            }
        }
    }
    return result;
}
