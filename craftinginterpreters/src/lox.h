// lox.h
#ifndef LOX_H
#define LOX_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#define u32 uint32_t
#define i32 int32_t
#define u8 uint8_t

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
  TOKEN_NIL,
  TOKEN_OR,
  TOKEN_PRINT,
  TOKEN_RETURN,
  TOKEN_SUPER,
  TOKEN_THIS,
  TOKEN_TRUE,
  TOKEN_VAR,

  TOKEN_IF,
  TOKEN_WHILE,
  TOKEN_FOR,
  TOKEN_BREAK,
  TOKEN_CONTINUE,

  TOKEN_EOF
} TokenType;

typedef struct {
  TokenType type;
  const char *lexeme;
  void *literal;
  u32 line;
  u32 length;
} Token;

typedef struct {
  const char *name;
  TokenType type;
} Keyword;

typedef enum {
  VAL_ERROR,
  VAL_NIL,
  VAL_BOOL,
  VAL_NUMBER,
  VAL_STRING,
  VAL_FUNCTION,
  VAL_NATIVE,
} ValueType;

typedef struct Value Value;

typedef Value (*NativeFn)(int argCount, Value *args);

struct Value {
  ValueType type;
  union {
    bool boolean;
    double number;
    char *string;
    struct LoxFunction *function;
    NativeFn native;
  } as;
};

typedef enum {
  SIGNAL_NONE,
  SIGNAL_BREAK,
  SIGNAL_CONTINUE,
  SIGNAL_RETURN
} ControlSignalType;

typedef enum {
  EXPR_BINARY,
  EXPR_UNARY,
  EXPR_LITERAL,
  EXPR_GROUPING,
  EXPR_VARIABLE,
  EXPR_ASSIGN,
  EXPR_LOGICAL,
  EXPR_CALL,
} ExprType;

typedef struct Expr {
  u32 line;

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
      struct Expr *value;
      int depth;
    } assign;

    struct {
      Token name;
      struct Expr *initializer;
      int depth;
    } var;

    struct {
      struct Expr *left;
      Token op; // TOKEN_AND or TOKEN_OR
      struct Expr *right;
    } logical;

    struct {
      struct Expr *callee;
      struct Expr **arguments;
      u8 argCount;
    } call;
  } as;
} Expr;

typedef enum {
  STMT_EXPR,
  STMT_PRINT,
  STMT_VAR,
  STMT_BLOCK,
  STMT_IF,
  STMT_WHILE,
  STMT_BREAK,
  STMT_CONTINUE,
  STMT_FOR,
  STMT_FUNCTION,
  STMT_RETURN,
} StmtType;

typedef struct Stmt {
  StmtType type;

  u32 line;

  union {

    Expr *expr;       // expression statement
    Expr *expr_print; // print statement

    struct {
      Token name;
      Expr *initializer; // optional initializer
    } var;               // var statement

    struct {
      struct Stmt **statements;
      i32 count;
    } block;

    struct {
      Expr *condition;
      struct Stmt *then_branch;
      struct Stmt *else_branch;
    } ifStmt;

    struct {
      Expr *condition;
      struct Stmt *body;
    } whileStmt;

    struct {
      Expr *condition;
      Expr *increment;
      struct Stmt *body;
    } forStmt;

    struct {
      Token name;
      Token *params;
      u8 paramCount;
      struct Stmt *body;
    } functionStmt;

    struct {
      Token keyword; // the 'return' token
      Expr *value;   // may be NULL
    } returnStmt;

  } as;
} Stmt;

#define MAX_SCOPES 64
#define MAX_SCOPE_VARS 256

typedef struct {
  const char *name;
  bool defined;
} ResolverVar;

typedef struct {
  ResolverVar vars[MAX_SCOPE_VARS];
  i32 varCount;
} ResolverScope;

typedef struct {
  ResolverScope scopes[MAX_SCOPES];
  i32 scopeCount;
} Resolver;

typedef struct {
  const char *key;
  Value value;
} EnvKV;

typedef struct Environment {
  EnvKV *entries;
  u32 count;
  u32 capacity;
  struct Environment *enclosing;
} Environment;

typedef struct LoxFunction {
  Token name;
  Token *params;
  u32 paramCount;
  Stmt *body;
  Environment *closure;
} LoxFunction;

typedef struct {
  Stmt **statements;
  u32 count;
  u32 capacity;
} Program;

const char *tokenTypeToString(TokenType type);

extern const Value NIL_VALUE;
extern const Value NO_VALUE;
Value errorValue(char *error);

void valueToString(Value value, char *buffer, u32 size);

typedef struct {
  u8 *data;
  u32 capacity;
  u32 offset;
} Arena;

void arenaInit(Arena *arena, u32 capacity);
void *arenaAlloc(Arena *arena, u32 size);
void arenaFree(Arena *arena);

typedef struct {
  const char *source;
  u32 start;
  u32 current;
  u32 line;

  Token *tokens;
  u32 count;
  u32 capacity;
} Scanner;

typedef struct {
  Token *tokens;
  u32 count;
  u32 current;

  u32 loopDepth;
  u32 functionDepth;

  u32 line;
} Parser;

typedef struct {
  bool hadError;
  bool hadRuntimeError;
  char errorMsg[512];
  char runtimeErrorMsg[512];
  char output[1024 * 10];
  u32 output_len;
  u32 indent;
  bool debugPrint;

  struct {
    ControlSignalType type;
    Value returnValue;
  } signal;

  Arena astArena;

  Scanner scanner;
  Parser parser;
  Environment *env;
} Lox;

void loxInit(Lox *lox, bool debugPrint);
void freeLox(Lox *lox);

void loxRun(Lox *lox, const char *source);
void loxRunPrompt(Lox *lox);
void loxRunFile(Lox *lox, const char *path);

void initScanner(Scanner *scanner, const char *source);
void freeScanner(Scanner *scanner);
Token *scanTokens(Lox *lox);

void initParser(Lox *lox);
bool isTokenEOF(Parser *parser);
bool checkToken(Parser *parser, TokenType type);
bool matchAnyTokenAdvance(Lox *lox, u32 count, ...);
Token consumeToken(Lox *lox, TokenType type, const char *message);
void advanceToken(Lox *lox);
Token prevToken(Parser *parser);
Token peekToken(Parser *parser);

Expr *parseExpression(Lox *lox);

bool isTruthy(Value v);
Value evaluate(Lox *lox, Expr *expr);

Stmt *parseStmt(Lox *lox);
Program *parseProgram(Lox *lox);
void executeStmt(Lox *lox, Stmt *stmt);
void executeProgram(Lox *lox, Program *prog);

Environment *envNew(Environment *enclosing);
void envFree(Environment *env);
void envDefine(Environment *env, const char *name, Value value);
Value evalVariable(Lox *lox, Expr *expr);
Value evalAssign(Lox *lox, Expr *expr);
void resolveStmt(Resolver *r, Lox *lox, Stmt *stmt);

void printExpr(Lox *lox, Expr *expr, Value result, u32 indent, bool space,
               bool newLine, char *msg);
void printValue(Value value);
void printToken(Lox *lox, const Token *token, u32 count, ...);
void printStmt(Lox *lox, Stmt *stmt, Value result, u32 indent);
void printEnvironment(Lox *lox);
void printProgram(Lox *lox, Program *prog);
void loxAppendOutput(Lox *lox, const char *s);

// Error handling
void reportError(Lox *lox, u32 line, const char *where, const char *message);
void scanError(Lox *lox, u32 line, const char *message);
void parseError(Lox *lox, const char *message);
void runtimeError(Lox *lox, Token token, const char *message);
void runtimeErrorAt(Lox *lox, u32 line, const char *message);
void printError(Lox *lox);
void synchronize(Lox *lox);

#endif
