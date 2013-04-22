%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
    void print(char *);
    void my_puts (char *);
    void new_state (char c, char out);
    void hash_bang (char *);
    void here_doc_start (char * text);
    int here_doc_print (char * text);
    int nl;
    int first;
%}

%x sq_str dq_str bq_str quote here_doc
%option stack

COMMENT (^[[:space:]]*#[^\r\n]*)|([[:space:]]+#[^\r\n]*)
%%
<*>\\           {
                    new_state('\\', *yytext);
                }
<quote>[^\r\n]  {
                    new_state('\\', *yytext);
                }
<quote>[\r]     {   /* ignore dos line end */
                }
<quote>[\n]     {
                    new_state('\\', '\n');
                    nl = 1;
                }

<INITIAL>['"`]  {
                    new_state(*yytext, *yytext);
                }

<sq_str>[^'\\\r\n]* {
                    my_puts (yytext);
                }

<sq_str>[']     {
                    new_state(*yytext, *yytext);
                }

<dq_str>[^"`\\\r\n]*    {
                    my_puts (yytext);
                }


<dq_str>["`]    {
                    new_state(*yytext, *yytext);
                }

<bq_str>[^'`"\\\r\n]*   {
                    print (yytext);
                }

<bq_str>[`"']   {
                    new_state(*yytext, *yytext);
                }


<sq_str,dq_str,bq_str>[\r]* {}
<sq_str,dq_str,bq_str>[\n]* {my_puts (yytext);}

#![^\r\n]*     { hash_bang (yytext); }
.*<<[^\r\n#]*   {
                        here_doc_start (yytext);
                        yy_push_state(here_doc);
                }
<here_doc>[^\n\r]*      {
                        if (here_doc_print (yytext))
                                yy_pop_state();
                }
<here_doc>[\n]  {       ECHO; }
<here_doc>[\r]* {}

^[[:space:]]*#[^\r\n]*  {}
[[:space:]]+#[^\r\n]*   {}

[^\r\n\\#'"`]*[^[:space:]\r\n\\#'"`]+   {
                    print (yytext);
                }
[[:blank:]]+$   { /* kill trailing spaces */ }
^[[:blank:]]+   { if (nl) fputc (' ', yyout); /* kill leading  spaces */ }
[[:blank:]]+    { print(" "); }
[\r\n]*         {
                        if (nl) { fputc ('\n', yyout); nl = 0; }
                }


%%

void lex_init(FILE * in, FILE * out)
{
    nl = 0;
    first = 1;
    yyin = in;
    yyout = out;
    BEGIN(INITIAL);
}

int yywrap ()
{
    return 1;
}
static char here_token[128];

void hash_bang (char * text)
{
    if (first)
        print (text);
}
void here_doc_start (char * text)
{
    char * p = strstr (text, "<<");
    char * q = here_token;
    if (!p)
    {
        fprintf (stderr, "failed to locate << in here doc statement\n");
        abort ();
    }
    p += 2;
    if (*p == '-')
        p++;
    while (*p && isspace (*p))
        p++;
    while (*p && (!isspace (*p) && *p != '>'))
        *q++ = *p++;
    *q = 0;
    print (text);
}
int here_doc_print (char * text)
{
    my_puts(text);
    if (text == strstr(text, here_token)) {
      return 1;
    }
    else
      return 0;

}
void print (char * p)
{
  while (*p) {
    if (isblank(*p)) {
      if (nl)
´       fputc (' ', yyout);
      p++;
      while (isblank (*p))
        p++;
    } else {
      fputc (*p++, yyout);
      nl=1;
    }
  }
}
void my_puts (char * text)
{
    first = 0;
    nl=1;
    fputs (text, yyout);
}
void new_state (char c, char out)
{
    int state;

    if (out)
    {
        fputc(out, yyout);
        if (c == '\n')
            nl=0;
        else
            nl=1;
    }

    switch (c)
    {
    case '\'': state = sq_str; break;
    case '"': state = dq_str; break;
    case '`': state = bq_str; break;
    case '\\': state = quote; break;
    default:
        fprintf(stderr, "unknown state char '%c' (%d)\n", c, (int)c);
        abort();
        break;
    }
    if (YY_START == state)
    {
        yy_pop_state ();
#ifdef FLEX_DEBUG
        if (yy_flex_debug)
            fprintf(stderr, "leaving state %d (%d -> %d)\n",
                    state, state, YY_START);
#endif
    }
    else
    {
#ifdef FLEX_DEBUG
        if (yy_flex_debug)
            fprintf(stderr, "entering state %d (%d -> %d)\n",
                    state, YY_START, state);
#endif
        yy_push_state (state);
    }
}
