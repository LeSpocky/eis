/* ---------------------------------------------------------------------
 * File: coproc.c
 * (run co process)
 *
 * Copyright (C) 2004
 * Daniel Vogel, <daniel_vogel@t-online.de>
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

#include "global.h"
#include "cui-util.h"

#define MAX_CHARACTERS 512
#define MAX_TIMEOUT    60
#define DEFAULT_SHELL  "/bin/sh"

#define BUFSIZE         128

/* local prototypes */
static void sig_handler(int signr);
static void CoProcExecute(int* pipe1, int* pipe2, int* pipe3,
              const char* filename,
              char* const parameters[]);
static int  CoProcParentRead(int pid,
              int* pipe1, 
              int* pipe2, 
              int* pipe3,
              TextCall callback,
              void* instance,
              int* exitcode);
int CoProcReadLineBuffer(int* pipe, char* buffer, TextCall callback, int fd_type, void* instance);



/* ---------------------------------------------------------------------
 * RunCoProcess
 * Run a shell command as co-Process and deliver stdin and stderr
 * to the given callback routine.
 * The waiting loop is terminated when:
 * - both pipes have been closed by the coprocess.
 * - there is no activity over one of the pipes for one second and the
 *   coprocess has been terminated in the meantime.
 * - there is no activity over one of the pipes for more than 60 seconds.
 * ---------------------------------------------------------------------
 */
int
RunCoProcess(const wchar_t* filename,
             wchar_t* const parameters[],
             TextCall callback,
             void* instance,
             int* exitcode)
{
	int     pipe1[2], pipe2[2], pipe3[2];
	pid_t   pid;
	int     result = FALSE;

	char*   mbfilename = filename ? TCharToMbDup(filename) : NULL;
	if (mbfilename)
	{
		int    numparam = 0;
		char** p;
		while (parameters[numparam] != NULL)
		{
			numparam++;
		}

		p = (char**) malloc((numparam + 1) * sizeof(char*));
		if (p)
		{
			int n = 0;

			/* prepare parameters */
			for (n = 0; n < numparam; n++)
			{
				p[n] = TCharToMbDup(parameters[n]);
			}		
			p[n] = NULL;
		
			if (signal(SIGPIPE, sig_handler) == SIG_ERR) return FALSE;

			if (pipe(pipe1) < 0 || pipe(pipe2) < 0 || pipe(pipe3) < 0) return FALSE;

			if ((pid = fork()) == 0)
			{
				CoProcExecute(pipe1, pipe2, pipe3, mbfilename, p);
			}
			else if (pid > 0)
			{
				result = CoProcParentRead(pid, pipe1, pipe2, pipe3, 
					callback, instance, exitcode);
			}

			/* free parameters */
			for (n = 0; n < numparam; n++)
			{
				free(p[n]);
			}
			free(p);
		}
		free(mbfilename);
	}
	return result;
}


/* ---------------------------------------------------------------------
 * CoProcCreate
 * Run a shell command
 * ---------------------------------------------------------------------
 */
COPROC*
CoProcCreate(const wchar_t* cmd)
{
	int     pipe1[2], pipe2[2], pipe3[2];
	pid_t   pid;
	char*   pcmd;
	COPROC* coproc;

	if (signal(SIGPIPE, sig_handler) == SIG_ERR) 
	{
		return NULL;
	}

	if (pipe(pipe1) < 0 || pipe(pipe2) < 0 || pipe(pipe3) < 0) 
	{
		return NULL;
	}

	coproc = (COPROC*) malloc(sizeof(COPROC));
	coproc->Command = TCharToMbDup(cmd);
	coproc->Terminated = FALSE;
	coproc->ReadPos = 0;
	coproc->ReadSize = 0;
	coproc->ReadBuf = (char*) malloc(BUFSIZE * sizeof(char));

	pcmd = coproc->Command;

	if ((pid = fork()) < 0)
	{
		free(coproc->Command);
		free(coproc);
		return FALSE;
	}
	else if (pid > 0)
	{
		close(pipe1[0]);
		close(pipe2[1]);
		close(pipe3[1]);

		coproc->FdStdin = pipe1[1];
		coproc->FdStdout = pipe2[0];
		coproc->FdStderr = pipe3[0];
		coproc->Pid = pid;
		coproc->StdoutOpen = TRUE;
		coproc->StderrOpen = TRUE;
		return coproc;
	}
	else
	{
		char *	argv[4];
		
		if(!(argv[0] = getenv("SHELL")))
		{
			argv[0] = DEFAULT_SHELL;
		}
		argv[1] = NULL;

		if (cmd)
		{
			argv[1] = "-c";
			argv[2] = (char*) pcmd;
			argv[3] = NULL;
		}

		CoProcExecute(pipe1,pipe2,pipe3,argv[0],&argv[0]);
		return NULL;
	}
}

/* ---------------------------------------------------------------------
 * CoProcRead
 * Read data from shell running as a coprocess
 * ---------------------------------------------------------------------
 */
int
CoProcRead(COPROC* coproc, wchar_t *buf, int count)
{
	mbstate_t    state;
	const char*  p;
	int          c;
	int          result = 0;
	
	memset (&state, 0, sizeof(state));

	do
	{	
		if (coproc->ReadPos >= coproc->ReadSize)
		{
			struct timeval timer1;
			fd_set set;
			int    res;

			coproc->ReadPos = 0;
			coproc->ReadSize = 0;
			coproc->ReadBuf[0] = 0;

			if ((coproc->StderrOpen != FALSE) || (coproc->StdoutOpen != FALSE))
			{
				int fhnr = (coproc->FdStdout > coproc->FdStderr) ? 
				    coproc->FdStdout : coproc->FdStderr;

				timer1.tv_sec = 0;
				timer1.tv_usec = 100;

				FD_ZERO(&set);
				if (coproc->StdoutOpen)
				{
					FD_SET(coproc->FdStdout,&set);
				}
				if (coproc->StderrOpen)
				{
					FD_SET(coproc->FdStderr,&set);
				}

				res = select(fhnr + 1, &set, NULL, NULL, &timer1);
				if (res > 0)
				{
					if (FD_ISSET(coproc->FdStderr,&set))
					{
						int c = read(coproc->FdStderr, coproc->ReadBuf, BUFSIZE);
						if (c > 0)
						{
							coproc->ReadSize = c;
							coproc->ReadBuf[c] = 0;
						}
						else
						{
							coproc->StderrOpen = FALSE;
						}
					}
					if (FD_ISSET(coproc->FdStdout,&set))
					{
						int c = read(coproc->FdStdout, coproc->ReadBuf, BUFSIZE);
						if (c > 0)
						{
							coproc->ReadSize = c;
							coproc->ReadBuf[c] = 0;
						}
						else
						{
							coproc->StdoutOpen = FALSE;
						}
					}
				}
			}
		} 
		c = (coproc->ReadSize - coproc->ReadPos);
		p = &coproc->ReadBuf[coproc->ReadPos];

		if (c > 0)
		{
			int num;
			num = c;
			do
			{
				if (count > result)
				{
					int size = mbrtowc(buf, p, num, &state);
					if (size > 0)
					{
						buf++;
						result++;
						num -= size;
						p += size;
					}
					else if (size == -2)
					{
						break; /* character incompelte */
					}
					else
					{
						*(buf++) = L'?';
						result++;
						num--;
						p++;
					}
				}
				else
				{
					*(buf++) = 0;
					coproc->ReadPos += (c - num);
					return result;
				}
			}
			while (num > 0);
			coproc->ReadPos += c;
		}
	}
	while (c > 0);

	*(buf++) = 0;
	return result;
}


/* ---------------------------------------------------------------------
 * CoProcWrite
 * Write data to shell running as a coprocess
 * ---------------------------------------------------------------------
 */
int
CoProcWrite(COPROC* coproc, const wchar_t *buf, int count)
{
	mbstate_t       state;
	int             result = 0;
	const wchar_t*    p1     = buf;
	const wchar_t*    p2     = buf;
	char            cbuffer[128 + 1];
	
	memset (&state, 0, sizeof(state));

	while ((count > 0) && (p1 != NULL))
	{
		int num = (count < 128) ? count : 128;
		int size = wcsrtombs(cbuffer, &p2, num, &state);
		if (size > 0)
		{
			result += write(coproc->FdStdin, cbuffer, size);
		}
		else if (size < 0)
		{
			break; /* -> invalid unicode character encountered */
		}
		if (p2 != NULL)
		{
			count -= (p2 - p1);
		}
		p1 = p2;
	}
	return result;
}


/* ---------------------------------------------------------------------
 * CoProcDelete
 * Close an existing coprocess
 * ---------------------------------------------------------------------
 */
void
CoProcDelete(COPROC* coproc)
{
	if (!coproc) return;

	if (!coproc->Terminated)
	{
		int status;
		if (kill(coproc->Pid, SIGINT) != -1)
		{
			waitpid(coproc->Pid,&status,0);
		}
	}

	close(coproc->FdStdin);
	close(coproc->FdStdout);
	close(coproc->FdStderr);
	free(coproc->ReadBuf);
	free(coproc->Command);
	free(coproc);
}

/* ---------------------------------------------------------------------
 * CoProcIsRunning
 * Has the shell been closed?
 * ---------------------------------------------------------------------
 */
int
CoProcIsRunning(COPROC* coproc, int *exitcode)
{
	int status;
	if (!coproc) return FALSE;

	if (coproc->Terminated)
	{
		return FALSE;
	}

	if (waitpid(coproc->Pid,&status,WNOHANG) == coproc->Pid)
	{
		if (WIFEXITED(status)) 
		{
			coproc->Terminated = TRUE;
			if (exitcode)
			{
				*exitcode = status;
			}
			return FALSE;
		}
	}
	return TRUE;
}

/* helper functions */

/* ---------------------------------------------------------------------
 * sig_handler
 * A signal has been send to us
 * ---------------------------------------------------------------------
 */
static void sig_handler(int signr)
{
	switch(signr)
	{
	case SIGPIPE:
		printf(".......... caught SIGPIPE ............\n");
		exit(EXIT_FAILURE);
	case SIGINT:
		/* killpg(pid, SIGINT); */
		break;
	case SIGCHLD:
		break;
	}
}

/* ---------------------------------------------------------------------
 * CoProcExecute (internal)
 * Execute the shell command "filename" and redirect stdin and stderr
 * to the given pipes.
 * ---------------------------------------------------------------------
 */
void
CoProcExecute(int* pipe1, int* pipe2, int* pipe3, 
              const char* filename,
              char* const parameters[])
{
	close(pipe1[1]);
	close(pipe2[0]);
	close(pipe3[0]);
	if (pipe1[0] != STDIN_FILENO) 
	{
		dup2(pipe1[0], STDIN_FILENO);
		close(pipe1[0]);
	}
	if (pipe2[1] != STDOUT_FILENO) 
	{
		dup2(pipe2[1], STDOUT_FILENO);
		close(pipe2[1]);
	}
	if (pipe3[1] != STDERR_FILENO) 
	{
		dup2(pipe3[1], STDERR_FILENO);
		close(pipe3[1]);
	}
	if (access(filename, X_OK) != 0)
	{
		fprintf(stderr, "unable to execute '%s'!", filename);
		close(STDOUT_FILENO);
		close(STDERR_FILENO);
		close(STDIN_FILENO);
		exit(EXIT_FAILURE);
	}
	if (execv(filename, parameters) < 0) 
	{
		fprintf(stderr, "error upon execution of '%s'!", filename);
		close(STDOUT_FILENO);
		close(STDERR_FILENO);
		close(STDIN_FILENO);
		exit(EXIT_FAILURE);
	}
}

/* ---------------------------------------------------------------------
 * CoProcParentRead (internal)
 * parent process - read stdin and stderr from child process
 * ---------------------------------------------------------------------
 */
static int
CoProcParentRead(int pid,
             int* pipe1, 
             int* pipe2, 
             int* pipe3,
             TextCall callback,
             void* instance,
             int* exitcode)
{
	int     result = FALSE;
	int     status;
	fd_set  set;
	struct  timeval timer1;
	int     p2closed;
	int     p3closed;
	int     c = pipe3[0];
	int     timeout = MAX_TIMEOUT;

	char    stdin_buffer[MAX_CHARACTERS + 1];
	char    stderr_buffer[MAX_CHARACTERS + 1];

	stdin_buffer[0] = 0;
	stderr_buffer[0] = 0;

	close(pipe1[0]);
	close(pipe2[1]);
	close(pipe3[1]);

	if (pipe2[0] > c) 
		c = pipe2[0];

	p2closed = FALSE;
	p3closed = FALSE;
	do
	{
		int res;
		timer1.tv_sec = 1;
		timer1.tv_usec = 0;

		FD_ZERO(&set);
		if (!p2closed) FD_SET(pipe2[0],&set);
		if (!p3closed) FD_SET(pipe3[0],&set);

		res = select(c + 1,&set,NULL,NULL,&timer1);
		if (res > 0)
		{
			if (FD_ISSET(pipe2[0],&set))
			{
				if (!CoProcReadLineBuffer(pipe2, 
					stdin_buffer, 
					callback, 
					PIPE_STDOUT, 
					instance))
				{
					p2closed = TRUE;
				}
			}
			if (FD_ISSET(pipe3[0],&set))
			{
				if (!CoProcReadLineBuffer(
					pipe3, 
					stderr_buffer, 
					callback, 
					PIPE_STDERR, 
					instance))
				{
					p3closed = TRUE;
				}
			}
		}
		else if (res == 0)                            /* handle timeouts */
		{
			if (waitpid(pid,&status,WNOHANG) == pid)
			{
				if (WIFEXITED(status))
				{
					timeout = 0;
				}
				else
				{
					timeout--;
				}
			}
			else
			{
				timeout--;
			}
			if (timeout <= 0)
			{
				p2closed = TRUE;
				p3closed = TRUE;
			}
		}
		else                                             /* handle errors */
		{
			p2closed = TRUE;
			p3closed = TRUE;
		}
	}
	while (!p2closed || !p3closed);

	if (strlen(stdin_buffer) && (callback))
	{
		callback(stdin_buffer, PIPE_STDOUT, instance);
	}
	if (strlen(stderr_buffer) && (callback))
	{
		callback(stderr_buffer, PIPE_STDERR, instance);
	}

	close(pipe1[1]);
	close(pipe2[0]);
	close(pipe3[0]);

	waitpid(pid,&status,0);
	if (WIFEXITED(status))
	{
		if (exitcode) *exitcode = WEXITSTATUS(status);
		result = TRUE;
	}
	return result;
}

/* ---------------------------------------------------------------------
 * CoProcReadLineBuffer (internal)
 * Read data from given pipe and copy it to the line buffer. If a
 * newline character is found within the input stream, the line buffer
 * is passed to the callback routine for text output - the line
 * buffer is cleared afterwards
 * ---------------------------------------------------------------------
 */
int
CoProcReadLineBuffer(int* pipe, char* buffer, TextCall callback, int fd_type, void* instance)
{
	char  line[MAX_CHARACTERS+1];
	char* pos;
	char* oldpos;
	int   count;

	count = read(pipe[0],line,MAX_CHARACTERS);
	if (count > 0)
	{
		line[count] = 0;
		pos    = (char*) strchr(line,'\n');
		oldpos = (char*) line;
		while (pos)
		{
			*pos = 0;

			strcat(buffer, oldpos);
			if (callback)
			{
				callback(buffer, fd_type, instance);
			}
			buffer[0] = 0;

			pos++;
			oldpos = (char*) pos;
			pos    = (char*) strchr(pos,'\n');
		}
		if (oldpos && strlen(oldpos))
		{
			strcat(buffer,oldpos);
		}
		return TRUE;
	}
	return FALSE;
}

