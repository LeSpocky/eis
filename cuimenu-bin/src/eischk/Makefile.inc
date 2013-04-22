COMMONSOURCES	:= var.c set_var.c check.c log.c str.c regex.c parse.c \
		   tree.c tree_debug.c array.c
SOURCES		:= mkfli4l.c regexp-main.c $(COMMONSOURCES)
LIBSOURCES	:= options.c convert.c grammar.c lex.c lex.cfg.c \
		   mk_syslinux.c $(COMMONSOURCES)

all: $(EXECUTABLES)

clean:
	$(VERBOSE)$(RM) -f libmkfli4l.a y.output *.o *~
	-$(VERBOSE)$(MAKE) -C flicp clean

cleanall: clean
	$(VERBOSE)$(RM) -f $(EXECUTABLES)

mkfli4l$(EXEEXT): mkfli4l.o libmkfli4l.a
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

regexp$(EXEEXT): regexp-main.o libmkfli4l.a
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

squeeze$(EXEEXT): squeeze_main.o squeeze.o
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^

tar-filter$(EXEEXT): tar-filter.o
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^

gen_init_cpio$(EXEEXT): gen_init_cpio.o squeeze.o
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^

gen_init_tar$(EXEEXT): gen_init_tar.o squeeze.o
	@echo "  LD $(@F)"
	$(VERBOSE)$(CC) $(LDFLAGS) -o $@ $^

gen_init_tar.o: gen_init_tar.c cpio_conv.c

gen_init_cpio.o: gen_init_cpio.c cpio_conv.c

libmkfli4l.a: $(patsubst %.c,%.o,$(LIBSOURCES))
	@echo "  AR $(@F)"
	$(VERBOSE)$(AR) rcs $@ $^

%.o: %.c
	@echo "  CC $*.o"
	$(VERBOSE)$(CC) $(CFLAGS) -o $@ -c $(VPATH)$*.c

imonc: imonc.c
	$(VERBOSE)$(CC) -s -O2 -o $@ $< -lncurses

mini-imonc: imonc.c
	$(VERBOSE)$(CC) -s -DFLI4L -O2 -fstrength-reduce -o $@ $<

# vim: set ft=make:
