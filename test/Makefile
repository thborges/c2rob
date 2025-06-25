SFILES = $(patsubst cfiles/%.c,out/%.s,$(wildcard cfiles/*.c))
ARCH = atmega328p
DUMP = avr-objdump

.SUFFIXES:

all : out ${SFILES}

count:
	@echo "Success: " `ls out/*.s | wc -l`

out :
	mkdir -p out

.PRECIOUS: out/%.rob
.DELETE_ON_ERROR:
out/%.rob : cfiles/%.c | ../c2rob
	../c2rob $< > $@

out/%.o : out/%.rob
	robcmp -I .. -bdep -a ${ARCH} $< -o $@

out/%.s : out/%.o
	${DUMP} -D $< > $@

clean:
	rm -f out/*
