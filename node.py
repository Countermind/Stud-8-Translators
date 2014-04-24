__author__ = 'Kostya'
from lexer import ids, reserved


class Leaf(object):
    def __init__(self, parse, id):
        self.type = parse.slice[id].type
        self.value = parse.slice[id].value

    def __str__(self):
        return "{0} [{1}:'{2}']".format(self.type, 'name' if self.type in ids + reserved else 'text', self.value)

    def to_ast(self):
        return str(self) + '\n'

    def ast(self):
        return str(self)


class Node(object):
    def __init__(self, prod, children=None, leaf=None, type=None):
        self.expr = prod.slice[0].type
        if children:
            self.children = children
        else:
            self.children = []
        self.leaf = leaf
        self.type = type

    def _get_statements(self):
        if self.expr != 'statement_list' or len(self.children) < 3:
            return None
        statements = [self.children[0]]
        child_st = self.children[2]._get_statements()
        if child_st:
            statements.extend(child_st)
        return statements

    def to_tree(self):
        cur = '{0}/{1}\n'.format(self.expr, 1 if self.leaf else len(self.children))
        child_num = 1
        child_text = ''
        if self.leaf:
            child_text = '{0} {1}'.format(child_num, self.leaf)
        else:
            for c in self.children:
                child_text += '{0} {1}\n'.format(child_num, c)
                child_num += 1
        cur += '\n'.join('  ' + s for s in child_text.split('\n') if s != '') + '\n'
        return cur

    def _append_to(self, txt, val='  '):
        append_to_end = ''
        if txt.endswith('\n'):
            append_to_end = '\n'
        res = '\n'.join(val + s for s in txt.split('\n') if s != '') + append_to_end
        return res

    def ast(self):
        if self.expr == 'program':
            return self.children[0].ast()
        if self.expr == 'compound_statement':
            self.expr = 'S'
            self.children = [c.ast() for c in self.children[1:-1]]
            return self
        if self.expr == 'statement_list':
            self.children = self._get_statements()
            self.expr = 'L'
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'expression':
            if hasattr(self.children[0], 'value') and self.children[0].type == 'LPAR':
                return self.children[1].ast()
            if len(self.children) == 3:
                self.expr = self.children[1].value
                del self.children[1]
                self.children = [c.ast() for c in self.children]
                return self
            if len(self.children) == 2:
                self.expr = 'call'
                self.children.extend(self.children[1].children)
                del self.children[1]
                self.children = [c.ast() for c in self.children]
                return self
        if self.expr == 'numeric_expression':
            if len(self.children) == 2:
                self.expr = self.children[0]
                self.children = [c.ast() for c in self.children[1:]]
                return self
            if len(self.children) == 3:
                self.expr = self.children[1]
                del self.children[1]
                self.children = [c.ast() for c in self.children]
                return self
        if self.expr == 'array_declare':
            self.expr = 'array'
            self.children = [c.ast() for c in self.children]
        if self.expr == 'array_access':
            self.expr = 'index'
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'index':
            return self.children[1].ast()
        if self.expr == 'assign_statement':
            self.expr = self.children[2]
            del self.children[2]
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'declare':
            self.expr = self.children[2]
            del self.children[2]
            self.children = [c.ast() for c in self.children[1:]]
            return self
        if self.expr == 'for_statement':
            self.expr = 'C'
            self.children = [c.ast() for c in [self.children[idx] for idx in (2, 4, 6, 8)]]
            return self
        if self.expr == 'while_statement' or self.expr == 'dowhile_statement':
            self.expr = 'C'
            self.children = [c.ast() for c in [self.children[idx] for idx in (1, 3)]]
            return self
        if self.expr in ('for_cond', 'while_condition', 'dowhile_condition'):
            self.expr = 'cond'
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'if_statement':
            self.expr = 'flow'
            del self.children[0]
            del self.children[1]
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'true_branch':
            self.children = [c.ast() for c in self.children]
            return self
        if self.expr == 'false_branch':
            self.children = [self.children[-1].ast()]
            return self
        if len(self.children) == 1:
            return self.children[0].ast()
        if self.leaf:
            return self.leaf.ast()
        return self


    def __str__(self):
        return self.to_tree()