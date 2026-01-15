#include "clox.h"

int main(void) {
  VM vm;
  vmInit(&vm);

  interpret(&vm, "1 + 2 * 3;");
  interpret(&vm, "1 == 2;");
  interpret(&vm, "1 != 2;");
  interpret(&vm, "1 > 2;");
  interpret(&vm, "1 < 2;");
  interpret(&vm, "1 >= 2;");
  interpret(&vm, "1 <= 2;");
  interpret(&vm, "!(5 - 4 > 3 * 2 == !nil);");
  interpret(&vm, "\"hello\" + \" \" + \"world\";");
  interpret(&vm, "print 1 + 2 * 3;");
  interpret(&vm, "print \"hello\" + \" \" + \"world\";");
  interpret(&vm, "var hello = \"hello\"; var world = \"world\"; "
                 "hello = hello + \" \" + world; print hello;");

  vmFree(&vm);
  return 0;
}
