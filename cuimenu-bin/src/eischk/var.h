/*----------------------------------------------------------------------------
 *  var.h   - some declarations
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: var.h 17656 2009-10-18 18:39:00Z knibo $
 *----------------------------------------------------------------------------
 */
#include <sys/types.h>
#include <regex.h>

#define MAX_FILENAMES           1024                /* max. 1024 filenames  */
#define MAX_VARIABLES           2048                /* max. 1024 variables  */
#define VAR_SIZE                128                 /* variable size        */

#define TYPE_UNKNOWN            0
#define TYPE_NUMERIC            1

#define OK                  0
#define ERR                 (-1)

int regexp_chkvar (char * name, char * value,
                   char * regexp_name, char * user_regexp);
int regexp_user (char * value, char * expr, size_t nmatch, regmatch_t * pmatch,
                 int modify_expr, char * file, int line);
int regexp_exists (char * name);
int regexp_find_type (char * regexp_name);
void regexp_init (void);
int regexp_read_file (char * expr_file);
int regexp_get_expr (char *name, regex_t  **preg, char ** err_msg);
int check_for_dangeling_extensions (void);

void free_variables (void);

void compile_one_expression (int num);
int add_expression (char * name, char * expr, char * error_msg,
                    int extend_expr,
                    char *expr_file, int line);
int extend_expression (char * name, char * expr, char * error_msg,
                       char *expr_file, int line);

int     mark_var_requested (char * name);
int     mark_var_copied (char * name);
int     mark_var_tagged (char * name);
int     mark_var_checked (char * name);
int     mark_var_numeric (char * name);
int     mark_var_generated (char * name);
int     mark_var_provide (char * name);

int     is_var_tagged (char * name);
int     is_var_checked (char * name);
int     is_var_numeric (char * name);
int     is_var_weak (char * name);
int     is_var_generated (char * name);
int     is_var_copy_pending (char * name);
int     is_var_unique (char * name, char * file, int line);
int     is_var_provide (char * name);
int     is_var_enabled (char * name, char * opt_var, int neg);

void    var_add_weak_declaration (char * package, char * name, char * value,
                                  char * comment, int type, char * file,
                                  int line, int log_level);

extern char *   strsave (char *);
int             check_variables (void);
int             dump_variables (char *fname, char *fname_full_cfg);
extern char *   get_variable (char *);
extern char *   get_variable_package (char * name);
extern char *   get_variable_comment (char *);
extern void     get_variable_src (char * name, char ** src, int * line);

extern int      chkvar (char *, char *, char *, char *, int, int, int, char *);
extern int      chkvar_idx (char *, char *, char *, char *, char *, char *,
                            int, int, int);
struct iter_t;
struct iter_t * init_set_var_iteration (char * set_var, char * opt_var, int neg);
char *          get_next_set_var (struct iter_t * iter, int * enabled);
int             get_last_index (struct iter_t * iter);
void            end_set_var_iteration (struct iter_t * iter);

extern void     var_init (void);
extern int      read_config_file (char *, char *, int def);
extern int      set_variable_content (char *, char *);
extern int      set_variable (char * package, char * name,
                              char * content, char * comment,
                              int supersede, char * config_file,
                              int dq, int line);
