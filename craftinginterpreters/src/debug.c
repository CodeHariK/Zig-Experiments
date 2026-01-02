#include "lox.h"
#include <stdio.h>

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
