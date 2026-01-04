#include "lox.h"
#include <stdio.h>
#include <stdlib.h>

void freeLox(Lox *lox) {
  for (int i = 0; i < lox->env->count; i++) {
    free((void *)lox->env->entries[i].key);
  }
  free(lox->env->entries);
  free(lox->env);

  arenaFree(&lox->astArena);
}

void freeScanner(Scanner *scanner) {
  free(scanner->tokens);

  for (size_t i = 0; i < scanner->count; i++) {
    // free((void *)scanner->tokens[i].lexeme);
    free(scanner->tokens[i].literal);
  }
}

void loxError(Lox *lox, int line, const char *where, const char *message) {
  snprintf(lox->errorMsg, sizeof(lox->errorMsg), "[line %d] Error%s: %s\n",
           line, where, message);
  printf("%s", lox->errorMsg);
  lox->hadError = true;
}

void parserError(Lox *lox, const char *message) {
  Token token = peekToken(&lox->parser);
  if (token.type == TOKEN_EOF) {
    loxError(lox, token.line, " at end", message);
  } else {
    char where[64];
    snprintf(where, sizeof(where), " at '%s'", token.lexeme);
    loxError(lox, token.line, where, message);
  }
}

void runtimeError(Lox *lox, Token op, const char *message) {
  snprintf(lox->runtimeErrorMsg, sizeof(lox->runtimeErrorMsg),
           "[line %d] RuntimeError at '%.*s': %s\n", op.line, (int)(op.length),
           op.lexeme, message);
  printf("%s", lox->runtimeErrorMsg);
  lox->hadRuntimeError = true;
  // exit(70);
}

void printError(Lox *lox) {
  if (lox->hadError) {
    printf("%s", lox->errorMsg);
  }
  if (lox->hadRuntimeError) {
    printf("%s", lox->runtimeErrorMsg);
  }
  printf("\n");
}

void printValue(Value value, char *msg) {
  char buffer[64];
  valueToString(value, buffer, sizeof(buffer));
  printf("%s:%s", msg, buffer);
}

void printEnvironment(Lox *lox) {
  if (!lox->debugPrint)
    return;
  Environment *env = lox->env;
  if (!env) {
    printf("<null environment>\n");
    return;
  }

  printf("===== Environment =====\n(count=%d, capacity=%d):\n", env->count,
         env->capacity);
  for (int i = 0; i < env->count; i++) {
    char buffer[128];
    valueToString(env->entries[i].value, buffer, sizeof(buffer));
    printf("%s = %s\n", env->entries[i].key, buffer);
  }
  printf("=======================\n");
}

void printToken(Lox *lox, const Token *token) {
  if (lox->debugPrint) {
    printf("[TOK] %-15s '%.*s'\n", tokenTypeToString(token->type),
           token->length, token->lexeme);
  }
}

void printTokens(Lox *lox) {
  printf("SOURCE:\n%s\n", lox->scanner.source);
  for (size_t i = 0; i < lox->scanner.count; i++) {
    Token token = lox->scanner.tokens[i];
    printf("[TOK] %-15s '%.*s'\n", tokenTypeToString(token.type), token.length,
           token.lexeme);
  }
  printf("\n");
}

static void indentPrint(int indent) {
  for (int i = 0; i < indent; i++)
    printf("  ");
}

void printExprAST(Expr *expr, int indent) {
  if (!expr)
    return;

  indentPrint(indent);

  switch (expr->type) {
  case EXPR_LITERAL:
    printf("Literal ");
    printValue(expr->as.literal.value, "");
    printf("\n");
    break;

  case EXPR_VARIABLE:
    printf("Variable %.*s\n", (int)expr->as.var.name.length,
           expr->as.var.name.lexeme);
    break;

  case EXPR_ASSIGN:
    printf("Assign %.*s\n", (int)expr->as.assign.name.length,
           expr->as.assign.name.lexeme);
    printExprAST(expr->as.assign.value, indent + 1);
    break;

  case EXPR_BINARY:
    printf("Binary %.*s\n", (int)expr->as.binary.op.length,
           expr->as.binary.op.lexeme);
    printExprAST(expr->as.binary.left, indent + 1);
    printExprAST(expr->as.binary.right, indent + 1);
    break;

  case EXPR_GROUPING:
    printf("Grouping\n");
    printExprAST(expr->as.grouping.expression, indent + 1);
    break;

  case EXPR_UNARY:
    printf("Unary %.*s\n", (int)expr->as.unary.op.length,
           expr->as.unary.op.lexeme);
    printExprAST(expr->as.unary.right, indent + 1);
    break;
  }
}

void printExpr(Expr *expr) {
  if (!expr) {
    printf("nil");
    return;
  }

  switch (expr->type) {
  case EXPR_BINARY:
    printf("(%s ", tokenTypeToString(expr->as.binary.op.type));
    printExpr(expr->as.binary.left);
    printf(" ");
    printExpr(expr->as.binary.right);
    printf(")");
    break;

  case EXPR_UNARY:
    printf("(%s ", tokenTypeToString(expr->as.unary.op.type));
    printExpr(expr->as.unary.right);
    printf(")");
    break;

  case EXPR_LITERAL:
    printValue(expr->as.literal.value, "LITERAL");

    break;

  case EXPR_GROUPING:
    printf("(GROUP ");
    printExpr(expr->as.grouping.expression);
    printf(")");
    break;

  case EXPR_VARIABLE:
    printf("VARIABLE %.*s", expr->as.var.name.length, expr->as.var.name.lexeme);

    break;

  case EXPR_ASSIGN:
    printf("ASSIGN (= %.*s ", (int)expr->as.assign.name.length,
           expr->as.assign.name.lexeme);
    printExpr(expr->as.assign.value);
    printf(")");
    break;
  }
}

void printStmtAST(Stmt *stmt, int indent) {
  if (!stmt)
    return;

  indentPrint(indent);

  switch (stmt->type) {
  case STMT_PRINT:
    printf("printStmtAST\n");
    printExprAST(stmt->as.printExprAST, indent + 1);
    break;

  case STMT_EXPR:
    printf("ExprStmt\n");
    printExprAST(stmt->as.expr, indent + 1);
    break;

  case STMT_VAR:
    printf("VarStmt %.*s\n", (int)stmt->as.var.name.length,
           stmt->as.var.name.lexeme);
    if (stmt->as.var.initializer)
      printExprAST(stmt->as.var.initializer, indent + 1);
    break;
  }
}

void printStmt(Stmt *stmt) {
  if (!stmt) {
    printf("[NULL_STMT]");
    return;
  }

  switch (stmt->type) {
  case STMT_PRINT:
    printf("[STMT_PRINT] ");
    printExpr(stmt->as.printExprAST);
    printf("\n");
    break;
  case STMT_EXPR:
    printf("[STMT_EXPR] ");
    if (stmt->as.expr)
      printExpr(stmt->as.expr);
    printf("\n");
    break;
  case STMT_VAR: {
    printf("[STMT_VAR] %s = ", stmt->as.var.name.lexeme);
    printExpr(stmt->as.var.initializer);
    printf("\n");
    break;
  }
  }
}

void printProgram(Lox *lox, Program *prog) {
  if (!prog || !lox->debugPrint)
    return;

  printf("==== Program [%zu statements] ====\n", prog->count);

  for (size_t i = 0; i < prog->count; i++) {
    printf("%-3d ", (int)i);
    printStmt(prog->statements[i]);
  }

  printf("=================\n");
}

void printProgramAST(Lox *lox, Program *prog) {
  if (!prog || !lox->debugPrint)
    return;

  printf("Program (%zu statements)\n", prog->count);

  for (size_t i = 0; i < prog->count; i++) {
    printStmtAST(prog->statements[i], 1);
  }
}

void synchronize(Lox *lox) {
  Parser *parser = &lox->parser;

  printf("### SYNCHRONIZE ###\n");

  advanceToken(lox);

  while (!isTokenEOF(parser)) {
    if (prevToken(parser).type == TOKEN_SEMICOLON)
      return;

    switch (peekToken(parser).type) {
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

    advanceToken(lox);
  }
}
