/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton interface for Bison's Yacc-like parsers in C

   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     ID = 258,
     IDSET = 259,
     NUM = 260,
     STRING = 261,
     CHAR = 262,
     VER = 263,
     MAJOR_VER = 264,
     VER_EXPR = 265,
     IF = 266,
     THEN = 267,
     ELSE = 268,
     FOREACH = 269,
     WARNING = 270,
     ERROR = 271,
     FATAL_ERROR = 272,
     FGREP = 273,
     STAT = 274,
     CRYPT = 275,
     SPLIT = 276,
     NUMERIC = 277,
     SET = 278,
     ADD_TO_OPT = 279,
     PROVIDES = 280,
     DEPENDS = 281,
     VERSION = 282,
     UNKNOWN = 283,
     FI = 284,
     IN = 285,
     DO = 286,
     DONE = 287,
     ON = 288,
     SAMENET = 289,
     SUBNET = 290,
     VALID_IP = 291,
     ASSIGN = 292,
     MOD = 293,
     DIV = 294,
     MULT = 295,
     SUB = 296,
     ADD = 297,
     OR = 298,
     AND = 299,
     MATCH = 300,
     GE = 301,
     LE = 302,
     GREATER = 303,
     LESS = 304,
     NOT_EQUAL = 305,
     EQUAL = 306,
     UNIQUE = 307,
     DEFINED = 308,
     COPY_PENDING = 309,
     NOT = 310
   };
#endif
/* Tokens.  */
#define ID 258
#define IDSET 259
#define NUM 260
#define STRING 261
#define CHAR 262
#define VER 263
#define MAJOR_VER 264
#define VER_EXPR 265
#define IF 266
#define THEN 267
#define ELSE 268
#define FOREACH 269
#define WARNING 270
#define ERROR 271
#define FATAL_ERROR 272
#define FGREP 273
#define STAT 274
#define CRYPT 275
#define SPLIT 276
#define NUMERIC 277
#define SET 278
#define ADD_TO_OPT 279
#define PROVIDES 280
#define DEPENDS 281
#define VERSION 282
#define UNKNOWN 283
#define FI 284
#define IN 285
#define DO 286
#define DONE 287
#define ON 288
#define SAMENET 289
#define SUBNET 290
#define VALID_IP 291
#define ASSIGN 292
#define MOD 293
#define DIV 294
#define MULT 295
#define SUB 296
#define ADD 297
#define OR 298
#define AND 299
#define MATCH 300
#define GE 301
#define LE 302
#define GREATER 303
#define LESS 304
#define NOT_EQUAL 305
#define EQUAL 306
#define UNIQUE 307
#define DEFINED 308
#define COPY_PENDING 309
#define NOT 310




#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
#line 25 "grammar.y"
{
       int line;
       elem_t * elem;
}
/* Line 1489 of yacc.c.  */
#line 164 "y.tab.h"
	YYSTYPE;
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif

extern YYSTYPE yylval;

