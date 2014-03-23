/**
 * print-tree.c
 *   ������� ����������, ������� ������ ������ ������� � �������� � �������� �����.
 *
 */


#include <stdlib.h>

#include "parse-tree.h"                 // ��� ������� PrintTree � FreeTree

// ��� �������� �� Bison/Yacc
extern int yyparse(void);

// ��� ������ ��� ����������
extern Node* tree;

int main(int argc, char* argv[])
{
    yyparse();
    PrintTree(stdout, tree);
    FreeTree(tree);
    exit (0);
}
