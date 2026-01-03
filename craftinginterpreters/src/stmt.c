#include "lox.h"
#include <stdlib.h>
#include <string.h>

static Stmt *parseExprStatement(Lox *lox) {
  Expr *expr = parseExpression(lox);
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after expression.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_EXPR;
  stmt->as.expr = expr;
  return stmt;
}

static Stmt *parsePrintStmt(Lox *lox) {
  Expr *value = parseExpression(lox);
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after value.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_PRINT;
  stmt->as.printExpr = value;
  return stmt;
}

static Stmt *parseVarStmt(Lox *lox) {
  // consume "var"
  Token name = consumeToken(lox, TOKEN_IDENTIFIER, "Expect variable name.");

  Expr *initializer = NULL;
  if (matchAnyTokenAdvance(&lox->parser, 1, TOKEN_EQUAL)) {
    initializer = parseExpression(lox);
  }

  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_VAR;
  stmt->as.var.name = name;
  stmt->as.var.initializer = initializer;
  return stmt;
}

static Stmt *parseDeclaration(Lox *lox) {
  if (matchAnyTokenAdvance(&lox->parser, 1, TOKEN_VAR)) {
    return parseVarStmt(lox);
  }
  return parseStmt(lox);
}

Stmt *parseStmt(Lox *lox) {
  Stmt *stmt = NULL;

  if (matchAnyTokenAdvance(&lox->parser, 1, TOKEN_PRINT)) {
    stmt = parsePrintStmt(lox);
  } else if (matchAnyTokenAdvance(&lox->parser, 1, TOKEN_VAR)) {
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

Program *parseProgram(Lox *lox) {
  const int INIT_CAPACITY = 8;

  Program *prog = arenaAlloc(&lox->astArena, sizeof(Program));

  prog->count = 0;
  prog->capacity = INIT_CAPACITY;
  prog->statements = malloc(sizeof(Stmt *) * prog->capacity);
  if (!prog->statements)
    exit(1);

  while (!isTokenEOF(&lox->parser)) {
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

bool envGet(Environment *env, const char *name, Value *out) {
  for (int i = env->count - 1; i >= 0; i--) {
    if (strcmp(env->entries[i].key, name) == 0) {
      *out = env->entries[i].value;
      return true;
    }
  }
  return false;
}
