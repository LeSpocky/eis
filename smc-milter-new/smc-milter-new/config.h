/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.in by autoheader.  */

/* ClamAV socket file. */
#define CLAMD_SOCKET_FILE "/run/clamav/clamd.sock"

/* SMC milter configuration file. */
#define CONFIG_FILE "/etc/smc-milter-new/smc-milter-new.conf"

/* Define to 1 if you have the `milter' library (-lmilter). */
#define HAVE_LIBMILTER 1

/* Define to 1 if you have the `pthread' library (-lpthread). */
#define HAVE_LIBPTHREAD 1

/* SMC milter hosts file. */
#define HOSTS_FILE "/etc/smc-milter-new/smc-milter-new.hosts"

/* altermime program file. */
#define ALTERMIME_FILE "/usr/bin/altermime"

/* Name of package */
#define PACKAGE "smc-milter-new"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "jens@eisfair.org"

/* Define to the full name of this package. */
#define PACKAGE_NAME "smc-milter-new"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "smc-milter-new 2.1"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "smc-milter-new"

/* Define to the version of this package. */
#define PACKAGE_VERSION "2.1"

/* SMC milter pid file. */
#define PID_FILE "/run/milter/smc-milter-new.pid"

/* Define as the return type of signal handlers (`int' or `void'). */
#define RETSIGTYPE void

/* Define to the type of arg 1 for `select'. */
#define SELECT_TYPE_ARG1 int

/* Define to the type of args 2, 3 and 4 for `select'. */
#define SELECT_TYPE_ARG234 (fd_set *)

/* Define to the type of arg 5 for `select'. */
#define SELECT_TYPE_ARG5 (struct timeval *)

/* SMC milter socket file. */
#define SOCKET_FILE "/run/milter/smc-milter-new.sock"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
#define TIME_WITH_SYS_TIME 1

/* SMC milter temporary file. */
#define TMP_FILE     "/var/tmp/smc-file.XXXXXX"

/* SMC milter signatur text temporary file. */
#define TMP_SIGNTXT  "/var/tmp/smc-signtxt.XXXXXX"

/* SMC milter signatur html temporary file. */
#define TMP_SIGNHTM  "/var/tmp/smc-signhtm.XXXXXX"

/* Begin of mozilla signature. */
#define MOZ_SIGNATURE "<pre class=\"moz-signature\" cols=\"72\">"

/* Version number of package */
#define VERSION "2.1"
