#include "lox.h"
#include <stdarg.h>
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

static void indentPrint(int indent) {
  for (int i = 0; i < indent; i++)
    printf("   ");
}

void printValue(Lox *lox, Value value, bool newLine, int count, ...) {
  if (!lox->debugPrint)
    return;

  char valueBuf[64];
  valueToString(value, valueBuf, sizeof(valueBuf));

  va_list args;
  va_start(args, count);

  for (int i = 0; i < count; i++) {
    const char *s = va_arg(args, const char *);
    fputs(s, stdout);
  }

  va_end(args);

  fputs(valueBuf, stdout);

  if (newLine) {
    putchar('\n');
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

  printf("===== Environment =====\n(count=%d, capacity=%d):\n", env->count,
         env->capacity);
  for (int i = 0; i < env->count; i++) {
    char buffer[128];
    valueToString(env->entries[i].value, buffer, sizeof(buffer));
    printf("%s = %s\n", env->entries[i].key, buffer);
  }
  printf("=======================\n");
}

void printToken(Lox *lox, const Token *token, int count, ...) {
  if (!lox->debugPrint)
    return;

  va_list args;
  va_start(args, count);

  for (int i = 0; i < count; i++) {
    const char *s = va_arg(args, const char *);
    fputs(s, stdout);
  }

  va_end(args);

  printf("[TOK] %-15s '%.*s'\n", tokenTypeToString(token->type), token->length,
         token->lexeme);
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

// void printExprAST(Lox *lox, Expr *expr, int indent) {
//   if (!expr)
//     return;

//   indentPrint(indent);

//   switch (expr->type) {
//   case EXPR_LITERAL:
//     printf("Literal ");
//     printValue(lox, expr->as.literal.value, 1, "");
//     printf("\n");
//     break;

//   case EXPR_VARIABLE:
//     printf("Variable %.*s\n", (int)expr->as.var.name.length,
//            expr->as.var.name.lexeme);
//     break;

//   case EXPR_ASSIGN:
//     printf("Assign %.*s\n", (int)expr->as.assign.name.length,
//            expr->as.assign.name.lexeme);
//     printExprAST(lox, expr->as.assign.value, indent + 1);
//     break;

//   case EXPR_BINARY:
//     printf("Binary %.*s\n", (int)expr->as.binary.op.length,
//            expr->as.binary.op.lexeme);
//     printExprAST(lox, expr->as.binary.left, indent + 1);
//     printExprAST(lox, expr->as.binary.right, indent + 1);
//     break;

//   case EXPR_GROUPING:
//     printf("Grouping\n");
//     printExprAST(lox, expr->as.grouping.expression, indent + 1);
//     break;

//   case EXPR_UNARY:
//     printf("Unary %.*s\n", (int)expr->as.unary.op.length,
//            expr->as.unary.op.lexeme);
//     printExprAST(lox, expr->as.unary.right, indent + 1);
//     break;
//   }
// }

void printExpr(Lox *lox, Expr *expr, int indent, bool space, bool newLine,
               char *msg) {
  if (!lox->debugPrint) {
    return;
  }
  if (!expr) {
    printf("[NIL_EXPR]");
    return;
  }

  indentPrint(indent);

  printf("%s", msg);

  if (space)
    printf("%-16s", "");

  switch (expr->type) {
  case EXPR_BINARY:
    printf("(%s ", tokenTypeToString(expr->as.binary.op.type));
    printExpr(lox, expr->as.binary.left, 0, false, false, "");
    printf(" ");
    printExpr(lox, expr->as.binary.right, 0, false, false, "");
    printf(")");
    break;

  case EXPR_UNARY:
    printf("(%s ", tokenTypeToString(expr->as.unary.op.type));
    printExpr(lox, expr->as.unary.right, 0, false, false, "");
    printf(")");
    break;

  case EXPR_LITERAL:
    printValue(lox, expr->as.literal.value, false, false, 1, "LITERAL");

    break;

  case EXPR_GROUPING:
    printf("(GROUP ");
    printExpr(lox, expr->as.grouping.expression, 0, false, false, "");
    printf(")");
    break;

  case EXPR_VARIABLE:
    printf("VARIABLE %.*s", expr->as.var.name.length, expr->as.var.name.lexeme);

    break;

  case EXPR_ASSIGN:
    printf("ASSIGN (= %.*s ", (int)expr->as.assign.name.length,
           expr->as.assign.name.lexeme);
    printExpr(lox, expr->as.assign.value, 0, false, false, "");
    printf(")");
    break;
  }

  if (newLine)
    printf("\n");
}

// void printStmtAST(Lox *lox, Stmt *stmt, int indent) {
//   if (!stmt)
//     return;

//   indentPrint(indent);

//   switch (stmt->type) {
//   case STMT_PRINT:
//     printf("printStmtAST\n");
//     printExprAST(lox, stmt->as.expr_print, indent + 1);
//     break;

//   case STMT_EXPR:
//     printf("ExprStmt\n");
//     printExprAST(lox, stmt->as.expr, indent + 1);
//     break;

//   case STMT_VAR:
//     printf("VarStmt %.*s\n", (int)stmt->as.var.name.length,
//            stmt->as.var.name.lexeme);
//     if (stmt->as.var.initializer)
//       printExprAST(lox, stmt->as.var.initializer, indent + 1);
//     break;

//   case STMT_BLOCK:
//     printf("BlockStmt\n");
//     break;
//   }
// }

void printStmt(Lox *lox, Stmt *stmt) {
  if (!lox->debugPrint)
    return;

  if (!stmt) {
    printf("[NULL_STMT]\n");
    return;
  }

  switch (stmt->type) {
  case STMT_PRINT:
    printExpr(lox, stmt->as.expr_print, 0, false, true, "[STMT_PRINT] ");
    break;
  case STMT_EXPR:
    printExpr(lox, stmt->as.expr, 0, false, true, "[STMT_EXPR] ");
    break;
  case STMT_VAR: {
    printf("[STMT_VAR] %s = ", stmt->as.var.name.lexeme);
    printExpr(lox, stmt->as.var.initializer, 0, false, true, "");
    break;
  case STMT_BLOCK:
    printf("[STMT_BLOCK]\n");
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
    printStmt(lox, prog->statements[i]);
  }

  printf("=================\n");
}

void printProgramAST(Lox *lox, Program *prog) {
  if (!prog || !lox->debugPrint)
    return;

  printf("Program (%zu statements)\n", prog->count);

  for (size_t i = 0; i < prog->count; i++) {
    printStmtAST(lox, prog->statements[i], 1);
  }
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
