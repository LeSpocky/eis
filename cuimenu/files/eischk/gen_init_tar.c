/* gen_init_cpio.c: taken form the Linux kernel.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 as published by
 * the Free Software Foundation
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <fcntl.h>
#include <errno.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>

/*
 * Original work by Jeff Garzik
 *
 * External file lists, symlink, pipe and fifo support by Thayne Harbaugh
 */

#define xstr(s) #s
#define str(s) xstr(s)

#ifdef O_BINARY
#warning Using binary flags in open and fopen ...
#define FOPEN_BINRAY_MODE "b"
#else
#define FOPEN_BINRAY_MODE
#define O_BINARY 0
#endif

static unsigned int offset;
static FILE *archive;

struct file_handler {
        const char *type;
        int (*handler)(const char *line);
};

#define FALSE 0
#define TRUE  1

#define REGTYPE  '0'           /* regular file */
#define AREGTYPE '\0'          /* regular file */
#define LNKTYPE  '1'           /* link */
#define SYMTYPE  '2'           /* reserved */
#define CHRTYPE  '3'           /* character special */
#define BLKTYPE  '4'           /* block special */
#define DIRTYPE  '5'           /* directory */
#define FIFOTYPE '6'           /* FIFO special */

union {
        /* ustar header, Posix 1003.1 */
        unsigned char raw[512];
        struct {
                char name[100]; /*   0-99 */
                char mode[8];   /* 100-107 */
                char uid[8];    /* 108-115 */
                char gid[8];    /* 116-123 */
                char size[12];  /* 124-135 */
                char mtime[12]; /* 136-147 */
                char chksum[8]; /* 148-155 */
                char typeflag;  /* 156-156 */
                char linkname[100];     /* 157-256 */
                char magic[6];  /* 257-262 */
                char version[2];        /* 263-264 */
                char uname[32]; /* 265-296 */
                char gname[32]; /* 297-328 */
                char devmajor[8];       /* 329-336 */
                char devminor[8];       /* 337-344 */
                char prefix[155];       /* 345-499 */
                char padding[12];       /* 500-512 */
        } formated;
} tar;
#define tar_set(field,val) put_octal(tar.formated.field, sizeof(tar.formated.field), val);

/* Put an octal string into the specified buffer.
 * The number is zero and space padded and possibly null padded.
 * Returns TRUE if successful.  */
static int put_octal(char *cp, int len, long value)
{
        int tempLength;
        char tempBuffer[32];
        char *tempString = tempBuffer;

        /* Create a string of the specified length with an initial space,
         * leading zeroes and the octal number, and a trailing null.  */
        sprintf(tempString, "%0*lo", len - 1, value);

        /* If the string is too large, suppress the leading space.  */
        tempLength = strlen(tempString) + 1;
        if (tempLength > len) {
                tempLength--;
                tempString++;
        }

        /* If the string is still too large, suppress the trailing null.  */
        if (tempLength > len)
                tempLength--;

        /* If the string is still too large, fail.  */
        if (tempLength > len)
                return FALSE;

        /* Copy the string to the field.  */
        memcpy(cp, tempString, len);

        return TRUE;
}

static void prepare_header(const char * name, char type, int mode, int uid, int gid)
{
        time_t mtime = time(NULL);

        memset(&tar, 0, sizeof(tar));
        strcpy(tar.formated.magic, "ustar");
        strncpy(tar.formated.name, name, sizeof(tar.formated.name)-1);
        tar.formated.typeflag = type;
        tar_set(uid, uid);
        tar_set(gid, gid);
        tar_set(mode, mode);
        tar_set(size, 0);
        tar_set(mtime, mtime);
}

static void write_header(void)
{
        int chksum;
        unsigned char * cp;

        /* Calculate and store the checksum (i.e., the sum of all of
           the bytes of the header).  The checksum field must be
           filled with blanks for the calculation.  The checksum field
           is formatted differently from the other fields: it has [6]
           digits, a null, then a space -- rather than digits,
           followed by a null like the other fields... */

        memset(tar.formated.chksum, ' ', sizeof(tar.formated.chksum));
        for (chksum = 0, cp = tar.raw; cp < tar.raw + 512; cp++)
            chksum += *cp;
        put_octal(tar.formated.chksum, 7, chksum);
        fwrite(tar.raw, sizeof(tar.raw), 1, archive);
        offset += sizeof(tar.raw);
}
static void push_pad (void)
{
        while (offset & 511) {
                fputc(0, archive);
                offset++;
        }
}

static void tar_trailer(void)
{
        memset(&tar, 0, sizeof(tar));
        fwrite(tar.raw, sizeof(tar.raw), 1, archive);
        fwrite(tar.raw, sizeof(tar.raw), 1, archive);
}

static int tar_mklink(const char *name, const char *target, char type,
                      unsigned int mode, uid_t uid, gid_t gid)
{
        prepare_header(name, type, mode, uid, gid);
        strncpy(tar.formated.linkname, target,
                sizeof(tar.formated.linkname)-1);
        write_header();
        return 0;
}

static int tar_mkslink_line(const char *line)
{
        char name[PATH_MAX + 1];
        char target[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        int rc = -1;

        if (5 != sscanf(line, "%" str(PATH_MAX) "s %" str(PATH_MAX) "s %o %d %d", name, target, &mode, &uid, &gid)) {
                fprintf(stderr, "Unrecognized dir format '%s'", line);
                goto fail;
        }
        rc = tar_mklink(name, target, SYMTYPE, mode, uid, gid);
 fail:
        return rc;
}

static int tar_mkhlink_line(const char *line)
{
        char name[PATH_MAX + 1];
        char target[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        int rc = -1;

        if (5 != sscanf(line, "%" str(PATH_MAX) "s %" str(PATH_MAX) "s %o %d %d", name, target, &mode, &uid, &gid)) {
                fprintf(stderr, "Unrecognized dir format '%s'", line);
                goto fail;
        }
        rc = tar_mklink(name, target, LNKTYPE, mode, uid, gid);
 fail:
        return rc;
}

static int tar_mkgeneric(const char *name, char type, unsigned int mode,
                       uid_t uid, gid_t gid)
{
        prepare_header(name, type, mode, uid, gid);
        write_header();
        return 0;
}

enum generic_types {
        GT_DIR,
        GT_PIPE,
};

struct generic_type {
        const char *type;
        char  mode;
};

static struct generic_type generic_type_table[] = {
        [GT_DIR] = {
                .type = "dir",
                .mode = DIRTYPE
        },
        [GT_PIPE] = {
                .type = "pipe",
                .mode = FIFOTYPE
        }
};

static int tar_mkgeneric_line(const char *line, enum generic_types gt)
{
        char name[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        int rc = -1;

        if (4 != sscanf(line, "%" str(PATH_MAX) "s %o %d %d", name, &mode, &uid, &gid)) {
                fprintf(stderr, "Unrecognized %s format '%s'",
                        line, generic_type_table[gt].type);
                goto fail;
        }
        rc = tar_mkgeneric(name, generic_type_table[gt].mode, mode, uid, gid);
 fail:
        return rc;
}

static int tar_mkdir_line(const char *line)
{
        return tar_mkgeneric_line(line, GT_DIR);
}

static int tar_mkpipe_line(const char *line)
{
        return tar_mkgeneric_line(line, GT_PIPE);
}

#if 0
static int tar_mksock_line(const char *line)
{
        return tar_mkgeneric_line(line, GT_SOCK);
}
#endif
static int tar_mknod(const char *name, unsigned int mode,
                       uid_t uid, gid_t gid, char dev_type,
                       unsigned int maj, unsigned int min)
{
        int type;

        if (dev_type == 'b')
                type = BLKTYPE;
        else
                type = CHRTYPE;

        prepare_header(name, type, mode, uid, gid);
        tar_set(devmajor, maj);
        tar_set(devminor, min);
        write_header();

        return 0;
}

static int tar_mknod_line(const char *line)
{
        char name[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        char dev_type;
        unsigned int maj;
        unsigned int min;
        int rc = -1;

        if (7 != sscanf(line, "%" str(PATH_MAX) "s %o %d %d %c %u %u",
                         name, &mode, &uid, &gid, &dev_type, &maj, &min)) {
                fprintf(stderr, "Unrecognized nod format '%s'", line);
                goto fail;
        }
        rc = tar_mknod(name, mode, uid, gid, dev_type, maj, min);
 fail:
        return rc;
}

/* Not marked static to keep the compiler quiet, as no one uses this yet... */
static int tar_mkfile(const char *name, const char *location,
                        unsigned int mode, uid_t uid, gid_t gid)
{
        char *filebuf = NULL;
        struct stat buf;
        int file = -1;
        int retval;
        int rc = -1;

        retval = stat (location, &buf);
        if (retval) {
                fprintf (stderr, "File %s could not be located\n", location);
                goto error;
        }

        file = open (location, O_RDONLY | O_BINARY);
        if (file < 0) {
                fprintf (stderr, "File %s could not be opened for reading\n", location);
                goto error;
        }

        filebuf = malloc(buf.st_size);
        if (!filebuf) {
                fprintf (stderr, "out of memory\n");
                goto error;
        }

        retval = read (file, filebuf, buf.st_size);
        if (retval < 0) {
                fprintf (stderr, "Can not read %s file\n", location);
                goto error;
        }

        prepare_header(name, REGTYPE, mode, uid, gid);
        tar_set(size, buf.st_size);
        write_header();
        fwrite(filebuf, buf.st_size, 1, archive);
        offset += buf.st_size;
        push_pad();
        rc = 0;

error:
        if (filebuf) free(filebuf);
        if (file >= 0) close(file);
        return rc;
}

/* NB: _DESTROYS_ str[len] character! */
static unsigned long long getOctal(char *str, int len)
{
        unsigned long long v;
        str[len] = '\0';
        v = strtoull(str, &str, 8);
        if (*str) {
                fprintf(stderr, "corrupted octal value in tar header");
                exit(1);
        }
        return v;
}
#define GET_OCTAL(a) getOctal((a), sizeof(a))

void prepare_append(FILE * f)
{
        long offs = 0;
        long size;

        assert(sizeof(tar) == 512);

        for(;;) {
                if (fread(&tar, sizeof(tar), 1, f) != 1) {
                        fprintf(stderr, "Short read while seeking through tar archive, aborting\n");
                        exit(1);
                }

                /* If there is no filename its an empty header */
                if (tar.formated.name[0] == 0 && tar.formated.prefix[0] == 0) {
                        /* rewind tar archive */
                        fseek(f, offs, SEEK_SET);
                        return;
                }
                offs += sizeof(tar);

                size = GET_OCTAL(tar.formated.size);
                if (size) {
                        if (size % sizeof(tar))
                                size += sizeof(tar) - size % sizeof(tar);

                        offs += size;
                        fseek(f, offs, SEEK_SET);
#if 0
                        printf("seeking to offset %lx and skipping file '%s'\n",
                               offs, tar.formated.name);
                } else {
                        printf("skipping file '%s'\n", tar.formated.name);
#endif
                }
        }
}

#define MKFILE tar_mkfile
#include "cpio_conv.c"

static int tar_mkfile_line(const char *line)
{
        char name[PATH_MAX + 1];
        char location[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        int rc = -1;

        if (! parse_file_line (line, name, location, &mode, &uid, &gid)) {
                fprintf(stderr, "Unrecognized file format '%s'", line);
                goto fail;
        }
        rc = tar_mkfile(name, location, mode, uid, gid);
 fail:
        return rc;
}

struct file_handler file_handler_table[] = {
        {
                .type    = "file",
                .handler = tar_mkfile_line,
        }, {
                .type    = "ufile",
                .handler = cpio_unix_mkfile_line,
        }, {
                .type    = "dfile",
                .handler = cpio_dos_mkfile_line,
        }, {
                .type    = "sfile",
                .handler = cpio_shell_mkfile_line,
        }, {
                .type    = "nod",
                .handler = tar_mknod_line,
        }, {
                .type    = "dir",
                .handler = tar_mkdir_line,
        }, {
                .type    = "slink",
                .handler = tar_mkslink_line,
        }, {
                .type    = "hlink",
                .handler = tar_mkhlink_line,
        }, {
                .type    = "pipe",
                .handler = tar_mkpipe_line,
#if 0
        }, {
                .type    = "sock",
                .handler = tar_mksock_line,
#endif
        }, {
                .type    = NULL,
                .handler = NULL,
        }
};

#define LINE_SIZE (2 * PATH_MAX + 50)

int main (int argc, char *argv[])
{
        FILE *tar_list;
        char line[LINE_SIZE];
        char *args, *type;
        int ec = 0;
        int line_nr = 0;

        get_options(argc, argv);

        if (! (tar_list = fopen(list_name, "r"))) {
                fprintf(stderr, "ERROR: unable to open '%s': %s\n\n",
                        list_name, strerror(errno));
                usage(argv[0]);
                exit(1);
        }

        while (fgets(line, LINE_SIZE, tar_list)) {
                int type_idx;
                size_t slen = strlen(line);

                line_nr++;

                if ('#' == *line) {
                        /* comment - skip to next line */
                        continue;
                }

                if (! (type = strtok(line, " \t"))) {
                        fprintf(stderr,
                                "ERROR: incorrect format, could not locate file type line %d: '%s'\n",
                                line_nr, line);
                        ec = -1;
                }

                if ('\n' == *type) {
                        /* a blank line */
                        continue;
                }

                if (slen == strlen(type)) {
                        /* must be an empty line */
                        continue;
                }

                if (! (args = strtok(NULL, "\n"))) {
                        fprintf(stderr,
                                "ERROR: incorrect format, newline required line %d: '%s'\n",
                                line_nr, line);
                        ec = -1;
                }

                for (type_idx = 0; file_handler_table[type_idx].type; type_idx++) {
                        int rc;
                        if (! strcmp(line, file_handler_table[type_idx].type)) {
                                if ((rc = file_handler_table[type_idx].handler(args))) {
                                        ec = rc;
                                        fprintf(stderr, " line %d\n", line_nr);
                                }
                                break;
                        }
                }

                if (NULL == file_handler_table[type_idx].type) {
                        fprintf(stderr, "unknown file type line %d: '%s'\n",
                                line_nr, line);
                }
        }
        tar_trailer();

        exit(ec);
}
