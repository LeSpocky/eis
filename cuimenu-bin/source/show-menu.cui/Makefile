# -----------------------------------------------------------------------
# Makefile for curses user interface programs on Eis/Fair
#
# Creation     : 13.03.2004
# Last Modified: $Id: Makefile 33544 2013-04-21 13:12:20Z dv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Tool settings
# ----------------------------------------------------------------------

# Tools
CC   = gcc
FLEX = flex

# compile options
CFLAGS     =  -Wall -Wextra -Wstrict-prototypes -g 
CFLAGS    += -D_XOPEN_SOURCE_EXTENDED 
CFLAGS    += -D_GNU_SOURCE
CFLAGS    += -std=c99

# linker
LDFLAGS_SHARED     = -lcui -lcui-util -ldl -lncursesw
LDFLAGS_STATIC     = /usr/lib/libcui.a /usr/lib/libcui-util.a
LDFLAGS_STATIC    += -ldl
LDFLAGS_STATIC    += -lncursesw

# ----------------------------------------------------------------------
# Objetcs to build
# ----------------------------------------------------------------------

# output files
OUTPUT_SHARED      = show-menu.cui
OUTPUT_STATIC      = show-menu.static.cui

# files
C_OBJECTS          =  main.o
C_OBJECTS         +=  mainwin.o
C_OBJECTS         +=  shelldlg.o
C_OBJECTS         +=  eismenu.o

# ----------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------

# compile targets
all:  $(OUTPUT_SHARED)

$(OUTPUT_SHARED): $(C_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -o $@ $^ $(LDFLAGS_SHARED)

$(OUTPUT_STATIC): $(C_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -o $@ $^ $(LDFLAGS_STATIC)

# include dependencies
-include $(C_OBJECTS:.o=.d)

# pattern build rule
%.o: %.c
	@echo "building $*.c ..."
	@$(CC) -c  $(CFLAGS) $*.c -o $*.o
	@$(CC) -MM $(CFLAGS) $*.c > $*.d
	@mv -f $*.d $*.d.tmp
	@sed -e 's|.*:|$*.o:|' < $*.d.tmp > $*.d
	@cp -f $*.d $*.d.tmp
	@sed -e 's/.*://' -e 's/\\$$//' < $*.d.tmp | fmt -1 | sed -e 's/^ *//' -e 's/$$/:/' >> $*.d
	@rm -f $*.d.tmp

# install and uninstall
install: $(OUTPUT_SHARED)
	@echo "installing $(OUTPUT_SHARED)..."
	@mkdir -p $(DESTDIR)/var/install/bin
	@strip -R .note -R .comment $(OUTPUT_SHARED)
	@cp $(OUTPUT_SHARED) $(DESTDIR)/var/install/bin

install_static: $(OUTPUT_SHARED) $(OUTPUT_STATIC)
	@echo "installing $(OUTPUT_STATIC)..."
	@mkdir -p $(DESTDIR)/var/install/bin
	@strip $(OUTPUT_STATIC)
	@cp $(OUTPUT_STATIC) $(DESTDIR)/var/install/bin

# clean build directory
clean :
	@echo "cleaning up build directory ..."
	@rm -f *.o
	@rm -f *.d
	@rm -f *.cui
