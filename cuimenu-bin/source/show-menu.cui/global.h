#ifndef GLOBAL_H
#define GLOBAL_H

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#if defined HAVE_NCURSESW_CURSES_H
#  include <ncursesw/curses.h>
#elif defined HAVE_NCURSESW_H
#  include <ncursesw.h>
#elif defined HAVE_NCURSES_CURSES_H
#  include <ncurses/curses.h>
#elif defined HAVE_NCURSES_H
#  include <ncurses.h>
#elif defined HAVE_CURSES_H
#  include <curses.h>
#else
#  error "SysV or X/Open-compatible Curses header file required"
#endif

#include <cui.h>
#include <cui-util.h>
#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <stdio.h>
#include <errno.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>


#define VERSION     3
#define SUBVERSION  0
#define PATCHLEVEL  2
#define BUILD       0

#define  VERSIONSTR PACKAGE_VERSION
#define  BUILDSTR   "(0) unicode/title option"


#endif
