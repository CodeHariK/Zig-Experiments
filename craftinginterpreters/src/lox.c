// lox.c
#include "lox.h"
#include <stdio.h>
#include <stdlib.h>

void loxInit(Lox *lox) {
  lox->hadError = false;
  lox->scanner.source = NULL;
}

void loxReport(Lox *lox, int line, const char *where, const char *message) {
  fprintf(stderr, "[line %d] Error%s: %s\n", line, where, message);
  lox->hadError = true;
}

void loxError(Lox *lox, int line, const char *message) {
  loxReport(lox, line, "", message);
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
