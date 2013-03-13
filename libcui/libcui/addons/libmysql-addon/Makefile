# -----------------------------------------------------------------------
# Makefile for curses user interface programs on Eis/Fair
#
# Creation     : 11.10.2009
# Last Modified: $Id: Makefile 25015 2010-07-17 14:02:25Z dv $
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
CFLAGS_UNICODE     =  -Wall -Wstrict-prototypes -g 
CFLAGS_UNICODE    += -D_XOPEN_SOURCE_EXTENDED 
CFLAGS_UNICODE    += -D_UNICODE -D_GNU_SOURCE
CFLAGS_UNICODE    += -std=c99
CURSESLIB_UNICODE  = ncursesw

# additional library flags
CLIBFLAGS = -fPIC

CFLAGS=$(CFLAGS_UNICODE) -I/usr/include/mysql
CURSESLIB=$(CURSESLIB_UNICODE)

# linker
LDFLAGS     = /usr/lib/libmysqlclient.so.18 
LDFLAGS    += -lcui -lcui-util -lcui-script
LDFLAGS    += -l$(CURSESLIB)

# ----------------------------------------------------------------------
# Objetcs to build
# ----------------------------------------------------------------------

# output files
LIB_VERSION        = 1.0.0
LIB_NAME           = libmysql-addon
INC_NAME           = mysqllib-1

# files
C_OBJECTS          =  libmain.o
C_OBJECTS         +=  chartools.o
C_OBJECTS         +=  server.o
C_OBJECTS         +=  server_api.o
C_OBJECTS         +=  inifile.o

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
	@echo "installing $(LIB_NAME) ..."
	@mkdir -p $(DESTDIR)/usr/lib/cui-addons
	@mkdir -p $(DESTDIR)/var/install/include
	@strip -R .note -R .comment $(LIB_NAME).so.$(LIB_VERSION)
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
