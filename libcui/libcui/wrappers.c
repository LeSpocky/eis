/* ---------------------------------------------------------------------
 * File: wrappers.c
 * (unicode wrappers for often used library functions)
 *
 * Copyright (C) 2008
 * Daniel Vogel, <daniel_vogel@t-online.de>
 *
 * Last Update:  $Id: wrappers.c 33397 2013-04-02 20:48:05Z dv $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * ---------------------------------------------------------------------
 */

#include "cui-util.h"
#include "global.h"

FILE* FileOpen(const wchar_t *filename, const wchar_t *mode)
{
	char* mbfilename = TCharToMbDup(filename);
	char* mbmode = TCharToMbDup(mode);
	FILE* result = NULL;
	if (mbfilename && mbmode)
	{
		result = fopen(mbfilename, mbmode);
	}
	if (mbfilename)
	{
		free(mbfilename);
	}
	if (mbmode)
	{
		free(mbmode);
	}
	return result;
}

int FileStat(const wchar_t *path, struct stat *buf)
{
	char* mbpath = TCharToMbDup(path);
	int result = -1;
	if (mbpath)
	{
		result = stat(mbpath, buf);
		free(mbpath);
	}
	return result;
}

int FileAccess(const wchar_t *filename, int mode)
{
	char* mbfilename = TCharToMbDup(filename);
	int result = -1;
	if (mbfilename)
	{
		result = access(mbfilename, mode);
		free(mbfilename);
	}
	return result;
}

int FileRemove(const wchar_t *filename)
{
	char* mbfilename = TCharToMbDup(filename);
	int result = -1;
	if (mbfilename)
	{
		result = unlink(mbfilename);
		free(mbfilename);
	}
	return result;
}

DIR* OpenDirectory(const wchar_t *name)
{
	char* mbname = TCharToMbDup(name);
	DIR* result = NULL;
	if (mbname)
	{
		result = opendir(mbname);
		free(mbname);
	}
	return result;
}

int CreateDirectory(const wchar_t *name, mode_t mode)
{
	char* mbname = TCharToMbDup(name);
	int result = -1;
	if (mbname)
	{
		result = mkdir(mbname, mode);
		free(mbname);
	}
	return result;
}

int RemoveDirectory(const wchar_t *name)
{
	char* mbname = TCharToMbDup(name);
	int result = -1;
	if (mbname)
	{
		result = rmdir(mbname);
		free(mbname);
	}
	return result;
}

int ExecSysCmd(const wchar_t * cmd)
{
	char* mbcmd = TCharToMbDup(cmd);
	int result = -1;
	if (mbcmd)
	{
		result = system(mbcmd);
		free(mbcmd);
	}
	return result;
}

int RegCompile(regex_t *preg, const wchar_t *regex, int cflags)
{
	char* mbregex = TCharToMbDup(regex);
	int result = -1;
	if (mbregex)
	{
		result = regcomp(preg, mbregex, cflags);
		free(mbregex);
	}
	return result;
}

int RegExec(const regex_t *preg, const wchar_t *string, size_t nmatch, regmatch_t pmatch[], int eflags)
{
	char* mbstring = TCharToMbDup(string);
	int result = -1;
	if (mbstring)
	{
		result = regexec(preg, mbstring, nmatch, pmatch, eflags);
		free(mbstring);
	}
	return result;
}



