#define NONE 0
#define SOMETHING 3
#define OPT 8

void    expect_types (elem_t * p, int arg1, int arg2, int arg3, int line);
void    expect_node (elem_t * p, int line, int arg, int opt);

void    dump_elem (int log_level, elem_t *p);
char *  get_op_name (int op);


