CC      = gcc
CFLAGS_RELEASE = -std=c23 -O2 -DNDEBUG -fno-omit-frame-pointer

CFLAGS_DEBUG = -std=c23 -Wall -Wextra -Wpedantic -Og -g \
	-fsanitize=address,undefined -fno-omit-frame-pointer \
	-DDEBUG_TRACE_EXECUTION -DDEBUG_PARSER

TARGET  = build/risc
SRC       = src/main.c src/emulator.c src/cpu.c

.PHONY: all run clean test clean_vm test_vm

clean:
	rm -f $(TARGET) $(TEST_TARGET)
	rm -f test/test.txt

all: clean $(TARGET)

$(TARGET): $(SRC)
	@mkdir -p build
	$(CC) $(CFLAGS_RELEASE) -o $(TARGET) $(SRC) || { echo "Build failed! Exiting..."; exit 1; }

run: clean $(TARGET)
	./$(TARGET) $(FILE) > output.txt
