#include    <stdio.h>
#include    <string.h>
#include    <ctype.h> 
#include    <iconv.h>
#include    <sys/types.h>
#include    <unistd.h>
#include    "utf8function.h"

char *
native_to_utf8( const char *string ) {
    const byte *s;
    char *buffer;
    size_t length=0;
    iconv_t cd;
    const char *inptr;
    char *outptr;
    size_t inbytes, outbytes;

    cd = iconv_open ("utf-8", "iso-8859-1");

    if (cd == (iconv_t)-1){
        perror ("utf-8");
        return native_to_utf8 (string);
    }

    for (s = (const byte *)string; *s; s++ ) {
        length++;
        if ((*s & 0x80))
            length += 5; /* We may need up to 6 bytes for the utf8 output. */
    }
    buffer = malloc (length + 1);

    inptr = string;
    inbytes = strlen (string);
    outptr = buffer;
    outbytes = length;

    if (iconv(cd, (char **)&inptr, &inbytes, &outptr, &outbytes) == (size_t)-1) {
        /* We don't do any conversion at all but use the strings as is. */
        strcpy (buffer, string);
    } else {
        *outptr = 0;
    }
    iconv_close (cd);
    return buffer;
}

