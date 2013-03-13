#include "tree_struct.h"
#include "tree.h"
#include "tree_debug.h"
#include "y.tab.h"
#include "log.h"

static void     expect_leaf (elem_t * p, int line, int arg, int opt);
static void     expect_none (elem_t * p, int line, int arg, int opt);
static void     expect_something (elem_t * p, int line, int arg, int opt);

static void     dump_node (int log_level, elem_t *p);
static void     dump_leaf (int log_level, elem_t *p);

char * get_op_name (int op)
{
    switch (op)
    {
    case ID:            return  "ID";
    case IDSET:         return  "IDSET";
    case NUM:           return  "NUM";
    case STRING:        return  "STRING";
    case VER:           return  "VER";
    case VER_EXPR:      return  "VER_EXPR";
    case MAJOR_VER:     return  "MAJOR_VER";
    case IF:            return  "IF";
    case THEN:          return  "THEN";
    case ELSE:          return  "ELSE";
    case FI:            return  "FI";
    case FOREACH:       return  "FOREACH";
    case IN:            return  "IN";
    case DO:            return  "DO";
    case DONE:          return  "DONE";
    case WARNING:       return  "WARNING";
    case ERROR:         return  "ERROR";
    case FATAL_ERROR:   return  "FATAL_ERROR";
    case FGREP:         return  "FGREP";
    case STAT:          return  "STAT";
    case SPLIT:         return  "SPLIT";
    case SPLIT | SPLIT_NUMERIC: return  "SPLIT (numeric)";
    case SET:           return  "SET";
    case PROVIDES:      return  "PROVIDES";
    case DEPENDS:       return  "DEPENDS";
    case ON:            return  "ON";
    case VERSION:       return  "VERSION";
    case UNKNOWN:       return  "UNKNOWN";
    case ASSIGN:        return  "ASSIGN";
    case ADD:           return  "ADD";
    case SUB:           return  "SUB";
    case MULT:          return  "MULT";
    case DIV:           return  "DIV";
    case MOD:           return  "MOD";
    case AND:           return  "AND";
    case OR:            return  "OR";
    case EQUAL:         return  "EQUAL";
    case NOT_EQUAL:     return  "NOT_EQUAL";
    case LESS:          return  "LESS";
    case LE:            return  "LESS or EQUAL";
    case GREATER:       return  "GREATER";
    case GE:            return  "GREATER or EQUAL";
    case MATCH:         return  "MATCH";
    case NOT:           return  "NOT";
    case COPY_PENDING:  return  "COPY_PENDING";
    case DEFINED:       return  "DEFINED";
    case SCRIPT:        return  "SCRIPT";
    case SAMENET:       return  "SAMENET";
    case SUBNET:        return  "SUBNET";
    case VALID_IP:      return  "VALID_IP";
    case ADD_TO_OPT:    return  "ADD_TO_OPT";
    case CRYPT:         return  "CRYPT";
    default:            return "unknown";
    }
}

void dump_leaf (int log_level, elem_t *p)
{
    log_info (log_level, "(%s:%d) leaf %s=%s\n", p->file, p->line,
              get_op_name (p->TYPE), p->VAL);
}
void dump_node (int log_level, elem_t *p)
{
    int i;
    log_info (log_level, "(%s:%d) node %s\n",  p->file, p->line,
              get_op_name (p->OP));
    inc_log_indent_level ();
    for (i=0; i<3; i++)
    {
        dump_elem (log_level, p->ARG[i]);
    }
    dec_log_indent_level ();
}
void dump_elem (int log_level, elem_t *p)
{
    if (p)
    {
        if (p->type == NODE)
        {
            dump_node (log_level, p);
        }
        else
        {
            dump_leaf (log_level, p);
        }
    }
    else
    {
        log_info (log_level, "empty_element\n");
    }
}

void expect_leaf (elem_t * p, int line, int arg, int opt)
{
    if (!p)
    {
        if (!opt)
        {
            fatal_exit ("%s %d: leaf expected, got NONE (arg %d)\n",
                        __FILE__, line, arg);
        }
    }
    else if (p->type != LEAF)
    {
        fatal_exit ("%s %d: leaf expected, node %s found (arg %d)\n",
                    __FILE__, line, get_op_name (p->ln.node.op), arg);
    }
}
void expect_node (elem_t * p, int line, int arg, int opt)
{
    if (!p)
    {
        if (!opt)
        {
            fatal_exit ("%s %d: node expected, got NONE (arg %d)\n",
                        __FILE__, line, arg);
        }
    }
    else if (p->type != NODE)
    {
        fatal_exit ("%s %d: node expected, leaf %s='%s' found (arg %d)\n",
                    __FILE__, line, get_op_name (p->TYPE),
                    p->VAL, arg);
    }
}
void expect_none (elem_t * p, int line, int arg, int opt)
{
    if (p)
    {
        fatal_exit ("%s %d: expected none, %s %s found (arg %d)\n",
                    __FILE__, line, p->type == NODE ? "node" : "leaf",
                    get_op_name (p->ln.node.op), arg);
    }
}

void expect_something (elem_t * p, int line, int arg, int opt)
{
    if (!p)
    {
        if (!opt)
        {
          fatal_exit ("%s %d: expected something, got none (arg %d)\n",
                      __FILE__, line, arg);
        }
    }
}

void    expect_types (elem_t * p, int arg1, int arg2, int arg3, int line)
{
    int i, type, opt;
    int types[3];

    types[0] = arg1;
    types[1] = arg2;
    types[2] = arg3;

    expect_node (p, line, -1, 0);
    for (i=0; i<3; i++)
    {
        type = types[i] & ~OPT;
        opt = types[i] & OPT;
        switch (type)
        {
        case NODE:
            expect_node (p->ln.node.arg[i], line, i, opt);
            break;
        case LEAF:
            expect_leaf (p->ln.node.arg[i], line, i, opt);
            break;
        case NONE:
            expect_none (p->ln.node.arg[i], line, i, opt);
            break;
        case SOMETHING:
            expect_something (p->ln.node.arg[i], line, i, opt);
            break;
        }
    }
}

