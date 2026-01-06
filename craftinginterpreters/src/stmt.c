#include "lox.h"
#include <stdlib.h>
#include <string.h>

static Stmt *parseExprStatement(Lox *lox) {
  Expr *expr = parseExpression(lox);
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after expression.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_EXPR;
  stmt->as.expr = expr;
  stmt->line = lox->parser.line++;
  return stmt;
}

static Stmt *parsePrintStmt(Lox *lox) {
  Expr *value = parseExpression(lox);
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after value.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_PRINT;
  stmt->as.expr_print = value;
  stmt->line = lox->parser.line++;
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
  stmt->line = lox->parser.line++;
  return stmt;
}

static Stmt *parseDeclaration(Lox *lox) {
  if (matchAnyTokenAdvance(lox, 1, TOKEN_VAR)) {
    return parseVarStmt(lox);
  }
  return parseStmt(lox);
}

static Stmt *parseBlockStmt(Lox *lox) {
  int line = lox->parser.line++;

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
  block->line = line;
  return block;
}

static Stmt *parseIfStmt(Lox *lox) {
  int line = lox->parser.line++;

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
  Expr *condition = parseExpression(lox);
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after 'if'.");

  Stmt *thenBranch = parseStmt(lox);

  Stmt *ifStmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  ifStmt->type = STMT_IF;
  ifStmt->as.ifStmt.condition = condition;
  ifStmt->as.ifStmt.then_branch = thenBranch;
  ifStmt->line = line;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_ELSE)) {
    ifStmt->as.ifStmt.else_branch = parseStmt(lox);
  } else {
    ifStmt->as.ifStmt.else_branch = NULL;
  }

  return ifStmt;
}

static Stmt *parseBreakStmt(Lox *lox) {
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after 'break'.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_BREAK;
  stmt->line = lox->parser.line++;

  if (lox->parser.loopDepth == 0) {
    loxError(lox, prevToken(&lox->parser).line,
             "Can't use 'break' outside of a loop.", "");
  }

  return stmt;
}

static Stmt *parseContinueStmt(Lox *lox) {
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after 'continue'.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_CONTINUE;
  stmt->line = lox->parser.line++;
  return stmt;
}

static Stmt *parseWhileStmt(Lox *lox) {
  int line = lox->parser.line++;

  lox->parser.loopDepth++;

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
  Expr *condition = parseExpression(lox);
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after 'while'.");

  Stmt *body = parseStmt(lox);

  Stmt *whileStmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  whileStmt->type = STMT_WHILE;
  whileStmt->as.whileStmt.condition = condition;
  whileStmt->as.whileStmt.body = body;
  whileStmt->line = line;

  lox->parser.loopDepth--;

  return whileStmt;
}

static Stmt *parseForStmt(Lox *lox) {
  int line = lox->parser.line;

  lox->parser.loopDepth++;

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");

  // 1️⃣ initializer
  Stmt *initializer = NULL;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_SEMICOLON)) {
    initializer = NULL;
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_VAR)) {
    initializer = parseVarStmt(lox);
  } else {
    initializer = parseExprStatement(lox);
  }

  // 2️⃣ condition
  Expr *condition = NULL;
  if (!checkToken(&lox->parser, TOKEN_SEMICOLON)) {
    condition = parseExpression(lox);
  }
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after loop condition.");

  // 3️⃣ increment
  Expr *increment = NULL;
  if (!checkToken(&lox->parser, TOKEN_RIGHT_PAREN)) {
    increment = parseExpression(lox);
  }
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");

  // 4️⃣ body
  Stmt *body = parseStmt(lox);

  // Create STMT_FOR
  Stmt *forStmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  forStmt->type = STMT_FOR;
  forStmt->as.forStmt.condition = condition;
  forStmt->as.forStmt.increment = increment;
  forStmt->as.forStmt.body = body;
  forStmt->line = line;

  // If initializer exists, wrap everything in a block
  if (initializer) {
    Stmt **stmts = arenaAlloc(&lox->astArena, sizeof(Stmt *) * 2);
    stmts[0] = initializer;
    stmts[1] = forStmt;

    Stmt *block = arenaAlloc(&lox->astArena, sizeof(Stmt));
    block->type = STMT_BLOCK;
    block->as.block.statements = stmts;
    block->as.block.count = 2;
    block->line = line;

    lox->parser.loopDepth--;
    return block;
  }

  lox->parser.loopDepth--;
  return forStmt;
}

Stmt *parseStmt(Lox *lox) {
  Stmt *stmt = NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_IF)) {
    stmt = parseIfStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_WHILE)) {
    stmt = parseWhileStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_FOR)) {
    stmt = parseForStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_BREAK)) {
    stmt = parseBreakStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_CONTINUE)) {
    stmt = parseContinueStmt(lox);
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_BRACE)) {
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

    if (lox->breakSignal || lox->continueSignal)
      break;
  }

  lox->env = previous;
}

void executeStmt(Lox *lox, Stmt *stmt) {
  // printStmt(lox, stmt);

  if (!stmt)
    return;

  switch (stmt->type) {
  case STMT_PRINT: {
    if (!stmt->as.expr_print) {
      loxError(lox, 0, "Null expression in print statement.", "");
      return;
    }
    Value result = evaluate(lox, stmt->as.expr_print);

    char buf[64];
    valueToString(result, buf, sizeof(buf));

    loxAppendOutput(lox, buf);
    loxAppendOutput(lox, "\n");

    printStmt(lox, stmt, result, 0);
    break;
  }

  case STMT_EXPR: {
    if (stmt->as.expr) {
      Value val = evaluate(lox, stmt->as.expr);
      printStmt(lox, stmt, val, 0);
    }
    break;
  }

  case STMT_VAR: {
    Value val = NIL_VALUE;
    if (stmt->as.var.initializer) {
      val = evaluate(lox, stmt->as.var.initializer);
    }
    envDefine(lox->env, stmt->as.var.name.lexeme, val);

    printStmt(lox, stmt, val, 0);

    break;
  }

  case STMT_BLOCK:
    executeBlock(lox, stmt->as.block.statements, stmt->as.block.count);
    break;

  case STMT_IF: {
    if (isTruthy(evaluate(lox, stmt->as.ifStmt.condition))) {
      executeStmt(lox, stmt->as.ifStmt.then_branch);
    } else if (stmt->as.ifStmt.else_branch) {
      executeStmt(lox, stmt->as.ifStmt.else_branch);
    }

    if (lox->breakSignal) {
      return;
    }

    break;
  }

  case STMT_WHILE: {
    while (!lox->hadRuntimeError && !lox->hadError &&
           isTruthy(evaluate(lox, stmt->as.whileStmt.condition))) {

      executeStmt(lox, stmt->as.whileStmt.body);

      if (lox->breakSignal) {
        lox->breakSignal = false;
        break;
      }

      if (lox->continueSignal) {
        lox->continueSignal = false;
        continue;
      }
    }
    break;
  }

  case STMT_FOR: {
    while (!lox->hadRuntimeError && !lox->hadError) {
      if (stmt->as.forStmt.condition &&
          !isTruthy(evaluate(lox, stmt->as.forStmt.condition))) {
        break;
      }

      executeStmt(lox, stmt->as.forStmt.body);

      if (lox->breakSignal) {
        lox->breakSignal = false;
        break;
      }

      if (lox->continueSignal) {
        lox->continueSignal = false;
        // fall through to increment
      }

      if (stmt->as.forStmt.increment) {
        evaluate(lox, stmt->as.forStmt.increment);
      }
    }
    break;
  }

  case STMT_BREAK: {
    lox->breakSignal = true;
    break;
  }

  case STMT_CONTINUE: {
    lox->continueSignal = true;
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
    executeStmt(lox, prog->statements[i]);

    if (lox->hadRuntimeError || lox->hadError)
      return; // stop on first error
  }
}
