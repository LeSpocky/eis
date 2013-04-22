#define safe_malloc(x) str_safe_malloc(x, __FILE__, __FUNCTION__, __LINE__)
void *  str_safe_malloc(size_t size, const char * file, const char * function, int line);
char *  convert_to_upper (char * str);
char *  strsave (char * s);
char *  strcat_save (char * s, char * a);
char *  strsave_quoted (char * s);
char *  strsave_ws (char * s);
char *  get_set_var_name_int (char * s, int index, char * file, int line);
char *  get_set_var_name_string (char * s, char * index, char * file, int line);
char *  get_set_var_n_name (char * s);
int     multiple_idx (char * name);
char *  strip_multiple_indices (char * s);
char *  replace_set_var_indices (char * s);

unsigned long   convert_to_long (char * val, char * file, int line);
