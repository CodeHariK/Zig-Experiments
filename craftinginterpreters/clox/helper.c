#include "clox.h"

#ifndef NAN_BOXING
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
#endif

ObjType OBJ_TYPE(Value value) { return AS_OBJ(value)->type; }
bool IS_OBJ_TYPE(Value value, ObjType type) {
  return IS_OBJ(value) && OBJ_TYPE(value) == type;
}
bool IS_STRING(Value value) { return IS_OBJ_TYPE(value, OBJ_STRING); }
ObjString *AS_STRING(Value value) { return (ObjString *)AS_OBJ(value); }
char *AS_CSTRING(Value value) { return AS_STRING(value)->chars; }

bool IS_FUNCTION(Value value) { return IS_OBJ_TYPE(value, OBJ_FUNCTION); }
ObjFunction *AS_FUNCTION(Value value) { return (ObjFunction *)AS_OBJ(value); }
bool IS_NATIVE(Value value) { return IS_OBJ_TYPE(value, OBJ_NATIVE); }
NativeFn AS_NATIVE(Value value) {
  return ((ObjNative *)AS_OBJ(value))->function;
}
bool IS_CLOSURE(Value value) { return IS_OBJ_TYPE(value, OBJ_CLOSURE); }
ObjClosure *AS_CLOSURE(Value value) { return (ObjClosure *)AS_OBJ(value); }
bool IS_CLASS(Value value) { return IS_OBJ_TYPE(value, OBJ_CLASS); }
ObjClass *AS_CLASS(Value value) { return (ObjClass *)AS_OBJ(value); }
bool IS_INSTANCE(Value value) { return IS_OBJ_TYPE(value, OBJ_INSTANCE); }
ObjInstance *AS_INSTANCE(Value value) { return (ObjInstance *)AS_OBJ(value); }
bool IS_BOUND_METHOD(Value value) {
  return IS_OBJ_TYPE(value, OBJ_BOUND_METHOD);
}
ObjBoundMethod *AS_BOUND_METHOD(Value value) {
  return (ObjBoundMethod *)AS_OBJ(value);
}

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
  if (array->count >= array->capacity * ARRAY_MAX_LOAD) {
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

// #define DEBUG_STRESS_GC
// #define DEBUG_LOG_GC

#ifdef DEBUG_LOG_GC
#include <stdio.h>
#endif

// Memory management functions
void *reallocate(VM *vm, void *pointer, size_t oldSize, size_t newSize) {
  if (vm != NULL) {
    vm->bytesAllocated += newSize - oldSize;

    if (newSize > oldSize) {
#ifdef DEBUG_STRESS_GC
      collectGarbage(vm);
#endif
      if (vm->bytesAllocated > vm->nextGC) {
        collectGarbage(vm);
      }
    }
  }

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
  return reallocate(NULL, NULL, 0, count * elementSize);
}

void freeType(void *pointer, size_t size) {
  reallocate(NULL, pointer, size, 0);
}

// Memory management - wrappers
void *allocate(size_t size) { return reallocate(NULL, NULL, 0, size); }

void freePtr(void *pointer) { reallocate(NULL, pointer, 0, 0); }

// Memory allocation helpers
void *ALLOCATE(size_t count, size_t elementSize) {
  return allocateType(count, elementSize);
}

void *ALLOCATE_OBJ(VM *vm, size_t size, ObjType type) {
  Obj *object = (Obj *)reallocate(vm, NULL, 0, size);
  object->type = type;
  object->isMarked = false;
  object->next = vm->objects;
  vm->objects = object;

#ifdef DEBUG_LOG_GC
  printf("%p allocate %zu for %d\n", (void *)object, size, type);
#endif

  return object;
}

void FREE(size_t size, void *pointer) { freeType(pointer, size); }

void FREE_ARRAY(size_t count, size_t elementSize, void *pointer) {
  reallocate(NULL, pointer, count * elementSize, 0);
}

// ====================================================
// Garbage Collection
// ====================================================

void markValue(VM *vm, Value value) {
  if (IS_OBJ(value))
    markObject(vm, AS_OBJ(value));
}

static void markArray(VM *vm, ValueArray *array) {
  for (size_t i = 0; i < array->values.count; i++) {
    markValue(vm, ((Value *)array->values.data)[i]);
  }
}

void markObject(VM *vm, Obj *object) {
  if (object == NULL)
    return;
  if (object->isMarked)
    return;

#ifdef DEBUG_LOG_GC
  printf("%p mark ", (void *)object);
  printValue(OBJ_VAL(object));
  printf("\n");
#endif

  object->isMarked = true;

  if (vm->grayCapacity < vm->grayCount + 1) {
    vm->grayCapacity = vm->grayCapacity < 8 ? 8 : vm->grayCapacity * 2;
    vm->grayStack =
        (Obj **)realloc(vm->grayStack, sizeof(Obj *) * vm->grayCapacity);
    if (vm->grayStack == NULL)
      exit(1);
  }

  vm->grayStack[vm->grayCount++] = object;
}

void markTable(VM *vm, Table *table) {
  for (i32 i = 0; i < table->capacity; i++) {
    Entry *entry = &table->entries[i];
    markObject(vm, (Obj *)entry->key);
    markValue(vm, entry->value);
  }
}

static void markRoots(VM *vm) {
  // Mark the stack
  for (Value *slot = vm->stack; slot < vm->stackTop; slot++) {
    markValue(vm, *slot);
  }

  // Mark call frames
  for (int i = 0; i < vm->frameCount; i++) {
    markObject(vm, (Obj *)vm->frames[i].closure);
  }

  // Mark open upvalues
  for (ObjUpvalue *upvalue = vm->openUpvalues; upvalue != NULL;
       upvalue = upvalue->next) {
    markObject(vm, (Obj *)upvalue);
  }

  // Mark globals
  markTable(vm, &vm->globals);

  // Mark initString
  markObject(vm, (Obj *)vm->initString);

  // Mark compiler roots
  Compiler *compiler = vm->compiler;
  while (compiler != NULL) {
    markObject(vm, (Obj *)compiler->function);
    compiler = compiler->enclosing;
  }
}

static void blackenObject(VM *vm, Obj *object) {
#ifdef DEBUG_LOG_GC
  printf("%p blacken ", (void *)object);
  printValue(OBJ_VAL(object));
  printf("\n");
#endif

  switch (object->type) {
  case OBJ_BOUND_METHOD: {
    ObjBoundMethod *bound = (ObjBoundMethod *)object;
    markValue(vm, bound->receiver);
    markObject(vm, (Obj *)bound->method);
    break;
  }
  case OBJ_CLASS: {
    ObjClass *klass = (ObjClass *)object;
    markObject(vm, (Obj *)klass->name);
    markTable(vm, &klass->methods);
    break;
  }
  case OBJ_CLOSURE: {
    ObjClosure *closure = (ObjClosure *)object;
    markObject(vm, (Obj *)closure->function);
    for (int i = 0; i < closure->upvalueCount; i++) {
      markObject(vm, (Obj *)closure->upvalues[i]);
    }
    break;
  }
  case OBJ_FUNCTION: {
    ObjFunction *function = (ObjFunction *)object;
    markObject(vm, (Obj *)function->name);
    markArray(vm, &function->chunk.constants);
    break;
  }
  case OBJ_INSTANCE: {
    ObjInstance *instance = (ObjInstance *)object;
    markObject(vm, (Obj *)instance->klass);
    markTable(vm, &instance->fields);
    break;
  }
  case OBJ_UPVALUE:
    markValue(vm, ((ObjUpvalue *)object)->closed);
    break;
  case OBJ_NATIVE:
  case OBJ_STRING:
    break;
  }
}

static void traceReferences(VM *vm) {
  while (vm->grayCount > 0) {
    Obj *object = vm->grayStack[--vm->grayCount];
    blackenObject(vm, object);
  }
}

void tableRemoveWhite(Table *table) {
  for (i32 i = 0; i < table->capacity; i++) {
    Entry *entry = &table->entries[i];
    if (entry->key != NULL && !entry->key->obj.isMarked) {
      tableDelete(table, entry->key);
    }
  }
}

static void freeObject(VM *vm, Obj *object) {
#ifdef DEBUG_LOG_GC
  printf("%p free type %d\n", (void *)object, object->type);
#endif

  switch (object->type) {
  case OBJ_BOUND_METHOD: {
    FREE(sizeof(ObjBoundMethod), object);
    break;
  }
  case OBJ_CLASS: {
    ObjClass *klass = (ObjClass *)object;
    freeTable(&klass->methods);
    FREE(sizeof(ObjClass), object);
    break;
  }
  case OBJ_CLOSURE: {
    ObjClosure *closure = (ObjClosure *)object;
    FREE_ARRAY(closure->upvalueCount, sizeof(ObjUpvalue *), closure->upvalues);
    FREE(sizeof(ObjClosure), object);
    break;
  }
  case OBJ_FUNCTION: {
    ObjFunction *function = (ObjFunction *)object;
    chunkFree(&function->chunk);
    FREE(sizeof(ObjFunction), object);
    break;
  }
  case OBJ_INSTANCE: {
    ObjInstance *instance = (ObjInstance *)object;
    freeTable(&instance->fields);
    FREE(sizeof(ObjInstance), object);
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
}

static void sweep(VM *vm) {
  Obj *previous = NULL;
  Obj *object = vm->objects;
  while (object != NULL) {
    if (object->isMarked) {
      object->isMarked = false;
      previous = object;
      object = object->next;
    } else {
      Obj *unreached = object;
      object = object->next;
      if (previous != NULL) {
        previous->next = object;
      } else {
        vm->objects = object;
      }

      freeObject(vm, unreached);
    }
  }
}

void collectGarbage(VM *vm) {
#ifdef DEBUG_LOG_GC
  printf("-- gc begin\n");
  size_t before = vm->bytesAllocated;
#endif

  markRoots(vm);
  traceReferences(vm);
  tableRemoveWhite(&vm->strings);
  sweep(vm);

  vm->nextGC = vm->bytesAllocated * GC_HEAP_GROW_FACTOR;

#ifdef DEBUG_LOG_GC
  printf("-- gc end\n");
  printf("   collected %zu bytes (from %zu to %zu) next at %zu\n",
         before - vm->bytesAllocated, before, vm->bytesAllocated, vm->nextGC);
#endif
}

// ====================================================
// Table functions
// ====================================================

void initTable(Table *table) {
  table->count = 0;
  table->capacity = 0;
  table->entries = NULL;
}

void freeTable(Table *table) {
  FREE_ARRAY(table->capacity, sizeof(Entry), table->entries);
  initTable(table);
}

static Entry *findEntry(Entry *entries, i32 capacity, ObjString *key) {
  u32 index = key->hash & (capacity - 1);
  Entry *tombstone = NULL;

  for (;;) {
    Entry *entry = &entries[index];

    if (entry->key == NULL) {
      if (IS_NIL(entry->value)) {
        // Empty entry.
        return tombstone != NULL ? tombstone : entry;
      } else {
        // We found a tombstone.
        if (tombstone == NULL)
          tombstone = entry;
      }
    } else if (entry->key == key) {
      // We found the key.
      return entry;
    }

    index = (index + 1) & (capacity - 1);
  }
}

static void adjustCapacity(Table *table, i32 capacity) {
  Entry *entries = (Entry *)ALLOCATE(capacity, sizeof(Entry));
  for (i32 i = 0; i < capacity; i++) {
    entries[i].key = NULL;
    entries[i].value = NIL_VAL;
  }

  table->count = 0;

  for (i32 i = 0; i < table->capacity; i++) {
    Entry *entry = &table->entries[i];
    if (entry->key == NULL)
      continue;

    Entry *dest = findEntry(entries, capacity, entry->key);
    dest->key = entry->key;
    dest->value = entry->value;

    table->count++;
  }

  FREE_ARRAY(table->capacity, sizeof(Entry), table->entries);

  table->entries = entries;
  table->capacity = capacity;
}

bool tableGet(Table *table, ObjString *key, Value *value) {
  if (table->count == 0)
    return false;

  Entry *entry = findEntry(table->entries, table->capacity, key);
  if (entry->key == NULL)
    return false;

  *value = entry->value;
  return true;
}

bool tableSet(Table *table, ObjString *key, Value value) {
  if (table->count + 1 > table->capacity * ARRAY_MAX_LOAD) {
    i32 capacity = table->capacity < 8 ? 8 : table->capacity * 2;
    adjustCapacity(table, capacity);
  }

  Entry *entry = findEntry(table->entries, table->capacity, key);

  bool isNewKey = entry->key == NULL;
  if (isNewKey && IS_NIL(entry->value)) {
    table->count++;
  }

  entry->key = key;
  entry->value = value;
  return isNewKey;
}

void tableAddAll(Table *from, Table *to) {
  for (i32 i = 0; i < from->capacity; i++) {
    Entry *entry = &from->entries[i];
    if (entry->key != NULL) {
      tableSet(to, entry->key, entry->value);
    }
  }
}

bool tableDelete(Table *table, ObjString *key) {
  if (table->count == 0)
    return false;

  // Find the entry.
  Entry *entry = findEntry(table->entries, table->capacity, key);
  if (entry->key == NULL)
    return false;

  // Place a tombstone in the entry.
  entry->key = NULL;
  entry->value = BOOL_VAL(true);
  return true;
}

ObjString *tableFindString(Table *table, const char *chars, i32 length,
                           u32 hash) {
  if (table->count == 0)
    return NULL;

  u32 index = hash & (table->capacity - 1);
  for (;;) {
    Entry *entry = &table->entries[index];
    if (entry->key == NULL) {
      // Stop if we find an empty non-tombstone entry.
      if (IS_NIL(entry->value))
        return NULL;
    } else if (entry->key->length == length && entry->key->hash == hash &&
               memcmp(entry->key->chars, chars, length) == 0) {
      // We found it.
      return entry->key;
    }

    index = (index + 1) & (table->capacity - 1);
  }
}
