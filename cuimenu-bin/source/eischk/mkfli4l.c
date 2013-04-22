/*----------------------------------------------------------------------------
 *  mkfli4l.c   - create opt file list for fli4l
 *
 *  Compilation by Makefile (called by ../mkfloppy.sh)
 *
 *  Copyright (c) 2000-2001 Frank Meyer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Creation:       03.05.2000  fm
 *  Last Update:    $Id: mkfli4l.c 19177 2011-03-16 10:10:01Z jw5 $
 *----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdarg.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <glob.h>

#ifndef  GLOB_ABEND
# define GLOB_ABEND GLOB_ABORTED
#endif

#if defined(WIN32)
#  include "regex.h"
#else
#  include <regex.h>
#endif

#ifdef MALLOC_DEBUG
#include <mcheck.h>
#endif

#ifdef WINDOWS
#include <direct.h>
#else
#include <dirent.h>
#endif

#include <string.h>
#include "var.h"
#include "check.h"
#include "log.h"
#include "str.h"
#include "parse.h"
#include "cfg.h"
#include "options.h"
#include "mk_syslinux.h"
#include "array.h"

#define DEP_BUFFER_SIZE 4096

#define SUPERSEDES "_fli4l"

#define OPT_FORMAT_VERSION 1
#ifndef TRUE
# define TRUE               1
# define FALSE              0
#endif

#define OK                  0
#define ERR                 (-1)

#define BUF_SIZE            1024

#define MAX_PACKAGES    128

#define ZIP_ANY         -1
#define ZIP_NORM        1
#define ZIP_CONF        2
#define ZIP_ROOT        4
#define ZIP_ROOT_NORM   5
#define ZIP_ROOT_CONF   6

#if 0
static char * zip_types[] = {
    "0 ZIP_ANY      ",
    "1 ZIP_NORM     ",
    "2 ZIP_CONF     ",
    "3 unknown      ",
    "4 ZIP_ROOT     ",
    "5 ZIP_ROOT_NORM",
    "6 ZIP_ROOT_CONF"};
#endif
static char * get_location(int type)
{
  return type & ZIP_ROOT ? "root" : "opt ";
}

struct files_t {
    char * filename;
    char * opts;
    int    type;
};

struct alias_t {
    char * name;
    char * alias;
    int    used;
};

char *          packages[MAX_PACKAGES];
char *          p;
int             n_packages = 0;
static array_t  *files_array;
static array_t  *modules_array;
static array_t  *alias_array;
static int      kernel_2_6;
static int      quiet_add = 0;

static int      make_zip_list (char * kernel_version);
static void     check_external_opt (char * var, char * package);
static void     read_supersede_config (char * name);
static void     read_configuration_files (char * config_dir,
                                          char * check_dir,
                                          char * pkg, int mandatory);
static void     read_mkfli4l_config (char * config_dir, char * check_dir);
static void     read_config (char * config_dir, char * check_dir,
                             char ** packages);
static void     zip_list_init (void);
static int      zip_list_entry_exists (char * file, int offs, int type);
static struct files_t *  get_zip_list_entry (char * file, int offs);
static void     add_zip_list_entry (char * file, int type, char * opt, char * comment);
static int      do_glob (char * filename, glob_t * globres);
static void     dump_single_ziplist (void);
static void     dump_zip_lists (void);
static void     catch (int sig);
static int      is_match (char * var, char * value, char * file, int line);
static int      check_one_var (char * var, char * value, char * opt, char * filename, char * package, char * opt_file, int line);
static void read_modules_aliases(const char * kernel_version);
static void read_modul_alias_file(const char * kernel_version, const char * name);
static int dump_modules_aliases(const char * kernel_version);
static char * check_module_name (char * name);
static char * lookup_module(char * module);
static char * lookup_module_alias(char * alias);
static int read_modules_dep (char * kernel_version);
static int resolve_dependencies (char * kernel_version);
static int strcmp_mod (char * module, char * file);


int
get_file_name (char * fname, char * dir, char * name, char * ext)
{
    #define FNAME_BUFFER 128
    char buffer [FNAME_BUFFER];

    int len = strlen (name);

    if (len >= FNAME_BUFFER)
    {
        fatal_exit ("get_file_name: filename too long: '%s'\n", name);
    }
    strcpy (buffer, name);

    if (ext && *ext)
    {
        char * p = strrchr (buffer, '.');
        if (p)
        {
            *p = '\0';
        }
        sprintf (fname, "%s/%s%s", dir, buffer, ext);
    }
    else
    {
        sprintf (fname, "%s/%s", dir, buffer);
    }
    if (access (fname, R_OK))
    {
        return 0;
    }
    return 1;
}

void read_supersede_config (char * name)
{
    char        file[BUF_SIZE];

    if (get_file_name (file, config_dir, name, def_cfg_ext))
    {
        log_info (INFO, "reading supersede configuration file %s\n",
                  file);
        if (read_config_file (strsave (file), name, 1) != OK)
        {
            fatal_exit ("Error while reading config file %s\n", file);
        }
    }
    else
    {
        log_info (INFO, "ignoring non existing supersede config file %s\n", file);
    }
}

void
read_configuration_files (char * config_dir, char * check_dir,
                          char * pkg, int mandatory)
{
    char        file[BUF_SIZE];
    char *      p;

    if (n_packages == MAX_PACKAGES)
    {
        fatal_exit ("Error: Number of packages exceeded maximum of %d while processing %s!\n", MAX_PACKAGES, pkg);
    }

    if (! strcasecmp (pkg, "config.txt"))
    {
        fatal_exit ("Error: %s/%s is an old style config file."
                    " READ DOCUMENTATION!\n", config_dir, pkg);
    }

    log_info (INFO, "package %s\n", pkg);
    inc_log_indent_level ();

    if (get_file_name (file, config_dir, pkg, def_cfg_ext))
    {
        log_info (VERBOSE, "reading %s\n", file);
        if (read_config_file (strsave (file), pkg, 0) != OK)
        {
            fatal_exit ("Error while reading config file %s\n", file);
        }
        packages[n_packages] = strsave (pkg);
        p = strrchr (packages[n_packages], '.');
        if (p)
        {
            *p = '\0';
        }


        if (get_file_name (file, check_dir, pkg, def_regex_ext))
        {
            log_info (VERBOSE, "reading %s\n", file);
            if (regexp_read_file (strsave (file)) != OK)
            {
                fatal_exit ("An error found while reading regular "
                            "expressions for package %s, aborting...\n", pkg);
            }
        }
        else
        {
            log_info (VERBOSE, "no expression file for package %s\n", pkg);
        }

        if (get_file_name (file, check_dir, pkg, def_check_ext))
        {
            log_info (VERBOSE, "reading %s\n", file);
            if (read_check_file (file, packages[n_packages]) != OK)
            {
                fatal_exit ("An error found while executing checks "
                            "for package %s, aborting...\n", pkg);
            }
        }
        else
        {
            fatal_exit ("Error while accessing %s: %s",
                        file, strerror (errno));
        }
        n_packages++;
    }
    else
    {
        if (mandatory)
            fatal_exit ("Error while accessing %s: %s\n",
                        file, strerror (errno));
    }

    dec_log_indent_level ();
}
typedef struct { char * packet; int mandatory; } plist_t;
plist_t plist[] = {{ SUPERSEDES, 0 },
                   { "base", 1 },
                   { "dns_dhcp", 0 },
                   { 0, 0 }};

static int filter_config_file (const char * name)
{
    plist_t * p;
    for (p=plist; p->packet; p++)
        if (!strcmp(name, p->packet))
            return 1;
    return 0;
}


void
static read_preordered_configs(char * config_dir, char * check_dir)
{
    plist_t * p;
    for (p=plist+1; p->packet; p++)
        read_configuration_files (config_dir, check_dir,
                                  p->packet, p->mandatory);
}

void catch (int sig)
{
  abort();
}

void read_mkfli4l_config (char * config_dir, char * check_dir)
{
    DIR *           dirp;
    struct dirent * dp;
    int             len;

    var_add_weak_declaration ("base", "CONFIG_DIR", config_dir,
                              "internal variable", TYPE_UNKNOWN,
                              __FILE__, __LINE__, 0);
    set_variable ("base", "BASE", "yes", "predefined variable", 0, NULL, 0, 0);
    mark_var_tagged ("BASE");
    mark_var_checked ("BASE");

    read_supersede_config (SUPERSEDES);
    log_info (INFO, "# parse pre-ordered config files\n");
    read_preordered_configs(config_dir, check_dir);
    log_info (INFO, "# parse other config files\n");

    dirp = opendir (config_dir);

    if (! dirp)
    {
        fatal_exit ("Error opening config dir '%s': %s\n",
                    config_dir, strerror (errno));
    }

    while ((dp = readdir (dirp)) != (struct dirent *) NULL)
    {
        len = strlen (dp->d_name);

        if (len > 4 && ! strcasecmp (dp->d_name + len - 4, ".txt"))
        {
            dp->d_name[len-4] = '\0';
            if (! filter_config_file(dp->d_name))
                (void) read_configuration_files (config_dir, check_dir,
                                                 dp->d_name, 1);
        }
    }

    (void) closedir (dirp);
}
void
read_config (char * config_dir, char * check_dir, char ** packages)
{
    char            file[BUF_SIZE];
    int read_base_exp = 1;
    char ** p;

    for (p = packages; *p; p++)
    {
        if (!strcmp ("base", *p))
        {
            read_base_exp = 0;
        }
    }
    if (read_base_exp)
    {
        if (get_file_name (file, check_dir, "base", def_regex_ext))
        {
            log_info (VERBOSE, "reading %s\n", file);
            if (regexp_read_file (strsave (file)) != OK)
            {
                fatal_exit ("An error found while basic regular "
                            "expressions from %s/base.exp\n", check_dir);
            }
        }
        else
        {
            fatal_exit ("Missing basic regular expressions (%s/base.exp)\n",
                        check_dir);
        }
    }
    for (p = packages; *p; p++)
    {
        read_configuration_files (config_dir, check_dir, *p, 1);
    }
}

/*----------------------------------------------------------------------------
 *  main (int argc, char ** argv)
 *----------------------------------------------------------------------------
 */
int
main (int argc, char ** argv)
{
    int    error = 0;
    char * kernel_version;
    int    check_only = 0;
#ifdef MALLOC_DEBUG
    mtrace ();
#endif

    signal (SIGTERM, catch);
    signal (SIGINT, catch);

    get_options (argc, argv);
    open_logfile (logfile);

    var_init();
    check_init();
    regexp_init();
    zip_list_init();

    log_info (INFO, "reading configuration files\n\n");
    inc_log_indent_level ();

    set_variable ("base", "AUTO", "99", "predefined variable", 0, NULL, 0, 0);
    mark_var_tagged ("AUTO");
    mark_var_checked ("AUTO");

    if (! *opt_packages)
    {
        read_mkfli4l_config (config_dir, check_dir);
    }
    else
    {
        read_config (config_dir, check_dir, opt_packages);
        check_only = 1;
    }
    if (check_for_dangeling_extensions ())
    {
        fatal_exit ("Error in configuration, aborting...\n");
    }
    dec_log_indent_level ();
    log_info (INFO, "\nfinished reading configuration files\n");

    log_info (INFO, "checking variables\n");
    if (check_all_variables () != OK)
    {
        fatal_exit ("Error in configuration, aborting...\n");
    }

    if (check_variables () != OK)
    {
        fatal_exit ("Error in configuration or packet structure, aborting...\n");
    }

    if (is_mkfli4l && !check_only)
    {
        /* ignore package list if there is no KERNEL_VERSION defined */
        if ( (kernel_version = get_variable ("KERNEL_VERSION")) ) {

            const char  kernel_2_6_str[] = "2.6";
            kernel_2_6 = !strncmp(kernel_version, kernel_2_6_str,
                                  sizeof(kernel_2_6_str)-1);

            log_info (INFO, "generating zip list\n\n");
            inc_log_indent_level ();
            error = make_zip_list (kernel_version);
            dec_log_indent_level ();
            log_info (INFO, "\nfinished generating zip list\n");
        } else {
                fatal_exit ("undefined KERNEL_VERSION, "
                            "unable to generate of package list\n");
        }
    }

    if (execute_all_extended_checks (check_dir) != OK || error)
    {
        fatal_exit ("Error in configuration, aborting...\n");
    }

    if (is_mkfli4l && !check_only)
    {
        if (resolve_dependencies(kernel_version)) {
            fatal_exit ("unable to resolve dependecies\n");
        }

        dump_zip_lists ();

        if (dump_variables (rc_file, full_rc_file) != OK)
        {
            fatal_exit ("error while writing %s (error in variables)\n",
                        rc_file);
        }

#ifdef SKIP_SYSLINUX
        if (!access (syslinux_template_file, R_OK))
        {
#endif
            log_info (INFO, "generating syslinux.cfg...\n");
            inc_log_indent_level ();
            if (mk_syslinux (syslinux_template_file, syslinux_cfg_file) != OK)
            {
                fatal_exit ("Error building syslinux.cfg, aborting...\n");
            }
            dec_log_indent_level ();
            log_info (INFO, "\nfinished generating syslinux.cfg\n");
#ifdef SKIP_SYSLINUX
        } else {
            log_error ("-> skipping generation of syslinux.cfg due to missing template file\n");
        }
#endif
    }

    close_logfile (logfile);

    free_check_variables ();
    free_variables ();

    return (0);
} /* main (argc, argv) */

#define SIZE_ERR_BUFFER 256
int
is_match (char * var, char * value, char * file, int line)
{
    int res, invers = 0;
    char regexp[256];

    if (*value == '!')
    {
        value++;
        invers=1;
    }
    else if (*value && *value == '\\' && *(value+1) == '!')
        value++;

    strcpy(regexp, "^(");
    strcpy(regexp+2, value);
    strcat(regexp, ")$");
    res = regexp_user (var, regexp, 0, 0, 0, file, line);

    log_info (ZIPLIST_REGEXP, "'%s' %s '%s'\n", regexp,
              res == REG_NOMATCH ? "doesn't match" : "matches",
              var);

    return invers ? res : !res;
}

/*----------------------------------------------------------------------------
 *  make_zip_list (char * zip_list_file, char * version_file)
 *----------------------------------------------------------------------------
 */
static int
make_package_zip_list (char * opt_file, char * package)
{
    char *      opt_regexp = "OPT_REGEXP";
    char        err_buf[SIZE_ERR_BUFFER+1];
    char        buf[BUF_SIZE];
    char        var_name[BUF_SIZE];
    char        value[BUF_SIZE];
    char        filename[BUF_SIZE];
    FILE *      opt_fp;
    char *      p, *opt;
    char *      var;
    int         line;
    int         error = 0;
    int         version;
    int         i;

        opt_fp = fopen (opt_file, "r");

        if (! opt_fp)
        {
            fatal_exit ("Error opening opt file '%s': %s\n",
                        opt_file, strerror (errno));
        }

        log_info (INFO|ZIPLIST|ZIPLIST_SKIP, "reading %s\n",  opt_file);
        inc_log_indent_level ();

        line = 0;
        version=0;
        while (fgets (buf, sizeof(buf), opt_fp))
        {
            line ++;
            /* strip comments   */
            p = strchr (buf, '#');

            if (p)
            {
                *p = '\0';
            }

            for (p = buf; *p; p++)
            {
                if (*p != ' ' && *p != '\t')
                {
                    break;
                }
            }

            if (*p == '\0' || *p == '\r' || *p == '\n')
            {
                continue;
            }

            if (sscanf (p, "%s %s %s", var_name, value, filename) != 3)
            {
                fatal_exit ("%s: syntax error: %d '%s'\n",
                            opt_file, *p, p);
            }

            for (opt=p, i=0; i<3; i++)
            {
                while (*opt && !isspace(*opt++))
                    ;
                while (*opt && isspace(*opt))
                    opt++;
            }
            if (*opt)
            {
                p = opt + strlen(opt);
                while ((iscntrl(*(p-1)) || isspace(*(p-1))) && p>opt)
                    p--;
                *p = 0;
                if (*opt)
                {
                    char * err_msg;
                    regex_t * preg;
                    int res;

                    if (! regexp_get_expr(opt_regexp, &preg, &err_msg))
                    {
                        fatal_exit ("unknown regular expression %s, please provide a regular expression describing the option flags in opt/package.txt\n",
                                    opt_regexp);
                    }

                    res = regexec (preg, opt, 0, NULL, 0);
                    if (res)
                    {
                        regerror (res, preg, err_buf, SIZE_ERR_BUFFER);
                        log_info (VERBOSE, "regex error %d (%s) for opt flags '%s'\n",
                                  res, err_buf, opt);
                        log_error ("(%s:%d) wrong option value '%s', %s\n",
                                   opt_file, line, opt, err_msg);

                    }

                }
            }

#if 1
            if (!strcmp (var_name, "opt"))
            {
                /* handle old style opt/package.txt files */
                fatal_exit ("%s: wrong file format (2.0.x format), "
                            "please convert to 2.2.x format\n",
                            package);
            }
#else
            if (!strcmp (var_name, "opt"))
            {
                /* handle old style opt/package.txt files */
                strcpy (var_name, value);
                strcpy (value, "yes");
            }

            if (!strcmp (value, "gen"))
            {
                /* handle old style gen tag */
                strcpy (value, "yes");
            }
#endif

            if (!strcmp (var_name, "weak"))
            {
                /* add weak deklaration for variable if its not already
                   present or replace its content */
                if ( !strchr (value, '%'))
                {
                    if (! get_variable (convert_to_upper (value)))
                    {
                        var_add_weak_declaration (package,
                                                  convert_to_upper (value),
                                                  "undefined", NULL,
                                                  TYPE_UNKNOWN,
                                                  opt_file, line,
                                                  ZIPLIST);
                    }
                }
                else
                {
                    check_add_weak_declaration (package,
                                                convert_to_upper (value),
                                                "0", NULL,
                                                opt_file, line, ZIPLIST);
                }
                continue;
            }
            if (!strcmp (var_name, "opt_format_version"))
            {
                int v = atoi(value);
                if (v < OPT_FORMAT_VERSION)
                {
                    log_error ("%s: incompatible opt format found,"
                               " uses version %d, needs version %d\n",
                               package, v, OPT_FORMAT_VERSION);
                    error = ERR;
                }
                version=1;
                continue;
            }

            if (check_opt_files)
            {
                add_to_zip_list (var_name, "enabled by debug flag",
                                 filename, opt, opt_file, line);
                continue;
            }

            var = var_name;
            do {
                char * next_var = strchr (var, ',');
                if (next_var)
                {
                    *next_var++=0;
                }
                if (check_one_var (var, value, opt, filename, package,
                                   opt_file, line) != OK)
                    error = ERR;
                var = next_var;
            } while (var);
        }
        if (!version)
        {
            log_error ("%s: Unknown opt format found, needs version %d."
                       " If your fli4l router does not work correctly,"
                       " check the dev documentation or ask the author"
                       " of this opt.\n",
                       package, OPT_FORMAT_VERSION);
        }

        dec_log_indent_level ();
        fclose (opt_fp);

    return error;
} /* make_zip_list (zip_list_file) */

static int
handle_single_zip_list(char * name, char * postfix)
{
    char opt[BUF_SIZE];
    char tmp[BUF_SIZE];

    strcpy(tmp, name);
    if (postfix) {
      char *p = tmp + strlen(tmp);
      *p++='_';
      while (*postfix) {
        if (*postfix != '.') {
          *p++ = *postfix++;
        } else {
          *p++ = '_';
          postfix++;
        }
      }
      *p = 0;
    }

    if (get_file_name (opt, "opt", tmp, def_opt_ext))
      return make_package_zip_list (opt, name);

    /* If we end up here, the file we are supposed to open does not exist. If
     * postfix is 0, we are supposed to open a basic package file which should
     * be there, so lets complain about it.
     */
    if (!postfix) {
        log_error("Unable to open '%s'\n", opt);
        return 1;
    }
    return 0;
}
static int
make_zip_list (char * kernel_version)
{
    char        kernel_major[]   = "KERNEL_MAJOR";
    int         pkg_idx;
    int         error = 0;

    set_variable ("base", kernel_major, kernel_2_6 ? "2.6" : "2.4",
                  "predefined variable", 0, NULL, 0, 0);
    mark_var_tagged (kernel_major);
    mark_var_checked (kernel_major);

    read_modules_aliases (kernel_version);
    read_modules_dep (kernel_version);
    for (pkg_idx = 0; pkg_idx < n_packages; pkg_idx++)
    {
      error |= handle_single_zip_list(packages[pkg_idx], 0);
      error |= handle_single_zip_list(packages[pkg_idx],
                                      kernel_2_6 ? "2.6" : "2.4");
      error |= handle_single_zip_list(packages[pkg_idx], kernel_version);
    }
    return error;
}

int check_one_var (char * var, char * value, char * opt, char * filename, char * package, char * opt_file, int line)
{
    char        var_name[BUF_SIZE];
    char        var_name2[BUF_SIZE];
    int error = 0;
    strcpy (var_name, convert_to_upper (var));

    /* check whether it is a *_% variable */
    if ( !strchr (var_name, '%'))
    {
        /* no, it isn't; check whether we have to prefix it
           with OPT_ */
        var = get_variable (var_name);
        if (!var && !check_var_defined (var_name))
        {
            var = convert_to_upper (var_name);
            strcpy (var_name2, "OPT_");
            strcat (var_name2, var);
            var = get_variable (var_name2);
            if (!var && !check_var_defined (var_name2))
            {
                fatal_exit ("%s:%d: Access to undefined variable %s\n",
                            opt_file, line, var_name);
            }
            strcpy(var_name, var_name2);
        }

        if (is_var_tagged (var_name))
        {
            check_external_opt (var_name, package);
            mark_var_requested (var_name);
            if (is_match (var, value, opt_file, line))
            {
                if (add_to_zip_list (var_name, var, filename, opt,
                                     opt_file, line) != OK)
                    error = ERR;
                mark_var_copied (var_name);
            }
            else
            {
                log_info (ZIPLIST_SKIP, "- %-40s : %s:'%s' != '%s'\n",
                          filename, var_name, var, value);
            }
        }
        else
        {
            /* skip file, its either not a paket file which
               should always be copied if OPT_PACKAGE='yes' or
               the variable depends on some other variable
               which isn't set */

            if (!is_var_weak (var_name))
            {
                log_info (ZIPLIST_SKIP, "- %-40s %s "
                          "not active.\n",
                          filename, var_name);
            }
        }
    }
    else
    {
        char *  tmp_var;
        int     enabled;

        struct iter_t * iter;

        if (! (iter = init_set_var_iteration (var_name, check_get_opt_var(var_name), 0)))
            fatal_exit("%s:%d: Unable to get var_n for variable %s\n", opt_file, line, var_name);
        while ((tmp_var = get_next_set_var (iter, &enabled))) {
          if (get_variable(tmp_var))
              if (check_one_var (tmp_var, value, opt, filename, package,
                                 opt_file, line) != OK)
                  error = ERR;
        }
    }
    return error;
}
static void
check_external_opt (char * var, char * package)
{
    char *          p;
    p = get_variable_package (var);
    if (strcmp (p, "BASE") && strcmp (p, "_fli4l") && strcmp(p, package))
    {
        log_info (ZIPLIST, "external reference to '%s' ('%s') in '%s'\n",
                  var, p, package);
    }
}

struct files_t *  get_zip_list_entry (char * file, int offs)
{
    ARRAY_ITER(array_iter, files_array, p, struct files_t)
    {
        if (p->filename && *p->filename && ! strcmp (p->filename + offs, file))
        {
            return p;
        }
    }
    return 0;
}

int zip_list_entry_exists (char * file, int offs, int type)
{
    struct files_t *p = get_zip_list_entry (file, offs);

    if (p) {
        if ((p->type & ZIP_ROOT) || !(type & ZIP_ROOT))
        {
            return 1;
        }
    }
    return 0;
}

void zip_list_init (void)
{
    files_array = init_array (FILES_ARRAY_SIZE, sizeof(struct files_t));
}

void add_zip_list_entry (char * file, int type, char * opt, char * comment)
{
    struct files_t *p = get_zip_list_entry (file, 0);

    if (!p) {
        p = get_new_elem (files_array);
        p->filename = strsave(file);
        p->type = type;
        p->opts = strsave(opt);
        log_info(ZIPLIST, "+  %s: %-40s %s\n",
                 get_location(type), file, comment);
        return;
    }

    if ((type & ZIP_ROOT) && !(p->type & ZIP_ROOT)) {
        p->type |= ZIP_ROOT;
        log_info(ZIPLIST, "-> %s: %-40s %s\n",
                 get_location(type), file, comment);
        return;
    }

    if (! quiet_add) {
        log_info(ZIPLIST, "%%  %s: %-40s (%s)\n",
                 get_location(type), file, comment);
    }
}

int exec_glob (char * pref, char * filename, glob_t * globres);
int exec_glob (char * pref, char * filename, glob_t * globres)
{
    char buf[BUF_SIZE];
    int  res;

    sprintf (buf, "%s/%s", pref, filename);
    res = glob (buf, 0, 0, globres);
    if (res == GLOB_NOSPACE || res == GLOB_ABEND)
    {
        fatal_exit ("error %s running glob(%s)\n",
                    res == GLOB_NOSPACE ? "no space" : "aborted",
                    buf);
    }

#ifdef GLOB_NOMATCH
    return res;
#else
    return res || 0 == globres->gl_pathc;
#endif
}

int do_glob (char * filename, glob_t * globres)
{
    if (! exec_glob (config_dir, filename, globres))
    {
        return ZIP_CONF;
    }

    if (! exec_glob ("opt", filename, globres))
    {
        return ZIP_NORM;
    }

    return -1;
}
/*----------------------------------------------------------------------------
 *  add_to_zip_list (FILE * fp, char * filename)
 *----------------------------------------------------------------------------
 */
int
add_to_zip_list (char * var, char * content, char * filename, char * opt, char *opt_file, int line)
{
    char         tmp[BUF_SIZE];
    int          type;
    int          res;
    int          i;
    const char * needle = "$KERNELVERSION$";
    const char rootfs_prefix[] = "rootfs:";
    char * p;

    glob_t glob_res;

    if (!strncmp (filename, rootfs_prefix, sizeof(rootfs_prefix)-1))
    {
        filename += sizeof(rootfs_prefix)-1;
        type = ZIP_ROOT_NORM;
    }
    else
    {
        type = ZIP_NORM;
    }

    p = strstr (filename, needle);
    if (p)
    {
        strncpy(tmp, filename, p-filename);
        strcpy(tmp+(p-filename), "${KERNEL_VERSION}");
        strcat(tmp, p+strlen(needle));
        filename=tmp;
    }

    filename = parse_rewrite_string (filename, opt_file, line);

    if ( (res = do_glob (filename, &glob_res)) < 0)
    {
        if (kernel_2_6)
        {
            int len = strlen(filename);
            if (len > 2 &&
                filename[len - 2] == '.' && filename[len - 1] == 'o')
            {
                strcpy(tmp, filename);
                strcpy(tmp + len - 2, ".ko");
                filename = tmp;
                res = do_glob (filename, &glob_res);
            }
        }
        if (res < 0)
        {
            char * module = check_module_name(filename);
            if (! module) {
                log_error ("Can't access '%s'\n", filename);
                return (ERR);
            }
            sprintf (tmp, "files%s", module);
            res = do_glob (tmp, &glob_res);
        }
    }

    if (res < 0)
    {
        log_error ("Can't access '%s'\n", filename);
        return (ERR);
    }

    if (res == ZIP_CONF)
    {
        log_info (INFO, "#  using %s/%s instead of normal version\n",
                  config_dir, filename);
        if (type == ZIP_NORM)
        {
            type = ZIP_CONF;
        }
        else
        {
            type = ZIP_ROOT_CONF;
        }
    }

    for (i=0; i< glob_res.gl_pathc; i++)
    {
        char * name = glob_res.gl_pathv[i];

        if (res == ZIP_CONF)
            name += strlen(config_dir);

        if (strchr(name, ' ')) {
            if (strcmp(name, filename))
                log_error("Invalid character in filename '%s' added via '%s' - spaces are not allowed\n",
                          name, filename);
            else
                log_error("Invalid character in filename '%s  - spaces are not allowed'\n",
                          name);
            return (ERR);
        }
        snprintf(tmp, sizeof(tmp)-1, "(%s='%s' %s:%d)",
                 var, content, opt_file, line);
        add_zip_list_entry (glob_res.gl_pathv[i], type, opt, tmp);
    }
    if (!is_var_tagged (var) && !check_opt_files)
    {
        log_error ("(%s='%s') not flagged, but file copied\n", var, content);
    }

    globfree (&glob_res);

    return 0;
} /* add_to_zip_list (fp, filename) */

static inline char * remove_one_prefix (char * name, char * prefix, int len)
{
    if (!strncmp (name, prefix, len))
        name += len;
    while (*name == '/')
        name++;
    return name;
}

static char * remove_prefix (char * name)
{
    char opt_prefix[] = "opt";
    char files_prefix[] = "files";
    name = remove_one_prefix (name, config_dir, config_dir_len);
    name = remove_one_prefix (name, opt_prefix, sizeof(opt_prefix)-1);
    name = remove_one_prefix (name, files_prefix, sizeof(files_prefix)-1);
    return name;
}
static int fn_compare (const void * name1, const void * name2);
static int fn_compare (const void * name1, const void * name2)
{
    return strcmp (remove_prefix(((struct files_t *)name1)->filename),
                   remove_prefix(((struct files_t *)name2)->filename));

}

#define MAX_NAME 1023
void dump_single_ziplist (void)
{
    char name[MAX_NAME+1];
    char * prefix, * archive;
    FILE * fp;

    DECLARE_ARRAY_ITER(array_iter, f, struct files_t);

    snprintf (name, MAX_NAME, "%s/opt_full.tmp", scratch_dir);
    fp = fopen (name, "wb");
    if (!fp)
    {
        fatal_exit ("Error opening zip list '%s': %s\n",
                    name, strerror (errno));
    }

    ARRAY_ITER_LOOP(array_iter, files_array, f)
    {
        if (!*f->filename)
          continue;

        switch (f->type)
        {
        case ZIP_NORM:
            archive="opt.tar";
            prefix="opt";
            break;
        case ZIP_CONF:
            archive="opt.tar";
            prefix=config_dir;
            break;
        case ZIP_ROOT_NORM:
            archive="rootfs.tar";
            prefix="opt";
            break;
        case ZIP_ROOT_CONF:
            archive="rootfs.tar";
            prefix=config_dir;
            break;
        default:
            fatal_exit("unknown archive type %d for '%s'\n",
                        f->type, f->filename);
        }
        fprintf(fp, "file='%s' archive=%s%s%s\n",
                f->filename, archive,
                f->opts ? " " : "", f->opts ? f->opts : "");
    }
    fclose(fp);
}

static void
add_directories(void)
{
    #define BUFFSIZE 4095
    char dir[BUFFSIZE+1];
    char * d;

    ARRAY_ITER(array_iter, files_array, first, struct files_t) {
        strncpy(dir, first->filename, BUFFSIZE);
        dir[BUFFSIZE]=0;

        d = dir + strlen(dir);
        while (d > dir) {
            if (*d == '/' || *d == '\\') {
                *d = 0;
                if (!strcmp (dir, config_dir))
                    break;
                add_zip_list_entry(dir, ZIP_ROOT_NORM, 0, "");
            }
            d--;
        }
        first++;
    }
}

static void
remove_duplicate_entries(void)
{
    char *p;

    ARRAY_ITER(array_iter, files_array, first, struct files_t) {
        array_iterator_t a;
        struct files_t * f;

        if (!*first->filename)
            continue;

        p = remove_prefix(first->filename);
        if (!*p) {
            log_info(ZIPLIST, "- '%s'\n", first->filename);
            *first->filename = 0;
            continue;
        }

        dup_array_iterator(&array_iter, &a);
        (void)get_next_elem(&a);
        while ( (f=get_next_elem(&a)) ) {
            if (!strcmp (p, remove_prefix(f->filename))) {
                log_info(ZIPLIST, "deleting '%s', keeping '%s'\n",
                         first->type & ZIP_ROOT ? first->filename : f->filename,
                         ! first->type & ZIP_ROOT ? first->filename : f->filename);
                if (first->type & ZIP_ROOT) {
                    *f->filename = 0;
                }
                else {
                    *first->filename = 0;
                    break;
                }
            }
        }
    }
}
static void
dump_zip_lists (void)
{
    struct files_t * first = get_first_elem(files_array);
    struct files_t * last = get_last_elem(files_array);

    if (!first)
        return;

    qsort (first, last - first + 1, sizeof (*first), fn_compare);

    log_info (INFO|ZIPLIST, "adding missing directories\n");
    quiet_add = 1;
    inc_log_indent_level ();
    add_directories();
    dec_log_indent_level ();

    first = get_first_elem(files_array);
    last = get_last_elem(files_array);
    qsort (first, last - first + 1, sizeof (*first), fn_compare);

    log_info (INFO|ZIPLIST, "removing duplicate entries\n");
    inc_log_indent_level ();
    remove_duplicate_entries ();
    dec_log_indent_level ();
    dump_single_ziplist();
}
static char mod_prefix[] = "opt/files";

static int resolve_dependency (char * module, int type, char * deps,
                               FILE * mdep)
{
    char name [1024];
    char * dep;
    int header = 1;
    int ret = 0;

    while (*deps) {
        if (!isspace(*deps)) {
            char orig;

            dep = deps;
            while (*deps && !isspace(*deps))
                deps++;

            orig = *deps;
            *deps = 0;

            if (! zip_list_entry_exists(dep, sizeof(mod_prefix)-1, type)) {
                ret = 1;
                if (mdep) {
                    log_error("unresolved dependency  %s -> %s\n",
                              module, dep);
                }
                if (header) {
                    log_info(LOG_DEP,"%s:\n", module);
                    inc_log_indent_level ();
                    header = 0;
                }
                sprintf(name, "%s%s", mod_prefix, dep);
                add_zip_list_entry (name, type, "", "");
                if (! zip_list_entry_exists(dep, sizeof(mod_prefix)-1, type)) {
                  log_info (LOG_DEP,"failed to add '%s' ('%s')\n", dep, name);
                }
            }
            else {
                if (mdep) {
                    fprintf(mdep, " %s", dep);
                }
                else {
                    if (header) {
                        inc_log_indent_level ();
                        header = 0;
                    }
                }
            }
            *deps = orig;
        }
        else
            deps++;
    }

    if (!header)
        dec_log_indent_level ();

    return ret;
}

static char * my_fgets (char *buffer, int size, FILE *f)
{
    int off = 0;
    while (fgets(buffer + off, size - off, f) != NULL) {
        char * end = buffer + strlen(buffer);
        while (end > buffer && ((isspace(*(end-1)) || iscntrl(*(end-1)))))
            end--;
        *end = 0;

        if (*(end - 1) != '\\')
            return buffer;

        off = end - buffer - 1;
    }
    return 0;
}

static int read_modules_dep (char * kernel_version)
{
    char buffer [DEP_BUFFER_SIZE];
    FILE *f;

    modules_array = init_array (FILES_ARRAY_SIZE, sizeof(char *));

    sprintf(buffer, "opt/files/lib/modules/%s/modules.dep", kernel_version);
    f = fopen(buffer, "r");
    if (!f) {
        log_error("unable to open %s, ignoring depdendencies\n", buffer);
        return 0;
    }

    while (my_fgets(buffer, sizeof(buffer)-1, f) != NULL) {
        char * end = strchr(buffer, ':');
        if (end) {
            char ** entry = get_new_elem (modules_array);
            *end = 0;
            *entry = strsave(buffer);
        }
    }
    fclose(f);
    return 0;
}

static void read_modul_alias_file(const char * kernel_version, const char * name)
{
    char buffer [1024];
    FILE *f;

    sprintf(buffer, "opt/files/lib/modules/%s/%s",
            kernel_version, name);
    f = fopen(buffer, "r");
    if (!f) {
        log_error("unable to open %s, ignoring aliases\n", buffer);
        return;
    }

    while (my_fgets(buffer, sizeof(buffer)-1, f) != NULL) {
        char name[1024];
        char alias[1024];
        int num = sscanf(buffer, "alias %s %s", alias, name);
        if (num == 2) {
            struct alias_t * entry = get_new_elem (alias_array);
            *entry = (struct alias_t){strsave(name), strsave(alias), 0};
        }
    }
    fclose(f);
}

static void read_modules_aliases(const char * kernel_version)
{

    alias_array = init_array (FILES_ARRAY_SIZE, sizeof(struct alias_t));

    if (kernel_2_6) {
      read_modul_alias_file(kernel_version, "modules.alias");
      read_modul_alias_file(kernel_version, "modules.symbols");
    }
}

static int dump_modules_aliases(const char * kernel_version)
{
    FILE *f;

    char * expr = ".*/lib/modules/.*/([^/.]+)(\\_target)?\\.ko$";
    regex_t reg;
    regmatch_t match[2];
    char err_buf[128];
    int res;

    DECLARE_ARRAY_ITER(files_array_iter, file, struct files_t);
    DECLARE_ARRAY_ITER(alias_array_iter, alias, struct alias_t);

    if (! kernel_2_6)
        return 0;

    res = regcomp (&reg, expr, REG_EXTENDED);
    if (res != 0)
    {
        regerror (res, &reg, err_buf, sizeof(err_buf) - 1);
        fatal_exit ("regex error %d (%s) in %s:%d\n",
                    res, err_buf, __FILE__, __LINE__);
    }

    f = fopen(modules_alias_file, "w");
    if (!f) {
        fatal_exit("unable to open '%s'\n", modules_alias_file);
        return 0;
    }

    ARRAY_ITER_LOOP(files_array_iter, files_array, file)
    {
        if (regexec(&reg, file->filename, sizeof(match)/sizeof(regmatch_t), match,
                    0) == 0)
        {
            char * name = file->filename + match[1].rm_so;
            char * end = file->filename + match[1].rm_eo;
            char c = *end;
            *end = '\0';
            ARRAY_ITER_LOOP(alias_array_iter, alias_array, alias)
            {
                if (!strcmp_mod (alias->name, name) ||
                    !strcmp_mod (alias->alias, name)) {
                    alias->used = 1;
                }
            }
            *end = c;
        }
    }

    ARRAY_ITER_LOOP(alias_array_iter, alias_array, alias)
    {
        if (alias->used)
            fprintf(f, "alias %s %s\n", alias->alias, alias->name);
    }

    regfree(&reg);
    fclose(f);
    return 0;
}

static int strcmp_mod (char * module, char * file)
{
    for( ; *module && *file; module++, file++) {
        if (*file != *module) {
            if ( (*file   != '-' && *file   != '_') ||
                 (*module != '-' && *module != '_') )
                return 1;
        }
    }
    /* ignore .o and .ko extension */
    if (*file && strcmp(file, ".o") && strcmp(file, ".ko"))
        return 1;
    if (*module && strcmp(module, ".o") && strcmp(module, ".ko"))
        return 1;

    return 0;
}

static char * lookup_module_alias(char * alias)
{
    ARRAY_ITER(array_iter, alias_array, a, struct alias_t)
    {
        if (!strcmp_mod (a->alias, alias)) {
            return a->name;
        }
    }
    return 0;
}

static char * lookup_module(char * module)
{
    int dist = strlen(module) + (kernel_2_6 ? 3 : 2);

    ARRAY_ITER(array_iter, modules_array, m, char *)
    {
        char * file = *m;
        int len = strlen (file);

        if (dist < len) {
            file += len - dist - 1;
            if (*file == '/' && !strcmp_mod (module, file + 1))
                return *m;
        }
    }
    return 0;
}

static int module_aliased (char * name)
{
    int ret = 0;
    char * dot = strrchr (name, '.');
    if (dot) {
        char * slash = strrchr (name, '/');
        if (slash)
            name = slash + 1;

        *dot = '\0';
        ret = lookup_module_alias (name) != 0;
        *dot = '.';
    }
    return ret;
}

static char * check_module_name (char * name)
{
    char * module = 0;
    char target[] = "_target";
    char *p, *q;

    int len = strlen(name);
    if (len > 2 &&
        name[len - 2] == '.' && name[len - 1] == 'o')
        name[len - 2] = 0;
    if (len > 3 &&
        name[len - 3] == '.' && name[len - 2] == 'k'
        && name[len - 1] == 'o')
        name[len - 3] = 0;

    module = lookup_module (name);
    if (module) {
        log_info (LOG_DEP, "#  using %s for %s\n", module, name);
        return module;
    }

    module = lookup_module_alias (name);
    if (module) {
        log_info (LOG_DEP, "#  trying to use %s instead of aliased %s\n", module, name);
        name = module;

        module = lookup_module (name);
        if (module) {
            log_info (LOG_DEP, "#      using %s\n", module);
            return module;
        }
    }

    /* try to handle original kernel tarballs with upper case letters */

    q = strchr(name, '_');
    p = strstr(name, target);
    if (p && q) {
        char * new_name = strsave(name);
        q = strchr(new_name, '_')+1;
        p = strstr(new_name, target);
        *p = 0;
        while (*q)
            *q++ -= 0x20;
        strcpy(p, p + sizeof(target)-1);
        module = check_module_name(new_name);
        free(new_name);
    }
    return module;
}
static int resolve_dependencies (char * kernel_version)
{
    char buffer [DEP_BUFFER_SIZE];
    FILE *f, *mdep;
    int pass;
    int ret = 0;

    log_info (INFO|LOG_DEP, "resolving open dependencies\n");
    inc_log_indent_level ();

    sprintf(buffer, "opt/files/lib/modules/%s/modules.dep", kernel_version);
    f = fopen(buffer, "r");
    if (!f) {
      log_error("unable to open %s, ignoring depdendencies\n", buffer);
      goto out;
    }

    mdep = fopen(modules_dep_file, "w");
    if (!mdep) {
        goto out_dep;
        log_error("unable to open %s, ignoring dependencies\n",
                  modules_dep_file);
        return 0;
    }

    for (pass = 1; pass <= 2;) {
        int module_added = 0;
        while (my_fgets(buffer, sizeof(buffer)-1, f) != NULL) {
            char * end = strchr(buffer, ':');
            if (end) {
                struct files_t *f;

                *end++ = 0;
                if ((f = get_zip_list_entry(buffer, sizeof(mod_prefix)-1))) {
                    if (pass == 1) {
                        module_added |= resolve_dependency(buffer, f->type, end, 0);
                    }
                    else {
                        fprintf(mdep, "%s:", buffer);
                        ret |= resolve_dependency(buffer, f->type, end, mdep);
                        fputc('\n', mdep);
                    }
                }
                else {
                    if (pass != 1 && module_aliased(buffer))
                        fprintf(mdep, "%s:\n", buffer);
                }
            }
        }
        rewind(f);

        if (!module_added)
            pass++;
    }
    fclose(mdep);
    dump_modules_aliases(kernel_version);

out_dep:
    fclose(f);
out:
    dec_log_indent_level ();
    return ret;
}

/* Local Variables: */
/* mode:c           */
/* c-basic-offset: 4 */
/* End:             */
