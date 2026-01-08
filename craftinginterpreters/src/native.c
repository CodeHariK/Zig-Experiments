#include "lox.h"

#include <time.h>

Value clockNative(int argCount, Value *args) {
  (void)argCount;
  (void)args;
  return (Value){VAL_NUMBER, {.number = (double)clock() / CLOCKS_PER_SEC}};
}

void defineNativeFunctions(Lox *lox) {
  // Define native functions
  envDefine(lox->env, NULL, "clock",
            (Value){VAL_NATIVE, {.native = clockNative}});
}
