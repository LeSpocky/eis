/*
 * utils.h
 *
 * Description:	Basic definitions and Function prototypes
 *
 */

#ifndef _UTILS_H
#define _UTILS_H 1

int file_read( int fd, void *buffer, size_t bufsize, int timeout, ssize_t *nread, int *errval );
int file_write( int fd, const void *buffer, size_t buflen, int timeout, ssize_t *nwritten, int *errval );
int file_signature_content(const char *fname);
int file_move(const char *oldfile, const char *newfile);
int file_save_local(const char *quarantinedir, const char *filename, const char *virus);
int chop( char* string ); 
u_int32_t get_file_size(const char *file_name);
void strtolower (char *str);

#endif /* UTILS */
