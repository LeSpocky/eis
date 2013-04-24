# -----------------------------------------------------------------------
# Makefile for curses user interface programs on eisfair
#
# Creation     : 2009 Daniel Vogel, <daniel@eisfair.org>
# Last Modified: $Id: Makefile 25015 2013-03-01 07:10:25Z jv $
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
CFLAGS_UNICODE     = -D_ATFILE_SOURCE -Wall -Wstrict-prototypes -g 
CFLAGS_UNICODE    += -D_XOPEN_SOURCE_EXTENDED 
CFLAGS_UNICODE    += -D_UNICODE -D_GNU_SOURCE
#CFLAGS_UNICODE    += -std=c99 
CURSESLIB_UNICODE  = ncursesw

# additional library flags
CLIBFLAGS = -fPIC 

# check platform target
CFLAGS=$(CFLAGS_UNICODE) 
CURSESLIB=$(CURSESLIB_UNICODE)

# linker
LDFLAGS     = -lcui -lcui-util -lcui-script
LDFLAGS    += -l$(CURSESLIB) -lcrypto -lz

# ----------------------------------------------------------------------
# Objetcs to build
# ----------------------------------------------------------------------

# output files
LIB_VERSION        = 2.0.0
LIB_NAME           = libapk-addon
INC_NAME           = apklib-2

# files
C_OBJECTS          =  libmain.o
C_OBJECTS         +=  chartools.o
C_OBJECTS         +=  pm_api.o
# files from alpine apk
C_OBJECTS         +=  common.o
C_OBJECTS         +=  database.o
C_OBJECTS         +=  package.o
C_OBJECTS         +=  archive.o
C_OBJECTS         +=  version.o
C_OBJECTS         +=  io.o
C_OBJECTS         +=  url.o
C_OBJECTS         +=  gunzip.o
C_OBJECTS         +=  blob.o
C_OBJECTS         +=  hash.o
C_OBJECTS         +=  print.o
C_OBJECTS         +=  solver.o

# ----------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------

# compile targets
$(LIB_NAME).so.$(LIB_VERSION): $(C_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -shared -Wl,-soname,$(LIB_NAME).so.1 -o $@ $^ $(LDFLAGS)

# include dependencies
-include $(C_OBJECTS:.o=.d)

# pattern build rule
%.o: %.c
	@echo "building $*.c ..."
	@$(CC) -c  $(CLIBFLAGS) $(CFLAGS) $*.c -o $*.o
	@$(CC) -MM $(CLIBFLAGS) $(CFLAGS) $*.c > $*.d
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
install: $(LIB_NAME).so.$(LIB_VERSION)
	@strip -R .note -R .comment $(LIB_NAME).so.$(LIB_VERSION)
	@echo "installing $(LIB_NAME) ..."
	@mkdir -p $(DESTDIR)/usr/lib/cui-addons
	@mkdir -p $(DESTDIR)/var/install/include
	@cp    $(LIB_NAME).so.$(LIB_VERSION) $(DESTDIR)/usr/lib/cui-addons
	@cp    $(INC_NAME) $(DESTDIR)/var/install/include

# clean build directory
clean :
	@echo "cleaning up build directory ..."
	@rm -f *.a
	@rm -f *.o
	@rm -f *.d
	@rm -f *.so.*
	@rm -f *.cui
