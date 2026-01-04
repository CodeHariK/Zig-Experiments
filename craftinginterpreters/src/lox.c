// lox.c
#include "lox.h"
#include <stdio.h>
#include <stdlib.h>

void loxInit(Lox *lox, bool debugPrint) {
  lox->hadError = false;
  lox->hadRuntimeError = false;
  lox->debugPrint = debugPrint;
  lox->errorMsg[0] = '\0';
  lox->runtimeErrorMsg[0] = '\0';

  lox->output_len = 0;
  lox->output[0] = '\0';

  lox->indent = 0;

  lox->scanner.source = NULL;

  lox->env = envNew(NULL);

  arenaInit(&lox->astArena, 1024 * 1024); // 1 MB is plenty
}

void loxRun(Lox *lox, const char *source) {
  initScanner(&lox->scanner, source);
  scanTokens(lox);

  initParser(lox);

  Program *prog = parseProgram(lox);
  for (size_t i = 0; i < prog->count; i++) {
    executeStmt(lox, prog->statements[i]);
  }
}

/* Reads entire file into memory and runs it */
void loxRunFile(Lox *lox, const char *path) {
  FILE *file = fopen(path, "rb");
  if (!file) {
    fprintf(stderr, "Could not open file \"%s\".\n", path);
    exit(65);
  }

  fseek(file, 0, SEEK_END);
  long size = ftell(file);
  rewind(file);

  char *buffer = malloc(size + 1);
  if (!buffer) {
    fprintf(stderr, "Out of memory.\n");
    exit(74);
  }

  fread(buffer, 1, size, file);
  buffer[size] = '\0';

  fclose(file);

  loxRun(lox, buffer);

  free(buffer);

  if (lox->hadError) {
    exit(65);
  }
}

/* REPL */
void loxRunPrompt(Lox *lox) {
  char line[1024];

  for (;;) {
    printf("> ");

    if (!fgets(line, sizeof(line), stdin)) {
      break; /* EOF */
    }

    loxRun(lox, line);

    lox->hadError = false;
  }
}
