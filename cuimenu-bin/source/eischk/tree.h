#ifndef TREE_H
#define TREE_H

typedef struct elem elem_t;

elem_t * mknode (int op, elem_t * arg1, elem_t * arg2, elem_t * arg3,
                 int line);
elem_t * mkleaf (int type, char * value);
elem_t * add_node (elem_t * node1, elem_t * node2);

void    add_script (elem_t * node);
void    walk_tree (void);

#define NUMEQUAL 1024
#define VEREQUAL 1025
#define SCRIPT   2048
#define SPLIT_NUMERIC    4096

#endif /* TREE_H */
