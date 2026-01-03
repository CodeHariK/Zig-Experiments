CC      = zig cc
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -O2 -g \
         -fsanitize=address,undefined
TARGET  = build/lox
SRC     = src/main.c src/arena.c src/lox.c src/debug.c src/expr.c src/parser.c src/scanner.c src/stmt.c
TEST_TARGET = build/test
TEST_SRC     = src/test.c src/arena.c src/lox.c src/debug.c src/expr.c src/parser.c src/scanner.c src/stmt.c

.PHONY: all run clean test

all: $(TARGET)

$(TARGET): $(SRC)
	@mkdir -p build
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

run: $(TARGET)
	./$(TARGET) $(FILE)

$(TEST_TARGET): $(TEST_SRC)
	@mkdir -p build
	$(CC) $(CFLAGS) -o $(TEST_TARGET) $(TEST_SRC)

test: $(TEST_TARGET)
	./$(TEST_TARGET) > test/test.txt
    
clean:
	rm -f $(TARGET) $(TEST_TARGET)
