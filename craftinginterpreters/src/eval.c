#include "lox.h"
#include <stdlib.h>

static Value evalUnary(Lox *lox, Expr *expr) {
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

static Value evalBinary(Lox *lox, Expr *expr) {
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

static Value evalCall(Lox *lox, Expr *expr) {

  Value callee = evaluate(lox, expr->as.call.callee);

  if (callee.type != VAL_FUNCTION && callee.type != VAL_NATIVE &&
      callee.type != VAL_CLASS) {
    runtimeErrorAt(lox, expr->line, "Can only call functions and classes.");
    return NIL_VALUE;
  }

  if (callee.type == VAL_NATIVE) {
    NativeFn native = callee.as.native;
    // simple native call, assuming no arg check for now or handle it inside
    // For clock(), argCount is 0.
    // But general native fns might want to check args.
    // Let's pass checking responsibility to the native function?
    // Or just pass args.

    // 1. Evaluate arguments
    Value args[255];
    for (u8 i = 0; i < expr->as.call.argCount; i++) {
      args[i] = evaluate(lox, expr->as.call.arguments[i]);
    }

    return native(expr->as.call.argCount, args);
  }

  if (callee.type == VAL_CLASS) {
    LoxClass *klass = callee.as.klass;

    LoxInstance *instance = arenaAlloc(&lox->astArena, sizeof(LoxInstance));

    instance->class = klass;
    instance->fields = envNew(NULL);

    // Call init if exists
    Value init;
    if (envGet(klass->methods, "init", &init)) {
      // callBoundMethod(lox, init, instance, expr);
      Value bound = bindMethod(lox, init, instance);

      Expr fakeCall = *expr;
      fakeCall.as.call.callee = arenaAlloc(&lox->astArena, sizeof(Expr));
      fakeCall.as.call.callee->type = EXPR_LITERAL;
      fakeCall.as.call.callee->as.literal.value = bound;

      evalCall(lox, &fakeCall);
    }

    Value result;
    result.type = VAL_INSTANCE;
    result.as.instance = instance;
    return result;
  }

  LoxFunction *fn = callee.as.function;

  if (expr->as.call.argCount != fn->paramCount) {
    char msg[100];
    snprintf(msg, sizeof(msg), "Expected %d arguments but got %d.",
             fn->paramCount, expr->as.call.argCount);
    runtimeErrorAt(lox, expr->line, msg);
    return NIL_VALUE;
  }

  // 1. Evaluate arguments in CURRENT environment
  Value args[255];
  for (u8 i = 0; i < fn->paramCount; i++) {
    args[i] = evaluate(lox, expr->as.call.arguments[i]);
  }

  // Create call environment
  Environment *previous = lox->env;
  lox->env = envNew(fn->closure);

  // Bind parameters
  for (u8 i = 0; i < fn->paramCount; i++) {
    envDefine(lox->env, lox, fn->params[i].lexeme, args[i]);
  }

  // Execute body
  executeStmt(lox, fn->body);

  Value result = NIL_VALUE;

  if (lox->signal.type == SIGNAL_RETURN) {
    result = lox->signal.returnValue;
  }

  // Restore environment
  lox->env = previous;

  lox->signal.type = SIGNAL_NONE;

  return result;
}

Value evaluate(Lox *lox, Expr *expr) {
  Value result = errorValue("No evaluation");

  if (!expr || lox->hadRuntimeError || lox->hadError)
    return result;

  lox->indent++;

  switch (expr->type) {
  case EXPR_LITERAL: {
    result = literalValue(expr);
    break;
  }
  case EXPR_GROUPING: {
    result = evaluate(lox, expr->as.grouping.expression);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_GROUP] ");
    break;
  }
  case EXPR_UNARY: {
    result = evalUnary(lox, expr);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_UNARY] ");
    break;
  }

  case EXPR_BINARY: {
    result = evalBinary(lox, expr);
    printExpr(lox, expr, result, lox->indent, false, true, "[EVAL_BINARY] ");
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

  case EXPR_VARIABLE: {
    result = evalVariable(lox, expr);
    break;
  }

  case EXPR_ASSIGN: {
    result = evalAssign(lox, expr);
    break;
  }

  case EXPR_CALL: {
    return evalCall(lox, expr);
  }

  case EXPR_GET: {
    return evalGet(lox, expr);
  }
  case EXPR_SET: {
    return evalSet(lox, expr);
  }
  case EXPR_THIS: {
    return envGetAt(lox->env, expr->as.thisExpr.depth, "this");
  }
  }

  lox->indent--;
  return result;
}
