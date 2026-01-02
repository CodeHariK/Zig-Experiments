#include "lox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Value numberValue(double n) { return (Value){VAL_NUMBER, {.number = n}}; }

Value boolValue(bool b) { return (Value){VAL_BOOL, {.boolean = b}}; }

Value nilValue(void) { return (Value){VAL_NIL, {.boolean = false}}; }

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

Expr *newUnaryExpr(Token operator, Expr * right) {
  Expr *expr = malloc(sizeof(Expr));
  if (!expr)
    return NULL;

  expr->type = EXPR_UNARY;
  expr->as.unary.op = operator;
  expr->as.unary.right = right;

  return expr;
}

Expr *newLiteralExpr(Value value) {
  Expr *expr = malloc(sizeof(Expr));
  expr->type = EXPR_LITERAL;
  expr->as.literal.value = value;
  return expr;
}

Expr *newGroupingExpr(Expr *expression) {
  Expr *expr = malloc(sizeof(Expr));
  if (!expr)
    return NULL;

  expr->type = EXPR_GROUPING;
  expr->as.grouping.expression = expression;

  return expr;
}

void runtimeError(Lox *lox, Token op, const char *message) {
  fprintf(stderr, "[line %d] RuntimeError at '%.*s': %s\n", op.line,
          (int)(op.length), op.lexeme, message);
  lox->hadRuntimeError = true;
  exit(70);
}

Value literalValue(Expr *expr) { return expr->as.literal.value; }

void checkNumberOperands(Lox *lox, Token op, Value left, Value right) {
  if (left.type == VAL_NUMBER && right.type == VAL_NUMBER)
    return;

  runtimeError(lox, op, "Operands must be numbers.");
}

bool isTruthy(Value v) {
  if (v.type == VAL_NIL)
    return false;
  if (v.type == VAL_BOOL)
    return v.as.boolean;
  return true;
}

bool isEqual(Value a, Value b) {
  if (a.type != b.type)
    return false;

  switch (a.type) {
  case VAL_NIL:
    return true;

  case VAL_BOOL:
    return a.as.boolean == b.as.boolean;

  case VAL_NUMBER:
    return a.as.number == b.as.number;

  case VAL_STRING:
    return strcmp(a.as.string, b.as.string) == 0;
  }

  return false;
}

Value evaluate(Lox *lox, Expr *expr);

Value evalUnary(Lox *lox, Expr *expr) {
  Value right = evaluate(lox, expr->as.unary.right);

  switch (expr->as.unary.op.type) {
  case TOKEN_MINUS:
    if (right.type != VAL_NUMBER) {
      runtimeError(lox, expr->as.unary.op, "Operand must be a number.");
    }
    return numberValue(-right.as.number);

  case TOKEN_NOT:
    if (right.type != VAL_BOOL) {
      runtimeError(lox, expr->as.unary.op, "Operand must be a boolean.");
    }
    return boolValue(!isTruthy(right));

  default:
    runtimeError(lox, expr->as.unary.op, "Invalid unary operator.");
    exit(1);
  }
}

Value evalBinary(Lox *lox, Expr *expr) {
  Value left = evaluate(lox, expr->as.binary.left);
  Value right = evaluate(lox, expr->as.binary.right);

  switch (expr->as.binary.op.type) {
  // Comparisons
  case TOKEN_GREATER:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return boolValue(left.as.number > right.as.number);

  case TOKEN_GREATER_EQUAL:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return boolValue(left.as.number >= right.as.number);

  case TOKEN_LESS:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return boolValue(left.as.number < right.as.number);

  case TOKEN_LESS_EQUAL:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return boolValue(left.as.number <= right.as.number);

  // Arithmetic
  case TOKEN_MINUS:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return numberValue(left.as.number - right.as.number);

  case TOKEN_SLASH:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return numberValue(left.as.number / right.as.number);

  case TOKEN_STAR:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return numberValue(left.as.number * right.as.number);

  case TOKEN_PLUS:
    checkNumberOperands(lox, expr->as.binary.op, left, right);
    return numberValue(left.as.number + right.as.number);

  // Equality (next section)
  case TOKEN_EQUAL_EQUAL:
    return boolValue(isEqual(left, right));

  case TOKEN_NOT_EQUAL:
    return boolValue(!isEqual(left, right));

  default:
    runtimeError(lox, expr->as.binary.op, "Invalid binary operator.");
    exit(1);
  }
}

Value evaluate(Lox *lox, Expr *expr) {
  switch (expr->type) {
  case EXPR_LITERAL:
    return literalValue(expr);

  case EXPR_GROUPING:
    return evaluate(lox, expr->as.grouping.expression);

  case EXPR_UNARY:
    return evalUnary(lox, expr);

  case EXPR_BINARY:
    return evalBinary(lox, expr);
  }

  return nilValue(); // unreachable
}
