%{
/* Входная спецификация bison для компилятора в трехадресный промежуточный код
     простых арифметических выражений,
     условных операторов if с обязательной частью else,
     операторов цикла с предусловием,
     операторов присваивания, а также вывода значений выражений.
   Пустой оператор недопустим.
   Разделитель операторов - символ новой строки.
   Имя переменной - нечувствительная к регистру латинская литера.
      
   Распространяется под лицензией zlib,
     см. http://www.gzip.org/zlib/zlib_license.html

   Разработчик - Александр Кузнецов.
   Проект начат 15.10.2008,
          модифицирован 17.10.2008, 23.03.2013, 03.04.2013, 17.04.2013.

   Обязательна генерация заголовочного файла синтаксического анализатора.
   Пример:
   $ bison -d language.y -o language.tab.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "calc.h"     /* описание структуры синтаксического дерева */


int g_tmpvar_upper_index = 0;

/* размер временной строки не изменяется*/
#define TMP_STRING_MAX_SIZE 64

#define ADDITION_OPERATOR       1
#define SUBTRACTION_OPERATOR    2
#define MULTIPLICATION_OPERATOR 3
#define DIVISION_OPERATOR       4

#define NEGATION_OPERATOR       5
#define UNPLUS_OPERATOR         6

#define IF_FALSE_GOTO_OPERATOR  7
#define IF_TRUE_GOTO_OPERATOR   8
#define GOTO_OPERATOR           9
#define SET_LABEL_OPERATOR     10

#define OUTPUT_OPERATOR        11

#define ASSIGN_OPERATOR        12

extern int lineno;

/* размер таблицы символов (только uppercase-литеры) */
#define TABLE_SIZE 26


/* описание таблицы символов,
   в текущей реализации не используется поле dval
*/
typedef struct
{
    double dval;        // вещественное значение, зарезервировано на будущее
    int   is_defined;   // объявлена ли переменная
} TVariableTableRecord;

TVariableTableRecord table[TABLE_SIZE];


/* ПРОТОТИПЫ ФУНКЦИЙ: */

/* Лексический анализатор */
extern int yylex ();

/* Обработка синтаксического дерева */
void freenode (nodeType* p);
nodeType* constants(double value);
nodeType* idents (int index);
nodeType* tmpvars (int tmp_index);

/* Генерация трехадресного кода */
int codegenBinary(FILE* outputFile, int operatorCode,
            nodeType* leftOperand, nodeType* rightOperand, nodeType* result
           );
int codegenUnary(FILE* outputFile, int operatorCode,
            nodeType* operand, nodeType* result
           );
int codegenGoto(FILE* outputFile, int operatorCode,
            int labelNumber, nodeType* optionalExpression
           );
int codegenLabel(FILE* outputFile, int labelNumber);


/* Вывод сообщений об ошибках */
int my_yyerror(char* error_message);
int yyerror(char* errormessage);

int g_ErrorStatus = 0; /* Состояние ошибки при анализе либо кодогенерации */


FILE* outfile;           /* Внешний выходной файл */
char g_outFileName[256]; /* Имя выходного файла */

/* Обработка таблицы меток. Используется стековая организация */
static int g_LastLabelNumber = 0; 
static int g_LabelStackPointer = 0;

static int Labels[256];
static void PushLabelNumber(int);
static int  PopLabelNumber(void);
static void EmptyLabels(void);
%}

%verbose

%union
{
    double    dval;            // числовое значение лексемы
    int       index_in_table;  // индекс в таблице символов
    char      other;           // другой символ
    nodeType* nptr;            // узел или поддерево синтаксического дерева
}

%token <index_in_table>VARIABLE
%token <dval>NUMBER
%token <other>EOFILE IF_KEYWORD ELSE_KEYWORD WHILE_KEYWORD

%left '+' '-'
%left '*' '/'
%right UMINUS UPLUS

%type <nptr>expr expr_in_pars
%type <other>error

%start program

%%

program : lines;

lines : stmt '\n'
      | stmt EOFILE  { YYACCEPT; }
      | lines stmt '\n'
      | lines stmt EOFILE { YYACCEPT; }
      | EOFILE { YYACCEPT; }
      ;

stmt :  VARIABLE '=' expr 
                    {
                        table[$1].is_defined = !0;
                        codegenUnary(outfile, ASSIGN_OPERATOR, $3, idents($1));

                        g_tmpvar_upper_index = 0;
                        freenode($3);
                    }
     | expr     {   // в случае ошибки в выражении возможен
                        // вывод некорректного значения
                        codegenUnary(outfile, OUTPUT_OPERATOR, $1, NULL);

                        g_tmpvar_upper_index = 0;
                        freenode ($1);
                    }
     | conditional_statement
     | loop_statement
     | error        {
                        // В этом случае считаем, что пришедшая лексема
                        // здесь совершенно не уместна.
                        // Формируем сообщение об ошибке и вывоим на экран
                        char tmp[TMP_STRING_MAX_SIZE] = "\0";
                        int ch;
                        strcat(tmp,"Unexpected token ");
                        if (isgraph($1))
                        {
                            tmp[strlen(tmp)] = $1;
                        }
                        else
                        {
                            char tmp1[32] = "\0";
                            strcat(tmp, "with code ");
                            itoa((int)$1, tmp1, 10);
                            strcat(tmp, tmp1);
                        }
                        strcat(tmp," in expression");
                        my_yyerror(tmp);

                        yyclearin; /* discard lookahead */
                        yyerrok;
                    }
     ;

conditional_statement
     : conditional_begin true_branch false_branch
     ;

conditional_begin :
       IF_KEYWORD '(' expr ')'
       { 
         codegenGoto(outfile, IF_FALSE_GOTO_OPERATOR
                      , g_LastLabelNumber, $3
                     );
         PushLabelNumber(g_LastLabelNumber);
         ++g_LastLabelNumber;
       }
    |
       IF_KEYWORD '(' expr error
       {
         my_yyerror("Unbalanced parentheses");
       }
     ;

true_branch :
       stmt
       {
         codegenGoto(outfile, GOTO_OPERATOR
                      , g_LastLabelNumber, NULL

                     );
         codegenLabel(outfile, PopLabelNumber());
         PushLabelNumber(g_LastLabelNumber);
         ++g_LastLabelNumber;
       }
    ;

false_branch :
       ELSE_KEYWORD stmt
       {
         codegenLabel(outfile, PopLabelNumber());
       }
    |
      error
       {
         my_yyerror("Else keyword expected");
       }
    ;

loop_statement :
     loop_header_statement loop_condidtion loop_body
     ;

loop_header_statement : WHILE_KEYWORD
       {
       codegenLabel(outfile, g_LastLabelNumber);
       PushLabelNumber(g_LastLabelNumber);
       ++g_LastLabelNumber;
       }
    ;

loop_condidtion : '(' expr ')'
        {
         codegenGoto(outfile, IF_FALSE_GOTO_OPERATOR
                      , g_LastLabelNumber, $2
                     );
         PushLabelNumber(g_LastLabelNumber);
         ++g_LastLabelNumber;
        }
    | '(' expr error { my_yyerror("Unbalanced parentheses"); }
    ;

loop_body : stmt
       {
         int tmpLabelJ = PopLabelNumber();
         int tmpLabelK = PopLabelNumber();
         
         codegenGoto(outfile, GOTO_OPERATOR
                      , tmpLabelK, NULL

                     );
         codegenLabel(outfile, tmpLabelJ);

       }
    ;
expr : expr '+' expr
                    {
                        $$ = tmpvars(g_tmpvar_upper_index);
                        $$->left = $1;
                        $$->right = $3;

                        ++g_tmpvar_upper_index;

                        codegenBinary(outfile, ADDITION_OPERATOR, $1, $3, $$);
                    }
     | expr '-' expr
                    {
                        $$ = tmpvars(g_tmpvar_upper_index);
                        $$->left = $1;
                        $$->right = $3;
                        ++g_tmpvar_upper_index;
                        codegenBinary(outfile, SUBTRACTION_OPERATOR, $1, $3, $$);
                    }
     | expr '*' expr
                    {
                        $$ = tmpvars(g_tmpvar_upper_index);
                        $$->left = $1;
                        $$->right = $3;

                        ++g_tmpvar_upper_index;

                        codegenBinary(outfile, MULTIPLICATION_OPERATOR, $1, $3, $$);
                    }
     | expr '/' expr
                    {
                        $$ = tmpvars(g_tmpvar_upper_index);
                        $$->left = $1;
                        $$->right = $3;

                        ++g_tmpvar_upper_index;

                        codegenBinary(outfile, DIVISION_OPERATOR, $1, $3, $$);
                    }
     | '-' expr %prec UMINUS
                    {
                        $$ = tmpvars(g_tmpvar_upper_index);
                        $$->right = $2;
                        ++g_tmpvar_upper_index;

                        codegenUnary(outfile, NEGATION_OPERATOR, $2, $$);

                    }
     | '+' expr %prec UPLUS
                    {
                        $$ = tmpvars (g_tmpvar_upper_index);
                        $$->right = $2;
                        ++g_tmpvar_upper_index;

                        codegenUnary(outfile, UNPLUS_OPERATOR, $2, $$);
                    }
     | expr_in_pars
                    {
                        $$ = $1;
                        $$->place = $1->place;
                        $$->type = $1->type;
                        $$->left = $1->left;
                        $$->right = $1->right;
                    }
     | VARIABLE
                    {
                        // если нет такой переменной в таблице
                        // выводим сообщение об ошибке
                        if (table[$1].is_defined == 0)
                        {
                            // формируем сообщение об ошибке и выводим на экран
                            char tmp[TMP_STRING_MAX_SIZE] = "\0";
                            strcat(tmp,"Undefined variable ");
                            tmp[strlen(tmp)] = $1 + 'A';
                            my_yyerror(tmp);

                            // восстановление после ошибки
                            yyerrok;
                            yyclearin;

                            // поскольку переменная не объявлена,
                            // то считаем, что этот элемент выражения равен 0
                            $$ = constants(0.0);
                        }
                        else
                        {
                            // если такая переменная есть в таблице,
                            // выводим сообщение об ошибке
                            // то считаем, что этот элемент выражения равен
                            // значению, взятому из таблицы
                            $$ = idents($1);
                        }
                    }
     | NUMBER       {
                        $$ = constants($1);
                    }
     ;

expr_in_pars : '(' expr ')'
                    {
                        $$ = $2;
                        $$->place = $2->place;
                        $$->type = $2->type;
                        $$->left = $2->left;
                        $$->right = $2->right;
                    }
             | '(' expr error
                    {
                        // если не закрыта круглая скобка, выводим сообщение,
                        // но не читаем до синхронизирующей лексемы,
                        // так как дальше может быть все в порядке
                        my_yyerror("Right parentheses expected.\n");
                        $$ = $2;
                        $$->place = $2->place; 
                        $$->left = $2->left;
                        $$->right = $2->right;
                    }
             ;
%%
// функция вывода сообщения об ошибке.
// Входной параметр - error_message
int my_yyerror(char* error_message)
{
    fprintf(stderr, "Line %d: %s.\n", lineno, error_message);
    g_ErrorStatus = !0;
    return !0;
}

// Yacc-функция вывода сообщения об ошибке.
// Входной параметр - error_message
int yyerror(char* errormessage)
{
    // Подавляем встроенное сообщение об ошибке
    // Вместо нее используется my_yyerror (см.выше)
    return !0;
}

nodeType* constants(double value)
{
    nodeType* p;
    size_t    nodeSize;

    /* выделить память для узла */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* установить значения полей */
    p->type = typeConst;
    p->place = 0;       // константа размещается в самом узле
    p->constant.value = value;

    p->right = p->left = NULL;

    return p;
}

nodeType* idents(int index)
{
    nodeType* p;
    size_t    nodeSize;

    /* выделить память для узла */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* установить значения полей */
    p->type = typeIdentifier;
    p->place = index;          // ссылка на таблицу идентификаторов
    p->right = p->left = NULL;

    return p;
}

nodeType* tmpvars (int tmp_index)
{
    nodeType* p;
    size_t    nodeSize;

    /* выделить память для узла */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* установить значения полей */
    p->type = typeTmpvar;
    p->place = tmp_index;   // сохранение до последующего использования
    p->right = p->left = NULL;

    return p;
}

// освобождение занятой пямяти
void freenode(nodeType* p)
{
    if (!p) return;
    freenode(p->left);
    freenode(p->right);
    free(p);
    return;
}


int codegenBinary(FILE* outputFile, int operatorCode,
            nodeType* leftOperand, nodeType* rightOperand, nodeType* result
           )
{
    fprintf(outputFile, "\t$t%u\t:=\t", result->place);
    switch (leftOperand->type)
    {
    case typeIdentifier:
        fprintf(outputFile, "%c", leftOperand->place + 'A');
        break;
    case typeTmpvar:
        fprintf(outputFile, "$t%d", leftOperand->place);
        break;
    case typeConst:
        fprintf(outputFile, "%g", leftOperand->constant.value);
        break;
    }

    switch (operatorCode)
    {
    case ADDITION_OPERATOR:
        fprintf(outputFile, "+");
        break;
    case SUBTRACTION_OPERATOR:
        fprintf(outputFile, "-");
        break;
    case MULTIPLICATION_OPERATOR:
        fprintf(outputFile, "*");
        break;
    case DIVISION_OPERATOR:
        fprintf(outputFile, "/");
        break;
    }

    switch (rightOperand->type)
    {
    case typeIdentifier:
        fprintf(outputFile, "%c", rightOperand->place + 'A');
        break;
    case typeTmpvar:
        fprintf(outputFile, "$t%d", rightOperand->place);
        break;
    case typeConst:
        fprintf(outputFile, "%g", rightOperand->constant.value);
        break;
    }

    fprintf(outputFile, "\n");
}

int codegenUnary(FILE* outputFile, int operatorCode,
            nodeType* operand, nodeType* result
           )
{
    if (operatorCode == OUTPUT_OPERATOR)
    {
        fprintf (outputFile, "\toutput\t");
    }

    else if (operatorCode == ASSIGN_OPERATOR)
    {
        fprintf(outputFile, "\t%c\t:=\t", result->place + 'A');
    }
    else
    {
        fprintf(outputFile, "\t$t%u\t:=\t", result->place);
        switch (operatorCode)
        {
        case UNPLUS_OPERATOR:
            fprintf(outputFile, "+");
            break;
        case NEGATION_OPERATOR:
            fprintf(outputFile, "-");
        }
    }

    switch (operand->type)
    {
    case typeIdentifier:
        fprintf(outputFile, "%c", operand->place + 'A');
        break;
    case typeTmpvar:
        fprintf(outputFile, "$t%d", operand->place);
        break;
    case typeConst:
        fprintf(outputFile, "%g", operand->constant.value);
        break;
    }
    fprintf(outputFile, "\n");
}

int codegenGoto(FILE* outputFile, int operatorCode,
            int labelNumber, nodeType* optionalExpression
           )
{
    if (operatorCode != GOTO_OPERATOR)
    {
        if(operatorCode == IF_FALSE_GOTO_OPERATOR)
            fprintf(outputFile, "\tiffalse\t");
        else if(operatorCode == IF_TRUE_GOTO_OPERATOR)
            fprintf(outputFile, "\tiftrue\t");
        
        switch (optionalExpression->type)
        {
        case typeIdentifier:
            fprintf(outputFile, "%c", optionalExpression->place + 'A');
            break;
        case typeTmpvar:
            fprintf(outputFile, "$t%d", optionalExpression->place);
            break;
        case typeConst:
            fprintf(outputFile, "%g", optionalExpression->constant.value);
            break;
        }
    }

    fprintf(outputFile, "\tgoto\t$L%d", labelNumber);
    fprintf(outputFile, "\n");

}

int codegenLabel(FILE* outputFile, int labelNumber)
{
    fprintf (outputFile, "$L%d:", labelNumber);
      
}


static void PushLabelNumber(int labelNumber)
{
    Labels[g_LabelStackPointer] = labelNumber;
    ++g_LabelStackPointer;
}

static int PopLabelNumber(void)
{
   if (g_LabelStackPointer > 0)
   {
       --g_LabelStackPointer;
       return Labels[g_LabelStackPointer];
   }
   else
   {
       g_LabelStackPointer = 0;
       return -1;
   }
}

static void EmptyLabels(void)
{
   g_LabelStackPointer = 0;
}

int main (int argc, char* argv[])
{
    int yyparse();

    // инициализируем таблицу идентификаторов
    int i;
    for (i = 0; i < TABLE_SIZE; ++i)
    {
        table[i].is_defined = 0;
    }

    if (argc < 3)
    {
        printf("Too few paremeters.\n");
        system("PAUSE");  // not for *NIXes
        return EXIT_FAILURE;
    }
    if (NULL == freopen (argv[1], "r", stdin))
    {
        printf("Cannot open input file %s.\n", argv[1]);
        system("PAUSE");   // not for *NIXes
        return EXIT_FAILURE;
    }
    outfile = fopen(argv[2], "w");
    if (NULL == outfile)
    {
        printf("Cannot open output file %s.\n", argv[2]);
        system("PAUSE");   // not for *NIXes
        return EXIT_FAILURE;
    }

    strcpy(g_outFileName, argv[2]);

    yyparse();

    fclose(outfile);

    if (0 != g_ErrorStatus)
    { 
        printf("Target code isn't generated.\n");
        unlink(g_outFileName);
    }

}
