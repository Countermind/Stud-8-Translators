from __future__ import print_function
__author__ = 'Kostya'

import pars
from lexer import test, token_str

if __name__ == '__main__':
    import argparse

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('file', help='path to file containing code to lex')
    tree_group = arg_parser.add_mutually_exclusive_group()
    tree_group.add_argument('-tree', action='store_true')
    tree_group.add_argument('-notree', action='store_true')

    lexemes_group = arg_parser.add_mutually_exclusive_group()
    lexemes_group.add_argument('-lexemes', action='store_true')
    lexemes_group.add_argument('-nolexemes', action='store_true')

    args = arg_parser.parse_args()

    code = ''
    if args.file:
        with open(args.file) as f:
            code = ''.join(f.readlines())


    if args.tree:
        res = pars.yparse(code)
        if res:
            print('Parsed tree:')
            print(res)
        else:
            print('There was an error parsing the code.')
        print('\n')

    if args.lexemes:
        print('Lexemes:')
        test(code, lambda t: print(token_str(t)), lambda e: print(e))