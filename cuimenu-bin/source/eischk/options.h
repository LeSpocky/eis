extern  char *  config_dir;
extern  int     config_dir_len;
extern  char *  check_dir;
extern  char *  def_cfg_ext;
extern  char *  def_regex_ext;
extern  char *  def_opt_ext;
extern  char *  def_check_ext;
extern  char *  def_extcheck_ext;
extern  char *  opt_packages [20];
extern  char *  opt_file;
extern  char    rc_file[];
extern  char    full_rc_file[];
extern  char *  logfile;
extern  char    syslinux_template_file[];
extern  char    syslinux_menu_file[];
extern  char    modules_dep_file[];
extern  char    modules_alias_file[];
extern  char *  modules_dep_name;
extern  char *  modules_alias_name;
extern  char    syslinux_cfg_file[];
extern  int     is_mkfli4l;

extern char * build_dir;
extern char * scratch_dir;
extern char * distrib;
extern char * img;

extern int check_opt_files;
extern int is_mkfli4l;
extern int strong_consistency;


int get_options (int argc, char ** argv);
