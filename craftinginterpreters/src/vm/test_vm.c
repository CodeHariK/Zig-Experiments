#include "clox.h"

int main(void) {
  Chunk chunk;
  chunkInit(&chunk);

  int constant = addConstant(&chunk, 1.2);
  chunkWrite(&chunk, OP_CONSTANT, 123);
  chunkWrite(&chunk, constant, 123);

  chunkWrite(&chunk, OP_RETURN, 123);

  chunkDisassemble(&chunk, "Hello");

  chunkFree(&chunk);
  return 0;
}
