# coding=utf-8
__author__ = 'Kostya'
import ply.yacc as yacc
import copy
import itertools

from lexer import tokens, lxr
from node import Node, Leaf
from variable_type import VariableType, FunctionType
from bytecode_formatter import FormatterState, ConditionLabels

precedence = (
    ('nonassoc', 'LESS', 'GREATER', 'GREQUALS', 'LSEQUALS'),
    ('right', 'ASSIGN'),
    ('right', 'PLUS', 'MINUS', 'LSUM'),
    ('right', 'MULTIPLY', 'DIVIDE', 'LMUL'),
    ('right', 'INR', 'DCR'),
    ('left', 'NOTEQUALS', 'EQUALS'),
    ('right', 'UMINUS')
)

defined_vars = {}
errors = []

bytecode_state = FormatterState()


def p_program_start(p):
    'program : compound_statement'
    p[0] = Node(p, [p[1]])


def p_statement_list(p):
    '''statement_list : statement SEMICOLON statement_list
                        | empty'''
    if len(p) == 2:
        p[0] = p[1]
    else:
        p[0] = Node(p, [p[1], Leaf(p, 2), p[3]])
        bytecode_state.reset_state()


def p_nonterminated_statement(p):
    '''statement_list : statement error statement_list'''
    errors.append('Missing semicolon, line {0}'.format(p.lineno(2)))
    p[0] = Node(p, [p[1], p[3]])


def p_statement(p):
    """statement : expression
                 | for_statement
                 | compound_statement
                 | if_statement
                 | while_statement
                 | dowhile_statement
                 | assign_statements"""
    p[0] = Node(p, [p[1]])
    p[0].type = p[1].type


def p_compound_statement(p):
    'compound_statement : LBRACE statement_list RBRACE'
    p[0] = Node(p, [Leaf(p, 1), p[2], Leaf(p, 3)])


def p_expression_numeric(p):
    'expression : numeric_expression'
    p[0] = p[1]


def p_expression_constants(p):
    """numeric_expression : id_expression
                          | letters"""
    p[0] = p[1]


def p_id_expression(p):
    'id_expression : ID'
    if p.slice[1].value not in defined_vars:
        errors.append('Attempt to use undefined variable \'{0}\' at line {1}'.format(p[1], p.lineno(1)))
    p[0] = Node(p, leaf=Leaf(p, 1), type=VariableType.get_type(p[1], defined_vars))


def p_literals_expression(p):
    """letters : HCONST
               | BCONST
               | FCONST"""
    p[0] = Node(p, leaf=Leaf(p, 1), type=VariableType.get_type(p.slice[1].type, defined_vars))
    if p.slice[1].type == 'BCONST':
        p[0].type.var_name = str(int(p[1], 2))
    elif p.slice[1].type == 'HCONST':
        p[0].type.var_name = str(int(p[1], 16))
    else:
        p[0].type.var_name = p[1]


def p_expression_comparison_operations(p):
    """expression : expression LESS expression
                  | expression GREATER expression
                  | expression GREQUALS expression
                  | expression LSEQUALS expression
                  | expression NOTEQUALS expression
                  | expression EQUALS expression"""
    if not VariableType.can_cast(VariableType.get_type(p[1], defined_vars), VariableType.get_type(p[3], defined_vars)):
        errors.append('Cannot perform \'{0}\' operation on different types at line {1}'.format(p[2], p.lineno(2)))
    p[0] = Node(p, [p[1], Leaf(p, 2), p[3]],
                type=VariableType(VariableType.type_bool, var_name=bytecode_state.reserve_var()))
    bytecode_state.code += '{0} := {1} {2} {3}\n'.format(p[0].type.var_name, p[1].type.var_name, p[2],
                                                         p[3].type.var_name)


def p_expression_arithmetic_operations(p):
    """numeric_expression : expression PLUS expression
                  | expression MINUS expression
                  | expression MULTIPLY expression
                  | expression DIVIDE expression
                  | MINUS expression %prec UMINUS"""
    expr_temp_var = bytecode_state.reserve_var()
    if len(p) > 3:
        if not (VariableType.can_cast(VariableType.get_type(p[1], defined_vars), VariableType.type_binary)
                and VariableType.can_cast(VariableType.get_type(p[3], defined_vars), VariableType.type_binary)):
            errors.append(
                'Cannot perform \'{0}\' operation for non-numeric types at line {1}'.format(p[2], p.lineno(2)))
        p[0] = Node(p, [p[1], Leaf(p, 2), p[3]], type=copy.deepcopy(VariableType.get_type(p[1], defined_vars)))
        bytecode_state.code += '{0} := {1} {2} {3}\n'.format(expr_temp_var, p[1].type.var_name, p[2],
                                                             p[3].type.var_name)
    else:
        if not (VariableType.can_cast(VariableType.get_type(p[2], defined_vars), VariableType.type_binary)):
            errors.append('Cannot perform unary minus at line {0}'.format(p.lineno(1)))
        p[0] = Node(p, [Leaf(p, 1), p[2]], type=copy.deepcopy(VariableType.get_type(p[1], defined_vars)))
        bytecode_state.code += '{0} := {1}{2}\n'.format(expr_temp_var, p[1], p[2].type.var_name)
    p[0].type.var_name = expr_temp_var


def p_expression_bool_arithmetic(p):
    """numeric_expression : expression LSUM expression
                  | expression LMUL expression
                  | expression XOR expression"""
    if VariableType.can_cast(p[1].type, VariableType.type_float, False) or \
            VariableType.can_cast(p[3].type, VariableType.type_float, False):
        errors.append('Cannot perform logic operations on float values, line {0}'.format(p.lineno(2)))
    p[0] = Node(p, [p[1], Leaf(p, 2), p[3]],
                type=copy.deepcopy(p[1].type) if VariableType.can_cast(p[1].type, VariableType.type_hex) else copy.deepcopy(p[3].type))
    expr_temp_var = bytecode_state.reserve_var()
    p[0].type.var_name = expr_temp_var
    bytecode_state.code += '{0} := {1} {2} {3}\n'.format(expr_temp_var, p[1].type.var_name, p[2],
                                                         p[3].type.var_name)


def p_exression_uoperation(p):
    """numeric_expression : INR expression
                  | DCR expression"""
    if not p[2].leaf or p[2].leaf.type != 'ID':
        errors.append('Cannot perform \'{0}\' operation at line {1}'.format(p[1], p.lineno(1)))
    p[0] = Node(p, [Leaf(p, 1), p[2]], type=p[2].type)
    bytecode_state.code += '{0} := {0} {1} 1\n'.format(p[2].type.var_name, p[1][0])


def p_different_assign_statement(p):
    """assign_statements : assign_statement
                         | declare"""
    p[0] = p[1]


def p_statement_assign(p):
    'assign_statement : id_expression array_indexes ASSIGN expression'
    id_type = copy.deepcopy(p[1].type)
    if len(p[2].children) > (len(id_type.array_dimensions) if id_type.array_dimensions else 0):
        errors.append('Attempt to access too deep into array, line {0}'.format(p.lineno(3)))
    elif p[2].children:
        id_type.array_dimensions = id_type.array_dimensions[len(p[2].children):]
    if not id_type.can_cast(VariableType.get_type(p[4], defined_vars)):
        errors.append('Cannot perform \'{0}\' operation on different types at line {1}'.format(p[3], p.lineno(3)))
    p[0] = Node(p, [p[1], p[2], Leaf(p, 3), p[4]])
    if p[2].children:
        array_index = calculate_index(p[2].children, p[1].type.array_dimensions)

        if p[4].type.array_dimensions:
            def get_array_elements(el):
                if el.expr == 'array_declare':
                    elements = []
                    for c in el.children:
                        cur_el = get_array_elements(c)
                        if isinstance(cur_el, list):
                            elements.extend(cur_el)
                        else:
                            elements.append(cur_el)
                    return elements
                return el.type.var_name
            els = get_array_elements(p[4].children[0])
        else:
            els = [p[4].type.var_name]
        for id, element in enumerate(els):
            bytecode_state.code += '{0}[{1}] := {2}\n'.format(p[1].type.var_name, array_index, element)
            if id < len(els) - 1:
                next_array_index = bytecode_state.reserve_var()
                bytecode_state.code += '{0} := {1} + 1\n'.format(next_array_index, array_index)
                array_index = next_array_index
    else:
        bytecode_state.code += '{0} := {1}\n'.format(p[1].type.var_name, p[4].type.var_name)


def p_statement_declare(p):
    """declare : type ID ASSIGN expression"""
    p[0] = Node(p, [p[1], Leaf(p, 2), Leaf(p, 3), p[4]])
    if p[2] not in defined_vars:
        cur_variable_type = copy.deepcopy(p[4].type)
        cur_variable_type.var_name = p[2]
        defined_vars[p[2]] = cur_variable_type
    t1 = p[1].type
    t2 = p[4].type
    t2_name = t2.var_name[:]
    if isinstance(t2.array_dimensions, list):
        t2_array_dimensions = t2.array_dimensions[:]
    else:
        t2_array_dimensions = t2.array_dimensions
    t2.array_dimensions = t1.array_dimensions
    if not t1.can_cast(t2, False) or (t1.array_dimensions is not None and t2_array_dimensions is not None and
                                              t1.array_dimensions != len(t2_array_dimensions)):
        errors.append('Cannot perform assign operation with different types at line {0}'.format(p.lineno(3)))
    bytecode_state.code += '{0} := {1}\n'.format(p[2], t2_name)


def p_type(p):
    """type : basic_type multiple_stars"""
    p[0] = Node(p, [p[1]], type=p[1].type)
    p[0].type.array_dimensions = p[2]


def p_basic_type(p):
    """basic_type : BINARY
                  | HEXADECIMAL
                  | FLOAT"""
    p[0] = Node(p, leaf=Leaf(p, 1), type=VariableType(p[1]))


def p_multiple_brackets(p):
    """multiple_stars : MULTIPLY multiple_stars
                         | empty"""
    if len(p) == 2:
        p[0] = 0
    else:
        p[0] = p[2] + 1


def p_expression_array_declare(p):
    'expression : array_declare'
    p[0] = Node(p, [p[1]], type=copy.deepcopy(p[1].type))
    array_name = bytecode_state.reserve_var()
    p[0].type.var_name = array_name[:]

    def define_array(arr, var_id):
        if arr.expr == 'array_declare':
            for item in arr.children:
                var_id = define_array(item, var_id)
        else:
            bytecode_state.code += '{0}[{1}] := {2}\n'.format(array_name, var_id, arr.type.var_name)
            return var_id + 1
        return var_id

    define_array(p[1], 0)


def p_array_declare(p):
    """array_declare : LBRACKET array_element array_params_list RBRACKET
                     | LBRACKET RBRACKET"""
    p[0] = Node(p, [], type=VariableType(None, [0]))
    if len(p) > 3:
        p[0].children.append(p[2])
        if p[3].children:
            p[0].children.extend(p[3].children)

        first_type = p[0].children[0].type
        for param in p[0].children:
            if not first_type.can_cast(param.type, True):
                errors.append('Nested array variables have different types, line {0}'.format(p.lineno(1)))
                break
        p[0].type = first_type
        if p[0].type.array_dimensions is None:
            p[0].type.array_dimensions = []
        p[0].type.array_dimensions.insert(0, len(p[0].children))


def p_array_inner(p):
    """array_element : numeric_expression
                     | array_declare"""
    p[0] = p[1]


def p_array_params(p):
    """array_params_list : COMMA array_element array_params_list
                         | empty"""
    if len(p) == 4:
        p[0] = Node(p, [p[2]])
        if p[3].children:
            p[0].children.extend(p[3].children)
    else:
        p[0] = p[1]


def p_def_array_access(p):
    'expression : array_access'
    p[0] = p[1]


def p_array_element_access(p):
    """array_access : expression index array_indexes"""
    access_depth = 1 + len(p[3].children)
    vartype = copy.deepcopy(p[1].type)
    if access_depth > len(vartype.array_dimensions):
        errors.append('Attempt to access too deep into array, line {0}'.format(p.lineno(2)))
    vartype.array_dimensions = vartype.array_dimensions[:-access_depth]
    vartype.var_name = bytecode_state.reserve_var()
    p[0] = Node(p, [p[1], p[2]], type=vartype)
    if p[3].children:
        p[0].children.extend(p[3].children)

    access_index = calculate_index(p[0].children[1:], p[1].type.array_dimensions)
    bytecode_state.code += '{0} := {1}[{2}]\n'.format(vartype.var_name, p[1].type.var_name,
                                                      access_index)


def calculate_index(index_arrays, dimensions):
    if len(index_arrays) == 1:
        return index_arrays[-1].type.var_name

    first_item = True
    cur_idx = 0
    for idx in index_arrays[:-1]:
        bytecode_state.code += '{0} := {1} * {2}\n'.format(bytecode_state.reserve_var(), idx.type.var_name,
                                                           dimensions[cur_idx])
        cur_idx += 1
        if not first_item:
            var_nums = bytecode_state.temp_var_number
            bytecode_state.code += '{0} := {1} + {2}\n'.format(bytecode_state.reserve_var(),
                                                               bytecode_state.temp_var(var_nums - 1),
                                                               bytecode_state.temp_var(var_nums - 2))
        else:
            first_item = False
    bytecode_state.code += '{0} := {1} + {2}\n'.format(bytecode_state.reserve_var(),
                                                       bytecode_state.temp_var(bytecode_state.temp_var_number - 2),
                                                       index_arrays[-1].type.var_name)
    return bytecode_state.last_var()


def p_array_access_list(p):
    """array_indexes : index array_indexes
                     | empty"""
    if len(p) == 2:
        #empty
        p[0] = p[1]
    else:
        p[0] = Node(p, [p[1]])
        if p[2].children:
            p[0].children.extend(p[2].children)


def p_array_element(p):
    'index : LBRACKET numeric_expression RBRACKET'
    if not p[2].type.can_cast(VariableType.type_binary, False):
        errors.append('Array indexes should be integer numbers, line {0}'.format(p.lineno(1)))
    p[0] = p[2]


def p_expression_group(p):
    'expression : LPAR expression RPAR'
    p[0] = Node(p, [Leaf(p, 1), p[2], Leaf(p, 3)], type=p[2].type)


def p_missing_rpar_error(p):
    """expression : LPAR expression error"""
    errors.append('Missing closing parenthesis, line {0}'.format(p.lineno(3)))
    p[0] = Node(p, [Leaf(p, 1), p[2]])


def p_loop_enter(p):
    'loop_enter :'
    bytecode_state.enter_loop()
    bytecode_state.code += bytecode_state.current_loop().label_start + ':\n'


def p_loop_leave(p):
    'loop_leave :'
    bytecode_state.code += bytecode_state.current_loop().label_end + ':\n'
    bytecode_state.leave_loop()


def p_for_statement(p):
    'for_statement : FOR LPAR for_declare SEMICOLON loop_enter for_cond SEMICOLON for_next RPAR compound_statement loop_leave'
    p[0] = Node(p,
                [Leaf(p, 1), Leaf(p, 2), p[3], Leaf(p, 4), p[6], Leaf(p, 7), p[8],
                 Leaf(p, 9), p[10]])


def p_for_declare_part(p):
    """for_declare : assign_statements
                   | empty"""
    p[0] = p[1]


def p_for_cond(p):
    """for_cond : expression
                | empty"""
    if p.slice[1].type == 'expression':
        if not VariableType.can_cast(p[1].type, VariableType.type_bool):
            errors.append('Conditional part of for statement should be of bool type, line {0}'.format(p.lineno(1)))
    p[0] = Node(p, [p[1]], type=p[1].type)
    bytecode_state.code += 'iffalse {0} goto {1}\n'.format(bytecode_state.last_var(),
                                                           bytecode_state.current_loop().label_end)


def p_for_expr(p):
    """for_next : expression
                | empty"""
    p[0] = p[1]


def p_while_statement(p):
    'while_statement : WHILE loop_enter while_condition COLON compound_statement loop_leave'
    if not VariableType.can_cast(VariableType.get_type(p[3], defined_vars), VariableType.type_bool):
        errors.append('Expression mus be boolean, line {0}'.format(p.lineno(1)))
    p[0] = Node(p, [Leaf(p, 1), p[3], Leaf(p, 4), p[5]])


def p_while_condition(p):
    'while_condition : expression'
    p[0] = Node(p, [p[1]], type=p[1].type)
    bytecode_state.code += 'iffalse {0} goto {1}\n'.format(bytecode_state.last_var(),
                                                           bytecode_state.current_loop().label_end)


def p_dowhile_statement(p):
    'dowhile_statement : DO loop_enter compound_statement WHILE dowhile_condition loop_leave'
    if not VariableType.can_cast(VariableType.get_type(p[5], defined_vars), VariableType.type_bool):
        errors.append('Expression mus be boolean, line {0}'.format(p.lineno(3)))
    p[0] = Node(p, [Leaf(p, 1), p[3], Leaf(p, 4), p[5]])


def p_dowhile_condition(p):
    'dowhile_condition : expression'
    p[0] = Node(p, [p[1]], type=p[1].type)
    bytecode_state.code += 'iftrue {0} goto {1}\n'.format(bytecode_state.last_var(),
                                                          bytecode_state.current_loop().label_start)


def p_break_continue_statement(p):
    """statement : BREAK
                 | CONTINUE"""
    p[0] = Node(p, leaf=Leaf(p, 1))
    if not bytecode_state.current_loop():
        errors.append('{0} should be nested in loop, line {1}'.format(p[1].title(), p.lineno(1)))
    else:
        bytecode_state.code += 'goto {0}\n'.format(
            bytecode_state.current_loop().label_end if p.slice[1].type == 'BREAK'
            else bytecode_state.current_loop().label_start)


def p_if_statement(p):
    """if_statement : IF expression enter_if COLON true_branch false_branch
                    | IF expression enter_if COLON true_branch"""
    if not VariableType.can_cast(VariableType.get_type(p[2], defined_vars), VariableType.type_bool):
        errors.append('Expression must be boolean, line {0}'.format(p.lineno(1)))
    p[0] = Node(p, [Leaf(p, 1), p[2], Leaf(p, 4), p[5]])
    if len(p) == 7:
        p[0].children.append(p[6])
    bytecode_state.code += bytecode_state.condition_stack.pop().label_end + ':\n'


def p_enter_if(p):
    'enter_if :'
    cond_labels = ConditionLabels(bytecode_state.reserve_label(), bytecode_state.reserve_label())
    bytecode_state.condition_stack.append(cond_labels)
    bytecode_state.code += 'iffalse {0} goto {1}\n'.format(bytecode_state.last_var(),
                                                           cond_labels.label_false)


def p_true_branch(p):
    'true_branch : compound_statement'
    p[0] = Node(p, [p[1]])
    if bytecode_state.condition_stack[-1].label_false:
        bytecode_state.code += 'goto {0}\n'.format(bytecode_state.condition_stack[-1].label_end)
        bytecode_state.code += bytecode_state.condition_stack[-1].label_false + ':\n'


def p_false_branch(p):
    """false_branch : ELSE COLON compound_statement"""
    p[0] = Node(p, [Leaf(p, 1), Leaf(p, 2), p[3]])


def p_func_call(p):
    """expression : func LPAR func_params RPAR"""
    if len(p[1].type.params) < len(p[3].children):
        errors.append('Attempt to call function with too much arguments, line {0}'.format(p.lineno(2)))
    elif len(p[1].type.params) > len(p[3].children):
        errors.append('Attempt to call function with not enough arguments, line {0}'.format(p.lineno(2)))
    elif any(itertools.starmap(lambda el1, el2: not el1.can_cast(el2),
                               zip(p[1].type.params, [c.type for c in p[3].children]))):
        errors.append('Parameter types of function call does not match declaration, line {0}'.format(p.lineno(2)))
    p[0] = Node(p, [p[1], p[3]], type=copy.deepcopy(p[1].type.return_type))
    if p[0].type.type:
        p[0].type.var_name = bytecode_state.reserve_var()
        bytecode_state.code += '{0} := call {1}, {2}\n'.format(p[0].type.var_name, p[1].leaf.value, len(p[3].children))
    else:
        bytecode_state.code += 'call {0}, {1}\n'.format(p[1].leaf.value, len(p[3].children))


def p_func_params(p):
    """func_params : expression func_params_list
                   | empty"""
    p[0] = Node(p, [])
    if len(p) > 2:
        p[0].children.append(p[1])
        if p[2].children:
            p[0].children.extend(p[2].children)
        for param in p[0].children:
            bytecode_state.code += 'param {0}\n'.format(param.type.var_name)


def p_func_params_list(p):
    """func_params_list : COMMA expression func_params_list
                        | empty"""
    if len(p) > 2:
        p[0] = Node(p, [p[2]])
        if p[3].children:
            p[0].children.extend(p[3].children)
    else:
        p[0] = p[1]


def p_func_print(p):
    """func : PRINT"""
    p[0] = Node(p, leaf=Leaf(p, 1), type=FunctionType(VariableType(None), [VariableType(VariableType.type_any)]))


def p_func_readi(p):
    """func : READI"""
    p[0] = Node(p, leaf=Leaf(p, 1), type=FunctionType(VariableType(VariableType.type_hex)))


def p_func_readf(p):
    """func : READF"""
    p[0] = Node(p, leaf=Leaf(p, 1), type=FunctionType(VariableType(VariableType.type_float)))


def p_empty(p):
    'empty :'
    p[0] = Node(p)


def p_error(p):
    if not p:
        print "Syntax error at EOF"
    else:
        errors.append('Unexpected symbol \'{0}\' at line {1}'.format(p.value, p.lineno))
        yacc.errok()
        return yacc.token()


yacc_parser = yacc.yacc(debug=True)


def yparse(data, debug=0):
    yacc_parser.error = 0
    lxr.lineno = 1
    p = yacc_parser.parse(data, debug=debug, lexer=lxr)
    if yacc_parser.error:
        return None
    return p, bytecode_state.code, errors