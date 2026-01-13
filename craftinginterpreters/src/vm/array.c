#include "clox.h"

void arrayInit(Array *array, u32 elementSize) {
  *array = (Array){
      .count = 0,
      .capacity = 0,
      .elementSize = elementSize,
      .data = NULL,
  };
}

void arrayWrite(Array *array, const void *element) {
  if (array->count >= array->capacity) {
    u32 newCapacity = array->capacity < 8 ? 8 : array->capacity * 2;
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
