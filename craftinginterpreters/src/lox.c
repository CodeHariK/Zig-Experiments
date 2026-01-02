// lox.c
#include "lox.h"
#include "scanner.h"
#include "stmt.h"
#include <stdio.h>
#include <stdlib.h>

void loxInit(Lox *lox, bool debugPrint) {
  lox->hadError = false;
  lox->hadRuntimeError = false;
  lox->debugPrint = debugPrint;
  lox->scanner.source = NULL;

  lox->env = malloc(sizeof(Environment));
  if (!lox->env)
    exit(1);

  lox->env->entries = malloc(sizeof(EnvKV) * 8);
  lox->env->count = 0;
  lox->env->capacity = 8;
}

void loxFree(Lox *lox) {
  for (int i = 0; i < lox->env->count; i++) {
    free((void *)lox->env->entries[i].key);
  }
  free(lox->env->entries);
  free(lox->env);
}

void loxReport(Lox *lox, int line, const char *where, const char *message) {
  fprintf(stderr, "[line %d] Error%s: %s\n", line, where, message);
  lox->hadError = true;
}

void loxError(Lox *lox, int line, const char *message) {
  loxReport(lox, line, "", message);
}

void loxRun(Lox *lox, const char *source) {
  initScanner(&lox->scanner, source);
  size_t count;
  Token *tokens = scanTokens(lox, &count);

  lox->parser.tokens = tokens;
  lox->parser.count = count;
  lox->parser.current = 0;

  Program *prog = parseProgram(lox);
  for (size_t i = 0; i < prog->count; i++) {
    executeStmt(lox, prog->statements[i], NULL, 0);
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
