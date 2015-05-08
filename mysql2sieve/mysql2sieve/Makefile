# -----------------------------------------------------------------------
# Makefile for mysql2sieve
#
# Creation     : 2010-05-28 Jens Vehlhaber jens@eisfair.org
# Last Modified: $Id: Makefile 7411 2007-04-05 17:38:38Z jv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------

# Release
# CCFLAGS = -Wall
CC=gcc
CFLAGS = -Wall -Wstrict-prototypes -g

# Debug
CCFLAGS = -Wall -g

# Debug + Profiling
# CCFLAGS = -Wall -g -pg

LDFLAGS_SHARED = -lmysqlclient 
#-liconv

all: mysql2sieve

mysql2sieve: mysql2sieve.o utf8function.o
	$(CC) -o $@ $^ $(LDFLAGS_SHARED) 
	strip -R .note -R .comment mysql2sieve
	rm *.o

clean :
	rm *.o
	rm mysqlsievefilter

