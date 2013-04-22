CC =$(shell if which kgcc > /dev/null 2>&1; then echo kgcc; else echo gcc; fi)
CFLAGS = -s -fstrength-reduce -Wall -s -march=i486 -mcpu=i586 -fomit-frame-pointer

TARGETS =	xmlsplit

all:	$(TARGETS)
	strip -R .note -R .comment $(TARGETS)

clean:
	rm -f $(TARGETS)

xmlsplit: xmlsplit.c
	$(CC) $(CFLAGS) xmlsplit.c -o xmlsplit

