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
  bool hadError;
  bool hadRuntimeError;
  Scanner scanner;
  Parser parser;
} Lox;

void loxInit(Lox *lox);

void loxReport(Lox *lox, int line, const char *where, const char *message);
void loxError(Lox *lox, int line, const char *message);

void loxRun(Lox *lox, const char *source);
void loxRunPrompt(Lox *lox);
void loxRunFile(Lox *lox, const char *path);

void initScanner(Scanner *scanner, const char *source);
void freeScanner(Scanner *scanner);
Token *scanTokens(Lox *lox, size_t *outCount);

Expr *parseExpression(Lox *lox);

void printExpr(Expr *expr);
void printValue(Value v);

Value evaluate(Lox *lox, Expr *expr);

#endif
