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

bool IS_FUNCTION(Value value) { return IS_OBJ_TYPE(value, OBJ_FUNCTION); }
ObjFunction *AS_FUNCTION(Value value) { return (ObjFunction *)AS_OBJ(value); }
bool IS_NATIVE(Value value) { return IS_OBJ_TYPE(value, OBJ_NATIVE); }
NativeFn AS_NATIVE(Value value) {
  return ((ObjNative *)AS_OBJ(value))->function;
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

// Memory management - wrappers
void *allocate(size_t size) { return reallocate(NULL, 0, size); }

void freePtr(void *pointer) { reallocate(pointer, 0, 0); }

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
  reallocate(pointer, count * elementSize, 0);
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
  u32 index = key->hash % capacity;
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

    index = (index + 1) % capacity;
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

  u32 index = hash % table->capacity;
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

    index = (index + 1) % table->capacity;
  }
}
