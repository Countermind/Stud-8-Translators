/**
 * parse-tree.c
 *   ������� ������ � ������� ���������� ������ �������.
 *
 */

// +-------------+
// | ����������� |
// +-------------+

/*
  1. ������ ��� ������� �� �������� ������������ Bison/Yacc, �������
     ���� ���� ����� �������� ���������� #include ������ .y-�����, ������
     ��� ����������.

  2. ���� ��� ������� �� ������� ������������ � attribute.h � attribute.c,
     ������� ������ ���� ����� ������� (��������) � ����� ����� �������.

  3. ��-�� ���� � ������ ������������, � .y-����� ����� ��������
     <stdio.h>, "parse-tree.h" � "attribute.h".
 */


// +---------------------------+
// | �������������� ���������� |
// +---------------------------+

int TYPE_NODE = 60000;
int TYPE_TNODE = 70000;
int TYPE_NNODE = 80000;


// +------------+
// | ���������� |
// +------------+

static void PrintTreeIndented(FILE* stream, Node* node, int spaces);


/**
 * ��������������� ������� ��� PrintAttributes, ������� �������� ���������� �������.
 */
static void PrintPrefix(FILE* stream, int* printed)
{
    if (*printed)
        fprintf(stream, ", ");
    else
        fprintf(stream, " [");
    ++(*printed);
}

/**
 * �������� ����� ���������.
 */
static void PrintAttributes(FILE* stream, AttributeSet* attributes)
{
    int printed = 0;
    if (attributes == NULL)
        return;
    if (HasAttribute(attributes, "name"))
    {
        PrintPrefix(stream, &printed);
        fprintf(stream, "name:'%s'", GetAttributeValueString(attributes, "name"));
    } 
    if (HasAttribute(attributes, "text"))
    {
        PrintPrefix(stream, &printed);
        fprintf(stream, "text:'%s'", GetAttributeValueString(attributes, "text"));
    }

    if (printed)
        fprintf(stream, "]");
}

/**
 * �������� ��������� ����, ����������� ��������� ����������� ��������.
 * ��� � ������� PrintTreeIndented, ���������, ��� ������ ����������
 * ��� ����������.
 */
static void PrintNonterminalNode(FILE* stream, NNode* nn, int spaces)
{
    Node* node = (Node *)nn;

    if (node == NULL)
    {
        fprintf(stream, "*** ERROR: Null NNode ***\n");
        return;
    }

    // �������� ������� ���� ������
     fprintf(stream, "%s/%d", nonterm_names[node->symbol], nn->arity);
     PrintAttributes(stream, node->attributes);
     fprintf(stream, "\n");

    // �������� ���� ���������������� ��������.
    int child_indent = spaces + 4;
    int i;
    for (i = 0; i < nn->arity; ++i)
    {
        fprintf(stream, "%*d ", child_indent, i+1);
        PrintTreeIndented(stream, nn->children[i], child_indent);
    }
}

/**
 * �������� ������������ ����.
 */
static void PrintTerminalNode(FILE* stream, TNode* tn)
{
    int symbol = ((Node *) tn)->symbol;
    AttributeSet* attributes = ((Node *) tn)->attributes;

    switch (symbol)
    {
    case _INTEGER:
        fprintf(stream, "INT_CONST");
        break;

    case _IDENTIFIER:
        fprintf(stream, "IDENTIFIER");
        break;

    case _BEGIN:
        fprintf(stream, "BEGIN");
        break;

    case _END:
        fprintf(stream, "END");
        break;

    case _SEMI:
        fprintf(stream, "SEMICOLON");
        break;

    case _PLUSOP:
        fprintf(stream, "PLUS_OPERATOR");
        break;

    default:
        if ((symbol < TOKENS_START) || (symbol > TOKENS_END))
            fprintf(stream, "*invalid*(%d)", symbol);
        else
          fprintf(stream, "%s", yytname[symbol]);
        break;
    }

  PrintAttributes(stream, attributes);
  fprintf(stream, "\n");
}

/**
 * �������� ������, ����������� ��������� ����������� ��������.
 * ���������, ��� ���������� ��� ���������� �� ������ ������.
 */
static void PrintTreeIndented(FILE* stream, Node* node, int spaces)
{
    if (node == NULL)
    {
        fprintf(stream, "*** ERROR: Null tree. ***\n");
    }
    else if (IsTerminalNode(node)) // ���� ��� ���� ������.
    {
        PrintTerminalNode(stream, (TNode *) node);
    }
    else if (IsNonterminalNode (node)) // ���� ��� ��������� ���� ������.
    {
      PrintNonterminalNode(stream, (NNode *) node, spaces);
    }
    else
    {
      fprintf(stream, "*** ERROR: Unknown node type %d. ***\n", node->type);
    }
}


// +------------------------+
// | �������������� ������� |
// +------------------------+

void FreeTree(Node* node)
{
    if (NULL == node)
        return;
    if (IsNonterminalNode(node)) // ���� ��� ����.
    {
        int i;
        NNode *nn = ((NNode *) node);
        for (i = 0; i < nn->arity; ++i)
            FreeTree(nn->children[i]);
        if (nn->children != NULL)
		{
            free(nn->children);
			nn->children = NULL;
		}

    }

    if (node->attributes != NULL)
        FreeAttributeSet(node->attributes);
  free(node);
  node = NULL;
}

int GetNodeArity(Node* node)
{
    if (0 == IsNonterminalNode(node))
       return 0;
    NNode* nn = (NNode *) node;
    return nn->arity;
}

Node* GetNodeChild(Node* node, int i)
{
    if (0 == IsNonterminalNode(node))
        return NULL;
    NNode* nn = (NNode *) node;
    if (nn->arity <= i)
        return NULL;
    return nn->children[i];
}

int IsNonterminalNode(Node* node)
{
    return node->type == TYPE_NNODE;
}

int IsTerminalNode(Node* node)
{
    return node->type == TYPE_TNODE;
}

Node* CreateNonterminalNode(int nonterm, int arity, AttributeSet* attributes)
{
    NNode *nn = (NNode *)malloc (sizeof (NNode));
    if (NULL == nn)
        return NULL;
    Node* node = (Node *) nn;
    node->type = TYPE_NNODE;
    node->symbol = nonterm;
    node->attributes = attributes;
    nn->arity = arity;
    nn->children = (Node**)malloc(arity * sizeof(Node *));
        return node;
}

Node* CreateTerminalNode(int term, AttributeSet* attributes)
{
    Node* tn = (Node *)malloc(sizeof(TNode));
    if (NULL == tn)
       return NULL;
    Node* node = (Node *) tn;
    node->type = TYPE_TNODE;
    node->symbol = term;
    node->attributes = attributes;
    return node;
}

void PrintTree(FILE* stream, Node* node)
{
    PrintTreeIndented (stream, tree, 0);
}

int SetNodeChild(Node* node, int i, Node* child)
{
    if (0 == IsNonterminalNode(node))
        return 0;
    NNode* nn = (NNode *) node;
    if (nn->arity <= i)
        return 0;
    nn->children[i] = child;
    return 1;
}
