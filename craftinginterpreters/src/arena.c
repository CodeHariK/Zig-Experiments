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

Environment *envNew(Environment *enclosing) {
  Environment *env = malloc(sizeof(Environment));
  if (!env)
    exit(1);

  *env = (Environment){
      .entries = malloc(sizeof(EnvKV) * 8),
      .count = 0,
      .capacity = 8,
      .enclosing = enclosing,
  };

  return env;
}

void envFree(Environment *env) {
  free(env->entries);
  free(env);
}

bool envGet(Environment *env, const char *name, Value *out) {
  for (u32 i = 0; i < env->count; i++) {
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

  env->entries[env->count] = (EnvKV){
      .key = strdup(name),
      .value = value,
  };

  env->count++;
}

bool envAssign(Environment *env, const char *name, Value value) {
  for (u32 i = 0; i < env->count; i++) {
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
