CC=gcc
LD=ld

.PHONY: all clean
all: hdd.img
hdd.img: loader.bin mbr.bin
	dd if=/dev/zero of=$@ bs=512 count=123880
	dd if=./mbr.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=./loader.bin of=$@ seek=2 bs=512 conv=notrunc
loader.o: loader.S
	${CC} -c $<
loader.bin: loader.o
	${LD} -Tloader.ld $< -o $@
mbr.o: mbr.S
	${CC} -c $<
mbr.bin: mbr.o
	${LD} -Tloader.ld $< -o $@
clean:
	rm -f *.o *.tmp *.bin *.img
bochs:
	bochs -f bochs.ini
qemu:
	qemu-system-x86_64 -drive format=raw,file=hdd.img,if=none,id=disk -device ich9-ahci,id=ahci -device ide-drive,drive=disk,bus=ahci.0
