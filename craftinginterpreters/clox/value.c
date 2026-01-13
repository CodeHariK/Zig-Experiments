#include "clox.h"

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

void printValue(Value value) { printf("%g", value); }
