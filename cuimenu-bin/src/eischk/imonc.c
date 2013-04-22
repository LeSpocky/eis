/*----------------------------------------------------------------------------
 *  imonc.c - imond client for Linux
 *
 *  Copyright (c) 2000-2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       06.06.2000  fm
 *  Last Update:    25.01.2001  fm
 *----------------------------------------------------------------------------
 */

#include <errno.h>
#include <stdio.h>

#ifdef FLI4L                                    /* imonc on fli4-router     */

#include <sys/types.h>
#include <termio.h>

#else

#  ifdef linux
#    include <ncurses.h>
#  else
#    include <curses.h>
#  endif

#endif /* not FLI4L */

#include <string.h>
#include <ctype.h>
#include <time.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>

#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>                          /* decl of inet_addr()      */
#include <sys/socket.h>


/*----------------------------------------------------------------------------
 * some mini curses functions for fli4l router without curses library
 *----------------------------------------------------------------------------
 */

#ifdef FLI4L                                    /* imonc on fli4-router     */

#define A_NORMAL        0
#define A_REVERSE       1
#define ERR             (-1)
#define FALSE           0
#define TRUE            1
#define OK              0
#define KEY_BACKSPACE   8
#define KEY_DC          127
#define stdscr          0
#define LINES           24
#define getyx(d,y,x)    y = cur_y, x = cur_x

static struct termio    oldmode;
static struct termio    newmode;
static int              cur_y;
static int              cur_x;

static int
addch (ch)
int ch;
{
    putchar (ch);

    if (ch == 8)
    {
        if (cur_x > 0)
        {
            cur_x--;
        }
    }
    else
    {
        cur_x++;
    }
    return (OK);
} /* addch (ch) */

static int
addstr (str)
char *  str;
{
    fputs (str, stdout);
    cur_x += strlen (str);
    return (OK);
} /* addstr (str) */

static int
attrset (attr)
int attr;
{
    if (attr == A_REVERSE)
    {
        fputs ("\033[7m", stdout);
    }
    else
    {
        fputs ("\033[0m", stdout);
    }
    return (OK);
} /* attrset (attr) */

static int
cbreak ()
{
    return (OK);
} /* cbreak () */

static int
clrtobot ()
{
    fputs ("\033[J", stdout);
    return (OK);
} /* clrtobot () */

static int
clrtoeol ()
{
    fputs ("\033[K", stdout);
    return (OK);
} /* clrtoeol () */

static int
move (y, x)
int y;
int x;
{
    printf ("\033[%d;%dH", y + 1, x + 1);
    cur_y = y;
    cur_x = x;
    return (OK);
} /* move (y, x) */

static int
getch ()
{
    int ch;

    fflush (stdout);
    ch = getchar ();
    return (ch);
} /* getch () */

static int
halfdelay (tenths)
int tenths;
{
    if (tenths <= 0)
    {
        newmode.c_cc[VMIN] = 1;                         /* block input:     */
        newmode.c_cc[VTIME] = 0;                        /* one character    */
    }
    else
    {
        if (tenths > 255)
        {
            tenths = 255;
        }
        newmode.c_cc[VMIN] = 0;                         /* set timeout      */
        newmode.c_cc[VTIME] = tenths;                   /* in tenths of sec */
    }
    (void) ioctl (0, TCSETAW, &newmode);
    return (OK);
} /* halfdelay (tenths) */

static int
keypad (dummy1, dummy2)
int dummy1;
int dummy2;
{
    return (OK);
} /* keypad (dummy1, dummy2) */

static int
noecho ()
{
    newmode.c_lflag &= ~ECHO;
    (void) ioctl (0, TCSETAW, &newmode);
    return (OK);
} /* noecho () */

static int
nonl ()
{
    newmode.c_oflag &= ~ONLCR;
    newmode.c_oflag &= ~ONLRET;
    (void) ioctl (0, TCSETAW, &newmode);
} /* nonl () */

#define VARARG ,v1,v2,v3,v4,v5,v6,v7,v8,v9      /* that's a bad dirty trick */

static int
printw (fmt VARARG)
char *  fmt;
{
    char str_buf[256];

    (void) sprintf (str_buf, fmt VARARG);
    (void) addstr (str_buf);
    return (OK);
} /* printw (fmt VARARG) */

static int
refresh ()
{
    (void) fflush (stdout);
    return (OK);
} /* refresh () */

static int
initscr ()
{
    (void) ioctl (0, TCGETA, &oldmode);
    (void) ioctl (0, TCGETA, &newmode);
    newmode.c_lflag &= ~ICANON;
    (void) ioctl (0, TCSETAW, &newmode);

    fputs ("\033[1;1H\033[2J", stdout);
    fflush (stdout);

    return (OK);
} /* initscr () */

static int
endwin ()
{
    move (LINES - 1, 0);
    (void) ioctl (0, TCSETAW, &oldmode);
    return (OK);
}

#endif /* FLI4L */

/*----------------------------------------------------------------------------
 *  service_connect (host_name, port)       - connect to tcp-service
 *----------------------------------------------------------------------------
 */
int
service_connect (host_name, port)
char *  host_name;
int     port;
{
    struct sockaddr_in  addr;
    struct hostent *    host_p;
    int                 fd;
    int                 opt = 1;

    (void) memset ((char *) &addr, 0, sizeof (addr));

    if ((addr.sin_addr.s_addr = inet_addr ((char *) host_name)) == INADDR_NONE)
    {
        host_p = gethostbyname (host_name);

        if (! host_p)
        {
            fprintf (stderr, "%s: host not found\n", host_name);
            return (-1);
        }

        (void) memcpy ((char *) (&addr.sin_addr), host_p->h_addr,
                        host_p->h_length);
    }

    addr.sin_family  = AF_INET;
    addr.sin_port    = htons ((unsigned short) port);

    if ((fd = socket (AF_INET, SOCK_STREAM, 0)) < 0)
    {                                           /* open socket              */
        perror ("socket");
        return (-1);
    }

    (void) setsockopt (fd, IPPROTO_TCP, TCP_NODELAY,
                       (char *) &opt, sizeof (opt));

    if (connect (fd, (struct sockaddr *) &addr, sizeof (addr)) != 0)
    {
        (void) close (fd);
        perror (host_name);
        return (-1);
    }

    return (fd);
} /* service_connect (host_name, port) */


/*----------------------------------------------------------------------------
 *  service_disconnect (fd)                 - disconnect from service
 *----------------------------------------------------------------------------
 */
void
service_disconnect (fd)
int fd;
{
    (void) close (fd);
    return;
} /* service_disconnect (fd) */

void
send_command (fd, str)
int     fd;
char *  str;
{
    char    buf[256];
    int     len = strlen (str);

    sprintf (buf, "%s\r\n", str);
    write (fd, buf, len + 2);

    return;
} /* send_command (fd, str) */


char *
get_answer (fd)
{
    static char buf[8192];
    int         len;

    len = read (fd, buf, 8192);

    if (len <= 0)
    {
        return ((char *) NULL);
    }

    while (len > 1 && (buf[len - 1] == '\n' || buf[len - 1] == '\r'))
    {
        buf[len - 1] = '\0';
        len--;
    }

    if (! strncmp (buf, "OK ", 3))                      /* OK xxxx          */
    {
        return (buf + 3);
    }
    else if (len > 2 && ! strcmp (buf + len - 2, "OK"))
    {
        *(buf + len - 2) = '\0';
        return (buf);
    }
    else if (len == 2 && ! strcmp (buf + len - 2, "OK"))
    {
        return (buf);
    }

    return ((char *) NULL);                             /* ERR xxxx         */
} /* get_answer (fd) */


static int      n_channels;
static int      n_circuits;

#define MAX_CIRCUITS    16

static char     circuits[MAX_CIRCUITS][25];

static int
passwd_getstr (buf, maxlen)
char *  buf;
int     maxlen;
{
    int     ch;
    char *  p = buf;
    int     cnt = 0;
    int     y;
    int     x;


    *p = '\0';

    while ((ch = getch ()) != '\n' && ch != '\r')
    {
        if (cnt < maxlen && ch >= 32 && ch != 127 && ch < 256)
        {
            addch ('*');
            *p++ = ch;
            cnt++;
        }
        else if ((ch == 8 || ch == 127 || ch == KEY_BACKSPACE || ch == KEY_DC)
                 && cnt > 0)
        {
            getyx (stdscr, y, x);
            x--;
            move (y, x);
            addch (' ');
            move (y, x);
            *--p = '\0';
            cnt--;
        }
    }

    *p = '\0';

    return (OK);
} /* passwd_getstr (buf, maxlen) */

int
init_status (fd)
int fd;
{
    char    pass[64];
    char    buf[64];
    char *  answer;
    int     i;

    send_command (fd, "pass");
    answer = get_answer (fd);

    if (answer && ! strcmp (answer, "1"))
    {
        int password_correct = FALSE;

        move (LINES - 1, 0);
        attrset (A_REVERSE);
        addstr (" Password: ");
        attrset (A_NORMAL);
        addch (' ');

        if (passwd_getstr (pass, 63) != ERR)
        {
            sprintf (buf, "pass %s", pass);
            send_command (fd, buf);
            answer = get_answer (fd);

            if (answer)                                         /* OK   */
            {
                password_correct = TRUE;
            }
        }

        if (password_correct == FALSE)
        {
            move (LINES - 2, 0);
            addstr ("Password incorrect");
            return (ERR);
        }
    }

    send_command (fd, "channels");
    answer = get_answer (fd);

    if (answer)
    {
        n_channels = atoi (answer);
    }

    send_command (fd, "circuits");
    answer = get_answer (fd);

    if (answer)
    {
        n_circuits = atoi (answer);

        for (i = 1; i <= n_circuits && i <= MAX_CIRCUITS; i++)
        {
            sprintf (buf, "circuit %d", i);
            send_command (fd, buf);
            answer = get_answer (fd);

            if (answer)
            {
                move (i - 1, 0);
                strcpy (circuits[i - 1], answer);
                printw ("Circuit %2d  %s", i, answer);
            }
        }
    }

    move (n_circuits + 1, 0);
    addstr ("No.  DriverId    Name                 Dir  Time     ChTime    Charge");

    move (n_circuits + 2, 0);
    addstr ("--------------------------------------------------------------------");

    return (OK);
} /* init_status (fd) */

void
get_and_set_answer (fd, cmd, arg, buf)
int     fd;
char *  cmd;
int     arg;
char *  buf;
{
    char    cmd_buf[128];
    char *  answer;

    if (arg >= 0)
    {
        sprintf (cmd_buf, "%s %d", cmd, arg);
        send_command (fd, cmd_buf);
    }
    else
    {
        send_command (fd, cmd);
    }

    if ((answer = get_answer (fd)) != (char *) NULL)
    {
        strcpy (buf, answer);
    }
    else
    {
        *buf = '\0';
    }

    return;
} /* get_and_set_answer (fd, cmd, arg, buf) */


int
print_status (fd)
int fd;
{
    char    driver_id[64];
    char    name[64];
    char    direction[64];
    char    online_time[64];
    char    charge_time [64];
    char    charge[64];
    char *  answer;
    int     i;

    send_command (fd, "date");
    answer = get_answer (fd);

    move (0, 38);
    printw ("fli4l date:    %s", answer);

    send_command (fd, "route");
    answer = get_answer (fd);

    if (answer)
    {
        i = atoi (answer);

        move (1, 38);

        addstr ("default route: ");

        if (i == 0)
        {
            addstr ("Automatic");
        }
        else
        {
            i--;

            if (i < MAX_CIRCUITS)
            {
                addstr (circuits[i]);
            }
            else
            {
                addstr ("...");
            }
        }

        clrtoeol ();
    }

    for (i = 0; i < n_channels; i++)
    {
        get_and_set_answer (fd, "driverid", i + 1, driver_id);
        get_and_set_answer (fd, "phone", i + 1, name);
        get_and_set_answer (fd, "direction", i + 1, direction);
        get_and_set_answer (fd, "time", i + 1, online_time);
        get_and_set_answer (fd, "chargetime", i + 1, charge_time);
        get_and_set_answer (fd, "charge", i + 1, charge);

        move (n_circuits + 3 + i, 0);

        printw ("%2d   %-10s  %-20s %-4s %-8s %-8s %6s", i, driver_id, name,
                direction, online_time, charge_time, charge);
    }

    refresh ();

    return (OK);
}


int
print_answer (cmd, answer, wanted_rtc, wait_for_any_key)
char *  cmd;
char *  answer;
char *  wanted_rtc;
int     wait_for_any_key;
{
    char *  p;
    int     first_answer_line   = TRUE;
    int     start_y             = n_channels + n_circuits + 4;
    int     y;

    if (! strcmp (cmd, "Help"))
    {
        start_y++;
    }

    y = start_y;

    move (y, 0);
    addstr (cmd);
    addstr (": ");

    clrtobot ();

    if (answer)
    {
        while ((p = strchr (answer, '\n')) != (char *) NULL)
        {
            if (first_answer_line)
            {
                start_y++;
                y++;
                move (y, 0);
                first_answer_line = FALSE;
            }
            *p = '\0';
            addstr (answer);
            answer = p + 1;
            y++;

            if (y >= LINES - 2)
            {
                move (LINES - 1, 0);
                attrset (A_REVERSE);
                addstr (" More ... ");
                attrset (A_NORMAL);

                while (getch () <= 0)
                {
                    ;
                }

                y = start_y;
                move (y, 0);
                clrtobot ();
            }

            move (y, 0);
        }

        if (wanted_rtc)
        {
            if (! strcmp (wanted_rtc, answer))
            {
                addstr ("ok");
            }
            else
            {
                addstr ("failed, return code: ");
                addstr (answer);
            }
        }
        else
        {
            addstr (answer);
        }

        if (wait_for_any_key == TRUE)
        {
            move (LINES - 1, 0);
            attrset (A_REVERSE);
            addstr (" Press any key ");
            attrset (A_NORMAL);

            while (getch () <= 0)
            {
                ;
            }

            move (start_y, 0);
            clrtobot ();
        }

        return (OK);
    }

    addstr ("ERROR");
    return (ERR);
} /* print_answer (cmd, answer, wanted_rtc, wait_for_any_key) */


int
get_and_print_answer (fd, cmd, wanted_rtc, wait_for_any_key)
int     fd;
char *  cmd;
char *  wanted_rtc;
int     wait_for_any_key;
{
    char *  answer;
    int     rtc;

    send_command (fd, cmd);

    if (wait_for_any_key)
    { /* HACK IN PRE VERSION (TIMETABLE COMMAND): WAIT FOR FLUSH OF IMOND */
        sleep (1);
    }

    answer = get_answer (fd);

    rtc = print_answer (cmd, answer, wanted_rtc, wait_for_any_key);

    return (rtc);
} /* get_and_print_answer (fd, cmd, wanted_rtc, wait_for_any_key) */


void
catch_sigpipe (sig)
int sig;
{
    move (LINES - 1, 0);
    clrtoeol ();
    refresh ();
    endwin ();

    fputs ("Connection lost.\n", stderr);
    exit (1);
} /* catch_sigpipe (sig) */


int
main (argc, argv)
int     argc;
char *  argv[];
{
    char    answer[4096];
    int     port = 5000;
    int     fd;
    int     ch;
    int     cnt = 1;
    char *  cmd = (char *) NULL;

#ifdef FLI4L

    FILE *  fp;

    if (argc > 1)
    {
        cmd = argv[1];
    }

    fp = fopen ("/var/run/imond.port", "r");

    if (fp)
    {
        (void) fscanf (fp, "%d", &port);
        fclose (fp);
    }

    if ((fd = service_connect ("127.0.0.1", port)) < 0)
    {
        exit (1);
    }

#else

    if (argc == 3)
    {
        port = atoi (argv[2]);
    }
    else if (argc != 2)
    {
        fprintf (stderr, "usage: %s host [port]\n", argv[0]);
        exit (1);
    }

    if ((fd = service_connect (argv[1], port)) < 0)
    {
        exit (1);
    }

#endif

    if (cmd)
    {
        if (! strcmp (cmd, "enable")        ||
            ! strcmp (cmd, "disable")       ||
            ! strcmp (cmd, "dial")          ||
            ! strcmp (cmd, "hangup")        ||
            ! strcmp (cmd, "reboot"))
        {
            char *  ap;

            send_command (fd, cmd);
            ap = get_answer (fd);

            if (ap)
            {
                printf ("%s\n", ap);
                return (0);
            }

            fprintf (stderr, "%s: no answer\n", argv[0]);
            return (1);
        }

        fprintf (stderr, "%s: unknown command: %s\n", argv[0], cmd);
        return (1);
    }

    signal (SIGPIPE, catch_sigpipe);

    initscr();
    noecho();
    nonl();
    refresh();
    cbreak();
    keypad(stdscr,TRUE);

    if (init_status (fd) == OK)
    {
        halfdelay(20);                  /* wait 2.0 seconds before timeout  */

        do
        {
            print_status (fd);

            strcpy (answer, "          0   quit               5   reboot\n");
            strcat (answer, "          1   enable             6   timetable\n");
            strcat (answer, "          2   disable            7   set default route circuit\n");
            strcat (answer, "          3   dial               8   add channel link\n");
            strcat (answer, "          4   hangup             9   remove channel link\n");

            print_answer ("Help", answer, (unsigned char *) NULL, FALSE);

            ch = getch ();

            if (isascii (ch))
            {
                ch = tolower (ch);
            }

            switch (ch)
            {
                case '0':
                    break;

                case '1':
                    get_and_print_answer (fd, "enable", "0", FALSE);
                    break;

                case '2':
                    get_and_print_answer (fd, "disable", "0", FALSE);
                    break;

                case '3':
                    get_and_print_answer (fd, "dial", "0", FALSE);
                    break;

                case '4':
                    get_and_print_answer (fd, "hangup", "0", FALSE);
                    break;

                case '5':
                    move (LINES - 1, 0);
                    addstr ("Really reboot (y/n) ? ");
                    clrtoeol ();

                    do
                    {
                        ch = getch ();
                    } while (ch != 'y' && ch != 'n');

                    if (ch == 'y')
                    {
                        get_and_print_answer (fd, "reboot", "0", FALSE);
                    }
                    break;

                case '6':
                    get_and_print_answer (fd, "timetable",
                                           (unsigned char *) NULL, TRUE);
                    break;

                case '7':
                    if (n_circuits > 0)
                    {
                        move (LINES - 1, 0);
                        printw ("circuit: 0 automatic, 1 - %d manual: ",
                                n_circuits);
                        clrtoeol ();

                        *answer = '\0';

                        do
                        {
                            ch = getch ();
                        } while (ch < '0' || ch > '9');

                        if (ch >= '0' && ch <= '0' + n_circuits)
                        {
                            sprintf (answer, "route %c", ch);
                            get_and_print_answer (fd, answer, (char *) NULL,
                                                  FALSE);
                        }
                        ch = -1;
                    }
                    break;

                case '8':
                    if (n_circuits > 0)
                    {
                        printw ("Add link to circuit: 1 - %d (0 = Cancel): ",
                                n_circuits);
                        clrtoeol ();

                        *answer = '\0';

                        do
                        {
                            ch = getch ();
                        } while (ch < '0' || ch > '9');

                        if (ch >= '1' && ch <= '0' + n_circuits)
                        {
                            sprintf (answer, "addlink %c", ch);
                            get_and_print_answer (fd, answer, (char *) NULL,
                                                  FALSE);
                        }
                        ch = -1;
                    }
                    break;

                case '9':
                    if (n_circuits > 0)
                    {
                        printw ("remove link from circuit: 1 - %d (0 = Cancel): ",
                                n_circuits);
                        clrtoeol ();

                        *answer = '\0';

                        do
                        {
                            ch = getch ();
                        } while (ch < '0' || ch > '9');

                        if (ch >= '1' && ch <= '0' + n_circuits)
                        {
                            sprintf (answer, "removelink %c", ch);
                            get_and_print_answer (fd, answer, (char *) NULL,
                                                  FALSE);
                        }
                        ch = -1;
                    }
                    break;

                case -1:
                    break;

                default:
                    break;
            }

            cnt++;
        } while (ch != 'q' && ch != '0');
    }

    move (LINES - 1, 0);
    clrtoeol ();
    refresh ();

    endwin ();

    service_disconnect (fd);

    return (0);
} /* main (argc, argv) */
