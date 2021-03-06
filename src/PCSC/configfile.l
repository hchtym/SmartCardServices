/*****************************************************************

  File   :   configfile.ll
  Author :   David Corcoran
  Date   :   February 12, 1999 modified 7/28/99
  Purpose:   Reads lexical config files and updates database.
             See http://www.linuxnet.com for more information.
  License:   Copyright (C) 1999 David Corcoran
             <corcoran@linuxnet.com>

******************************************************************/

%{
int evaluatetoken(char *pcToken);

static int iLinenumber      = 1;
static char *pcPrevious     = 0;
static char *pcCurrent      = 0;
static char *pcFriendlyname = 0;
static char *pcDevicename   = 0;
static char *pcLibpath      = 0;
static char *pcChannelid    = 0;
static int   badError       = 0;

void tok_error(char *pcToken_error);

%}

%option nounput
%option noyywrap

%%

#.*                                       {}
"\n"                                      { iLinenumber++; }
(\"[^"\n]*["\n])|(\'[^'\n]*['\n])         { (void)evaluatetoken(yytext); }
[ \t]                                     {}
([A-Z]|[a-z]|[0-9]|[\\\/\-\.\_\@])+       { (void)evaluatetoken(yytext); }
.                                         { tok_error(yytext); }
%%

#include <stdio.h>
#include <string.h>
#include <wintypes.h>

#include "pcsclite.h"
#include "sys_generic.h"
#include "readerfactory.h"
#include "debuglog.h"

int evaluatetoken(char *pcToken)
{

	DWORD dwChannelId = 0;
	int p = 0;
	int n = 0;

	if (pcPrevious == NULL)
	{	/* This is the key */
		pcPrevious = strdup(pcToken);
	}
	else
	{
		pcCurrent = pcToken;
		if (strcmp(pcPrevious, "FRIENDLYNAME") == 0)
		{
			if (pcFriendlyname == NULL)
			{
				pcFriendlyname = malloc(strlen(pcCurrent) - 1);
				for (n = 0; n < strlen(pcCurrent); n++)
				{
					if (pcCurrent[n] != '"')
					{	/* Strip off the quotes */
						pcFriendlyname[p++] = pcCurrent[n];
					}
				}
				pcFriendlyname[p++] = '\0';
			}
			else
			{
				tok_error(pcPrevious);
				return 1;
			}
		}
		else if (strcmp(pcPrevious, "DEVICENAME") == 0)
		{
			if (pcDevicename == NULL)
			{
				pcDevicename = strdup(pcCurrent);
			}
			else
			{
				tok_error(pcPrevious);
				return 1;
			}
		}
		else if (strcmp(pcPrevious, "LIBPATH") == 0)
		{
			if (pcLibpath == NULL)
			{
				pcLibpath = strdup(pcCurrent);
			}
			else
			{
				tok_error(pcPrevious);
				return 1;
			}
		}
		else if (strcmp(pcPrevious, "CHANNELID") == 0)
		{
			if (pcChannelid == NULL)
				pcChannelid = strdup(pcCurrent);
			else
			{
				tok_error(pcPrevious);
				return 1;
			}
		}
		else
		{
			tok_error(pcPrevious);
			return 1;
		}

		free(pcPrevious);
		pcPrevious = NULL;
	}

	if (pcFriendlyname != NULL && pcDevicename != NULL &&
		pcLibpath != NULL && pcChannelid != NULL)
	{

		dwChannelId = strtoul(pcChannelid, 0, 16);
		RFAddReader(pcFriendlyname, dwChannelId, pcLibpath, pcDevicename);

		free(pcFriendlyname);
		free(pcDevicename);
		free(pcLibpath);
		free(pcChannelid);
		pcFriendlyname = NULL;
		pcDevicename = NULL;
		pcLibpath = NULL;
		pcChannelid = NULL;
	}

	return 0;
}

void tok_error (char *token_error)
{
	Log2(PCSC_LOG_ERROR, "tok_error: invalid value in " PCSCLITE_READER_CONFIG ": %s", token_error);
	badError = 1;
}

int DBUpdateReaders (const char *readerconf)
{
	FILE *configFile = NULL;

	configFile = fopen(readerconf, "r");

	if (configFile == NULL)
		return 1;

	yyin = configFile;

	do
	{
		(void)yylex();
	}
	while (!feof(configFile));

	(void)fclose(configFile);

	if (badError == 1)
		return -1;
	else
		return 0;
} /* End of configfile.c */

