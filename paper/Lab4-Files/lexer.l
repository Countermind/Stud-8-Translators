%{
/* ������� ������������ flex ������������ ����������� ��� �����������
   � ������������ ������������� ��� ������� �������������� ���������,
   �������� ���������� if � ������������ ������ else,
   ���������� ����� � ������������,
   ���������� ������������, � ����� ������ �������� ���������.
   ����������� ���������� - ������ ����� ������.
   ��� ���������� - ���������������� � �������� ��������� ������.
      
   ����������� - ��������� ��������.
   ������ ����� 15.10.2008,
          ������������� 17.10.2008, 23.03.2013, 03.04.2013, 17.04.2013.
   ���������������� ��� ��������� zlib,
     ��. http://www.gzip.org/zlib/zlib_license.html

   ��� ���������� ���������� ��������� ���� ������������ �����������
     ���������� ��������� ������������� ����� ��������������� �����������,
     ��������:
   $ bison -d language.y -o language.tab.c

     � ����������� ��� ���������� ���������������� �����������.
   ������ (��. ����� ����� �� ������):
   #include "language.tab.h"
   
*/

#include <stdio.h>
#include <ctype.h>
#include "calc.h"
#include "language.tab.h"

#if defined _WIN32
#include <io.h>              // ��� isatty
#elif defined _WIN64
#include <io.h>              // ��� isatty
#endif

#ifdef MSVC
#define  isatty _isatty	      // � VC isatty ������ _isatty
#endif

int yylex();

int lineno = 1;
%}

%option nounistd nodefault

first_part   [0-9]+(\.[0-9]*)?
second_part  [0-9]*\.[0-9]+
%%
if                  {
                        return IF_KEYWORD;
                    }
else                {
                        return ELSE_KEYWORD;
                    }
while               {
                        return WHILE_KEYWORD;
                    }
[a-zA-Z]            {
                        yylval.index_in_table = tolower (yytext[0]) - 'a';
                        return VARIABLE;
                    }
{first_part}|{second_part}        {
                        yylval.dval = atof (yytext);
                        return NUMBER;
                    }
[ \t]+              ;
<<EOF>>             {
                        yylval.other = yytext[0];
                        return EOFILE;
                    }
\n                  {
                        ++lineno;
                        return yylval.other = yytext[0];
                    }
.                   {
                        return yylval.other = yytext[0];
                    }
%%
int yywrap ()
{
    return 1;
}
