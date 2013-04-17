# -----------------------------------------------------------------------
# Makefile for curses user interface programs on Eis/Fair
#
# Creation     : 13.03.2004
# Last Modified: $Id: Makefile 33478 2013-04-15 17:44:11Z dv $
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
CC=gcc
FLEX=flex

# unicode support
CFLAGS          = -Wall -Wextra
CFLAGS         += -Wstrict-prototypes 
CFLAGS         += -Wimplicit-function-declaration
CFLAGS         += -D_XOPEN_SOURCE_EXTENDED 
CFLAGS         += -D_UNICODE -D_GNU_SOURCE
CFLAGS         += -std=c99
CFLAGS         += -g
CURSESLIB       = ncursesw

# additional library flags
CLIBFLAGS       = -fPIC


# ----------------------------------------------------------------------
# Objetcs build from C code
# ----------------------------------------------------------------------

# version
CUI_VERSION   = 2.0.0

# files for test aplication
C_OBJECTS     =  main.o

# files for libcui
C_CUI_OBJECTS =  wrappers.o
C_CUI_OBJECTS += chartools.o
C_CUI_OBJECTS += window.o
C_CUI_OBJECTS += edit.o
C_CUI_OBJECTS += label.o
C_CUI_OBJECTS += button.o
C_CUI_OBJECTS += radio.o
C_CUI_OBJECTS += checkbox.o
C_CUI_OBJECTS += groupbox.o
C_CUI_OBJECTS += listbox.o
C_CUI_OBJECTS += combobox.o
C_CUI_OBJECTS += progressbar.o
C_CUI_OBJECTS += textview.o
C_CUI_OBJECTS += listview.o
C_CUI_OBJECTS += terminal.o
C_CUI_OBJECTS += menu.o
C_CUI_OBJECTS += msgbox.o
C_CUI_OBJECTS += finddlg.o
C_CUI_OBJECTS += inputdlg.o
C_CUI_OBJECTS += passwddlg.o

# files for libcui-util
C_CUI_UTIL_OBJECTS =  xmlparser.o
C_CUI_UTIL_OBJECTS += config.o
C_CUI_UTIL_OBJECTS += coproc.o
C_CUI_UTIL_OBJECTS += xml.o
C_CUI_UTIL_OBJECTS += cfg.o

# files for libcui-script
C_CUI_SCRIPT_OBJECTS = backend.o
C_CUI_SCRIPT_OBJECTS += api.o
C_CUI_SCRIPT_OBJECTS += api_ctrl.o
C_CUI_SCRIPT_OBJECTS += api_util.o
C_CUI_SCRIPT_OBJECTS += stub.o


# ----------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------

# compile targets
all:  libcui.so.$(CUI_VERSION) libcui.a \
      libcui-util.so.$(CUI_VERSION) libcui-util.a \
      libcui-script.so.$(CUI_VERSION) libcui-script.a

test: test.cui

test.cui: $(C_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -o $@ $^ -lcui -lcui-util -liconv

libcui.so.$(CUI_VERSION): $(C_CUI_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -shared -Wl,-soname,libcui.so.2 -o $@ $^ -l$(CURSESLIB) -liconv

libcui.a: $(C_CUI_OBJECTS)
	@rm -f $@
	@ar rs $@ $^

libcui-util.so.$(CUI_VERSION): $(C_CUI_UTIL_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -shared -Wl,-soname,libcui-util.so.2 -o $@ $^

libcui-util.a: $(C_CUI_UTIL_OBJECTS)
	@rm -f $@
	@ar rs $@ $^
	
libcui-script.so.$(CUI_VERSION): $(C_CUI_SCRIPT_OBJECTS)
	@echo "linking $@ ..."
	@$(CC) -L./ -shared -Wl,-soname,libcui-script.so.2 -lcui -lcui-util -ldl -o $@ $^
	
libcui-script.a: $(C_CUI_SCRIPT_OBJECTS)
	@rm -f $@
	@ar rs $@ $^

# include dependencies
-include $(C_OBJECTS:.o=.d)
-include $(C_CUI_OBJECTS:.o=.d)
-include $(C_CUI_UTIL_OBJECTS:.o=.d)
-include $(C_CUI_SCRIPT_OBJECTS:.o=.d)

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
install: libcui-script.so.$(CUI_VERSION) libcui-util.so.$(CUI_VERSION) libcui.so.$(CUI_VERSION)
	@echo "installing libcui $(CUI_VERSION)"
	@mkdir -p $(DESTDIR)/usr/include
	@mkdir -p $(DESTDIR)/usr/lib
	@mkdir -p $(DESTDIR)/var/install/include
	@cp libcui.so.$(CUI_VERSION) $(DESTDIR)/usr/lib
	@cp libcui-script.so.$(CUI_VERSION) $(DESTDIR)/usr/lib
	@cp libcui-util.so.$(CUI_VERSION) $(DESTDIR)/usr/lib
	@cp libcui-script.a $(DESTDIR)/usr/lib
	cp libcui-util.a $(DESTDIR)/usr/lib
	@cp libcui.a $(DESTDIR)/usr/lib
	@ldconfig -n $(DESTDIR)/usr/lib
	@ln -s $(DESTDIR)/usr/lib/libcui.so.$(CUI_VERSION) libcui.so
	@ln -s $(DESTDIR)/usr/lib/libcui-script.so.$(CUI_VERSION) libcui-script.so
	@ln -s $(DESTDIR)/usr/lib/libcui-util.so.$(CUI_VERSION) libcui-util.so
	@cp cui.h $(DESTDIR)/usr/include
	@cp cui-char.h $(DESTDIR)/usr/include
	@cp cui-util.h $(DESTDIR)/usr/include
	@cp cui-script.h $(DESTDIR)/usr/include
	@cp cuilib $(DESTDIR)/var/install/include

# clean build directory
clean :
	@echo "cleaning up build directory ..."
	@rm -f *.a
	@rm -f *.o
	@rm -f *.d
	@rm -f *.so.*
	@rm -f *.cui

