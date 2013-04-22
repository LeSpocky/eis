#include "tree.h"

#define NODE 1
#define LEAF 2

#define OP   ln.node.op
#define ARG  ln.node.arg
#define TYPE ln.leaf.type
#define VAL  ln.leaf.value

typedef struct
{
    int type;
    char * value;
} leaf_t;

typedef struct
{
    int op;
    elem_t * arg[3];
} node_t;

struct elem
{
    union
    {
        leaf_t leaf;
        node_t node;
    } ln;
    int type;
    char * file;
    char * package;
    int line;
    elem_t *next;
};

