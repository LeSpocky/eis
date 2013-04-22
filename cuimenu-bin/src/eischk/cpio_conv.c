extern int yylex(void);
extern int lex_init(FILE * in, FILE * out);
static char * tmp_dir = "/tmp";
char * list_name = 0;
static int pid;

static void usage(const char *prog)
{
        fprintf(stderr, "Usage:\n"
                "\t%s [ -t <tmp_dir> ] [ [ -o | -a ] <file> ] <cpio_list>\n"
                "\n"
                "<cpio_list> is a file containing newline separated entries that\n"
                "describe the files to be included in the initramfs archive:\n"
                "\n"
                "<tmp_dir> is used to store temporary files during conversion (default: /tmp)\n"
                "<file> is the name of the file the output should be written to\n"
                "# a comment\n"
                "file <name> <location> <mode> <uid> <gid>\n"
                "  ufile - same as file but convert to unix format\n"
                "  dfile - same as file but convert to dos format\n"
                "  sfile - same as file but compress shell script\n"
                "dir <name> <mode> <uid> <gid>\n"
                "nod <name> <mode> <uid> <gid> <dev_type> <maj> <min>\n"
                "slink <name> <target> <mode> <uid> <gid>\n"
                "pipe <name> <mode> <uid> <gid>\n"
                "sock <name> <mode> <uid> <gid>\n"
                "\n"
                "<name>      name of the file/dir/nod/etc in the archive\n"
                "<location>  location of the file in the current filesystem\n"
                "<target>    link target\n"
                "<mode>      mode/permissions of the file\n"
                "<uid>       user id (0=root)\n"
                "<gid>       group id (0=root)\n"
                "<dev_type>  device type (b=block, c=character)\n"
                "<maj>       major number of nod\n"
                "<min>       minor number of nod\n"
                "\n"
                "example:\n"
                "# A simple initramfs\n"
                "dir /dev 0755 0 0\n"
                "nod /dev/console 0600 0 0 c 5 1\n"
                "dir /root 0700 0 0\n"
                "dir /sbin 0755 0 0\n"
                "file /sbin/kinit /usr/src/klibc/kinit/kinit 0755 0 0\n",
                prog);
}

static void get_options(int argc, char ** argv)
{
        char * out_file = 0;
        int append = 0;

        int index;

        while(1) {
                int c = getopt(argc, argv, "t:o:a:");

                if (c == -1)
                        break;

                switch (c) {
                case 't':
                        tmp_dir = optarg;
                        break;
                case 'o':
                        out_file = optarg;
                        break;
                case 'a':
                        append=1;
                        out_file = optarg;
                        break;
                default:
                        usage(argv[0]);
                        exit(1);
                }
        }

        index = optind;

        if (index >= argc) {
                usage(argv[0]);
                exit(1);
        }
        list_name = argv[index++];
        if (index != argc) {
                usage(argv[0]);
                exit(1);
        }

        if (out_file) {
                const char * mode = append ? "r+" FOPEN_BINRAY_MODE : "w" FOPEN_BINRAY_MODE;
                if (! (archive = fopen(out_file,  mode)) ) {
                        fprintf(stderr,
                                "unable to open target archive '%s': %s\n",
                                out_file, strerror(errno));
                        exit(1);
                }
                if (append) {
                        prepare_append(archive);
                        offset = ftell(archive);
                }
        } else
                archive = stdout;

        pid = getpid();
}

static int
dtou (FILE *in, FILE *out)
{
        int     cnt = 0;
        int     c;

        while ((c = fgetc (in)) != EOF)
        {
                if (c == '\r')     /* don't copy multiple CRs at end of line   */
                {
                        cnt++;
                }
                else if (c == '\n')
                {
                        cnt = 0;
                        fputc (c, out);
                }
                else
                {
                        while (cnt > 0) /* CRs not at end of line, copy them!       */
                        {
                                fputc ('\r', out);
                                cnt--;
                        }
                        fputc (c, out);
                }
        }
        return 0;
}

static int
utod (FILE *in, FILE *out)
{
        int     cnt = 0;
        int     c;

        while ((c = fgetc(in)) != EOF)
        {
                if (c == '\r')       /* don't copy multiple CRs at end of line */
                {
                        cnt++;
                }
                else if (c == '\n')
                {
                        cnt = 0;
                        fputs("\r\n", out);
                }
                else
                {
                        while (cnt > 0)   /* CRs not at end of line, copy them!     */
                        {
                                fputc ('\r', out);
                                cnt--;
                        }
                        fputc(c, out);
                }
        }
        return 0;
}

static int
squeeze (FILE *in, FILE *out)
{
        extern int yy_flex_debug;
        yy_flex_debug = 0;
        lex_init(in, out);
        return yylex();
}

static int
parse_file_line (const char * line, char * name, char * location,
                 unsigned int * mode, int * uid, int * gid)
{
        const char * p;
        int len;

        while (*line && isspace(*line))
                line++;
        for (p = line; *p && !isspace(*p); p++)
                ;
        len = p - line;
        if (len < PATH_MAX) {
                memcpy(name, line, len);
                *(name + len) = 0;
        } else
                return 0;

        line += len;
        while (*line && isspace(*line))
                line++;

        if (*line == '\'') {
                line++;
                for (p=line; *p && *p != '\''; p++)
                        ;
        } else {
                for (p = line; *p && !isspace(*p); p++)
                        ;
        }
        len = p - line;
        if (len < PATH_MAX) {
                memcpy(location, line, len);
                *(location + len) = 0;
        } else
                return 0;

        line += len;
        if (*line == '\'')
                line++;

        while (*line && isspace(*line))
                line++;

        return 3 == sscanf(line, "%o %d %d", mode, uid, gid);
}

static const char *
my_basename(const char * name)
{
        const char * base = name;
        while (*name) {
                if (*name == '/' || *name == '\\')
                        base = name + 1;
                name++;
        }
        return base;
}
typedef int (*conversion_t)(FILE *in, FILE *out);
static int cpio_conv_mkfile_line(const char *line, conversion_t conv)
{
        char name[PATH_MAX + 1];
        char tmp_name[PATH_MAX + 1];
        char location[PATH_MAX + 1];
        unsigned int mode;
        int uid;
        int gid;
        int rc = -1;

        FILE* in = 0;
        FILE* out = 0;

        if (! parse_file_line (line, name, location, &mode, &uid, &gid)) {
                fprintf(stderr, "Unrecognized file format '%s'", line);
                goto fail;
        }

        sprintf(tmp_name, "%s/%s.%d", tmp_dir, my_basename(location), pid);
        in  = fopen(location, "r" FOPEN_BINRAY_MODE);
        out = fopen(tmp_name, "w" FOPEN_BINRAY_MODE);

        if (!in || !out)
                goto fail;

        conv(in, out);

        fclose(in);
        fflush(out);
        fclose(out);

        rc = MKFILE(name, tmp_name, mode, uid, gid);

        unlink(tmp_name);
        return rc;
 fail:
        if (in)
                fclose(in);
        if (out) {
                fclose(out);
                unlink(tmp_name);
        }

        return rc;
}

static int cpio_unix_mkfile_line(const char *line)
{
        return cpio_conv_mkfile_line(line, dtou);
}

static int cpio_dos_mkfile_line(const char *line)
{
        return cpio_conv_mkfile_line(line, utod);
}

static int cpio_shell_mkfile_line(const char *line)
{
        return cpio_conv_mkfile_line(line, squeeze);
}

