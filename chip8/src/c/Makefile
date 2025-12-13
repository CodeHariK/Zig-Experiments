CC = clang
CFLAGS = -std=c11 -Wall -Wextra -O2

all: c8asm c8dasm

c8asm: asmmain.c c8asm.c chip8.c chip8.h
	$(CC) $(CFLAGS) asmmain.c c8asm.c chip8.c -o ../../roms/c8asm

c8dasm: dasmmain.c c8dasm.c chip8.c chip8.h
	$(CC) $(CFLAGS) dasmmain.c c8dasm.c chip8.c -o ../../roms/c8dasm

clean:
	rm -f ../../roms/c8asm ../../roms/c8dasm
