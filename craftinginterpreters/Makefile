CC      = clang
CFLAGS  = -std=c11 -Wall -Wextra -Wpedantic -O2
TARGET  = build/lox
SRC     = src/main.c src/lox.c src/debug.c src/expr.c src/parser.c src/scanner.c

.PHONY: all run clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)
