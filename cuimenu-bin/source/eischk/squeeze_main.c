#include <stdio.h>
#include <stdlib.h>

extern int yylex(void);
extern int lex_init(FILE * in, FILE * out);

int main (int argc, char ** argv)
{
         FILE * in, * out;

         argc--; argv++;
#ifdef FLEX_DEBUG
         if (argc > 0 && !strcmp(argv[0], "-d"))
         {
             yy_flex_debug = 1;
             argv++;
             argc--;
         }
         else
             yy_flex_debug = 0;
#endif
         if (argc > 0)
         {
             in = fopen (argv[0], "r");
             if (!in)
             {
                  fprintf(stderr, "unable to open '%s' for reading, aborting\n", argv[0]);
                  exit(1);
             }
             argv++;
             argc--;
         }
         if (argc > 0)
         {
             out = fopen (argv[0], "wb");
             if (!out)
             {
                  fprintf(stderr, "unable to open '%s' for writing, aborting\n", argv[0]);
                  exit(1);
             }
         }
         lex_init(in, out);
         return yylex();
}
