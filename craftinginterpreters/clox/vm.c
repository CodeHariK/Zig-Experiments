#include "clox.h"

static inline u8 readByte(VM *vm) { return *vm->ip++; }

static void resetStack(VM *vm) { vm->stackTop = vm->stack; }

void vmInit(VM *vm) {
  vm->chunk = NULL;
  vm->ip = NULL;
  vm->stackTop = vm->stack;
}

void vmFree(VM *vm) {}

void push(VM *vm, Value value) {
  if (vm->stackTop < vm->stack + STACK_MAX) {
    *vm->stackTop = value;
    vm->stackTop++;
  }
}

Value pop(VM *vm) {
  vm->stackTop--;
  return *vm->stackTop;
}

static InterpretResult run(VM *vm) {

  for (;;) {

    traceExecution(vm);

    uint8_t instruction;
    switch (instruction = readByte(vm)) {
    case OP_CONSTANT: {
      Value constant = getChunkConstant(vm->chunk, readByte(vm));
      push(vm, constant);
      break;
    }
    case OP_ADD: {
      double b = pop(vm);
      double a = pop(vm);
      push(vm, a + b);
      break;
    }
    case OP_SUBTRACT: {
      double b = pop(vm);
      double a = pop(vm);
      push(vm, a - b);
      break;
    }
    case OP_MULTIPLY: {
      double b = pop(vm);
      double a = pop(vm);
      push(vm, a * b);
      break;
    }
    case OP_DIVIDE: {
      double b = pop(vm);
      double a = pop(vm);
      push(vm, a / b);
      break;
    }
    case OP_NEGATE: {
      push(vm, -pop(vm));
      break;
    }
    case OP_RETURN: {
      printValue(pop(vm));
      printf("\n");
      return INTERPRET_OK;
    }
    }
  }
}

InterpretResult interpret(VM *vm, const char *source) {

  Chunk chunk;
  chunkInit(&chunk);

  vm->chunk = &chunk;
  vm->ip = vm->chunk->code.data;

  Scanner scanner;
  initScanner(&scanner, source);
  vm->scanner = &scanner;

  Parser parser;
  parser.hadError = false;
  parser.panicMode = false;
  vm->parser = &parser;

  if (!compile(vm)) {
    chunkFree(&chunk);
    return INTERPRET_COMPILE_ERROR;
  }

  vm->ip = vm->chunk->code.data;
  InterpretResult result = run(vm);

  chunkFree(&chunk);
  return result;
}
