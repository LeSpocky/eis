undefined reference to locale_charset

run ./configure
go to eglib/
open config.h and replace following string
 #define HAVE_LOCALCHARSET_H 1
by
 #define HAVE_LOCALCHARSET_H 0


ld: final link failed: Bad value

There's a very simple way to avoid this problem in the future. Pass --enable-maintainer-mode to the configure script. This will make sure that when building mono it will check if the input files for the Makefiles have changed.


