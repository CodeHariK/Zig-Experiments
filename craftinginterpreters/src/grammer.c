#include "lox.h"
#include <stdlib.h>

Expr *newBinaryExpr(Expr *left, Token operator, Expr * right) {
  Expr *expr = malloc(sizeof(Expr));
  if (!expr)
    return NULL;

  expr->type = EXPR_BINARY;
  expr->as.binary.left = left;
  expr->as.binary.op = operator;
  expr->as.binary.right = right;

  return expr;
}