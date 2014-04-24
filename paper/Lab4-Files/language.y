%{
/* ������� ������������ bison ��� ����������� � ������������ ������������� ���
     ������� �������������� ���������,
     �������� ���������� if � ������������ ������ else,
     ���������� ����� � ������������,
     ���������� ������������, � ����� ������ �������� ���������.
   ������ �������� ����������.
   ����������� ���������� - ������ ����� ������.
   ��� ���������� - ���������������� � �������� ��������� ������.
      
   ���������������� ��� ��������� zlib,
     ��. http://www.gzip.org/zlib/zlib_license.html

   ����������� - ��������� ��������.
   ������ ����� 15.10.2008,
          ������������� 17.10.2008, 23.03.2013, 03.04.2013, 17.04.2013.

   ����������� ��������� ������������� ����� ��������������� �����������.
   ������:
   $ bison -d language.y -o language.tab.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "calc.h"     /* �������� ��������� ��������������� ������ */


int g_tmpvar_upper_index = 0;

/* ������ ��������� ������ �� ����������*/
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

/* ������ ������� �������� (������ uppercase-������) */
#define TABLE_SIZE 26


/* �������� ������� ��������,
   � ������� ���������� �� ������������ ���� dval
*/
typedef struct
{
    double dval;        // ������������ ��������, ��������������� �� �������
    int   is_defined;   // ��������� �� ����������
} TVariableTableRecord;

TVariableTableRecord table[TABLE_SIZE];


/* ��������� �������: */

/* ����������� ���������� */
extern int yylex ();

/* ��������� ��������������� ������ */
void freenode (nodeType* p);
nodeType* constants(double value);
nodeType* idents (int index);
nodeType* tmpvars (int tmp_index);

/* ��������� ������������� ���� */
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


/* ����� ��������� �� ������� */
int my_yyerror(char* error_message);
int yyerror(char* errormessage);

int g_ErrorStatus = 0; /* ��������� ������ ��� ������� ���� ������������� */


FILE* outfile;           /* ������� �������� ���� */
char g_outFileName[256]; /* ��� ��������� ����� */

/* ��������� ������� �����. ������������ �������� ����������� */
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
    double    dval;            // �������� �������� �������
    int       index_in_table;  // ������ � ������� ��������
    char      other;           // ������ ������
    nodeType* nptr;            // ���� ��� ��������� ��������������� ������
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
     | expr     {   // � ������ ������ � ��������� ��������
                        // ����� ������������� ��������
                        codegenUnary(outfile, OUTPUT_OPERATOR, $1, NULL);

                        g_tmpvar_upper_index = 0;
                        freenode ($1);
                    }
     | conditional_statement
     | loop_statement
     | error        {
                        // � ���� ������ �������, ��� ��������� �������
                        // ����� ���������� �� �������.
                        // ��������� ��������� �� ������ � ������ �� �����
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
                        // ���� ��� ����� ���������� � �������
                        // ������� ��������� �� ������
                        if (table[$1].is_defined == 0)
                        {
                            // ��������� ��������� �� ������ � ������� �� �����
                            char tmp[TMP_STRING_MAX_SIZE] = "\0";
                            strcat(tmp,"Undefined variable ");
                            tmp[strlen(tmp)] = $1 + 'A';
                            my_yyerror(tmp);

                            // �������������� ����� ������
                            yyerrok;
                            yyclearin;

                            // ��������� ���������� �� ���������,
                            // �� �������, ��� ���� ������� ��������� ����� 0
                            $$ = constants(0.0);
                        }
                        else
                        {
                            // ���� ����� ���������� ���� � �������,
                            // ������� ��������� �� ������
                            // �� �������, ��� ���� ������� ��������� �����
                            // ��������, ������� �� �������
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
                        // ���� �� ������� ������� ������, ������� ���������,
                        // �� �� ������ �� ���������������� �������,
                        // ��� ��� ������ ����� ���� ��� � �������
                        my_yyerror("Right parentheses expected.\n");
                        $$ = $2;
                        $$->place = $2->place; 
                        $$->left = $2->left;
                        $$->right = $2->right;
                    }
             ;
%%
// ������� ������ ��������� �� ������.
// ������� �������� - error_message
int my_yyerror(char* error_message)
{
    fprintf(stderr, "Line %d: %s.\n", lineno, error_message);
    g_ErrorStatus = !0;
    return !0;
}

// Yacc-������� ������ ��������� �� ������.
// ������� �������� - error_message
int yyerror(char* errormessage)
{
    // ��������� ���������� ��������� �� ������
    // ������ ��� ������������ my_yyerror (��.����)
    return !0;
}

nodeType* constants(double value)
{
    nodeType* p;
    size_t    nodeSize;

    /* �������� ������ ��� ���� */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* ���������� �������� ����� */
    p->type = typeConst;
    p->place = 0;       // ��������� ����������� � ����� ����
    p->constant.value = value;

    p->right = p->left = NULL;

    return p;
}

nodeType* idents(int index)
{
    nodeType* p;
    size_t    nodeSize;

    /* �������� ������ ��� ���� */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* ���������� �������� ����� */
    p->type = typeIdentifier;
    p->place = index;          // ������ �� ������� ���������������
    p->right = p->left = NULL;

    return p;
}

nodeType* tmpvars (int tmp_index)
{
    nodeType* p;
    size_t    nodeSize;

    /* �������� ������ ��� ���� */
    nodeSize = sizeof(nodeType);
    if (NULL == (p = (nodeType*)malloc(nodeSize)))
       my_yyerror("out of memory");

    /* ���������� �������� ����� */
    p->type = typeTmpvar;
    p->place = tmp_index;   // ���������� �� ������������ �������������
    p->right = p->left = NULL;

    return p;
}

// ������������ ������� ������
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

    // �������������� ������� ���������������
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
