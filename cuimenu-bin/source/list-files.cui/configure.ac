# -----------------------------------------------------------------------
# autoconf configure.ac for show-doc.cui
#
# Creation     : 2015-10-18
# Last Modified: $Id$
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------

AC_INIT([list-files.cui], [3.0.0], [daniel@eisfair.org])

m4_include([m4/ax_with_curses.m4])
m4_include([m4/ax_check_cflags.m4])

AC_PROG_CC([gcc cc])
AC_PROG_CC_C99
AX_CHECK_CFLAGS([-std=c99 -pedantic])
AC_PROG_LEX
AC_PROG_SED
AC_CHECK_PROG([FMT_CHECK],   [fmt], [yes], [no])
if test x"$FMT_CHECK" != x"yes" ; then
   AC_MSG_ERROR([fmt console command not found!])
fi
AC_CHECK_PROG([MV_CHECK],   [mv], [yes], [no])
if test x"$MV_CHECK" != x"yes" ; then
   AC_MSG_ERROR([mv console command not found!])
fi
AC_CHECK_PROG([MKDIR_CHECK],   [mkdir], [yes], [no])
if test x"$MKDIR_CHECK" != x"yes" ; then
   AC_MSG_ERROR([mkdir console command not found!])
fi
AC_CHECK_PROG([CP_CHECK],   [cp], [yes], [no])
if test x"$CP_CHECK" != x"yes" ; then
   AC_MSG_ERROR([cp console command not found!])
fi
AC_CHECK_PROG([RM_CHECK],   [rm], [yes], [no])
if test x"$RM_CHECK" != x"yes" ; then
   AC_MSG_ERROR([rm console command not found!])
fi
AX_WITH_CURSES
if test x"$ax_cv_ncursesw" != x"yes" ; then
   AC_MSG_ERROR([NcursesW library was not found])
fi
AC_CHECK_HEADER([cui.h])
AC_CHECK_HEADER([cui-util.h])
AC_CHECK_HEADER([cui-char.h])
AC_CHECK_HEADER([cui-script.h])
AC_CHECK_LIB([cui], [WindowStart])
AC_CONFIG_FILES([Makefile])
AC_CONFIG_HEADER([config.h])
AC_OUTPUT
