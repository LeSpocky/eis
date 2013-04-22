/*----------------------------------------------------------------------------
 *  var.c   - handling of variables
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: var.c 18424 2010-04-23 10:05:06Z jw5 $
 *----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#if defined(WIN32)
#include "utsname.h"
#else
#include <sys/utsname.h>
#endif
#include "var.h"
#include "check.h"
#include "log.h"
#include "str.h"
#include "cfg.h"
#include "array.h"
#include "options.h"

#ifndef TRUE
# define TRUE               1
# define FALSE              0
#endif

typedef struct
{
    unsigned dq:1;
    unsigned supersede:1;
    unsigned checked:1;
    unsigned tagged:1;
    unsigned requested:1;
    unsigned copied:1;
    unsigned weak:1;
    unsigned numeric:1;
    unsigned generated:1;
    unsigned provide:1;
} flags_t;

typedef struct variables
{
    char *  package;
    char *  name;
    char *  content;
    char *  comment;
    char *  file;
    int     line;
    flags_t flags;
} VARIABLES;

static array_t * var_array;

static VARIABLES *      lookup_variable (char * name);
static void             chkvar_add_empty_instance (char * var);

static int
var_dump_package_header (FILE * fp, char * package)
{
    int error = 0;
    int found = 0;

    DECLARE_ARRAY_ITER(array_iter, p, VARIABLES);

    if (! (p = get_first_elem(var_array)))
        return 0;

    error = (fprintf (fp, "#\n# package '%s'", package) < 0);

    ARRAY_ITER_LOOP(array_iter, var_array, p)
    {
        if (p->flags.provide)
        {
            if (!strcmp (package, p->package))
            {
                if (!found)
                {
                    error = (fprintf (fp, ", provides:") < 0);
                    found = 1;
                }
                error = (fprintf (fp, "\n#\t- %s version %s",
                                  p->name, p->comment)< 0);
            }
        }
    }
    error = (fprintf (fp, "\n#\n") < 0);

    return error;
}

int check_variables ()
{
    int ret = OK;

    ARRAY_ITER(array_iter, var_array, p, VARIABLES)
    {
        if (p->flags.weak)
        {
            /* skip weak variables */
            continue;
        }

        if (! p->flags.tagged && !p->flags.checked)
        {
            /* check wether there is a corrosponding entry
             * in check/package.txt
             */
            char * set_var = replace_set_var_indices (p->name);
            if (!check_var_defined (set_var))
            {
                if (p->flags.supersede) {
                    log_error ("Unchecked variable %s='%s' in supersede config"
                               " file %s:%d. Please check whether you forgot "
                               "to install the package this variable belongs "
                               "to.\n",
                               p->name, p->content,
                               p->file, p->line);
                    ret = ERR;
                }
                else if (strong_consistency) {
                    log_error ("Unchecked variable %s='%s' in package %s. This "
                               "may be an obsolete variable from an earlier "
                               "version (check %s/%s%s and "
                               "documentation) or an error in %s/%s%s. "
                               "If there is an error in %s/%s%s, ask the "
                               "maintainer of the package to fix this.\n",
                               p->name, p->content, p->package,
                               config_dir, p->package,  def_cfg_ext ? def_cfg_ext : "",
                               check_dir, p->package,  def_check_ext ? def_check_ext : "",
                               check_dir, p->package,  def_check_ext ? def_check_ext : "");
                    ret = ERR;
                }
            }
#if 0
            else
            {
                char * tmp = strsave (set_var);
                while (strchr (tmp, '%'))
                {
                    char * p;
                    char * var_n = check_get_var_n (tmp);
                    if (var_n)
                    {
                        char * val= get_variable (var_n);
                        if (!val && check_var_optional (var_n))
                        {
                            log_info (INFO|VAR,
                                      "skipping optional variable '%s' "
                                      "(depends on undefined optional "
                                      "variable '%s')\n",
                                      p->name, var_n);
                            break;
                        }
                    }
                    else
                    {
                        fatal_exit ("(%s:%d) undefined var_n for '%s'\n",
                                    __FILE__, __LINE__,tmp);
                    }
                    p = tmp;
                    tmp = get_set_var_name_int (tmp, 1, __FILE__, __LINE__);
                    free (p);
                }
            }
#endif
        }
    }
    return ret;
}

/*----------------------------------------------------------------------------
 *  dump_variables (char * fname, char * fname_full_cfg)
 *----------------------------------------------------------------------------
 */
int
dump_variables (char * fname, char * fname_full_cfg)
{
    FILE *  fp;
    FILE *  fp_full;
    char *  last_package;

    int     num, total_num;
    int     ret = OK;
    int     next_package;

    struct utsname sys;

    DECLARE_ARRAY_ITER(array_iter, p, VARIABLES);

    log_info (INFO, "generating %s\n", fname);

    num = total_num = 0;
    fp = fopen (fname, "wb");

    if (! fp)
    {
        fatal_exit ("Error opening '%s': %s\n", fname, strerror (errno));
    }

    fp_full = fopen (fname_full_cfg, "wb");

    if (! fp_full)
    {
        fatal_exit ("Error opening '%s': %s\n",
                    fname_full_cfg, strerror (errno));
    }

    if (uname (&sys) != -1)
    {
        if (fprintf (fp, "#\n# generated by mkfli4l (%s) running under "
                     "%s Version %s\n", DATE, sys.sysname, sys.release) < 0)
        {
            fatal_exit ("Error while writing to %s: %s",
                        fname, strerror (errno));
        }
    }

    last_package = "";

    ARRAY_ITER_LOOP(array_iter, var_array, p)
    {
        int error = 0;
        char quote;
        total_num++;
        if (p->flags.weak || p->flags.generated)
        {
            /* skip weak variables */
            continue;
        }

        next_package = strcmp (last_package, p->package);
        last_package = p->package;
        if (next_package)
        {
            error |= var_dump_package_header (fp_full, p->package);
        }

        error |= (fprintf (fp_full, "%s='%s'\n",
                           p->name, p->content) < 0);
        if (error)
        {
            fatal_exit ("Error while writing to %s: %s",
                        fname_full_cfg, strerror (errno));
        }

        if (p->flags.tagged)
        {
            quote = p->flags.dq ? '"' : '\'';
            num++;
            if (next_package)
            {
                error |= var_dump_package_header (fp, p->package);
            }
            error |= (fprintf (fp, "%s=%c%s%c\n", p->name,
                               quote, p->content, quote) < 0);
            if (error)
            {
                fatal_exit ("Error while writing to %s: %s",
                            fname, strerror (errno));
            }
        }
    }

    if (ret == (OK))
    {
        inc_log_indent_level ();
        log_error ("total number of variables : %d, \twritten: %d\n",
                   total_num, num);
        log_error ("total size of variables   : %ld, \twritten: %ld\n",
                   ftell (fp_full), ftell (fp));
        dec_log_indent_level ();
    }
    else
    {
        unlink (fname);
        unlink (fname_full_cfg);
    }
    fclose (fp);
    fclose (fp_full);
    return ret;
} /* dump_variables (char * fname, char * fname_full_cfg) */


static VARIABLES * last_lookup = NULL;

VARIABLES *
lookup_variable (char *name)
{
    DECLARE_ARRAY_ITER(array_iter, p, VARIABLES);

    if (last_lookup)
    {
        if (last_lookup >= (VARIABLES *)get_first_elem(var_array) &&
            last_lookup <= (VARIABLES *)get_last_elem(var_array) &&
            ! strcmp (name, last_lookup->name))
        {
            return last_lookup;
        }
        last_lookup = 0;
    }

    ARRAY_ITER_LOOP(array_iter, var_array, p)
    {
        if (! strcmp (name, p->name))
        {
            last_lookup = p;
            return last_lookup;
        }
    }

    return NULL;
}
/*----------------------------------------------------------------------------
 *  get_variable (char * name)
 *----------------------------------------------------------------------------
 */
char *
get_variable (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->content;
    }

    return ((char *) NULL);
} /* get_variable (name) */

/*----------------------------------------------------------------------------
 *  get_variable_package (char * name)
 *----------------------------------------------------------------------------
 */
char *
get_variable_package (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->package;
    }

    return ((char *) NULL);
} /* get_variable (name) */


/*----------------------------------------------------------------------------
 *  get_variable_comment (char * name)
 *----------------------------------------------------------------------------
 */
char *
get_variable_comment (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->comment;
    }

    return ((char *) NULL);
} /* get_variable_comment (name) */

void
get_variable_src (char * name, char ** src, int * line)
{
    static char * unknown = "unknown";

    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        *src = p->file;
        *line = p->line;
    }
    else
    {
        *src = unknown;
        *line = -1;

    }
}

static void
chkvar_add_empty_instance (char * var)
{
    /* add an empty instance of this variable */
    static char *optional_var_pkg = "undefined optional variables";
    if (set_variable (optional_var_pkg, var, "", NULL, 0, "internal", 0, 0) != OK)
    {
        fatal_exit ("(%s:%d) internal error while generating "
                    "entry for %s\n", __FILE__, __LINE__, var);
    }
    mark_var_generated (var);
    mark_var_checked (var);
    mark_var_tagged (var);
}
/*----------------------------------------------------------------------------
 *  chkvar (char * name, cha *regexp_name)
 *----------------------------------------------------------------------------
 */
int
chkvar (char * name,
        char * regexp_name, char * user_regexp, char * package,
        int enabled, int type, int opt, char * defval)
{
    char *  p = get_variable (name);

    log_info (VAR, "checking %s='%s'\n", name, p ? p : "(undefined)");

    if (! p)
    {
        if (! opt)
        {
            if (enabled)
            {
                if (! defval)
                {
                    log_error ("Error: missing variable '%s' in config "
                               "file of package '%s'\n", name, package);
                    return (ERR);
                }
                set_variable (package, name, defval, "default value", 0,
                              "check file", 0, 0);
                log_info(INFO, "using default value for %s='%s'\n",
                         name, defval);
                p = defval;
            }
            else
                return OK;
        }
        else
        {
            chkvar_add_empty_instance (name);
            return OK;
        }
    }

    mark_var_checked (name);
    if (type == TYPE_NUMERIC)
    {
        mark_var_numeric (name);
    }
    if (enabled)
    {
        mark_var_tagged (name);
        return regexp_chkvar (name, p, regexp_name, user_regexp);
    }
    else
    {
        return OK;
    }

} /* chkvar (name, regexp_name) */

int
chkvar_idx (char * var, char * max_idx_name, char * opt_name,
            char * regexp_name, char * user_regexp, char * package,
            int type, int opt, int neg)
{
    char *  tmp_var;
    int     error = OK;
    int     enabled;
    struct iter_t * iter;

    log_info (VAR, "checking index var %s, var_n %s\n", var, max_idx_name);

    iter = init_set_var_iteration (var, opt_name, neg);

    while ((tmp_var = get_next_set_var (iter, &enabled)))
    {
        int ret;
        if (get_variable (tmp_var))
        {
            ret = chkvar(tmp_var, regexp_name, user_regexp, package,
                         enabled, type, opt, NULL);
            if (ret != OK)
            {
                error = ret;
            }
        }
        else
        {
            if (enabled)
            {
                if (opt != CHECK_REALLY_OPTIONAL)
                {
                    log_error ("Error: missing variable '%s' in config "
                               "file of package '%s'\n", tmp_var, package);
                    error = ERR;
                }
                else
                {
                    chkvar_add_empty_instance (tmp_var);
                }
            }
        }
    }
    end_set_var_iteration (iter);

    return error;
} /* chkvar_idx (var, max_idx, regexp_name) */

#define VAR_NAME        0
#define VAR_VAL         2
#define VAR_COMMENT     3

void var_init (void)
{
    var_array = init_array (VAR_ARRAY_SIZE, sizeof(VARIABLES));
}

int
read_config_file (char * config_file, char * package, int def)
{
    int         ret;
    int         result = OK;

    struct token_t tokens[5] = { TOKEN(CFG_ID),
                                 TOKEN(CFG_EQUAL),
                                 TOKEN(CFG_STRING),
                                 TOKEN(CFG_COMMENT|CFG_NL),
                                 TOKEN(CFG_NONE) };


    cfg_fopen (config_file);
    while ( (ret = get_config_tokens (tokens, 0)) != CFG_EOF)
    {
        if (ret == CFG_ERROR)
        {
            result = ERR;
            continue;
        }

        if (set_variable (package, tokens[VAR_NAME].text,
                          tokens[VAR_VAL].text, tokens[VAR_COMMENT].text,
                          def, config_file, tokens[VAR_VAL].dq,
                          tokens[VAR_NAME].line) == ERR)
        {
            log_error ("%s: line %d: variable %s already defined\n",
                       config_file, tokens[VAR_NAME].line,
                       tokens[VAR_NAME].text);
            result = ERR;
        }
    }
    cfg_fclose ();

    return result;
} /* read_config_file (char * config_file) */

/*----------------------------------------------------------------------------
 *  set_variable (char * name, char * content, comment)
 *----------------------------------------------------------------------------
 */
int
set_variable (char * package, char * name, char * content, char * comment,
              int supersede, char * config_file, int dq, int line)
{
    VARIABLES * p;
    static char * do_debug = "_DO_DEBUG";
    int offset;

    log_info (VERBOSE, "adding %s:%s='%s'%s\n",
              package, name, content, comment ? comment : "");

    p = lookup_variable (name);

    if (p)
    {
        if (!p->flags.supersede || supersede)
            return (ERR);

        p->flags.supersede=0;
        log_info (INFO, "using supersede value %s='%s' "
                  "instead of %s='%s' in %s:%d\n",
                  name, p->content, name, content, config_file, line);
        return (OK);
    }

    last_lookup = 0;
    p = get_new_elem (var_array);
    offset = strlen (name) - strlen (do_debug);

    p->package   = strsave (package);
    p->name      = strsave (name);
    p->content   = strsave (content);
    p->comment   = comment ? strsave (comment):NULL;
    p->file      = config_file;
    p->line      = line;
    p->flags.dq           = dq ? 1 : 0;
    p->flags.supersede    = supersede ? 1 : 0;
    p->flags.checked   = 0;
    p->flags.tagged    = 0;
    p->flags.requested = 0;
    p->flags.copied    = 0;
    p->flags.weak      = 0;
    p->flags.numeric   = 0;
    p->flags.generated = 0;
    p->flags.provide   = 0;

    if (offset > 0 && !strcmp (name + offset, do_debug))
    {
        /* copy .*_DO_DEBUG variables without further checking */
        log_info (VERBOSE, "copying debug macro %s\n", name);
        p->flags.tagged = 1;
    }

    return (OK);
} /* set_variable (package, name, content, comment) */

/*----------------------------------------------------------------------------
 *  set_variable_content (char * name, char * content)
 *----------------------------------------------------------------------------
 */
int
set_variable_content (char * name, char * content)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }

    if (p->content)
    {
        free (p->content);
    }
    p->content   = strsave (content);

    return (OK);
} /* set_variable_content (char * name, char * content) */

void
var_add_weak_declaration (char * package, char * name, char * value,
                          char * comment, int type, char * file,
                          int line, int log_level)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        log_info (log_level, "adding weak declaration for %s:%s='%s'\n",
                  package, name, value);

        set_variable (package, name, value, comment, 0, NULL, 0, 0);
        p = lookup_variable (name);
        if (!p)
        {
            fatal_exit ("%s %d: Error adding weak deklaration\n",
                        __FILE__, __LINE__);
        }
    }
    else
    {
        if (p->flags.weak)
        {
            log_info (log_level, "overwriting weak declaration for %s:%s='%s'"
                      " with %s:%s='%s'\n",
                      p->package, name, p->content, package, name, value);
            free (p->content);
            free (p->package);
            if (p->comment)
            {
                free (p->comment);
            }
            p->content = strsave (value);
            p->package = strsave (package);
            p->comment = strsave (comment);
        }
        else
        {
            fatal_exit ("(%s:%d) trying to overwrite config variable '%s', "
                        "aborting...\n", file, line, p->name);
        }
    }
    p->flags.checked   = 1;
    p->flags.weak      = 1;
    switch (type)
    {
    case TYPE_NUMERIC:
        p->flags.numeric   = 1;
        break;
    case TYPE_UNKNOWN:
        p->flags.numeric   = 0;
        break;
    default:
      fatal_exit ("(%s:%d) unknown type %x\n",
                  __FILE__, __LINE__, type);
    }
}

int
mark_var_tagged (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }

    p->flags.tagged   = 1;

    return (OK);
}

int
mark_var_checked (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        log_error ("undefined variable %s\n", name);
        return (ERR);
    }

    p->flags.checked   = 1;

    return (OK);
}

int
mark_var_requested (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }

    p->flags.requested   = 1;

    return (OK);
}

int
mark_var_copied (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }

    p->flags.copied   = 1;

    return (OK);
}

int
mark_var_numeric (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }
    log_info (T_EXEC, "setting %s to numeric type\n", name);
    p->flags.numeric   = 1;

    return (OK);
}

int
mark_var_generated (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }
    p->flags.generated   = 1;

    return (OK);
}

int
mark_var_provide (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return (ERR);
    }
    p->flags.provide   = 1;

    return (OK);
}

int
is_var_checked (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->flags.checked;
    }

    return 0;
}

int
is_var_tagged (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->flags.tagged;
    }

    return 0;
}

int
is_var_enabled (char * name, char * opt_var, int neg)
{
    char * val;

    if (! opt_var)
        return 1;

    if ( (val = get_variable (opt_var)) ) {
        if (! is_var_checked(opt_var))
            fatal_exit ("%s depends on unchecked variable %s\n",
                        name, opt_var);
        if (neg)
            return ! strcmp (val, "no");
        else
            return is_var_tagged(opt_var) && ! strcmp (val, "yes");
    }
    return 0;
}



int
is_var_numeric (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        if (p->flags.numeric)
        {
            log_info (T_EXEC, "(%s:%d) %s numeric type (%d)\n",
                      __FILE__, __LINE__, name, (int)p->flags.numeric);
        }
        return p->flags.numeric;
    }

    return 0;
}

int
is_var_weak (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->flags.weak;
    }

    return 0;
}

int
is_var_generated (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->flags.generated;
    }

    return 0;
}

int
is_var_provide (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (p)
    {
        return p->flags.provide;
    }

    return 0;
}

int
is_var_copy_pending (char * name)
{
    VARIABLES * p = lookup_variable (name);

    if (!p)
    {
        return ERR;
    }

    if (p->flags.tagged && p->flags.requested && !p->flags.copied)
    {
      return 1;
    }

    return 0;
}
int
is_var_unique (char * name, char * file, int line)
{
    char * val;

    DECLARE_ARRAY_ITER(array_iter, p, VARIABLES);
    VARIABLES *q = lookup_variable (name);

    if (!q)
    {
        return ERR;
    }

    val = q->content;

    ARRAY_ITER_LOOP(array_iter, var_array, p)
    {
        if (q->flags.tagged && ! strcmp (val, p->content) && p != q)
        {
#if 0
            char buffer[1024];
            snprintf(buffer, sizeof (buffer), "Variable '%s' (%s:%d) contains the same value as '%s'\n",  p->name, p->file, p->line, name);
            parse_warning (buffer, file, line);
#endif
            return 0;
        }
    }
    return 1;
}

void
free_variables (void)
{
    ARRAY_ITER(array_iter, var_array, p, VARIABLES)
    {
        free (p->name);
        free (p->package);
        free (p->content);
        if (p->comment)
            free (p->comment);
    }

}
