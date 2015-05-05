# -----------------------------------------------------------------------
# Makefile for curses user interface programs on Eis/Fair
#
# Creation     : 20.09.2007
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
CFLAGS      =  -Wall -Wextra -Wstrict-prototypes 
#-g
CFLAGS     += -D_XOPEN_SOURCE_EXTENDED
CFLAGS     += -D_GNU_SOURCE
CFLAGS     += -std=c99

# linker
LDFLAGS_SHARED     = -lcui
LDFLAGS_SHARED    += -lcui-util
LDFLAGS_SHARED    += -lcui-script
LDFLAGS_SHARED    += -ldl
LDFLAGS_SHARED    += -lncursesw

LDFLAGS_STATIC     = /usr/lib/libcui-script.a
LDFLAGS_STATIC    += /usr/lib/libcui-util.a
LDFLAGS_STATIC    += /usr/lib/libcui.a
LDFLAGS_STATIC    += -ldl
LDFLAGS_STATIC    += -lncursesw

# ----------------------------------------------------------------------
# Objetcs to build
# ----------------------------------------------------------------------

# output files
OUTPUT_SHARED      = edit-conf.cui
OUTPUT_STATIC      = edit-conf.static.cui

# files
C_OBJECTS          =  main.o
C_OBJECTS         +=  mainwin.o
C_OBJECTS         +=  expfile.o
C_OBJECTS         +=  conffile.o
C_OBJECTS         +=  confview.o
C_OBJECTS         +=  createdlg.o
C_OBJECTS         +=  check.o
C_OBJECTS         +=  cfg.o
C_OBJECTS         +=  exp.o

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

# pattern build rule c->o
%.o: %.c
	@echo "building $*.c ..."
	@$(CC) -c  $(CFLAGS) $*.c -o $*.o
	@$(CC) -MM $(CFLAGS) $*.c > $*.d
	@mv -f $*.d $*.d.tmp
	@sed -e 's|.*:|$*.o:|' < $*.d.tmp > $*.d
	@cp -f $*.d $*.d.tmp
	@sed -e 's/.*://' -e 's/\\$$//' < $*.d.tmp | fmt -1 | sed -e 's/^ *//' -e 's/$$/:/' >> $*.d
	@rm -f $*.d.tmp

# pattern build rule l->c
%.c: %.l
	@echo "generating $*.c from $*.l ..."
	@$(FLEX) -P$* -o$*.c $*.l

# install and uninstall
install: $(OUTPUT_SHARED)
	@echo "installing $(OUTPUT_SHARED)..."
	@mkdir -p $(DESTDIR)/var/install/bin
	@strip -R .note -R .comment $(OUTPUT_SHARED)
	@cp $(OUTPUT_SHARED) $(DESTDIR)/var/install/bin
	@mkdir -p $(DESTDIR)/var/install/include
	@cp ecelib $(DESTDIR)/var/install/include

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
