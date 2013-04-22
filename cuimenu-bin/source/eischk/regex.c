/*----------------------------------------------------------------------------
 *  regex.c - regular expression facility for mkfli4l
 *
 *  Copyright (c) 2002-2005 Jean Wolter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       01.03.2002  jw5
 *  Last Update:    $Id: regex.c 19657 2011-05-06 19:30:43Z kristov $
 *----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <sys/types.h>
#if defined(WIN32)
#  include "regex.h"
#else
#  include <regex.h>
#endif
#include <stdarg.h>
#include <ctype.h>

#include <dirent.h>

#include "var.h"
#include "check.h"
#include "log.h"
#include "str.h"
#include "cfg.h"
#include "array.h"

/* #define DEBUG_REGEX */

typedef struct
{
    char * name;
    char * expr;
    char * error_msg;
    char * file;
    int    line;
    int    type;
    int    extended;
    int    compiled;
    char * complete_expr;
    regex_t comp_expr;
} exp_cache_t;
#define INIT_EXPR (exp_cache_t){NULL, NULL, NULL, NULL, 0, 0, 0, 0, NULL, }
#define SIZE_ERR_BUFFER 128+1
#define SIZE_EXPR_BUFFER 5120*2
static char expr_buffer[SIZE_EXPR_BUFFER+1];
/* #define SIZE_EXPR_BUFFER 20 */
#define CHUNK_SIZE 40

static char err_buf[SIZE_ERR_BUFFER];
static exp_cache_t * find_expr (char * name);
static void copy_substring (char ** dest, char * src, int size,
                            char * expr_file, int line);
static void
compile_expression (exp_cache_t * e, char * expr, int final, int modify_expr,
                    char * expr_file, int line);
void compile_all_expressions (void);
int has_warn_prefix (const char * name);

static regex_t  reg;

static array_t * regexp_array;

#define REGEXP_WARN_PREFIX "WARN_"
int
has_warn_prefix (const char * name)
{
    return name &&
      *name == 'W' &&
      strlen (name) >= sizeof(REGEXP_WARN_PREFIX) &&
      !strncmp (name, REGEXP_WARN_PREFIX, sizeof(REGEXP_WARN_PREFIX)-1);
}
int
regexp_exists (char * name)
{
    return find_expr (name) != 0;
}

exp_cache_t *
find_expr (char * name)
{
    DECLARE_ARRAY_ITER(array_iter, p, exp_cache_t);

    if (! (p = get_first_elem(regexp_array)))
        return 0;

    if (has_warn_prefix (name))
    {
        name += sizeof(REGEXP_WARN_PREFIX)-1;
    }
    ARRAY_ITER_LOOP(array_iter, regexp_array, p)
    {
        if (!strcmp (name, p->name))
        {
            return p;
        }
    }
    return NULL;
}

char * user_regexp = "user defined regular expression";

int
regexp_user (char * value, char * expr, size_t nmatch, regmatch_t * pmatch,
             int modify_expr, char * file, int line)
{
    exp_cache_t e;
    int res;

    e.name = user_regexp;
    compile_expression (&e, expr, 1, modify_expr, file, line);
    log_info (LOG_REGEXP, "checking '%s' against regexp '%s' ('%s')\n",
              value, expr, e.complete_expr);

    res = regexec (&e.comp_expr, value, nmatch, pmatch, 0);
    if (res)
    {
        regerror (res, &e.comp_expr, err_buf, SIZE_ERR_BUFFER);
        log_info (LOG_REGEXP|VERBOSE, "regex error %d (%s) for value '%s' "
                  "and regexp '%s' ('%s')\n",
                  res, err_buf, value, expr, e.complete_expr);
    }
    regfree (&e.comp_expr);
    return res;
}

int
regexp_chkvar (char * name, char * value,
               char * regexp_name, char * user_regexp)
{
    int res;
    char * err_msg;

    if (!regexp_name)
    {
        if (strlen (user_regexp) > SIZE_EXPR_BUFFER-4)
        {
            log_error ("user supplied regular expression for variable"
                       " %s too long (max len: %d)\n",
                       name, SIZE_EXPR_BUFFER-4);
            return ERR;
        }
        err_msg = "user supplied regular expression";
        res = regexp_user (value, user_regexp, 0, 0, 1, __FILE__, __LINE__);
    }
    else
    {
        exp_cache_t *p = find_expr (regexp_name);
        if (!p)
        {
            fatal_exit ("%s %d: unknown regular expression %s\n",
                        __FILE__, __LINE__, regexp_name);
        }

        if (!p->compiled)
        {
            compile_expression (p, p->expr, 1, 1, p->file, p->line);
            p->compiled = 1;
        }
        err_msg = p->error_msg;
        res = regexec (&p->comp_expr, value, 0, NULL, 0);
        if (res)
        {
            regerror (res, &p->comp_expr, err_buf, SIZE_ERR_BUFFER);
            log_info (VERBOSE, "regex error %d (%s) for value '%s' "
                      "and regexp '%s'\n",
                      res, err_buf, value, p->expr);
        }
    }

    if (!res)
    {
        return OK;
    }
    if (res != FATAL_ERR)
    {
        char * config_file;
        int line;

        get_variable_src (name, &config_file, &line);
        if (config_file)
        {
          if (has_warn_prefix (regexp_name))
            {
                log_error ("(%s:%d) problematical value of variable %s: '%s' (%s)\n",
                           config_file, line, name, value, err_msg);
                return OK;
            }
            log_error ("(%s:%d) wrong value of variable %s: '%s' (%s)\n",
                       config_file, line, name, value, err_msg);
        }
    }
    return ERR;
}

int
regexp_find_type (char * regexp_name)
{
    exp_cache_t *p = find_expr (regexp_name);

    if (p)
    {
        return p->type;
    }

    return -1;
}

void copy_substring (char ** dest, char * src, int size, char * expr_file,
                     int line)
{
    if (!size)
    {
        size = strlen (src);
    }

    if (size >= SIZE_EXPR_BUFFER - (*dest-expr_buffer))
    {
        fatal_exit ("expression too long in %s line %d (max len after "
                    "sub expression replacement: %d)\n",
                    expr_file, line, SIZE_EXPR_BUFFER);
    }

    strncpy (*dest, src, size);
    *dest += size;
    **dest = '\0';
}

int
extend_expression (char * name, char * expr, char * error_msg,
                   char *expr_file, int line)
{
    char * tmp;
    exp_cache_t *p;

    /* name already existing ? */
    if (!(p = find_expr (name)))
    {
        log_error ("%s: line %d: tries to extend expression '%s' which "
                   "doesn't exist\n",
                   expr_file, line, name);
        return (ERR);
    }
    /* create new regexp and compile it */
    tmp = (char *) malloc (strlen (expr) + strlen (p->expr) + 6);
    strcpy (tmp, "(");
    strcat (tmp, p->expr);
    strcat (tmp, ")|(");
    strcat (tmp, expr);
    strcat (tmp, ")");
    compile_expression (p, tmp, 0, 0, expr_file, line);
    free (p->expr);
    p->expr = tmp;

    /* extend error message */
    tmp = malloc (strlen (p->error_msg) + strlen (error_msg) + 1);
    strcpy (tmp, p->error_msg);
    strcat (tmp, error_msg);
    free (p->error_msg);
    p->error_msg = strsave_ws (tmp);
    free (tmp);
    return 0;
}

int
check_for_dangeling_extensions (void)
{
    ARRAY_ITER(array_iter, regexp_array, p, exp_cache_t)
    {
        if (p->extended)
        {
            log_info (INFO|LOG_REGEXP,
                      "Tried to extend undefined regular expression '%s'.\n",
                       p->name);
            *p->name = '#';
        }
    }
    return 0;
}

void
compile_all_expressions (void)
{
    DECLARE_ARRAY_ITER(array_iter, p, exp_cache_t);

    if (! (p = get_first_elem(regexp_array)))
    {
        fatal_exit ("No regular expression defined, unable to check configuration.\n");
    }

    ARRAY_ITER_LOOP(array_iter, regexp_array, p)
    {
        if (p->expr)
        {
            compile_expression (p, p->expr, 1, 1, __FILE__, __LINE__);
        }
    }

}
void
compile_expression (exp_cache_t * e, char * expr, int final, int modify_expr,
                    char * expr_file, int line)
{
    int         res;
    regmatch_t  pmatch[4];
    char *      sub_name;
    char *      subs = 0;

    char expr_src[SIZE_EXPR_BUFFER+1];
    exp_cache_t * p;
    char *      dst;
    char *      src;

    strcpy (expr_src, expr);

    do {
        dst = expr_buffer;
        src = expr_src;

        while (*src)
        {
            /* look for subexpressions (RE:.*) */
            res = regexec (&reg, src, 2, pmatch, 0);
            if (res != 0)
            {
                /* no sub expressions */
                copy_substring (&dst, src, 0, expr_file, line);
                break;
            }

            /* copy substring including '(' and skip substring
             * including '(RE:' */
            copy_substring (&dst, src, pmatch[1].rm_so+1, expr_file, line);
            sub_name = src + pmatch[1].rm_so+4;
            src[pmatch[1].rm_eo-1]='\0';
            src += pmatch[1].rm_eo;

            if (!subs)
            {
                subs = strsave (e->name);
            }
            subs = strcat_save (subs, " -> ");
            subs = strcat_save (subs, sub_name);
            if (!strcmp (sub_name, e->name))
            {
                fatal_exit ("recursive definition of %s (%s) detected in %s line %d'\n",
                            sub_name, subs, expr_file, line);
            }
            p = find_expr (sub_name);
            if (!p)
            {
                fatal_exit ("unknown subexpression %s in %s line %d'\n",
                            sub_name, expr_file, line);
            }

            copy_substring (&dst, p->expr, 0, expr_file, line);
            copy_substring (&dst, ")", 0, expr_file, line);
        }

        /* look for subexpressions (RE:.*) */
        res = regexec (&reg, expr_buffer, 2, pmatch, 0);
        if (!res)
        {
            /* there are still sub expressions */
            strcpy (expr_src, expr_buffer);
        }
    } while (!res);

    strcpy (expr_src, expr_buffer);
    dst = expr_buffer;
    src = expr_src;

    /* add leading '^(' and trailing ')$' */
    if (modify_expr)
        copy_substring (&dst, "^(", 0, expr_file, line);
    copy_substring (&dst, src, 0, expr_file, line);
    if (modify_expr)
        copy_substring (&dst, ")$", 0, expr_file, line);

    /* compile regexp for regexps */
    res = regcomp (&e->comp_expr,
                   expr_buffer,
                   REG_EXTENDED | REG_NEWLINE);
    if (res != 0)
    {
        regerror (res, &reg, err_buf, SIZE_ERR_BUFFER);
        fatal_exit ("regex error %d (%s) for expr '%s' in %s line %d\n",
                    res, err_buf, expr_buffer, expr_file, line);
    }

    if (final)
    {
        e->complete_expr = strsave (expr_buffer);
        if (e->name != user_regexp)
            log_info (LOG_REGEXP, "adding %s='%s' ('%s')\n",
                      e->name, expr, e->complete_expr);
    }
    else
    {
        regfree (&e->comp_expr);
    }
    free(subs);
}

void regexp_init (void)
{
    int res;
    const char * regexpr = "(\\(RE:[^\\)]*\\))";

    /* compile regexp for regexps */
    res = regcomp (&reg, regexpr, REG_EXTENDED | REG_NEWLINE);
    if (res != 0)
    {
        regerror (res, &reg, err_buf, SIZE_ERR_BUFFER);
        fatal_exit ("regex error %d (%s) in %s:%d\n",
                    res, err_buf, __FILE__, __LINE__);
    }
    regexp_array = init_array (REGEXP_ARRAY_SIZE, sizeof(exp_cache_t));
}

int
add_expression (char * name, char * expr, char * error_msg, int extend_expr,
                char *expr_file, int line)
{
    char * saved_expr = NULL;
    char * saved_error_msg = NULL;

    exp_cache_t *p;

    /* name already existing ? */
    if ((p = find_expr (name)))
    {
        if (extend_expr)
        {
            return extend_expression (name, expr, error_msg, expr_file, line);
        }

        if (p->extended)
        {
            saved_expr = p->expr;
            saved_error_msg = p->error_msg;
            p->extended = 0;
            p->expr = p->error_msg = NULL;
        }
        else
        {
            log_error ("%s: line %d: redefinition of expression %s,"
                       " already defined in %s:%d\n",
                       expr_file, line, p->name, p->file, p->line);

            return (ERR);
        }
    }
    else
    {
        p = get_new_elem (regexp_array);
        *p = INIT_EXPR;
        p->extended = extend_expr;
    }

    /* add name, error msg and regexp */
    p->name = strsave (name);
    p->expr = strsave (expr);
    p->error_msg = strsave_ws (error_msg);
    p->file = expr_file;
    p->line = line;
    p->compiled = 0;

    if (!strncmp (name, "NUM", 3))
    {
        log_info (VERBOSE|T_EXEC, "found numeric mode '%s'\n", name);
        p->type = TYPE_NUMERIC;
    }
    compile_expression (p, p->expr, 0, 0, expr_file, line);

    if (saved_expr)
    {
        int ret = extend_expression (name, saved_expr, saved_error_msg,
                                     expr_file, line);
        free (saved_expr);
        free (saved_error_msg);
        p->extended = 0;
        return ret;
    }

    return OK;
}

/*----------------------------------------------------------------------------
 * read file with regular expressions
 *----------------------------------------------------------------------------
 */
#define EXPR_NAME       0
#define EXPR_VAL        2
#define EXPR_ERRMSG     4

int
regexp_read_file (char * expr_file)
{
    int    result = OK;
    int    ret;

    struct token_t tokens[6] = { TOKEN(CFG_ID|CFG_OPT_ID|CFG_DEP_ID),
                                 TOKEN(CFG_EQUAL),
                                 TOKEN(CFG_STRING),
                                 TOKEN(CFG_COLON),
                                 TOKEN(CFG_STRING|CFG_ML_STRING),
                                 TOKEN(CFG_NONE)
    };

    cfg_fopen (expr_file);
    while ( (ret = get_config_tokens (tokens, 1)) != CFG_EOF)
    {
        char * name;
        int expand;

        if (ret == CFG_ERROR)
        {
            result = ERR;
            continue;
        }

        name = tokens[EXPR_NAME].text;
        expand = tokens[EXPR_NAME].token != CFG_ID;

        if (tokens[EXPR_NAME].token == CFG_DEP_ID)
        {
            char *dep, *expr;
            char *res;
            int len;

            if (*name != '+')
            {
                log_error ("%s: %d: conditional regular expressions may only be used to expand already existing expressions, please use '+%s'\n",
                           expr_file, tokens[EXPR_NAME].line, name);
                result = FATAL_ERR;
                continue;
            }
            name++;

            len = strlen (name);
            dep = strchr(name, '(');
            assert (name[len-1] == ')' && dep);

            name[len-1] = '\0';
            *dep++ = '\0';

            expr = strstr(dep, "=~'");
            if (expr) {
                *expr = 0;
                expr += 3;
                assert (name[len-2] == '\'');
                name[len-2] = '\0';
            }
            else {
                expr = "^yes$";
            }

            if (! (res = get_variable(dep)))
            {
                log_info (LOG_EXP, "%s: %d: %s depends on undefined variable %s\n",
                          expr_file, tokens[EXPR_NAME].line, name, dep);
                continue;
            }
            if (regexp_user(res, expr, 0, 0, 0,
                            expr_file, tokens[EXPR_NAME].line))
            {
                log_info (LOG_EXP, "%s: %d: ignoring expansion of %s - '%s' =~ '%s'\n",
                          expr_file, tokens[EXPR_NAME].line, name, res, expr);
                continue;
            }
        }
        if (expand)
            log_info (LOG_EXP, "%s: %d: expanding definition of %s\n",
                      expr_file, tokens[EXPR_NAME].line, name);

        if (add_expression (name,
                            tokens[EXPR_VAL].text,
                            tokens[EXPR_ERRMSG].text,
                            expand,
                            expr_file, tokens[EXPR_NAME].line) != OK)
        {
                result = FATAL_ERR;
        }
    }

    cfg_fclose ();
    // compile_all_expressions ();

    return result;
} /* read_expr_file (char * expr_file) */

int regexp_get_expr (char *name, regex_t  **preg, char ** err_msg)
{
    exp_cache_t * e = find_expr (name);
    if (e)
    {
        if (! e->compiled)
        {
            compile_expression (e, e->expr, 1, 1, e->file, e->line);
            e->compiled = 1;
        }
        *preg = &e->comp_expr;
        *err_msg = e->error_msg;
    }
    return e!=0;
}
