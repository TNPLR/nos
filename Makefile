export CC=gcc
export CFLAGS=-ffreestanding -no-pie -fno-pic -std=gnu11 -mno-red-zone \
	      -Wall -I${PWD}/include -mcmodel=kernel -fno-stack-protector \
	      -fno-strict-aliasing -Wextra
export LD=ld
export LDFLAGS=
KERN64_OBJ=init/main.o \
					 drivers/text.o \
					 kernel/memory.o kernel/bitmap.o
.PHONY: all clean filesys boot init bochs qemu drivers kernel
all: hdd.img kernel64.elf
	@echo "========================================================"
	@echo "Please enter \"sudo make filesys\" to complete the image"
	@echo "========================================================"
boot:
	make -C boot/ all
init:
	make -C init/ all
drivers:
	make -C drivers/ all
kernel:
	make -C kernel/ all
filesys: hdd.img kernel64.elf
	losetup -o 16384 /dev/loop3 hdd.img
	mkfs.ext2 /dev/loop3
	mkdir mnt/
	mount /dev/loop3 mnt/
	cp boot/kernel.elf mnt/
	cp kernel64.elf mnt/
	umount mnt/
	rmdir mnt/
	losetup -d /dev/loop3
kernel64.elf: init drivers kernel
	${LD} ${LDFLAGS} -Tkernel/kernel64.ld -m elf_x86_64 ${KERN64_OBJ} -o $@
hdd.img: boot
	dd if=/dev/zero of=$@ bs=512 count=122880
	dd if=boot/mbr.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=boot/loader.bin of=$@ seek=2 bs=512 count=14 conv=notrunc
clean:
	rm -f hdd.img kernel64.elf
	make -C vmtest/ clean
	make -C boot/ clean
	make -C init/ clean
	make -C drivers/ clean
	make -C kernel/ clean
bochs:
	make -C vmtest/ bochs
qemu:
	make -C vmtest/ qemu
