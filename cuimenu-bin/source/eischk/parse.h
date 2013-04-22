#include <stdio.h>

extern int yy_flex_debug;
extern int yydebug;
extern int yyline;

#define CMP_EQUAL    0
#define CMP_LESS    -1
#define CMP_GREATER  1

int     str_strmatch (char * value, char * expr, char * package, int line);
int     val_numcmp (char * var, char * content, char * package, int line);
int     val_vercmp (char * var, char * version, char * package, int line);

char *  parse_get_variable (char * name, char * package, int line);
char *  parse_rewrite_string (char * name, char * package, int line);

void    parse_warning (char * warning, char * package, int line);
void    parse_error (char * warning, char * package, int line);
void    parse_fatal_error (char * warning, char * package, int line);
void    parse_add_to_opt (char * file, char * options, char * package, int line);
void    parse_stat (char * file, char * id, char * package, int line);
void    parse_fgrep (char * file, char * search, char * package, int line);
void    parse_crypt (char * id, char * package, int line);
void    parse_provides (char * id, char * version, char * package, int line);
void    parse_depends (char * id, char * version, char * package,
                       int regexp, char * file, int line);
int     parse_copy_pending (char * name);

char *  parse_get_current_package (void);
char *  parse_get_current_file (void);
int     execute_all_extended_checks (char * check_dir);

int     get_file_name (char * fname, char * dir, char * name,
                       char * ext);

int     yyparse (void);
int     add_to_zip_list (char *, char *, char *, char *, char *, int);

void    utod (void);
void    dtou (void);
