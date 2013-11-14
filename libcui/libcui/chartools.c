#include "cui-util.h"
#include "global.h"
#include <iconv.h>

static const char *pStdCodec = "UTF-8";

#define SIZE_MAX 64535

int MbStrLen(const char* str)
{
	return mbsrtowcs(NULL, &str, SIZE_MAX, NULL);
}

int MbByteLen(const wchar_t* str)
{
	return wcsrtombs(NULL, &str, SIZE_MAX, NULL);
}

wchar_t* MbToTCharDup(const char*  str)
{
	int    len = MbStrLen(str);
	wchar_t* tstr = (wchar_t*) malloc((len + 1) * sizeof(wchar_t));
	if (tstr)
	{
		mbsrtowcs(tstr, &str, len + 1, NULL);
		return tstr;
	}
	return NULL;
}

char* TCharToMbDup(const wchar_t* str)
{
	int   len = MbByteLen(str);
	char* mbstr = (char*) malloc((len + 1) * sizeof(char));
	if (mbstr)
	{
		wcsrtombs(mbstr, &str, len + 1, NULL);	
		return mbstr;
	}
	return NULL;
}


/**************************************************************************//**
 **  Assign codec for converter routines implemented in this module
 **
 **  @param[in]  codec  pointer to codec struct
 **  @return     n/a
 *****************************************************************************/

void CuuSetStdCodec(const char *encoding)
{
	pStdCodec = encoding;
}

wchar_t *CuuToUtf16(wchar_t *buffer, const char *str, int bufsize)
{
	return CuuEncToUtf16(pStdCodec, buffer, str, bufsize);
}

wchar_t *CuuEncToUtf16(const char *encoding, wchar_t *buffer, const char *str, int bufsize)
{
	size_t      inlen;
	size_t      outlen;
	char       *in;
	char       *out;
	iconv_t     ic;

	ic     = iconv_open("UCS-4LE", encoding);
	if (ic != (iconv_t)-1)
	{
		in     = (char*) str;
		out    = (char*) buffer;
		inlen  = strlen(str) + 1;
		outlen = bufsize;
		
		buffer[0] = 0;
		
		iconv(ic, &in, &inlen, &out, &outlen);
		if (outlen >= sizeof(wchar_t))
		{
			*((wchar_t*)out) = 0;
		}
		iconv_close(ic);
	}
	return buffer;
}

char *CuuFromUtf16(char *buffer, const wchar_t *str, int bufsize)
{
	return CuuEncFromUtf16(pStdCodec, buffer, str, bufsize);
}

char *CuuEncFromUtf16(const char *encoding, char *buffer, const wchar_t *str, int bufsize)
{
	size_t      inlen;
	size_t      outlen;
	char       *in;
	char       *out;
	iconv_t     ic;

	ic     = iconv_open(encoding, "UCS-4LE");
	if (ic != (iconv_t)-1)
	{
		in     = (char*) str;
		out    = (char*) buffer;
		inlen  = (wcslen(str) + 1) * sizeof(wchar_t);
		outlen = bufsize;

		buffer[0] = 0;

		iconv(ic, &in, &inlen, &out, &outlen);
		if (outlen >= sizeof(char))
		{
			*((char*)out) = 0;
		}
		iconv_close(ic);
	}
	return buffer;
}

