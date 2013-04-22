#include "array.h"
#include "log.h"
#include <stdlib.h>
#include <string.h>

struct array {
  int elem_size;
  int elem_number;
  int last;
  char *array;
};

array_t * init_array (int initial_number, int elem_size)
{
    array_t * a = (array_t *)malloc (sizeof (array_t));

    if (a)
        *a = (array_t){elem_size, initial_number, -1,
                       calloc(initial_number, elem_size)};
    if (!a || !a->array)
        fatal_exit ("unable to allocate array.");

    return a;
}

void free_array (array_t * array)
{
    if (array)
    {
        if (array->array)
        {
            memset (array->array, 0, array->elem_size * array->elem_number);
            free(array->array);
        }
        memset(array, 0, sizeof(array_t));
        free(array);
    }
}

void reset_array (array_t * array)
{
    array->last = -1;
}

void * get_first_elem (array_t * array)
{
    return array->last != -1 ? array->array : 0;
}

void * get_last_elem (array_t * array)
{
    return array->last != -1 ? array->array + array->last * array->elem_size : 0;
}

void * get_new_elem (array_t * array)
{
    array->last++;
    if (array->last == array->elem_number)
    {
        int inc = array->elem_number;
        array->array = realloc (array->array, array->elem_size * (array->elem_number + inc));
        if (!array->array)
            fatal_exit ("unable to resize array");

        memset (get_last_elem (array), 0, array->elem_size * inc);
        array->elem_number+=inc;
    }
    return get_last_elem(array);
}

void init_array_iterator (array_iterator_t * iterator, array_t * array)
{
    iterator->index = 0;
    iterator->array = array;
}

void * get_next_elem  (array_iterator_t * iterator)
{
    return ( (iterator->array->last == -1) ||
             (iterator->index > iterator->array->last) ) ? 0 :
        iterator->array->array + iterator->index++ * iterator->array->elem_size;
}

void dup_array_iterator (array_iterator_t * src, array_iterator_t * dst)
{
    *dst = *src;
}
