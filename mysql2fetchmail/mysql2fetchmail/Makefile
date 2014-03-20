# -----------------------------------------------------------------------
# Makefile for mysql2fetchmail
#
# Creation     : Jens Vehlhaber 13.03.2004
# Last Modified: $Id: Makefile 7411 2006-08-06 17:38:38Z jv $
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------

# Release
# CCFLAGS = -Wall
CC=gcc
CFLAGS = -Wall -Wstrict-prototypes -O2

# Debug
CCFLAGS = -Wall -g

# Debug + Profiling
# CCFLAGS = -Wall -g -pg

LDFLAGS_SHARED = -lmysqlclient

all: mysql2fetchmail

mysql2fetchmail: mysql2fetchmail.c
	$(CC) -o $@ $^ $(LDFLAGS_SHARED)
	strip -R .note -R .comment mysql2fetchmail

install: fetchmysql
	strip -R .note -R .comment mysql2fetchmail

clean :
	rm *.o
	rm mysql2fetchmail

