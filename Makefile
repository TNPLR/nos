.PHONY: all clean filesys boot
all: hdd.img
	@echo "========================================================"
	@echo "Please enter \"sudo make filesys\" to complete the image"
	@echo "========================================================"
boot:
	make -C boot/ all
filesys: hdd.img
	losetup -o 16384 /dev/loop3 hdd.img
	mkfs.ext2 /dev/loop3
	mkdir mnt/
	mount /dev/loop3 mnt/
	cp boot/kernel.elf mnt/
	umount mnt/
	rmdir mnt/
	losetup -d /dev/loop3
hdd.img: boot
	dd if=/dev/zero of=$@ bs=512 count=122880
	dd if=boot/mbr.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=boot/loader.bin of=$@ seek=2 bs=512 count=14 conv=notrunc
clean:
	rm -f hdd.img
	make -C vmtest/ clean
	make -C boot/ clean
bochs:
	make -C vmtest/ bochs
qemu:
	make -C vmtest/ qemu
