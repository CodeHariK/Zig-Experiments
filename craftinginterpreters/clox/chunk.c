#include "clox.h"

inline u8 *getCodeArr(Chunk *chunk) { return ((u8 *)chunk->code.data); }

inline Value *getConstantArr(Chunk *chunk) {
  return ((Value *)chunk->constants.values.data);
}

inline u32 *getLineArr(Chunk *chunk) { return ((u32 *)chunk->lines.data); }

void chunkInit(Chunk *chunk) {
  arrayInit(&chunk->code, sizeof(u8));
  arrayInit(&chunk->lines, sizeof(u32));
  initValueArray(&chunk->constants);
}

void chunkWrite(Chunk *chunk, u8 byte, u32 line) {
  arrayWrite(&chunk->code, &byte);
  arrayWrite(&chunk->lines, &line);
}

void chunkFree(Chunk *chunk) {
  arrayFree(&chunk->code);
  arrayFree(&chunk->lines);
  freeValueArray(&chunk->constants);
}

static size_t simpleInstruction(const char *name, size_t offset) {
  printf("%s\n", name);
  return offset + 1;
}

static size_t constantInstruction(const char *name, Chunk *chunk,
                                  size_t offset) {
  u8 constantOffset = getCodeArr(chunk)[offset + 1];
  printf("%-16s %4d '", name, constantOffset);
  printValue(getConstantArr(chunk)[constantOffset]);
  printf("'\n");
  return offset + 2;
}

void chunkDisassemble(Chunk *chunk, const char *name) {
  printf("== %s ==\n", name);

  for (size_t offset = 0; offset < chunk->code.count;) {
    offset = instructionDisassemble(chunk, offset);
  }
}

size_t instructionDisassemble(Chunk *chunk, size_t offset) {
  printf("%04zu ", offset);

  if (offset > 0 &&
      getLineArr(chunk)[offset] == getLineArr(chunk)[offset - 1]) {
    printf("   | ");
  } else {
    printf("%4d ", getLineArr(chunk)[offset]);
  }

  u8 instruction = getCodeArr(chunk)[offset];

  switch (instruction) {
  case OP_CONSTANT:
    return constantInstruction("OP_CONSTANT", chunk, offset);

  case OP_NIL:
    return simpleInstruction("OP_NIL", offset);
  case OP_TRUE:
    return simpleInstruction("OP_TRUE", offset);
  case OP_FALSE:
    return simpleInstruction("OP_FALSE", offset);

  case OP_EQUAL:
    return simpleInstruction("OP_EQUAL", offset);
  case OP_NOT_EQUAL:
    return simpleInstruction("OP_NOT_EQUAL", offset);
  case OP_GREATER:
    return simpleInstruction("OP_GREATER", offset);
  case OP_LESS:
    return simpleInstruction("OP_LESS", offset);
  case OP_GREATER_EQUAL:
    return simpleInstruction("OP_GREATER_EQUAL", offset);
  case OP_LESS_EQUAL:
    return simpleInstruction("OP_LESS_EQUAL", offset);

  case OP_ADD:
    return simpleInstruction("OP_ADD", offset);
  case OP_SUBTRACT:
    return simpleInstruction("OP_SUBTRACT", offset);
  case OP_MULTIPLY:
    return simpleInstruction("OP_MULTIPLY", offset);
  case OP_DIVIDE:
    return simpleInstruction("OP_DIVIDE", offset);

  case OP_NOT:
    return simpleInstruction("OP_NOT", offset);
  case OP_NEGATE:
    return simpleInstruction("OP_NEGATE", offset);

  case OP_POP:
    return simpleInstruction("OP_POP", offset);

  case OP_PRINT:
    return simpleInstruction("OP_PRINT", offset);

  case OP_GET_GLOBAL:
    return constantInstruction("OP_GET_GLOBAL", chunk, offset);

  case OP_SET_GLOBAL:
    return constantInstruction("OP_SET_GLOBAL", chunk, offset);

  case OP_DEFINE_GLOBAL:
    return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset);

  case OP_RETURN:
    return simpleInstruction("OP_RETURN", offset);
  default:
    printf("Unknown opcode %d\n", instruction);
    return offset + 1;
  }
}

size_t addConstant(Chunk *chunk, Value value) {
  writeValueArray(&chunk->constants, value);
  return chunk->constants.values.count - 1;
}
