#include    <stdio.h>
#include    <string.h>
#include    <ctype.h> 
#include    <iconv.h>
#include    <sys/types.h>
#include    <unistd.h>
#include    "utf8function.h"


int
is_utf8( const char * string )
{
    if(!string)
        return 0;

    const unsigned char * bytes = (const unsigned char *)string;
    while(*bytes)
    {
        if( (// ASCII
             // use bytes[0] <= 0x7F to allow ASCII control characters
                bytes[0] == 0x09 ||
                bytes[0] == 0x0A ||
                bytes[0] == 0x0D ||
                (0x20 <= bytes[0] && bytes[0] <= 0x7E)
            )
        ) {
            bytes += 1;
            continue;
        }

        if( (// non-overlong 2-byte
                (0xC2 <= bytes[0] && bytes[0] <= 0xDF) &&
                (0x80 <= bytes[1] && bytes[1] <= 0xBF)
            )
        ) {
            bytes += 2;
            continue;
        }

        if( (// excluding overlongs
                bytes[0] == 0xE0 &&
                (0xA0 <= bytes[1] && bytes[1] <= 0xBF) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF)
            ) ||
            (// straight 3-byte
                ((0xE1 <= bytes[0] && bytes[0] <= 0xEC) ||
                    bytes[0] == 0xEE ||
                    bytes[0] == 0xEF) &&
                (0x80 <= bytes[1] && bytes[1] <= 0xBF) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF)
            ) ||
            (// excluding surrogates
                bytes[0] == 0xED &&
                (0x80 <= bytes[1] && bytes[1] <= 0x9F) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF)
            )
        ) {
            bytes += 3;
            continue;
        }

        if( (// planes 1-3
                bytes[0] == 0xF0 &&
                (0x90 <= bytes[1] && bytes[1] <= 0xBF) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF) &&
                (0x80 <= bytes[3] && bytes[3] <= 0xBF)
            ) ||
            (// planes 4-15
                (0xF1 <= bytes[0] && bytes[0] <= 0xF3) &&
                (0x80 <= bytes[1] && bytes[1] <= 0xBF) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF) &&
                (0x80 <= bytes[3] && bytes[3] <= 0xBF)
            ) ||
            (// plane 16
                bytes[0] == 0xF4 &&
                (0x80 <= bytes[1] && bytes[1] <= 0x8F) &&
                (0x80 <= bytes[2] && bytes[2] <= 0xBF) &&
                (0x80 <= bytes[3] && bytes[3] <= 0xBF)
            )
        ) {
            bytes += 4;
            continue;
        }

        return 0;
    }

    return 1;
}


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

