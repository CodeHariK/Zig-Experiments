#include "clox.h"

int main(void) {
  VM vm;
  vmInit(&vm);

  interpret(&vm, "1 + 2 * 3");

  vmFree(&vm);
  return 0;
}
