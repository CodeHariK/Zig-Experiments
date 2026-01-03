// lox.h
#ifndef LOX_H
#define LOX_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef enum {
  // Single-character tokens.
  TOKEN_LEFT_PAREN,
  TOKEN_RIGHT_PAREN,
  TOKEN_LEFT_BRACE,
  TOKEN_RIGHT_BRACE,
  TOKEN_COMMA,
  TOKEN_DOT,
  TOKEN_MINUS,
  TOKEN_PLUS,
  TOKEN_SEMICOLON,
  TOKEN_SLASH,
  TOKEN_STAR,

  // One or two character tokens.
  TOKEN_NOT,
  TOKEN_NOT_EQUAL,
  TOKEN_EQUAL,
  TOKEN_EQUAL_EQUAL,
  TOKEN_GREATER,
  TOKEN_GREATER_EQUAL,
  TOKEN_LESS,
  TOKEN_LESS_EQUAL,

  // Literals.
  TOKEN_IDENTIFIER,
  TOKEN_STRING,
  TOKEN_NUMBER,

  // Keywords.
  TOKEN_AND,
  TOKEN_CLASS,
  TOKEN_ELSE,
  TOKEN_FALSE,
  TOKEN_FUN,
  TOKEN_FOR,
  TOKEN_IF,
  TOKEN_NIL,
  TOKEN_OR,
  TOKEN_PRINT,
  TOKEN_RETURN,
  TOKEN_SUPER,
  TOKEN_THIS,
  TOKEN_TRUE,
  TOKEN_VAR,
  TOKEN_WHILE,

  TOKEN_EOF
} TokenType;

typedef struct {
  TokenType type;
  const char *lexeme;
  void *literal;
  int line;
  int length;
} Token;

typedef struct {
  const char *name;
  TokenType type;
} Keyword;

typedef enum {
  EXPR_BINARY,
  EXPR_UNARY,
  EXPR_LITERAL,
  EXPR_GROUPING,
  EXPR_VARIABLE,
} ExprType;

typedef enum { VAL_BOOL, VAL_NIL, VAL_NUMBER, VAL_STRING } ValueType;

typedef struct {
  ValueType type;
  union {
    bool boolean;
    double number;
    char *string;
  } as;
} Value;

typedef struct Expr {
  ExprType type;
  union {
    struct {
      struct Expr *left;
      Token op;
      struct Expr *right;
    } binary;

    struct {
      Token op;
      struct Expr *right;
    } unary;

    struct {
      Value value; // number, string, bool, or NULL
    } literal;

    struct {
      struct Expr *expression;
    } grouping;

    struct {
      Token name;
      struct Expr *initializer;
    } var;

  } as;
} Expr;

typedef enum { STMT_EXPR, STMT_PRINT, STMT_VAR } StmtType;

typedef struct Stmt {
  StmtType type;
  union {
    Expr *expr;      // expression statement
    Expr *printExpr; // print statement
    struct {
      Token name;
      Expr *initializer; // optional initializer
    } var;               // var statement
  } as;
} Stmt;

typedef struct {
  Stmt **statements;
  size_t count;
  size_t capacity;
} Program;

const char *tokenTypeToString(TokenType type);

Value numberValue(double n);
Value boolValue(bool b);
Value nilValue(void);
Value stringValue(char *s);

void valueToString(Value value, char *buffer, size_t size);

typedef struct {
  uint8_t *data;
  size_t capacity;
  size_t offset;
} Arena;

void arenaInit(Arena *arena, size_t capacity);
void *arenaAlloc(Arena *arena, size_t size);
void arenaFree(Arena *arena);

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

  Arena astArena;
  Scanner scanner;
  Parser parser;
  Environment *env;
} Lox;

void loxInit(Lox *lox, bool debugPrint);
void freeLox(Lox *lox);

void loxReport(Lox *lox, int line, const char *where, const char *message);
void loxError(Lox *lox, int line, const char *message);

void loxRun(Lox *lox, const char *source);
void loxRunPrompt(Lox *lox);
void loxRunFile(Lox *lox, const char *path);

void initScanner(Scanner *scanner, const char *source);
void freeScanner(Scanner *scanner);
Token *scanTokens(Lox *lox, size_t *outCount);

void initParser(Lox *lox, Token *tokens, size_t count);
bool isTokenEOF(Parser *parser);
bool matchAnyTokenAdvance(Parser *parser, int count, ...);
Token consumeToken(Lox *lox, TokenType type, const char *message);
void advanceToken(Parser *parser);
Token prevToken(Parser *parser);
Token peekToken(Parser *parser);

Expr *parseExpression(Lox *lox);

Expr *newBinaryExpr(Lox *lox, Expr *left, Token op, Expr *right);
Expr *newUnaryExpr(Lox *lox, Token op, Expr *right);
Expr *newLiteralExpr(Lox *lox, Value value);
Expr *newGroupingExpr(Lox *lox, Expr *expression);
Expr *newVariableExpr(Lox *lox, Token token);
// void freeExpr(Expr *expr);

Value evaluate(Lox *lox, Expr *expr);

Stmt *parseStmt(Lox *lox);
Program *parseProgram(Lox *lox);
void executeStmt(Lox *lox, Stmt *stmt, char *outBuffer, size_t bufSize);
bool envGet(Environment *env, const char *name, Value *out);
// void freeStmt(Stmt *stmt);

void printExpr(Expr *expr);
void printValue(Value v, char *msg);
void printToken(Lox *lox, const Token *token);
void printStmt(Stmt *stmt);
void printEnvironment(Lox *lox);

void runtimeError(Lox *lox, Token op, const char *message);
void parserError(Lox *lox, const char *message);
void synchronize(Lox *lox);

#endif
