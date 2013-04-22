# -----------------------------------------------------------------------
# Makefile for curses user interface programs on Eis/Fair
#
# Creation     : 13.03.2004
# Last Modified: $Id: Makefile 28336 2011-05-08 18:32:34Z dv $
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

# unicode support
CFLAGS_UNICODE     =  -Wall -Wstrict-prototypes
CFLAGS_UNICODE    += -D_XOPEN_SOURCE_EXTENDED 
CFLAGS_UNICODE    += -D_UNICODE -D_GNU_SOURCE
CFLAGS_UNICODE    += -std=c99
CURSESLIB_UNICODE  = ncursesw

# flags for debug target
DEBUG_FLAGS        = -g

CFLAGS=$(CFLAGS_UNICODE)
CURSESLIB=$(CURSESLIB_UNICODE)

# linker
LDFLAGS_SHARED     = -lcui -lcui-util -ldl -l$(CURSESLIB)

# ----------------------------------------------------------------------
# Objetcs to build
# ----------------------------------------------------------------------

# output files
OUTPUT_SHARED      = show-doc.cui

# files
C_OBJECTS          =  main.o
C_OBJECTS         +=  mainwin.o
C_OBJECTS         +=  pagerview.o
C_OBJECTS         +=  pagerfile.o
C_OBJECTS         +=  index.o

# ----------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------

debug: CFLAGS += $(DEBUG_FLAGS)
debug: all

# compile targets
all:  $(OUTPUT_SHARED) 

$(OUTPUT_SHARED): $(C_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -o $@ $^ $(LDFLAGS_SHARED)

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
	@strip -R .note -R .comment $(OUTPUT_SHARED)
	@cp $(OUTPUT_SHARED) $(DESTDIR)/var/install/bin

# clean build directory
clean :
	@echo "cleaning up build directory ..."
	@rm -f *.o
	@rm -f *.d
	@rm -f *.cui

