#include "clox.h"

Value NIL_VAL = {VAL_NIL, {.boolean = false}};

Obj *allocateObject(VM *vm, size_t size, ObjType type) {
  return ALLOCATE_OBJ(vm, size, type);
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
  tableSet(&vm->strings, string, NIL_VAL);
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
  ObjString *b = AS_STRING(pop(vm));
  ObjString *a = AS_STRING(pop(vm));

  i32 length = a->length + b->length;
  char *chars = (char *)ALLOCATE(length + 1, sizeof(char));
  memcpy(chars, a->chars, a->length);
  memcpy(chars + a->length, b->chars, b->length);
  chars[length] = '\0';

  ObjString *result = takeString(vm, chars, length);
  push(vm, OBJ_VAL((Obj *)result));
}

static void freeObject(VM *vm, Obj *object) {
  (void)vm; // May be needed for future garbage collection
  switch (object->type) {
  case OBJ_STRING: {
    ObjString *string = (ObjString *)object;
    FREE_ARRAY(string->length + 1, sizeof(char), string->chars);
    FREE(sizeof(ObjString), object);
    break;
  }
  }
}

void freeObjects(VM *vm) {
  Obj *object = vm->objects;
  while (object != NULL) {
    Obj *next = object->next;
    freeObject(vm, object);
    object = next;
  }
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

void printObject(Value value) {
  switch (OBJ_TYPE(value)) {
  case OBJ_STRING:
    printf("%s", AS_CSTRING(value));
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
