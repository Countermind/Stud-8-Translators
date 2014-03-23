/**
 * language.yy
 *   Синтаксический анализатор очень простого языка,
 *   выводящий на экран дерево разбора.
 *
 */

%no-lines
%verbose
%require "2.5"

%{
#include <ctype.h>              // Для tolower
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "attribute.h"
#include "parse-tree.h"
%}


// +----------------------------+
// | Определения для Bison/Yacc |
// +----------------------------+

/* Поскольку мы пытаемся построить дерево разбора,
 * нужно, чтобы с каждым элементом была связана часть дерева.
 */

%{
#define YYSTYPE Node*
%}

/* Таблица лексем. */
%token_table

/* Все лексемы, которые используются. */
%token TOKENS_START
%token _IDENTIFIER
%token _SEMI
%token _BEGIN
%token _END
%token _PLUSOP
%token _INTEGER
%token TOKENS_END

%left _PLUSOP

%{

/* Несколько внешних программных объектов от лексера, которые нужно предварительно объявить. */
extern char* yytext;
extern int yylineno;

extern int yylex(void);

/* Определяем функцию yyerror. */
void yyerror(char* err)
{
    fprintf(stderr, "Line %d - \"%s\"\n", yylineno, err);

    // Не очень хорошо поступаем, не освобождая память перед выходом.
    // Для завершения работы после первой ошибки нужно раскомментировать код на следующей строке.
    // exit (1);
}

%}


// +---------------------------+
// | Информация о нетерминалах |
// +---------------------------+

%{

/* "Волшебный тип", который позволит ссылаться на нетерминалы по имени. */
#define NONTERMINAL(NAME) _ ## NAME
enum nonterms
#include "nonterminals.c"
typedef enum nonterms nonterms;
#undef NONTERMINAL


#define NONTERMINAL(NAME) #NAME
char* nonterm_names[] = 
#include "nonterminals.c"

%}


// +-------------------------------+
// | Глобальные объекты Bison/Yacc |
// +-------------------------------+

%{
Node* tree;
%}


// +------------------------------------+
// | Процедуры поддержки дерева разбора |
// +------------------------------------+

%{
/**
 * Создает новый промежуточный узел с нужным числом непосредственных потомков.
 */
Node* CreateInteriorNode(int nonterm, AttributeSet* attributes, int arity, ...)
{
    va_list children;
    int c;
    Node* child;

    // Обработка переменного числа аргументов
    va_start(children, arity);

    // Создается новый узел дерева.
    Node* node = CreateNonterminalNode(nonterm, arity, attributes);

    // Добавляются непосредственные потомки.
    for (c = 0; c < arity; ++c)
    {
        child = va_arg(children, Node *);
        SetNodeChild(node, c, child);
    }

    // Убираемся за собой после обработки переменного числа аргументов.
    va_end (children);

    // Здесь все сделано.
    return node;
}
%}

// +-------------------+
// | Обработка списков |
// +-------------------+

%{
/**
 * Создает список из головы и хвоста.
 */
Node* ConstructList(Node* car, Node* cdr)
{
    return CreateInteriorNode(_cons, NULL, 2, car, cdr);
}

/**
 * Определяет длину списка.
 */
int GetListLength(Node* lst)
{
    int length = 0;
    while (lst->symbol != _epsilon)
    {
        lst = GetNodeChild(lst, 1);
        ++length;
    }
    return length;
}

/**
 * По заданному непустому списку строит узел дерева, который содержит
 * все элементы списка. По мере преобразования освобождает память,
 * занятую списком.
 */
Node* ConvertListToNode(int type, AttributeSet* attributes, Node* lst)
{
    int len;                      // Общая длина списка
    Node* parent;                 // Узел дерева, который строится
    Node* tmp;                    // Временный узел

    len = GetListLength(lst);
    parent = CreateNonterminalNode(type, len, attributes);
    int child = 0;

    while (lst->symbol != _epsilon)
    {
        SetNodeChild(parent, child++, GetNodeChild(lst, 0));
        tmp = lst;
        lst = GetNodeChild(lst, 1);
        if (tmp->attributes != NULL)
            FreeAttributeSet(tmp->attributes);
        free(tmp);
    }

    if (lst->attributes != NULL)
        FreeAttributeSet(lst->attributes);
    free (lst);

    return parent;
}

/**
 * Создает узел для пустой (epsilon) цепочки.
 */
Node* CreateEpsilonNode(void)
{
    return CreateNonterminalNode(_epsilon, 0, NULL);
}
%}


// +----------------------+
// | Различные полезности |
// +----------------------+

%{
/**
 * Преобразует строку к нижнему регистру.
 */
void ConvertStringToLowerCase(char* str)
{
    while (*str != '\0')
    {
      *str = tolower(*str);
      ++str;
    }
}
%}

// +----------------------+
// | Продукции грамматики |
// +----------------------+

%%
start : program      { $$ = CreateInteriorNode(_start, NULL, 1, $1); tree = $$; }
      ;

program : statement
          { $$ = CreateInteriorNode(_program, NULL, 1, $1); }
      ;

statement
    : /* epsilon-правило */
      { $$ = CreateNonterminalNode (_empty_statement, 0, NULL); }
    | expr
      { $$ = CreateInteriorNode(_statement, NULL, 1, $1); }
    | compound_statement
      { $$ = CreateInteriorNode(_statement, NULL, 1, $1); }
    ;

expr :
      _IDENTIFIER
      {
          AttributeSet* attributes = CreateAttributeSet(1);
          char* name = strdup(yytext);
          ConvertStringToLowerCase(name);
          SetAttributeValueString(attributes, "name", name);
          Node* nodeTerminal = CreateTerminalNode(_IDENTIFIER, attributes);
          Node* node = CreateInteriorNode(_expr, NULL, 1, nodeTerminal);
          $$ = node;
      }
     |
      _INTEGER
      {
          AttributeSet* attributes = CreateAttributeSet(1);
          char* name = strdup(yytext);
          SetAttributeValueString(attributes, "text", name);
          Node* nodeTerminal = CreateTerminalNode(_INTEGER, attributes);
          Node* node = CreateInteriorNode(_expr, NULL, 1, nodeTerminal);
          $$ = node;
      }
     | 
      expr _PLUSOP expr
      {
          AttributeSet* attributes = CreateAttributeSet(1);
          SetAttributeValueString(attributes, "text", "+");
          Node* nodeTerminal = CreateTerminalNode(_PLUSOP, attributes);
          Node* node = CreateInteriorNode(_expr, NULL, 3, $1, nodeTerminal, $3);
          $$ = node;
      }
    ;

compound_statement
    : _BEGIN statement_list _END
      {
          AttributeSet* attributes1 = CreateAttributeSet(1);
          SetAttributeValueString(attributes1, "name", "begin");
          Node* nodeTerminal1 = CreateTerminalNode(_BEGIN, attributes1);

          AttributeSet* attributes2 = CreateAttributeSet(1);
          SetAttributeValueString(attributes2, "name", "end");
          Node* nodeTerminal2 = CreateTerminalNode(_END, attributes2);

          $$ = CreateInteriorNode(_compound_statement, NULL, 3, nodeTerminal1, $2, nodeTerminal2);
      }
    ;

statement_list
    : statement statement_list_tail
      {
          AttributeSet *attributes = CreateAttributeSet(0);
          $$ = ConvertListToNode(_statement_list, attributes, ConstructList($1, $2));
      }
    ;

statement_list_tail
    : /* epsilon-правило */
      { $$ = CreateEpsilonNode(); }
    | _SEMI statement statement_list_tail
      {
          AttributeSet* attributes = CreateAttributeSet(1);
          SetAttributeValueString(attributes, "name", ";");
          Node* nodeTerminal = CreateTerminalNode(_SEMI, attributes);

          $$ = CreateInteriorNode(_statement_list_tail, NULL, 2, nodeTerminal, ConstructList($2, $3));
      }
    ;

%%

// +--------------------+
// | Дополнительный код |
// +--------------------+

/* Подключаем лексический анализатор. */
#include "lex.yy.c"

/* Код для управления атрибутами. */
#include "attribute.c"

/* Код для построения дерева разбора. */
#include "parse-tree.c"