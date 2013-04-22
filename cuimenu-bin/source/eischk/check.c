/*----------------------------------------------------------------------------
 *  check.c   - check variables
 *
 *  Copyright (c) 2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       12.08.2001  fm
 *  Last Update:    $Id: check.c 17656 2009-10-18 18:39:00Z knibo $
 *----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include "check.h"
#include "var.h"
#include "log.h"
#include "parse.h"
#include "str.h"
#include "cfg.h"
#include "array.h"

#ifndef TRUE
# define TRUE               1
# define FALSE              0
#endif

#define SUNDAY              0                       /* 1st day of unix week */
#define HOURS_PER_DAY       24                      /* hours per day        */
#define DAYS_PER_WEEK       7                       /* days per week        */

static int      time_table[HOURS_PER_DAY * DAYS_PER_WEEK];  /* 24 * 7 hours */
static int      local_time_table[HOURS_PER_DAY * DAYS_PER_WEEK];  /* 24 * 7 hours */
static char **  time_variables;
static char **  time_values;

static char *   en_wday_strings[DAYS_PER_WEEK] =
{
    "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"
};

static char *   ge_wday_strings[DAYS_PER_WEEK] =
{
    "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"
};

typedef struct
{
    unsigned type_numeric:1;
    unsigned optional:1;
    unsigned really_optional:1;
    unsigned var_n_auto:1;
    unsigned weak:1;
    unsigned neg_opt:1;
} flags_t;
#define INIT_FLAGS (flags_t){0,0,0,0,0,0}

typedef struct check
{
    char *  name;
    char *  opt_var;
    char *  var_n;
    char *  regexp_name;
    char *  regexp;
    char *  defval;
    char *  package;
    flags_t flags;
} CHECK;

static array_t  *check_array;

char         *  check_get_opt_var (char * var);
static void     check_var_n (char * var, char * opt_var, char * varn_n, char * file, int line);
static CHECK *  lookup_check_var (char * name);
static int      check_local_time_table (int times_idx);
static void     init_local_time_table (void);

static CHECK *  lookup_check_var (char * name)
{
    ARRAY_ITER(array_iter, check_array, p, CHECK)
    {
        if (!strcmp (p->name, name))
        {
            return p;
        }
    }
    return NULL;
}

int check_var_defined (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return 1;
    }
    return 0;
}

int check_var_numeric (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->flags.type_numeric;
    }
    return 0;
}

int check_var_weak (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->flags.weak;
    }
    return 0;
}

int check_var_optional (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->flags.optional || p->flags.really_optional;
    }
    return 0;
}

int check_var_really_optional (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->flags.really_optional;
    }
    return 0;
}

int check_var_optional_state (char * var)
{
    int res = 0;
    CHECK * p = lookup_check_var (var);

    if (p)
    {
            if (p->flags.really_optional)
                res |=  CHECK_REALLY_OPTIONAL;
            if (p->flags.optional)
                res |=  CHECK_OPTIONAL;
            if (p->flags.var_n_auto)
                res |=  CHECK_AUTO;
            return res;
    }
    return 0;
}

int check_var_n_auto (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->flags.var_n_auto;
    }
    return 0;
}

char * check_get_opt_var (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->opt_var;
    }
    fatal_exit ("%s %d: undefined variable %s\n", __FILE__, __LINE__,
                var);
    return NULL;
}
char * check_get_var_n (char * var)
{
    CHECK * p = lookup_check_var (var);

    if (p)
    {
        return p->var_n;
    }
    return 0;
}
void check_var_n (char * var, char * opt_var, char * var_n, char * file, int line)
{
    char * opt_var_n;

    if (!check_var_defined (var_n))
    {
        log_error ("%s:%d: Variable %s depends on var_n %s"
                   " which isn't defined in any check file\n",
                   file, line, var, var_n);
        return;
    }

    opt_var_n = check_get_opt_var (var_n);
    if (opt_var && opt_var_n)
    {
        if (strcmp (opt_var, opt_var_n) && !strchr(opt_var, '%'))
        {
            log_error ("%s:%d: var_n depends on different opt_var\n"
                       "\tVariable: '%s' -> '%s'\n"
                       "\tVar_n:    '%s' -> '%s'\n",
                        file, line, var, opt_var, var_n, opt_var_n);
        }
    }
    else if (opt_var_n)
    {
        log_error ("%s:%d: var_n depends on opt_var while"
                   " var doesn't depend on opt_var\n"
                   "\tVariable: '%s' -> no dependency\n"
                   "\tVar_n:    '%s' -> '%s'\n",
                   file, line, var, var_n, opt_var_n);
    }
    if (!check_var_optional (var))
    {
        if (var_n && check_var_optional (var_n))
        {
            fatal_exit ("%s:%d: nonoptional variable %s depends on "
                        "optional var_n %s\n", file, line, var, var_n);
        }
    }
}

#define CHK_NAME        0
#define CHK_OPT_VAR     1
#define CHK_VAR_N       2
#define CHK_VAL         3
#define CHK_DEFVAL      4

void check_init (void)
{
    check_array = init_array (CHECK_ARRAY_SIZE, sizeof(CHECK));
}

int
read_check_file (char * fname, char * package)
{
    int         result = OK;
    int         ret;

    struct token_t tokens[6] = { TOKEN(CFG_ID | CFG_OPT_ID | CFG_REALLY_OPT_ID),
                                 TOKEN(CFG_ID | CFG_NEG_ID | CFG_HYPHEN),
                                 TOKEN(CFG_ID | CFG_OPT_ID | CFG_HYPHEN),
                                 TOKEN(CFG_ID | CFG_REGEXP),
                                 TOKEN(CFG_STRING|CFG_NL),
                                 TOKEN(CFG_NONE)
    };

    cfg_fopen (fname);
    while ( (ret = get_config_tokens (tokens, 0)) != CFG_EOF)
    {
        int type;
        CHECK * c;

        if (ret == CFG_ERROR)
        {
            result = ERR;
            continue;
        }

        c = get_new_elem (check_array);
        c->package = package;
        c->flags = INIT_FLAGS;

        switch (tokens[CHK_NAME].token)
        {
        case CFG_ID:
            c->flags.optional = c->flags.really_optional = 0;
            break;
        case CFG_OPT_ID:
            c->flags.optional = 1;
            c->flags.really_optional = 0;
            log_info (VERBOSE, "optional variable %s found\n",
                      tokens[CHK_NAME].text);
            break;
        case CFG_REALLY_OPT_ID:
            c->flags.optional = c->flags.really_optional = 1;
            log_info (VERBOSE, "really optional variable %s found\n",
                      tokens[CHK_NAME].text);
            break;
        default:
            fatal_exit ("unexpected value for variable name\n");
        }
        c->name = tokens[CHK_NAME].text;

        switch (tokens[CHK_OPT_VAR].token)
        {
        case CFG_HYPHEN:
            c->opt_var = NULL;
        case CFG_ID:
            c->opt_var = tokens[CHK_OPT_VAR].text;
            break;
        case CFG_NEG_ID:
            c->opt_var = tokens[CHK_OPT_VAR].text;
            c->flags.neg_opt = 1;
            break;
        default:
            fatal_exit ("unexpected value for opt variable\n");
        }

        switch (tokens[CHK_VAR_N].token)
        {
        case CFG_HYPHEN:
            c->var_n = NULL;
        case CFG_ID:
            c->var_n = tokens[CHK_VAR_N].text;
            c->flags.var_n_auto = 0;
            break;
        case CFG_OPT_ID:
            c->var_n = tokens[CHK_VAR_N].text;
            c->flags.var_n_auto = 1;
            break;
        default:
            fatal_exit ("unexpected value for var_n\n");
        }

        if (c->var_n && !strchr (c->name, '%'))
        {
            log_error ("%s:%d  missing '%%' in set variable %s\n",
                       fname, tokens[CHK_NAME].line, c->name);
            result = ERR;
            continue;
        }

        switch (tokens[CHK_VAL].token)
        {
        case CFG_ID:
            type = regexp_find_type (tokens[CHK_VAL].text);

            if (type >= 0)
            {
                if (type == TYPE_NUMERIC)
                {
                    c->flags.type_numeric = 1;
                }
            }
            else
            {
                log_error ("%s: line %d: unknown value '%s'\n",
                           fname, tokens[CHK_NAME].line, tokens[CHK_VAL].text);
                result = ERR;
            }
            c->regexp_name = tokens[CHK_VAL].text;
            break;
        case CFG_REGEXP:
            /* user defined regular expression */
            c->regexp_name = 0;
            c->regexp = tokens[CHK_VAL].text;
            break;
        default:
            fatal_exit ("unexpected value for check expression\n");
        }
        switch (tokens[CHK_DEFVAL].token)
        {
        case CFG_NL:
            break;
        case CFG_STRING:
            if (c->var_n)
            {
                log_error ("You can't specify a default value for an array "
                           "variable: %s='%s'\n",
                           c->name, tokens[CHK_DEFVAL].text);
                result=ERR;
            }
            else
            {
                c->defval = tokens[CHK_DEFVAL].text;
                log_info(VAR, "default: %s='%s'\n", c->name, c->defval);
            }
            break;
        default:
            fatal_exit ("unexpected value for default expression\n");
        }

        if (c->opt_var && !check_var_defined (c->opt_var))
        {
            log_error ("Variable %s depends on opt_var %s"
                       " which isn't checked yet\n",
                       c->name, c->opt_var);
        }

        if (!c->flags.optional &&
            c->opt_var && check_var_optional (c->opt_var))
        {
            fatal_exit ("nonoptional variable %s depends on "
                        "optional variable %s\n", c->name, c->opt_var);
        }
        if (c->var_n)
        {
            check_var_n (c->name, c->opt_var, c->var_n, fname, tokens[CHK_NAME].line);
        }
    }

    cfg_fclose ();

    return result;
} /* read_check_file (char * fname) */

int
get_variable_dimension (char * variable)
{
    ARRAY_ITER(array_iter, check_array, p, CHECK)
    {
        if (! strcmp (p->name, variable))
        {
            if (p->var_n)
            {
                char *  value;
                int         n;

                value = get_variable (p->var_n);

                if (! value)
                {
                    if (!check_var_optional (p->var_n))
                    {
                        char * opt = check_get_opt_var (p->var_n);
                        if (opt)
                        {
                            value = get_variable (opt);
                        }
                        if (!opt || !value || !strcmp(value, "YES"))
                        {
                            log_error ("%s %d: variable '%s' not defined\n",
                                       __FILE__, __LINE__, p->var_n);
                            return (FATAL_ERR);
                        }
                    }
                    return 0;
                }

                n = atoi (value);

                return (n);
            }
            else
            {
                return (ERR);               /* no dimension!        */
            }
        }
    }

    log_error ("%s %d: variable '%s' not defined in any check file\n",
               __FILE__, __LINE__, variable);
    return (FATAL_ERR);                     /* variable not found   */
} /* get_variable_dimension (char * variable) */

char *
get_set_var_n (char * variable)
{
    CHECK * c;
    char *  ret = NULL;
    char *  q;
    char *  p;

    q = strip_multiple_indices (variable);
    p = replace_set_var_indices (q);
    free (q);

    c = lookup_check_var (p);

    if (c)
    {
        ret = c->var_n;
    }
    free (p);
    return ret;
} /* get_set_var_n (char * variable) */

void
check_add_weak_declaration (char * package, char * name, char * value,
                            char ** var_n, char * file, int line,
                            int log_level)
{
    static char * weak_var_n;
    char * p;

    /* try to find check rule for % variable */
    CHECK * c = lookup_check_var (name);
    if (c)
    {
        if (var_n)
        {
            *var_n = NULL;
        }
        return;
    }

    log_info (log_level,  "adding weak declaration for %s\n", name);
    /* construct var_n name */
    weak_var_n = strsave (name);
    if (!(p = strchr (weak_var_n, '%')))
    {
        fatal_exit ("check_add_weak_declaration: can't add non set var %s\n",
                    name);
    }
    *p = 'N';
    *(p+1) = '\0';

    /* ok, no check rule present, so lets create one */
    c = get_new_elem (check_array);
    c->name     = weak_var_n;
    c->opt_var  = NULL;
    c->var_n    = NULL;
    c->regexp_name      = 0;
    c->flags.type_numeric = c->flags.weak = 1;
    c->flags.optional = c->flags.really_optional = 0;

    c = get_new_elem (check_array);
    c->name     = strsave (name);
    c->opt_var  = NULL;
    c->var_n    = strsave (weak_var_n);
    c->regexp_name      = 0;
    c->flags.optional = c->flags.really_optional = c->flags.weak = 1;
    c->flags.type_numeric = 0;

    var_add_weak_declaration ("internal", weak_var_n, value,
                              "internal variable used to handle % variables"
                              " declared inside opt/package.txt",
                              TYPE_NUMERIC, file, line, T_EXEC|VAR);
    mark_var_checked (weak_var_n);
    if (var_n)
    {
        *var_n = weak_var_n;
    }
}


/*----------------------------------------------------------------------------
 * convert_week_day_to_day ()               - convert week day to index 0 - 6
 *----------------------------------------------------------------------------
 */
static int
convert_week_day_to_day (char * week_day)
{
    int i;

    for (i = 0; i < DAYS_PER_WEEK; i++)
    {
        if (! strcmp (week_day, en_wday_strings[i]) ||
            ! strcmp (week_day, ge_wday_strings[i]))
        {
            return (i);
        }
    }

    return (-1);
} /* convert_week_day_to_day (week_day) */


/*----------------------------------------------------------------------------
 * init_local_time_table ()                 - initialize local time table
 *----------------------------------------------------------------------------
 */
void
init_local_time_table (void)
{
    int i;
    for (i=0; i< DAYS_PER_WEEK*HOURS_PER_DAY; i++)
    {
        local_time_table [i] = -1;
    }
/*     memset (local_time_table, -1, HOURS_PER_DAY * DAYS_PER_WEEK * sizeof (int)); */
}
/*----------------------------------------------------------------------------
 * check_local_time_table () - check whether time table spans the whole week
 *----------------------------------------------------------------------------
 */
int
check_local_time_table (int times_idx)
{
    int day, hour;
    int start_day=0, start_hour=0;
    int found = 0;
    int ret = OK;
    for (day = 0; day < DAYS_PER_WEEK; day++)
    {
        for (hour = 0; hour < HOURS_PER_DAY; hour++)
        {
            if (!found)
            {
                if (local_time_table [day*HOURS_PER_DAY + hour] == -1)
                {
                    found = 1;
                    ret = ERR;
                    start_day = day;
                    start_hour = hour;
                }
            }
            else
            {
                if (local_time_table [day*HOURS_PER_DAY + hour] != -1)
                {
                    found = 0;
                    log_error ("Error: undefined time span in variable %s starting at %s:%d ending at %s:%d\n",
                               time_variables[times_idx],
                               ge_wday_strings[start_day], start_hour,
                               ge_wday_strings[day], hour);
                }
            }
        }
    }
    if (found)
    {
            log_error ("Error: undefined time span in variable %s starting at %s:%d ending at %s:%d\n",
                       time_variables[times_idx],
                       ge_wday_strings[start_day], start_hour,
                       ge_wday_strings[DAYS_PER_WEEK-1], HOURS_PER_DAY);
    }

    return ret;
}
/*----------------------------------------------------------------------------
 * fill_time_table ()                       - fill time tables
 *----------------------------------------------------------------------------
 */
static int
fill_global_time_table (int times_idx, int start_time, int end_time)
{
    int i;

    for (i = start_time; i < end_time; i++)
    {
        if (time_table[i] < 0)
        {
            time_table[i] = times_idx;
        }
        else
        {
            if (time_table[i] == times_idx)
            {

                log_error ("Error: overlapping time ranges in variable %s\n",
                           time_variables[times_idx]);
            }
            else
            {
                log_error ("Error: overlapping time ranges in variables %s and %s\n",
                          time_variables[time_table[i]], time_variables[times_idx]);
            }
            return (ERR);
        }
    }

    return (OK);
} /* fill_global_time_table (times_idx, start_time, end_time) */
static int
fill_local_time_table (int times_idx, int start_time, int end_time)
{
    int i;

    for (i = start_time; i < end_time; i++)
    {
        if (local_time_table[i] < 0)
        {
            local_time_table[i] = 0;
        }
        else
        {
            log_error ("Error: overlapping time ranges in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }
    }
    return (OK);
} /* fill_local_time_table (times_idx, start_time, end_time) */

static int
fill_time_table (int times_idx, int lcr, int start_time, int end_time)
{
    int res = OK;

    if (lcr)
    {
        res = fill_global_time_table (times_idx, start_time, end_time);
    }
    if (res == OK)
    {
        res = fill_local_time_table (times_idx, start_time, end_time);
    }
    return res;
}

/*----------------------------------------------------------------------------
 *  check_a_time_value (int times_idx,
 *----------------------------------------------------------------------------
 */
static int
check_a_time_value (int times_idx, int lcr,
                    char * start_week_day_str, char * end_week_day_str,
                    char * start_hour_str, char * end_hour_str)
{
    int     start_day;
    int     end_day;
    int     start_hour;
    int     end_hour;
    int     day;
    int     start_time;
    int     end_time;

    start_day   = convert_week_day_to_day (start_week_day_str);
    end_day     = convert_week_day_to_day (end_week_day_str);

    if (start_day < 0)
    {
        log_error ("Error: format error in variable %s: no weekday: %s\n",
                   time_variables[times_idx], start_week_day_str);
        return (ERR);
    }

    if (end_day < 0)
    {
        log_error ("Error: format error in variable %s: no weekday: %s\n",
                   time_variables[times_idx], end_week_day_str);
        return (ERR);
    }

    start_hour  = atoi (start_hour_str);
    end_hour    = atoi (end_hour_str);

    if (start_hour < 0 || start_hour >= 24)
    {
        log_error ("Error: format error in variable %s: no valid hour: %s\n",
                   time_variables[times_idx], start_hour_str);
        return (ERR);
    }

    if (end_hour <= 0 || end_hour > 24)
    {
        log_error ("Error: format error in variable %s: no valid hour: %s\n",
                   time_variables[times_idx], end_hour_str);
        return (ERR);
    }

    day = start_day;

    for (;;)
    {
        if (start_hour > end_hour)
        {
            start_time  = day * HOURS_PER_DAY + start_hour;
            end_time    = day * HOURS_PER_DAY + HOURS_PER_DAY;

            if (fill_time_table (times_idx, lcr, start_time, end_time) != OK)
            {
                return (ERR);
            }

            start_time  = day * HOURS_PER_DAY + 0;
            end_time    = day * HOURS_PER_DAY + end_hour;

            if (fill_time_table (times_idx, lcr, start_time, end_time) != OK)
            {
                return (ERR);
            }
        }
        else
        {
            start_time  = day * HOURS_PER_DAY + start_hour;
            end_time    = day * HOURS_PER_DAY + end_hour;

            if (fill_time_table (times_idx, lcr, start_time, end_time) != OK)
            {
                return (ERR);
            }
        }

        if (day == end_day)
        {
            break;
        }

        day++;

        if (day == DAYS_PER_WEEK)
        {
            day = 0;
        }
    }

    return (OK);
} /* check_a_time_value (...) */

/*----------------------------------------------------------------------------
 *  check_time_values (int times_idx, int def_route)    - check time values of variable
 *
 *  Example:
 *
 *  Mo-Fr:08-18:0.032:Y Mo-Fr:18-08:0.025:Y Sa-Su:00-24:0.025:Y
 *----------------------------------------------------------------------------
 */
static int
check_time_values (int times_idx, int def_route)
{
    char *  week_range_str;
    char *  hour_range_str;
    char *  yes_no_str;
    char *  start_week_day_str;
    char *  end_week_day_str;
    char *  start_hour_str;
    char *  end_hour_str;
    char *  p;
    char *  pp;
    char *  ppp;

    char *  orig_val;
    int     complained = 0;

    p = time_values[times_idx];
    orig_val = strsave (p);
    init_local_time_table ();

    do
    {
        pp = strchr (p, ' ');

        if (pp)
        {
            *pp++ = '\0';

            while (*pp == ' ')
            {
                pp++;
            }

            if (! *pp)
            {
                pp = (char *) NULL;
            }
        }

        ppp = strchr (p, ':');

        if (ppp)
        {
            week_range_str = p;
            *ppp++ = '\0';
        }
        else
        {
            log_error ("Error: format error in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }

        p = ppp;
        ppp = strchr (p, ':');

        if (ppp)
        {
            hour_range_str = p;
            *ppp++ = '\0';
        }
        else
        {
            log_error ("Error: format error in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }

        p = ppp;
        ppp = strchr (p, ':');

        if (ppp)
        {
            *ppp++ = '\0';
        }
        else
        {
            log_error ("Error: format error in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }

        yes_no_str = ppp;

        if (strlen (week_range_str) != 5 ||
            *(week_range_str + 2)   != '-' ||
            strlen (hour_range_str) != 5 ||
            *(hour_range_str + 2)   != '-')
        {
            log_error ("Error: format error in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }

        if (! (strcmp (yes_no_str, "Y") && strcmp (yes_no_str, "y") &&
               strcmp (yes_no_str, "N") && strcmp (yes_no_str, "n") &&
               strcmp (yes_no_str, "D") && strcmp (yes_no_str, "d")))
        {
            int lcr = ! (strcmp (yes_no_str, "Y") && strcmp (yes_no_str, "y"));
            *(week_range_str + 2)   = '\0';
            start_week_day_str      = week_range_str;
            end_week_day_str        = week_range_str + 3;

            *(hour_range_str + 2)   = '\0';
            start_hour_str          = hour_range_str;
            end_hour_str            = hour_range_str + 3;

            if (lcr && !def_route)
            {
                if (!complained)
                {
                    log_error ("ignoring %s in %s='%s' "
                               "since the circuit has no "
                               "default route and therefore can't be used "
                               "for least cost routing\n",
                               yes_no_str,
                               time_variables[times_idx], orig_val);
                    complained = 1;
                }
                lcr = 0;
            }
            if (check_a_time_value (times_idx, lcr,
                                    start_week_day_str, end_week_day_str,
                                    start_hour_str, end_hour_str) != OK)
            {
                return (ERR);
            }
        }
        else
        {
            log_error ("Error: format error in variable %s\n",
                       time_variables[times_idx]);
            return (ERR);
        }

        p = pp;
    } while (pp);

    free (orig_val);
    return check_local_time_table (times_idx);

} /* check_time_values (times_idx) */


/*----------------------------------------------------------------------------
 *  check_time_variables (void)
 *----------------------------------------------------------------------------
 */
static int
check_time_variables (void)
{
    char    varname[64];
    char *  p;
    int     n_time_variables    = 0;
    int     pppoe_used          = FALSE;
    int     is_pptp             = FALSE;
    int     n_isdn_circuits     = 0;
    int     times_idx;
    int     i;
    int     j;
    int     ret = OK;

    p = get_variable ("OPT_PPPOE");

    if (p && ! strcmp (p, "yes"))
    {
        pppoe_used = TRUE;
        n_time_variables++;
    }
    else
    {
        p = get_variable ("OPT_PPTP");

        if (p && ! strcmp (p, "yes"))
        {
            pppoe_used  = TRUE;
            is_pptp         = TRUE;
            n_time_variables++;
        }
    }

    p = get_variable ("OPT_ISDN");

    if (p && ! strcmp (p, "yes"))
    {
        n_isdn_circuits = atoi (get_variable ("ISDN_CIRCUITS_N"));
        n_time_variables += n_isdn_circuits;
    }

    if (n_time_variables == 0)
    {
        return (OK);
    }

    time_values     = (char **) malloc (n_time_variables * sizeof (char *));
    time_variables  = (char **) malloc (n_time_variables * sizeof (char *));

    for (i = 0; i < n_isdn_circuits; i++)
    {
        sprintf (varname, "ISDN_CIRC_%d_TIMES", i + 1);
        time_variables[i] = strsave (varname);
        p = get_variable (varname);
        time_values[i] = strsave (p ? p : "");
    }

    if (pppoe_used == TRUE)
    {
        if (is_pptp == TRUE)
        {
            time_variables[i] = strsave ("PPTP_TIMES");
            p = get_variable ("PPTP_TIMES");
            time_values[i] = strsave (p ? p : "");
        }
        else
        {
            time_variables[i] = strsave ("PPPOE_TIMES");
            p = get_variable ("PPPOE_TIMES");
            time_values[i] = strsave (p ? p : "");
        }
    }

    for (i = 0; i < DAYS_PER_WEEK; i++)
    {
        for (j = 0; j < HOURS_PER_DAY; j++)
        {
            time_table[i * HOURS_PER_DAY + j] = -1;
        }
    }

    for (times_idx = 0; times_idx < n_time_variables; times_idx++)
    {
        int def_route = 1;
        if (times_idx < n_isdn_circuits)
        {
            sprintf (varname, "ISDN_CIRC_%d_ROUTE", times_idx + 1);
            p = get_variable (varname);

            if (p && strcmp (p, "default") != 0 && strcmp (p, "0.0.0.0") != 0)
            {
                def_route = 0;              /* no lcr circuit, skip */
            }
        }

        if (check_time_values (times_idx, def_route) != OK)
        {
            ret = (ERR);
        }
    }

    return ret;
} /* check_time_variables () */

static void
check_external_opt (char * var, char * var1)
{
    char *          p, *q;
    char * tmp = strsave (var);

    p = strchr (tmp, '%');
    if (p)
    {
        *p = '1';
    }

    p = get_variable_package (tmp);
    if (p)
    {
        q = get_variable_package (var1);
        if (q && strcmp (q, "BASE") && strcmp(q, "_fli4l") &&
            strcmp(p, "_fli4l") && strcmp(p, q))
        {
            log_info (ZIPLIST, "external reference to '%s' ('%s') in '%s' "
                      "(variable '%s)\n",
                      var1, q, p, var);
        }
    }
    free (tmp);
}

/*----------------------------------------------------------------------------
 *  check_all_variables (void)
 *----------------------------------------------------------------------------
 */
int
check_all_variables (void)
{
    char *  opt_var_content;

    int     ret = OK;
    int     optional;

    ARRAY_ITER(array_iter, check_array, c, CHECK)
    {
        if (c->opt_var && ! c->var_n)
        {
            check_external_opt (c->name, c->opt_var);
            opt_var_content = get_variable (c->opt_var);

            if (! opt_var_content)
            {
                log_error ("variable %s depends on %s, which is not defined\n",
                           c->name, c->opt_var);
                return (ERR);
            }

            if (! strcmp (opt_var_content, "no"))
            {
                char * content = get_variable (c->name);

                if (! strncmp (c->name, "OPT_", 4) &&  /* optvar dependent ? */
                    content && ! strcmp (content, "yes"))
                {
                    printf ("Warning: %s='%s' ignored, because %s='no'\n",
                            c->name, content, c->opt_var);

                    set_variable_content (c->name, "no");
                }
            }
        }

        if (c->flags.really_optional)
        {
            optional = CHECK_REALLY_OPTIONAL;
        }
        else if (c->flags.optional)
        {
            optional = CHECK_OPTIONAL;
        }
        else
        {
            optional = CHECK_NON_OPTIONAL;
        }

        if (c->var_n)
        {
            int type = c->flags.type_numeric ? TYPE_NUMERIC : TYPE_UNKNOWN;
            check_external_opt (c->name, c->var_n);
            if (chkvar_idx (c->name, c->var_n, c->opt_var,
                            c->regexp_name, c->regexp,
                            c->package, type, optional, c->flags.neg_opt) != OK)
            {
                ret =  ERR;
            }
        }
        else
        {
            int type = c->flags.type_numeric ? TYPE_NUMERIC : TYPE_UNKNOWN;
            if (chkvar (c->name,
                        c->regexp_name, c->regexp,  c->package,
                        is_var_enabled(c->name, c->opt_var, c->flags.neg_opt),
                        type, optional, c->defval) != OK)
            {
                ret =  ERR;
            }
        }
    }

    if (check_time_variables () != OK)
    {
        return (ERR);
    }

    return ret;
} /* check_all_variables () */

void
free_check_variables ()
{
    ARRAY_ITER(array_iter, check_array, p, CHECK)
    {
        free (p->name);
        if (p->opt_var)
            free (p->opt_var);
        if (p->var_n)
            free (p->var_n);
        if (p->regexp)
            free (p->regexp);

    }
}

/*
Local Variables:
c-file-style: "linux"
c-basic-offset: 4
End:
*/
