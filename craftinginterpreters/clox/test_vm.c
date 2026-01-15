#include "clox.h"

int main(void) {
  VM vm;
  vmInit(&vm);

  interpret(&vm, "1 + 2 * 3");
  interpret(&vm, "1 == 2");
  interpret(&vm, "1 != 2");
  interpret(&vm, "1 > 2");
  interpret(&vm, "1 < 2");
  interpret(&vm, "1 >= 2");
  interpret(&vm, "1 <= 2");
  interpret(&vm, "!(5 - 4 > 3 * 2 == !nil)");
  interpret(&vm, "\"hello\" + \" \" + \"world\"");

  vmFree(&vm);
  return 0;
}
