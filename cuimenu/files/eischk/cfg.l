%{
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include "cfg.h"
#include "str.h"
#include "log.h"
int cfglex (void);

#define MAX_STR_CONST 4096*2
static char string_buf[MAX_STR_CONST+1];
static char *string_buf_ptr;
static int multi_flag;
static void cfg_new_line (void);

int cfgline = 0;
int cfgcolumn = 0;

static char * cfgfile = NULL;
static int quote_active = 0;
static void copy_string (char *, int);
#define YY_NO_UNPUT
%}

%x sq_str dq_str

ID              [A-Z][A-Z0-9_%]*
NEG_ID          !{ID}
OPT_ID          \+{ID}
REALLY_OPT_ID   \+\+{ID}
DEP_ID          \+?{ID}\({ID}(=~\'[^\']*\')?\)
STR_ELEM        \\\\|\\\'|[^'\n]
ML_STR_ELEM     \\\\|\\\'|[^']
STRING          \'{STR_ELEM}*\'
ML_STRING       \'({ML_STR_ELEM}*[\n])*\'
REGEXP          RE:[^[:space:]]+
DCOMMENT        ^{SPACE}*[#]{1,2}[^\n\r]*
COMMENT         [ \t\r]+[#][^\n\r]*
WCOMMENT        [#][^\n\r]*
NL              [\n]
HYPHEN          [-]
EQUAL           [=]
COLON           [:]
SPACE           [ ]+
CR              [\r]
TAB             [\t]
%%

\'              {
                        string_buf_ptr = string_buf;
                        multi_flag = 0;
                        cfglval.dq = 0;
                        quote_active = 1;
                        BEGIN(sq_str);
                }
<sq_str>\'      {
                        /* saw closing quote - all done */
                        BEGIN(INITIAL);
                        quote_active = 0;
                        *string_buf_ptr = '\0';
                        log_info (SCAN, "found singe qouted string '%s' (%s)\n",
                                        string_buf,
                                        multi_flag ? "multi line string" : "normal string");
                        cfglval.text = strsave (string_buf);
                        return multi_flag ? CFG_ML_STRING : CFG_STRING;
                }

\"              {
                        string_buf_ptr = string_buf;
                        multi_flag = 0;
                        cfglval.dq = 1;
                        quote_active = 1;
                        BEGIN(dq_str);
                }
<dq_str>\"      {
                        /* saw closing quote - all done */
                        BEGIN(INITIAL);
                        quote_active = 0;
                        *string_buf_ptr = '\0';
                        log_info (SCAN, "found double quoted string '%s' (%s)\n",
                                        string_buf,
                                        multi_flag ? "multi line string" : "normal string");
                        cfglval.text = strsave (string_buf);
                        return multi_flag ? CFG_ML_STRING : CFG_STRING;
                }

<sq_str,dq_str>[\n]     {
                        multi_flag = 1;
                        cfg_new_line ();
                }

<sq_str>[^'\n]+ {
                        copy_string (cfgtext, cfgleng);
                }
<dq_str>[^"\\\n]+       {
                        copy_string (cfgtext, cfgleng);
                }
<dq_str>\\.     {
                        copy_string (cfgtext, cfgleng);
                }
<dq_str,sq_str><<EOF>>  {
                        log_error ("Error in %s:%d,%d: expecting closing single/double quote, got EOF\n",
                                   cfgfile, cfgline, cfgcolumn);
                        BEGIN(INITIAL);
                        yyterminate();
                }

{ID}            {
                        cfglval.text = strsave (cfgtext);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_ID;
                }
{NEG_ID}        {
                        cfglval.text = strsave (cfgtext+1);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_NEG_ID;
                }
{OPT_ID}        {
                        cfglval.text = strsave (cfgtext+1);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_OPT_ID;
                }
{DEP_ID}        {
                        cfglval.text = strsave (cfgtext);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_DEP_ID;
                }
{REALLY_OPT_ID} {
                        cfglval.text = strsave (cfgtext+2);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_REALLY_OPT_ID;
                }
{REGEXP}        {
                        cfglval.text = strsave (cfgtext+3);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_REGEXP;
                }
{HYPHEN}        {
                        cfglval.text = NULL;
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_HYPHEN;
                }
{EQUAL}         {
                        cfglval.text = NULL;
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_EQUAL;
                }
{COLON}         {
                        cfglval.text = NULL;
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_COLON;
                }
{DCOMMENT}

{COMMENT}       {
                        cfglval.text = strsave (cfgtext);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_COMMENT;
                }

{WCOMMENT}      {
                        cfglval.text = strsave (cfgtext);
                        cfglval.column = cfgcolumn;
                        cfgcolumn += cfgleng;
                        return CFG_WCOMMENT;
                }


{SPACE}         { cfgcolumn += cfgleng; }
{TAB}           { cfgcolumn += 8; }
{CR}

{NL}            {
                        cfglval.text = NULL;
                        cfglval.column = cfgcolumn;
                        cfg_new_line ();
                        return CFG_NL;
                }

.               {
                        cfglval.text = NULL;
                        cfglval.column = cfgcolumn;
                        return CFG_UNKNOWN;
                }
%%

char * token_names [] = { "conditional id (depends on other id)",
                          "id",
                          "optional id (id with leading '+')",
                          "really optional id (id with leading '++')",
                          "string (enclosed in \"'\")",
                          "string (maybe stretched accross several lines)",
                          "regular expression (lead by 'RE:'",
                          "comment (starting with some spaces followed by '#')",
                          "wrong comment (starting with '#' without leading spaces)",
                          "=",
                          ":",
                          "-",
                          "new line",
                          "unknown character (i.e. lower case char)"};

struct  cfglval_t cfglval;
static FILE * cfgfp;
static void cfg_error (int expected, int got, int column);

void cfg_fopen (char * file)
{
    free (cfgfile);
    cfgfile = strsave (file);

    cfgfp = fopen (file, "r");
    if (! cfgfp)
    {
        fatal_exit ("Error opening file '%s': %s\n",
                    file, strerror (errno));
    }

    cfgrestart (cfgfp);
    cfgline = 1;
    cfgcolumn = 1;
    log_info (SCAN, "cfgestart, reading \"%s\"\n", file);
}

void cfg_fclose (void)
{
    fclose (cfgfp);
}

int cfgwrap ()
{
    return 1;
}

void cfg_error (int expected, int got, int column)
{
    int i;
    int first = 1;
    char * gotstr = NULL;
    log_error ("Error in %s:%d,%d: expected ",
               cfgfile, cfgline, column);
    for (i=0; i<32; i++)
    {
        if (expected & (1<<i))
        {
            if (first)
            {
                first = 0;
            }
            else
            {
                log_error (" or ");
            }
            log_error ("\"%s\"", token_names[i]);
        }
        if (got & (1<<i))
        {
            gotstr = token_names[i];
        }
    }
    log_error (", got '%s' (%x)\n", gotstr, got);
}
int get_config_tokens (struct token_t * t, int ignore_nl)
{
    int ret;
    int first_token = 1;
    int eof = 0;

    log_info (SCAN, "entering get_config_tokens\n");

    while (t->allowed_tokens != CFG_NONE)
    {
        log_info (SCAN, "calling cfglex \n");
        ret = cfglex ();
        if (first_token)
        {
            if (!ret)
            {
                return CFG_EOF;
            }
            if (ret == CFG_NL || ret == CFG_COMMENT)
                continue;
            first_token = 0;
        }
        else if (!ret) {
            if (quote_active || eof)
            {
                log_error ("Error in %s:%d,%d: unexpected end of file\n",
                           cfgfile, cfgline, cfglval.column);
                return CFG_ERROR;
            }
            eof = 1;
            ret = CFG_NL;
        }

        log_info (SCAN, "cfglex returned with 0x%x \n", ret);
        if (ret & t->allowed_tokens)
        {
            char * p;
            t->token = ret;
            t->text  = cfglval.text;
            t->dq = cfglval.dq;
            t->line = cfgline;
            switch (ret)
            {
            case CFG_NL:
                return 1;
                break;
            case CFG_HYPHEN:
                p = "-";
                break;
            default:
                p = cfglval.text ? cfglval.text : "unknown";
                break;
            }
            log_info (SCAN, "got 0x%x ('%s')\n", t->token, p);
        }
        else
        {
            if (ignore_nl && ret == CFG_NL)
            {
                continue;
            }

            cfg_error (t->allowed_tokens, ret, cfglval.column);
            /* skip line */
            while (ret && ret != CFG_NL)
            {
                ret = cfglex ();
            }
            return CFG_ERROR;
        }
        t++;
    }

    log_info (SCAN, "leaving get_config_tokens\n");
    return 0;
}

void cfg_new_line ()
{
    cfgline ++;
    cfgcolumn = 0;
    log_info (SCAN, "cfgline: %d\n", cfgline);
}

void copy_string (char * str, int length)
{
    int i;
    char * p;

    for (i=0, p=str; i<length && *p; i++, p++)
    {
        if (iscntrl (*p) && *p != '\015' && *p != '\011')
        {
            fatal_exit ("%s:%d : Control character %02d found in string, "
                        "aborting\n",
                        cfgfile, cfgline, *p);
        }
    }
    if (length < &string_buf[MAX_STR_CONST-1] - string_buf_ptr)
    {
        strncpy (string_buf_ptr, str, length);
        string_buf_ptr += length;
    }
    else
    {
        fatal_exit ("string too long ...");
    }
}
