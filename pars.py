__author__ = 'Kostya'
import ply.yacc as yacc

from lexer import tokens, lxr
from node import Node, Leaf, LeafError

precedence = (
    ('nonassoc', 'LESS', 'GREATER', 'GREQUALS', 'LSEQUALS'),
    ('right', 'ASSIGN'),
    ('left', 'NOTEQUALS', 'EQUALS')
)


def p_program_start(p):
    'program : statement_list'
    p[0] = Node(p, [p[1]])


def p_statement_list(p):
    '''statement_list : statement SEMICOLON statement_list
                        | empty'''
    p[0] = Node(p, [p[1]] if len(p) == 2 else [p[1], Leaf(p, 2), p[3]])


def p_nonterminated_statement(p):
    '''statement_list : statement error statement_list'''
    p[0] = Node(p, [p[1], LeafError('Missing semicolon', p.lineno(2)), p[3]])


def p_statement(p):
    '''statement : expression
                 | for_statement'''
    p[0] = Node(p, [p[1]])


def p_expression_constants(p):
    '''expression : HCONST
                  | BCONST
                  | ID'''
    p[0] = Node(p, leaf=Leaf(p, 1))


def p_expression_operations(p):
    '''expression : expression LESS expression
                  | expression GREATER expression
                  | expression GREQUALS expression
                  | expression LSEQUALS expression
                  | expression NOTEQUALS expression
                  | expression EQUALS expression
                  | expression ASSIGN expression'''
    p[0] = Node(p, [p[1], Leaf(p, 2), p[3]])


def p_expression_group(p):
    'expression : LPAR expression RPAR'
    p[0] = Node(p, [Leaf(p, 1), p[2], Leaf(p, 3)])


def p_missing_rpar_error(p):
    '''expression : LPAR expression error'''
    p[0] = Node(p, [Leaf(p, 1), p[2], LeafError('Missing closing parenthesis', p.lineno(3))])


def p_missing_lpar_error(p):
    'expression : error expression RPAR'
    p[0] = Node(p, [LeafError('Missing opening parenthesis', p.lineno(1)), p[2], Leaf(p, 3)])


def p_for_statement(p):
    'for_statement : FOR LPAR for_expr SEMICOLON for_expr SEMICOLON for_expr RPAR statement'
    p[0] = Node(p,
                [Leaf(p, 1), Leaf(p, 2), p[3], Leaf(p, 4), p[5], Leaf(p, 6), p[7],
                 Leaf(p, 8), p[9]])


def p_for_expr(p):
    '''for_expr : expression
                | empty'''
    p[0] = p[1]


def p_empty(p):
    'empty :'
    p[0] = Node(p)


def p_error(p):
    if not p:
        print "Syntax error at EOF"
    else:
        print('Unexpected symbol \'{0}\' at line {1}'.format(p.value, p.lineno))
        yacc.errok()
        return yacc.token()




yacc_parser = yacc.yacc(debug=True)


def yparse(data, debug=0):
    yacc_parser.error = 0
    lxr.lineno = 1
    p = yacc_parser.parse(data, debug=debug, lexer=lxr)
    if yacc_parser.error:
        return None
    return p