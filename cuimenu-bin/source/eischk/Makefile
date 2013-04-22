#----------------------------------------------------------------------------
#  unix/Makefile
#
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  Creation:       03.05.2000  fm
#  Last Update:    $Id: Makefile 12467 2006-11-16 13:43:46Z tobig $
#----------------------------------------------------------------------------

CFLAGS  :=-O2
ifeq ($(DATE),)
CFLAGS+=-DDATE='"eisfair config check - 2012-11-07"'
else
CFLAGS+=-DDATE='"$(DATE)"'
endif

VERBOSE:=@

LDFLAGS+=$(STATIC) -s

EXEEXT:=
EXECUTABLES:=mkfli4l imonc regexp flicp/flicp squeeze tar-filter \
		gen_init_cpio gen_init_tar
include Makefile.inc

flicp: flicp/flicp

flicp/flicp:
	make -C flicp

grammar.c: grammar.y
	touch grammar.c

lex.c: lex.l
	touch lex.c

lex.cfg.c: cfg.l
	touch lex.cfg.c

squeeze.c: squeeze.l
	touch squeeze.c

eischk: mkfli4l
	$(VERBOSE)mv -f mkfli4l eischk
	$(VERBOSE)strip -R .note -R .comment eischk
