#include "clox.h"

// Value constructors and accessors
Value BOOL_VAL(bool value) { return (Value){VAL_BOOL, {.boolean = value}}; }

Value NUMBER_VAL(double value) {
  return (Value){VAL_NUMBER, {.number = value}};
}

bool AS_BOOL(Value value) { return value.as.boolean; }
double AS_NUMBER(Value value) { return value.as.number; }

bool IS_BOOL(Value value) { return value.type == VAL_BOOL; }
bool IS_NIL(Value value) { return value.type == VAL_NIL; }
bool IS_NUMBER(Value value) { return value.type == VAL_NUMBER; }

Value OBJ_VAL(Obj *obj) { return (Value){VAL_OBJ, {.obj = obj}}; }
bool IS_OBJ(Value value) { return value.type == VAL_OBJ; }
Obj *AS_OBJ(Value value) { return value.as.obj; }
ObjType OBJ_TYPE(Value value) { return AS_OBJ(value)->type; }
bool IS_OBJ_TYPE(Value value, ObjType type) {
  return IS_OBJ(value) && OBJ_TYPE(value) == type;
}
bool IS_STRING(Value value) { return IS_OBJ_TYPE(value, OBJ_STRING); }
ObjString *AS_STRING(Value value) { return (ObjString *)AS_OBJ(value); }
char *AS_CSTRING(Value value) { return AS_STRING(value)->chars; }

bool isFalsey(Value value) {
  return IS_NIL(value) || (IS_BOOL(value) && !AS_BOOL(value));
}

// ====================================================
// Array functions
// ====================================================

void arrayInit(Array *array, size_t elementSize) {
  *array = (Array){
      .count = 0,
      .capacity = 0,
      .elementSize = elementSize,
      .data = NULL,
  };
}

void arrayWrite(Array *array, const void *element) {
  if (array->count >= array->capacity) {
    size_t newCapacity = array->capacity < 8 ? 8 : array->capacity * 2;
    void *newData = realloc(array->data, newCapacity * array->elementSize);
    if (!newData)
      exit(1);

    array->data = newData;
    array->capacity = newCapacity;
  }

  memcpy((u8 *)array->data + array->count * array->elementSize, element,
         array->elementSize);

  array->count++;
}

void arrayFree(Array *array) {
  free(array->data);
  array->data = NULL;
  array->count = 0;
  array->capacity = 0;
}

// ====================================================
// Obj functions
// ====================================================

// Memory management functions
void *reallocate(void *pointer, size_t oldSize, size_t newSize) {
  (void)oldSize; // Unused but kept for API consistency
  if (newSize == 0) {
    free(pointer);
    return NULL;
  }

  void *result = realloc(pointer, newSize);
  if (result == NULL)
    exit(1);
  return result;
}

// Memory allocation helpers (converted from macros)
void *allocateType(size_t count, size_t elementSize) {
  return reallocate(NULL, 0, count * elementSize);
}

void freeType(void *pointer, size_t size) { reallocate(pointer, size, 0); }

void freeTypeArray(void *pointer, size_t count, size_t elementSize) {
  reallocate(pointer, count * elementSize, 0);
}

// Memory management - wrappers
void *allocate(size_t size) { return reallocate(NULL, 0, size); }

void freePtr(void *pointer) { reallocate(pointer, 0, 0); }

void *freeArray(void *pointer, size_t count, size_t elementSize) {
  return reallocate(pointer, count * elementSize, 0);
}

// Memory allocation helpers
void *ALLOCATE(size_t count, size_t elementSize) {
  return allocateType(count, elementSize);
}

void *ALLOCATE_OBJ(VM *vm, size_t size, ObjType type) {
  Obj *object = (Obj *)reallocate(NULL, 0, size);
  object->type = type;
  object->next = vm->objects;
  vm->objects = object;
  return object;
}

void FREE(size_t size, void *pointer) { freeType(pointer, size); }

void FREE_ARRAY(size_t count, size_t elementSize, void *pointer) {
  freeTypeArray(pointer, count, elementSize);
}
