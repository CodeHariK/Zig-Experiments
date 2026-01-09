#include "lox.h"
#include <stdlib.h>
#include <string.h>

static Stmt *parseDeclaration(Lox *lox);

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

static Stmt *parseFunctionStmt(Lox *lox) {
  Token name = consumeToken(lox, TOKEN_IDENTIFIER, "Expect function name.");

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after function name.");

  lox->parser.functionDepth++;

  Token *params = NULL;
  int paramCount = 0;
  int capacity = 0;

  if (!checkToken(&lox->parser, TOKEN_RIGHT_PAREN)) {
    do {
      if (paramCount >= 255) {
        parseError(lox, "Can't have more than 255 parameters.");
      }

      if (paramCount + 1 > capacity) {
        capacity = capacity < 8 ? 8 : capacity * 2;
        Token *newParams = arenaAlloc(&lox->astArena, sizeof(Token) * capacity);
        if (params)
          memcpy(newParams, params, sizeof(Token) * paramCount);
        params = newParams;
      }

      params[paramCount++] =
          consumeToken(lox, TOKEN_IDENTIFIER, "Expect parameter name.");
    } while (matchAnyTokenAdvance(lox, 1, TOKEN_COMMA));
  }

  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after parameters.");

  consumeToken(lox, TOKEN_LEFT_BRACE, "Expect '{' before function body.");
  Stmt *body = parseBlockStmt(lox);

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_FUNCTION;
  stmt->as.functionStmt.name = name;
  stmt->as.functionStmt.params = params;
  stmt->as.functionStmt.paramCount = paramCount;
  stmt->as.functionStmt.body = body;
  stmt->line = name.line;

  lox->parser.functionDepth--;

  return stmt;
}

static Stmt *parseClassStmt(Lox *lox) {
  Token tok = consumeToken(lox, TOKEN_IDENTIFIER, "Expect class name.");

  Expr *superclass = NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_LESS)) {
    Token superClassToken =
        consumeToken(lox, TOKEN_IDENTIFIER, "Expect superclass name.");
    superclass = parseVariableExpr(lox, superClassToken);
  }

  consumeToken(lox, TOKEN_LEFT_BRACE, "Expect '{' before class body.");

  Stmt **methods = arenaAlloc(&lox->astArena, sizeof(Stmt *) * 8);
  int count = 0, capacity = 8;

  while (!checkToken(&lox->parser, TOKEN_RIGHT_BRACE) &&
         !isTokenEOF(&lox->parser)) {

    if (count >= capacity) {
      capacity *= 2;
      Stmt **new = arenaAlloc(&lox->astArena, sizeof(Stmt *) * capacity);
      memcpy(new, methods, sizeof(Stmt *) * count);
      methods = new;
    }

    methods[count++] = parseFunctionStmt(lox);
  }

  consumeToken(lox, TOKEN_RIGHT_BRACE, "Expect '}' after class body.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_CLASS;
  stmt->as.classStmt.name = tok;
  stmt->as.classStmt.methods = methods;
  stmt->as.classStmt.methodCount = count;
  stmt->line = tok.line;
  stmt->as.classStmt.superclass = superclass;

  return stmt;
}

static Stmt *parseIfStmt(Lox *lox) {
  int line = lox->parser.line++;

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
  Expr *condition = parseExpression(lox);
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after 'if'.");

  consumeToken(lox, TOKEN_LEFT_BRACE, "Expect '{' after if condition.");
  Stmt *thenBranch = parseBlockStmt(lox);

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
    reportError(lox, prevToken(&lox->parser).line, " at 'break'",
                "Can't use 'break' outside of a loop.");
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

static Stmt *parseReturnStmt(Lox *lox) {
  Token keyword = prevToken(&lox->parser);
  Expr *value = NULL;

  if (!checkToken(&lox->parser, TOKEN_SEMICOLON)) {
    value = parseExpression(lox);
  }

  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after return value.");

  Stmt *stmt = arenaAlloc(&lox->astArena, sizeof(Stmt));
  stmt->type = STMT_RETURN;
  stmt->as.returnStmt.keyword = keyword;
  stmt->as.returnStmt.value = value;
  stmt->line = keyword.line;

  return stmt;
}

static Stmt *parseWhileStmt(Lox *lox) {
  int line = lox->parser.line++;

  lox->parser.loopDepth++;

  consumeToken(lox, TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
  Expr *condition = parseExpression(lox);
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after 'while'.");

  consumeToken(lox, TOKEN_LEFT_BRACE, "Expect '{' after while condition.");
  Stmt *body = parseBlockStmt(lox);

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

  Stmt *initializer = NULL;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_SEMICOLON)) {
    initializer = NULL;
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_VAR)) {
    initializer = parseVarStmt(lox);
  } else {
    initializer = parseExprStatement(lox);
  }

  Expr *condition = NULL;
  if (!checkToken(&lox->parser, TOKEN_SEMICOLON)) {
    condition = parseExpression(lox);
  }
  consumeToken(lox, TOKEN_SEMICOLON, "Expect ';' after loop condition.");

  Expr *increment = NULL;
  if (!checkToken(&lox->parser, TOKEN_RIGHT_PAREN)) {
    increment = parseExpression(lox);
  }
  consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");

  consumeToken(lox, TOKEN_LEFT_BRACE, "Expect '{' after while condition.");
  Stmt *body = parseBlockStmt(lox);

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
  } else if (matchAnyTokenAdvance(lox, 1, TOKEN_RETURN)) {
    if (lox->parser.loopDepth == 0 && lox->parser.functionDepth == 0) {
      reportError(lox, prevToken(&lox->parser).line, " at 'return'",
                  "Can't return from top-level code.");
    }
    return parseReturnStmt(lox);
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

static Stmt *parseDeclaration(Lox *lox) {
  if (matchAnyTokenAdvance(lox, 1, TOKEN_FUN)) {
    return parseFunctionStmt(lox);
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_VAR)) {
    return parseVarStmt(lox);
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_CLASS)) {
    return parseClassStmt(lox);
  }
  return parseStmt(lox);
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
