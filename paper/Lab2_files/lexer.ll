/**
 * lexer.ll
 *   flex-������������ ������������ ����������� �������� �����.
 *
 */

%{
#if defined _WIN32
#include <io.h>			// ��� isatty
#elif defined _WIN64
#include <io.h>			// ��� isatty
#endif
#ifdef MSVC
#define  isatty _isatty		// � VC isatty ������ _isatty
#endif
%}

%option nounistd
%%

        /* ������������ ��� ���������� �������.
           ���������� ����� ��������� ��� ��� ������������. */
[ \t\n]         { }      

        /* ������������� ���������. */
0               { return _INTEGER; }
[1-9][0-9]*     { return _INTEGER; }

        /* �������� �����. */
begin           { return _BEGIN; }
end             { return _END; }

        /* ����� ����������, ���� ����� ������ ����� � �������. */
";"             { return _SEMI; }
"+"             { return _PLUSOP; }

        /* ��������������. ��� ������� ������ ���� �����, �� �� � ���� ������
         * �� �������, ��������������� ��, ��� ����� ���� ���������������,
         * ��������, �������� �����.
         */
[a-z][a-z0-9_]* { return _IDENTIFIER; }
.               { yyerror("Not in alphabet."); }
%%
int yywrap () { return 1; }