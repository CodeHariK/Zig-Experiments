#include "lox.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

void freeLox(Lox *lox) {
  for (u32 i = 0; i < lox->env->count; i++) {
    free((void *)lox->env->entries[i].key);
  }
  free(lox->env->entries);
  free(lox->env);

  arenaFree(&lox->astArena);
}

void freeScanner(Scanner *scanner) {
  free(scanner->tokens);

  for (u32 i = 0; i < scanner->count; i++) {
    // free((void *)scanner->tokens[i].lexeme);
    free(scanner->tokens[i].literal);
  }
}

// Error handling implementations
void reportError(Lox *lox, u32 line, const char *where, const char *message) {
  snprintf(lox->errorMsg, sizeof(lox->errorMsg), "[line %d] Error%s: %s\n",
           line, where, message);
  printf("%s", lox->errorMsg);
  lox->hadError = true;
}

void scanError(Lox *lox, u32 line, const char *message) {
  reportError(lox, line, "", message);
}

void parseError(Lox *lox, const char *message) {
  Token token = peekToken(&lox->parser);
  if (token.type == TOKEN_EOF) {
    reportError(lox, token.line, " at EOF", message);
  } else {
    char where[64];
    snprintf(where, sizeof(where), " at '%.*s'", (int)token.length,
             token.lexeme);
    reportError(lox, token.line, where, message);
  }
}

void runtimeError(Lox *lox, Token token, const char *message) {
  snprintf(lox->runtimeErrorMsg, sizeof(lox->runtimeErrorMsg),
           "[line %d] RuntimeError at '%.*s': %s\n", token.line,
           (int)(token.length), token.lexeme, message);
  printf("%s", lox->runtimeErrorMsg);
  lox->hadRuntimeError = true;
}

void runtimeErrorAt(Lox *lox, u32 line, const char *message) {
  snprintf(lox->runtimeErrorMsg, sizeof(lox->runtimeErrorMsg),
           "[line %d] RuntimeError: %s\n", line, message);
  printf("%s", lox->runtimeErrorMsg);
  lox->hadRuntimeError = true;
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

void indentPrint(int indent) {
  for (int i = 0; i < indent; i++)
    printf("   ");
}

void printValue(Value value) {
  char valueBuf[64];
  valueToString(value, valueBuf, sizeof(valueBuf));
  fputs(valueBuf, stdout);
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
  for (u32 i = 0; i < env->count; i++) {
    char buffer[128];
    valueToString(env->entries[i].value, buffer, sizeof(buffer));
    printf("%s = %s\n", env->entries[i].key, buffer);
  }
  printf("=======================\n");
}

void printToken(Lox *lox, const Token *token, char *msg) {
  if (true || !lox->debugPrint)
    return;

  printf("%s[TOK] %-20s '%.*s'\n", msg, tokenTypeToString(token->type),
         token->length, token->lexeme);
}

void printExpr(Lox *lox, Expr *expr, Value result, u32 indent, bool space,
               bool newLine, char *msg) {
  if (!lox->debugPrint) {
    return;
  }
  if (!expr) {
    printf("[NULL_EXPR]");
    return;
  }

  indentPrint(indent);

  printf("%s", msg);

  // if (space)
  //   printf("%-12s", "");

  switch (expr->type) {
  case EXPR_BINARY: {
    printValue(result);
    printf(" (");
    printExpr(lox, expr->as.binary.left, NO_VALUE, 0, false, false, "");
    printf("%s ", tokenTypeToString(expr->as.binary.op.type));
    printExpr(lox, expr->as.binary.right, NO_VALUE, 0, false, false, "");
    printf(")");
    break;
  }
  case EXPR_UNARY: {
    printValue(result);
    printf("%s ", tokenTypeToString(expr->as.unary.op.type));
    printExpr(lox, expr->as.unary.right, NO_VALUE, 0, false, false, "");
    break;
  }
  case EXPR_LITERAL: {
    printValue(expr->as.literal.value);
    break;
  }
  case EXPR_GROUPING: {
    printValue(result);
    printf(" (GROUP");
    printExpr(lox, expr->as.grouping.expression, NO_VALUE, 0, false, false, "");
    printf(")");
    break;
  }

  case EXPR_VARIABLE: {
    printf("$%s ", expr->as.var.name.lexeme);
    printValue(result);
    break;
  }

  case EXPR_ASSIGN: {
    printf("%s = ", expr->as.assign.name.lexeme);
    printValue(result);
    printExpr(lox, expr->as.assign.value, NO_VALUE, 0, false, false, "");
    break;
  }
  case EXPR_LOGICAL: {
    printValue(result);
    printExpr(lox, expr->as.logical.left, NO_VALUE, 0, false, false, " ");
    printf(" %s ", tokenTypeToString(expr->as.logical.op.type));
    printExpr(lox, expr->as.logical.right, NO_VALUE, 0, false, false, "");
    break;
  }
  case EXPR_CALL: {
    printExpr(lox, expr->as.call.callee, NO_VALUE, 0, false, false, "");
    printf("(");
    for (u8 i = 0; i < expr->as.call.argCount; i++) {
      printExpr(lox, expr->as.call.arguments[i], NO_VALUE, 0, false, false, "");
      if (i < expr->as.call.argCount - 1) {
        printf(",");
      }
    }
    printf(")");
    break;
  }
  case EXPR_GET: {
    printExpr(lox, expr->as.getExpr.object, NO_VALUE, 0, false, false, "");
    printf(".%s", expr->as.getExpr.name.lexeme);

    break;
  }
  case EXPR_SET: {
    printf("[EXPR_SET] ");
    printExpr(lox, expr->as.setExpr.object, NO_VALUE, 0, false, false, "");
    printf(".%s = ", expr->as.setExpr.name.lexeme);
    printExpr(lox, expr->as.setExpr.value, NO_VALUE, 0, false, false, "");
    break;
  }
  case EXPR_THIS: {
    printf("%s", expr->as.thisExpr.keyword.lexeme);
    break;
  }
  }

  if (newLine) {
    printf("\n");
  }
}

void printStmt(Lox *lox, Stmt *stmt, Value result, u32 indent) {
  if (!lox->debugPrint)
    return;

  indentPrint(indent);

  if (!stmt) {
    printf("[NULL_STMT]\n");
    return;
  }

  char valueBuf[64];
  valueToString(result, valueBuf, sizeof(valueBuf));

  printf("@%-3d: ", stmt->line);

  switch (stmt->type) {
  case STMT_PRINT: {
    printExpr(lox, stmt->as.expr_print, result, 0, false, true,
              "[STMT_PRINT] ");
    break;
  }
  case STMT_EXPR: {
    printExpr(lox, stmt->as.expr, result, 0, false, true, "[STMT_EXPR] ");
    break;
  }
  case STMT_VAR: {
    printf("[STMT_VAR] %s = ", stmt->as.var.name.lexeme);
    printExpr(lox, stmt->as.var.initializer, result, 0, false, true, "");
    break;
  }
  case STMT_BLOCK: {
    printf("[STMT_BLOCK]\n");
    for (i32 i = 0; i < stmt->as.block.count; i++) {
      printStmt(lox, stmt->as.block.statements[i], result, indent + 1);
    }
    break;
  }

  case STMT_IF: {
    printf("[STMT_IF]\n");

    indentPrint(indent + 1);
    printf("condition:\n");
    printExpr(lox, stmt->as.ifStmt.condition, result, indent + 2, false, true,
              "");

    indentPrint(indent + 1);
    printf("then:\n");
    printStmt(lox, stmt->as.ifStmt.then_branch, result, indent + 2);

    if (stmt->as.ifStmt.else_branch) {
      indentPrint(indent + 1);
      printf("else:\n");
      printStmt(lox, stmt->as.ifStmt.else_branch, result, indent + 2);
    }
    break;
  }

  case STMT_WHILE: {
    printf("[STMT_WHILE]\n");

    indentPrint(indent + 1);
    printf("condition:\n");
    printExpr(lox, stmt->as.whileStmt.condition, result, indent + 2, false,
              true, "");

    indentPrint(indent + 1);
    printf("body:\n");
    printStmt(lox, stmt->as.whileStmt.body, result, indent + 2);
    break;
  }
  case STMT_FOR: {
    printf("[STMT_FOR]\n");

    indentPrint(indent + 1);
    printf("condition:\n");
    if (stmt->as.forStmt.condition) {
      printExpr(lox, stmt->as.forStmt.condition, result, indent + 2, false,
                true, "");
    } else {
      indentPrint(indent + 2);
      printf("(none)\n");
    }

    indentPrint(indent + 1);
    printf("increment:\n");
    if (stmt->as.forStmt.increment) {
      printExpr(lox, stmt->as.forStmt.increment, result, indent + 2, false,
                true, "");
    } else {
      indentPrint(indent + 2);
      printf("(none)\n");
    }

    indentPrint(indent + 1);
    printf("body:\n");
    printStmt(lox, stmt->as.forStmt.body, result, indent + 2);
    break;
  }

  case STMT_FUNCTION: {
    printf("[STMT_FUNCTION] %s (", stmt->as.functionStmt.name.lexeme);

    for (u8 i = 0; i < stmt->as.functionStmt.paramCount; i++) {
      Token t = stmt->as.functionStmt.params[i];
      printf("%s", t.lexeme);
      if (i < stmt->as.functionStmt.paramCount - 1) {
        printf(",");
      }
    }
    printf(")\n");

    printStmt(lox, stmt->as.functionStmt.body, result, indent + 2);

    break;
  }

  case STMT_CLASS: {
    printf("[STMT_CLASS] %s \n", stmt->as.classStmt.name.lexeme);

    for (u8 i = 0; i < stmt->as.classStmt.methodCount; i++) {
      Stmt *t = stmt->as.classStmt.methods[i];
      printStmt(lox, t, NO_VALUE, indent + 2);
    }
    printf(")\n");

    break;
  }

  case STMT_BREAK:
    printf("[STMT_BREAK]\n");
    break;
  case STMT_CONTINUE:
    printf("[STMT_CONTINUE]\n");
    break;
  case STMT_RETURN:
    printf("[STMT_RETURN]\n");
    break;
  }
}

void printProgram(Lox *lox, Program *prog) {
  if (!prog || !lox->debugPrint)
    return;

  printf("==== Program [%d statements] ====\n", prog->count);

  for (u32 i = 0; i < prog->count; i++) {
    printStmt(lox, prog->statements[i], NO_VALUE, 0);
  }

  printf("=================\n");
}

void loxAppendOutput(Lox *lox, const char *s) {
  int remaining = sizeof(lox->output) - lox->output_len - 1;
  if (remaining <= 0)
    return;

  int written = snprintf(lox->output + lox->output_len, remaining, "%s", s);

  if (written > 0)
    lox->output_len += written;
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
