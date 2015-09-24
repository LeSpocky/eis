PROJECT=picadstat
SOURCES=picadstat.c
INCPATHS=
LIBPATHS=
LDFLAGS=-lpifacecad -lmcp23s17
CFLAGS=-c -Wall
CC=gcc
STRIP=strip

all: picadstat

picadstat: picadstat.c
	$(CC) -o $@ $^ $(LDFLAGS)
	$(STRIP) -R .note -R .comment picadstat


clean :
	rm -f *.o
	rm picadstat
