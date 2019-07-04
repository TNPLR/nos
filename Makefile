CC=gcc
LD=ld

.PHONY: all clean filesys
all: hdd.img
	@echo "========================================================"
	@echo "Please enter \"sudo make filesys\" to complete the image"
	@echo "========================================================"
filesys:
	losetup -o 16384 /dev/loop3 hdd.img
	mkfs.ext2 /dev/loop3
	mkdir mnt/
	mount /dev/loop3 mnt/
	cp kernel.elf mnt/
	umount mnt/
	rmdir mnt/
	losetup -d /dev/loop3
hdd.img: loader.bin mbr.bin kernel.elf
	dd if=/dev/zero of=$@ bs=512 count=122880
	dd if=./mbr.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=./loader.bin of=$@ seek=2 bs=512 count=14 conv=notrunc
loader.o: loader.S
	${CC} -c $<
loader.bin: loader.o
	${LD} -Tloader.ld $< -o $@
mbr.o: mbr.S
	${CC} -c $<
mbr.bin: mbr.o
	${LD} -Tloader.ld $< -o $@
kernel.elf:
	dd if=/dev/urandom of=$@ bs=512 count=32
clean:
	rm -f *.o *.tmp *.bin *.img *.elf
bochs:
	bochs -f bochs.ini
qemu:
	qemu-system-x86_64 -drive format=raw,file=hdd.img,if=none,id=disk -device ich9-ahci,id=ahci -device ide-drive,drive=disk,bus=ahci.0
