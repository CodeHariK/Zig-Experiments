#include "clox.h"

int main(void) {
  Chunk chunk;
  chunkInit(&chunk);

  int constant = addConstant(&chunk, 1.2);
  chunkWrite(&chunk, OP_CONSTANT, 123);
  chunkWrite(&chunk, constant, 123);

  constant = addConstant(&chunk, 3.4);
  chunkWrite(&chunk, OP_CONSTANT, 123);
  chunkWrite(&chunk, constant, 123);

  chunkWrite(&chunk, OP_ADD, 123);

  constant = addConstant(&chunk, 5.6);
  chunkWrite(&chunk, OP_CONSTANT, 123);
  chunkWrite(&chunk, constant, 123);

  chunkWrite(&chunk, OP_DIVIDE, 123);

  chunkWrite(&chunk, OP_NEGATE, 123);

  chunkWrite(&chunk, OP_RETURN, 123);

  chunkDisassemble(&chunk, "Hello");

  printf("\n==========\n");

  VM vm;
  interpret(&vm, &chunk);

  chunkFree(&chunk);
  return 0;
}
