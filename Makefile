all:
	flex calc.l
	bison -d calc.y
	clang *.c -o calc
