/* ---------------------------------------------------------------------
 * File: cui-char.h
 * (Header file for libcui - char definitions and macros)
 *
 * Copyright (C) 2007
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * ---------------------------------------------------------------------
 */

#ifndef CUI_CHAR_H
#define CUI_CHAR_H

#ifdef _UNICODE
  #include <wchar.h>
  #include <wctype.h>
  #define TCHAR wchar_t
  #define TEXT(s) L##s
  #define _T(s) L##s
#else
  #define TCHAR char
  #define TEXT(s) s
  #define _T(s) s
#endif

#ifdef _UNICODE  
  #define istalnum iswalnum
  #define istalpha iswalpha
  #define istcntrl iswcntrl
  #define istdigit iswdigit
  #define istgraph iswgraph
  #define istlower iswlower
  #define istprint iswprint
  #define istpunct iswpunct
  #define istspace iswspace
  #define istupper iswupper
  #define istxdigit iswxdigit
  #define istblank iswblank
  #define totlower towlower
  #define totupper towupper
  #define tcscpy wcscpy
  #define tcsncpy wcsncpy
  #define tcscat wcscat
  #define tcsncat wcsncat
  #define tcscmp wcscmp
  #define tcsncmp wcsncmp
  #define tcscoll wcscoll
  #define tcsxfrm wcsxfrm
  #define tcscoll_l wcscoll_l
  #define tcsxfrm_l wcsxfrm_l
  #define tcsdup wcsdup
  #define tcschr wcschr
  #define tcsrchr wcsrchr
  #define tcschrnul wcschrnul
  #define tcscspn wcscspn
  #define tcsspn wcsspn
  #define tcspbrk wcspbrk
  #define tcsstr wcsstr
  #if defined(_WIN32)
  #define tcstok(s,d,p) wcstok(s,d)
  #else
  #define tcstok wcstok
  #endif
  #define tcslen wcslen
  #define tcsnlen wcsnlen
  #define tmemcpy wmemcpy
  #define tmemmove wmemmove
  #define tmemset wmemset
  #define tmemcmp wmemcmp
  #define tmemchr wmemchr
  #define tcscasecmp wcscasecmp
  #define tcsncasecmp wcsncasecmp
  #define tcscasecmp_l wcscasecmp_l
  #define tcsncasecmp_l wcsncasecmp_l
  #define tcpcpy wcpcpy
  #define tcpncpy wcpncpy
  #define tcstod wcstod
  #define tcstof wcstof
  #define tcstold wcstold
  #define tcstol wcstol
  #define tcstoul wcstoul
  #define tcstoq wcstoq
  #define tcstouq wcstouq
  #define tcstoll wcstoll
  #define tcstoull wcstoull
  #define tcstol_l wcstol_l
  #define tcstoul_l wcstoul_l
  #define tcstoll_l wcstoll_l
  #define tcstoull_l wcstoull_l
  #define tcstod_l wcstod_l
  #define tcstof_l wcstof_l
  #define tcstold_l wcstold_l
  #define tcsftime wcsftime
  #define fputts _fputws
  #if !defined(_WIN32)
  #define stprintf swprintf
  #define vstprintf vswprintf
  #else
  #define stprintf _snwprintf
  #define vstprintf _vsnwprintf
  #endif
  #define stscanf swscanf
  #define vstscanf vswscanf
  
  #define text_length wcs_length
  #define text_size wcs_size
  #define text_copy wcs_copy
  #define text_copy_new wcs_copy_new

  // curses
  #define MOVEYX   wmove
  #define PRINT    waddwstr
  #define PRINTN   waddnwstr
  #define PRINTC  wadd_wch
  
#else
  
  #define istalnum isalnum
  #define istalpha isalpha
  #define istcntrl iscntrl
  #define istdigit isdigit
  #define istgraph isgraph
  #define istlower islower
  #define istprint isprint
  #define istpunct ispunct
  #define istspace isspace
  #define istupper isupper
  #define istxdigit isxdigit
  #define istblank isblank
  #define totlower tolower
  #define totupper toupper
  #define tcscpy strcpy
  #define tcsncpy strncpy
  #define tcscat strcat
  #define tcsncat strncat
  #define tcscmp strcmp
  #define tcsncmp strncmp
  #define tcscoll strcoll
  #define tcsxfrm strxfrm
  #define tcscoll_l strcoll_l
  #define tcsxfrm_l strxfrm_l
  #define tcsdup strdup
  #define tcschr strchr
  #define tcsrchr strrchr
  #define tcschrnul strchrnul
  #define tcscspn strcspn
  #define tcsspn strspn
  #define tcspbrk strpbrk
  #define tcsstr strstr
  #if defined(__GNUC__)
  #define tcstok strtok_r
  #else
  #define tcstok(s,d,p) strtok(s,d)
  #endif
  #define tcslen strlen
  #define tcsnlen strnlen
  #define tmemcpy memcpy
  #define tmemmove memmove
  #define tmemset memset
  #define tmemcmp memcmp
  #define tmemchr memchr
  #define tcscasecmp strcasecmp
  #define tcsncasecmp strncasecmp
  #define tcscasecmp_l strcasecmp_l
  #define tcsncasecmp_l strncasecmp_l
  #define tcpcpy stpcpy
  #define tcpncpy stpncpy
  #define tcstod strtod
  #define tcstof strtof
  #define tcstold strtold
  #define tcstol strtol
  #define tcstoul strtoul
  #define tcstoq strtoq
  #define tcstouq strtouq
  #define tcstoll strtoll
  #define tcstoull strtoull
  #define tcstol_l strtol_l
  #define tcstoul_l strtoul_l
  #define tcstoll_l strtoll_l
  #define tcstoull_l strtoull_l
  #define tcstod_l strtod_l
  #define tcstof_l strtof_l
  #define tcstold_l strtold_l
  #define tcsftime strftime
  #define fputts fputs
  #if !defined(_WIN32)
  #define stprintf snprintf
  #define vstprintf vsnprintf
  #else
  #define stprintf _snprintf
  #define vstprintf _vsnprintf
  #endif
  #define stscanf sscanf
  #define vstscanf vsscanf
  
  #define text_length str_length
  #define text_size str_size
  #define text_copy str_copy
  #define text_copy_new str_copy_new
  
  // curses
  #define MOVEYX   wmove
  #define PRINT    waddstr
  #define PRINTN   waddnstr
  #define PRINTC   waddch
  
#endif

#endif


