.PHONY: all clean filesys boot
clean:
	rm -f bochsout.txt
bochs:
	bochs -f bochs.ini
qemu:
	qemu-system-x86_64 -drive file=../hdd.img,index=0,media=disk,if=ide,format=raw
