/*----------------------------------------------------------------------------
 *  log.c   - logging funtionality
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: log.c 17656 2009-10-18 18:39:00Z knibo $
 *----------------------------------------------------------------------------
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <ctype.h>

#ifdef __STDC__
#  include <stdarg.h>
#  define VARARG            ...
#  define VA_START(a,b)     va_start (a, b)
#  define VA_END(a)         va_end (a)
#else /* not __STDC__ */
#  include <varargs.h>
#  define VARARG            va_alist
#  define VA_START(a,b)     va_start (a)
#  define VA_END(a)         va_end (a)
#endif /* __STDC__ */

#include "log.h"
#include "str.h"

static FILE *   logfp;
static char *   log_name;
static int      log_opened;
static int      log_level=0;
static int      log_indent_lvl;
static int      indent_output(char * s);
static char *   reformat (char * src, int indent);
static char     printable_buf[32];
static char     output[4096*4];
static char     output2[4096*4];

int no_reformat=0;

void really_open_logfile (char * logfile);
#define check_log do { if (!log_opened && log_name) {    \
                          log_opened = 1;                \
                          really_open_logfile (log_name);\
                       }                                 \
                     } while (0)

static char * char_table[32] = {
"\0",
NULL,
NULL,
NULL,
NULL,
NULL,
NULL,
"\\a",
"\\b",
"\\t",
"\\n",
"\\v",
"\\f",
"\\r",
};

char * log_get_printable (int c)
{
    if (isprint (c))
    {
        printable_buf[0] = c;
        printable_buf[1] = '\0';
    }
    else
    {
        if (char_table[c])
        {
            sprintf(printable_buf, "%s", char_table[c]);
        }
        else
        {
            sprintf(printable_buf, "\\0%o", c);
        }
    }
    return printable_buf;
}

void set_log_level (int level)
{
    log_level = level;
}

void inc_log_indent_level (void)
{
    log_indent_lvl++;
}

void dec_log_indent_level (void)
{
    if (log_indent_lvl > 0)
    {
        log_indent_lvl--;
    }
}

int indent_output(char * s)
{
    int i;
    for (i=0; i<log_indent_lvl; i++, s+=4)
    {
        strcpy (s, "    ");
    }
    return log_indent_lvl * 4;
}

char * reformat (char * src, int indent)
{
    char * tmp;
    int line = 0;
    int first_word;
    int num_indent = 4;

    char * dest = output2;

    if (no_reformat)
    {
        if (indent)
        {
            int c = indent_output (dest);
            dest += c;
        }
        strcpy(dest, src);
        return output2;
    }

    tmp = strchr (src, ':');
    if (tmp && tmp - src < 15)
    {
        num_indent = tmp - src + 2;
    }

    do {
        /* indent text */
        *dest = '\0';
        if (indent)
        {
            int c = indent_output (dest);
            dest += c;
            line = c;
        }
        first_word = 1;
        while (1)
        {
            /* find next word boundary */
            for (tmp=src; *tmp && !isspace (*tmp); tmp++)
                ;
            if (line + tmp-src > 70 && !first_word)
            {
                int i;
                *dest++ = '\n';
                for (i=0; i<num_indent; i++)
                    *dest++ = ' ';

                line = num_indent;
                break;
            }
            first_word = 0;
            line += tmp-src + 1;
            while (src <= tmp)
            {
                *dest++ = *src++;
            }
        }
    } while (*src);
    *dest = '\0';

    return output2;
}

void open_logfile (char * logfile)
{
    log_name = strsave (logfile);
}

void really_open_logfile (char * logfile)
{
    logfp = fopen (logfile, "w");

    if (! logfp)
    {
        log_error ("Error opening log file '%s': %s\n",
                    logfile, strerror (errno));
        abort ();
    }
}

void close_logfile (char * logfile)
{
    if (logfp)
            fclose (logfp);
}

#ifdef __STDC__
void log_lex_fprintf (FILE *file, const char *fmt, VARARG)
#else
void log_lex_fprintf (file, fmt, VARARG)
FILE *          file;
const char *    fmt;
va_dcl
#endif
{
    static char * useless = "--(end of buffer";
    va_list ap;
    char        lex_msg_buf[1024];
    char        msg_buf[1024];
    const char * p;
    char * q;

    if (!strncmp (fmt, useless, strlen(useless)))
    {
        return;
    }

    VA_START (ap, fmt);
    vsprintf (lex_msg_buf, fmt, ap);
    VA_END (ap);

    p = lex_msg_buf;
    q = msg_buf;

    while (*p)
    {
        if (isprint (*p) || !*(p+1))
        {
            *q++=*p++;
            *q = '\0';
        }
        else
        {
            char *n = log_get_printable (*p);
            strcat (q, n);
            q += strlen (n);
            *q = '\0';
            p++;
        }
    }
    *q = '\0';

    q = reformat (msg_buf, 1);
    fprintf (stderr, "%s", q);
    check_log;
    if (logfp)
    {
        fprintf (logfp, "%s", q);
    }
}
#ifdef __STDC__
void log_yacc_fprintf (FILE * file, const char *fmt, VARARG)
#else
void log_yacc_fprintf (file, fmt, VARARG)
FILE *          file;
const char *    fmt;
va_dcl
#endif
{
    va_list ap;
    char * real_output;

    VA_START (ap, fmt);
    vsprintf (output, fmt, ap);
    VA_END (ap);

    real_output = reformat (output, 1);
    fprintf (stderr, "%s", real_output);
    check_log;
    if (logfp)
    {
        fprintf (logfp, "%s", real_output);
    }
}
#ifdef __STDC__
void log_info (int level, const char *fmt, VARARG)
#else
void log_info (level, fmt, VARARG)
int             level;
const char *    fmt;
va_dcl
#endif
{
    va_list ap;
    char * real_output;

    if (log_level & level)
    {
        VA_START (ap, fmt);
        vsprintf (output, fmt, ap);
        VA_END (ap);

        real_output = reformat (output, 1);
        fprintf (stderr, "%s", real_output);
        check_log;
        if (logfp)
        {
            fprintf (logfp, "%s", real_output);
        }
    }
}
#ifdef __STDC__
void log_error (const char *fmt, VARARG)
#else
void log_error (fmt, VARARG)
const char *    fmt;
va_dcl
#endif
{
    va_list ap;
    char * real_output;

    VA_START (ap, fmt);
    vsprintf (output, fmt, ap);
    VA_END (ap);

    real_output = reformat (output, 0);
    fprintf (stderr, "%s", real_output);
    check_log;
    if (logfp)
    {
        fprintf (logfp, "%s", real_output);
    }
}

void
#ifdef __STDC__
fatal_exit (const char *fmt, VARARG)
#else
fatal_exit (fmt, VARARG)
const char *    fmt;
va_dcl
#endif
{
    va_list ap;
    char * real_output;

    if (fmt)
    {
        VA_START (ap, fmt);
        vsprintf (output, fmt, ap);
        VA_END (ap);

        real_output = reformat (output, 0);
        fprintf (stderr, "%s", real_output);
        check_log;
        if (logfp)
        {
            fprintf (logfp, "%s", real_output);
        }
    }

    if (logfp)
    {
        fclose (logfp);
    }
    if (log_level)
    {
        fprintf (stderr, "creating core dump (or stack trace under windows) "
                 "for debugging purposes...\n");
        abort ();
    }
    else
    {
        exit (1);
    }
}
