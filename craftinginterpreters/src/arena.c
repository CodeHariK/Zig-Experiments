#include "lox.h"
#include <stdlib.h>
#include <string.h>

void arenaInit(Arena *arena, u32 capacity) {
  arena->data = malloc(capacity);
  if (!arena->data)
    exit(1);

  arena->capacity = capacity;
  arena->offset = 0;
}

void *arenaAlloc(Arena *arena, u32 size) {
  size = (size + 7) & ~7;

  if (arena->offset + size > arena->capacity) {
    fprintf(stderr, "Arena out of memory\n");
    abort();
  }

  void *ptr = arena->data + arena->offset;
  arena->offset += size;
  return ptr;
}

void arenaFree(Arena *arena) { free(arena->data); }
