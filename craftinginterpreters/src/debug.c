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

// void freeExpr(Expr *expr) {
//   if (!expr)
//     return;
//   switch (expr->type) {
//   case EXPR_BINARY:
//     freeExpr(expr->as.binary.left);
//     freeExpr(expr->as.binary.right);
//     break;
//   case EXPR_UNARY:
//     freeExpr(expr->as.unary.right);
//     break;
//   case EXPR_GROUPING:
//     freeExpr(expr->as.grouping.expression);
//     break;
//   case EXPR_LITERAL:
//     if (expr->as.literal.value.type == VAL_STRING)
//       free(expr->as.literal.value.as.string);
//     break;
//   case EXPR_VARIABLE:
//     if (expr->as.var.initializer)
//       freeExpr(expr->as.var.initializer);
//     break;
//   }
//   free(expr);
// }

// void freeStmt(Stmt *stmt) {
//   if (!stmt)
//     return;
//   switch (stmt->type) {
//   case STMT_PRINT:
//     freeExpr(stmt->as.printExpr);
//     break;
//   case STMT_EXPR:
//     freeExpr(stmt->as.expr);
//     break;
//   case STMT_VAR:
//     freeExpr(stmt->as.var.initializer);
//     break;
//   }
//   free(stmt);
// }

// void freeProgram(Program *prog) {
//   for (size_t i = 0; i < prog->count; i++) {
//     freeStmt(prog->statements[i]);
//   }
//   free(prog->statements);
//   free(prog);
// }

void loxReport(Lox *lox, int line, const char *where, const char *message) {
  fprintf(stderr, "[line %d] Error%s: %s\n", line, where, message);
  lox->hadError = true;
}

void loxError(Lox *lox, int line, const char *message) {
  loxReport(lox, line, "", message);
}

void parserError(Lox *lox, const char *message) {
  Token token = peekToken(&lox->parser);
  if (token.type == TOKEN_EOF) {
    loxReport(lox, token.line, " at end", message);
  } else {
    char where[64];
    snprintf(where, sizeof(where), " at '%s'", token.lexeme);
    loxReport(lox, token.line, where, message);
  }
}

void runtimeError(Lox *lox, Token op, const char *message) {
  fprintf(stderr, "[line %d] RuntimeError at '%.*s': %s\n", op.line,
          (int)(op.length), op.lexeme, message);
  lox->hadRuntimeError = true;
  exit(70);
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
    printValue(expr->as.literal.value, "LITERAL: ");
    break;

  case EXPR_GROUPING:
    printf("(group ");
    printExpr(expr->as.grouping.expression);
    printf(")");
    break;

  case EXPR_VARIABLE:
    printf("%.*s", expr->as.var.name.length, expr->as.var.name.lexeme);
    break;
  }
}

void printValue(Value value, char *msg) {
  char buffer[64];
  valueToString(value, buffer, sizeof(buffer));
  printf("%s %s", msg, buffer);
}

void printToken(Lox *lox, const Token *token) {
  if (lox->debugPrint) {
    printf(">: %s %s %p\n", tokenTypeToString(token->type), token->lexeme,
           token->literal);
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

void synchronize(Lox *lox) {
  Parser *parser = &lox->parser;

  advanceToken(parser);

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

    advanceToken(parser);
  }
}
