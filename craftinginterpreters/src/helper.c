#include "lox.h"
#include <string.h>

const Value NO_VALUE = {VAL_NIL, {.boolean = true}};
const Value NIL_VALUE = {VAL_NIL, {.boolean = false}};
inline Value errorValue(char *error) {
  return (Value){VAL_ERROR, {.string = error}};
}
inline Value numberValue(double n) {
  return (Value){VAL_NUMBER, {.number = n}};
}
inline Value boolValue(bool b) { return (Value){VAL_BOOL, {.boolean = b}}; }
inline Value stringValue(char *s) { return (Value){VAL_STRING, {.string = s}}; }
inline Value literalValue(Expr *expr) { return expr->as.literal.value; }

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

  case VAL_FUNCTION:
    snprintf(buffer, size, "<fn %s>", value.as.function->name.lexeme);
    break;
  case VAL_NATIVE:
    snprintf(buffer, size, "<native fn>");
    break;

  case VAL_CLASS:
    snprintf(buffer, size, "<class %s>", value.as.klass->name.lexeme);
    break;
  case VAL_INSTANCE:
    snprintf(buffer, size, "<instance %s>",
             value.as.instance->class->name.lexeme);
    break;
  case VAL_METHOD:
    snprintf(buffer, size, "<method %s>", value.as.function->name.lexeme);
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

  case VAL_FUNCTION:
    return a.as.function = b.as.function;

  case VAL_NATIVE:
    return a.as.native == b.as.native;

  case VAL_CLASS:
    return a.as.klass == b.as.klass;
  case VAL_INSTANCE:
    return a.as.instance == b.as.instance;
  case VAL_METHOD:
    return a.as.function == b.as.function;
  }

  return false;
}

Value makeFunction(Lox *lox, Stmt *func, bool isClass) {

  LoxFunction *fn = arenaAlloc(&lox->astArena, sizeof(LoxFunction));
  fn->name = func->as.functionStmt.name;
  fn->params = func->as.functionStmt.params;
  fn->paramCount = func->as.functionStmt.paramCount;
  fn->body = func->as.functionStmt.body;
  fn->closure = lox->env;
  if (isClass) {
    fn->isInitializer = strcmp(fn->name.lexeme, "init") == 0;
  } else {
    fn->isInitializer = false;
  }

  return (Value){.type = VAL_FUNCTION, .as.function = fn};
}

Value bindMethod(Lox *lox, Value method, LoxInstance *instance) {
  LoxFunction *fn = method.as.function;

  Environment *env = envNew(fn->closure);

  envDefine(env, lox, "this",
            (Value){
                .type = VAL_INSTANCE,
                .as.instance = instance,
            });

  LoxFunction *bound = arenaAlloc(&lox->astArena, sizeof(LoxFunction));
  *bound = *fn;
  bound->closure = env;

  return (Value){.type = VAL_FUNCTION, .as.function = bound};
}
