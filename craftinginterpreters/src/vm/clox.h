#ifndef CLOX_H
#define CLOX_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint32_t u32;
typedef int32_t i32;
typedef uint8_t u8;

typedef double Value;

typedef struct {
  u32 count;
  u32 capacity;
  u32 elementSize;
  void *data;
} Array;

void arrayInit(Array *array, u32 elementSize);
void arrayWrite(Array *array, const void *element);
void arrayFree(Array *array);

typedef enum {
  OP_CONSTANT,
  OP_RETURN,
} OpCode;

typedef struct {
  Array values;
} ValueArray;

void initValueArray(ValueArray *array);
void writeValueArray(ValueArray *array, Value value);
void freeValueArray(ValueArray *array);

typedef struct {
  Array code;
  Array lines;
  ValueArray constants;
} Chunk;

void chunkInit(Chunk *chunk);
void chunkWrite(Chunk *chunk, u8 byte, u32 line);
void chunkFree(Chunk *chunk);
void chunkDisassemble(Chunk *chunk, const char *name);
u32 instructionDisassemble(Chunk *chunk, u32 offset);
u32 addConstant(Chunk *chunk, Value value);

void printValue(Value value);

#endif
