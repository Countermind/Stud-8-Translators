from __future__ import print_function

__author__ = 'Kostya'

import pars
from lexer import test, token_str

if __name__ == '__main__':
    import argparse

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('file', help='path to file containing code to lex')

    out_group = arg_parser.add_mutually_exclusive_group()
    tree_group = out_group.add_mutually_exclusive_group()
    tree_group.add_argument('-tree', action='store_true', default=False)
    tree_group.add_argument('-notree', action='store_true')

    ast_group = out_group.add_mutually_exclusive_group()
    ast_group.add_argument('-ast', action='store_true', default=False)
    ast_group.add_argument('-noast', action='store_true')

    lexemes_group = arg_parser.add_mutually_exclusive_group()
    lexemes_group.add_argument('-lexemes', action='store_true', default=False)
    lexemes_group.add_argument('-nolexemes', action='store_true')

    output_code_group = arg_parser.add_mutually_exclusive_group()
    output_code_group.add_argument('-il', nargs=1, dest='output_dest')
    output_code_group.add_argument('-noil')

    args = arg_parser.parse_args()

    code = ''
    if args.file:
        with open(args.file) as f:
            code = ''.join(f.readlines())

    res, byte_code, errs = pars.yparse(code)
    if not res:
        print('There was an error parsing the code.')
    else:
        if args.tree:
            print('Parsed tree:')
            print(res)
        if args.ast:
                print('AST:')
                print(res.ast())
    if errs:
        print('Errors:')
        for e in errs:
            print(e)
    print('\n')

    if args.output_dest:
        if errs:
            print('There were errors compiling the code, cannot build 3ac.')
        else:
            with open(args.output_dest[0], 'w+') as f:
                f.write(byte_code)

    if args.lexemes:
        print('Lexemes:')
        test(code, lambda t: print(token_str(t)), lambda e: print(e))