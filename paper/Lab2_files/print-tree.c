/**
 * print-tree.c
 *   Простой анализатор, который строит дерево разбора и печатает в выходной поток.
 *
 */


#include <stdlib.h>

#include "parse-tree.h"                 // Для функций PrintTree и FreeTree

// Это получаем от Bison/Yacc
extern int yyparse(void);

// Это строит наш анализатор
extern Node* tree;

int main(int argc, char* argv[])
{
    yyparse();
    PrintTree(stdout, tree);
    FreeTree(tree);
    exit (0);
}
