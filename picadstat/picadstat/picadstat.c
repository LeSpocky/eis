/* ========================================================================== */
/*   picadstat.c                                                              */
/*   system status for PiFaceCaD Display                                      */
/*   (c) 2015 Jens Vehlhaber                                                  */
/*   Description                                                              */
/* ========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <net/if.h>

#include <pifacecad.h>
#include <mcp23s17.h>


/*#define LCDDEBUG 1 */


/* ========================================================================== */
// read current CPU frequency
int get_cpufreq(void) {
    int freq = 0;
    char line[10];
    FILE *fp;

    fp = fopen("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", "r");
    if (fp != NULL) {
        fgets(line, 8, fp);
        line[7] = 0;
        fclose(fp);
        freq = atoi(line) / 1000;
    }
    return freq;
}


/* ========================================================================== */
// open thermal_zone0/temp and parse cpu temp values
double get_cputemp(void) {
    double temp = 0;
    char line[8];
    FILE *fp;

    fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (fp != NULL) {
        fgets(line, 6, fp);
        line[5] = 0;
        fclose(fp);
        temp = atoi(line);
        temp /= 1000;
    }
    return temp;
}

/* ========================================================================== */
// open /proc/meminfo and parse out memory usage values
int get_mempct(void) {
    long double memTotal, memFree, memAvailable, memBuffers, memCache;
    int memPct = 0;
    FILE *fp;

    fp = fopen("/proc/meminfo", "r");
    if (fp != NULL) {
        fscanf(fp, "MemTotal: %Lf %*s\n",     &memTotal);
        fscanf(fp, "MemFree: %Lf %*s\n",      &memFree);
        fscanf(fp, "MemAvailable: %Lf %*s\n", &memAvailable);
        fscanf(fp, "Buffers: %Lf %*s\n",      &memBuffers);
        fscanf(fp, "Cached: %Lf %*s\n",       &memCache);
        fclose(fp);
        //calculate the memory used as a percentage.
        //this calculation takes into account buffers and caches which linux
        //lists as "used" but are still available for applications to alloc.
        memPct = (int)((1.0 - ((memFree + memBuffers + memCache) / memTotal)) * 100.0);
        //printf("Mem Total: %Lf Free: %Lf Buff: %Lf Cache: %Lf\n", memTotal, memFree, memBuffers, memCache);
    }
    return memPct;
}


/* ========================================================================== */
int pifacecad_service(void) {

    //define bitmaps
    uint8_t thermo[]={0x4,0x4,0x4,0x4,0xe,0xe,0xe,0x0};
    uint8_t degree[]={0x18,0x18,0x3,0x4,0x4,0x4,0x3,0x0};
    uint8_t memory[]={0xe,0x1f,0xe,0x1f,0xe,0x1f,0xe,0x0};
    uint8_t  aleft[]={0x0,0x2,0x6,0xe,0x6,0x2,0x0,0x0};
    uint8_t aright[]={0x0,0x8,0xc,0xe,0xc,0x8,0x0,0x0};

    //Handle for file being parsed from /proc
    FILE *stat;

    //various variables used in parsing out statistics and calculating
    //display values
    long double user, nice, sys, idle, sum;
    long double lIdle = 0, lSum = 0;
    long double usage; 
    int pct = 0;

    //used memory
    int memPct = 0;

    //small buffer to build display strings
    char out[40];
    out[39] = 0;

    //ip-address
    int fd;
    struct ifreq ifr;

    //show display values and light
    int ncnt   = 0;
    int nLight = 0;
    int nView  = 1;

    //button result
    uint8_t input;
    
    //flag so that main loop knows when to shut down after catching a signal
    int run = 1;

    #ifndef LCDDEBUG
    //enable interrupts for buttons
    if (mcp23s17_enable_interrupts() == -1) {
        syslog(LOG_CRIT, "Could not enable interrupts.\n");
    } else {
        //call init_epoll  
        mcp23s17_wait_for_interrupt(1);
    }
    //init display
    int mcp23s17_fd = pifacecad_open();
    pifacecad_lcd_autoscroll_off();
    pifacecad_lcd_cursor_off();
    pifacecad_lcd_blink_off();
    pifacecad_lcd_store_custom_bitmap(0, thermo);
    pifacecad_lcd_store_custom_bitmap(1, degree);
    pifacecad_lcd_store_custom_bitmap(2, memory);
    pifacecad_lcd_store_custom_bitmap(3, aleft);
    pifacecad_lcd_store_custom_bitmap(4, aright);
    #endif


    syslog( LOG_NOTICE, "Daemon started ...\n");


    //loop until we're done
    while ( run ) {

        //open /proc/stat and parse cpu usage values
         if ( stat = fopen("/proc/stat", "r") ) {
            fscanf(stat, "cpu %Lf %Lf %Lf %Lf", &user, &nice, &sys, &idle);
            fclose(stat);
            //calculate cpu usage in percentage
            sum = user + nice + sys;
            usage = (sum - lSum) / (idle + sum - lIdle - lSum) * 100;
            //printf( "CPU user:%Lf nice:%Lf sys:%Lf idle:%Lf USAGE:%Lf\n", user, nice, sys, idle, usage);
            pct = (int)usage;
        }

        #ifndef LCDDEBUG
        pifacecad_lcd_clear();
        #endif

        /* === LCD row 1 ==================================================== */
        switch ( nView ) {
          case 1:
            //show ip-address
            fd = socket(AF_INET, SOCK_DGRAM, 0);
            if (fd > 0) {
                ifr.ifr_addr.sa_family = AF_INET;
                // I want IP address attached to "eth0" 
                strncpy(ifr.ifr_name, "eth0", IFNAMSIZ-1);
                ioctl(fd, SIOCGIFADDR, &ifr);
                close(fd);
            }
            sprintf(out, "%s", inet_ntoa(((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr));
            #ifndef LCDDEBUG
            pifacecad_lcd_write(out);
            #else
            printf("%s \n", out);
            #endif
            ncnt++;
            if ( ncnt > 2)
              nView = 0;
            break;
          case 2:
            // show version
            pifacecad_lcd_write("eis-ng ");
            if ( stat = fopen("/etc/alpine-release", "r") ) {
               fgets(out, 8, stat);
               fclose(stat);
               pifacecad_lcd_write(out);
            }
            nView = 0;
            break;
          case 9:
            //query shutdown
            pifacecad_lcd_write("Shutdown? ");
            pifacecad_lcd_write_custom_bitmap(3);
            pifacecad_lcd_write("Y  N");
            pifacecad_lcd_write_custom_bitmap(4);
            break;
          default:
            //show cpu temp
            sprintf(out, ":%3.1f", get_cputemp());
            #ifndef LCDDEBUG
            pifacecad_lcd_write_custom_bitmap(0);
            pifacecad_lcd_write(out);
            pifacecad_lcd_write_custom_bitmap(1);
            #else
            printf("Temp%s C  ", out);
            #endif
            //show used memory
            memPct = get_mempct();
            sprintf(out, ":%0*d%%", 2, memPct);
            #ifndef LCDDEBUG
            pifacecad_lcd_set_cursor(8, 0);
            pifacecad_lcd_write_custom_bitmap(2);
            pifacecad_lcd_write(out);
            #else
            printf("Mem%s  ", out);
            #endif
        }

        /* === LCD row 2 ==================================================== */
        // CPU using
        sprintf(out, "CPU:%i%%", pct);
        #ifndef LCDDEBUG
        pifacecad_lcd_set_cursor(0, 1);
        pifacecad_lcd_write(out);
        #else
        printf("%s  ", out);
        #endif
        //CPU speed
        sprintf(out, "%i MHz", get_cpufreq());
        #ifndef LCDDEBUG
        pifacecad_lcd_set_cursor(8, 1);
        pifacecad_lcd_write(out);
        #else
        printf("%s \n", out);
        #endif

        #ifndef LCDDEBUG
        if (pct > 30 || memPct > 50 || nLight == 1) {
            pifacecad_lcd_backlight_on();
        } else {
            pifacecad_lcd_backlight_off();
        }
        #endif

        lSum = sum;
        lIdle = idle;

        #ifndef LCDDEBUG
        if (mcp23s17_wait_for_interrupt(3000)) {
            input = mcp23s17_read_reg(GPIOA, 0, mcp23s17_fd);
            switch ( input ) {
            case 0xfe:
              //printf("Inputs: 01 (fe)\n", input);
              //Show ip-address
              nView = 1;
              ncnt  = 0;
              break;
            case 0xfd:
              //printf("Inputs: 02 (fd)\n", input);
              //Light on off
              nLight = !nLight;
              break;
            case 0xfb:
              //printf("Inputs: 03 (fb)\n", input);
              nView = 2;
              break;
            case 0xf7:
              //printf("Inputs: 04 (f7)\n", input);
              nView = 2;
              break;
            case 0xef:
              //printf("Inputs: 05 (ef)\n", input);
              nView = 2;
              break;
            case 0xbf:
              //printf("Inputs: links (bf)\n", input);
              //YES
              if ( nView == 9 ) {
                run = 0;
                system( "poweroff" );
              }
              break;
            case 0x7f:
              //printf("Inputs: rechts (7f)\n", input);
              //NO
              nView = 0;
              nLight = 0;
              break;
            case 0xdf:
              //printf("Inputs: Enter (df)\n", input);
              //Shutdown?
              nView = 9;
              nLight = 1;
              break;
            //default:
                //printf("\nInputs: 0x%x\n", input);
            }
            usleep(250000);
        }
        #else
        sleep(2);
        #endif
    }

    #ifndef LCDDEBUG
    mcp23s17_disable_interrupts();
    pifacecad_lcd_clear();
    pifacecad_lcd_backlight_off();
    pifacecad_close();
    #endif

    syslog( LOG_NOTICE, "closed.\n");
    closelog();

    return 0;
}


int main(int argc, char* argv[]) {
    pid_t pid;
    int i;
    
    pid = fork();
    if (pid < 0) {
        perror("unable to fork\n");
        return 1;
    }
    if (pid > 0) {
        // parent process, exit normally 
        // printf("forked input daemon\n");
        return 0;
    }
 
    if (!pid) {
        /* child process, should not return */
        if (setsid() < 0) 
            exit (EXIT_FAILURE);
        signal(SIGHUP, SIG_IGN);   
        if ((pid = fork ()) != 0)
            exit (EXIT_FAILURE); 
        chdir ("/"); 
        umask (0);
        for (i = sysconf (_SC_OPEN_MAX); i > 0; i--)
            close (i); 
        if (open("/dev/null",O_RDONLY) == -1) {
            perror("failed to reopen stdin while daemonising\n");
        } 
        if (open("/dev/null",O_WRONLY) == -1) {
            perror("failed to reopen stdout while daemonising\n");
        }
        if (open("/dev/null",O_RDWR) == -1) {
            perror("failed to reopen stderr while daemonising\n");
        }       
        openlog("picadstat", LOG_PID | LOG_PERROR | LOG_NDELAY, LOG_DAEMON);
        return pifacecad_service();
    }
}
