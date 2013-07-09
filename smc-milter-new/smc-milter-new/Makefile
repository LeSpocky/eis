# Wedit Makefile for project smc-milter-new
#
# Optional builds
#	ALTERMIME_PRETEXT - Allows prefixing of the email body with a file, sort of the
#								opposite of a disclaimer.
#ALTERMIME_OPTIONS=-DALTERMIME_PRETEXT
PRG_OPTIONS=
CFLAGS=-Wall -Werror -g -I. -O2 $(PRG_OPTIONS)


.c.o:
	${CC} ${CFLAGS} -c $*.c

all: smc-milter-new

smc-milter-new: smc-milter.o utils.o virus.o ${OBJS}
	@rm -f smc-milter-new
	${CC} ${CFLAGS} smc-milter.o utils.o virus.o -lmilter -lpthread -lmysqlclient -o smc-milter-new
	strip -R .note -R .comment smc-milter-new
	rm -f *.o


clean:
	rm -f *.o smc-milter-new
