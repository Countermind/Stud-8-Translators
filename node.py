__author__ = 'Kostya'
from lexer import ids, reserved


class LeafError(object):
    def __init__(self, text, errorline):
        self.text = text
        self.error_line = errorline

    def __str__(self):
        return '{0} at line {1}'.format(self.text, self.error_line)


class Leaf(object):
    def __init__(self, parse, id):
        self.type = parse.slice[id].type
        self.value = parse.slice[id].value

    def __str__(self):
        return "{0} [{1}:'{2}']".format(self.type, 'name' if self.type in ids + reserved else 'text', self.value)

class Node(object):
    def __init__(self, name, children=None, leaf=None):
        if type(name) is str:
            self.type = type
        else:
            self.type = name.slice[0].type
        if children:
            self.children = children
        else:
            self.children = []
        self.leaf = leaf

    def lineno(self, n):
        return 1

    def to_tree(self):
        cur = '{0}/{1}\n'.format(self.type, 1 if self.leaf else len(self.children))
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

    def __str__(self):
        return self.to_tree()

