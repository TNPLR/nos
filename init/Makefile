CC=gcc
CFLAGS=-ffreestanding -no-pie -fno-pic -std=gnu11 -mno-red-zone -Wall
LD=ld
TOAMD64=objcopy -I elf32-i386 -O elf64-x86-64 $@ $@
ALL_OBJ=main.o


.PHONY: clean
all: ${ALL_OBJ}
%.o: %.c
	${CC} ${CFLAGS} -c $< -o $@
clean:
	rm -f *.o *.tmp *.bin *.img *.elf
