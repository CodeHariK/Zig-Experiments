#include "stmt.h"
#include "lox.h"
#include "parser.h"
#include <stdlib.h>
#include <string.h>

static void synchronize(Lox *lox) {
  Parser *parser = &lox->parser;

  advance(parser);

  while (!isAtEnd(parser)) {
    if (previous(parser).type == TOKEN_SEMICOLON)
      return;

    switch (peek(parser).type) {
    case TOKEN_CLASS:
    case TOKEN_FUN:
    case TOKEN_VAR:
    case TOKEN_FOR:
    case TOKEN_IF:
    case TOKEN_WHILE:
    case TOKEN_PRINT:
    case TOKEN_RETURN:
      return;
    default:
      break;
    }

    advance(parser);
  }
}

static Stmt *parseExprStatement(Lox *lox) {
  Expr *expr = parseExpression(lox);
  consume(lox, TOKEN_SEMICOLON, "Expect ';' after expression.");

  Stmt *stmt = malloc(sizeof(Stmt));
  if (!stmt)
    exit(1);
  stmt->type = STMT_EXPR;
  stmt->as.expr = expr;
  return stmt;
}

static Stmt *parsePrintStmt(Lox *lox) {
  Expr *value = parseExpression(lox);
  consume(lox, TOKEN_SEMICOLON, "Expect ';' after value.");

  Stmt *stmt = malloc(sizeof(Stmt));
  if (!stmt)
    exit(1);
  stmt->type = STMT_PRINT;
  stmt->as.printExpr = value;
  return stmt;
}

static Stmt *parseVarStmt(Lox *lox) {
  // consume "var"
  Token name = consume(lox, TOKEN_IDENTIFIER, "Expect variable name.");

  Expr *initializer = NULL;
  if (match(&lox->parser, 1, TOKEN_EQUAL)) {
    initializer = parseExpression(lox);
  }

  consume(lox, TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

  Stmt *stmt = malloc(sizeof(Stmt));
  stmt->type = STMT_VAR;
  stmt->as.var.name = name;
  stmt->as.var.initializer = initializer;
  return stmt;
}

static Stmt *parseDeclaration(Lox *lox) {
  if (match(&lox->parser, 1, TOKEN_VAR)) {
    return parseVarStmt(lox);
  }
  return parseStmt(lox);
}

Stmt *parseStmt(Lox *lox) {
  Stmt *stmt = NULL;

  if (match(&lox->parser, 1, TOKEN_PRINT)) {
    stmt = parsePrintStmt(lox);
  } else if (match(&lox->parser, 1, TOKEN_VAR)) {
    stmt = parseVarStmt(lox);
  } else {
    stmt = parseExprStatement(lox);
  }

  if (!stmt || lox->hadError) {
    synchronize(lox); // skip to next statement
    return NULL;
  }

  return stmt;
}

void envDefine(Environment *env, const char *name, Value value) {
  if (env->count >= env->capacity) {
    env->capacity = env->capacity < 8 ? 8 : env->capacity * 2;
    env->entries = realloc(env->entries, sizeof(EnvKV) * env->capacity);
  }

  env->entries[env->count].key = strdup(name);
  env->entries[env->count].value = value;
  env->count++;
}

void printStmt(Stmt *stmt) {
  switch (stmt->type) {
  case STMT_PRINT:
    printf("(print ");
    printExpr(stmt->as.printExpr);
    printf(")\n");
    break;
  case STMT_EXPR:
    printf("(expr ");
    if (stmt->as.expr)
      printExpr(stmt->as.expr);
    printf(")\n");
    break;
  case STMT_VAR: {
    printf("(var %s ...)\n", stmt->as.var.name.lexeme);
    break;
  }
  }
}

Program *parseProgram(Lox *lox) {
  const int INIT_CAPACITY = 8;

  Program *prog = malloc(sizeof(Program));
  if (!prog)
    exit(1);

  prog->count = 0;
  prog->capacity = INIT_CAPACITY;
  prog->statements = malloc(sizeof(Stmt *) * prog->capacity);
  if (!prog->statements)
    exit(1);

  while (!isAtEnd(&lox->parser)) {
    Stmt *stmt = parseDeclaration(lox);

    if (prog->count >= prog->capacity) {
      prog->capacity *= 2;
      prog->statements =
          realloc(prog->statements, sizeof(Stmt *) * prog->capacity);
      if (!prog->statements)
        exit(1);
    }

    prog->statements[prog->count++] = stmt;
  }

  return prog;
}

void executeStmt(Lox *lox, Stmt *stmt, char *outBuffer, size_t bufSize) {
  if (!stmt)
    return;

  switch (stmt->type) {
  case STMT_PRINT: {
    if (!stmt->as.printExpr) {
      loxError(lox, 0, "Null expression in print statement.");
      return;
    }
    Value val = evaluate(lox, stmt->as.printExpr);
    if (outBuffer && bufSize > 0)
      valueToString(val, outBuffer, bufSize);
    printValue(val, "PRINT: ");
    printf("\n");
    break;
  }

  case STMT_EXPR:
    if (stmt->as.expr)
      evaluate(lox, stmt->as.expr);
    break;

  case STMT_VAR: {
    Value val = nilValue();
    if (stmt->as.var.initializer)
      val = evaluate(lox, stmt->as.var.initializer);
    envDefine(lox->env, stmt->as.var.name.lexeme, val);

    envGet(lox->env, stmt->as.var.name.lexeme, &val);
    printValue(val, "VAR: ");
    printf("\n");

    break;
  }
  }
}

void printEnvironment(Lox *lox) {
  if (!lox->debugPrint)
    return;
  Environment *env = lox->env;
  if (!env) {
    printf("<null environment>\n");
    return;
  }

  printf("> Environment (count=%d, capacity=%d):\n", env->count, env->capacity);
  for (int i = 0; i < env->count; i++) {
    char buffer[128];
    valueToString(env->entries[i].value, buffer, sizeof(buffer));
    printf("%s = %s\n", env->entries[i].key, buffer);
  }
}

void freeStmt(Stmt *stmt) {
  if (!stmt)
    return;
  switch (stmt->type) {
  case STMT_PRINT:
    freeExpr(stmt->as.printExpr);
    break;
  case STMT_EXPR:
    freeExpr(stmt->as.expr);
    break;
  case STMT_VAR:
    freeExpr(stmt->as.var.initializer);
    break;
  }
  free(stmt);
}

void freeProgram(Program *prog) {
  for (size_t i = 0; i < prog->count; i++) {
    freeStmt(prog->statements[i]);
  }
  free(prog->statements);
  free(prog);
}

bool envGet(Environment *env, const char *name, Value *out) {
  for (int i = env->count - 1; i >= 0; i--) {
    if (strcmp(env->entries[i].key, name) == 0) {
      *out = env->entries[i].value;
      return true;
    }
  }
  return false;
}
