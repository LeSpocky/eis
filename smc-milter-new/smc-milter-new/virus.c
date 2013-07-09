/*
 * virus.c
 *
 * Description:  SMC support for ClamAV
 * Copyright (c) 2003-2008 Aleksander Djuric.
 * All rights reserved.
 *
 * jv 2010-03-10 change clamav handling
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <syslog.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/un.h>
#include <netinet/in.h>
#include "libmilter/mfapi.h"
#include "smc-milter.h"
#include "virus.h"

inline void
close_sock (int sock) {
	while (close(sock) == -1 && errno == EINTR);
}


int
send_to_socket (int socknr, const void *buffer, int count) {
	fd_set wfds;
	struct timeval tv;
    int retval = 0;
	int sent = 0;
	int n = 0;

	tv.tv_sec = SEND_TIMEOUT;
    tv.tv_usec = 0;

	FD_ZERO(&wfds);
	FD_SET(socknr, &wfds);

    while (sent < count) {
        if ((n = select(socknr + 1, NULL, &wfds, NULL, &tv)) > 0) {
            if ((retval = send(socknr, buffer + sent, count - sent, 0)) != -1)
                sent += retval;
        } else
        return n;
    }
    return sent;
}


int
recive_from_socket (int socknr, void *buffer, int count) {
	fd_set rfds;
	struct timeval tv;
	int ret = 0;

	tv.tv_sec = RECV_TIMEOUT;
	tv.tv_usec = 0;
	FD_ZERO(&rfds);
	FD_SET(socknr, &rfds);

	do {
	    ret = select(socknr + 1, &rfds, 0, 0, &tv);
	} while (ret < 0 && errno == EINTR);
	
	if (ret <= 0 || !FD_ISSET(socknr, &rfds)) 
        return -1;

	do {
	    ret = recv(socknr, buffer, count, MSG_NOSIGNAL);
	} while (ret < 0 && errno == EINTR);
	if (ret <= 0)
        return -1;

	return ret;
}

/******************************************************************************
  clamd_check
  Test filename with clamd via UNIX socket 
******************************************************************************/

int
clamd_check (const char *filename, char *report, const char *clamsock) {
	char b[MAXLINE];
    int sfd = 0; /* gcc shut up */
    int rval = 0;
    int i = 0;
    int ret;	
    struct sockaddr_un av_addr[1];

	/* check for required data presented */
	if (!filename || !report) return -1;

	/* clean up the report */
	*report = '\0';

    memset(av_addr, '\0', sizeof(struct sockaddr_un));
    av_addr->sun_family = PF_UNIX;
    strncpy(av_addr->sun_path, clamsock, sizeof(av_addr->sun_path));
    sfd = socket(PF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) {
	    syslog(LOG_ERR, "can't create socket");
        rval = CLAMD_ERROR;
        goto end;
    }
    rval = connect(sfd, (struct sockaddr *)av_addr, SUN_LEN(av_addr));
    if (rval < 0) {
        syslog(LOG_ERR,  "connecting to ClamAV socket '%s'", av_addr->sun_path);
        rval = CLAMD_ERROR;
        goto end;
    }

    memset(b, '\0', MAXLINE );
    ret = snprintf(b, MAXLINE - 1, "SCAN %s", filename);
   
    // syslog(LOG_DEBUG, "Send to ClamAV on socket '%s' the command '%s'", av_addr->sun_path, b );    

    rval = send_to_socket(sfd, b, ret + 1 );
    if (rval < 0) {
    	syslog(LOG_ERR, "unable to send message to ClamdAV: %s", strerror(errno));
        rval = CLAMD_ERROR;
        goto end;
    }
    rval = recive_from_socket (sfd, b, MAXLINE -1 );
    if ((rval < 0) || (rval > MAXLINE)) {
        syslog(LOG_ERR,   "recv from ClamAV socket '%s': %s", av_addr->sun_path, b);
        rval = CLAMD_ERROR;
        goto end;
    }
    b[strlen(b)-1] = '\0';
    
    /* Clamav returns string "/some/file.name OK" if file is clean or
     * "/some/file.name _wirus_name_ FOUND" if file is infected. */
    for (i = 0; i < MAXLINE-1; i++)
        if (b[i] == '\0')
            break;
    /* tail of "_some_file_name_ OK\n" */
    if (i > 3 && !strncmp(b+i-3, " OK", 3)) {
        snprintf(report, MAXLINE - 1, "ClamAV: message ok");  
        syslog(LOG_INFO, "ClamAV: clean  %s", filename  );                 
        rval = CLAMD_OK;
    /* tail of "_some_file_name_ _virus_name_ FOUND\n" */
    } else if (i > 6 && !strncmp(b+i-5, "FOUND", 5)) {
        for (i -= 6; i > 0; i--)
        if (b[i-1] == ' ')
            break;
        /* remove FOUND */
        b[strlen(b)-5] = '\0';   
        syslog(LOG_ERR, "ClamAV: --> found %s", b+i);
        rval = CLAMD_FOUND;
        if (strstr( b+i, "Phishing") != NULL) {
            rval = CLAMD_PHISHING;
        } 
        snprintf(report, MAXLINE - 1, "%s", b+i);
    /* tail of "_some_file_name_ Empty file\n" */
    } else if (i > 11 && !strncmp(b+i-10, "Empty file", 10)) {
        snprintf(report, MAXLINE - 1, "ClamAV message ok: %s", b);
        syslog(LOG_INFO, "%s", report);                 
        rval = CLAMD_OK;
    } else {
        snprintf(report, MAXLINE - 1, "ClamAV: %s", b);        
        syslog(LOG_INFO, "%s", report);
        rval = CLAMD_MALFORMED;
    }
end:
    close_sock(sfd);
    return rval;
}


/******************************************************************************
  fprot_check
  Test filename with Fprotd 6.0.x via UNIX port 
******************************************************************************/
int
fprot_check (const char *filename, char *report) {
	char b[MAXLINE];
    int sfd = 0; /* gcc shut up */
    int rval = 0;
    int i = 0;
    int r = 0;
    int ret;
    struct sockaddr_in av_addr[1];

	/* check for required data presented */
	if (!filename || !report) return -1;

	/* clean up the report */
	*report = '\0';

    memset(av_addr, '\0', sizeof(struct sockaddr_in));
    av_addr->sin_family = AF_INET;
    av_addr->sin_port = htons(FPROT_SERVER_PORT);
    av_addr->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
 
    sfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sfd < 0) {
	    syslog(LOG_ERR, "can't create socket");
        rval = FPROT_ERROR;
        goto end;
    }
    rval = connect(sfd, (struct sockaddr *)av_addr,  sizeof (struct sockaddr));
    if (rval < 0) {
        syslog(LOG_ERR,  "Cannot connect to F-Prot port '%d'", ntohs(av_addr->sin_port));
        rval = FPROT_ERROR;
        goto end;
    }

    memset(b, '\0', MAXLINE );
    ret = snprintf(b, MAXLINE - 1, "SCAN --scanlevel=4 --heurlevel=3 --adware FILE %s\n", filename);
   
//    syslog(LOG_DEBUG, "Send to F-Prot on port '%d' the command '%s'", ntohs(av_addr->sin_port), b );    

    rval = send_to_socket(sfd, b, ret + 1 );
    if (rval < 0) {
    	syslog(LOG_ERR, "unable to send message to F-Prot: %s", strerror(errno));
        rval = FPROT_ERROR;
        goto end;
    }
    rval = recive_from_socket (sfd, b, MAXLINE -1 );
    if ((rval < 0) || (rval > MAXLINE)) {
        syslog(LOG_ERR,   "recv from F-Prot port '%d': %s", ntohs(av_addr->sin_port), b);
        rval = FPROT_ERROR;
        goto end;
    }
    
    // remove first char '>' and '\n'
    for (i = 0; i < MAXLINE-1; i++) {
        if ((r == 0) && (b[i] == '>')) {
            b[i] = ' ';
            r++;
        } else if (b[i] == '\n')  {
            b[i] = '\0';
            break;
        }
    }

    if (i > 2 && !strncmp(b, "0 <", 3)) {
        snprintf(report, MAXLINE - 1, "F-Prot: %s", b + 3);  
        syslog(LOG_INFO, "%s", report);                 
        rval = FPROT_OK;        
    } else if (i > 2 && !strncmp(b, "1 <", 3)) {
        snprintf(report, MAXLINE - 1, "F-Prot: %s", b + 3);  
        syslog(LOG_INFO, "%s", report);                 
        rval = FPROT_FOUND;        
    } else {
        snprintf(report, MAXLINE - 1, "F-Prot: %s", b + 3);  
        syslog(LOG_ERR, "%s", report);                 
        rval = FPROT_ERROR;        
    }
end:
    close_sock(sfd);
    return rval;
}




