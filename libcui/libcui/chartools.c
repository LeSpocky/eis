#include "cui-util.h"
#include "global.h"

#define SIZE_MAX 64535

int MbStrLen(const char* str)
{
#ifdef _UNICODE
	return mbsrtowcs(NULL, &str, SIZE_MAX, NULL);
#else
	return strlen(str);
#endif
}

int MbByteLen(const TCHAR* str)
{
#ifdef _UNICODE
	return wcsrtombs(NULL, &str, SIZE_MAX, NULL);	
#else
	return strlen(str);
#endif
}

TCHAR* MbToTCharDup(const char*  str)
{
	int    len = MbStrLen(str);
	TCHAR* tstr = (TCHAR*) malloc((len + 1) * sizeof(TCHAR));
	if (tstr)
	{
#ifdef _UNICODE
		mbsrtowcs(tstr, &str, len + 1, NULL);
#else
		strncpy(tstr, str, len + 1);
#endif
		return tstr;
	}
	return NULL;
}

char* TCharToMbDup(const TCHAR* str)
{
	int   len = MbByteLen(str);
	char* mbstr = (char*) malloc((len + 1) * sizeof(char));
	if (mbstr)
	{
#ifdef _UNICODE
		wcsrtombs(mbstr, &str, len + 1, NULL);	
#else
		strncpy(mbstr, str, len + 1);
#endif
		return mbstr;
	}
	return NULL;
}


