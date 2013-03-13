#include <stdio.h>
#include "parse.h"

void
dtou (void)
{
    int     cnt = 0;
    int     c;

    while ((c = getchar ()) != EOF)
    {
        if (c == '\r')     /* don't copy multiple CRs at end of line   */
        {
            cnt++;
        }
        else if (c == '\n')
        {
            cnt = 0;
            putchar (c);
        }
        else
        {
            while (cnt > 0) /* CRs not at end of line, copy them!       */
            {
                putchar ('\r');
                cnt--;
            }
            putchar (c);
        }
    }
    return;
}

void
utod (void)
{
    int     cnt = 0;
    int     c;

    while ((c = getchar ()) != EOF)
    {
        if (c == '\r')       /* don't copy multiple CRs at end of line */
        {
            cnt++;
        }
        else if (c == '\n')
        {
            cnt = 0;
            putchar ('\r');
            putchar (c);
        }
        else
        {
            while (cnt > 0)   /* CRs not at end of line, copy them!     */
            {
                putchar ('\r');
                cnt--;
            }
            putchar (c);
        }
    }
    return;
}
