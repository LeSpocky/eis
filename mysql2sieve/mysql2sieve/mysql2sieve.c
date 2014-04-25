/* ==========================================================================
 *
 * Copyright (C) 2010 Jens Vehlhaber jv <jens@eisfair.org>
 *
 * Last Update:  $Id: mysql2sive.c 9685 2007-04-05 21:00:11Z jv $
 *
 * Export sieve filter entries from MySQL table
 * ---------------------------------------------------------------------
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

#include    <mysql/mysql.h>
#include    <sys/stat.h>
#include    <stdio.h>
#include    <dirent.h>
#include    <stdlib.h>
#include    <unistd.h>
#include    <string.h>
#include    <syslog.h>
#include    <ctype.h>
#include    <errno.h>
#include    <time.h>
#include    <wchar.h>
#include    <wctype.h>
#include    "mysql2sieve.h"
#include    "utf8function.h"

char*  mysqldatabase = NULL;
char*  mysqlquery    = NULL;
char*  mysqluser     = NULL;
char*  mysqlpass     = NULL;
char*  mysqlserver   = NULL;
int    cnt_filter;             // count of filter per user
int    cnt_record;             // database records all per user (incl. disabled)
int    uidlist[512];           // filter id's per user
int    verbose       = 0;
int    nuid          = 8;       // uid  8 = mail
int    ngid          = 12;      // gid 12 = mail

/* --------------------------------------------------------------------
*  ExitProg
*  Clean up memory and stop execution returing 'code' as exit value
* --------------------------------------------------------------------- */
void
ExitProg(int code)
{
    if (mysqldatabase)  free(mysqldatabase);
    if (mysqlquery)     free(mysqlquery);
    if (mysqluser)      free(mysqluser);
    if (mysqlpass)      free(mysqlpass);
    if (mysqlserver)    free(mysqlserver);
    exit (code);
}


/* ---------------------------------------------------------------------
 *  ConnectMySQLServer
 *  connecting MySQL Server and execute query
 * --------------------------------------------------------------------- */
MYSQL*
ConnectMySQLServer( void )
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
*  find_entry_nr
*  find db entry nr
*  --------------------------------------------------------------------- */
int
find_entry_nr( int nval )
{
    int n;
    int nret = 0;

    for (n = 0; n <= cnt_filter; ++n) {
        if ( uidlist[n] == nval ) {
             nret = 1;
             break;
        }
        if (uidlist[n] > nval)
            break;
    }
    return (nret);
}

/* ---------------------------------------------------------------------
*  select_files
*  select only vmail files
*  --------------------------------------------------------------------- */
int
select_files(const struct dirent *ent)
{
    return strncmp(ent->d_name, "vmailentry", 10)==0;
}

/* ---------------------------------------------------------------------
 * Maildirname to dir
 * DIR location, INBOX.name  
 * --------------------------------------------------------------------- 
char*
maildir_name_convert(const char *maildir, 
               const char *foldername) 
{
    const char *inbox=INBOX;
    int l=strlen(inbox);
    char *p;

    if (!maildir)
        maildir=".";

    if (foldername && strncasecmp(foldername, INBOX, l) == 0 &&  strchr(foldername, '/') == NULL) {
        if (foldername[l] == 0)
            return strdup(maildir); 
            // INBOX: main maildir inbox 

        if (foldername[l] == '.') {
            const char *r;

            for (r=foldername; *r; r++) {
                if (*r != '.')  
                    continue;
                if (r[1] == 0 || r[1] == '.') {
                    errno=EINVAL;
                    return (0);
                }
            }

            r=strchr(foldername, '.');

            p=malloc(strlen(maildir)+strlen(r) + 2);

            if (!p)
                return NULL;

            return (strcat(strcat(strcpy(p, maildir), "/"),
                       r));
        }
    }

    errno=EINVAL;
    return NULL;
}
*/
/* ---------------------------------------------------------------------
 * maildir_filter_autoresp_info_init_str
 * --------------------------------------------------------------------- */
int
maildir_filter_autoresp_info_init_str(struct maildir_filter_autoresp_info *i, const char *c)
{
    char *p;
    memset(i, 0, sizeof(*i));
    i->name=strdup(c);
    if (!(i->name))
        return (-1);

    for (p = strtok(i->name, " \t\r\n"); p; p = strtok(NULL, " \t\r\n")) {
        if (strncmp(p, "dsn=", 4) == 0)
            i->dsnflag=atoi(p+4) ? 1:0;
        else if (strncmp(p, "days=", 5) == 0)
            i->days=atoi(p+5);
    }
    return (0);
}


/* ---------------------------------------------------------------------
 * maildir_filter_autoresp_info_free
 * --------------------------------------------------------------------- */
void
maildir_filter_autoresp_info_free(struct maildir_filter_autoresp_info *i)
{
    if (i->name) {
        free(i->name);
        i->name=0;
    }
}


/* ---------------------------------------------------------------------
 * PrintPattern
 * --------------------------------------------------------------------- 
static void
PrintPattern(FILE *f, int flags, const char *v)
{
    if (!(flags & MFR_PLAINSTRING))
    {
        fprintf(f, "%s%s", *v && isspace((int)(unsigned char)*v) ? "\\":"", v);
        return;
    }
    while (*v)
    {
        if (!isalnum((int)(unsigned char)*v))
            putc('\\', f);
        putc((int)(unsigned char)*v, f);
        ++v;
    }
}
*/

/* ---------------------------------------------------------------------
 * sieve filter rule update
 * Before creating a new rule, validate all input.  
 * --------------------------------------------------------------------- */
int
maildir_filter_ruleupdate(struct maildirfilter *r,
          struct maildirfilterrule *p,
          const char *name,
          enum maildirfiltertype type,
          int flags,
          const char *header,
          const char *value,
          const char *folder,
          const char *fromhdr,
          const char *memotext,
          int *errcode) 
{
    const char *c;

    *errcode=0;

    /* rule name: may not contain quotes or control characters. */
    *errcode=MF_ERR_BADRULENAME;
    if (!name || !*name || strlen(name) > 200) {
        return (-1);
    }

    for (c=name; *c; c++)
        if ((unsigned char)*c < ' ' || *c == '\'' || *c == '"' || *c == '`') {
            return (-1);
        }

    /* rule name: may not already exist */
    *errcode=MF_ERR_EXISTS;

    struct maildirfilterrule *pom;
    for (pom=r->first; pom->next; pom=pom->next) {
        if (p!=pom && !strcmp(name, pom->rulename)) {
            return (-1);
        }
    }

    /* rule type: we must know what it is */
    switch (type) {
        case startswith:
        case endswith:
        case contains:
        case hasrecipient:
        case mimemultipart:
        case textplain:
        case islargerthan:
        case anymessage:
            break;
        default:
            *errcode=MF_ERR_BADRULETYPE;
            break;
    } ;

    /* header: */
    *errcode=MF_ERR_BADRULEHEADER;

    c=header;
    if (c && strlen(c) > 200)
        return (-1);
    if (c == 0 || *c == 0) {
        switch (type) {
            case hasrecipient:
            case islargerthan:
            case mimemultipart:
            case textplain:
            case anymessage:
                break;
            case contains:
            case startswith:
            case endswith:
                if (flags & MFR_BODY)
                    break;
                /* FALLTHRU */
            default:
                return (-1);
        }
    } else {
        for ( ; *c; c++) {
            /* no control characters */
            if (*c <= ' ' || *c == MDIRSEP[0] || *c >= 127 || *c == '\'' || *c == '\\' || *c == '"' || *c == '`' || *c == '/')
                return (-1);
        }
    }

    /* rule pattern */
    *errcode=MF_ERR_BADRULEVALUE;

    c=value;
    if (c && strlen(c) > 200)   return (-1);
    if (c == 0 || *c == 0) {
        switch (type) {
            case mimemultipart:
            case textplain:
            case anymessage:
                break;
            default:
                /* required */
                return (-1);
        }
    } else if (!(flags & MFR_PLAINSTRING))  {
        /*
        ** Let PCRE decide if this is a valid pattern.
        **
        ** One exception: the forward slash character, and some other
        ** special characters, must always be escaped.
        */

        while (*c) {
            if (*c == '/' || *c == '$' || *c == '!' || *c == '`' || (int)(unsigned char)*c < ' ' || *c == '\'' || *c == '"')
                return (-1);
            /* must be escaped */
            if (type == islargerthan) {
                if (!isdigit((int)(unsigned char)*c))
                    return (-1);
            }

            if (*c == '(') {
                if (type == hasrecipient)   return (-1);
                ++c;
                if (*c == ')')  return (-1);
                continue;
            }
            if (*c == ')') {
                if (type == hasrecipient)   return (-1);
                ++c;
                continue;
            }
            if (*c == '[') { /* This is a set */
                if (type == hasrecipient)   return (-1);
                ++c;
                for (;;)
                {
                    if (*c == '\'' || *c == '"' || *c == '`')
                        return (-1); /* must be quoted*/
                    if (*c == '\\')
                        ++c;
                    if (!*c)    return (-1);
                    if ((int)(unsigned char)*c < ' ')
                        return (-1);
                    ++c;
                    if (*c == ']')  break;
                    if (*c != '-')  continue;
                    ++c;

                    if (*c == '\'' || *c == '"' ||  *c == '`')
                        return (-1); /* must be quoted*/
                    if (*c == '\\')
                        ++c;
                    if ((int)(unsigned char)*c < ' ')
                        return (-1);
                    if (!*c)    return (-1);
                    ++c;
                    if (*c == ']')  break;
                }
                ++c;
                continue;
            }

            if (*c == '\\')
            {
                if (type == hasrecipient)   return (-1);
                ++c;
            }
            if (!*c)    return (-1);
            ++c;
        }


#if HAVE_PCRE_H
        switch (type) {
        case contains:
        case startswith:
        case endswith:
            {
                const char *errptr;
                int errindex;
                pcre *p=pcre_compile(value, 0, &errptr, &errindex, 0);
                if (p == NULL)
                    return -1;
                pcre_free(p);
            }
            break;
        default:
            break;
        }
#endif
    }

    /* validate FROM header */
    *errcode=MF_ERR_BADFROMHDR;

    while (fromhdr && *fromhdr && isspace((int)(unsigned char)*fromhdr))
        ++fromhdr;

    for (c=fromhdr; *c; c++)
        if (*c == '\'' || *c == '\\' || (int)(unsigned char)*c < ' ') {
            return (-1);
        }

    *errcode=MF_ERR_BADRULEFOLDER;
    /* validate name of destination folder */
    c=folder;
    if (!c)
        return (-1);
    if (strlen(c) > 200)
        return (-1);

    if (*c == '*' || *c == '!')
    {
        /* Forward, or bounce with an error */
        ++c;
        for ( ; *c; c++)
        {
            if (strchr("'\"$\\`;(){}#&<>~", *c) || (unsigned char)*c < ' '){
                return (-1); }
        }
    }
    else if (*c == '+') /* Autorespond */
    {
        struct maildir_filter_autoresp_info ai;

        if (maildir_filter_autoresp_info_init_str(&ai, c+1))
            return (-1);

        maildir_filter_autoresp_info_free(&ai);
    }
    else if (strcmp(c, "exit") == 0) {    /* Purge */

    }
    else
    {
        /* char *s;

        if (strcmp(c, INBOX) && strncmp(c, INBOX ".", sizeof(INBOX)))
            return -1;
        s = maildir_name_convert(".", c);
        if (!s)
            return -1;
        free(s); */
    }

    /* OK, we're good */
    *errcode=MF_ERR_INTERNAL;

    if (p->rulename)    free(p->rulename);
    if ((p->rulename=strdup(name)) == 0)    return (-1);
    p->type=type;
    if (p->fieldname)   free(p->fieldname);
    if ((p->fieldname=strdup(header ? header:"")) == 0) return (-1);
    if (p->fieldvalue)  free(p->fieldvalue);
    if ((p->fieldvalue=strdup(value ? value:"")) == 0)  return (-1);
    if (p->tofolder)    free(p->tofolder);
    if ((p->tofolder=malloc(strlen(folder)+1)) == 0)    return (-1);
    strcpy(p->tofolder, folder);
    if (p->fromhdr)     free(p->fromhdr);
    if ((p->fromhdr=strdup(fromhdr ? fromhdr:"")) == NULL) return (-1);
    if (p->memotext)     free(p->memotext);
    if ((p->memotext=strdup(memotext ? memotext:"")) == NULL) return (-1);
    p->flags=flags;

    *errcode=0;

    return (0);
}


/* ---------------------------------------------------------------------
 * maildir_filter_ruledel
 * --------------------------------------------------------------------- */
void
maildir_filter_ruledel(struct maildirfilter *r, struct maildirfilterrule *p) 
{
    if (p->prev)
        p->prev->next=p->next;
    else
        r->first=p->next;
    if (p->next)
        p->next->prev=p->prev;
    else
        r->last=p->prev;
    if (p->rulename)    free(p->rulename);
    if (p->fieldname)   free(p->fieldname);
    if (p->fieldvalue)  free(p->fieldvalue);
    if (p->tofolder)    free(p->tofolder);
    if (p->fromhdr)     free(p->fromhdr);
    if (p->memotext)    free(p->memotext);
    free(p);
}


/* ---------------------------------------------------------------------
 * append_sieve_rule
 * --------------------------------------------------------------------- */
struct maildirfilterrule*
append_sieve_rule(  struct maildirfilter *r,
                    const char *name,
                    enum maildirfiltertype type,
                    int flags,
                    const char *header,
                    const char *value,
                    const char *folder,
                    const char *fromhdr,
                    const char *memotext,
                    int *errcode)
{
    struct maildirfilterrule *p=malloc(sizeof(struct maildirfilterrule));
    *errcode=MF_ERR_INTERNAL;

    if (!p)
        return (0);
    memset(p, 0, sizeof(*p));

    if ((p->prev=r->last) != 0)
        p->prev->next=p;
    else
        r->first=p;
    r->last=p;

    if (maildir_filter_ruleupdate(r, p, name, type, flags, header, value, folder, fromhdr, memotext, errcode)) {
        if ( errcode > 0 )
            syslog( LOG_ERR, "Error maildir_filter_ruleupdate '%s' code: %d", name, *errcode );
        maildir_filter_ruledel(r, p);
        return (0);
    }
    return (p);
}


/* ---------------------------------------------------------------------
 * Write all filter rules to sieve file
 * --------------------------------------------------------------------- */
int
write_sieve_rules(struct maildirfilter *r, const char *filename,
                  const char *maildir, const char *maildirpath,
                  const char *fromaddr)
{
    FILE    *f=fopen(filename, "w");
    FILE    *fu=fopen("userfilter.sieve", "r");

    struct maildirfilterrule *p;

    if ((!f) || (fchown(fileno(f), nuid, ngid)))
        return (-1);

    if (!fu)
        fprintf(f, "require [\"fileinto\",\"envelope\",\"reject\",\"vacation\",\"vacation-seconds\",\"subaddress\",\"regex\",\"copy\",\"body\"];\n");
    else
    {
        fclose(fu);
        fprintf(f, "require [\"fileinto\",\"envelope\",\"reject\",\"vacation\",\"vacation-seconds\",\"subaddress\",\"regex\",\"copy\",\"body\",\"include\"];\n");
        fprintf(f, "include :personal \"userfilter\";\n\n");
    }
    for (p=r->first; p; p=p->next) {
        const char *fieldname=p->fieldname ? p->fieldname:"";
        const char *fieldvalue=p->fieldvalue ? p->fieldvalue:"";
        const char *tofolder=p->tofolder ? p->tofolder:"";

/*
        fprintf(f, "##Op:%s\n",     typelist[p->type].name);
        fprintf(f, "##Header:%s\n", fieldname);
        fprintf(f, "##Value:%s\n",  fieldvalue);
        if (*tofolder == '+') 
        {
            fprintf(f, "##Folder:+%s %s\n", p->rulename, tofolder + 1 );
        }
        else
        {
            fprintf(f, "##Folder:%s\n",
                strcmp(tofolder, INBOX) == 0 ? ".":
                strncmp(tofolder, INBOX ".", sizeof(INBOX)) == 0
                ? strchr(tofolder, '.'):tofolder);
        }
        fprintf(f, "##From:%s\n", p->fromhdr ? p->fromhdr:"");

        if (p->flags & MFR_PLAINSTRING)
            fprintf(f, "##PlainString\n");
        if (p->flags & MFR_DOESNOT)
            fprintf(f, "##DoesNot\n");
        if (p->flags & MFR_BODY)
            fprintf(f, "##Body\n");
        if (p->flags & MFR_CONTINUE)
            fprintf(f, "##Continue\n");
*/ 
        // start rule entry
        if ( p->rulename == '\0' )
            fprintf(f, "# rule:[noname %d]\n", rand() );
        else
            fprintf(f, "# rule:[%s]\n", p->rulename);

        fprintf(f, "if ");

        if (p->flags & MFR_DOESNOT)
            fprintf(f, "not ");

        switch (p->type) {
        case startswith:
            if (p->flags & MFR_BODY) {
                fprintf(f, "body :matches \"%s\"", fieldvalue);
                // PrintPattern(f, p->flags, fieldvalue);
                // fprintf(f, "*");
            } else {
                fprintf(f, "header :matches \"%s\" \"%s*\" ", fieldname, fieldvalue);
                // PrintPattern(f, p->flags, fieldvalue);
                // fprintf(f, "*");
            }
            break;
        case endswith:
            if (p->flags & MFR_BODY) {
                fprintf(f, "body :matches \"*%s\" ", fieldvalue);
            } else {
                fprintf(f, "header :matches \"%s\" \"*%s\" ", fieldname, fieldvalue);
            }
            break;
        case contains:
            if (p->flags & MFR_BODY) {
                fprintf(f, "body :contains \"%s\" ", fieldvalue);
            } else {
                fprintf(f, "header :contains \"%s\" \"%s\" ", fieldname, fieldvalue);
            }
            break;
        case hasrecipient:
            fprintf(f, "hasaddr(\"%s\")", fieldvalue);
            break;
        case mimemultipart:
            fprintf(f, "/^Content-Type: *multipart\\/mixed/");
            break;
        case textplain:
            fprintf(f, " (! /^Content-Type:/) || /^Content-Type: text\\/plain$/ || /^Content-Type: text\\/plain;/");
            break;
        case islargerthan:
            fprintf(f, "size :over %s", fieldvalue);
            break;
        case anymessage:
            if (*tofolder == '+')
                // fprintf(f, "allof (not exists [\"list-help\", \"list-unsubscribe\", \"list-subscribe\", \"list-owner\", \"list-post\", \"list-archive\", \"list-id\", \"Mailing-List\"], not header :comparator \"i;ascii-casemap\" :is \"Precedence\" [\"list\", \"bulk\", \"junk\"], not header :comparator \"i;ascii-casemap\" :matches \"To\" \"Multiple recipients of*\" ) ");
                fprintf(f, "true ");
            else
                fprintf(f, "true ");
            break;
        }
        fprintf(f, "\n{\n");

        if (*tofolder == '!') {
            fprintf(f, "redirect %s\"%s\";\n%s", p->flags & MFR_CONTINUE ? ":copy ":"", tofolder+1, p->flags & MFR_CONTINUE ? "":"stop;\n" );
        } else if (*tofolder == '|') {
            fprintf(f, "%s;\n%s", tofolder+1, p->flags & MFR_CONTINUE ? "":"stop;\n" );
        } else if (*tofolder == '+') {
            /* vacation handling */
            struct maildir_filter_autoresp_info ai;

            if (maildir_filter_autoresp_info_init_str(&ai, tofolder+1) == 0)
            {
                /*
                if (p->fromhdr && p->fromhdr[0])
                    fprintf(f, "    AUTOREPLYFROM='%s'\n", p->fromhdr);
                else
                    fprintf(f, "    AUTOREPLYFROM=$FROM\n" );
                */
                fprintf(f, "vacation ");
                if (ai.days > 0)
                    fprintf(f, ":days %d ", ai.days );
//                fprintf(f, ":subject \"Abwesenheitsnachricht\" text:\n" );
                fprintf(f, "text:\n" );  
                fprintf(f, "%s", p->memotext);
                fprintf(f, "\n.\n;\n");
                maildir_filter_autoresp_info_free(&ai);
            } else
                syslog( LOG_ERR, "Error create vacation entry %s", p->rulename );
        } else if (strcmp(tofolder, "exit") == 0) {
            fprintf(f, "stop;\n");
        } else {
            /*char *s;
            s = maildir_name_convert(maildirpath, tofolder);
            if (!s) {
                syslog( LOG_ERR, "INTERNAL ERROR in maildir_name_convert %s", p->rulename );
            } else {
                fprintf(f, "fileinto \"%s\";\n%s", s, p->flags & MFR_CONTINUE ? "":"stop;\n");
                free(s);
            }
            */
            fprintf(f, "fileinto \"%s\";\n%s", tofolder, p->flags & MFR_CONTINUE ? "":"stop;\n");
        }
        fprintf(f, "}\n");
    }
    fflush(f);
    if (ferror(f))
    {
        fclose(f);
        return (-1);
    }

    if (fclose(f))
        return (-1);
    if (chmod(filename, 0600))
        return (-1);

    return (0);
}


/* ---------------------------------------------------------------------
 * Check if entry enabled
 *
 * --------------------------------------------------------------------- */
int
CheckIfEntryEnabled( const int active, const int endtime )
{
    if (( active == 1) && ((endtime == 0) || (endtime > time(NULL))))
    {
        return 1;
    }
    return 0;
}


/* ---------------------------------------------------------------------
 * Add internal uidlist entry
 *
 * --------------------------------------------------------------------- */
void
AddUidlistEntry( const int nuid, const int active, const int endtime )
{
    cnt_record++;
    if ( CheckIfEntryEnabled( active, endtime) == 1 )
    {
        cnt_filter++;
        uidlist[cnt_filter] = nuid ;
    }
}


/* ---------------------------------------------------------------------
 * ShowProgramHelp
 * Show all available command line options and parameters
 * --------------------------------------------------------------------- */
void
ShowProgramHelp(const char* progname)
{
    printf ("usage: %s [options]\n"
        "\t-h   show this help\n"
        "\t-v   Verbose output\n"
        "\t-s   MySQL server socket 'unix:pathname' or port 'inet:host:port'\n"
        "\t                           - default: unix:/run/mysqld/mysqld.sock\n"
        "\t-d   MySQL database name   - default: vmaildata\n"
        "\t-u   MySQL user name       - default: vmailprovider\n"
        "\t-p   MySQL user password   - default: \n"
        "\t-m   Maildir root          - default: /var/spool/postfix/virtual\n"
        "\t-g   Generate no domain and user folder\n"
        "\t-f   SQL listing query string\n"
        "\t-b   UID for sieve script  - default:  8\n"
        "\t-c   GID for sieve script  - default: 12\n\n",
        progname);
}


/* ---------------------------------------------------------------------
*
*  main
*  --------------------------------------------------------------------- */
int
main(int argc, char* argv[])
{
    int        c;
    char       sievedir[512];
    char       smaildir[512];
    char       mailuser[128];
    char       rulename[512];
    char*      mailroot      = NULL;
    MYSQL      *mysql;
    MYSQL_RES  *res;
    MYSQL_ROW  row;
    int        nrow    = 0;           // current db row #
    int        nreset  = 0;
    int        nuidold = 0;
    int        nfolder = 0;
    int errcode, i;
    struct maildirfilter mf;
    memset(&mf, 0, sizeof(mf));

    /* test UTF-8
    FILE    *f=fopen("test.txt", "wb");
    if (!f)
        return (-1);

    char *s1 = "Hello ae=ä";

    char *p =  native_to_utf8(s1);

    fprintf(f, "%s", p );
    fprintf(stderr, "> %s <\n", p );

    fclose(f);
    return (0);
    */



    while (1) {
        c = getopt(argc, argv, "b:c:d:f:ghm:p:s:u:v");
        if (c == -1)
            break;
        switch (c) {
            case 'b':
                nuid = atoi(optarg);
                break;
            case 'c':
                ngid = atoi(optarg);
                break;
            case 'd':
                mysqldatabase = strdup(optarg);
                break;
            case 'f':
                mysqlquery = strdup(optarg);
                break;
            case 'g':
                nfolder = 1;
                break;
            case 'h':
                ShowProgramHelp(argv[0]);
                ExitProg(0);
                break;
            case 'm':
                mailroot = strdup(optarg);
                break;
            case 'p':
                mysqlpass = strdup(optarg);
                break;
            case 's':
                mysqlserver = strdup(optarg);
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


    if (!mailroot)
        mailroot = strdup( "/var/spool/postfix/virtual" );

    // activate and deactivate filter only internal, not by query! 
    if (!mysqlquery)
        mysqlquery = strdup( "SELECT b.id, b.ownerid, SUBSTRING_INDEX(a.email,'@',-1), SUBSTRING_INDEX(a.email,'@',1), b.filtertype, b.flags, b.fieldname, b.fieldvalue, b.tofolder, b.body, b.active, b.dateend, b.dateupdate FROM view_users AS a JOIN maildropfilter AS b ON a.id = b.ownerid WHERE b.datefrom < UNIX_TIMESTAMP(NOW()) ORDER BY b.ownerid, b.position");

    mysql = ConnectMySQLServer();
    if (!mysql) ExitProg(-1);

    res = mysql_store_result(mysql);
    if (res == NULL)
    {
        syslog( LOG_ERR, "Error get data. %s", (char*)mysql_error(mysql));
        mysql_close(mysql);
        ExitProg(-1);
    }
/*
row0 = maildropfilter.id
row1 = maildropfilter.ownerid
row2 = user.Name (name@... )
row3 = user.Domain ( ...@domain.tld)
row4 = maildropfilter.filtertype
row5 = maildropfilter.flags
row6 = maildropfilter.fieldname
row7 = maildropfilter.fieldvalue
row8 = maildropfilter.tofolder
row9 = maildropfilter.body
row10= maildropfilter.active
row11= maildropfilter.dateend
row12= maildropfilter.dateupdate
*/

// printf("Fieldcount: %d \n", mysql_num_fields(res) );
    while ((row = mysql_fetch_row(res)) != NULL)
    {
        nrow++;
        /* define first entry for user */
        nreset     = 1;
        cnt_filter = 0;
        cnt_record = 0;
        nuidold    = atoi(row[1]);
        if (nfolder == 1)
        {
            snprintf(sievedir, 511, "%s/sieve", mailroot );
            snprintf(smaildir, 511, "%s", mailroot );
            snprintf(mailuser, 127, "%s@%s", "root", "localhost" );
        }
        else
        {
            snprintf(sievedir, 511, "%s/%s/%s/sieve", mailroot, row[2], row[3] );
            snprintf(smaildir, 511, "%s/%s/%s", mailroot, row[2], row[3] );
            snprintf(mailuser, 127, "%s@%s", row[3], row[2] );
        } 
        AddUidlistEntry( atoi(row[0]), atoi(row[10]), atoi(row[11]) );

        /* get all id nr. for build filenames */
        while ((row = mysql_fetch_row(res)) != NULL)
        {
            nrow++;
            nreset++;
            if (atoi(row[1]) != nuidold )
                break;
            // if filter active und date ok
            AddUidlistEntry( atoi(row[0]), atoi(row[10]), atoi(row[11]) );
        }

        if (chdir( smaildir ) == -1) {
           syslog( LOG_ERR, "Cannot change to mail directory %s", smaildir);
           continue;
        }
        mkdir(sievedir, 0700);
        chown(sievedir, nuid, ngid);
        if (chdir( sievedir ) == -1) {
           syslog( LOG_ERR, "Cannot change to sieve directory %s", sievedir);
           continue;
        }
        /* return to first entry from current user */
        nrow = nrow - nreset;
        mysql_data_seek( res, nrow );

        /* create and update all filter entries */
        while (( cnt_record > 0 ) && ((row = mysql_fetch_row(res)) != NULL))
        {
            nrow++;
            cnt_record--;
            if ( CheckIfEntryEnabled( atoi(row[10]), atoi(row[11])) == 1 )
            {
                if (verbose == 1)
                {
                    printf("%d %s | %s%s%s %s%s %s %s %s", atoi(row[0]),mailuser, 
                                                     atoi(row[5])& MFR_BODY ? "BODY ":"",
                                                     atoi(row[5])& MFR_PLAINSTRING ? "PLAINSTRING ":"",
                                                     row[4],
                                                     atoi(row[5])& MFR_DOESNOT ? "NOT ":"",
                                                     row[6],row[7],row[8],
                                                     atoi(row[5])& MFR_CONTINUE ? "CONTINUE ":"STOP ");
                    if (row[7][1] == '+') {
                        printf("Text:\n%s\n", row[9]);
                    } else {
                        printf("\n");
                    }
                    printf("___________________________________________________________________________\n");  
                }
                snprintf( rulename, 40, "vmailentry%d %s", atoi(row[0]), row[12]);
                /* find maildirfiltertype (startswith, endswith, contains) */
                for (i=0; typelist[i].name; i++)
                {
                    if (strcasecmp(typelist[i].name, row[4]) == 0)
                        break;
                }
                if ( !row[9] ) {
                    append_sieve_rule(&mf, rulename, typelist[i].type ,atoi(row[5]), row[6], row[7], row[8], ".", "", &errcode);
                } else {
                    char *p = native_to_utf8(row[9]);
                    append_sieve_rule(&mf, rulename, typelist[i].type ,atoi(row[5]), row[6], row[7], row[8], ".", p, &errcode);
                    if ( p )
                        free ( p );
                }
            }
        }
        errcode = write_sieve_rules(&mf, ".vmailfilter.tmp", ".", "INBOX", mailuser);
        maildir_filter_freerules(&mf);
        if (errcode == 0)
        {
            snprintf(rulename, 511, "%s/.dovecot.sieve", smaildir );
            unlink( SIEVEFILE );
            rename(".vmailfilter.tmp", SIEVEFILE );
            unlink( rulename );
            symlink( "sieve/vmailfilter.sieve", rulename );
        }
    }

    if (mailroot)       free(mailroot);
    mysql_close(mysql);
    ExitProg( 1 );
    return 0;
}
