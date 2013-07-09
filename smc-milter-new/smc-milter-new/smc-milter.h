/*
 * smc-milter.h
 *
 * Description: Basic configuration
 *
 */

#ifndef _SMC_H
#define _SMC_H 1

#include <libmilter/mfapi.h>

#define MILTER		"SMC-milter"
#define PROJECT_NAME	"SMC ANTI-VIRUS E-MAIL FILTER."
#define COPYRIGHT	"Copyright (c) 2003-2010 Aleksander Djuric. All rights reserved."
#define DEVELOPERS	"Developed by:\n\n \
	Aleksander Djuric <ald@true-audio.com>\n \
	Pavel Zhilin <pzh@true-audio.com>\n \
	Stanislav Ivankin <stas@concat.info>\n \
	Jens Vehlhaber <jens@eisfair.org>"

#define STAT_LOCAL	1
#define STAT_RELAY	2
#define STAT_WARN	4
#define STAT_TEMP	8
#define STAT_PASS	16

/*body replacing */
#define STAT_SIGNATURE   1
#define STAT_FILEREMOVE  2


#define MAILER_HEADER	"X-Mailer"
#define FLAG_HEADER	"X-Spam-Flag"
#define REPORT_HEADER	"X-Spam-Report"
#define CHECKER_HEADER	"X-Content-Checker"
#define CLAMD_HEADER	"X-Virus-Scanned"
#define DEFAULT_USER	"root"
#define DEFAULT_DOMAIN  "localhost"

#define STR_CRLF        "\r\n"
#define FILEIOTIMEOUT   30

#define TMP_FILE_SIZE   64

#define DEFAULT_ACTION	0
#define SOCKET_TIMEOUT	600
#define MQUEUE_COST	300
#define MQUEUE_LIMIT	2
#define MQUEUE_LIFETIME 3600
#define ACCESS_LIFETIME 604800
#define CACHE_LIFETIME  86400

#define MAXMX		8
/* #define MAXLINE		4096 */
#define MAXLINE		1024
/* #define HEADER_SIZE	MAXLINE */
#define HEX_DIGEST	"0123456789ABCDEF"
#define MD5_STRING_LENGTH (MD5_DIGEST_LENGTH * 2)

#ifndef bool
#define bool   int
#define TRUE   1
#define FALSE  0
#endif /* ! bool */

struct ALTERMIMEAPP_globals {
	char tmpdir[1024];
	char *input_file;
	int input_is_stdin;
	char *disclaimer_file;
	char *disclaimer_html_file;
	char *disclaimer_b64_file;
	char *disclaimer_attachment;
	int   disclaimer_insert;
	char *pretext_file;
	char *pretext_html_file;
	char *pretext_b64_file;
	int   pretext_insert;
	char *remove_filename;
	char *replace;
	char *with;
	char *xheader;
	char *embedded_file;
	char *embedded_cid;
	char *embedded_type;
	char *embedded_list;
	char *alter_header;
	char *alter_with;
	int alter_mode;
	int verbose;
};

sfsistat mlfi_cleanup(SMFICTX *ctx, sfsistat rc);
int externalcommand(SMFICTX *ctx, char *workdir, int fd, char *p, char **av);
int externalbody(SMFICTX *ctx, int nOperation );
bool db_test( void );
int main(int argc, char** argv);

#endif /* SMC */
