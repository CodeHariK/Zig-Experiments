#include "clox.h"
#include <stdarg.h>

static inline u8 READ_BYTE(VM *vm) { return *vm->ip++; }

static inline Value READ_CONSTANT(VM *vm) {
  return getConstantArr(vm->chunk)[READ_BYTE(vm)];
}

static inline ObjString *READ_STRING(VM *vm) {
  return AS_STRING(READ_CONSTANT(vm));
}

static void resetStack(VM *vm) {
  vm->stackTop = vm->stack;
  vm->objects = NULL;
}

static void runtimeError(VM *vm, const char *format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fputs("\n", stderr);

  size_t instruction = vm->ip - getCodeArr(vm->chunk) - 1;
  i32 line = getLineArr(vm->chunk)[instruction];
  fprintf(stderr, "[line %d] in script\n", line);
  resetStack(vm);
}

void vmInit(VM *vm) {
  vm->chunk = NULL;
  vm->ip = NULL;
  vm->stackTop = vm->stack;
  vm->objects = NULL;
  initTable(&vm->globals);
  initTable(&vm->strings);
}

void vmFree(VM *vm) {
  freeTable(&vm->globals);
  freeTable(&vm->strings);
  freeObjects(vm);
}

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

static inline Value peek(VM *vm, i32 distance) {
  return vm->stackTop[-1 - distance];
}

static InterpretResult run(VM *vm) {

  for (;;) {

    traceExecution(vm);

    u8 instruction;
    switch (instruction = READ_BYTE(vm)) {
    case OP_CONSTANT: {
      Value constant = getConstantArr(vm->chunk)[READ_BYTE(vm)];
      push(vm, constant);
      break;
    }
    case OP_NIL:
      push(vm, NIL_VAL);
      break;
    case OP_TRUE:
      push(vm, BOOL_VAL(true));
      break;
    case OP_FALSE:
      push(vm, BOOL_VAL(false));
      break;

    case OP_EQUAL: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(VAL_EQUAL(a, b)));
      break;
    }
    case OP_NOT_EQUAL: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(!VAL_EQUAL(a, b)));
      break;
    }
    case OP_GREATER: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(AS_NUMBER(a) > AS_NUMBER(b)));
      break;
    }
    case OP_LESS: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(AS_NUMBER(a) < AS_NUMBER(b)));
      break;
    }
    case OP_GREATER_EQUAL: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(AS_NUMBER(a) >= AS_NUMBER(b)));
      break;
    }
    case OP_LESS_EQUAL: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, BOOL_VAL(AS_NUMBER(a) <= AS_NUMBER(b)));
      break;
    }

    case OP_ADD: {
      if (IS_STRING(peek(vm, 0)) && IS_STRING(peek(vm, 1))) {
        concatenate(vm);
      } else if (IS_NUMBER(peek(vm, 0)) && IS_NUMBER(peek(vm, 1))) {
        double b = AS_NUMBER(pop(vm));
        double a = AS_NUMBER(pop(vm));
        push(vm, NUMBER_VAL(a + b));
      } else {
        runtimeError(vm, "Operands must be two numbers or two strings.");
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }
    case OP_SUBTRACT: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, NUMBER_VAL(AS_NUMBER(a) - AS_NUMBER(b)));
      break;
    }
    case OP_MULTIPLY: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, NUMBER_VAL(AS_NUMBER(a) * AS_NUMBER(b)));
      break;
    }
    case OP_DIVIDE: {
      Value b = pop(vm);
      Value a = pop(vm);
      push(vm, NUMBER_VAL(AS_NUMBER(a) / AS_NUMBER(b)));
      break;
    }

    case OP_NOT: {
      push(vm, BOOL_VAL(isFalsey(pop(vm))));
      break;
    }
    case OP_NEGATE: {
      if (!IS_NUMBER(peek(vm, 0))) {
        runtimeError(vm, "Operand must be a number.");
        return INTERPRET_RUNTIME_ERROR;
      }
      push(vm, NUMBER_VAL(-AS_NUMBER(pop(vm))));
      break;
    }

    case OP_POP:
      pop(vm);
      break;

    case OP_PRINT: {
      printValue(pop(vm));
      printf("\n");
      break;
    }

    case OP_GET_GLOBAL: {
      ObjString *name = READ_STRING(vm);
      Value value;
      if (!tableGet(&vm->globals, name, &value)) {
        runtimeError(vm, "Undefined variable '%.*s'.", (i32)name->length,
                     name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      push(vm, value);
      break;
    }

    case OP_SET_GLOBAL: {
      ObjString *name = READ_STRING(vm);
      if (tableSet(&vm->globals, name, peek(vm, 0))) {
        tableDelete(&vm->globals, name);
        runtimeError(vm, "Undefined variable '%.*s'.", (i32)name->length,
                     name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }

    case OP_DEFINE_GLOBAL: {
      ObjString *name = READ_STRING(vm);
      tableSet(&vm->globals, name, peek(vm, 0));
      pop(vm);
      break;
    }

    case OP_RETURN: {
      // Exit interpreter.
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
