__author__ = 'Kostya'


class FormatterState(object):
    def __init__(self):
        self.temp_var_number = 1
        self.label_number = 1
        self.code = ''
        self._loop_stack = []
        self.condition_stack = []

    def reset_state(self):
        self.temp_var_number = 1

    def temp_var(self, number=None):
        format_number = self.temp_var_number
        if number:
            format_number = number
        return '@t{0}'.format(format_number)

    def last_var(self):
        return self.temp_var(self.temp_var_number - 1)

    def reserve_label(self):
        label = '@L{0}'.format(self.label_number)
        self.label_number += 1
        return label

    def reserve_var(self):
        var = self.temp_var()
        self.temp_var_number += 1
        return var

    def enter_loop(self):
        loop = LoopLabels(self.reserve_label(), self.reserve_label())
        self._loop_stack.append(loop)

    def leave_loop(self):
        self._loop_stack.pop()

    def current_loop(self):
        if self._loop_stack:
            return self._loop_stack[-1]
        return None


class LoopLabels(object):
    def __init__(self, label_start=None, label_end=None):
        self.label_start = label_start
        self.label_end = label_end


class ConditionLabels(object):
    def __init__(self, label_end, label_false=None):
        self.label_false = label_false
        self.label_end = label_end