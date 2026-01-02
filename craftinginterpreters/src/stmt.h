#include "lox.h"

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

Stmt *parseStmt(Lox *lox);
Program *parseProgram(Lox *lox);
void executeStmt(Lox *lox, Stmt *stmt, char *outBuffer, size_t bufSize);
void printStmt(Stmt *stmt);
bool envGet(Environment *env, const char *name, Value *out);
void printEnvironment(Lox *lox);
void freeStmt(Stmt *stmt);
