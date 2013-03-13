#ifndef ARRAY_H
#define ARRAY_H

typedef struct array array_t;
typedef struct array_iterator array_iterator_t;

struct array_iterator {
    int index;
    array_t * array;
};

array_t * init_array (int initial_number, int elem_size);
void free_array (array_t * array);
void reset_array (array_t * array);
void * get_first_elem (array_t * array);
void * get_last_elem (array_t * array);
void * get_new_elem (array_t * array);

void init_array_iterator (array_iterator_t * iterator, array_t * array);
void * get_next_elem  (array_iterator_t * iterator);
void dup_array_iterator (array_iterator_t * src, array_iterator_t * dst);

#define CHECK_ARRAY_SIZE        1024
#define VAR_ARRAY_SIZE          1024
#define SET_VAR_ARRAY_SIZE      128
#define REGEXP_ARRAY_SIZE       256
#define FILES_ARRAY_SIZE        1024

#define DECLARE_ARRAY_ITER(iter, var, type)     \
    array_iterator_t iter;                      \
    type * var;

#define ARRAY_ITER_LOOP(iter, array, var)       \
    init_array_iterator(&iter, array);          \
    while( (var = get_next_elem(&iter)) )

#define ARRAY_ITER(iter, array, var, type)      \
    DECLARE_ARRAY_ITER(iter, var, type);        \
    ARRAY_ITER_LOOP(iter, array, var)

#endif /*  ARRAY_H */
