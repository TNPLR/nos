ALL_OBJ=memory.o bitmap.o


.PHONY: clean all
all: ${ALL_OBJ}
%.o: %.c
	${CC} ${CFLAGS} -c $< -o $@
clean:
	rm -f *.o *.tmp *.bin *.img *.elf
