CC =$(shell if which kgcc > /dev/null 2>&1; then echo kgcc; else echo gcc; fi)
CFLAGS = -s -fstrength-reduce -Wall -s -fomit-frame-pointer

TARGETS =	netcalc

all:	$(TARGETS)
	strip -R .note -R .comment $(TARGETS)

clean:
	rm -f $(TARGETS)

netcalc: netcalc.c
	$(CC) $(CFLAGS) netcalc.c -o netcalc
