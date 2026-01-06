#include "lox.h"
#include <stdlib.h>
#include <string.h>

Expr *newBinaryExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_BINARY;
  expr->as.binary.left = left;
  expr->as.binary.op = op;
  expr->as.binary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_BINARY] ");
  return expr;
}

Expr *newUnaryExpr(Lox *lox, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_UNARY;
  expr->as.unary.op = op;
  expr->as.unary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_UNARY] ");
  return expr;
}

Expr *newLiteralExpr(Lox *lox, Value value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LITERAL;
  expr->as.literal.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_LITERAL] ");
  return expr;
}

Expr *newGroupingExpr(Lox *lox, Expr *expression) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_GROUPING;
  expr->as.grouping.expression = expression;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_GROUP] ");
  return expr;
}

Expr *newVariableExpr(Lox *lox, Token token) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_VARIABLE;
  expr->as.var.name = token;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_VAR] ");
  return expr;
}

Expr *newAssignExpr(Lox *lox, Token name, Expr *value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_ASSIGN;
  expr->as.assign.name = name;
  expr->as.assign.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_ASSIGN] ");
  return expr;
}

Expr *newLogicalExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LOGICAL;
  expr->as.logical.left = left;
  expr->as.logical.op = op;
  expr->as.logical.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_LOGICAL] ");
  return expr;
}

void valueToString(Value value, char *buffer, u32 size) {
  switch (value.type) {
  case VAL_NIL:
    if (value.as.boolean == true) {
      snprintf(buffer, size, "");
    } else {
      snprintf(buffer, size, "nil");
    }
    break;
  case VAL_ERROR:
    snprintf(buffer, size, "Error: %s\n", value.as.string);
    break;

  case VAL_BOOL:
    snprintf(buffer, size, value.as.boolean ? "true" : "false");
    break;

  case VAL_NUMBER:
    if (value.as.number == (long)value.as.number)
      snprintf(buffer, size, "%ld", (long)value.as.number);
    else
      snprintf(buffer, size, "%g", value.as.number);
    break;

  case VAL_STRING:
    snprintf(buffer, size, "%s", value.as.string);
    break;
  }
}

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
  case VAL_ERROR:
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

inline Value errorValue(char *error) {
  return (Value){VAL_ERROR, {.string = error}};
}
const Value NO_VALUE = {VAL_NIL, {.boolean = true}};
// inline Value nilValue() { return (Value){VAL_NIL, {.boolean = false}}; }
const Value NIL_VALUE = {VAL_NIL, {.boolean = false}};

inline Value numberValue(double n) {
  return (Value){VAL_NUMBER, {.number = n}};
}
inline Value boolValue(bool b) { return (Value){VAL_BOOL, {.boolean = b}}; }
inline Value stringValue(char *s) { return (Value){VAL_STRING, {.string = s}}; }
static inline Value literalValue(Expr *expr) { return expr->as.literal.value; }

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
      return errorValue("Operand must be a boolean.");
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
  Value result = errorValue("No evaluation");

  if (!expr || lox->hadRuntimeError || lox->hadError)
    return result;

  lox->indent++;

  switch (expr->type) {
  case EXPR_LITERAL:
    result = literalValue(expr);
    break;

  case EXPR_GROUPING:
    result = evaluate(lox, expr->as.grouping.expression);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_GROUP] ");
    break;

  case EXPR_UNARY:
    result = evalUnary(lox, expr);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_UNARY] ");
    break;

  case EXPR_BINARY:
    result = evalBinary(lox, expr);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_BINARY] ");
    break;

  case EXPR_VARIABLE: {
    if (!envGet(lox->env, expr->as.var.name.lexeme, &result)) {
      loxError(lox, expr->as.var.name.line, " at variable",
               "Undefined variable.");
      result = errorValue("Undefined variable.");
      break;
    }
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_VAR] ");
    break;
  }

  case EXPR_ASSIGN: {
    result = evaluate(lox, expr->as.assign.value);

    if (!envAssign(lox->env, expr->as.assign.name.lexeme, result)) {
      runtimeError(lox, expr->as.assign.name, "Undefined variable.");
      result = errorValue("Undefined variable.");
      break;
    }

    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_ASSIGN] ");
    break;
  }

  case EXPR_LOGICAL: {
    Value left = evaluate(lox, expr->as.logical.left);

    if (expr->as.logical.op.type == TOKEN_OR) {
      if (isTruthy(left))
        return left;
    } else {
      if (!isTruthy(left))
        return left;
    }

    result = evaluate(lox, expr->as.logical.right);

    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_LOGICAL] ");
    break;
  }
  }

  lox->indent--;
  return result;
}
