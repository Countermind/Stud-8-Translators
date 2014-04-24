from __future__ import print_function

__author__ = 'Kostya'

# type names
SEMICOLON = 'SEMICOLON'
COMMA = 'COMMA'
COLON = 'COLON'
ID = 'ID'
FOR = 'FOR'
IF = 'IF'
ELSE = 'ELSE'
WHILE = 'WHILE'
DO = 'DO'
BINARY = 'BINARY'
HEXADECIMAL = 'HEXADECIMAL'
FLOAT = 'FLOAT'
BREAK = 'BREAK'
CONTINUE = 'CONTINUE'
PRINT = 'PRINT'
READF = 'READF'
READI = 'READI'
HCONST = 'HCONST'
BCONST = 'BCONST'
FCONST = 'FCONST'
ASSIGN = 'ASSIGN'
GREATER = 'GREATER'
LESS = 'LESS'
EQUALS = 'EQUALS'
NOTEQUALS = 'NOTEQUALS'
GREQUALS = 'GREQUALS'
LSEQUALS = 'LSEQUALS'
PLUS = 'PLUS'
MINUS = 'MINUS'
MULTIPLY = 'MULTIPLY'
DIVIDE = 'DIVIDE'
INR = 'INR'
DCR = 'DCR'
LSUM = 'LSUM'
LMUL = 'LMUL'
XOR = 'XOR'
LPAR = 'LPAR'
RPAR = 'RPAR'
LBRACE = 'LBRACE'
RBRACE = 'RBRACE'
LBRACKET = 'LBRACKET'
RBRACKET = 'RBRACKET'


builtins = (PRINT, READF, READI)

keywords = (FOR, BINARY, HEXADECIMAL, FLOAT, IF, ELSE, WHILE, DO, BREAK, CONTINUE)

# reserved words
reserved = builtins + keywords

punctuators = (
    SEMICOLON,
    COMMA,
    COLON,
    LPAR,
    RPAR,
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET
)

operators = (
    ASSIGN,
    GREATER,
    LESS,
    EQUALS,
    NOTEQUALS,
    GREQUALS,
    LSEQUALS,
    INR,
    DCR,
    PLUS,
    MINUS,
    MULTIPLY,
    DIVIDE,
    LSUM,
    LMUL,
    XOR
)

ids = (
    ID,
)

constants = (
    HCONST,
    BCONST,
    FCONST
)

tokens = reserved + punctuators + operators + ids + constants

t_ignore = ' \t'


def t_NEWLINE(t):
    r'\n+'
    t.lexer.lineno += t.value.count('\n')


t_COMMA = r','
t_SEMICOLON = r';'
t_COLON = r':'
t_ASSIGN = r':='
t_LPAR = r'\('
t_RPAR = r'\)'
t_LBRACE = r'{'
t_RBRACE = r'}'
t_LBRACKET = r'\['
t_RBRACKET = r'\]'
t_HCONST = r'0x[0-9a-fA-F]+'
t_BCONST = r'0(B|b)[01]+'
t_FCONST = r'[0-9]*\.[0-9]+'

#arithmetic operations
t_MINUS = r'-'
t_PLUS = r'\+'
t_MULTIPLY = r'\*'
t_DIVIDE = r'/'
t_INR = r'\+\+'
t_DCR = r'--'
t_LSUM = r'\|'
t_LMUL = r'&'
t_XOR = r'\^'

# comparison operators
t_GREATER = r'>'
t_LESS = r'<'
t_EQUALS = r'==?'
t_NOTEQUALS = r'(!=|<>)'
t_GREQUALS = r'>='
t_LSEQUALS = r'<='

reserved_map = {}
for r in reserved:
    reserved_map[r.lower()] = r


def t_ID(t):
    r'[A-Za-z_][\w_]*'
    t.type = reserved_map.get(t.value, ID)
    return t

from ply.lex import LexError
class IllegalTokenException(LexError):
    def __init__(self, character, line_number):
        self.character = character
        self.line_number = line_number

    def __str__(self):
        return "Illegal character '{0}' at line {1}".format(self.character, self.line_number)


def t_error(t):
    t.lexer.skip(1)
    print("Illegal character '{0}' at line {1}".format(t.value[0], t.lineno))
    #raise IllegalTokenException(t.value[0], t.lineno)


def type_str(t):
    if t in reserved:
        return 'KEYWORD'
    if t in punctuators:
        return 'PUNCTUATOR'
    if t in operators:
        return 'OPERATOR'
    if t in ids:
        return 'ID'
    if t in constants:
        return 'CONSTANT'

def token_str(token):
    type = (str(type_str(token.type)) + ':').ljust(12, ' ')
    val = str(token.value).ljust(12, ' ')
    line = token.lineno
    return '{0}\t{1}\tline:{2}'.format(type, val, line)

import ply.lex as lex
lxr = lex.lex()
#a = dict(lxr)

def test(code, token_callback=None, error_callback=None):
    lxr.lineno = 1
    lxr.input(code)
    tokens = []
    errors = []
    while True:
        try:
            tok = lxr.token()
            if not tok:
                break
        except LexError as e:
            if error_callback:
                error_callback(e)
            errors.append(e)
        else:
            if token_callback:
                token_callback(tok)
            tokens.append(tok)
    return tokens, errors

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('file', help='path to file containing code to lex', nargs='?')
    args = parser.parse_args()

    if args.file:
        with open(args.file) as f:
            data = ''.join(f.readlines())
            test(data, lambda t: print(token_str(t)), lambda e: print(e))
    else:
        def get_results(tests):
            tokens = []
            errors = []
            for t in tests:
                cur_tokens, cur_errors = test(t)
                tokens.extend(cur_tokens)
                errors.extend(cur_errors)
            return tokens, errors

        # check variable names
        id_tests = ['a', '_a', 'a_', '_1', '1', '1_', 'A_B', 'A_1', 'A1']
        tokens, errors = get_results(id_tests)
        assert len(tokens) == 8
        assert all(t.type == ID for t in tokens)
        assert len(errors) == 2

        # check simple tokens
        op_tests = [';', '=', '==', ':=', '!=', '<', '>', '<>', '>=', '<=', '(', ')', 'for', 'for123']
        correct_types = [SEMICOLON, EQUALS, EQUALS, ASSIGN, NOTEQUALS, LESS, GREATER, NOTEQUALS, GREQUALS, LSEQUALS, LPAR,
                         RPAR, FOR, ID]
        tokens, errors = get_results(op_tests)
        assert len(tokens) == len(correct_types)
        assert all(p[0] == p[1] for p in zip((t.type for t in tokens), correct_types))
        assert len(errors) == 0

        # check hex numbers
        hex_tests = ['0x0', '0xf', '0f', 'f', '1', '-0x1']
        tokens, errors = get_results(hex_tests)
        assert len([t for t in tokens if t.type == HCONST]) == 3
        assert len(errors) == 2  # 'f' token is not an error

        random_test = '''for(a>b;a:=0xf;0xa) x==x
        x for 0x1
        x <> r
        x != 0x0
        '''
        tokens, errors = test(random_test)
        assert len(tokens) == 24
        assert len(errors) == 0