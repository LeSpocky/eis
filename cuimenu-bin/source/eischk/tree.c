#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "log.h"
#include "str.h"
#include "parse.h"
#include "var.h"
#include "check.h"
#include "tree_struct.h"
#include "tree.h"
#include "tree_debug.h"
#include "y.tab.h"

#define ARG_STRING      1
#define ARG_NUM         2
#define ARG_VER         4
#define ARG_ID          8
#define ARG_WEAK        16

void    walk_node (elem_t * p);
int     walk_condition (elem_t * p, char * file, int line);

void    foreach_idset (elem_t * p);
void    foreach_idset_set (elem_t * p);
void    foreach_id (elem_t * p);
void    assign (elem_t * p);

unsigned long get_numeric_value (elem_t * p);
char *  numeric_op (elem_t * p);
void    split (elem_t * p, int type);

typedef unsigned long u32;

int     my_inet_aton (const char * cp, u32 * s_addr);
int     get_netmask_bits (u32 mask, char * file, int line);
u32     get_netmask (int netmask_bits);
void    normalize_network (char * network, u32 * ip, int * netmask_bits,
                           char * file, int line);


int     cond_id (elem_t * p);
int     cond_copy_pending (elem_t * p);
int     cond_unique (elem_t * p, char * file, int line);
int     cond_defined (elem_t * p, char * file, int line);
int     cond_match (elem_t * p);
int     cond_relop (elem_t * p, char * file, int line);
int     cond_sub_net (elem_t * p, char * file, int line);
int     cond_same_net (elem_t * p, char * file, int line);
int     cond_valid_ip (elem_t * p, char * file, int line);

char *  elem_get_set_name_type (elem_t *p, int * type);
char *  elem_get_set_name (elem_t *p);
char *  elem_get_name_type (elem_t * p, int * type);
char *  elem_get_name (elem_t * p);
char *  elem_get_arg (elem_t * p, int * type);

static elem_t parse_tree;
static elem_t * current_node = &parse_tree;
static void assert_numeric (elem_t * p, char * file, int line);


/************************************
 *
 * Functions used to build parse tree
 *
 ************************************/
elem_t * mknode (int op, elem_t * arg1, elem_t * arg2, elem_t * arg3, int line)
{
    elem_t * p = (elem_t *)malloc (sizeof (elem_t));
    if (!p)
    {
        fatal_exit ("out of memory in mknode\n");
    }

    p->type = NODE;
/*     p->ln.node = ((node_t){op, {arg1, arg2, arg3}}); */
    p->OP = op;
    p->ARG[0] = arg1;
    p->ARG[1] = arg2;
    p->ARG[2] = arg3;
    p->file = parse_get_current_file ();
    p->package = parse_get_current_package ();
    p->line = line;
    p->next = NULL;

    log_info (T_BUILD, "creating node for %s (%d)\n", get_op_name (op), op);
    dump_elem (T_BUILD, p);

    return p;
}

elem_t * mkleaf (int type, char * value)
{
    elem_t * p = (elem_t *)malloc (sizeof (elem_t));
    if (!p)
    {
        fatal_exit ("out of memory in mkleaf\n");
    }

    p->type = LEAF;
    p->TYPE = type;
    p->file = parse_get_current_package ();
    p->line = yyline;
    p->next = NULL;

    switch (type)
    {
    case ID:
    case IDSET:
        p->VAL = strsave (convert_to_upper (value));
        break;
    case STRING:
        p->VAL = strsave_quoted (value);
        break;
    default:
        p->VAL = strsave (value);
    }
    log_info (T_BUILD, "creating leaf for %s = %s\n", get_op_name (type), p->VAL);
    dump_elem (T_BUILD, p);
    return p;
}

elem_t * add_node (elem_t * node1, elem_t * node2)
{
    elem_t * p = node1;

    while (p->next)
    {
        p = p->next;
    }
    log_info (T_BUILD, " appending %s to %s\n", get_op_name (node2->ln.node.op),
              get_op_name (p->ln.node.op));
    p->next = node2;
    return node1;
}

void    add_script (elem_t * node)
{
    current_node->next = mknode (SCRIPT, node, 0, 0, 0);
    current_node = current_node->next;
}

/****************************************************
 *
 * Helper functions used to handle function arguments
 *
 ****************************************************/

static void assert_numeric (elem_t * p, char * file, int line)
{
    char * name;
    int numeric;
    int type;
    int weak = 0;

    name = elem_get_name_type (p, &type);
    numeric = type & ARG_NUM;

    if (! numeric)
    {
        dump_elem (T_EXEC|INFO, p);
        if (weak)
        {
            fatal_exit ("(%s:%d) You can't use a non numeric id "
                        "in a numeric context.\n"
                        "\tIf the temporary variable %s "
                        "should be a numeric id,\n"
                        "\tassign a numeric value or a numeric ID to it.h\n",
                        file, line, name);

        }
        else
        {
            fatal_exit ("(%s:%d) You can't use a non numeric id "
                        "in a numeric context.\n"
                        "\tIf this should be a numeric id, specify a numeric "
                        "type \n\tfor variable '%s' in %s\n",
                        file, line, name, file);
        }
    }
}

/*
 * two possible cases:
 * var_%[id] -- a node with two leafes
 *      - first leaf set var name
 *      - leaf or node representing the index
 *      for instance foo_a_%[1]:
 *              node IDSET
 *                      leaf IDSET=FOO_A_%
 *                      leaf NUM=1
 *
 * var_%_%[id][id]... a node with one or two nodes
 *      for instance foo_a_%_b_%[1][1]:
 *              node IDSET
 *                      node IDSET
 *                              leaf IDSET=FOO_A_%_B_%
 *                              leaf NUM=1
 *                      leaf NUM=1
 */
char * elem_get_set_name (elem_t *p)
{
    int dummy;
    return elem_get_set_name_type (p, &dummy);
}

char * elem_get_set_name_type (elem_t *p, int * type)
{
    int    t;
    char * ret;
    char * set_var;
    char * index = elem_get_arg (p->ARG[1], &t);

    if ((t & ARG_NUM) == 0)
    {
        fatal_exit ("(%s:%d)You can't use a non numeric id "
                    "in a numeric context. Check type of '%s'.\n",
                    p->file, p->line, elem_get_name (p->ARG[1]));
    }
    if (p->ARG[0]->type == LEAF)
    {
        *type = ARG_ID;
        if (check_var_numeric (p->ARG[0]->VAL))
        {
            log_info (T_EXEC, "%s is numeric\n", p->ARG[0]->VAL);
            *type |= ARG_NUM;
        }
        ret = get_set_var_name_string (p->ARG[0]->VAL, index,
                                       p->file, p->line);
    }
    else
    {
        /* recursively descend until we reach a leaf */
        inc_log_indent_level ();
        set_var = elem_get_set_name_type (p->ARG[0], type);
        ret = get_set_var_name_string (set_var, index,
                                       p->file, p->line);
        dec_log_indent_level ();
    }

    free (index);
    log_info (T_EXEC, "elem_get_set_name returning '%s' (%s)\n",
              ret, *type & ARG_NUM ? "numeric" : "non numeric");
    return ret;
}

char * elem_get_name (elem_t * p)
{
    int dummy;
    return elem_get_name_type (p, &dummy);
}
char * elem_get_name_type (elem_t * p, int * type)
{
    char * ret;

    *type = 0;
    if (p->type == LEAF)
    {
        switch (p->TYPE)
        {
        case ID:
        case IDSET:
            ret =  strsave (p->VAL);
            *type = ARG_ID | check_var_numeric (p->VAL) ? ARG_NUM : 0;
            break;
        case STRING:
            ret =  parse_rewrite_string (p->VAL, p->file, p->line);
            break;
        default:
            fatal_exit ("(%s:%d): invalid argument type %s\n",
                        __FILE__, __LINE__, get_op_name (p->TYPE));
        }
    }
    else if (p->OP == IDSET)
    {
        ret = elem_get_set_name_type (p, type);
    }
    else
    {
        fatal_exit ("(%s:%d): invalid argument type %s\n",
                    __FILE__, __LINE__, get_op_name (p->TYPE));
    }

    log_info (T_EXEC, "(%s:%d) returns '%s' (%s)\n",
              __FILE__, __LINE__, ret,
              *type & ARG_NUM ? "numeric" : "non numeric");
    return ret;

}

char * elem_get_arg (elem_t * p, int * type)
{
    char * name = NULL;
    if (p->type == LEAF)
    {
        switch (p->TYPE)
        {
        case STRING:
            *type = ARG_STRING;
            return parse_rewrite_string (p->VAL, p->file, p->line);
        case NUM:
            *type = ARG_NUM;
            return strsave (p->VAL);
        case VER:
            *type = ARG_VER;
            return strsave (p->VAL);
        case ID:
            name = strsave (p->VAL);
            break;
        }
    }
    else
    {
        switch (p->OP)
        {
        case IDSET:
            name = elem_get_name (p);
            break;
        case ADD:
        case SUB:
        case MULT:
        case DIV:
        case MOD:
            *type = ARG_NUM;
            return numeric_op (p);
        default:
            fatal_exit ("(%s:%d) unexpected op '%s' in elem_get_arg\n",
                        __FILE__, __LINE__, get_op_name (p->OP));
        }
    }
    if (name)
    {
        char * ret = parse_get_variable (name, p->file, p->line);
        if (is_var_numeric (name))
        {
            log_info (T_EXEC, "(%s:%d): numeric id %s found\n",
                      __FILE__, __LINE__, name);
            *type = ARG_NUM | ARG_ID;
        }
        else
        {
            *type = ARG_STRING | ARG_ID;
        }
        free (name);
        return strsave (ret);
    }
    fatal_exit ("(%s:%d): unexpected argument %s\n",
                __FILE__, __LINE__, get_op_name (p->OP));
}

/****************************************
 *
 * Functions used to implement iterations
 *
 ****************************************/

void foreach_idset (elem_t * p)
{
    char index_buf[32];
    char * set_var;
    int dummy;
    struct iter_t * iter;


    log_info (T_EXEC, "%s: foreach_idset %s in %s (line: %d)\n",
              get_op_name (p->OP),  p->ARG[0]->VAL, p->ARG[1]->VAL, p->line);

    if (! (iter = init_set_var_iteration (p->ARG[1]->VAL, "BASE", 0)))
      fatal_exit ("%s:%d: Unable to get var_n for variable %s\n", p->file, p->line, p->ARG[1]->VAL);

    while ((set_var = get_next_set_var (iter, &dummy)))
    {
        char * val = get_variable (set_var);
        if (!val)
        {
            if (check_var_really_optional (p->ARG[1]->VAL))
            {
                log_info (T_EXEC, "%s: skipping '%s', "
                          "'%s' optional and undefined\n",
                          get_op_name (p->OP),  set_var, p->ARG[1]->VAL);
                continue;
            }
            else
            {
                fatal_exit ("unknown variable '%s' in %s, line %d\n",
                            set_var, p->file, p->line);

            }
        }
        sprintf (index_buf, "%d", get_last_index (iter));
        log_info (T_EXEC, "%s: executing loop using %s='%s'\n",
                  get_op_name (p->OP),  p->ARG[0]->VAL, val);
        inc_log_indent_level ();
        var_add_weak_declaration (set_var, p->ARG[0]->VAL,
                                  val, index_buf,
                                  is_var_numeric (set_var) ?
                                  TYPE_NUMERIC : TYPE_UNKNOWN,
                                  p->file, p->line, T_EXEC);
        walk_node (p->ARG[2]);
        dec_log_indent_level ();
    }
    end_set_var_iteration (iter);
}

void foreach_idset_set (elem_t *p)
{
    elem_t e = *p;
    p = p->ARG[1];
    while (p)
    {
        e.ARG[1] = p->ARG[0];
        foreach_idset (&e);
        p = p->ARG[2];
    }
}
void foreach_id (elem_t * p)
{
    int index;
    int max_index;
    char index_buf[32];

    char * val = parse_get_variable (p->ARG[1]->VAL, p->file, p->line);

    log_info (T_EXEC, "%s: foreach_id %s in %s (line: %d)\n",
              get_op_name (p->OP),  p->ARG[0]->VAL, p->ARG[1]->VAL, p->line);

    assert_numeric (p->ARG[1], p->file, p->line);

    max_index = convert_to_long (val, p->file, p->line);

    for(index=1; index <= max_index; index++)
    {
        int current_index;
        sprintf (index_buf, "%d", index);
        log_info (T_EXEC, "%s: executing loop using %s='%s'\n",
                  get_op_name (p->OP),  p->ARG[0]->VAL, index_buf);
        inc_log_indent_level ();
        var_add_weak_declaration ("not a set variable", p->ARG[0]->VAL,
                                  index_buf, index_buf, TYPE_NUMERIC,
                                  p->file, p->line, T_EXEC);
        walk_node (p->ARG[2]);
        dec_log_indent_level ();
        val = parse_get_variable (p->ARG[0]->VAL, p->file, p->line);
        current_index = convert_to_long (val, p->file, p->line);

        if (index != current_index)
        {
            log_info (T_EXEC, "changing loop variable from %d to %d\n",
                      index, current_index);
            index = current_index;
        }
    }
}

/***************************
 *
 * numeric_op
 *
 ***************************/
unsigned long get_numeric_value (elem_t * p)
{
    char * val;
    int    type;

    val = elem_get_arg (p, &type);
    if (! (type & ARG_NUM))
    {
        fatal_exit ("(%s:%d)You can't use a non numeric id "
                    "in a numeric context. Check type of operand.\n",
                    p->file, p->line);
    }
    return  convert_to_long (val, p->file, p->line);
}

char * numeric_op (elem_t * p)
{
    unsigned long x, y, res;
    char buf[32];

    x = get_numeric_value (p->ARG[0]);
    y = get_numeric_value (p->ARG[1]);
    switch (p->OP)
    {
    case ADD:
        res = x + y;
        break;
    case SUB:
        res = x - y;
        break;
    case MULT:
        res = x * y;
        break;
    case DIV:
        if (y == 0)
        {
            fatal_exit ("(%s:%d) divide by zero\n", p->file, p->line);
        }
        res = x / y;
        break;
    case MOD:
        if (y == 0)
        {
            fatal_exit ("(%s:%d) divide by zero\n", p->file, p->line);
        }
        res = x % y;
        break;
    default:
        fatal_exit ("(%s:%d) unknown operation\n", p->file, p->line);
    }
    sprintf (buf, "%lu", res);
    return strsave (buf);
}
/***************************
 *
 * assign
 *
 ***************************/
void assign (elem_t * p)
{
    char * val;
    char * var;
    char * var_n;
    int type = 0;

    if (!p->ARG[1])
    {
        val = strsave ("yes");
    }
    else
    {
        val = elem_get_arg (p->ARG[1], &type);
    }

    if (p->ARG[0]->TYPE == ID)
    {
        var = strsave (p->ARG[0]->VAL);
    }
    else
    {
        var = p->ARG[0]->VAL;
        if (!check_var_defined (var))
        {
            check_add_weak_declaration ("internal", var, "0",
                                        &var_n, p->file, p->line, T_EXEC);
        }
        else
        {
            if (!check_var_weak (var))
            {
                fatal_exit ("(%s:%d) trying to overwrite config variable %s\n",
                            p->file, p->line, var);
            }
            var_n = get_set_var_n (var);
        }
        if (! (type & ARG_NUM))
        {
            fatal_exit ("(%s:%d) non numeric index\n",
                        p->file, p->line);

        }
        if (val_numcmp (get_variable (var_n), val,
                        p->ARG[1]->file, p->ARG[1]->line) == CMP_LESS)
        {
            set_variable_content (var_n, val);
        }
        var = get_set_var_name_string (var, val,
                                       p->ARG[1]->file, p->ARG[1]->line);
        val = elem_get_arg (p->ARG[2], &type);
    }

    var_add_weak_declaration ("internal variable defined by assign command",
                              var, val, val,
                              type & ARG_NUM ? TYPE_NUMERIC : TYPE_UNKNOWN,
                              p->file, p->line, T_EXEC);
    free (var);
}
/***************************
 *
 * split
 *
 ***************************/
void split (elem_t * e, int type)
{
    char * arg;
    char * var;
    char * var_n;
    char   c;

    char buf[32];
    char *p;
    char *set_var;
    int i = 0;
    int dummy;

    arg = p = elem_get_arg (e->ARG[0], &dummy);
    var = e->ARG[1]->VAL;
    c = e->ARG[2]->VAL[1];
    strcpy (buf, "0");

    if (!check_var_defined (var))
    {
        check_add_weak_declaration ("internal", var, "0",
                                    &var_n, e->file, e->line, T_EXEC);
    }
    else
    {
        var_n = get_set_var_n (var);
    }

    while (*p)
    {
        char *q = p;
        char *sub = p;

        if (c == ' ')
        {
            while (*q && !isspace (*q))
            {
                q++;
            }
            if (*q && *(q+1) && isspace (*(q+1)))
            {
                *q = '\0';
                while (*(q+1) && isspace (*(q+1)))
                {
                    q++;
                }

            }
        }
        else
        {
            while (*q && *q != c)
            {
                q++;
            }
        }
        if (*q)
        {
            p = q+1;
        }
        else
        {
            p=q;
        }
        *q = '\0';

        i++;
        set_var = get_set_var_name_int (var, i, e->file, e->line);
        sprintf (buf, "%d", i);
        var_add_weak_declaration (var, set_var, sub, buf,
                                  type, e->file, e->line, T_EXEC);
    }
    log_info (T_EXEC, "setting %s to '%s'\n", var_n, buf);
    if (set_variable_content (var_n, buf) != OK)
    {
        fatal_exit ("(%s:%d) unexpected error while setting value of %s\n",
                    __FILE__, __LINE__, var_n);
    }
}

/****************************************************
 *
 * Execute a script by recursively walking the parse tree
 *
 ****************************************************/

void walk_node (elem_t * p)
{
    if (!p)
    {
        log_info (T_EXEC, "empty tree\n");
    }
    while (p)
    {
        expect_node (p, __LINE__, -1, 0);
        switch (p->OP)
        {
        case WARNING:
            expect_types (p, LEAF, NONE, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_warning (p->ARG[0]->VAL, p->file, p->line);
            break;
        case ERROR:
            expect_types (p, LEAF, NONE, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_error (p->ARG[0]->VAL, p->file, p->line);
            break;
        case FATAL_ERROR:
            expect_types (p, LEAF, NONE, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_fatal_error (p->ARG[0]->VAL, p->file, p->line);
            break;
        case ADD_TO_OPT:
            expect_types (p, LEAF, LEAF|OPT, NONE, __LINE__);
            if (p->ARG[1])
            {
                log_info (T_EXEC, "%s: \"%s\" \"%s\" (line: %d)\n",
                          get_op_name (p->OP), p->ARG[0]->VAL,
                          p->ARG[1]->VAL, p->line);
                parse_add_to_opt (p->ARG[0]->VAL, p->ARG[1]->VAL,
                                  p->file, p->line);
            }
            else
            {
                log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                          get_op_name (p->OP), p->ARG[0]->VAL,
                          p->line);
                parse_add_to_opt (p->ARG[0]->VAL, 0,
                                  p->file, p->line);

            }
            break;
        case FGREP:
            expect_types (p, LEAF, LEAF, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_fgrep (p->ARG[0]->VAL, p->ARG[1]->VAL, p->file, p->line);
            break;
        case STAT:
            expect_types (p, LEAF, LEAF, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_stat (p->ARG[0]->VAL, p->ARG[1]->VAL, p->file, p->line);
            break;
        case CRYPT:
            expect_types (p, SOMETHING, NONE, NONE, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            parse_crypt (elem_get_name(p->ARG[0]), p->file, p->line);
            break;
        case SPLIT:
        case SPLIT | SPLIT_NUMERIC:
            expect_types (p, SOMETHING, LEAF, LEAF, __LINE__);
            log_info (T_EXEC, "%s: \"%s\" (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            split (p, p->OP & SPLIT_NUMERIC ? TYPE_NUMERIC : TYPE_UNKNOWN);
            break;
        case PROVIDES:
            expect_types (p, LEAF, LEAF, NONE, __LINE__);
            log_info (T_EXEC, "%s: '%s' version '%s' (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->ARG[1]->VAL,
                      p->line);
            parse_provides (p->ARG[0]->VAL,  p->ARG[1]->VAL, p->file, p->line);
            break;
        case DEPENDS:
            expect_types (p, LEAF, LEAF, NONE, __LINE__);
            log_info (T_EXEC, "%s: on '%s' version '%s' (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->ARG[1]->VAL,
                      p->line);
            parse_depends (p->ARG[0]->VAL,  p->ARG[1]->VAL, p->package,
                           p->ARG[1]->OP == VER_EXPR, p->file, p->line);
            break;
        case IF:
            expect_types (p, NODE, NODE, NODE|OPT, __LINE__);
            log_info (T_EXEC, "IF: checking condition... (line: %d)\n", p->line);
            inc_log_indent_level ();
            if (walk_condition (p->ARG[0], p->file, p->line))
            {
                dec_log_indent_level ();
                log_info (T_EXEC, "IF: executing then statements (line: %d)\n",
                          p->ARG[1]->line);
                inc_log_indent_level ();
                walk_node (p->ARG[1]);
            }
            else
            {
                dec_log_indent_level ();
                if (p->ARG[2])
                {
                    log_info (T_EXEC, "IF: executing else statements"
                              "(line: %d)\n", p->ARG[2]->line);
                    inc_log_indent_level ();
                    walk_node (p->ARG[2]);
                }
                else
                {
                    log_info (T_EXEC, "IF: empty else statement\n");
                    inc_log_indent_level ();
                }
            }
            dec_log_indent_level ();
            break;
        case FOREACH:
            expect_types (p, LEAF, SOMETHING, NODE, __LINE__);
            if (p->ARG[1]->type == LEAF)
            {
                if (p->ARG[1]->TYPE == IDSET)
                {
                    foreach_idset (p);
                }
                else
                {
                    foreach_id (p);
                }
            }
            else
            {
                foreach_idset_set (p);
            }
            break;
        case ASSIGN:
            expect_types (p, SOMETHING, SOMETHING|OPT, SOMETHING|OPT, __LINE__);
            log_info (T_EXEC, "%s: '%s' (line: %d)\n",
                      get_op_name (p->OP), p->ARG[0]->VAL, p->line);
            assign (p);
            break;
        case SCRIPT:
            expect_types (p, NODE, NONE, NONE, __LINE__);
            log_info (INFO|T_EXEC, "executing extended checks in %s\n", p->file);
            inc_log_indent_level ();
            walk_node (p->ARG[0]);
            dec_log_indent_level ();
            break;
        default:
            printf ("(%s:%d) unknown case: %d:  (%s)\n",
                    __FILE__, __LINE__, p->OP, get_op_name (p->OP));
        }
        p = p->next;
        if (p && p->OP != SCRIPT)
            log_info (T_EXEC, "choosing next statement\n");
    }
}

/***************************
 *
 * condition implementations
 *
 ***************************/
int cond_id (elem_t * p)
{
    int ret;
    char * val;
    char * name;

    expect_types (p, SOMETHING, NONE, NONE, __LINE__);
    if (p->ARG[0]->TYPE != ID && p->ARG[0]->TYPE != IDSET)
    {
        fatal_exit ("(%s:%d) impossible boolean expression: "
                    "if ( %s ) then...\n",
                    p->ARG[0]->file, p->ARG[0]->line,
                    get_op_name (p->ARG[0]->TYPE));
    }

    name = elem_get_name (p->ARG[0]);
    log_info (T_EXEC, "%s: %s == '%s'\n",
              get_op_name (p->OP), get_op_name (p->ARG[0]->TYPE), name);
    val = get_variable (name);
    if (!val)
    {
        ret = 0;
    }
    else
    {
        ret = !strcmp (val, "yes");
    }

    log_info (T_EXEC, "%s: returning %s (%s = '%s')\n",
              get_op_name (p->OP), ret ? "true" : "false",
              name, val ? val : "undefined");
    free (name);
    return ret;
}

int cond_copy_pending (elem_t * p)
{
    int ret;
    char * name;

    expect_types (p, SOMETHING, NONE, NONE, __LINE__);

    name = elem_get_name (p->ARG[0]);

    log_info (T_EXEC, "%s: %s == '%s'\n",
              get_op_name (p->OP), get_op_name (p->ARG[0]->TYPE), name);
    ret = is_var_copy_pending (name);
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP), ret ? "true" : "false");
    free (name);
    return ret;
}

int cond_unique (elem_t * p, char * file, int line)
{
    int ret;
    char * name;

    expect_types (p, SOMETHING, NONE, NONE, __LINE__);

    name = elem_get_name (p->ARG[0]);

    log_info (T_EXEC, "%s: %s == '%s'\n",
              get_op_name (p->OP), get_op_name (p->ARG[0]->TYPE), name);
    ret = is_var_unique (name, file, line);
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP), ret ? "true" : "false");
    free (name);
    return ret;
}

int
my_inet_aton (const char * cp, u32 * s_addr)
{
        unsigned long addr;
        int value;
        int part;

        addr = 0;
        for (part = 1; part <= 4; part++) {

                if (!isdigit(*cp))
                        return 0;

                value = 0;
                while (isdigit(*cp)) {
                        value *= 10;
                        value += *cp++ - '0';
                        if (value > 255)
                                return 0;
                }

                if (part < 4) {
                        if (*cp++ != '.')
                                return 0;
                } else {
                        char c = *cp++;
                        if (c != '\0' && !isspace(c))
                        return 0;
                }

                addr <<= 8;
                addr |= value;
        }

        *s_addr = addr;

        return 1;
}

int
get_netmask_bits (u32 mask, char * file, int line)
{
  int mbits = 0;

  if(mask == 0xFFFFFFFF)
  {
      return (32);
  }
  else
  {
      int i;
      unsigned long comp = 0x80000000UL;

      for (i=1; i < 32; i++, comp >>= 1)
      {
          if ((mask & comp) == 0)
          {
              mbits = mbits ? mbits : i-1;
          }
          else
          {
              if (mbits)
              {
                  return 0;
              }
          }
      }
      return mbits;
  }
}

u32 get_netmask (int netmask_bits)
{
    u32 bit = 0x80000000UL;
    u32 nm = 0;

    for (; netmask_bits; netmask_bits--, bit >>=1)
        nm |= bit;
    return nm;
}

void
normalize_network (char * network, u32 * ip, int * netmask_bits,
                   char * file, int line)
{
    const char delim[3] = {'/', ':', ' '};
    u32 netmask = 0;

    char * nm = 0;
    int i;

    *netmask_bits=32;

    for(i=0; i < 3 && !nm; i++)
    {
        nm = strchr(network, delim[i]);
    }
    if (nm)
    {
        *nm++ = '\0';
        if (strchr (nm, '.'))
        {
            if (!my_inet_aton (nm, &netmask))
                fatal_exit ("%s:%d : Invalid netmask %s\n", file, line, nm);
            *netmask_bits = get_netmask_bits(netmask, file, line);
        }
        else
        {
            sscanf (nm, "%d", netmask_bits);
            if (netmask < 0 || netmask > 32)
                fatal_exit ("%s:%d : Invalid netmask '/%s'\n", file, line,
                            network);
        }
    }
    netmask = get_netmask (*netmask_bits);

    if (!my_inet_aton (network, ip))
        fatal_exit ("%s:%d : Invalid ip address %s\n", file, line, network);

    *ip &= netmask;
}
int cond_same_net (elem_t * p, char * file, int line)
{
    int ret;
    int dummy;
    char * left_net, * right_net;
    u32 left_ip, right_ip;
    int left_netmask_bits, right_netmask_bits;

    expect_types (p, SOMETHING, SOMETHING, NONE, __LINE__);


    left_net = parse_rewrite_string (elem_get_arg (p->ARG[0], &dummy),
                                     file, line);
    right_net = parse_rewrite_string (elem_get_arg (p->ARG[1], &dummy),
                                      file, line);
    log_info (T_EXEC, "%s: '%s' == '%s'\n",
              get_op_name (p->OP), left_net, right_net);
    normalize_network (left_net, &left_ip, &left_netmask_bits, file, line);
    normalize_network (right_net, &right_ip, &right_netmask_bits, file, line);

    ret = left_ip == right_ip && left_netmask_bits == right_netmask_bits;
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP), ret ? "true" : "false");

    free (left_net);
    free (right_net);
    return ret;
}

int cond_valid_ip (elem_t * p, char * file, int line)
{
    int ret;
    int dummy;
    char * net;
    u32 ip, netmask, inverted_netmask;
    int netmask_bits;

    expect_types (p, SOMETHING, NONE, NONE, __LINE__);

    net = parse_rewrite_string (elem_get_arg (p->ARG[0], &dummy),
                                file, line);
    log_info (T_EXEC, "%s: '%s'\n",
              get_op_name (p->OP), net);
    normalize_network (net, &ip, &netmask_bits, file, line);
    my_inet_aton (net, &ip);
    netmask = get_netmask (netmask_bits);
    inverted_netmask = ~netmask;

    ret = inverted_netmask != (ip & inverted_netmask);
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP), ret ? "true" : "false");

    free (net);
    return ret;
}

int cond_sub_net (elem_t * p, char * file, int line)
{
    int ret;
    int dummy;
    char * left_net, * right_net;
    u32 left_ip, right_ip;
    int left_netmask_bits, right_netmask_bits;

    expect_types (p, SOMETHING, SOMETHING, NONE, __LINE__);


    left_net = parse_rewrite_string (elem_get_arg (p->ARG[0], &dummy),
                                     file, line);
    right_net = parse_rewrite_string (elem_get_arg (p->ARG[1], &dummy),
                                      file, line);
    log_info (T_EXEC, "%s: '%s' subnet of '%s'\n",
              get_op_name (p->OP), right_net, left_net);
    normalize_network (left_net, &left_ip, &left_netmask_bits, file, line);
    normalize_network (right_net, &right_ip, &right_netmask_bits, file, line);

    if (right_netmask_bits <= left_netmask_bits)
    {
        u32 nm = get_netmask (right_netmask_bits);
        left_ip &= nm;
        ret = left_ip == right_ip;
    }
    else
    {
        ret = 0;
    }
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP), ret ? "true" : "false");
    free (left_net);
    free (right_net);
    return ret;
}

int cond_defined (elem_t * p, char * file, int line)
{
    char * name = NULL;

    int ret = 0;

    expect_types (p, SOMETHING, NONE, NONE, __LINE__);
    p = p->ARG[0];

    dump_elem (T_EXEC, p);
    if (p->type == LEAF)
    {
        switch (p->TYPE)
        {
        case STRING:
            name = parse_rewrite_string (p->VAL, file, line);
            break;
        case ID:
            name = strsave (p->VAL);
            break;
        }
        log_info (T_EXEC, "DEFINED: %s '%s'\n",
                  get_op_name (p->TYPE), name);

        if (get_variable(name) && !is_var_generated (name))
        {
            ret = 1;
        }
        else
        {
#if 0
            if (!check_var_defined (name))
            {
                fatal_exit ("unknown variable '%s' in %s, line %d\n",
                            name, file, line);

            }
#endif
            ret = 0;
        }
        free (name);
    }
    else if (p->OP == IDSET)
    {
        name = elem_get_name (p);

        log_info (T_EXEC, "DEFINED: %s '%s'\n",
                  get_op_name (p->TYPE), name);

        if (get_variable(name) && !is_var_generated (name))
        {
            ret = 1;
        }
        else
        {
#if 0
            char * pure_set_var = replace_set_var_indices (name);
            log_info (INFO, "checking %s\n", pure_set_var);
            if (!check_var_defined (pure_set_var))
            {
                fatal_exit ("unknown variable '%s' in %s, line %d\n",
                            pure_set_var, file, line);
            }
#endif
            ret = 0;
        }
        free (name);

    }
    else
    {
        fatal_exit ("(%s:%d) unexpected argument %s\n",
                    __FILE__, __LINE__, get_op_name (p->OP));
    }
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP),
              ret ? "true" : "false");
    return ret;
}

int cond_match (elem_t * p)
{
    int ret;
    char * name;
    char * val;
    char * regexp;

    expect_types (p, SOMETHING, LEAF, NONE, __LINE__);

    name = elem_get_name (p->ARG[0]);
    val = parse_get_variable (name, p->file, p->line);
    regexp = elem_get_name (p->ARG[1]);

    log_info (T_EXEC, "%s: left hand %s == '%s', right hand %s == '%s'\n",
              get_op_name (p->OP),
              get_op_name (p->ARG[0]->TYPE), val,
              get_op_name (p->ARG[1]->TYPE), regexp);

    ret = str_strmatch (val, regexp, p->file, p->line);

    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP),
              ret ? "true" : "false");

    free (name);
    free (regexp);
    return ret;
}

/* ID|IDSET rel ID|IDSET
   ID|IDSET rel STRING
   ID|IDSET rel NUM
   ID|IDSET rel VER
*/
int cond_relop (elem_t * p, char * file, int line)
{
    char * left_val;
    char * right_val;
    int left_type;
    int right_type;
    int arg_types;
    int ret = 5;

    expect_types (p, SOMETHING, SOMETHING, NONE, __LINE__);

    left_val  = elem_get_arg (p->ARG[0], &left_type);
    right_val = elem_get_arg (p->ARG[1], &right_type);
    arg_types = (left_type | right_type) & (ARG_NUM | ARG_STRING | ARG_VER);

    log_info (T_EXEC, "%s: left hand %s == '%s', right hand %s == '%s'\n",
              get_op_name (p->OP),
              get_op_name (p->ARG[0]->TYPE), left_val,
              get_op_name (p->ARG[1]->TYPE), right_val);

    switch (arg_types)
    {
    case 1:
        ret = strcmp (left_val, right_val);
        if (ret < 0)
        {
            ret = CMP_LESS;
        }
        else if (ret > 0)
        {
            ret = CMP_GREATER;
        }
        log_info (T_EXEC, "strcmp (%s, %s) returned %d\n",
                  left_val, right_val, ret);
        break;
    case 3: /* num rel str */
        if (left_type & ARG_ID)
        {
            assert_numeric (p->ARG[0], file, line);
        }
        if (right_type & ARG_ID)
        {
            assert_numeric (p->ARG[0], file, line);
        }
        /* fall through */
    case 2: /* num rel num */
        ret = val_numcmp (left_val, right_val, file, line);
        log_info (T_EXEC, "val_numcmp  (%s, %s) returned %d\n",
                  left_val, right_val,ret);
        break;
    case 4: /* version rel version */
    case 5: /* version rel string */
        ret = val_vercmp (left_val, right_val, file, line);
        log_info (T_EXEC, "val_numcmp (%s, %s) returned %d\n",
                  left_val, right_val,ret);
        break;
    case 6:
        fatal_exit ("(%s:%d) you can't compare a version with "
                    "a plain number\n", __FILE__, __LINE__);
    default:
        fatal_exit ("(%s:%d) unknown arguments for comparison\n",
                    __FILE__, __LINE__);
    }

    switch (p->OP)
    {
    case EQUAL:
        ret = (ret == CMP_EQUAL);
        break;
    case NOT_EQUAL:
        ret = (ret != CMP_EQUAL);
        break;
    case LESS:
        ret = (ret == CMP_LESS);
        break;
    case GREATER:
        ret = (ret == CMP_GREATER);
        break;
    case GE:
        ret = (ret != CMP_LESS);
        break;
    case LE:
        ret = (ret != CMP_GREATER);
        break;
    default:
        fatal_exit ("(%s:%d) unknown/wrong relational operation: '%s'\n",
                    __FILE__, __LINE__, get_op_name (p->OP));

    }
    log_info (T_EXEC, "%s: returning %s\n",
              get_op_name (p->OP),
              ret ? "true" : "false");

    return ret;
}

/********************************************************************
 *
 * get the result of a condition by simply walking the condition tree
 *
 ********************************************************************/

int walk_condition (elem_t * p, char * file, int line)
{
    int ret;

    expect_node (p, __LINE__, -1, 0);
    log_info (T_EXEC, "condition: %s (%d)\n", get_op_name (p->OP), p->OP);
    inc_log_indent_level ();
    switch (p->OP)
    {
    case ID:
        ret = cond_id (p);
        break;
    case COPY_PENDING:
        ret = cond_copy_pending (p);
        break;
    case UNIQUE:
        ret = cond_unique (p, file, line);
        break;
    case DEFINED:
        ret = cond_defined (p, file, line);
        break;
    case MATCH:
        ret = cond_match (p);
        break;
    case SAMENET:
        ret = cond_same_net (p, file, line);
        break;
    case SUBNET:
        ret = cond_sub_net (p, file, line);
        break;
    case VALID_IP:
        ret = cond_valid_ip (p, file, line);
        break;
    case EQUAL:
    case NOT_EQUAL:
    case LESS:
    case GREATER:
    case LE:
    case GE:
        ret = cond_relop (p, file, line);
        break;
    case NOT:
        expect_types (p, NODE, NONE, NONE, __LINE__);
        ret = !walk_condition (p->ARG[0], file, line);
        break;
    case AND:
        expect_types (p, NODE, NODE, NONE, __LINE__);
        ret = walk_condition (p->ARG[0], file, line) &&
            walk_condition (p->ARG[1], file, line);
        break;
    case OR:
        expect_types (p, NODE, NODE, NONE, __LINE__);
        ret = walk_condition (p->ARG[0], file, line) ||
            walk_condition (p->ARG[1], file, line);
        break;
    default:
        fatal_exit ("(%s:%d) impossible boolean expression: %s\n",
                    p->file, p->line, get_op_name (p->OP));
    }
    dec_log_indent_level ();
    log_info (T_EXEC, "condition: '%s' returns '%s'\n",
              get_op_name (p->OP), ret ? "true" : "false");
    return ret;
}

void    walk_tree (void)
{
    walk_node (parse_tree.next);
}
