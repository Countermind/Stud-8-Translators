/**
 * lexer.ll
 *   flex-спецификация лексического анализатора простого языка.
 *
 */

%{
#if defined _WIN32
#include <io.h>			// Для isatty
#elif defined _WIN64
#include <io.h>			// Для isatty
#endif
#ifdef MSVC
#define  isatty _isatty		// В VC isatty назван _isatty
#endif
%}

%option nounistd
%%

        /* Пропускаются все пробельные символы.
           Аналогично будет выглядеть код для комментариев. */
[ \t\n]         { }      

        /* Целочисленные константы. */
0               { return _INTEGER; }
[1-9][0-9]*     { return _INTEGER; }

        /* Ключевые слова. */
begin           { return _BEGIN; }
end             { return _END; }

        /* Знаки пунктуации, пока здесь только точка с запятой. */
";"             { return _SEMI; }
"+"             { return _PLUSOP; }

        /* Идентификаторы. Это правило должно идти после, но ни в коем случае
         * до шаблона, представляющего то, что может быть идентификатором,
         * например, ключевые слова.
         */
[a-z][a-z0-9_]* { return _IDENTIFIER; }
.               { yyerror("Not in alphabet."); }
%%
int yywrap () { return 1; }