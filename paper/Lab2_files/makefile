CFLAGS=-g -Wall
YACC=bison --report=all -d -l -o language.tab.c
LEX=flex
LFLAGS=-i -o lex.yy.c --noline

# Things that get included in our Yacc file
INCLUDED_FILES = \
	parse-tree.h \
	parse-tree.c 

# The various .o files that are needed for executables.
OBJECT_FILES = language.tab.o 

default: print-tree

print-tree: print-tree.o $(OBJECT_FILES)
	$(LINK.o) -o $@ $^

language.tab.o: language.tab.c lex.yy.c $(INCLUDED_FILES)

language.tab.c: language.yy
	$(YACC) $(YFLAGS) $^

lex.yy.c: lexer.ll
	$(LEX) $(LFLAGS) $^

clean-all:
	make clean
	-rm -f print-tree

clean:
	-rm -f *.o
	-rm -f language.output
	-rm -f language.tab.*
	-rm -f lex.yy.c

