CC      = zig cc
CFLAGS_RELEASE = -std=c23 -O2 -DNDEBUG -fno-omit-frame-pointer

CFLAGS_DEBUG = -std=c23 -Wall -Wextra -Wpedantic -Og -g \
-fsanitize=address,undefined -fno-omit-frame-pointer

TARGET  = build/lox
SRC     = src/main.c src/arena.c src/lox.c src/debug.c src/parser.c src/scanner.c src/stmt.c
TEST_TARGET = build/test
TEST_SRC     = src/test.c src/arena.c src/lox.c src/debug.c src/parser.c src/scanner.c src/stmt.c

.PHONY: all run clean test

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
