#include "clox.h"

inline u8 getChunkInstruction(Chunk *chunk, u32 offset) {
  return ((u8 *)chunk->code.data)[offset];
}

inline Value getChunkConstant(Chunk *chunk, u32 offset) {
  return ((Value *)chunk->constants.values.data)[offset];
}

inline u32 getChunkLine(Chunk *chunk, u32 offset) {
  return ((u32 *)chunk->lines.data)[offset];
}

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

static u32 simpleInstruction(const char *name, u32 offset) {
  printf("%s\n", name);
  return offset + 1;
}

static u32 constantInstruction(const char *name, Chunk *chunk, u32 offset) {
  u8 constantOffset = getChunkInstruction(chunk, offset + 1);
  printf("%-16s %4d '", name, constantOffset);
  printValue(getChunkConstant(chunk, constantOffset));
  printf("'\n");
  return offset + 2;
}

void chunkDisassemble(Chunk *chunk, const char *name) {
  printf("== %s ==\n", name);

  for (u32 offset = 0; offset < chunk->code.count;) {
    offset = instructionDisassemble(chunk, offset);
  }
}

u32 instructionDisassemble(Chunk *chunk, u32 offset) {
  printf("%04u ", offset);

  if (offset > 0 &&
      getChunkLine(chunk, offset) == getChunkLine(chunk, offset - 1)) {
    printf("   | ");
  } else {
    printf("%4d ", getChunkLine(chunk, offset));
  }

  u8 instruction = getChunkInstruction(chunk, offset);

  switch (instruction) {
  case OP_CONSTANT:
    return constantInstruction("OP_CONSTANT", chunk, offset);
  case OP_ADD:
    return simpleInstruction("OP_ADD", offset);
  case OP_SUBTRACT:
    return simpleInstruction("OP_SUBTRACT", offset);
  case OP_MULTIPLY:
    return simpleInstruction("OP_MULTIPLY", offset);
  case OP_DIVIDE:
    return simpleInstruction("OP_DIVIDE", offset);
  case OP_NEGATE:
    return simpleInstruction("OP_NEGATE", offset);
  case OP_RETURN:
    return simpleInstruction("OP_RETURN", offset);
  default:
    printf("Unknown opcode %d\n", instruction);
    return offset + 1;
  }
}

u32 addConstant(Chunk *chunk, Value value) {
  writeValueArray(&chunk->constants, value);
  return chunk->constants.values.count - 1;
}
