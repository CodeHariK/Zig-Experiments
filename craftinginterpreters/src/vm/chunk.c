#include "clox.h"

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
  u8 constant = ((u8 *)chunk->code.data)[offset + 1];
  printf("%-16s %4d '", name, constant);
  printValue(((Value *)chunk->constants.values.data)[constant]);
  printf("'\n");
  return offset + 2;
}

void printValue(Value value) { printf("%g", value); }

void chunkDisassemble(Chunk *chunk, const char *name) {
  printf("== %s ==\n", name);

  for (u32 offset = 0; offset < chunk->code.count;) {
    offset = instructionDisassemble(chunk, offset);
  }
}

u32 instructionDisassemble(Chunk *chunk, u32 offset) {
  printf("%04u ", offset);

  u32 *linesArray = (u32 *)chunk->lines.data;
  if (offset > 0 && linesArray[offset] == linesArray[offset - 1]) {
    printf("   | ");
  } else {
    printf("%4d ", linesArray[offset]);
  }

  u8 instruction = ((u8 *)chunk->code.data)[offset];

  switch (instruction) {
  case OP_CONSTANT:
    return constantInstruction("OP_CONSTANT", chunk, offset);
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
