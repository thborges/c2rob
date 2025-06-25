all:
	flex c2rob.l
	bison -d c2rob.y
	clang++ -std=c++20 -g -O1 *.c -o c2rob
