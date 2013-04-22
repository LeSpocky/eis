#define _XOPEN_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include "crypt.h"
#include "var.h"
#include "log.h"
#include "str.h"
#include "check.h"
#include "parse.h"
#include "tree.h"
#include "options.h"

static int      error=OK;
static int      final_pass = 0;
static int      parse_pass = 0;
static int      package_provider_added = 0;
static char *   parse_current_package;
static char *   parse_current_file;
static char     fli4l_version_tag[20];
static int      get_ver_num (char * ver, char * file, int line);
void            yyrestart (FILE * fp);
static char     var_buf[VAR_SIZE+1];

static int      parse_get_error (void);
static void     parse_set_current (char * pkg, char * file);
static int      parse_check_file (char * name, char * check_dir);

static char *   parse_get_variable_package (char * name,
                                            char * package, int line);
static char *   parse_get_variable_comment (char * name,
                                            char * package, int line);

extern FILE * yyin;

char *
parse_get_variable (char * name, char * package, int line)
{
    char * content;

    content = get_variable (convert_to_upper (name));
    if (!content)
    {
        fatal_exit ("unknown variable '%s' in %s, line %d\n",
                    name, package, line);
    }
    return content;
}
char *
parse_get_variable_package (char * name, char * package, int line)
{
    char * content;

    content = get_variable_package (convert_to_upper (name));
    if (!content)
    {
        fatal_exit ("unknown variable '%s' in %s, line %d\n",
                    name, package, line);
    }
    return content;
}
char *
parse_get_variable_comment (char * name, char * package, int line)
{
    char * content;

    content = get_variable_comment (convert_to_upper (name));
    if (!content)
    {
        fatal_exit ("unknown variable '%s' in %s, line %d\n",
                    name, package, line);
    }
    return content;
}

#define PMAX_MATCH 20
int
str_strmatch (char * value, char * expr, char * package, int line)
{
    int res;
    regmatch_t match[PMAX_MATCH];
    char * match_var_n = "MATCH_N";
    char * match_set_var = "MATCH_%";
    char match_var[10];
    char num[10];

    if (!check_var_defined (match_set_var))
    {
        check_add_weak_declaration ("internal", match_set_var, "0",
                                    0, package, line, T_EXEC);

    }
    else
    {
        if (set_variable_content (match_var_n, "0") != OK)
        {
            fatal_exit ("(%s:%d) unexpected error while setting value of %s\n",
                        __FILE__, __LINE__, match_var_n);
        }
    }
    res = regexp_user (value, expr, PMAX_MATCH, match, 0, package, line);
    log_info (T_EXEC, "checking regular expression '%s' against value '%s', "
              "res = %d\n",
              expr, value, res);
    if (!res)
    {
        int i;

        for (i=1; i<PMAX_MATCH && match[i].rm_so != -1; i++)
        {
            char * end = value+match[i].rm_eo;
            char tmp = *end;
            *end = '\0';

            sprintf (match_var, "MATCH_%d", i);
            sprintf (num, "%d", i);
            var_add_weak_declaration ("internal variable - match_%",
                                      match_var, value+match[i].rm_so,
                                      num, TYPE_UNKNOWN,
                                      package, line, T_EXEC);
            *end = tmp;
        }
        set_variable_content (match_var_n, num);
        return 1;
    }
    if (res != FATAL_ERR)
    {
        return 0;
    }
    fatal_exit ("wrong regular expression '%s' "
                "in %s, line %d, terminating\n",
                expr, package, line);
}

int val_numcmp (char * val, char * num, char * file, int line)
{
    unsigned long x, y;

    log_info (T_EXEC, "numcmp ('%s' rel %s') ?\n", val, num);

    x = convert_to_long (val, file, line);
    y = convert_to_long (num, file, line);

    if (x==y)
    {
        return CMP_EQUAL;
    }
    else if (x<y)
    {
        return CMP_LESS;
    }
    else
    {
        return CMP_GREATER;
    }
}

int get_ver_num (char * ver, char * file, int line)
{
    int ver_major, ver_minor;
    unsigned long sub = 0;

    if (!ver)
    {
        fatal_exit ("%s %d: Null pointer passed to get_ver_num\n",
                    __FILE__, __LINE__);
    }
    if (strlen (ver) < 3)
    {
        fatal_exit ("%s %d: Short version passed to get_ver_num\n",
                    __FILE__, __LINE__);
    }

    ver_major = ver[0]-'0';
    ver_minor = ver[2]-'0';

    if (ver[3] != '\0')
    {
        sub = convert_to_long (&ver[4], file, line);
    }
    return sub + ver_minor*1000 + ver_major*10000 ;
}
int val_vercmp (char * val, char * version, char * file, int line)
{
    int x, y;

    log_info (T_EXEC, "vercmp ('%s'=='%s') ?\n", val, version);

    x = get_ver_num (val, file, line);
    y = get_ver_num (version, file, line);

    if (x==y)
    {
        return CMP_EQUAL;
    }
    else if (x<y)
    {
        return CMP_LESS;
    }
    else
    {
        return CMP_GREATER;
    }
}

char *
parse_rewrite_string (char * msg, char * package, int line)
{
#define MSG_SIZE 6144
    char msg_buf[MSG_SIZE];
    char *p=msg_buf;

    while (*msg)
    {
        switch (*msg)
        {
        case '$':
        case '%':
        case '@':
            if (isalpha (*(msg+1)) || (*(msg+1) == '{'))
            {
                /* get variable name */
                char *var = var_buf;
                char prefix = *msg++;

                if (*msg == '{')
                {
                    msg++;
                    while ((isalnum (*msg) || *msg == '_') && *msg != '}')
                    {
                        *var++ = *msg++;
                    }
                    msg++;
                }
                else
                {
                    while (isalnum (*msg) || *msg == '_')
                    {
                        *var++ = *msg++;
                    }
                }
                *var = '\0';
                if (strlen (var_buf) >= VAR_SIZE)
                {
                    fatal_exit ("%s %d: buffer overflow,"
                                " variable name too long\n",
                                __FILE__, __LINE__);
                }

                switch (prefix)
                {
                case '$':
                    var = parse_get_variable (var_buf, package, line);
                    break;
                case '%':
                    var = parse_get_variable_package (var_buf, package, line);
                    break;
                case '@':
                    var = parse_get_variable_comment (var_buf, package, line);
                    break;
                }
                /* append to msg text */
                *p = '\0';
                strcat (msg_buf, var);
                p += strlen (var);

                break;
            }
            else
            {
                switch (*(msg+1))
                {
                case '$':
                case '%':
                case '@':
                    msg++;
                }
                /* fall through */
            }
        default:
            *p++ = *msg++;
            break;
        }
    }
    *p = '\0';
    if (strlen (msg_buf) >= MSG_SIZE)
    {
        fatal_exit ("%s %d: buffer overflow, msg too long\n",
                    __FILE__, __LINE__);
    }
    return strsave (msg_buf);
}

void parse_warning (char * warning, char * package, int line)
{
    char * p;
    if (!final_pass)
    {
        return;
    }
    p = parse_rewrite_string (warning, package, line);
    log_error ("Warning: %s\n", p);
    free (p);

}
void parse_error (char * warning, char * package, int line)
{
    char * p;
    if (!final_pass)
    {
        return;
    }
    p = parse_rewrite_string (warning, package, line);
    log_error ("Error: %s\n", p);
    free (p);
    error = 1;
}

void parse_fatal_error (char * warning, char * package, int line)
{
    char * p;

    p = parse_rewrite_string (warning, package, line);
    log_error ("Fatal Error: %s\n", p);
    free (p);
    fatal_exit ("fatal error, aborting...\n");;
}

void parse_add_to_opt (char * file, char * options, char * package, int line)
{
    if (!final_pass)
    {
        return;
    }
    if (add_to_zip_list ("BASE", "yes", file,
                         options ? parse_rewrite_string(options, package, line) : "",
                         package, line))
        error = 1;
}
void parse_crypt (char * id, char * package, int line)
{
    char * key;
    char * crypted_passwd;
    static char salt[3];
    char rndChar[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./";

    if (!final_pass)
    {
        return;
    }

    key = parse_get_variable (id, package, line);
    salt[2]=salt[0];
    salt[0]=rndChar[(int) (time ((time_t *) NULL) + salt[1]) % 64];
    salt[1]=rndChar[(int) ((time ((time_t *) NULL) / 64) + salt[2] ) % 64];
    salt[2]=0;
    crypted_passwd = (char *) crypt_ (key, salt);
    set_variable_content (id, crypted_passwd);
}
void parse_stat (char * file, char * id, char * package, int line)
{
    char * p;
    char * end;
    struct stat stat_buf;
    char buf[128];

    p = parse_rewrite_string (file, package, line);
    log_info (T_EXEC, "executing stat on %s, results go to %s_*\n",
              p, id);
    strcpy (var_buf, id);
    if (stat (p, &stat_buf))
    {
        strcat (var_buf, "_RES");
        var_add_weak_declaration (package, var_buf,
                                  strsave (strerror (errno)), NULL,
                                  TYPE_UNKNOWN, package, line, T_EXEC);
    }
    else
    {
        end = var_buf + strlen (var_buf);
        strcpy (end, "_RES");
        var_add_weak_declaration (package, var_buf,
                                  strsave ("OK"), NULL, TYPE_UNKNOWN,
                                  package, line, T_EXEC);
        sprintf (buf, "%ld", (unsigned long)stat_buf.st_size);
        strcpy (end, "_SIZE");
        var_add_weak_declaration (package, var_buf,
                                  strsave (buf), NULL, TYPE_NUMERIC,
                                  package, line, T_EXEC);
    }
    free (p);
}
void parse_fgrep (char * file, char * _expr, char * package, int line)
{
    char * p;
    char * expr;
    int res;
    char * match_var_n = "FGREP_MATCH_N";
    char * match_set_var = "FGREP_MATCH_%";
    char match_var[25];
    char num[10];
    FILE *fh;

    p = parse_rewrite_string (file, package, line);
    expr = parse_rewrite_string (_expr, package, line);

    log_info (T_EXEC, "checking regular expression '%s' against file '%s'\n", expr, p);

    if (!check_var_defined (match_set_var))
    {
        check_add_weak_declaration ("internal", match_set_var, "0",
                                    0, package, line, T_EXEC);

    }
    else
    {
        if (set_variable_content (match_var_n, "0") != OK)
        {
            fatal_exit ("(%s:%d) unexpected error while setting value of %s\n",
                        __FILE__, __LINE__, match_var_n);
        }
    }

    fh = fopen(p, "r");
    if(NULL != fh)
      {
        char buff[1024];
        int matches = 0;

        while(NULL != fgets(buff, sizeof(buff), fh))
          {
            regmatch_t match[PMAX_MATCH];
            int len;

            len = strlen(buff);
            if(len > 1)
              len--;
            if(buff[len] == '\n' || buff[len] == '\r')
              buff[len] = '\0';
            if(len > 1)
              len--;
            if(buff[len] == '\n' || buff[len] == '\r')
              buff[len] = '\0';

            res = regexp_user (buff, expr, PMAX_MATCH, match, 0, package, line);
            if (0 == res)
              {
                int i;

                for (i=0; i<PMAX_MATCH && match[i].rm_so != -1; i++)
                  {
                    char * end = buff+match[i].rm_eo;
                    char tmp = *end;
                    *end = '\0';

                    matches++;
                    sprintf (match_var, "FGREP_MATCH_%d", matches);
                    sprintf (num, "%d", matches);
                    var_add_weak_declaration ("internal variable - fgrep_match_%",
                                              match_var, buff+match[i].rm_so,
                                              num, TYPE_UNKNOWN,
                                              package, line, T_EXEC);
                    *end = tmp;
                  }
                set_variable_content (match_var_n, num);
              }
            else if (res == FATAL_ERR)
              {
                fatal_exit ("wrong regular expression in fgrep '%s' in %s, line %d, terminating\n",
                            expr, package, line);
              }
          }
        fclose(fh);
      }
    else
      {
        fatal_exit ("can't read file for fgrep '%s' in %s, line %d, terminating\n",
                    p, package, line);
      }

#if 0
    if (stat (p, &stat_buf))
    {
        strcat (var_buf, "_RES");
        var_add_weak_declaration (package, var_buf,
                                  strsave (strerror (errno)), NULL,
                                  TYPE_UNKNOWN, package, line, T_EXEC);
    }
    else
    {
        end = var_buf + strlen (var_buf);
        strcpy (end, "_RES");
        var_add_weak_declaration (package, var_buf,
                                  strsave ("OK"), NULL, TYPE_UNKNOWN,
                                  package, line, T_EXEC);
        sprintf (buf, "%ld", (unsigned long)stat_buf.st_size);
        strcpy (end, "_SIZE");
        var_add_weak_declaration (package, var_buf,
                                  strsave (buf), NULL, TYPE_NUMERIC,
                                  package, line, T_EXEC);
    }
#endif

    free (p);
    free (expr);
}

static void mangle_version (char * dest, size_t size, char * version,
                            char * package)
{
    static char * base_version = 0;
    char * p;

    if (! base_version) {
        char buffer[128];
        FILE *f;
        if (! (f = fopen("version.txt", "r"))) {
            fatal_exit ("(%s:%d) unable to open 'version.txt'\n",
                        __FILE__, __LINE__);
        }
        if (!fgets(buffer, sizeof(buffer)-1, f)) {
            fatal_exit ("(%s:%d) unable to read 'version.txt'\n",
                        __FILE__, __LINE__);
        }
        base_version = strsave (buffer);
        log_info (T_EXEC|INFO, "using version from version.txt: %s\n",
                base_version);
    }

    if (!strcmp (version, fli4l_version_tag))
        version = base_version;

    /* remove potential version postfix */
    strncpy (dest, version, size);
    for (p = dest; *p && (isdigit(*p) || *p == '.'); p++)
        ;
    *p = '\0';
}
void parse_provides (char * id, char * version, char * package, int line)
{
    char * p;
    char real_version[128];
    char internal_id[128];

    mangle_version (real_version, sizeof(real_version), version, package);
    strcpy (internal_id, "provides_");
    strcat (internal_id, convert_to_upper (id));
    p = get_variable_package (internal_id);
    if (p)
    {
        char * q = get_variable_package (internal_id);
        if (strcmp (package, q))
        {
            fatal_exit ("Conflicting packages, package %s already"
                        " provides '%s' with version '%s'\n",
                        package, id, get_variable (internal_id));
        }
        return;
    }
    log_info (T_EXEC, "package %s provides %s version %s\n",
              package, id, version);
    var_add_weak_declaration (package, internal_id, real_version, version,
                              TYPE_NUMERIC, package, line,
                              T_EXEC);
    mark_var_generated (internal_id);
    mark_var_provide (internal_id);

    package_provider_added = 1;
}

void parse_depends (char * id, char * version, char * package,
                    int regexp, char * file, int line)
{
    char * p;
    char internal_id[128];
    char real_version[128];

    if (!regexp)
      mangle_version (real_version, sizeof(real_version), version, "");
    else
      strcpy (real_version, version);

    if (!final_pass)
    {
        return;
    }

    strcpy (internal_id, "provides_");
    strcat (internal_id, convert_to_upper (id));
    p = get_variable (internal_id);
    if (p)
    {
        int err=0;
        if (!regexp)
        {
            err = strncmp (p, real_version, strlen(real_version));
        }
        else
        {
            err = regexp_chkvar (internal_id, p, 0, real_version);
        }
        if (err)
        {
            fatal_exit ("(%s:%d) Version mismatch, package '%s' depends on "
                        "'%s', version %s, but '%s' has version %s\n",
                        file, line, package,
                        id, real_version, id, p);
        }
    }
    else
    {
        fatal_exit ("(%s:%d) Package missing, %s depends on %s, "
                    "which is either not present or not enabled\n",
                    file, line, package, id);
    }
}

void    parse_set_current (char * pkg, char * file)
{
    parse_current_package = strsave (pkg);
    parse_current_file = strsave (file);
}

char *  parse_get_current_package (void)
{
    return parse_current_package;
}

char *  parse_get_current_file (void)
{
    return parse_current_file;
}

int parse_check_file (char * name, char * check_dir)
{
    char        buf[256];
    FILE *      fp;
    int ret;

    if (! get_file_name (buf, check_dir, name, def_extcheck_ext))
    {
        log_info (VERBOSE, "no extended check file for package %s\n",
                  name);
        return 0;
    }
    fp = fopen (buf, "r");

    if (!fp)
    {
        fatal_exit ("Error opening extended check file %s: %s\n",
                    buf, strerror (errno));
    }

    log_info (T_EXEC|INFO,
              "reading extended check file %s\n", buf);
    yyrestart(fp);
    yyline = 1;
    inc_log_indent_level ();
    parse_set_current (name, buf);
    ret = yyparse ();
    dec_log_indent_level ();
    fclose (fp);

    if (ret != 0)
    {
        fatal_exit ("error while parsing check file %s\n", buf);
        return ERR;
    }
    return OK;
}

int parse_get_error (void)
{
    return error;
}

int execute_all_extended_checks (char * check_dir)
{
    int i;
    int         error = OK;

    /* parse all packages and build parse tree */
    log_info (INFO, "parsing extended check files\n\n");
    inc_log_indent_level ();

    /* prepare version string, we can't have it in the source because
     * it would be replaced by th svn version tag */
    strcpy (fli4l_version_tag, "__FLI4L");
    strcat (fli4l_version_tag, "VER__");

    for (i=0; i<n_packages; i++)
    {
        if (parse_check_file (packages[i], check_dir))
        {
            return ERR;
        }
    }
    dec_log_indent_level ();
    log_info (INFO, "\nfinished parsing extended check files\n");


    /* actually execute scripts */
    parse_pass = 1;
    while (1)
    {
        if (final_pass)
        {
            log_info (INFO, "executing extended checks, final pass\n\n");
        }
        else
        {
            log_info (INFO, "executing extended checks, pass %d\n\n",
                      parse_pass);
        }
        inc_log_indent_level ();
        walk_tree ();
        error = parse_get_error ();
        if (error)
        {
            return error;
        }
        dec_log_indent_level ();
        if (final_pass)
        {
            if (package_provider_added)
            {
                fatal_exit ("package provided during final check pass, "
                            "bad extended check file\n");
            }
            log_info (INFO, "\nfinished final pass\n");
            break;
        }
        log_info (INFO, "\nfinished pass %d\n", parse_pass);

        if (package_provider_added)
        {
            package_provider_added = 0;
        }
        else
        {
            final_pass = 1;
        }

        parse_pass++;

        if (parse_pass > 99)
        {
            fatal_exit ("bad extended check files, aborting after pass 99");
        }
    }
    return OK;
}
