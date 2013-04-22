#include "check.h"
#include "var.h"
#include "log.h"
#include "str.h"
#include "array.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define _free(x) do { free(x) ; (x) = 0; } while (0)
#define VAR_N_STACK_SIZE 32

typedef struct
{
    char * var_n_fmt;
    char * var_n;
    int max_index;
    int index;
    int state;
} var_n_stack_t;

typedef struct
{
    char * set_var;
    int enabled;
} set_var_t;

struct iter_t
{
    var_n_stack_t var_n_stack[VAR_N_STACK_SIZE];
    array_t * set_var_array;

    char * set_var_fmt;
    char * opt_var_fmt;
    int    set_var_state;
    int    opt_var_state;

    int    set_var_level;

    set_var_t * current;
    set_var_t * last;
};

static void set_var_init (struct iter_t *iter)
{
    iter->set_var_array = init_array (SET_VAR_ARRAY_SIZE, sizeof(set_var_t));
}

static int get_level (char * set_var)
{
    int level;
    char * p;

    for (level = 0, p = set_var; (p = strchr(p, '%'));  level++, p++)
        ; /* do nothing */
    return level;
}

static char * get_var_fmt (char * set_var)
{
    int level = get_level (set_var);
    char * fmt = safe_malloc (strlen(set_var) + level + 1);
    char * p = fmt;
    do {
        if (*set_var == '%') {
            *p++ = '%';
            *p++ = 'd';
        }
        else
            *p++ = *set_var;
    } while (*set_var++);
    return fmt;
}
static char * gen_set_var (struct iter_t * iter, char * set_var_fmt)
{
    char buf[1024];
    if (set_var_fmt) {
        sprintf(buf,
                set_var_fmt,
                iter->var_n_stack[0].index,
                iter->var_n_stack[1].index,
                iter->var_n_stack[2].index);
        assert(strlen(buf) < 1024);
        return strsave(buf);
    }
    return 0;
}

int get_last_index (struct iter_t * iter)
{
    return iter->current - (set_var_t *)get_first_elem(iter->set_var_array) + 1;
}

void end_set_var_iteration (struct iter_t * iter)
{
    int i;
    set_var_t * p;

    if (iter->current) {
        for (p = get_first_elem (iter->set_var_array); p <= iter->last; p++) {
            _free(p->set_var);
        }
        reset_array(iter->set_var_array);
    }

    for (i=0; i<iter->set_var_level; i++)
        _free(iter->var_n_stack[i].var_n_fmt);

    _free (iter->set_var_fmt);
    _free (iter->opt_var_fmt);
    free_array(iter->set_var_array);
    _free(iter);
}

static int iterate (struct iter_t * iter, int level, int enabled, int neg)
{
    int max;

    char * var_n;
    char * val;

    var_n_stack_t * s;

    if (level == iter->set_var_level) {
        char * set_var = gen_set_var (iter, iter->set_var_fmt);
        char * opt_var = gen_set_var (iter, iter->opt_var_fmt);
        set_var_t * p = get_new_elem (iter->set_var_array);

        *p = (set_var_t){set_var, is_var_enabled (set_var, opt_var, neg) };

        _free(opt_var);

        return 0;
    }

    s = & iter->var_n_stack[level];
    var_n = gen_set_var (iter, s->var_n_fmt);
    val = get_variable (var_n);
    if (val) {
        max = atoi(val);
        for (s->index = 1; s->index<=max; s->index++)
            iterate(iter, level+1, 1, neg);
    }
    iter->current = get_first_elem(iter->set_var_array);;
    iter->last = get_last_elem(iter->set_var_array);
    return 0;
}
struct iter_t * init_set_var_iteration (char * set_var, char * opt_var, int neg)
{
    struct iter_t * iter = (struct iter_t *)safe_malloc(sizeof(struct iter_t));
    int level = get_level (set_var);
    char * var_n;
    char * p = set_var;

    int l;
    if (! level)
    {
        fatal_exit ("BUG: init_set_var_iteration called "
                    "for non set variable %s\n", set_var);
    }
    set_var_init(iter);

    for (l = level; l--; ) {
        var_n = check_get_var_n (p);
        if (!var_n)
        {
            free(iter);
            return 0;
        }
        iter->var_n_stack[l].state = check_var_optional_state(var_n);
        iter->var_n_stack[l].var_n_fmt = get_var_fmt (var_n);
        iter->var_n_stack[l].index = 0;
        iter->var_n_stack[l].max_index = 0;
        p = var_n;
    }


    iter->set_var_level = level;
    iter->set_var_fmt = get_var_fmt (set_var);
    iter->opt_var_fmt = opt_var ? get_var_fmt (opt_var) : 0;
    iter->set_var_state = check_var_optional_state(set_var);
    iter->opt_var_state = opt_var ? check_var_optional_state(opt_var) : CHECK_NON_OPTIONAL;

    iterate (iter, 0, 0, neg);

    return iter;
}

char * get_next_set_var (struct iter_t * iter, int * enabled)
{
    if (iter->current && iter->current <= iter->last) {
        char * name = iter->current->set_var;
        * enabled = iter->current->enabled;
        iter->current++;
        log_info (VAR, "get_next_set_var: %s (%s)\n", name,
                  *enabled ? "enabled" : "disabled");

        return name;
    }
    return 0;
}

