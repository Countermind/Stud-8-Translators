__author__ = 'Kostya'
from node import Node, Leaf


class VariableType(object):
    type_binary = 'binary'
    type_hex = 'hexadecimal'
    type_bool = 'boolean'
    type_float = 'float'
    type_any = 'any'

    def __init__(self, var_type, array_dimensions=None, var_name=None):
        self.type = var_type
        if array_dimensions is None:
            self.array_dimensions = []
        self.array_dimensions = array_dimensions
        self.var_name = var_name
        self.original_variable = None

    @classmethod
    def get_type(cls, expr, defined_vars):
        if type(expr) is Node:
            return expr.type
        if type(expr) is Leaf:
            return expr.type
        types_table = {'HCONST': cls.type_hex,
                       'BCONST': cls.type_binary,
                       'FCONST': cls.type_float}
        if expr in types_table:
            return VariableType(types_table[expr])
        if defined_vars and expr in defined_vars:
            return defined_vars[expr]
        return None

    def can_cast(self, another, allow_rounding=True):
        if self is None:
            return False
        if self.type == VariableType.type_any:
            return True
        another_t = another
        if not type(another) is VariableType:
            another_t = VariableType(another)
        #if another_t.type is None and another_t.array_dimensions == self.array_dimensions:
        #    return True

        same_types = [
            [VariableType.type_bool]
        ]
        if allow_rounding:
            same_types.append([VariableType.type_binary, VariableType.type_hex, VariableType.type_float])
        else:
            same_types.append([VariableType.type_binary, VariableType.type_hex])
            same_types.append([VariableType.type_float])
        for t in same_types:
            if self.type in t and another_t.type in t and (self.array_dimensions == another_t.array_dimensions or
                                                        (not self.array_dimensions and not another_t.array_dimensions)):
                return True
        return False


class FunctionType(object):
    def __init__(self, return_type, params=None):
        self.return_type = return_type
        if params is None:
            self.params = []
        else:
            self.params = params

    @property
    def type(self):
        if self.return_type:
            return self.return_type.var_type
        return None