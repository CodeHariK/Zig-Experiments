#include "lox.h"
#include <stdio.h>

static void printParenthesized(const char *name, Expr *left, Expr *right) {
  printf("(%s ", name);
  printExpr(left);
  printf(" ");
  printExpr(right);
  printf(")");
}

void printExpr(Expr *expr) {
  if (!expr) {
    printf("nil");
    return;
  }

  switch (expr->type) {
  case EXPR_BINARY:
    printParenthesized(expr->as.binary.op.lexeme, expr->as.binary.left,
                       expr->as.binary.right);
    break;

  case EXPR_UNARY:
    printf("(%s ", expr->as.unary.op.lexeme);
    printExpr(expr->as.unary.right);
    printf(")");
    break;

  case EXPR_LITERAL:
    printValue(expr->as.literal.value);
    break;

  case EXPR_GROUPING:
    printf("(group ");
    printExpr(expr->as.grouping.expression);
    printf(")");
    break;
  }
}

void printValue(Value value) {
  switch (value.type) {
  case VAL_STRING:
    printf("%s\n", value.as.string);
    break;
  case VAL_NIL:
    printf("nil\n");
    break;

  case VAL_BOOL:
    printf(value.as.boolean ? "true\n" : "false\n");
    break;

  case VAL_NUMBER: {
    double num = value.as.number;

    // Print integers without .0
    if (num == (long)num) {
      printf("%ld\n", (long)num);
    } else {
      printf("%g\n", num);
    }
    break;
  }
  }
}
