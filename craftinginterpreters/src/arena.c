#include "lox.h"
#include <stdlib.h>
#include <string.h>

void arenaInit(Arena *arena, size_t capacity) {
  arena->data = malloc(capacity);
  if (!arena->data)
    exit(1);

  arena->capacity = capacity;
  arena->offset = 0; // ← THIS WAS THE MISSING LINE
}

void *arenaAlloc(Arena *arena, size_t size) {
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

Environment *envNew(Environment *enclosing) {
  Environment *env = malloc(sizeof(Environment));
  if (!env)
    exit(1);

  env->entries = malloc(sizeof(EnvKV) * 8);
  env->count = 0;
  env->capacity = 8;
  env->enclosing = enclosing;

  return env;
}

void envFree(Environment *env) {
  free(env->entries);
  free(env);
}

bool envGet(Environment *env, const char *name, Value *out) {
  for (int i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      *out = env->entries[i].value;
      return true;
    }
  }

  if (env->enclosing) {
    return envGet(env->enclosing, name, out);
  }

  return false;
}

void envDefine(Environment *env, const char *name, Value value) {
  if (env->count >= env->capacity) {
    env->capacity *= 2;
    env->entries = realloc(env->entries, sizeof(EnvKV) * env->capacity);
  }

  env->entries[env->count].key = strdup(name);
  env->entries[env->count].value = value;
  env->count++;
}

bool envAssign(Environment *env, const char *name, Value value) {
  for (int i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      env->entries[i].value = value;
      return true;
    }
  }

  if (env->enclosing) {
    return envAssign(env->enclosing, name, value);
  }

  return false;
}
