#include "clox.h"
#include <stdarg.h>
#include <time.h>

static void resetStack(VM *vm) {
  vm->stackTop = vm->stack;
  vm->frameCount = 0;
  vm->openUpvalues = NULL;
}

static void runtimeError(VM *vm, const char *format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fputs("\n", stderr);

  for (int i = vm->frameCount - 1; i >= 0; i--) {
    CallFrame *frame = &vm->frames[i];
    ObjFunction *function = frame->closure->function;
    size_t instruction = frame->ip - getCodeArr(&function->chunk) - 1;
    fprintf(stderr, "[line %d] in ", getLineArr(&function->chunk)[instruction]);
    if (function->name == NULL) {
      fprintf(stderr, "script\n");
    } else {
      fprintf(stderr, "%s()\n", function->name->chars);
    }
  }

  resetStack(vm);
}

static Value clockNative(int argCount, Value *args) {
  (void)argCount;
  (void)args;
  return NUMBER_VAL((double)clock() / CLOCKS_PER_SEC);
}

static void defineNative(VM *vm, const char *name, NativeFn function) {
  push(vm, OBJ_VAL((Obj *)copyString(vm, name, (i32)strlen(name))));
  push(vm, OBJ_VAL((Obj *)newNative(vm, function)));
  tableSet(&vm->globals, AS_STRING(vm->stack[0]), vm->stack[1]);
  pop(vm);
  pop(vm);
}

void vmInit(VM *vm) {
  resetStack(vm);
  vm->objects = NULL;
  vm->compiler = NULL;
  vm->bytesAllocated = 0;
  vm->nextGC = 1024 * 1024;
  vm->grayCount = 0;
  vm->grayCapacity = 0;
  vm->grayStack = NULL;
  initTable(&vm->globals);
  initTable(&vm->strings);
  vm->printBuffer[0] = '\0';
  vm->printBufferLen = 0;

  defineNative(vm, "clock", clockNative);
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

static bool call(VM *vm, ObjClosure *closure, int argCount) {
  if (argCount != closure->function->arity) {
    runtimeError(vm, "Expected %d arguments but got %d.",
                 closure->function->arity, argCount);
    return false;
  }

  if (vm->frameCount == FRAMES_MAX) {
    runtimeError(vm, "Stack overflow.");
    return false;
  }

  CallFrame *frame = &vm->frames[vm->frameCount++];
  frame->closure = closure;
  frame->ip = getCodeArr(&closure->function->chunk);
  frame->slots = vm->stackTop - argCount - 1;
  return true;
}

static bool callValue(VM *vm, Value callee, int argCount) {
  if (IS_OBJ(callee)) {
    switch (OBJ_TYPE(callee)) {
    case OBJ_CLOSURE:
      return call(vm, AS_CLOSURE(callee), argCount);
    case OBJ_NATIVE: {
      NativeFn native = AS_NATIVE(callee);
      Value result = native(argCount, vm->stackTop - argCount);
      vm->stackTop -= argCount + 1;
      push(vm, result);
      return true;
    }
    default:
      break; // Non-callable object type.
    }
  }
  runtimeError(vm, "Can only call functions and classes.");
  return false;
}

static ObjUpvalue *captureUpvalue(VM *vm, Value *local) {
  ObjUpvalue *prevUpvalue = NULL;
  ObjUpvalue *upvalue = vm->openUpvalues;
  while (upvalue != NULL && upvalue->location > local) {
    prevUpvalue = upvalue;
    upvalue = upvalue->next;
  }

  if (upvalue != NULL && upvalue->location == local) {
    return upvalue;
  }

  ObjUpvalue *createdUpvalue = newUpvalue(vm, local);
  createdUpvalue->next = upvalue;

  if (prevUpvalue == NULL) {
    vm->openUpvalues = createdUpvalue;
  } else {
    prevUpvalue->next = createdUpvalue;
  }

  return createdUpvalue;
}

static void closeUpvalues(VM *vm, Value *last) {
  while (vm->openUpvalues != NULL && vm->openUpvalues->location >= last) {
    ObjUpvalue *upvalue = vm->openUpvalues;
    upvalue->closed = *upvalue->location;
    upvalue->location = &upvalue->closed;
    vm->openUpvalues = upvalue->next;
  }
}

static InterpretResult run(VM *vm) {
  CallFrame *frame = &vm->frames[vm->frameCount - 1];

#define READ_BYTE() (*frame->ip++)
#define READ_SHORT()                                                           \
  (frame->ip += 2, (u16)((frame->ip[-2] << 8) | frame->ip[-1]))
#define READ_CONSTANT()                                                        \
  (getConstantArr(&frame->closure->function->chunk)[READ_BYTE()])
#define READ_STRING() AS_STRING(READ_CONSTANT())

  for (;;) {

    traceExecution(vm);

    u8 instruction;
    switch (instruction = READ_BYTE()) {
    case OP_CONSTANT: {
      Value constant = READ_CONSTANT();
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
      printValueToBuffer(vm, pop(vm));
      size_t len = vm->printBufferLen;
      if (len < sizeof(vm->printBuffer) - 1) {
        vm->printBuffer[len] = '\n';
        vm->printBuffer[len + 1] = '\0';
        vm->printBufferLen++;
      }
      break;
    }

    case OP_GET_LOCAL: {
      u8 slot = READ_BYTE();
      push(vm, frame->slots[slot]);
      break;
    }

    case OP_SET_LOCAL: {
      u8 slot = READ_BYTE();
      frame->slots[slot] = peek(vm, 0);
      break;
    }

    case OP_GET_UPVALUE: {
      u8 slot = READ_BYTE();
      push(vm, *frame->closure->upvalues[slot]->location);
      break;
    }

    case OP_SET_UPVALUE: {
      u8 slot = READ_BYTE();
      *frame->closure->upvalues[slot]->location = peek(vm, 0);
      break;
    }

    case OP_GET_GLOBAL: {
      ObjString *name = READ_STRING();
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
      ObjString *name = READ_STRING();
      if (tableSet(&vm->globals, name, peek(vm, 0))) {
        tableDelete(&vm->globals, name);
        runtimeError(vm, "Undefined variable '%.*s'.", (i32)name->length,
                     name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }

    case OP_DEFINE_GLOBAL: {
      ObjString *name = READ_STRING();
      tableSet(&vm->globals, name, peek(vm, 0));
      pop(vm);
      break;
    }

    case OP_JUMP: {
      u16 offset = READ_SHORT();
      frame->ip += offset;
      break;
    }

    case OP_JUMP_IF_FALSE: {
      u16 offset = READ_SHORT();
      if (isFalsey(peek(vm, 0)))
        frame->ip += offset;
      break;
    }

    case OP_LOOP: {
      u16 offset = READ_SHORT();
      frame->ip -= offset;
      break;
    }

    case OP_CALL: {
      int argCount = READ_BYTE();
      if (!callValue(vm, peek(vm, argCount), argCount)) {
        return INTERPRET_RUNTIME_ERROR;
      }
      frame = &vm->frames[vm->frameCount - 1];
      break;
    }

    case OP_CLOSURE: {
      ObjFunction *function = AS_FUNCTION(READ_CONSTANT());
      ObjClosure *closure = newClosure(vm, function);
      push(vm, OBJ_VAL((Obj *)closure));
      for (int i = 0; i < closure->upvalueCount; i++) {
        u8 isLocal = READ_BYTE();
        u8 index = READ_BYTE();
        if (isLocal) {
          closure->upvalues[i] = captureUpvalue(vm, frame->slots + index);
        } else {
          closure->upvalues[i] = frame->closure->upvalues[index];
        }
      }
      break;
    }

    case OP_CLOSE_UPVALUE:
      closeUpvalues(vm, vm->stackTop - 1);
      pop(vm);
      break;

    case OP_RETURN: {
      Value result = pop(vm);
      closeUpvalues(vm, frame->slots);
      vm->frameCount--;
      if (vm->frameCount == 0) {
        pop(vm);
        return INTERPRET_OK;
      }

      vm->stackTop = frame->slots;
      push(vm, result);
      frame = &vm->frames[vm->frameCount - 1];
      break;
    }
    }
  }

#undef READ_BYTE
#undef READ_SHORT
#undef READ_CONSTANT
#undef READ_STRING
}

InterpretResult interpret(VM *vm, const char *source) {
  Scanner scanner;
  initScanner(&scanner, source);
  vm->scanner = &scanner;

  Parser parser;
  parser.hadError = false;
  parser.panicMode = false;
  vm->parser = &parser;

  ObjFunction *function = compile(vm);
  if (function == NULL)
    return INTERPRET_COMPILE_ERROR;

  push(vm, OBJ_VAL((Obj *)function));
  ObjClosure *closure = newClosure(vm, function);
  pop(vm);
  push(vm, OBJ_VAL((Obj *)closure));
  call(vm, closure, 0);

  return run(vm);
}
