ALL_OBJ=text.o


.PHONY: clean
all: ${ALL_OBJ}
%.o: %.c
	${CC} ${CFLAGS} -c $< -o $@
clean:
	rm -f *.o *.tmp *.bin *.img *.elf
