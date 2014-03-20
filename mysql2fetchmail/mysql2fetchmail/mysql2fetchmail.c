/* ---------------------------------------------------------------------
 * File: fmysql2fetchmail.c
 * create fetchmailrc file from MySQL table
 *
 * Copyright (C) 2006
 * Jens Vehlhaber, <jvehlhaber@buchenwald.de>
 *
 * Last Update:  $Id: fetchmysql.c 7512 2006-08-11 09:04:22Z jv $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * ---------------------------------------------------------------------
 */

#define BUFSIZE 64
#define MAXEMAILADRESSES 40
#define FIELDS  5

#include <mysql/mysql.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <syslog.h>
#include <stdlib.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <syslog.h>

int    verbose       = 0;
char*  mysqldatabase = NULL;
char*  mysqlquery    = NULL;
char*  mysqluser     = NULL;
char*  mysqlpass     = NULL;
char*  mysqlserver   = NULL;
char*  fetchfile     = NULL;
char*  alldomains    = NULL;
char*  mysqlencodepass = NULL;
int    nuid          = 8;       // uid  8 = mail
int    ngid          = 12;      // gid 12 = mail

/* ---------------------------------------------------------------------
 * ExitProg
 * Clean up memory and stop execution returing 'code' as exit value
 * ---------------------------------------------------------------------
 */
void
ExitProg(int code)
{
    if (mysqldatabase)  free(mysqldatabase);
    if (mysqlquery)     free(mysqlquery);
    if (mysqluser)      free(mysqluser);
    if (mysqlpass)      free(mysqlpass);
    if (mysqlserver)    free(mysqlserver);
    if (fetchfile)      free(fetchfile);
    if (alldomains)     free(alldomains);
    if (mysqlencodepass) free(mysqlencodepass);
    exit (code);
}


/* ---------------------------------------------------------------------
 *  ConnectMySQLServer
 *  connecting MySQL Server and execute query
 * ---------------------------------------------------------------------
*/
MYSQL*
ConnectMySQLServer(char* mysqlquerystr )
{
    char*    host = mysqlserver ? mysqlserver : "unix:/run/mysqld/mysqld.sock";
    char*    username = mysqluser ? mysqluser : "vmailprovider";
    char*    dbname = mysqldatabase ? mysqldatabase : "vmaildata";
    char*    hostname = 0;
    char*    unix_socket = NULL;
    unsigned port = 3306;
    char*    p;
    int      t;

    MYSQL* mysql;

    /* Ad-hoc parsing code. Expect "unix:pathname" or "inet:host:port", where
    * both "inet:" and ":port" are optional. */
    if (strncmp(host, "unix:", 5) == 0) {
        unix_socket = host + 5;
    } else {
        if (strncmp(host, "inet:", 5) == 0) {
            host += 5;
        }
        if ((p = strchr(host,':')) == 0 || *++p == '\0') {
            hostname = strdup(host);
        } else {
            hostname = malloc((p - host) * sizeof(char));
            if (hostname == NULL)
                return 0;
            hostname[0] = '\0';
            strncat(hostname, host, p - host - 1);
            port = strtol(p, NULL, 10);
        }
    }

    if (!mysqlquery)
        return NULL;
    mysql = mysql_init(NULL);
    if(mysql == NULL) {
        syslog( LOG_ERR, "Cannot connect mysql: %s", (char*)mysql_error(mysql));
        return NULL;
    }

    if (!mysql_real_connect(mysql, hostname, username, mysqlpass, dbname, port, unix_socket, 0)) {
        syslog( LOG_ERR, "Error connection of database: %s", (char*)mysql_error(mysql));
        return NULL;
    }

    t = mysql_real_query(mysql, mysqlquery, (unsigned int) strlen(mysqlquery));
    if (t) {
        syslog( LOG_ERR, "Error execute query: %s", (char*)mysql_error(mysql));
        mysql_close(mysql);
        return NULL;
    }
    return mysql;
}


/* ---------------------------------------------------------------------
 *  GetAllDomains
 *  get all hosted domain names
 * ---------------------------------------------------------------------
*/
void
GetAllDomains(void)
{
    MYSQL*       mysql;
    MYSQL_RES*   res;
    MYSQL_FIELD* field;
    MYSQL_ROW    row;
    char*        ptr;
    alldomains   = strdup("");

    mysql = ConnectMySQLServer("SELECT name FROM virtual_domains WHERE active = 1");
    if (!mysql) ExitProg(-1);
    res = mysql_store_result(mysql);
    if (res == NULL)
    {
        syslog( LOG_ERR, "Error get data. %s", (char*)mysql_error(mysql));
        if (verbose == 1)
            fprintf(stderr,"Error get data: %s\n", (char*)mysql_error(mysql));
        mysql_close(mysql);
        ExitProg(-1);
    }
    while ((row = mysql_fetch_row(res)) != NULL)
    {
        if (row[0])
        {
            ptr = strdup(row[0]);
            alldomains = (char *) realloc(alldomains, strlen(ptr) + strlen(alldomains) + 2);
            strcat(alldomains,ptr);
            strcat(alldomains," \0");
        }
    }
    mysql_close(mysql);
    if (verbose == 1)
        printf("Domains: %s\n", alldomains);

}

/* ---------------------------------------------------------------------
 * ShowProgramHelp
 * Show all available command line options and parameters
 * ---------------------------------------------------------------------
 */
void
ShowProgramHelp(const char* progname)
{
    printf ("mysql2fetchmail for eisfair-ng 2014-03-20\n"
        "usage: %s -t /var/tmp/.fetchmailrc [options]\n"
        "\t-h   show this help\n"
        "\t-v   Verbose output\n"
        "\t-t   .fetchmailrc file\n"
        "\t-c   SSL cert path         - default: /etc/ssl/certs\n"
        "\t-s   MySQL server socket 'unix:pathname' or port 'inet:host:port'\n"
        "\t                           - default: unix:/run/mysqld/mysqld.sock\n"
        "\t-d   MySQL database name   - default: vmaildata\n"
        "\t-u   MySQL user name       - default: vmailprovider\n"
        "\t-p   MySQL user password     \n"
        "\t-e   MySQL encoder password  \n"
        "\t-f   SQL listing query string\n"
        "\t-a   UID for .fetchmailrc  - default:  8\n"
        "\t-b   GID for .fetchmailrc  - default: 12\n\n",
        progname);
}


int
main(int argc, char* argv[])
{
    int          c;
    MYSQL*       mysql;
    MYSQL_RES*   res;
    MYSQL_FIELD* field;
    MYSQL_ROW    row;
    int          t, n;
    int          nactive    = 0;
    char*        servername = NULL;
    char*        prot       = NULL;
    char*        server_old = strdup("-");
    char*        prot_old   = strdup("-");
    char*        loginname  = NULL;
    char*        upassword  = NULL;
    char*        recipient  = NULL;
    char*        options    = NULL;
    char*        sslproto   = NULL;
    char*        sslfingerprint = NULL;
    char*        sslcertpath = strdup("/etc/ssl/certs");
    char         temp_query[1024];
    FILE*        fd;

    while (1)
    {
        c = getopt(argc, argv, "a:b:c:d:e:f:hp:s:t:u:v");
        if (c == -1)
            break;
        switch (c)
        {
            case 'a':
                nuid = atoi(optarg);
                break;
            case 'b':
                ngid = atoi(optarg);
                break;
            case 'c':
                sslcertpath = strdup(optarg);
                break;
            case 'd':
                mysqldatabase = strdup(optarg);
                break;
            case 'e':
                mysqlencodepass = strdup(optarg);
                break;                
            case 'f':
                mysqlquery = strdup(optarg);
                break;
            case 'h':
                ShowProgramHelp(argv[0]);
                ExitProg(0);
                break;
            case 'p':
                mysqlpass = strdup(optarg);
                break;
            case 's':
                mysqlserver = strdup(optarg);
                break;
            case 't':
                fetchfile = strdup(optarg);
                break;
            case 'u':
                mysqluser = strdup(optarg);
                break;
            case 'v':
                verbose = 1;
                break;
            case '?':
                fprintf(stderr,"%s: error reading command line!\n\n", argv[0]);
                ShowProgramHelp(argv[0]);
                ExitProg(-1);
                break;
        }
    }

    if (!fetchfile)
        fetchfile = strdup( ".fetchmailrc" );

    if (!mysqlquery) {
        snprintf(temp_query, 1023, "SELECT active, servername, prot, loginname, AES_DECRYPT(password,'%s'), recipient, options, sslproto, sslfingerprint FROM fetchmail ORDER BY servername, prot", mysqlencodepass);
        mysqlquery = strdup( temp_query );
    }

    /* get all domain names */
    GetAllDomains();

    mysql = ConnectMySQLServer(mysqlquery);
    if (!mysql) ExitProg(-1);

    res = mysql_store_result(mysql);
    if (res == NULL) {
        syslog( LOG_ERR, "Error get data. %s", (char*)mysql_error(mysql));
        if (verbose == 1)
            fprintf(stderr,"Error get data: %s\n", (char*)mysql_error(mysql));
        mysql_close(mysql);
        ExitProg(-1);
    }

    if ((fd = (FILE *)fopen(fetchfile,"w"))==NULL) {
         syslog( LOG_ERR, "Cannot create file %s", fetchfile);
         if (verbose == 1)
             fprintf(stderr, "Cannot create file %s \n", fetchfile);
         mysql_close(mysql);
         ExitProg(-1);
    }
    if (fchown(fileno(fd), nuid, ngid)) {
         syslog( LOG_ERR, "Cannot chown %d : %d file %s", nuid, ngid, fetchfile);
         if (verbose == 1)
             fprintf(stderr, "Cannot chown %d : %d file %s", nuid, ngid, fetchfile);
        return (-1);
    }

    n = mysql_num_fields(res);
    while ((row = mysql_fetch_row(res)) != NULL)
    {
        if ( atoi(row[0]) == 0 )
            continue;
        else {
            if (verbose == 1) {                
                printf("Servername: '%s'\n",  row[1] );
                printf("Protokoll:  '%s'\n",  row[2] );
                printf("Loginname:  '%s'\n",  row[3] );
                if (row[4])
                    printf("Passwort:   '%s'\n",  row[4] );
                else
                    printf("Kein Passwort!\n");
                printf("Empfaenger: '%s'\n",  row[5] );
                printf("Optionen:   '%s'\n",  row[6] );
                printf("SSL-prot:   '%s'\n",  row[7] );
                printf("SSL-fingpr: '%s'\n",  row[8] ); 
            }
            servername = strdup(row[1]);
            prot       = strdup(row[2]);
            loginname  = strdup(row[3]);
            if (row[4])
                upassword  = strdup(row[4]);
            else {
                if (upassword)  free(upassword);
                upassword = NULL;
            }
            recipient  = strdup(row[5]);
            options    = strdup(row[6]);
            sslproto   = strdup(row[7]);
            sslfingerprint = strdup(row[8]);
        }
        

        if ( (servername) && (prot) && (loginname) && (strlen(servername)>2) && (strlen(prot)>2) && (strlen(loginname)>0)) {
            if (strcasecmp(recipient, "*")==0) {
                fprintf(fd, "poll %s localdomains %s with proto %s envelope 'Delivered-To:' no dns\n",servername, alldomains ,prot );
                server_old = strdup("-");
            } else {
                if (!((strcasecmp(servername,server_old)==0) && (strcasecmp(prot,prot_old)==0))) {
                    server_old = strdup(servername);
                    prot_old   = strdup(prot);
                    fprintf(fd, "poll %s with proto %s:\n",servername ,prot );
                }
            }
            
            fprintf(fd, "    user '%s', with password '%s', is", loginname, upassword);
                
            if (!strcmp(recipient,"*")==0)
                fprintf(fd, " '%s' here", recipient);
            else
                fprintf(fd, " * here");
                
            if ((options) && (strlen(options)>1))
                fprintf(fd, ", %s", options );
            if ((sslproto) && (strlen(sslproto)>1))
                fprintf(fd, ", sslproto %s", sslproto);
            if ((sslfingerprint) && (strlen(sslfingerprint)>1))
                fprintf(fd, ", ssl sslfingerprint %s sslcertpath %s sslcertck",
                               sslfingerprint, sslcertpath );
            fprintf(fd, ";\n");
        }
    }
    fclose(fd);
    chmod(fetchfile, 0600 );

    if (servername) free(servername);
    if (prot)       free(prot);
    if (loginname)  free(loginname);
    if (upassword)  free(upassword);
    if (recipient)  free(recipient);
    if (options)    free(options);
    if (sslproto)   free(sslproto);
    if (sslfingerprint) free(sslfingerprint);
    if (server_old) free( server_old );
    if (prot_old)   free( prot_old );

    ExitProg( 1 );
    return 0;
}
