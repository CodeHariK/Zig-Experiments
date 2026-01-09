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

void runtimeError(Lox *lox, Token *token, Expr *expr, const char *message) {
  if (token) {
    snprintf(lox->runtimeErrorMsg, sizeof(lox->runtimeErrorMsg),
             "[line %d] RuntimeError at '%.*s': %s\n", token->line,
             (int)(token->length), token->lexeme, message);
  }
  if (expr) {
    snprintf(lox->runtimeErrorMsg, sizeof(lox->runtimeErrorMsg),
             "[line %d] RuntimeError: %s\n", expr->line, message);
  }

  indentPrint(lox->indent + 1);
  printf("%s", lox->runtimeErrorMsg);
  lox->hadRuntimeError = true;
}

void indentPrint(int indent) {
  for (int i = 0; i < indent; i++)
    printf("|   ");
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

void printEnv(Lox *lox, const char *name, Value value, char *msg) {
  if (lox) {
    indentPrint(lox->indent);
    printf("%s %s = ", msg, name);
    printValue(value);
    printf("\n");
  }
}

void printExpr(Lox *lox, Expr *expr, Value result, u32 indent, bool newLine,
               char *msg) {
  if (!lox->debugPrint) {
    return;
  }

  if (!expr) {
    printf("[NULL_EXPR]");
    return;
  }

  indentPrint(indent);
  printf("%s", msg);

  switch (expr->type) {
  case EXPR_BINARY: {
    printValue(result);
    printf(" (");
    printExpr(lox, expr->as.binary.left, NO_VALUE, 0, false, "");
    printf(" %s ", tokenTypeToString(expr->as.binary.op.type));
    printExpr(lox, expr->as.binary.right, NO_VALUE, 0, false, "");
    printf(")");
    break;
  }
  case EXPR_UNARY: {
    printValue(result);
    printf(" %s", tokenTypeToString(expr->as.unary.op.type));
    printExpr(lox, expr->as.unary.right, NO_VALUE, 0, false, "");
    break;
  }
  case EXPR_LITERAL: {
    printValue(expr->as.literal.value);
    break;
  }
  case EXPR_GROUPING: {
    printValue(result);
    printExpr(lox, expr->as.grouping.expression, NO_VALUE, 0, false, "");
    break;
  }

  case EXPR_VARIABLE: {
    printf("$%s ", expr->as.var.name.lexeme);
    printValue(result);
    break;
  }

  case EXPR_ASSIGN: {
    printf("%s = ", expr->as.assign.name.lexeme);
    printExpr(lox, expr->as.assign.value, NO_VALUE, 0, false, "");
    break;
  }
  case EXPR_LOGICAL: {
    printValue(result);
    printExpr(lox, expr->as.logical.left, NO_VALUE, 0, false, " ");
    printf(" %s ", tokenTypeToString(expr->as.logical.op.type));
    printExpr(lox, expr->as.logical.right, NO_VALUE, 0, false, "");
    break;
  }
  case EXPR_CALL: {
    printExpr(lox, expr->as.call.callee, NO_VALUE, 0, false, "");
    printf("(");
    for (u8 i = 0; i < expr->as.call.argCount; i++) {
      printExpr(lox, expr->as.call.arguments[i], NO_VALUE, 0, false, "");
      if (i < expr->as.call.argCount - 1) {
        printf(",");
      }
    }
    printf(")");
    break;
  }
  case EXPR_GET: {
    printExpr(lox, expr->as.getExpr.object, NO_VALUE, 0, false, "");
    printf(".%s", expr->as.getExpr.name.lexeme);

    break;
  }
  case EXPR_SET: {
    printf("[EXPR_SET] ");
    printExpr(lox, expr->as.setExpr.object, NO_VALUE, 0, false, "");
    printf(".%s = ", expr->as.setExpr.name.lexeme);
    printExpr(lox, expr->as.setExpr.value, NO_VALUE, 0, false, "");
    break;
  }
  case EXPR_THIS: {
    printf("%s", expr->as.thisExpr.keyword.lexeme);
    break;
  }
  case EXPR_SUPER: {
    printf("[EXPR_SUPER]");
    printToken(lox, &expr->as.superExpr.keyword, "");
    printToken(lox, &expr->as.superExpr.method, " ");
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

  if (!stmt) {
    printf("[NULL_STMT]\n");
    return;
  }
  if (stmt->type != STMT_BLOCK) {
    indentPrint(indent);
    printf("@%d: ", stmt->line);
  }

  switch (stmt->type) {
  case STMT_PRINT: {
    printExpr(lox, stmt->as.expr_print, result, 0, true, "print ");
    break;
  }
  case STMT_EXPR: {
    printExpr(lox, stmt->as.expr, result, 0, true, "[STMT_EXPR] ");
    break;
  }
  case STMT_VAR: {
    printf("VAR %s = ", stmt->as.var.name.lexeme);
    printExpr(lox, stmt->as.var.initializer, result, 0, true, "");
    break;
  }
  case STMT_BLOCK: {
    for (i32 i = 0; i < stmt->as.block.count; i++) {
      printStmt(lox, stmt->as.block.statements[i], result, indent + 1);
    }
    break;
  }

  case STMT_IF: {
    printf("IF\n");

    printExpr(lox, stmt->as.ifStmt.condition, result, indent + 1, true,
              "condition ");

    indentPrint(indent + 1);
    printf("then:\n");
    printStmt(lox, stmt->as.ifStmt.then_branch, result, indent + 1);

    if (stmt->as.ifStmt.else_branch) {
      indentPrint(indent + 1);
      printf("else:\n");
      printStmt(lox, stmt->as.ifStmt.else_branch, result, indent + 1);
    }
    break;
  }

  case STMT_WHILE: {
    printf("WHILE\n");

    printExpr(lox, stmt->as.whileStmt.condition, result, indent + 1, true,
              "condition ");

    indentPrint(indent + 1);
    printf("body:\n");
    printStmt(lox, stmt->as.whileStmt.body, result, indent + 1);
    break;
  }
  case STMT_FOR: {
    printf("FOR\n");

    if (stmt->as.forStmt.condition) {
      printExpr(lox, stmt->as.forStmt.condition, result, indent + 1, true,
                "condition ");
    } else {
      indentPrint(indent + 1);
      printf("condition : none\n");
    }

    if (stmt->as.forStmt.increment) {
      printExpr(lox, stmt->as.forStmt.increment, result, indent + 1, true,
                "increment ");
    } else {
      indentPrint(indent + 1);
      printf("increment : none\n");
    }

    indentPrint(indent + 1);
    printf("body:\n");
    printStmt(lox, stmt->as.forStmt.body, result, indent + 1);
    break;
  }

  case STMT_FUNCTION: {
    printf("FN %s (", stmt->as.functionStmt.name.lexeme);

    for (u8 i = 0; i < stmt->as.functionStmt.paramCount; i++) {
      Token t = stmt->as.functionStmt.params[i];
      printf("%s", t.lexeme);
      if (i < stmt->as.functionStmt.paramCount - 1) {
        printf(",");
      }
    }
    printf(")\n");

    printStmt(lox, stmt->as.functionStmt.body, result, indent + 1);

    break;
  }

  case STMT_CLASS: {
    printf("Class %s \n", stmt->as.classStmt.name.lexeme);

    for (u8 i = 0; i < stmt->as.classStmt.methodCount; i++) {
      Stmt *t = stmt->as.classStmt.methods[i];
      printStmt(lox, t, NO_VALUE, indent + 1);
    }

    break;
  }

  case STMT_BREAK:
    printf("BREAK\n");
    break;
  case STMT_CONTINUE:
    printf("CONTINUE\n");
    break;
  case STMT_RETURN:
    printf("RETURN ");
    printValue(result);
    printf("\n");
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
