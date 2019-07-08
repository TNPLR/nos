TOAMD64=objcopy -I elf32-i386 -O elf64-x86-64 $@ $@
ALL_OBJ=loader.bin mbr.bin kernel.elf

.PHONY: clean all

all: ${ALL_OBJ}
asm_utility.o: asm_utility.S
	${CC} -c $<
	${TOAMD64}
loader.o: loader.S
	${CC} -c $<
	${TOAMD64}
loader.bin: loader.o asm_utility.o
	${LD} ${LDFLAGS}  -Tloader.ld $^ -o $@
mbr.o: mbr.S
	${CC} -c $<
mbr.bin: mbr.o
	${LD} ${LDFLAGS} -Tloader.ld $< -o $@
multiboot_header.o: multiboot_header.S
	${CC} -c $< -o $@
kernel.elf: multiboot_header.o
	${LD} ${LDFLAGS} -Tkernel.ld $^ -o $@ -m elf_x86_64
clean:
	rm -f *.o *.tmp *.bin *.img *.elf
