/*
 * utils.c
 *
 * Description:  File utilities
 * Copyright (c) 2005-2014 Jens Vehlhaber
 * All rights reserved.
 *
 */

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <sys/sendfile.h>
#include <limits.h>
#include "smc-milter.h"
#include "utils.h"
#include "config.h"

/* ----------------------------------------------------------------------------
 * File handling
 * ----------------------------------------------------------------------------*/
int
file_read( int fd, void *buffer, size_t bufsize, int timeout, ssize_t *nread, int *errval ) {
    ssize_t n_read;

    if( !errval ) { errno = EINVAL; return -1; }
    if( !buffer || timeout < 0 || !nread ) { errno = *errval = EINVAL; return -1; }

    if( timeout > 0 ) {
                fd_set readfds;
                struct timeval tv;

                FD_ZERO( &readfds );
                FD_SET( fd, &readfds );
                tv.tv_sec = timeout;
                tv.tv_usec = 0;

                if( select( fd+1, &readfds, NULL, NULL, &tv ) == -1 ) { *errval = errno; return -1; }
                if( !FD_ISSET( fd, &readfds ) ) { errno = *errval = ETIMEDOUT; return -1; }
        }

    do {
        n_read = read( fd, buffer, bufsize );
    } while( (n_read == -1 && errno == EINTR) );

    *nread = ( n_read == -1 ? 0 : n_read );
    *errval = ( n_read == -1 ? errno : 0 );
    return ( n_read == -1 ? -1 : 0 );
}


int 
file_write( int fd, const void *buffer, size_t buflen, int timeout, ssize_t *nwritten, int *errval ) {
    ssize_t n_written, n_writtenonce;

    if( !errval ) { errno = EINVAL; return -1; }
    if( !buffer || timeout < 0 || !nwritten ) { errno = *errval = EINVAL; return -1; }

    if( timeout > 0 ) {
        fd_set writefds;
        struct timeval tv;

        FD_ZERO( &writefds );
        FD_SET( fd, &writefds );
        tv.tv_sec = timeout;
        tv.tv_usec = 0;

        if( select( fd+1, NULL, &writefds, NULL, &tv ) == -1 ) { *errval = errno; return -1; }
        if( !FD_ISSET( fd, &writefds ) ) { errno = *errval = ETIMEDOUT; return -1; }
    }

    n_written = 0;
    do {
        n_writtenonce = write( fd, buffer+n_written, buflen );
        if( n_writtenonce != -1 ) n_written += n_writtenonce;
    } while( (n_writtenonce != -1 || (n_writtenonce == -1 && errno == EINTR)) && n_written < buflen );

    *nwritten = n_written;
    *errval = ( n_writtenonce == -1 ? errno : 0 );
    return ( n_writtenonce == -1 ? -1 : 0 );
}

/* ----------------------------------------------------------------------------
 * check file content
 * ----------------------------------------------------------------------------*/
int
file_signature_content(const char *fname) {
    FILE *fp;
    char tmp[128];

    fp = fopen(fname, "r");
    if (!fp)
        return 0;
    while (fgets (tmp, sizeof (tmp) - 1, fp) != NULL) {
       switch(tmp[0]) {
          case '-' :
              if (strcmp(tmp, "-- \r\n") == 0 ) {
                  fclose(fp);
                  return 1;
              }
              break; 
          case ' ' :
          case '<' :
              if (strstr(tmp, "moz-signature") != NULL) {
                  fclose(fp);
                  return 1;
              }
              break; 
       }
    }   
    fclose(fp);
    return 0;
}


/* ----------------------------------------------------------------------------
 * Move oldfile to newfile using the fastest possible method
 * ----------------------------------------------------------------------------*/
int
file_move(const char *oldfile, const char *newfile)
{
    int ret, c;
    FILE *fin, *fout;
    struct stat statb;
    int in, out;
    off_t offset;

    ret = rename(oldfile, newfile);
	if(ret >= 0) 
	    return 0;
 
	if((ret < 0) && (errno != EXDEV)) {
		syslog( LOG_ERR, "Error: new file %s", newfile); 	
 	    return -1;
    }
    
    in = open(oldfile, O_RDONLY);
	if(in < 0) {
	    syslog( LOG_ERR, "Error: open for read %s", oldfile); 
        return -1;
    }

    if(fstat(in, &statb) < 0) {
 	    syslog( LOG_ERR, "Error: old file %s", oldfile);    
        close(in);
		return -1;
    }
    out = open(newfile, O_WRONLY|O_CREAT, 0600);
	if(out < 0) {
	    syslog( LOG_ERR, "Cannot open for write %s", newfile); 	
        close(in);
		return -1;
    }
	offset = (off_t)0;
	ret = sendfile(out, in, &offset, statb.st_size);
	close(in);
	if(ret < 0) {
        close(out);
		unlink(newfile);
		fin = fopen(oldfile, "r");
		if(fin == NULL)
		    return -1;
        fout = fopen(newfile, "w");
		if(fout == NULL) {
            fclose(fin);
			return -1;
        }
        while((c = getc(fin)) != EOF)
		    putc(c, fout);
        fclose(fin);
        fclose(fout);
    } else
	    close(out);

	syslog( LOG_INFO,"removing %s ", oldfile);
    
    return unlink(oldfile);
}


/* ----------------------------------------------------------------------------
 * Move oldfile to newfile using the fastest possible method
 * ----------------------------------------------------------------------------*/
int
file_save_local(const char *quarantinedir, const char *filename, const char *virus) {
	int MM, YY, DD;
	time_t tt;
	size_t len;
	const struct tm *tm;    
    char qfilename[2048];
	char  *ptr;    
	const mode_t old_umask = umask(0007);

    tt = time((time_t *)0);
    tm = localtime(&tt);
    MM = tm->tm_mon + 1;
    YY = tm->tm_year - 100;
    DD = tm->tm_mday;
    len = strlen(quarantinedir);
    
    memset(qfilename, '\0', 2048 );
    
    snprintf(qfilename,2047, "%s/%02d%02d%02d", quarantinedir, YY, MM, DD);
    if (( mkdir(qfilename, 0700) == -1 ) && ( errno != EEXIST )) {
        syslog(LOG_ERR, "Create dir: %s ERROR: %s", qfilename, strerror(errno));     
        umask(old_umask);
        return -1;
    }

    umask(old_umask);
    snprintf(qfilename, 2047, "%s/%02d%02d%02d/%02d%02d%02d%04d.%s", 
                      quarantinedir, YY, MM, DD, tm->tm_hour, tm->tm_min, 
                      tm->tm_sec, (1+(rand()%(9999-2))), virus);
    for(ptr = &qfilename[len + 10]; *ptr; ptr++) {
        if(*ptr == '/')
		    *ptr = '_';
        if (isspace((int) *ptr))
            *ptr = '.';
    }
    syslog( LOG_INFO, "quarantine file: %s", qfilename); 
    if ( file_move(filename, qfilename) == -1 ) {
        syslog( LOG_ERR, "Cannot move %s to quarantine file: %s", filename, qfilename); 
        return -1;   
    }
    return 0;
}      
     
/* ----------------------------------------------------------------------------
 * Removes all dangling white-spaces and EOL chars from the end of a string.
 * Returns total number of chopped-off characters.
 * ----------------------------------------------------------------------------*/
int
chop ( char* string ) {
    int i;
    int chopped;
    int stop = 0;

    chopped = 0;
    i = strlen ( string ) - 1;
    while ( i >= 0 ) {
        stop = 1;
        if (( string[i] == '\n' ) || ( string[i] == '\t' ) || ( string[i] == '\f' ) || ( string[i] == '\r' )) {
            chopped ++;
            stop = 0;
        }
        if ( stop == 1 ) {
            /* got a non white-space char: stop chopping! */
            break;
        }
        i --;
    }
    /* chop string */
    string[strlen(string)-chopped] = '\0';
    return (chopped);
}
    

/* ----------------------------------------------------------------------------
 * Get the file size
 * Return bytes
 * ----------------------------------------------------------------------------*/
u_int32_t
get_file_size(const char *file_name) {
    struct stat buf;
    if ( stat(file_name, &buf) != 0 ) 
        return(0);
    return( buf.st_size );
}
 

/* ----------------------------------------------------------------------------
 * convert string to lower case
 * Return null
 * ----------------------------------------------------------------------------*/
void
strtolower (char *str) {
	/* check for required data presented */
	if (!str) 
        return;
	for (; *str; str++) *str = tolower(*str);
}


/* ----------------------------------------------------------------------------
 * Replaces UTF-8 characters with ISO characters.
 *
 * @param input the UTF-8 encoded, zero terminated input string.
 * @returns newly allocated string with replaced characters. Caller is
 *      responsible for freeing the memory.
 * ----------------------------------------------------------------------------*/
char*
UTF8toISO(char *input, int inputlen)
{
    unsigned int replacement;
    int i, j;
    char c;
    char *result = malloc(inputlen + 1);
    if (result == NULL )
        return NULL;

    i = j = 0;
    while ((c = input[i++])) {
        if (c == (char) 195) {
            switch ((unsigned char) input[i]) {
                case 164: replacement = 228; break;
                case 182: replacement = 246; break;
                case 188: replacement = 252; break;
                case 132: replacement = 196; break;
                case 150: replacement = 214; break;
                case 156: replacement = 220; break;
                case 159: replacement = 223; break;
                default: replacement = 0;
            }
            if (replacement > 0) {
                result[j++] = replacement;
                 ++i;
                continue;
            }
        }
        result[j++] = c;
    }
    result[j++] = '\0';
    return realloc(result, j);
}


/* ----------------------------------------------------------------------------
 * Replaces UTF-8 characters by HTML entities.
 *
 * @param input the UTF-8 encoded, zero terminated input string.
 * @returns newly allocated string with replaced characters. Caller is
 *      responsible for freeing the memory.
 * ----------------------------------------------------------------------------*/
char*
UTF8toHTML(char *input, int inputlen)
{
    char *replacement;
    int i, j;
    char c;
    /* Allocate enough memory for the worst case which is an input of
     * just 'sz' characters, each two bytes long, which will be replaced
     * by seven bytes ("&szlig;").  */
    char *result = malloc(inputlen * 6 + 1);
    if (result == NULL )
        return NULL;

    i = j = 0;
    while ((c = input[i++])) {
        if (c == (char) 195) {
            switch ((unsigned char) input[i]) {
                case 164: replacement = "auml"; break;
                case 182: replacement = "ouml"; break;
                case 188: replacement = "uuml"; break;
                case 132: replacement = "Auml"; break;
                case 150: replacement = "Ouml"; break;
                case 156: replacement = "Uuml"; break;
                case 159: replacement = "szlig"; break;
                default: replacement = NULL;
            }
            if (replacement) {
                result[j++] = '&';
                while ((result[j++] = *replacement++));
                result[j - 1] = ';';
                ++i;
                continue;
            }
        }
        result[j++] = c;
    }
    result[j++] = '\0';
    return realloc(result, j);
}


/* ----------------------------------------------------------------------------
 * Function to remove line feeds from string
 * ----------------------------------------------------------------------------*/
void
remove_crln(char *value)
{
    int i = 0;
    while (value[i] != '\0') {
        if (value[i] == '\n') {
            if (value[i + 1] == '\0') {
                value[i] = '\0';
            } else {
                value[i] = ' ';
            }
        }
        i++;
    }
}

/* eof */
