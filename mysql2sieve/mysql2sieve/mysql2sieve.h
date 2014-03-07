#ifndef mysqlmaildropfilter_h
#define mysqlmaildropfilter_h

/* ---------------------------------------------------------------------
 *
 * Copyright (C) 2007
 * Jens Vehlhaber
 *
 * Last Update:  $Id: mysqlmaildropfilter.h 9685 2007-04-05 21:00:11Z jv $
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


enum maildirfiltertype {
	startswith,
	endswith,
	contains,
	hasrecipient,
	mimemultipart,
	textplain,
	islargerthan,
	anymessage
	} ;


static struct {
    enum maildirfiltertype type;
    const char *name;
    } typelist[] = {
        {startswith, "startswith"},
        {endswith, "endswith"},
        {contains, "contains"},
        {hasrecipient, "hasrecipient"},
        {mimemultipart, "mimemultipart"},
        {textplain, "textplain"},
        {islargerthan, "islargerthan"},
        {anymessage, "anymessage"},
        { 0, 0}};


struct maildirfilterrule {
	struct maildirfilterrule *next, *prev;
	char *rulename;
	enum maildirfiltertype type;
	int flags;
#define MFR_DOESNOT     1 /* Negates pretty much every condition */
#define MFR_BODY        2 /* startswith/endswith/contains applied to body */
#define MFR_CONTINUE    4 /* Continue filtering (cc instead of to) */
#define MFR_PLAINSTRING 8 /* Pattern is a plain string, not a regex */
	char *fieldname;	/* Match this header */
	char *fieldvalue;	/* Match/search value */
	char *tofolder;		/* Destination folder, fwd address, err msg */
	char *fromhdr;		/* From: header on autoreplies. */
	char *memotext;		/* Vacation or comment text. */	
	} ;

struct maildirfilter {
	struct maildirfilterrule *first, *last;
	} ;


#define	maildir_filter_freerules(r) do { \
    while ( (r)->first ) \
        maildir_filter_ruledel( (r), (r)->first ); \
    } while (0)


#define	MF_ERR_BADRULENAME	1
#define	MF_ERR_BADRULETYPE	2
#define	MF_ERR_BADRULEHEADER	3
#define	MF_ERR_BADRULEVALUE	4
#define	MF_ERR_BADRULEFOLDER	5
#define MF_ERR_BADFROMHDR	6
#define MF_ERR_EXISTS		7
#define MF_ERR_INTERNAL		100


#define	MF_LOADOK	    0
#define	MF_LOADNOTFOUND	1
#define	MF_LOADFOREIGN	2
#define	MF_LOADERROR	3


struct maildir_filter_autoresp_info {
	char *name;
	int dsnflag;
	unsigned days;
} ;


#define INBOX   "INBOX"
#define DRAFTS  "Drafts"
#define SENT    "Sent"
#define TRASH   "Trash"
#define SHARED  "shared"

#define SHAREDSUBDIR    "shared-folders"

#define NEWSHAREDSP "#shared"
#define NEWSHARED   "#shared."

#define PUBLIC      "public" /* SMAP */

#define MDIRSEP     ":"

#define NUMBUFSIZE  60

#define CONTENT_CHARSET "ISO-8859-15"

#define SIEVEFILE   "vmailfilter.sieve"

#endif

