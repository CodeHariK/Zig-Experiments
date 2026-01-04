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
  stmt->as.expr_print = value;
  return stmt;
}

static Stmt *parseVarStmt(Lox *lox) {
  // consume "var"
  Token name = consumeToken(lox, TOKEN_IDENTIFIER, "Expect variable name.");

  Expr *initializer = NULL;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_EQUAL)) {
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
  if (matchAnyTokenAdvance(lox, 1, TOKEN_VAR)) {
    return parseVarStmt(lox);
  }
  return parseStmt(lox);
}

static Stmt *parseBlockStmt(Lox *lox) {
  Stmt **stmts = arenaAlloc(&lox->astArena, sizeof(Stmt *) * 8);
  int count = 0;
  int capacity = 8;

  while (!checkToken(&lox->parser, TOKEN_RIGHT_BRACE) &&
         !isTokenEOF(&lox->parser)) {

    Stmt *stmt = parseDeclaration(lox);
    if (stmt) {
      if (count >= capacity) {
        capacity *= 2;
        Stmt **new = arenaAlloc(&lox->astArena, sizeof(Stmt *) * capacity);
        memcpy(new, stmts, sizeof(Stmt *) * count);
        stmts = new;
      }
      stmts[count++] = stmt;
    }
  }

  consumeToken(lox, TOKEN_RIGHT_BRACE, "Expect '}' after block.");

  Stmt *block = arenaAlloc(&lox->astArena, sizeof(Stmt));
  block->type = STMT_BLOCK;
  block->as.block.statements = stmts;
  block->as.block.count = count;
  return block;
}

Stmt *parseStmt(Lox *lox) {
  Stmt *stmt = NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_BRACE)) {
    stmt = parseBlockStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_PRINT)) {
    stmt = parsePrintStmt(lox);
  } else {
    stmt = parseExprStatement(lox);
  }

  if (!stmt || lox->hadError) {
    synchronize(lox);
    return NULL;
  }

  return stmt;
}
void executeBlock(Lox *lox, Stmt **stmts, int count) {
  Environment *previous = lox->env;
  lox->env = envNew(previous);

  for (int i = 0; i < count; i++) {
    executeStmt(lox, stmts[i]);
  }

  lox->env = previous;
}

void executeStmt(Lox *lox, Stmt *stmt) {
  printStmt(lox, stmt);

  if (!stmt)
    return;

  switch (stmt->type) {
  case STMT_PRINT: {
    if (!stmt->as.expr_print) {
      loxError(lox, 0, "Null expression in print statement.", "");
      return;
    }
    Value val = evaluate(lox, stmt->as.expr_print);

    char buf[64];
    valueToString(val, buf, sizeof(buf));

    loxAppendOutput(lox, buf);
    loxAppendOutput(lox, "\n");

    printValue(lox, val, true, 1, "[STMT_PRINT_EVAL]");
    break;
  }

  case STMT_EXPR:
    if (stmt->as.expr) {
      Value val = evaluate(lox, stmt->as.expr);
      printValue(lox, val, true, 1, "[STMT_EXPR_EVAL]");
    }
    break;

  case STMT_VAR: {
    Value val = nilValue();
    if (stmt->as.var.initializer) {
      val = evaluate(lox, stmt->as.var.initializer);
    }
    envDefine(lox->env, stmt->as.var.name.lexeme, val);

    printValue(lox, val, true, 3, "[STMT_VAR_DEFINE] ",
               stmt->as.var.name.lexeme, " = ");

    break;

  case STMT_BLOCK:
    executeBlock(lox, stmt->as.block.statements, stmt->as.block.count);
    break;
  }
  }
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

void executeProgram(Lox *lox, Program *prog) {
  if (!prog)
    return;

  for (size_t i = 0; i < prog->count; i++) {
    printf("$:%-3d ", (int)i);
    executeStmt(lox, prog->statements[i]);

    if (lox->hadRuntimeError || lox->hadError)
      return; // stop on first error
  }
}
