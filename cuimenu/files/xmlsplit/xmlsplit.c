//-------------------------------------------------------------------------
//  xmlsplit.c - split xml tag
//
//  Creation:     06.12.2004  max
//  Last Update:  $Id: xmlsplit.c 5777 2006-02-19 19:33:11Z max $
//
//  Copyright (c) 2001-2004 Frank Meyer <frank@eisfair.org>
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//-------------------------------------------------------------------------

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#define BOOL int
#define TRUE (-1)
#define FALSE 0

#define MAX_TAGOPTIONS 32

static char *lpszVersion = "1.0";
static char *lpszBuild   = "$Revision: 5777 $";


const void usage(char *lpszProgram)
{
    char *p = strrchr(lpszProgram, '/');
    if (p) { p++; }
    else { p = lpszProgram; }

    printf("Usage: %s [options] xml-tag tag-name [tag-option] ...\n", p);
    printf("\n");
    printf("Options:\n");
    printf("\n");
    printf("  -h, --help                  Print this help message and exit.\n");
    printf("  -v, --version               Print the version number of %s and exit.\n", p);
    printf("\n");
}

const void version(char *lpszProgram)
{
    char *p = strrchr(lpszProgram, '/');
    if (p) { p++; }
    else { p = lpszProgram; }

    printf("%s %s (Build %s)\n", p, lpszVersion, lpszBuild);
}

char *strcasestr(char *a, char *b)
{
    size_t l;
    char f[3];

    snprintf(f, sizeof(f), "%c%c", tolower(*b), toupper(*b));
    for (l = strcspn(a, f); l != strlen(a); l += strcspn(a + l + 1, f) + 1)
        if (strncasecmp(a + l, b, strlen(b)) == 0)
            return(a + l);
    return(NULL);
}

int main(int argc, char **argv)
{
    // parse command line arguments
    char *lpszTag      = NULL;
    char *lpszBuffer   = NULL;
    char *lpszTemp     = NULL;
    char **lpszInput;
    char *lpszOutput[MAX_TAGOPTIONS];
    char szQuote = '\0';

    int retval = EXIT_SUCCESS;
    int argn;
    int i;

    memset(lpszOutput, 0x00, sizeof(lpszOutput));

    for (argn = 1; argn < argc; argn++)
    {
        if (argv==NULL || argv[argn]==NULL)
        {
            printf("fatal error.. exiting.\n");
            return 255;
        }

        if (strcmp(argv[argn], "-h")==0 || strcmp(argv[argn], "--help")==0)
        {
            usage(argv[0]);
            return 0;
        }
        if (strcmp(argv[argn], "-v")==0 || strcmp(argv[argn], "--version")==0)
        {
            version(argv[0]);
            return 0;
        }

        break;
    }
    if (argn+2 > argc)
    {
        return EXIT_FAILURE;
    }

    // Init Variables
    lpszInput  = argv;
    lpszTag    = lpszInput[0+argn];
    lpszBuffer = malloc(strlen(lpszTag)+1);

    // remove leading blanks
    lpszTag = lpszTag + strspn(lpszTag, "\t ");

    // check open tag
    strcpy(lpszBuffer, "<");
    strcpy(lpszBuffer+1, lpszInput[1+argn]);
    if (strncasecmp(lpszTag, lpszBuffer, strlen(lpszBuffer)) == 0)
    {
        lpszTag += strlen(lpszBuffer);
    }
    else
    {
        retval = EXIT_FAILURE;
        goto EXCEPTION_EXIT;
    }

    // check tag options
    lpszTag  = lpszTag + strspn(lpszTag, "\t ");
    while (*lpszTag != '>')
    {
        lpszTemp = strpbrk(lpszTag, "\t =>");
        if (lpszTemp == NULL)
        {
            retval = EXIT_FAILURE;
            goto EXCEPTION_EXIT;
        }

        i = lpszTemp-lpszTag;
        strncpy(lpszBuffer, lpszTag, i);
        lpszBuffer[i] = '\0';
        lpszTag += i;

        if (strncmp(lpszTag, "=\"", 2) == 0 || strncmp(lpszTag, "='", 2) == 0)
        {
            szQuote = lpszTag[1];

            lpszTag += 2;
            lpszTemp = strchr(lpszTag, szQuote);

            if (lpszTemp == NULL)
            {
                retval = EXIT_FAILURE;
                goto EXCEPTION_EXIT;
            }

            for (i=2; (i<MAX_TAGOPTIONS) && (i+argn < argc); i++)
            {
                if (strcasecmp(lpszBuffer, lpszInput[i+argn]) == 0)
                {
                    lpszOutput[i] = malloc(lpszTemp-lpszTag+1);
                    strncpy(lpszOutput[i], lpszTag, lpszTemp-lpszTag);
                    *(lpszOutput[i]-lpszTag+lpszTemp) = '\0';
                    break;
                }
            }

            lpszTag = lpszTemp + 1;
        }
        else if (*lpszTag == ' ' || *lpszTag == '>')
        {
            for (i=2; (i<MAX_TAGOPTIONS) && (i+argn < argc); i++)
            {
                if (strcasecmp(lpszBuffer, lpszInput[i+argn]) == 0)
                {
                    lpszOutput[i] = strdup("true");
                    break;
                }
            }
        }
        else
        {
            retval = EXIT_FAILURE;
            goto EXCEPTION_EXIT;
        }

        lpszTag  = lpszTag + strspn(lpszTag, "\t ");
    }

    // skip >
    lpszTag++;

    // get tag value & check close tag
    strcpy(lpszBuffer, "</");
    strcpy(lpszBuffer+2, lpszInput[1+argn]);
    strcpy(lpszBuffer+strlen(lpszBuffer), ">");
    lpszTemp = strcasestr(lpszTag, lpszBuffer);
    if (lpszTemp != NULL)
    {
        lpszOutput[1] = malloc(lpszTemp-lpszTag+1);
        strncpy(lpszOutput[1], lpszTag, lpszTemp - lpszTag);
        lpszTag = lpszTemp + strlen(lpszBuffer);
    }
    else
    {
        retval = EXIT_FAILURE;
        goto EXCEPTION_EXIT;
    }

    // check blanks
    lpszTag = lpszTag + strspn(lpszTag, "\t ");
    if (*lpszTag != 0x00)
    {
        retval = EXIT_FAILURE;
        goto EXCEPTION_EXIT;
    }


//    printf("%s\n", lpszOutput[1]);
//    printf("Returns: %d\n", retval);
//    printf("%d\n", setenv("XMLSET", "title", TRUE));
//    printf("%s\n", getenv("XMLSET"));
//    unsetenv();
    // output
    if (strchr(lpszOutput[1], '"')) szQuote='\'';
    else szQuote='"';
    printf("XMLSPLIT_TAG=%c%s%c", szQuote, lpszOutput[1], szQuote);
    for (i=2; (i<MAX_TAGOPTIONS) && (i+argn < argc); i++)
    {
        printf(" XMLSPLIT_ATTR_%s=", lpszInput[i+argn]);
        if (lpszOutput[i])
        {
            if (strchr(lpszOutput[i], '"')) szQuote='\'';
            else szQuote='"';
            printf("%c%s%c", szQuote, lpszOutput[i], szQuote);
        }
    }

EXCEPTION_EXIT:

    // free all dynamical allocated variables
    if (lpszBuffer) { free (lpszBuffer); }

    for (i=0; i<MAX_TAGOPTIONS; i++)
    {
        if (lpszOutput[i])
        {
            free (lpszOutput[i]);
        }
    }
    printf("\n");

    return retval;
}

