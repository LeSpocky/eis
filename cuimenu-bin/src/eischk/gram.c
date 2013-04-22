#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <stdarg.h>

#include <dirent.h>

#include "var.h"
#include "check.h"
#include "log.h"

extern int yydebug;

int main(int argc, char ** argv)
{
    char *check_dir         = "check";
    DIR *           dirp;
    struct dirent * dp;
    char buf[512];
    int wrong_usage = 0;
    int len;

    if (argc == 3)
    {
        if (!strcmp(argv[1], "-c"))
        {
            check_dir = argv[2];
        }
        else
        {
            wrong_usage = 1;
        }
    }
    else
    {
        wrong_usage = 1;
    }

    if (!wrong_usage)
    {
        dirp = opendir (check_dir);

        if (! dirp)
        {
            fatal_exit ("Error opening check dir '%s': %s\n",
                        check_dir, strerror(errno));
        }

        while ((dp = readdir (dirp)) != (struct dirent *) NULL)
        {
            len = strlen (dp->d_name);

            if (len > 4 && ! strcasecmp (dp->d_name + len - 4, ".txt"))
            {
                sprintf(buf, "%s/%s", check_dir, dp->d_name);
                printf("%s/%s", check_dir, dp->d_name);
                (void)read_config_file(buf, buf);
            }
        }
        yydebug=1;
        yyparse();
        return 0;
    }
    else
    {
        printf("usage: %s -c <config directory>\n", argv[0]);
    }
    return 0;
}
