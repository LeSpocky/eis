# Makefile for flicp
# programm from 
# 
# Copyright (C) 2002 Christopher Loessl <cloessl@gmx.net>
# Copyright (C) 2002 Stefan Strigler <steve@zeank.in-berlin.de>
#
# This programm is under the GPL 2
#
#  Created:             2002 08 03
#  Last updated:        2003 03 10


CC = gcc
CFLAGS = -ggdb -Wall

flicp: flicp.o comi.o

clean:
	@rm -f *.o flicp *~

install: flicp
	@cp ./flicp /usr/local/bin/flicp

uninstall:
	@rm /usr/local/bin/flicp

tar-ball:
	@tar cvfz flicp.tgz *.c Makefile README AUTHORS COPYING

bz2-ball:
	@tar cvfj flicp.tgz *.c Makefile README AUTHORS COPYING
