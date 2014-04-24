%{
/* Входная спецификация flex лексического анализатора для компилятора
   в трехадресный промежуточный код простых арифметических выражений,
   условных операторов if с обязательной частью else,
   операторов цикла с предусловием,
   операторов присваивания, а также вывода значений выражений.
   Разделитель операторов - символ новой строки.
   Имя переменной - нечувствительная к регистру латинская литера.
      
   Разработчик - Александр Кузнецов.
   Проект начат 15.10.2008,
          модифицирован 17.10.2008, 23.03.2013, 03.04.2013, 17.04.2013.
   Распространяется под лицензией zlib,
     см. http://www.gzip.org/zlib/zlib_license.html

   Для корректной компиляции исходного кода лексического анализатора
     необходима генерация заголовочного файла синтаксического анализатора,
     например:
   $ bison -d language.y -o language.tab.c

     с последующим его включением соответствующими директивами.
   Пример (см. также далее по тексту):
   #include "language.tab.h"
   
*/

#include <stdio.h>
#include <ctype.h>
#include "calc.h"
#include "language.tab.h"

#if defined _WIN32
#include <io.h>              // Для isatty
#elif defined _WIN64
#include <io.h>              // Для isatty
#endif

#ifdef MSVC
#define  isatty _isatty	      // В VC isatty назван _isatty
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
