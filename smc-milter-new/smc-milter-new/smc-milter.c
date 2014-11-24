/*
 * smc-milter.c
 * Description:	 SMC anti-spam e-mail filter
 * Copyright (c) 2003-2008 Aleksander Djuric.
 *
 * jens@eisfair.org
 * remove autospf 
 * remove classicspf 
 * remove greylisting 
 * remove autoswl 
 * add antivirus operations
 * add signature from mysql table  
 */
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <assert.h>
#include <syslog.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <pthread.h>
#include <pwd.h>
#include <netinet/in.h>
#include <arpa/nameser.h>
#include <arpa/inet.h>
#include <resolv.h>
#include <netdb.h>
#include <mysql/mysql.h>
#include <libmilter/mfapi.h>
#include "smc-milter.h"
#include "utils.h"
#include "config.h"
#include "virus.h"

#if !defined O_SYNC && defined O_FSYNC
#define O_SYNC O_FSYNC
#endif

/* Static variables for config defaults, etc. */
static int  runmode    = 0;
static int  terminate  = 0;
static int  nochild    = 0;
static char *smfisock  = NULL;
static char *smfiuser  = NULL;
static char *dbhost    = NULL;
static int   dbport    = 0;
static char *dbname    = NULL;
static char *dbtable   = NULL;
static char *dbuser    = NULL;
static char *dbpass    = NULL;
static char *optremove = NULL;
static char *quarantinedir = NULL;
static char *avmail    = NULL;
static int  clamcheck  = 0;
static char *clamsock  = NULL;
static int  fprotcheck = 0;
static int  signatureadd = 0;
static int  debuglevel = 0;
static char *scriptfile = NULL;

/* Milter mutexes */
pthread_mutex_t mkstemp_mail_mtx = PTHREAD_MUTEX_INITIALIZER;

struct mlfiPriv {
	unsigned long status;
	long body_offset;                     /* offset from begin of file to data section */
	int  numTo;                           /* Number of people the message is going to */
	char helo_host[MAXLINE];
	char conn_addr[INET_ADDRSTRLEN];
	char from_addr[MAXLINE];
	char report[MAXLINE];
	char temp_mail[TMP_FILE_SIZE];        /* mail file complete, for virus scann! */
	char temp_signtxt[TMP_FILE_SIZE];     /* temp signature text file */
	char temp_signhtm[TMP_FILE_SIZE];     /* temp signature html file */
	char subject[MAXLINE];                /* Original subject */
	char **to;                            /* Who is the message going to */
	int  utf8;                            /* if found "charset=UTF-8" set to 1 */
	int child1pid;                        // pid from virus scanner script
	int child2pid;                        // pid from body script
};

#define MLFIPRIV ((struct mlfiPriv *) smfi_getpriv(ctx))


/* ----------------------------------------------------------------------------
 * check releay state
 * ----------------------------------------------------------------------------*/
int
check_relay (const char *conn, const char *hosts_file) {
	FILE *fh;
	char buffer[MAXLINE];
	uint32_t addr, network, netmask;
	int d1, d2, d3, d4, m1, m2, m3, m4;
	int found = 0;
	int ret;

	/* check for required data presented */
	if (!conn || *conn == '\0') return 0;
	
	addr = ntohl(inet_addr(conn));

	if ((addr & 0xffffff00) == 0xc0000200     /* 192.0.2.0/24    test network   */
	    ||  (addr & 0xffffff00) == 0xc0586300 /* 192.88.99.0/24  RFC 3068       */
	    ||  (addr & 0xffff0000) == 0xa9fe0000 /* 169.254.0.0/16  link local     */
	    ||  (addr & 0xffff0000) == 0xc0a80000 /* 192.168.0.0/16  private use    */
	    ||  (addr & 0xfffe0000) == 0xc6120000 /* 198.18.0.0/15   RFC 2544       */
	    ||  (addr & 0xfff00000) == 0xac100000 /* 172.16.0.0/12   private use    */
	    ||  (addr & 0xff000000) == 0x00000000 /* 0.0.0.0/8       "this" network */
	    ||  (addr & 0xff000000) == 0x7f000000 /* 127.0.0.0/8     loopback       */
	    ||  (addr & 0xff000000) == 0x0a000000 /* 10.0.0.0/8      private use    */
	    ||  (addr & 0xf0000000) == 0xe0000000 /* 224.0.0.0/4     RFC 3171       */
	    ) return 1;
	
	if (!(fh  = fopen(hosts_file, "r"))) {
	    syslog(LOG_ERR, "failed to open %s: ", hosts_file);
	    return -1;
	}

	while (fgets(buffer, MAXLINE, fh)) {
	    if (*buffer == '\r' || *buffer == '\n' ||
		*buffer == '#' || *buffer == ' ') continue;

	    d1 = d2 = d3 = d4 = 0;
	    m1 = m2 = m3 = m4 = 0;
	    network = netmask = 0;

	    ret = sscanf(buffer, "%3d.%3d.%3d.%3d/%3d.%3d.%3d.%3d",
		&d1, &d2, &d3, &d4, &m1, &m2, &m3, &m4);
	    switch (ret) {
	    case 1: /* 80.80.80 */
	    case 2:
	    case 3:
	    case 4:
		    netmask  = (d1|d2|d3|d4) ? 0xff000000 : 0;
		    netmask |= (d2|d3|d4) ? 0x00ff0000 : 0;
		    netmask |= (d3|d4) ? 0x0000ff00 : 0;
		    netmask |= (d4) ? 0x000000ff : 0;
		    break;
	    case 5: /* 80.80.80.0/8 */
		    if (m1 < 0 || m1 > 32) 
                continue;
		    netmask = (0xffffffff & (0xffffffff << (32 - m1)));
		    break;
	    case 8: /* 80.80.80.0/255.255.255.0 */
		    netmask = (m4 << 24) + ((m3 & 0xff) << 16) + ((m2 & 0xff) << 8) + (m1 & 0xff);
		    break;
	    default:
		    continue;
	    }

	    network = (d1 << 24) + ((d2 & 0xff) << 16) + ((d3 & 0xff) << 8) + (d4 & 0xff);
	    if ((addr & netmask) == (network & netmask)) {
		    found = 1;
		    break;
	    }
	}
		
	fclose (fh);
	return found;
}

/* ----------------------------------------------------------------------------
 * Store the name of the virus in the subject of the e-mail
 * ----------------------------------------------------------------------------*/
static void
setnewsubject(SMFICTX *ctx, const char *virusname) {
    struct mlfiPriv *priv = MLFIPRIV;
    char buffer[MAXLINE];

    memset(buffer, '\0', MAXLINE );
    if(priv->subject)
        smfi_addheader(ctx, "X-Original-Subject", priv->subject);
    snprintf(buffer, MAXLINE - 1, "[Virus] %s", virusname);
    if ( !priv->subject || *priv->subject == '\0')
        smfi_addheader(ctx, "Subject", buffer);
    else
        smfi_chgheader(ctx, "Subject", 1, buffer);
}


/* ----------------------------------------------------------------------------
 * replace original email body with new createt body 
 * ----------------------------------------------------------------------------*/
int
change_body(SMFICTX *ctx) {
    int errval, rc1, rc2 = 0;
    int fd = -1;
    ssize_t nread;
    unsigned char buffer[MAXLINE];
    struct mlfiPriv *priv = MLFIPRIV;

    if ((fd = open(priv->temp_mail, O_RDONLY)) < 0) {
        syslog(LOG_ERR, "can't open %s : %s", priv->temp_mail, strerror(errno));
        return -1;
    }
    /* go to the body begin */
    if( lseek( fd, priv->body_offset, SEEK_SET ) < 0 ) {
        syslog(LOG_ERR, "cannot seek to offset=%ld for file %s",priv->body_offset, priv->temp_mail );
        (void) close(fd); 
        return -1;
    }
    while( (rc1 = file_read( fd, buffer, sizeof(buffer), FILEIOTIMEOUT, &nread, &errval )) == 0 && nread > 0 ) {
        /* replace the message body */
        if( (rc2 = smfi_replacebody( ctx, (unsigned char*)buffer, nread )) != MI_SUCCESS ) break;
    }
    (void) close(fd);
    if (rc1 != 0) 
        syslog(LOG_ERR, "change_body: Error when reading message body, %s", strerror(errval));
    if (rc2 != 0) 
        syslog(LOG_ERR, "change_body: Error when replacing the original message body");
    syslog(LOG_INFO, "Body modified: %s", priv->temp_mail);
    return 0;
}


/* ----------------------------------------------------------------------------
 * add signature or disclaimer from mysql table
 * ----------------------------------------------------------------------------*/
bool
add_external_signature(SMFICTX *ctx ) {
    struct mlfiPriv *priv = MLFIPRIV;
    char buffer[MAXLINE]; 
    MYSQL_RES *result;
    MYSQL_ROW row;
    MYSQL *g_mysql;
    unsigned long *lengths;
    int row_count;
    int count = 0;
    int fd;
    FILE *fp;

    if ( file_signature_content( priv->temp_mail ) == 1 ){
        syslog(LOG_INFO, "Signatur found %s", priv->temp_mail );
        return FALSE;
    }
    snprintf(buffer, 1023, "SELECT signature FROM %s WHERE email = '%s' ORDER BY email LIMIT 1", dbtable, priv->from_addr );

    g_mysql= mysql_init( NULL );
    mysql_options(g_mysql, MYSQL_SET_CHARSET_NAME, "utf8");
    mysql_options(g_mysql, MYSQL_INIT_COMMAND, "SET NAMES utf8");

    if ( ! mysql_real_connect(g_mysql, dbhost, dbuser, dbpass, dbname, dbport, 0, 0)) {
        syslog(LOG_ERR, "add_external_signature: mysql_real_connect failed");
        syslog(LOG_ERR, "%s", mysql_error(g_mysql));
        mysql_close(g_mysql);
        return FALSE;
    }
    else  {
        /* Reconnect must be set *after* real_connect()! */
        mysql_options(g_mysql, MYSQL_OPT_RECONNECT, "1"); 
        if (debuglevel > 0)
             syslog(LOG_INFO, "mysql: new connect" );
    }

	while ( count < 4)
	{
        /* check the mysql connect */
        if (debuglevel > 0)
            syslog(LOG_INFO, "mysql_query: %s", buffer ); 
        if (mysql_query(g_mysql, buffer ) == 0) {
            /* get the results */
            result = mysql_store_result(g_mysql);
            row_count = mysql_num_rows(result);
            if (row_count) {
  	            if (*priv->temp_signtxt == '\0') {
	                strcpy(priv->temp_signtxt, TMP_SIGNTXT);
	                pthread_mutex_lock (&mkstemp_mail_mtx);
	                fd = mkstemp(priv->temp_signtxt);
	                pthread_mutex_unlock (&mkstemp_mail_mtx);
	                if (fd == -1) 
		                syslog(LOG_ERR, "mkstemp: can't create: %s", strerror(errno));
	                else {
                        fchmod(fd, 0644);
                       (void) close( fd );
                    }
		        }
  	            if (*priv->temp_signhtm == '\0') {
	                strcpy(priv->temp_signhtm, TMP_SIGNHTM);
	                pthread_mutex_lock (&mkstemp_mail_mtx);
	                fd = mkstemp(priv->temp_signhtm);
	                pthread_mutex_unlock (&mkstemp_mail_mtx);
	                if (fd == -1) 
		                syslog(LOG_ERR, "mkstemp: can't create: %s", strerror(errno));
	                else {
                        fchmod(fd, 0644);
                       (void) close( fd );
                    }
		        }
                fp = fopen(priv->temp_signtxt, "wb");
                row = mysql_fetch_row(result);
                lengths = mysql_fetch_lengths(result);
                if ( priv->utf8 == 0) {
                    /* if mail not utf-8 encoded then translate signature to ISO */
                    char *tmp1 = UTF8toISO(row[0], lengths[0]);
                    if (tmp1) {
                        fwrite(tmp1, strlen(tmp1), 1, fp);
                        free(tmp1);
                    } else {
                        fwrite(row[0], lengths[0], 1, fp);
                    }
                } else {
                    fwrite(row[0], lengths[0], 1, fp);
                }
                fwrite(STR_CRLF, strlen(STR_CRLF), 1, fp);
                fclose(fp);

                fp = fopen(priv->temp_signhtm, "wb");
                fwrite( MOZ_SIGNATURE, strlen(MOZ_SIGNATURE), 1, fp);
                char *tmp2 = UTF8toHTML(row[0], lengths[0]);
                if (tmp2) {
                    fwrite(tmp2, strlen(tmp2), 1, fp);
                    free(tmp2);
                } else
                    fwrite(row[0], lengths[0], 1, fp);
                fwrite("</pre>", 6, 1, fp);                
                fwrite(STR_CRLF, strlen(STR_CRLF), 1, fp);                        
                fclose(fp);
                if (externalbody( ctx, 3 ) != -1) {
                    syslog(LOG_INFO, "Signatur added %s", priv->temp_mail );
                }
            } else {
			    count = 4;
			}
            mysql_free_result(result); 
            break; 
        }
        else { 
            syslog(LOG_ERR, "mysql_query problem: %s", mysql_error(g_mysql) );
        } 
		count += 1;
        usleep(299999);
	    if (mysql_ping(g_mysql) != 0) {
   		    syslog(LOG_CRIT, "mysql_ping (%d): %s", mysql_errno(g_mysql), mysql_error(g_mysql)); 
        }
    }

    mysql_close( g_mysql );
    
    if (count > 3)
        return FALSE;   
    else
        return TRUE;
    
}


/* ----------------------------------------------------------------------------
 * run external anti-virus script
 * ----------------------------------------------------------------------------*/
int 
externalcommand(SMFICTX *ctx, char *workdir, int fd, char *p, char **av) {
    struct mlfiPriv *priv = MLFIPRIV;
    char *ev[]={"PATH=/bin:/usr/bin:/usr/local/bin",NULL};
    int i;
    int childstatus;
    int openmax=getdtablesize();

    if (debuglevel > 1)
        syslog(LOG_INFO,"externalcommand( %s )", p);
    if ((priv->child1pid) != 0) 
        syslog(LOG_CRIT,"externalcommand() called and priv->child1pid is %d", priv->child1pid);
    
    childstatus = 0;
    priv->child1pid = fork();
    switch(priv->child1pid) {
    case -1: /* error */
        syslog(LOG_CRIT, "fork(): %s", strerror(errno));
        priv->child1pid=0;
        return(-1);
        break;
    case 0: /* child */
        if (workdir!=NULL) {
	        if (chdir(workdir)!=0) {
	            syslog(LOG_CRIT, "chdir(%s): %s", workdir, strerror(errno));
	        }
	    }
        if (fd == EOF) {
	        close(0);
	        close(1);
	        close(2);
	        open("/dev/null", O_RDONLY);
	        open("/dev/null", O_WRONLY);
	        open("/dev/null", O_WRONLY);
	    } else {
	        close(0);
	        open("/dev/null", O_RDONLY);
	        dup2(fd, 1);
	        dup2(fd, 2);
	    }
        for (i=3;i<openmax;i++)
	        close(i);
        execve(p, av, ev);
        syslog(LOG_CRIT,"externalcommand() failed to execve() %s", p);
        exit(1);
        break;
    default: /* parent */
        waitpid(priv->child1pid,&(childstatus), 0);
        priv->child1pid = 0;
        if (WIFEXITED(childstatus)) {
	        if (debuglevel > 1)
	            syslog(LOG_INFO,"externalcommand( %s ) => %d", p, WEXITSTATUS(childstatus));
	        return(WEXITSTATUS(childstatus));
	    } else {
	        if (debuglevel > 1)
	            syslog(LOG_INFO,"externalcommand( %s ) => -1", p);
	        return(-1);
	    }
        break;
    }
    if (debuglevel > 1)
        syslog(LOG_INFO,"externalcommand( %s ) => -1", p);
    return(-1);
}

/* ----------------------------------------------------------------------------
 * run altermime - add signatur and remove attachment
 * ----------------------------------------------------------------------------*/
int 
externalbody(SMFICTX *ctx, int nOperation ) {
    struct mlfiPriv *priv = MLFIPRIV;
    int childstatus;
    char buff1[128];
    char buff2[128];
    char buff3[128];
    char buff4[128];
    
    memset(buff1, '\0', 128 );
    memset(buff2, '\0', 128 );
    memset(buff3, '\0', 128 );
    memset(buff4, '\0', 128 );

    snprintf(buff1, 127, "--input=%s", priv->temp_mail);
    if ( nOperation & 1 ) {
        snprintf(buff2, 127, "--disclaimer=%s", priv->temp_signtxt);
        snprintf(buff3, 127, "--disclaimer-html=%s", priv->temp_signhtm);
    }
    if ( nOperation & 2 ) {
        if (optremove)
            snprintf(buff4, 127, "--remove=%s", optremove );
    }
    
    childstatus = 0;
    priv->child2pid = fork();
    switch(priv->child2pid) {
      case -1: /* error */
        syslog(LOG_CRIT, "fork(): %s", strerror(errno));
        priv->child2pid = 0;
        return(-1);
        break;
      case 0: /* child */
        switch(nOperation) {
          case 1:  
          case 3:  
	        if (debuglevel > 1)      
                syslog(LOG_INFO, "altermime %s %s %s %s", buff1, buff2, buff3, buff4);
            // "--force-for-bad-html"    
            if( execl(ALTERMIME_FILE , "altermime", buff1, buff2, buff3, buff4, NULL ) < 0)
                syslog(LOG_CRIT,"Failed to run: altermime %s %s %s %s", buff1, buff2, buff3, buff4);
          case 2:  
	        if (debuglevel > 1)      
                syslog(LOG_INFO, "altermime %s %s", buff1, buff4);
            if( execl(ALTERMIME_FILE , "altermime", buff1, buff4, NULL ) < 0)
                syslog(LOG_CRIT,"Failed to run: altermime %s %s", buff1, buff4);
        }
        return(-1);
        break;
      default: /* parent */
        waitpid(priv->child2pid,&(childstatus), 0);
        priv->child2pid = 0;
        if (WIFEXITED(childstatus)) {
	        return(WEXITSTATUS(childstatus));
	    } else {
	        return(-1);
	    }
        break;
    }
    return(-1);
}

/* ----------------------------------------------------------------------------
 * Milter functions:
 * ----------------------------------------------------------------------------*/
sfsistat
mlfi_connect (SMFICTX *ctx, char *hostname, _SOCK_ADDR *hostaddr) {
	struct mlfiPriv *priv;
	struct sockaddr_in *conn;

	/* allocate memory for private data */
    priv = malloc(sizeof *priv);
    if (priv == NULL) {
        /* can't accept this message right now */
	    syslog(LOG_ERR, "%s", strerror(errno));
        return SMFIS_TEMPFAIL;
    }
    memset(priv, '\0', sizeof *priv);

	/* set private data pointer */
	if (smfi_setpriv(ctx, (void*)priv) != MI_SUCCESS) {
	    syslog(LOG_ERR, "can't set private data pointer");
	    free(priv);
	    return SMFIS_TEMPFAIL;
	}

	/* store connection data */
	if (!hostaddr) 
        strcpy(priv->conn_addr, "127.0.0.1");
	else {
	    conn = (struct sockaddr_in *) hostaddr;
	    if (!inet_ntop(AF_INET, &conn->sin_addr.s_addr,
		priv->conn_addr, INET_ADDRSTRLEN)) {
		syslog(LOG_ERR, "can't parse connect address: %s", strerror(errno));
		return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
	    }
	}
    priv->status = 0;

	return SMFIS_CONTINUE;
}


sfsistat
mlfi_helo (SMFICTX *ctx, char *helohost) {
	struct mlfiPriv *priv = MLFIPRIV;

	/* check for private data presented */
	if (!priv) return SMFIS_TEMPFAIL;

	/* check for required data presented */
	if (!helohost || *helohost == '\0') {
	    smfi_setreply(ctx, "501", "5.5.2", "HELO requires domain address");
	    return SMFIS_REJECT;
	}

	/* store helo hostname */
	strncpy(priv->helo_host, helohost, MAXLINE - 15);

	return SMFIS_CONTINUE;
}


sfsistat
mlfi_envfrom (SMFICTX *ctx, char **envfrom) {
	struct mlfiPriv *priv = MLFIPRIV;
	char *from_addr;

	/* check for private data presented */
	if (!priv) return SMFIS_TEMPFAIL;

	/* get macro data */
	if (!(from_addr = smfi_getsymval(ctx, "{mail_addr}"))) {
	    syslog(LOG_ERR, "mail_macro: {mail_addr} must be available");
	    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
	}

	/* workaround bogus address in MAIL FROM: <> */
	if (from_addr == '\0') {
	    snprintf(priv->from_addr, MAXLINE - 1, "postmaster@%s", priv->helo_host);
	    snprintf(priv->report, MAXLINE - 1, "couldn't verify sender");
	    priv->status |= STAT_WARN;
	    return SMFIS_CONTINUE;
	}

	strtolower(from_addr);
	strncpy(priv->from_addr, from_addr, MAXLINE - 1);

	/* accept local relay connections */
	if (check_relay(priv->conn_addr, HOSTS_FILE) > 0) {
	    priv->status |= STAT_RELAY;
	    return SMFIS_CONTINUE;
	}

	/* Is the user authenticated? */
	if (smfi_getsymval(ctx, "{auth_type}")) {
	    priv->status |= STAT_RELAY;
	    return SMFIS_CONTINUE;
	}

	return SMFIS_CONTINUE;
}


sfsistat
mlfi_envrcpt (SMFICTX *ctx, char **envrcpt) {
	struct mlfiPriv *priv = MLFIPRIV;
	int fd;
	const char *to;

	/* check for private data presented */
	if (!priv) return SMFIS_TEMPFAIL;

    /* Keep our dynamic linked list array of recipients update */
    if (priv->to == NULL) {
        priv->to = malloc(sizeof(char *) * 2);
        assert(priv->numTo == 0);
    } else
        priv->to = realloc(priv->to, sizeof(char *) * (priv->numTo + 2));

	/* get macro data */
    to = smfi_getsymval(ctx, "{rcpt_addr}");
    if(to == NULL)
        to = envrcpt[0];
    
    priv->to[priv->numTo] = strdup(to);
    priv->to[++priv->numTo] = NULL;
    
     /* create temp mail file, if not exists */
	if (*priv->temp_mail == '\0') {
	    strcpy(priv->temp_mail, TMP_FILE);
	    pthread_mutex_lock (&mkstemp_mail_mtx);
	    fd = mkstemp(priv->temp_mail);
	    pthread_mutex_unlock (&mkstemp_mail_mtx);
	    if (fd == -1) {
		    syslog(LOG_ERR, "mkstemp: can't create: %s", strerror(errno));
		    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
	    }
	    fchmod(fd, 0644);
        (void) close( fd );
    }   

    return SMFIS_CONTINUE;
}


sfsistat
mlfi_header (SMFICTX *ctx, char *headerf, char *headerv) {
	struct mlfiPriv *priv = MLFIPRIV;
	const char *splitter = ": ";
	int fd, errval;
	ssize_t nwritten;

	/* check for private data presented */
	if (!priv) return SMFIS_TEMPFAIL;

	/* check for required data presented */
	if (!headerf || !headerv)
	    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);

	/* skip null headers */
	if (*headerf == '\0') return SMFIS_CONTINUE;

	/* get subject if found */
    if(strcasecmp(headerf, "Subject") == 0) {
        strncpy(priv->subject, headerv, MAXLINE - 1);
        if (debuglevel > 2)
                syslog(LOG_INFO, "Header Subject: %s", headerv );
    }
    /* set default to UTF-8 */
    priv->utf8 = 1;
    /* get Content-Type header */
    if (strcasecmp(headerf, "Content-Type") == 0) {
        if ((strstr(headerv, "ISO-" )) || (strstr(headerv, "iso-" )))  {
            priv->utf8 = 0;
        }
        if (debuglevel > 1) {
            remove_crln( headerv );
            syslog(LOG_INFO, "Header Content-Type: %s ", headerv );
        }
    }
 
    if (*priv->temp_mail) {
		if ((fd = open(priv->temp_mail, O_WRONLY|O_APPEND|O_CREAT|O_SYNC)) < 0) {
		    syslog(LOG_ERR, "Can't open message tempfile: %s", strerror(errno));
		    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
		}    
        if( file_write( fd, headerf, strlen(headerf), 0, &nwritten, &errval ) == -1 ||
            file_write( fd, splitter, strlen(splitter), 0, &nwritten, &errval ) == -1 ||
            file_write( fd, headerv, strlen(headerv), 0, &nwritten, &errval ) == -1 ||
            file_write( fd, STR_CRLF, strlen(STR_CRLF), 0, &nwritten, &errval ) == -1 ) {
                syslog( LOG_ERR, "Header data write error: %s", strerror(errval) );
                (void) close( fd );
		        return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
        }
        (void) close( fd );
    }
    
	return SMFIS_CONTINUE;
}


sfsistat
mlfi_eoh(SMFICTX *ctx)
{
 	struct mlfiPriv *priv = MLFIPRIV; 
	int fd, errval;
	ssize_t nwritten;
 	 	
    /* output the blank line between the header and the body */
    if (*priv->temp_mail) {
		if ((fd = open(priv->temp_mail, O_WRONLY|O_APPEND|O_CREAT|O_SYNC)) < 0) {
		    syslog(LOG_ERR, "Can't open message tempfile: %s", strerror(errno));
            return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
		}    
        if (file_write( fd, STR_CRLF, strlen(STR_CRLF), 0, &nwritten, &errval ) == -1 )
		    syslog(LOG_ERR, "%s", strerror(errno));
        priv->body_offset = lseek( fd, 0, SEEK_CUR );
        (void) close( fd );
    }
    /* continue processing */
    return SMFIS_CONTINUE;
}


sfsistat
mlfi_body (SMFICTX *ctx, u_char *bodyp, size_t len) {
	struct mlfiPriv *priv = MLFIPRIV;
	int            fd, errval;
	ssize_t        nwritten;
    
	/* check for private data presented */
	if (!priv) 
        return SMFIS_TEMPFAIL;
	/* check for required data presented */
	if (!bodyp)
	    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);

	/* open mail temp file (with all header ) */
	if (*priv->temp_mail) {
		if ((fd = open(priv->temp_mail, O_WRONLY|O_APPEND|O_CREAT|O_SYNC)) < 0) {
		    syslog(LOG_ERR, "Can't open message tempfile: %s", strerror(errno));
        	    return mlfi_cleanup(ctx, SMFIS_TEMPFAIL);
		}    
		if (file_write( fd, bodyp, len, 0, &nwritten, &errval ) == -1 )
		    syslog(LOG_ERR, "can't write mail boddy message tempfile: %s", strerror(errno));
		(void) close( fd );
	}      
	return SMFIS_CONTINUE;
}


sfsistat
mlfi_eom (SMFICTX *ctx) {
	struct mlfiPriv *priv = MLFIPRIV;
	int ret = 0;
	bool lret = FALSE;
	char **to;
	u_int32_t nfilesize;

	/* check for private data presented */
	if (!priv) return
        SMFIS_TEMPFAIL;
 
    /* get current file size before run virus scanner and body modifiers */
    nfilesize = get_file_size(priv->temp_mail);

	if (clamcheck) {
	    ret = clamd_check(priv->temp_mail, priv->report, clamsock);
	    switch (ret) {
	    case CLAMD_OK:
		    smfi_addheader(ctx, CLAMD_HEADER, "ClamAV using " MILTER);
		    break;
	    case CLAMD_PHISHING:
		    smfi_addheader(ctx, CLAMD_HEADER, "ClamAV found phishing message" );
		    for(to = priv->to; *to; to++) {
		        smfi_delrcpt(ctx, *to);
		        smfi_addheader(ctx, "X-Original-To", *to);
		    }
		    setnewsubject(ctx, priv->report);
		    smfi_addrcpt(ctx, avmail );
		    return mlfi_cleanup(ctx, SMFIS_CONTINUE); 	        
		    break;
	    case CLAMD_FOUND:
            file_save_local( quarantinedir, priv->temp_mail, priv->report);
            smfi_setreply(ctx, "554", "5.6.1", priv->report);
            return mlfi_cleanup(ctx, SMFIS_REJECT);
		break;
	    }
	}
 	if (fprotcheck) {
	    ret = fprot_check(priv->temp_mail, priv->report);
	    switch (ret) {
	    case FPROT_OK:
		     smfi_addheader(ctx, CLAMD_HEADER, "F-Prot using " MILTER);
		     break;
	    case FPROT_FOUND:
		     file_save_local( quarantinedir, priv->temp_mail, priv->report);
		     smfi_setreply(ctx, "554", "5.6.1", priv->report);
		     return mlfi_cleanup(ctx, SMFIS_REJECT);
		     break;
	    }
	}
    if (scriptfile) {
 		char *p = scriptfile;
		char *av[] = {NULL,NULL,NULL,NULL};
		av[0] = scriptfile;
		av[1] = priv->temp_mail;
        ret = externalcommand(ctx, NULL, EOF, p, av);
	    switch (ret) {
	    case 0:
		     smfi_addheader(ctx, CLAMD_HEADER, "Scriptfile   " MILTER);
             syslog(LOG_INFO, "Script: clean  %s", priv->temp_mail  );
		     break;
	    case 10: // virus found!
             snprintf(priv->report, MAXLINE - 1, "content reject");
             syslog(LOG_ERR, "Script: content reject" );             
		     file_save_local( quarantinedir, priv->temp_mail, priv->report);
		     smfi_setreply(ctx, "554", "5.6.1", priv->report);
		     return mlfi_cleanup(ctx, SMFIS_REJECT);
		     break;
	    }
    }
    
	/***************** body replace! ******************************************/
    if (priv->status & STAT_RELAY){
        if (signatureadd) 
            lret = add_external_signature(ctx);
        if ((optremove) && (lret == FALSE)) {        
                ret = externalbody(ctx, 2);
	            switch (ret) {
	                case 1:
		              syslog(LOG_ERR,  "ERR body rem.: %s attachment: %s ", priv->temp_mail, optremove );
                      break;	         
	                case 9:            
		              syslog(LOG_INFO, "Remove from:   %s attachment: %s ", priv->temp_mail, optremove );
                      break;
                }
        }
    } 
    /* if file size changed then replace mail message body */   
	if (nfilesize != get_file_size(priv->temp_mail))
	    change_body(ctx);
	return mlfi_cleanup(ctx, SMFIS_CONTINUE);
}


sfsistat
mlfi_cleanup (SMFICTX *ctx, sfsistat rc) {
	struct mlfiPriv *priv = MLFIPRIV;

	/* check for private data presented */
	if (!priv) 
        return rc;
    if ((priv->child1pid)>0) {
	    syslog(LOG_ERR, "cleanup() killing %d av-script", priv->child1pid);
	    kill(priv->child1pid, SIGABRT);
	    waitpid(priv->child1pid, NULL, 0);
	    priv->child1pid = 0;
	}
    if ((priv->child2pid)>0) {
	    syslog(LOG_ERR, "cleanup() killing %d altermime", priv->child2pid);
	    kill(priv->child2pid, SIGABRT);
	    waitpid(priv->child2pid, NULL, 0);
	    priv->child2pid = 0;
	}	
    if (debuglevel < 4) {
	    /* unlink temporary files */
	    if (*priv->temp_mail) {
            if (debuglevel > 0)
                syslog(LOG_INFO, "Cleanup remove %s", priv->temp_mail);   	    
	        (void) unlink(priv->temp_mail);
	    }
	    if (*priv->temp_signtxt) 
	        (void) unlink(priv->temp_signtxt);
	    if (*priv->temp_signhtm) 
	        (void) unlink(priv->temp_signhtm);
    }
	/* cleanup per-message data */
	*priv->from_addr    = '\0';
	*priv->temp_mail    = '\0';
	*priv->temp_signtxt = '\0';
	*priv->temp_signhtm = '\0';	
	*priv->report       = '\0';
	*priv->helo_host    = '\0';
	*priv->subject      = '\0';        	
	priv->body_offset   = 0;
    if (priv->to) {
        char **to;
        for (to = priv->to; *to; to++) {
            free(*to);
        }
        free(priv->to);
        priv->to = NULL;
    }
    priv->numTo = 0;
    /* release private memory */
    free(priv);
    smfi_setpriv(ctx, NULL);
	return rc;
}


sfsistat
mlfi_abort (SMFICTX *ctx) {
	return mlfi_cleanup(ctx, SMFIS_CONTINUE);
}


sfsistat
mlfi_close (SMFICTX *ctx) {
	return mlfi_cleanup(ctx, SMFIS_CONTINUE);
}


struct smfiDesc smfilter = {
	MILTER,		/* filter name */
	SMFI_VERSION,	/* version code -- do not change */
	SMFIF_ADDHDRS|SMFIF_CHGBODY|SMFIF_ADDRCPT|SMFIF_DELRCPT|SMFIF_CHGHDRS|SMFIF_QUARANTINE,	/* flags */
	/* flags */
	mlfi_connect,	/* connection info filter */
	mlfi_helo,	/* SMTP HELO command filter */
	mlfi_envfrom,	/* envelope sender filter */
	mlfi_envrcpt,	/* envelope recipient filter */
	mlfi_header,	/* header filter */
	mlfi_eoh,   /* end of header */
	mlfi_body,	/* body block filter */
	mlfi_eom,	/* end of message */
	mlfi_abort,	/* message aborted */
	mlfi_close,	/* connection cleanup */
	NULL,		/* unknown SMTP commands */
	NULL,    	/* DATA command */
	NULL		/* Once, at the start of each SMTP connection */
};


/* MySQL handling 
#######################################################################
# Database functions
#######################################################################
*/

bool
db_test( void ) {
    char testbuffer[1024];
    MYSQL *g_mysql;

    if(!dbname){
        syslog(LOG_ERR, "DBName not defined");
        return FALSE;
    }
    else if(!dbhost){
        syslog(LOG_ERR, "DBServer not defined");
        return FALSE;
    }
    else if(!dbuser){
        syslog(LOG_ERR, "DBUser not defined");
        return FALSE;
    }
    else if(!dbtable){
        syslog(LOG_ERR, "DBTable not defined");
        return FALSE;
    }
    g_mysql= mysql_init( NULL );
    
    if ( ! mysql_real_connect(g_mysql, dbhost, dbuser, dbpass, dbname, dbport, 0, 0)) {
        syslog(LOG_ERR, "db_test: mysql_real_connect failed");
        syslog(LOG_ERR, "%s", mysql_error(g_mysql));
        mysql_close(g_mysql);
        return FALSE;
    }

    snprintf(testbuffer, 1023, "SELECT signature FROM %s LIMIT 1", dbtable);
    /* run the query check */
    if (mysql_query(g_mysql, testbuffer ) != 0)
        syslog(LOG_ERR, "db_query problem: %s", mysql_error(g_mysql));

    mysql_close(g_mysql);
    return TRUE;
}


/* ----------------------------------------------------------------------------
 * load / reload configuration
 * ----------------------------------------------------------------------------*/
int
read_config (void) {
	FILE *fh = fopen(CONFIG_FILE, "r");
	char buffer[MAXLINE], value[MAXLINE];

	if (!fh) 
        return -1;
	syslog(LOG_INFO, "config: load/reload configuration");
	
	while (fgets(buffer, MAXLINE, fh))
	if (*buffer == '#') {
	    continue;
	} else if (strncasecmp("user", buffer, 4) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!smfiuser) smfiuser = strdup(value);
	} else if (strncasecmp("socket", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!smfisock) smfisock = strdup(value);
	} else if (strncasecmp("clamcheck", buffer, 9) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    clamcheck = strcasecmp(value, "yes")? 0 : 1;
	} else if (strncasecmp("clamsocket", buffer, 10) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!clamsock) clamsock = strdup(value);
	} else if (strncasecmp("fprotcheck", buffer, 9) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    fprotcheck = strcasecmp(value, "yes")? 0 : 1;
	} else if (strncasecmp("quarantinedir", buffer, 13) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!quarantinedir) quarantinedir = strdup(value);
	} else if (strncasecmp("avmail", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!avmail) avmail = strdup(value);
	} else if (strncasecmp("signatureadd", buffer, 12) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    signatureadd = strcasecmp(value, "yes")? 0 : 1;
	} else if (strncasecmp("dbhost", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!dbhost) dbhost = strdup(value);
	} else if (strncasecmp("dbport", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %d", &dbport);
	} else if (strncasecmp("dbname", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!dbname) dbname = strdup(value);
	} else if (strncasecmp("dbtable", buffer, 7) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!dbtable) dbtable = strdup(value);
	} else if (strncasecmp("dbuser", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!dbuser) dbuser = strdup(value);
	} else if (strncasecmp("dbpass", buffer, 6) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!dbpass) dbpass = strdup(value);
	} else if (strncasecmp("optremove", buffer, 9) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!optremove) optremove = strdup(value);
	} else if (strncasecmp("debuglevel", buffer, 10) == 0) {
	    sscanf(buffer, "%*s %d", &debuglevel);		
	} else if (strncasecmp("scriptfile", buffer, 10) == 0) {
	    sscanf(buffer, "%*s %s", value);
	    if (!scriptfile) scriptfile = strdup(value);
    }

	if (!dbhost)   dbhost   = strdup("localhost");
	if (!smfiuser) smfiuser = strdup(DEFAULT_USER);
	if (!smfisock) smfisock = strdup(SOCKET_FILE);
//	if (!smfisock) smfisock = strdup(SOCKET_PORT);	
	if (!clamsock) clamsock = strdup(CLAMD_SOCKET_FILE);
	if (!quarantinedir) quarantinedir = strdup("/var/tmp");
	if (!avmail)   avmail   = strdup("root@localhost");	
   

	fclose(fh);
	return 0;
}

void
usage () {
	printf("Usage:\t" PACKAGE "\t[-fhv]\n\n");
}

void
version () {
	printf(PROJECT_NAME " version " VERSION "\n" COPYRIGHT "\n\n");
}

void
help () {
	version();
	usage();
	printf("\t-f\t\t\tRun milter in the foreground.\n");
	printf("\t-v\t\t\tShow program version.\n");
	printf("\t-h\t\t\tShow this help.\n\n");
	printf("Program recognises the following config file options:\n\n");
	printf("\t[user username]\t\tSpecifies the user the milter should\n");
	printf("\t\t\t\trun as after it initializes.\n");
	printf("\t\t\t\tmail which has not passed the filter checks.\n");
	printf("\t[socket path]\t\tPath to create socket.\n");
	printf("\t[dbname name]\t\tName of MySQL database.\n");
	printf("\t[dbtable name]\t\tName of MySQL table.\n");
	printf("\t[dbuser name]\t\tName of MySQL connect user.\n");
  	printf("\t[dbpass name]\t\tPassword to connect MySQL table.\n");	
	printf("\t[clamcheck (yes|no)]\tEnable or disable mail checks\n");
	printf("\t\t\t\tusing ClamAV antivirus.\n");
	printf("\t[clamsocket path]\tPath to ClamAV socket.\n");
	printf("\t[quarantinedir path]\tPath for infected files.\n");
	printf("\t[avmail mailuser]\t\tE-Mail address for infect messages.\n");	

	printf("Program settings:\n\n");
	printf("\tuser\t\t\t[%s]\n", smfiuser);
	printf("\tsocket\t\t\t[%s]\n", smfisock);
	printf("\tdbname\t\t\t[%s]\n", dbname);
	printf("\tdbtable\t\t\t[%s]\n", dbtable);
	printf("\tclamcheck\t\t[%s]\n", (clamcheck) ? "yes" : "no");
	printf("\tclamsocket\t\t[%s]\n", clamsock);
	printf("\tfprotcheck\t\t[%s]\n", (fprotcheck) ? "yes" : "no");	
	printf("\tquarantinedir\t\t[%s]\n", quarantinedir);
	printf("\tdebuglevel\t\t[%d]\n", debuglevel);    

	printf("%s\n\n", DEVELOPERS);
}


/* ----------------------------------------------------------------------------
 * sighandler must reenable
 * ----------------------------------------------------------------------------*/
void 
signal_handler (int sig) {
	switch (sig) {
	    case SIGINT:
	    case SIGTERM:
	        terminate = 1;
	        break;
	    case SIGCHLD:
	        nochild = 1;
	        break;
	}
}


/* ----------------------------------------------------------------------------
 * create a pid file
 * ----------------------------------------------------------------------------*/
int
create_pid (const char *pidfile, pid_t pid) {
	char buffer[16];
	pid_t spid;
	int fd;

	if (access(pidfile, R_OK) == 0) {
	    if ((fd = open(pidfile, O_RDONLY)) < 0)
		    return -1;
	    if (read(fd, buffer, sizeof(buffer)) < 0) {
		    close(fd);
		    return -1;
	    }
	    close(fd);
	    sscanf(buffer, "%d", &spid);
	    if (spid == pid) 
            return 0;
	    if ((kill(spid, 0) < 0) && errno == ESRCH)
		    unlink(pidfile);
	    else 
            return 1;
	}
	if (!pid) 
        return 0;
	if ((fd = open(pidfile, O_RDWR|O_TRUNC|O_CREAT, 0644)) < 0)
	    return -1;
	/* put my pid in it */
	sprintf(buffer, "%d", pid);
	if (write(fd, buffer, strlen(buffer)) < 0)
	    syslog(LOG_ERR, "%s", strerror(errno));
	close(fd);
	return 0;
}


/* ----------------------------------------------------------------------------
 * restart daemon if crash
 * ----------------------------------------------------------------------------*/
void 
start_phoenix (void) {
	int i;
	pid_t pid;

start:
	/* setup signals */
	signal(SIGCHLD, signal_handler);
	signal(SIGINT,  signal_handler);
	signal(SIGTERM, signal_handler);
	signal(SIGHUP,  SIG_IGN);
	signal(SIGPIPE, SIG_IGN);
	nochild = 0;
	
    /* specify the socket to use */
	if (smfi_setconn(smfisock) == MI_FAILURE) 
        return;
	/* set socket timeout */
	if (smfi_settimeout(SOCKET_TIMEOUT) == MI_FAILURE)
        return;
	/* register the filter */
	if (smfi_register(smfilter) == MI_FAILURE) 
        return;
	/* remove old socket if found */
    if (smfi_opensocket(1) != MI_SUCCESS) {
        syslog(LOG_ERR, "could not open milter socket %s", smfisock);    
        return;
    }  

	switch ((pid = fork())) {
	  case -1:
	    syslog(LOG_ERR, "could not fork new process: %s", strerror(errno));
	    return;
	  case 0:
	    /* open syslog */
	    openlog(PACKAGE, LOG_PID, LOG_MAIL);	    
	    /* set file creation mask */
	    umask(S_IXUSR|S_IXGRP|S_IXOTH);
	    /* ignore signals */
	    signal(SIGTTOU, SIG_IGN);
	    signal(SIGTTIN, SIG_IGN);
	    signal(SIGTSTP, SIG_IGN);
	    signal(SIGHUP,  SIG_IGN);
	    signal(SIGPIPE, SIG_IGN);        
	    /* hand control to libmilter */
	    if (smfi_main() != MI_SUCCESS) {
		    syslog(LOG_ERR, "shutdown abnormally");
		    exit(EX_UNAVAILABLE);
	    } 
	    closelog();
	    exit(EX_OK);
	}

	while (!terminate && !nochild) sleep(1);

	if (terminate) {
	    syslog(LOG_INFO, "stopping..");
	    kill(0, SIGTERM);
	    waitpid(0, NULL, 0);
	    return;
	}
	/* terminate processes */
	for (i = 0; i < 4; i++) {
	    if (kill(-pid, SIGTERM) < 0) {
		waitpid(-pid, NULL, 0);
		if (kill(pid, SIGTERM) < 0) {
		    waitpid(pid, NULL, 0);
		    sleep(1);
		    break;
		}
		usleep(999999);
	    }
	}

	/* rip threads */
	kill(-pid, SIGKILL);
	waitpid(-pid, NULL, 0);

	/* rip child */
	kill(pid, SIGKILL);
	waitpid(pid, NULL, 0);

	/* reload configuration */
	syslog(LOG_INFO, "Reload configuration");

	if (read_config() < 0)
	    syslog(LOG_ERR, "Can't read config file: %s", CONFIG_FILE);

	goto start;
}


/* ----------------------------------------------------------------------------
 * main
 * ----------------------------------------------------------------------------*/
int
main (int argc, char **argv) {
	int c;
	extern int optind;
	struct passwd *pw;
	pid_t pid;

	/* get configuration file options */
	if (read_config() < 0) {
	    fprintf(stderr, "Can't read config file: %s\n", CONFIG_FILE);
	    exit(EXIT_FAILURE);
	}

	/* process command line options */
	while ((c = getopt(argc, argv, "fhv:")) != -1) {
	    switch (c) {
	    case 'f':
		runmode = 1;
		break;
	    case 'h':
		help();
		exit(EX_OK);
	    case 'v':
		version();
		exit(EX_OK);
	    default:
		usage();
		exit(EX_USAGE);
	    }
	}

	if ((pw = getpwnam(smfiuser)) == NULL) {
	    fprintf(stderr, "%s: user '%s' not found\n", PACKAGE, smfiuser);
	    exit(EX_USAGE);
	}

	/* avoid running as root user and/or group */
	if (getuid() == 0 && pw->pw_uid != 0 && pw->pw_gid != 0) {
	    (void) setgid(pw->pw_gid);
	    (void) setuid(pw->pw_uid);
	}
	
	/* check pid file */
	switch (create_pid(PID_FILE, 0)) {
	case -1:
	    fprintf(stderr, "%s: can't create pid file: %s\n", PACKAGE, PID_FILE);
	    exit(EXIT_FAILURE);
	    break;
	case 1:
	    fprintf(stderr, "%s: filter is already running..\n", PACKAGE);
	    exit(EX_OK);
	    break;
	}

	if (runmode == 0) {
	    /* ignore signals */
	    signal(SIGTTOU, SIG_IGN);
	    signal(SIGTTIN, SIG_IGN);
	    signal(SIGTSTP, SIG_IGN);
	    signal(SIGHUP,  SIG_IGN);
	    signal(SIGPIPE, SIG_IGN);
	    /* run in background */
	    if ((pid = daemon(0, 0)) < 0) {
		    fprintf(stderr, "%s: could not run filter in background, %s", PACKAGE, strerror(errno));
		    exit(EX_OSERR);
	    }
	    if (pid != 0) 
            exit(EX_OK);
	}

	/* open syslog */
	openlog(PACKAGE, LOG_PID, LOG_MAIL);

	if( (signatureadd) && (db_test())){
	    syslog(LOG_INFO, "MySQL server %s connect and query check, with table %s ", dbhost, dbtable);
	}
  	/* get new pid */
	pid = getpid();
	/* create pid file */
	if (create_pid(PID_FILE, pid)) {
	    syslog(LOG_ERR, "can't create pid file %s", PID_FILE);
	    exit(EX_UNAVAILABLE);
	}
	syslog(LOG_INFO, "running in %s as user '%s'", (runmode) ? "foreground" : "background", pw->pw_name);
  
  
  	if (smfi_settimeout(SOCKET_TIMEOUT) == MI_FAILURE)
	    exit(EX_UNAVAILABLE);
	if (smfi_setconn(smfisock) == MI_FAILURE) {
	    syslog(LOG_ERR, "could not set milter socket");
	    exit(EX_UNAVAILABLE);
    }
	if (smfi_register(smfilter) == MI_FAILURE) {
        syslog(LOG_ERR, "could not register milter");	
	    exit(EX_UNAVAILABLE);
    }
    if (smfi_opensocket(1) != MI_SUCCESS) {
        syslog(LOG_ERR, "could not open milter socket");
	    exit(EX_UNAVAILABLE);
    }  
 	start_phoenix();
           
	if (smfiuser)   free(smfiuser);
	if (smfisock)   free(smfisock);
	if (clamsock)   free(clamsock);
	if (dbhost)     free(dbhost);
	if (dbname)     free(dbname);
	if (dbtable)    free(dbtable);	
	if (dbuser)     free(dbuser);
	if (dbpass)     free(dbpass);
	if (optremove)  free(optremove);
	if (scriptfile) free(scriptfile);	

	closelog();
	exit(EX_OK);
}

/* eof */
