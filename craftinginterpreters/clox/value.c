#include "clox.h"
#include <stdio.h>

Value NIL_VAL = {VAL_NIL, {.boolean = false}};

Obj *allocateObject(VM *vm, size_t size, ObjType type) {
  return ALLOCATE_OBJ(vm, size, type);
}

ObjFunction *newFunction(VM *vm) {
  ObjFunction *function =
      (ObjFunction *)ALLOCATE_OBJ(vm, sizeof(ObjFunction), OBJ_FUNCTION);
  function->arity = 0;
  function->upvalueCount = 0;
  function->name = NULL;
  chunkInit(&function->chunk);
  return function;
}

ObjNative *newNative(VM *vm, NativeFn function) {
  ObjNative *native =
      (ObjNative *)ALLOCATE_OBJ(vm, sizeof(ObjNative), OBJ_NATIVE);
  native->function = function;
  return native;
}

ObjClosure *newClosure(VM *vm, ObjFunction *function) {
  ObjUpvalue **upvalues =
      (ObjUpvalue **)ALLOCATE(function->upvalueCount, sizeof(ObjUpvalue *));
  for (int i = 0; i < function->upvalueCount; i++) {
    upvalues[i] = NULL;
  }

  ObjClosure *closure =
      (ObjClosure *)ALLOCATE_OBJ(vm, sizeof(ObjClosure), OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalueCount = function->upvalueCount;
  return closure;
}

ObjUpvalue *newUpvalue(VM *vm, Value *slot) {
  ObjUpvalue *upvalue =
      (ObjUpvalue *)ALLOCATE_OBJ(vm, sizeof(ObjUpvalue), OBJ_UPVALUE);
  upvalue->closed = NIL_VAL;
  upvalue->location = slot;
  upvalue->next = NULL;
  return upvalue;
}

static u32 hashString(const char *key, i32 length) {
  u32 hash = 2166136261u;
  for (i32 i = 0; i < length; i++) {
    hash ^= (u8)key[i];
    hash *= 16777619;
  }
  return hash;
}

ObjString *copyString(VM *vm, const char *chars, i32 length) {
  u32 hash = hashString(chars, length);
  ObjString *interned = tableFindString(&vm->strings, chars, length, hash);
  if (interned != NULL)
    return interned;

  char *heapChars = (char *)ALLOCATE(length + 1, sizeof(char));
  memcpy(heapChars, chars, length);
  heapChars[length] = '\0';
  return allocateString(vm, heapChars, length, hash);
}

ObjString *allocateString(VM *vm, char *chars, i32 length, u32 hash) {
  ObjString *string =
      (ObjString *)ALLOCATE_OBJ(vm, sizeof(ObjString), OBJ_STRING);
  string->length = length;
  string->chars = chars;
  string->hash = hash;

  push(vm, OBJ_VAL((Obj *)string));
  tableSet(&vm->strings, string, NIL_VAL);
  pop(vm);

  return string;
}

ObjString *takeString(VM *vm, char *chars, i32 length) {
  u32 hash = hashString(chars, length);
  ObjString *interned = tableFindString(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    FREE_ARRAY(length + 1, sizeof(char), chars);
    return interned;
  }

  return allocateString(vm, chars, length, hash);
}

void concatenate(VM *vm) {
  // Use peek to keep strings on stack during allocation (GC protection)
  ObjString *b = AS_STRING(vm->stackTop[-1]);
  ObjString *a = AS_STRING(vm->stackTop[-2]);

  i32 length = a->length + b->length;
  char *chars = (char *)ALLOCATE(length + 1, sizeof(char));
  memcpy(chars, a->chars, a->length);
  memcpy(chars + a->length, b->chars, b->length);
  chars[length] = '\0';

  ObjString *result = takeString(vm, chars, length);
  pop(vm);
  pop(vm);
  push(vm, OBJ_VAL((Obj *)result));
}

// freeObject is defined in helper.c for GC

void freeObjects(VM *vm) {
  Obj *object = vm->objects;
  while (object != NULL) {
    Obj *next = object->next;
    // Use the freeObject from helper.c via sweep's pattern
    // Actually, just inline the freeing here for non-GC cleanup
    switch (object->type) {
    case OBJ_CLOSURE: {
      ObjClosure *closure = (ObjClosure *)object;
      FREE_ARRAY(closure->upvalueCount, sizeof(ObjUpvalue *),
                 closure->upvalues);
      FREE(sizeof(ObjClosure), object);
      break;
    }
    case OBJ_FUNCTION: {
      ObjFunction *function = (ObjFunction *)object;
      chunkFree(&function->chunk);
      FREE(sizeof(ObjFunction), object);
      break;
    }
    case OBJ_NATIVE: {
      FREE(sizeof(ObjNative), object);
      break;
    }
    case OBJ_STRING: {
      ObjString *string = (ObjString *)object;
      FREE_ARRAY(string->length + 1, sizeof(char), string->chars);
      FREE(sizeof(ObjString), object);
      break;
    }
    case OBJ_UPVALUE: {
      FREE(sizeof(ObjUpvalue), object);
      break;
    }
    }
    object = next;
  }

  free(vm->grayStack);
}

void initValueArray(ValueArray *array) {
  arrayInit(&array->values, sizeof(Value));
}

void writeValueArray(ValueArray *array, Value value) {
  arrayWrite(&array->values, &value);
}

void freeValueArray(ValueArray *array) {
  arrayFree(&array->values);
  initValueArray(array);
}

bool VAL_EQUAL(Value a, Value b) {
  if (a.type != b.type)
    return false;
  switch (a.type) {
  case VAL_BOOL:
    return AS_BOOL(a) == AS_BOOL(b);
  case VAL_NIL:
    return true;
  case VAL_NUMBER:
    return AS_NUMBER(a) == AS_NUMBER(b);
  case VAL_OBJ:
    return AS_OBJ(a) == AS_OBJ(b);
  default:
    return false; // Unreachable.
  }
}

static void printFunction(ObjFunction *function) {
  if (function->name == NULL) {
    printf("<script>");
    return;
  }
  printf("<fn %s>", function->name->chars);
}

void printObject(Value value) {
  switch (OBJ_TYPE(value)) {
  case OBJ_CLOSURE:
    printFunction(AS_CLOSURE(value)->function);
    break;
  case OBJ_FUNCTION:
    printFunction(AS_FUNCTION(value));
    break;
  case OBJ_NATIVE:
    printf("<native fn>");
    break;
  case OBJ_STRING:
    printf("%s", AS_CSTRING(value));
    break;
  case OBJ_UPVALUE:
    printf("upvalue");
    break;
  }
}

void printValue(Value value) {
  switch (value.type) {
  case VAL_BOOL:
    printf(AS_BOOL(value) ? "true" : "false");
    break;
  case VAL_NIL:
    printf("nil");
    break;
  case VAL_NUMBER:
    printf("%g", AS_NUMBER(value));
    break;
  case VAL_OBJ:
    printObject(value);
    break;
  default:
    printf("nil");
  }
}

void printValueToBuffer(VM *vm, Value value) {
  char temp[256];
  size_t len = 0;

  switch (value.type) {
  case VAL_BOOL:
    len = snprintf(temp, sizeof(temp), "%s", AS_BOOL(value) ? "true" : "false");
    break;
  case VAL_NIL:
    len = snprintf(temp, sizeof(temp), "nil");
    break;
  case VAL_NUMBER:
    len = snprintf(temp, sizeof(temp), "%g", AS_NUMBER(value));
    break;
  case VAL_OBJ:
    switch (OBJ_TYPE(value)) {
    case OBJ_CLOSURE: {
      ObjFunction *fn = AS_CLOSURE(value)->function;
      if (fn->name == NULL) {
        len = snprintf(temp, sizeof(temp), "<script>");
      } else {
        len = snprintf(temp, sizeof(temp), "<fn %s>", fn->name->chars);
      }
      break;
    }
    case OBJ_FUNCTION: {
      ObjFunction *fn = AS_FUNCTION(value);
      if (fn->name == NULL) {
        len = snprintf(temp, sizeof(temp), "<script>");
      } else {
        len = snprintf(temp, sizeof(temp), "<fn %s>", fn->name->chars);
      }
      break;
    }
    case OBJ_NATIVE:
      len = snprintf(temp, sizeof(temp), "<native fn>");
      break;
    case OBJ_STRING:
      len = snprintf(temp, sizeof(temp), "%s", AS_CSTRING(value));
      break;
    case OBJ_UPVALUE:
      len = snprintf(temp, sizeof(temp), "upvalue");
      break;
    }
    break;
  default:
    len = snprintf(temp, sizeof(temp), "nil");
    break;
  }

  // Append to buffer
  if (vm->printBufferLen + len < sizeof(vm->printBuffer) - 1) {
    memcpy(vm->printBuffer + vm->printBufferLen, temp, len);
    vm->printBufferLen += len;
    vm->printBuffer[vm->printBufferLen] = '\0';
  }
}

const char *vmGetPrintBuffer(VM *vm) { return vm->printBuffer; }

void vmClearPrintBuffer(VM *vm) {
  vm->printBuffer[0] = '\0';
  vm->printBufferLen = 0;
}
