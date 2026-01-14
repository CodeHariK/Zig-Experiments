CC      = zig cc
CFLAGS_RELEASE = -std=c23 -O2 -DNDEBUG -fno-omit-frame-pointer

CFLAGS_DEBUG = -std=c23 -Wall -Wextra -Wpedantic -Og -g \
-fsanitize=address,undefined -fno-omit-frame-pointer \
-DDEBUG_TRACE_EXECUTION -DDEBUG_PARSER

TARGET  = build/lox
SRC       = src/main.c src/arena.c src/lox.c src/helper.c src/debug.c src/native.c src/parser.c src/scanner.c src/stmt.c src/eval.c src/exec.c src/env.c
TEST_TARGET = build/test
TEST_SRC  = src/test.c src/arena.c src/lox.c src/helper.c src/debug.c src/native.c src/parser.c src/scanner.c src/stmt.c src/eval.c src/exec.c src/env.c

.PHONY: all run clean test clean_vm test_vm

clean:
	rm -f $(TARGET) $(TEST_TARGET)
	rm test/test.txt

all: $(clean) $(TARGET)

$(TARGET): $(SRC)
	@mkdir -p build
	$(CC) $(CFLAGS_RELEASE) -o $(TARGET) $(SRC) || { echo "Build failed! Exiting..."; exit 1; }

run: $(clean) $(TARGET)
	./$(TARGET) $(FILE)

$(TEST_TARGET): $(TEST_SRC)
	@mkdir -p build
	$(CC) $(CFLAGS_DEBUG) -o $(TEST_TARGET) $(TEST_SRC) || { echo "Test build failed! Exiting..."; exit 1; }

# Test rule modification to ensure error reporting if test fails
test: ${clean} $(TEST_TARGET)
	@mkdir -p test
	./$(TEST_TARGET) > test/test.txt || { echo "Tests failed!"; exit 1; }
	grep -oiE '\b(passerror|pass|fail)\b' test/test.txt | sort | uniq -c
	

TEST_VM_TARGET = build/test_vm
TEST_VM_SRC  = clox/test_vm.c clox/debug.c clox/array.c clox/value.c clox/chunk.c clox/parser.c clox/scanner.c clox/vm.c

clean_vm:
	rm -f $(TEST_VM_TARGET)
	rm test/test_vm.txt

$(TEST_VM_TARGET): $(TEST_VM_SRC)
	@mkdir -p build
	$(CC) $(CFLAGS_DEBUG) -o $(TEST_VM_TARGET) $(TEST_VM_SRC) || { echo "Test build failed! Exiting..."; exit 1; }

build_vm: ${clean_vm} $(TEST_VM_SRC)
	@mkdir -p build
		$(CC) $(CFLAGS_DEBUG) -o $(TEST_VM_TARGET) $(TEST_VM_SRC)

test_vm: ${clean_vm} $(TEST_VM_TARGET)
	@mkdir -p test
	./$(TEST_VM_TARGET) > test/test_vm.txt || { echo "Tests failed!"; exit 1; }
	grep -oiE '\b(passerror|pass|fail)\b' test/test_vm.txt | sort | uniq -c
	
