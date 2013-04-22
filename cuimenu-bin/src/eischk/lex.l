%{
/* need this for the call to atof() below */
#include "tree.h"
#include "y.tab.h"
#include "str.h"
#include "log.h"
#include <ctype.h>
int yylex (void);
int yyline = 1;
extern char * input_buf;
extern int current_pos;

#define fprintf log_lex_fprintf
#define YY_NO_UNPUT
%}

ID              [a-zA-Z][a-zA-Z0-9_]*
IDSET           [a-zA-Z]((_%_)?[a-zA-Z0-9_]*)*(_%)?
IF              if|IF
THEN            then|THEN
ELSE            else|ELSE
FI              fi|FI
DEFINED         defined|DEFINED
WARNING         warning|WARNING
ERROR           error|ERROR
FATAL_ERROR     fatal_error|FATAL_ERROR
ADD_TO_OPT      add_to_opt|ADD_TO_OPT
FGREP           fgrep|FGREP
STAT            stat|STAT
SPLIT           split|SPLIT
CRYPT           crypt|CRYPT
NUMERIC         numeric|NUMERIC
COPY_PENDING    copy_pending|COPY_PENDING
UNIQUE          unique|UNIQUE
SET             set|SET
PROVIDES        provides|PROVIDES
DEPENDS         depends|DEPENDS
ON              on|ON
FOREACH         foreach|FOREACH
IN              in|IN
DO              do|DO
DONE            done|DONE
SAMENET         samenet|SAMENET
SUBNET          subnet|SUBNET
VALID_IP        valid_ip|VALID_IP
VERSION         version|VERSION
GREATER         greater|GREATER
VER             ([0-9]\.[0-9]\.[0-9]{1,3}([^[:space:]]+)?)|3.6.2
VER_EXPR        [0-9]\.[0-9]\.[-0-9.?*+{}\\\[\]]*
MAJOR_VER       [0-9]\.[0-9]
STRING          \"[^\"]*\"
CHAR            '.'
%%

(0x)?[0-9]+     { yylval.elem = mkleaf (NUM, yytext); return NUM; }
{IF}            { yylval.line = yyline; return IF; }
{THEN}          { yylval.line = yyline; return THEN; }
{ELSE}          { yylval.line = yyline; return ELSE; }
{FI}            { return FI; }
{SET}           { yylval.line = yyline; return SET; }
{WARNING}       { yylval.line = yyline; return WARNING; }
{ERROR}         { yylval.line = yyline; return ERROR; }
{FATAL_ERROR}   { yylval.line = yyline; return FATAL_ERROR; }
{ADD_TO_OPT}    { yylval.line = yyline; return ADD_TO_OPT; }
{FGREP}         { yylval.line = yyline; return FGREP; }
{STAT}          { yylval.line = yyline; return STAT; }
{CRYPT}         { yylval.line = yyline; return CRYPT; }
{SPLIT}         { yylval.line = yyline; return SPLIT; }
{NUMERIC}       { yylval.line = yyline; return NUMERIC; }
{COPY_PENDING}  { return COPY_PENDING; }
{UNIQUE}        { return UNIQUE; }
{DEFINED}       { return DEFINED; }
{STRING}        { yylval.elem = mkleaf (STRING, yytext); return STRING; }
{CHAR}          { yylval.elem = mkleaf (CHAR, yytext); return CHAR; }
{PROVIDES}      { yylval.line = yyline; return PROVIDES; }
{VERSION}       { return VERSION; }
{DEPENDS}       { yylval.line = yyline; return DEPENDS; }
{ON}            { return ON; }
{FOREACH}       { yylval.line = yyline; return FOREACH; }
{IN}            { return IN; }
{DO}            { return DO; }
{DONE}          { return DONE; }
{SAMENET}       { return SAMENET; }
{SUBNET}        { return SUBNET; }
{VALID_IP}      { return VALID_IP; }
{VER}           { yylval.elem = mkleaf (VER, yytext); return VER; }
{VER_EXPR}      { yylval.elem = mkleaf (VER_EXPR, yytext); return VER_EXPR; }
{MAJOR_VER}     { yylval.elem = mkleaf (MAJOR_VER, yytext); return MAJOR_VER; }
{ID}            { yylval.elem = mkleaf (ID, yytext); return ID; }
{IDSET}         { yylval.elem = mkleaf (IDSET, yytext); return IDSET; }
"=="            { return EQUAL; }
"!="            { return NOT_EQUAL; }
"=~"            { return MATCH; }
"="             { return ASSIGN; }
"("             { return '('; }
")"             { return ')'; }
"["             { return '['; }
"]"             { return ']'; }
","             { return ','; }
"<"             { return LESS; }
"<="            { return LE; }
">="            { return GE; }
">"             { return GREATER; }
"&&"            { return AND; }
"||"            { return OR; }
"!"             { return NOT; }
"+"             { return ADD; }
"-"             { return SUB; }
"*"             { return MULT; }
"/"             { return DIV; }
"%"             { return MOD; }

"#".*           /* eat up one-line comments */

[ \r\t]+        /* eat up whitespace */
[\n]+           { yyline += yyleng; } /* eat up new lines */

.               { if (!iscntrl (yytext[0])) return UNKNOWN; else fprintf(yyout, "control char %d\n", (int)yytext[0]); }

%%
