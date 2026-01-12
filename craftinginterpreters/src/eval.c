#include "lox.h"

static Value evalUnary(Lox *lox, Expr *expr) {
  auto unary = expr->as.unary;
  Value right = evaluate(lox, unary.right);

  switch (unary.op.type) {
  case TOKEN_MINUS:
    if (right.type != VAL_NUMBER) {
      return errorValue(lox, &unary.op, expr, "Operand must be a number", true);
    }
    return numberValue(-right.as.number);

  case TOKEN_NOT:
    if (right.type != VAL_BOOL) {
      return errorValue(lox, &unary.op, NULL, "Operand must be a boolean",
                        true);
    }
    return boolValue(!isTruthy(right));

  default:
    return errorValue(lox, &unary.op, expr, "Invalid unary operator", true);
  }
}

static Value evalBinary(Lox *lox, Expr *expr) {
  auto binary = expr->as.binary;
  Value left = evaluate(lox, binary.left);
  Value right = evaluate(lox, binary.right);

  switch (binary.op.type) {
  // Comparisons
  case TOKEN_GREATER:
    checkNumberOperands(lox, &binary.op, left, right);
    return boolValue(left.as.number > right.as.number);

  case TOKEN_GREATER_EQUAL:
    checkNumberOperands(lox, &binary.op, left, right);
    return boolValue(left.as.number >= right.as.number);

  case TOKEN_LESS:
    checkNumberOperands(lox, &binary.op, left, right);
    return boolValue(left.as.number < right.as.number);

  case TOKEN_LESS_EQUAL:
    checkNumberOperands(lox, &binary.op, left, right);
    return boolValue(left.as.number <= right.as.number);

  // Arithmetic
  case TOKEN_MINUS:
    checkNumberOperands(lox, &binary.op, left, right);
    return numberValue(left.as.number - right.as.number);

  case TOKEN_SLASH:
    checkNumberOperands(lox, &binary.op, left, right);
    return numberValue(left.as.number / right.as.number);

  case TOKEN_STAR:
    checkNumberOperands(lox, &binary.op, left, right);
    return numberValue(left.as.number * right.as.number);

  case TOKEN_PLUS:
    checkNumberOperands(lox, &binary.op, left, right);
    return numberValue(left.as.number + right.as.number);

  // Equality (next section)
  case TOKEN_EQUAL_EQUAL:
    return boolValue(isEqual(left, right));

  case TOKEN_NOT_EQUAL:
    return boolValue(!isEqual(left, right));

  default:
    return errorValue(lox, &binary.op, expr, "Invalid binary operator", true);
  }
}

static Value evalCall(Lox *lox, Expr *expr) {
  printExpr(lox, expr, NO_VALUE, lox->indent, true, "");

  Value callee = evaluate(lox, expr->as.call.callee);

  if (callee.type != VAL_FUNCTION && callee.type != VAL_NATIVE &&
      callee.type != VAL_CLASS) {
    return errorValue(lox, NULL, expr, "Can only call functions and classes",
                      true);
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
    if (envGet(lox, klass->methodsEnv, "init", &init)) {
      Value bound = bindMethod(lox, init, instance);

      Expr fakeCall = *expr;
      fakeCall.as.call.callee = arenaAlloc(&lox->astArena, sizeof(Expr));
      fakeCall.as.call.callee->type = EXPR_LITERAL;
      fakeCall.as.call.callee->as.literal.value = bound;

      Value initResult = evalCall(lox, &fakeCall);

      // if init failed, abort instance creation
      if (initResult.type == VAL_ERROR || lox->hadRuntimeError) {
        return initResult; // or errorValue(...)
      }

      // initializer return value is ignored by design
      lox->signal.type = SIGNAL_NONE;
    }

    Value result;
    result.type = VAL_INSTANCE;
    result.as.instance = instance;
    return result;
  }

  LoxFunction *fn = callee.as.function;

  if (expr->as.call.argCount != fn->paramCount) {
    char msg[100];
    snprintf(msg, sizeof(msg), "Expected %d arguments but got %d",
             fn->paramCount, expr->as.call.argCount);
    return errorValue(lox, NULL, expr, msg, true);
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

  LoxFunction *prev = lox->currentFunction;
  lox->currentFunction = fn;
  // Execute body
  executeStmt(lox, fn->body);
  lox->currentFunction = prev;

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
  Value result = errorValue(lox, NULL, NULL, "No evaluation", false);

  if (!expr || lox->hadRuntimeError || lox->hadError) {
    return result;
  }

  lox->indent++;

  if (expr->type != EXPR_CALL && expr->type != EXPR_VARIABLE) {
    printExpr(lox, expr, NO_VALUE, lox->indent, true, ":> ");
  }

  switch (expr->type) {
  case EXPR_LITERAL: {
    result = literalValue(expr);
    break;
  }
  case EXPR_GROUPING: {
    result = evaluate(lox, expr->as.grouping.expression);
    break;
  }
  case EXPR_UNARY: {
    result = evalUnary(lox, expr);
    break;
  }

  case EXPR_BINARY: {
    result = evalBinary(lox, expr);
    break;
  }

  case EXPR_LOGICAL: {
    Value left = evaluate(lox, expr->as.logical.left);

    if (expr->as.logical.op.type == TOKEN_OR) {
      if (isTruthy(left)) {
        result = left;
        break;
      }
    } else {
      if (!isTruthy(left)) {
        result = left;
        break;
      }
    }

    result = evaluate(lox, expr->as.logical.right);
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
    result = evalCall(lox, expr);
    break;
  }

  case EXPR_GET: {
    result = evalGet(lox, expr);
    break;
  }
  case EXPR_SET: {
    result = evalSet(lox, expr);
    break;
  }
  case EXPR_THIS: {
    result = envGetAt(lox->env, expr->as.thisExpr.depth, "this");
    break;
  }

  case EXPR_SUPER: {
    result = evalSuper(lox, expr);
    break;
  }
  }

  lox->indent--;
  return result;
}
