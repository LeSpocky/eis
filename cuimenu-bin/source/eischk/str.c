#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#include "var.h"
#include "log.h"
#include "str.h"

/*----------------------------------------------------------------------------
 *  convert_to_upper (char * str)
 *----------------------------------------------------------------------------
 */
char *
convert_to_upper (char * str)
{
    static char *   rtc;
    unsigned char * s;
    unsigned char * r;

    if (! str)
    {
        return ((char *) NULL);
    }

    if (rtc == str)
    {
        fatal_exit ("%s %d: freeing string still in use\n",
                    __FILE__, __LINE__);
    }

    if (rtc)
    {
        free (rtc);
    }

    rtc = (char *) malloc (strlen (str) + 1);

    if (! rtc)
    {
        return ((char *) NULL);
    }

    for (s = (unsigned char *) str, r = (unsigned char *) rtc; *s; s++, r++)
    {
        if (isascii (*s) && islower (*s))
        {
            *r = toupper (*s);
        }
        else
        {
            *r = *s;
        }
    }

    *r = '\0';

    return (rtc);
} /* convert_to_upper (str) */


/*------------------------------------------------------------------------------
 * strsave (s)                      - save string s
 *------------------------------------------------------------------------------
 */
char *
strsave (char * s)
{
    char *  t;

    if (s)
    {
         t = calloc ((unsigned) strlen (s) + 1, 1);

         if (t)
         {
            (void) strcpy (t, s);
         }
    }
    else
    {
        t = (char *) NULL;
    }

    return (t);
} /* strsave (s) */

char *
strcat_save (char * s, char * a)
{
    int len, len_s;

    if (! a)
    {
        return s;
    }
    len_s = len = s ? strlen (s) : 0;
    len += strlen (a);

    s = realloc (s, len + 1);
    strcpy (s+len_s, a);

    return s;
} /* strsave (s) */


char *
strsave_quoted (char * s)
{
    char *  t;
    int len =  strlen (s);
    if (s)
    {
         t = calloc ((unsigned) len - 1, 1);

         if (t)
         {
            (void) strncpy (t, s+1, len - 2);
         }
         t[len-2] = '\0';
    }
    else
    {
        t = (char *) NULL;
    }

    return (t);
} /* strsave (s) */

char *
strsave_ws (char * s)
{
    char * t = strsave (s);
    char * ret = NULL;
    if (t)
    {
        char *p, *q;
        for (p = q = t; *q; p++, q++)
        {
            *p = (*q == '\t') ? ' ' : *q;
            if (isspace (*q))
            {
                while (isspace (*(q+1)))
                {
                    q++;
                }
            }
        }
        *p = '\0';
        ret = strsave (t);
        free (t);
    }
    return ret;
}

char *  get_set_var_name_int (char * s, int index, char * file, int line)
{
    char var_buf [VAR_SIZE+1];
    char fmt_buf [VAR_SIZE+1];
    char * p;
    char * fmt;
    int  index_found = 0;

    if (strlen (s) >= VAR_SIZE)
    {
        fatal_exit ("Variable name too long\n");
    }

    for (p = fmt_buf, fmt=s; *fmt; fmt++)
    {
        *p++ = *fmt;

        if (*fmt == '%')
        {
            if (!index_found)
            {
                index_found = 1;
                *p++ = 'd';
            }
            else
            {
                *p++ = '%';
            }
        }
    }
    *p = '\0';

    sprintf (var_buf, fmt_buf, index);

    if (strlen (var_buf) >= VAR_SIZE)
    {
        fatal_exit ("Variable name too long\n");
    }
    return strsave (var_buf);
}

char *  get_set_var_name_string (char * s, char * index, char * file, int line)
{
    return get_set_var_name_int (s, convert_to_long (index, file, line),
                                 file, line);
}

char *  strip_multiple_indices (char * s)
{
    char * q = strsave (s);
    if (multiple_idx (q))
    {
        char * p = strchr (q, '%');
        if (p)
        {
            *(p+1) = '\0';
        }
    }
    return q;
}

char * replace_set_var_indices (char * s)
{
    char * src = strsave (s);
    char * dst = src;
    char * ret = src;

    while (*src)
    {
        if (isdigit (*src) && (src != s) && (*(src - 1) == '_'))
        {
            *dst++ = '%';
            do
            {
                src++;
            } while (isdigit (*src));
        }
        else
        {
            *dst++ = *src++;
        }
    }

    *dst = '\0';
    return ret;
}

int multiple_idx (char * name)
{
    char * q = strchr (name, '%');
    return (q != NULL && strchr (q+1, '%') != NULL);
}

unsigned long convert_to_long (char * val, char * file, int line)
{
    char * endptr;
    unsigned long res;

    if (*val == '0' && *(val+1) == 'x')
    {
        res = strtoul (val, &endptr, 16);
    }
    else
    {
        res = strtoul (val, &endptr, 10);
    }

    if (*endptr)
    {
        fatal_exit ("invalid number '%s' in %s, line %d\n",
                    val, file, line);
    }
    return res;
}

void * str_safe_malloc(size_t size, const char * file, const char * function, int line)
{
    void * p = malloc(size);
    if (!p) {
        fatal_exit ("%s:%d, %s: unable to allocate memory\n", file, line, function);
    }
    return p;
}
