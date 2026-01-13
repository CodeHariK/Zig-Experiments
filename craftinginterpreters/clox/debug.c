#include "clox.h"

#ifdef DEBUG_TRACE_EXECUTION

static void printStack(VM *vm) {
  printf("STACK ");
  for (Value *slot = vm->stack; slot < vm->stackTop; slot++) {
    printf("| ");
    printValue(*slot);
    printf(" ");
  }
  printf("|\n");
}

void traceExecution(VM *vm) {
  printStack(vm);
  instructionDisassemble(vm->chunk, (u32)(vm->ip - (u8 *)vm->chunk->code.data));
}
#else
void traceExecution(VM *vm) { (void)vm; }
#endif
