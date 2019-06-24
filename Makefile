CC=gcc
LD=ld

.PHONY: all clean
all: loader.bin
loader.o: loader.S
	${CC} -c $<
loader.bin: loader.o
	${LD} -Tloader.ld $< -o loader.tmp
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=./loader.tmp of=$@ bs=512 conv=notrunc
	rm -f loader.tmp
clean:
	rm -f *.o *.tmp *.bin
bochs:
	bochs -f bochs.ini
qemu:
	qemu-system-x86_64 -drive format=raw,if=floppy,file=loader.bin
