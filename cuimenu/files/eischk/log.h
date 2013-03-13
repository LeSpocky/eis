/*----------------------------------------------------------------------------
 *  log.h   - logging funtionality
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: log.h 17656 2009-10-18 18:39:00Z knibo $
 *----------------------------------------------------------------------------
 */
#ifndef LOG_H
#define LOG_H

#include <stdio.h>

#define INFO            1
#define VERBOSE         2
#define ZIPLIST         4
#define ZIPLIST_SKIP    8
#define T_BUILD         0x10
#define T_EXEC          0x20
#define VAR             0x40
#define SET_VAR         0x80
#define ZIPLIST_REGEXP  0x100
#define SCAN            0x200
#define LOG_REGEXP      0x400
#define LOG_EXP         0x800
#define LOG_DEP         0x1000

extern int no_reformat;

extern void    open_logfile (char * logfile);
extern void    close_logfile (char * fname);
extern void    set_log_level (int level);
extern void    inc_log_indent_level (void);
extern void    dec_log_indent_level (void);

char *          log_get_printable (int c);

#ifdef __GNUC__
extern void    log_info (int level, const char *fmt, ...) __attribute__ ((format (printf, 2, 3)));
extern void    log_error (const char *fmt, ...) __attribute__ ((format (printf, 1, 2)));
extern void    fatal_exit (const char *fmt, ...) __attribute__ ((format (printf, 1, 2))) __attribute__ ((noreturn));
extern void    log_lex_fprintf (FILE *, const char *fmt, ...) __attribute__ ((format (printf, 2, 3)));
extern void    log_yacc_fprintf (FILE *, const char *fmt, ...) __attribute__ ((format (printf, 2, 3)));
#else
extern void    log_info (int level, char *fmt, ...);
extern void    log_error (char *fmt, ...);
extern void    fatal_exit (char *fmt, ...);
extern void    log_lex_fprintf (FILE *, char *fmt, ...);
extern void    log_yacc_fprintf (FILE *, char *fmt, ...);
#endif

#endif
