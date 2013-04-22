/*----------------------------------------------------------------------------
 *  check.h   - some declarations
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: check.h 17656 2009-10-18 18:39:00Z knibo $
 *----------------------------------------------------------------------------
 */

#define FATAL_ERR           (-2)

#define CHECK_USER_RE           -1                  /* user supplied regular expression */

#define CHECK_NON_OPTIONAL      0
#define CHECK_OPTIONAL          1
#define CHECK_REALLY_OPTIONAL   2
#define CHECK_AUTO              4

extern void     check_init (void);
extern int      read_check_file (char *, char *);
extern int      get_variable_dimension (char *);
extern char *   get_set_var_n (char *);
extern char *   check_get_var_n (char * var);
extern char *   check_get_opt_var (char * var);
extern int      check_var_defined (char * var);
extern int      check_var_numeric (char * var);
extern int      check_var_optional (char * var);
extern int      check_var_really_optional (char * var);
extern int      check_var_optional_state (char * var);
extern int      check_var_n_auto (char * var);
extern int      check_var_weak (char * var);
extern int      check_all_variables (void);
void            free_check_variables (void);
void            check_add_weak_declaration (char * package, char * name,
                                            char * value, char ** var_n,
                                            char * file, int line,
                                            int log_level);

extern char *   packages[];
extern int      n_packages;
