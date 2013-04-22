#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct entry * lookup_entry (char * name);
int get_chksum (void);
char get_header_tar(int fd);
void usage (char *msg);

#define FALSE 0
#define TRUE 1
#define EXIT_FAILURE 1
#define EXIT_SUCCESS 0

long pos = 0;
long size;
int verb = 0;

#define DIRTYPE  '5'            /* directory */

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

struct entry {
    char name[100];     /*   0-99 */
    int mode, uid, gid;
};

struct entry default_dir = (struct entry){"", 0755, 0, 0};

static int alloc_entries = 128;
static int max_entries = 0;
static int last_entry = 0;
struct entry * entries;

static struct entry * get_entry (void)
{
    if (! entries) {
        max_entries += alloc_entries;
        alloc_entries *= 2;
        entries = (struct entry *)malloc (max_entries * sizeof (struct entry));
    }

    if (last_entry == max_entries) {
        max_entries += alloc_entries;
        alloc_entries *= 2;
        entries = (struct entry *)realloc (entries, max_entries * sizeof (struct entry));
    }

    return entries + last_entry++;
}

struct entry * lookup_entry (char * name)
{
    struct entry * e;
    if (*name == '.' && *(name+1) == '/')
        name +=2;

    for (e=entries; e < entries + last_entry; e++)
        if (! strcmp (e->name, name))
            return e;
    return 0;
}

static void read_perms (char * file)
{
    FILE * fp;
    char buffer[1024];

    if (! (fp = fopen (file, "r"))) {
        perror ("Error opening permisson file");
        exit (1);
    }

    while (fgets (buffer, sizeof(buffer), fp)) {
        struct entry * e = get_entry ();
        if (sscanf (buffer, "%s %d %d %o",
                    e->name, &e->uid, &e->gid, &e->mode) != 4) {
            fprintf (stderr, "failed to read permissions, offending line:\n"
                     "\t%s\n", buffer);
            exit (1);
        }
    }
    fclose (fp);
}

int get_chksum (void)
{
    long sum = 0;
    int i;

    /* Do checksum on headers */
    for (i =  0; i < 148 ; i++) {
        sum += tar.raw[i];
    }
    sum += ' ' * 8;
    for (i =  156; i < 512 ; i++) {
        sum += tar.raw[i];
    }
    if (sum != strtol(tar.formated.chksum, NULL, 8)) {
        fprintf (stderr, "Invalid tar header checksum: %s != %lo\n",  tar.formated.chksum, sum);
        return(EXIT_FAILURE);
    }
    return EXIT_SUCCESS;
}

char get_header_tar(int fd)
{
    static int end = 0;
    struct entry *e;

    if (read(fd, tar.raw, 512) != 512) {
        /* Assume end of file */
        return(1);
    }
    pos += 512;

    /* If there is no filename its an empty header */
    if (tar.formated.name[0] == 0) {
        if (end) {
            /* This is the second consecutive empty header! End of archive!
             * Read until the end to empty the pipe from gz or bz2
             */
            while (read (fd, tar.raw, 512) == 512);
            return(EXIT_FAILURE);
        }
        end = 1;
        return(EXIT_SUCCESS);
    }
    end = 0;

    /* Check header has valid magic, "ustar" is for the proper tar
     * 0's are for the old tar format
     */
    if (strncmp(tar.formated.magic, "ustar", 5) != 0) {
        perror("Invalid tar magic");
        return EXIT_FAILURE;
    }

    if (get_chksum () != EXIT_SUCCESS)
        return EXIT_FAILURE;

    e = lookup_entry (tar.formated.name);
    if (!e && tar.formated.typeflag == DIRTYPE &&
        strcmp(tar.formated.uid, "0000000") ) {
        e = &default_dir;
        if (verb)
            printf ("using default permissions for %s\n",
                    tar.formated.name);
    }

    if (e) {
        long chksum;
        unsigned char * cp;

        if (verb) {
            printf("setting %s to uid %d (%s), gid %d (%s), mode: %o (%s)\n",
                   tar.formated.name, e->uid, tar.formated.uid,
                   e->gid, tar.formated.gid,
                   e->mode, tar.formated.mode);
        }
        put_octal(tar.formated.uid, 8, e->uid);
        put_octal(tar.formated.gid, 8, e->gid);
        put_octal(tar.formated.mode, 8, e->mode);
        /* Calculate and store the checksum (i.e., the sum of all of
         * the bytes of
         * the header).  The checksum field must be filled with blanks for the
         * calculation.  The checksum field is formatted differently from the
         * other fields: it has [6] digits, a null, then a space -- rather than
         * digits, followed by a null like the other fields... */
        memset(tar.formated.chksum, ' ', sizeof(tar.formated.chksum));
        memset(tar.formated.uname, '\0', sizeof(tar.formated.uname));
        memset(tar.formated.gname, '\0', sizeof(tar.formated.gname));
        for (chksum = 0, cp = tar.raw; cp < tar.raw + 512; cp++)
            chksum += *cp;
        put_octal(tar.formated.chksum, 7, chksum);

        if (get_chksum () != EXIT_SUCCESS) {
            fprintf(stderr, "wrong checksum after recalc\n");
            return EXIT_FAILURE;
        }

        if (lseek (fd, pos - 512, SEEK_SET) < 0) {
            perror ("writing tar header");
            return EXIT_FAILURE;
        }
        if (write (fd, tar.raw, 512) < 0) {
            perror ("writing tar header");
            return EXIT_FAILURE;
        }
    }

    size = strtol(tar.formated.size, NULL, 8);
    if (size) {
        pos += ((size + 511) / 512) * 512;
        if (lseek (fd, pos, SEEK_SET) < 0) {
            perror ("seeking to next header");
            return EXIT_FAILURE;
        }
    }
    return(EXIT_SUCCESS);
}

void usage (char *msg)
{
    fprintf (stderr, "%s\n"
             "usage: filter -t tarball -p permissions\n", msg);
    exit (1);
}

int main (int argc, char ** argv)
{
    int fd;
    int c;
    char *perm=0, *tar = 0;

    while ( (c = getopt (argc, argv, "p:t:v")) != -1) {
        switch (c) {
        case 'p' :
            perm = optarg;
            break;
        case 't' :
            tar = optarg;
            break;
        case 'v' :
            verb++;
            break;
        default:
            usage("unknown option");
            break;
        }
    }

    if (!perm || !tar)
        usage("missing parameters");

    read_perms(perm);
    fd = open (tar, O_RDWR);
    while ( get_header_tar (fd) == EXIT_SUCCESS );
    return 0;
}
