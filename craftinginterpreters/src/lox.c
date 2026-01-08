#include "lox.h"
#include <stdio.h>
#include <stdlib.h>

void loxInit(Lox *lox, bool debugPrint) {
  *lox = (Lox){
      .hadError = false,
      .hadRuntimeError = false,
      .debugPrint = debugPrint,
      .errorMsg[0] = '\0',
      .runtimeErrorMsg[0] = '\0',
      .output_len = 0,
      .output[0] = '\0',
      .scanner.source = NULL,
      .env = envNew(NULL),
      .astArena = {0},
      .signal = {.type = SIGNAL_NONE},
  };

  arenaInit(&lox->astArena, 1024 * 1024); // 1 MB is plenty

  defineNativeFunctions(lox);
}

void loxRun(Lox *lox, const char *source) {
  initScanner(&lox->scanner, source);
  scanTokens(lox);

  initParser(lox);

  Program *prog = parseProgram(lox);
  executeProgram(lox, prog);
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

  if (lox->output_len > 0) {
    printf("%s", lox->output);
    lox->output_len = 0;
    lox->output[0] = '\0';
  }

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

    if (lox->output_len > 0) {
      printf("%s", lox->output);
      lox->output_len = 0;
      lox->output[0] = '\0';
    }

    lox->hadError = false;
  }
}
