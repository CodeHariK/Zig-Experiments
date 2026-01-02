// lox.h
#ifndef LOX_H
#define LOX_H

#include "token.h"
#include <stdbool.h>
#include <stddef.h>

typedef struct {
  const char *source;
  size_t start;
  size_t current;
  int line;

  Token *tokens;
  size_t count;
  size_t capacity;
} Scanner;

typedef struct {
  Token *tokens;
  size_t count;
  size_t current;
} Parser;

typedef struct {
  const char *key;
  Value value;
} EnvKV;

typedef struct {
  EnvKV *entries;
  int count;
  int capacity;
} Environment;

typedef struct {
  bool hadError;
  bool hadRuntimeError;
  bool debugPrint;
  Scanner scanner;
  Parser parser;
  Environment *env;
} Lox;

void loxInit(Lox *lox, bool debugPrint);
void loxFree(Lox *lox);

void loxReport(Lox *lox, int line, const char *where, const char *message);
void loxError(Lox *lox, int line, const char *message);

void loxRun(Lox *lox, const char *source);
void loxRunPrompt(Lox *lox);
void loxRunFile(Lox *lox, const char *path);

Expr *parseExpression(Lox *lox);

void printExpr(Expr *expr);
void printValue(Value v, char *msg);

Value evaluate(Lox *lox, Expr *expr);

#endif
