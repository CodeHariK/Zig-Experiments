#include "lox.h"
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

const Value NO_VALUE = {VAL_NIL, {.boolean = true}};
const Value NIL_VALUE = {VAL_NIL, {.boolean = false}};
static inline Value errorValue(char *error) {
  return (Value){VAL_ERROR, {.string = error}};
}
static inline Value numberValue(double n) {
  return (Value){VAL_NUMBER, {.number = n}};
}
static inline Value boolValue(bool b) {
  return (Value){VAL_BOOL, {.boolean = b}};
}
static inline Value stringValue(char *s) {
  return (Value){VAL_STRING, {.string = s}};
}
static inline Value literalValue(Expr *expr) { return expr->as.literal.value; }

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
  }
}

static void checkNumberOperands(Lox *lox, Token op, Value left, Value right) {
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

static bool isEqual(Value a, Value b) {
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
    return strcmp(a.as.function->name.lexeme, b.as.function->name.lexeme) == 0;

  case VAL_NATIVE:
    return a.as.native == b.as.native;
  }

  return false;
}

void initParser(Lox *lox) {
  lox->parser = (Parser){
      .tokens = lox->scanner.tokens,
      .count = lox->scanner.count,
      .current = 0,
      .line = 1,
  };
}

inline Token peekToken(Parser *parser) {
  return parser->tokens[parser->current];
}

inline Token prevToken(Parser *parser) {
  return parser->tokens[parser->current - 1];
}

inline bool isTokenEOF(Parser *parser) {
  return peekToken(parser).type == TOKEN_EOF;
}

inline void advanceToken(Lox *lox) {
  if (!isTokenEOF(&lox->parser))
    lox->parser.current++;
}

bool checkToken(Parser *parser, TokenType type) {
  if (isTokenEOF(parser))
    return false;
  return peekToken(parser).type == type;
}

inline bool matchAnyTokenAdvance(Lox *lox, u32 count, ...) {
  va_list args;
  va_start(args, count);

  for (u32 i = 0; i < count; i++) {
    TokenType type = va_arg(args, TokenType);
    if (checkToken(&lox->parser, type)) {

      Token t = peekToken(&lox->parser);
      printToken(lox, &t, 1, "[MatchAdv] ");

      advanceToken(lox);
      va_end(args);
      return true;
    }
  }

  va_end(args);
  return false;
}

Token consumeToken(Lox *lox, TokenType type, const char *message) {
  Parser *parser = &lox->parser;
  Token tok = peekToken(parser);
  if (checkToken(parser, type)) {
    printToken(lox, &tok, 1, "[CONSUME]");

    advanceToken(lox);
  } else {
    parseError(lox, message);
  }

  return tok; // error recovery will improve later
}

static Expr *parseBinaryExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_BINARY;
  expr->as.binary.left = left;
  expr->as.binary.op = op;
  expr->as.binary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_BINARY] ");
  return expr;
}

static Expr *parseUnaryExpr(Lox *lox, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_UNARY;
  expr->as.unary.op = op;
  expr->as.unary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_UNARY] ");
  return expr;
}

static Expr *parseLiteralExpr(Lox *lox, Value value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LITERAL;
  expr->as.literal.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_LITERAL] ");
  return expr;
}

static Expr *parseGroupingExpr(Lox *lox, Expr *expression) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_GROUPING;
  expr->as.grouping.expression = expression;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_GROUP] ");
  return expr;
}

static Expr *parseVariableExpr(Lox *lox, Token token) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_VARIABLE;
  expr->as.var.name = token;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_VAR] ");
  return expr;
}

static Expr *parseAssignExpr(Lox *lox, Token name, Expr *value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_ASSIGN;
  expr->as.assign.name = name;
  expr->as.assign.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_ASSIGN] ");
  return expr;
}

static Expr *parseLogicalExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LOGICAL;
  expr->as.logical.left = left;
  expr->as.logical.op = op;
  expr->as.logical.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, true, "[EXPR_LOGICAL] ");
  return expr;
}

// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
static Expr *parsePrimary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_FALSE)) {
    return parseLiteralExpr(lox, boolValue(false));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_TRUE)) {
    return parseLiteralExpr(lox, boolValue(true));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_NIL)) {
    return parseLiteralExpr(lox, NIL_VALUE);
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_NUMBER)) {
    return parseLiteralExpr(lox,
                            numberValue(*(double *)prevToken(parser).literal));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_STRING)) {
    return parseLiteralExpr(lox,
                            stringValue((char *)prevToken(parser).literal));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {
    Expr *expr = parseExpression(lox);
    consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
    return parseGroupingExpr(lox, expr);
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_IDENTIFIER)) {
    return parseVariableExpr(lox, prevToken(parser));
  }

  parseError(lox, "Expect expression.");
  return NULL;
}

static Expr *parseFunctionCall(Lox *lox) {
  Expr *callee = parsePrimary(lox);

  while (true) {
    if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {
      Expr **args = NULL;
      int argCount = 0;
      int capacity = 0;

      if (!checkToken(&lox->parser, TOKEN_RIGHT_PAREN)) {
        do {
          if (argCount >= 255) {
            parseError(lox, "Can't have more than 255 arguments.");
          }

          if (argCount + 1 > capacity) {
            capacity = capacity < 8 ? 8 : capacity * 2;
            Expr **newArgs =
                arenaAlloc(&lox->astArena, sizeof(Expr *) * capacity);
            if (args)
              memcpy(newArgs, args, sizeof(Expr *) * argCount);
            args = newArgs;
          }

          args[argCount++] = parseExpression(lox);
        } while (matchAnyTokenAdvance(lox, 1, TOKEN_COMMA));
      }

      Token paren =
          consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");

      Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
      expr->type = EXPR_CALL;
      expr->as.call.callee = callee;
      expr->as.call.arguments = args;
      expr->as.call.argCount = argCount;
      expr->line = paren.line;

      callee = expr;

      printExpr(lox, callee, NO_VALUE, 0, true, true, "[EXPR_CALL] ");
    } else {
      break;
    }
  }

  return callee;
}

// unary          → ( "!" | "-" ) unary
//                | primary ;
static Expr *parseUnary(Lox *lox) {
  if (matchAnyTokenAdvance(lox, 2, TOKEN_NOT, TOKEN_MINUS)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseUnary(lox);
    return parseUnaryExpr(lox, op, right);
  }

  return parseFunctionCall(lox);
}

// factor         → unary ( ( "/" | "*" ) unary )* ;
static Expr *parseFactor(Lox *lox) {
  Expr *expr = parseUnary(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_STAR, TOKEN_SLASH)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseUnary(lox);
    expr = parseBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

// term           → factor ( ( "-" | "+" ) factor )* ;
static Expr *parseTerm(Lox *lox) {
  Expr *expr = parseFactor(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_PLUS, TOKEN_MINUS)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseFactor(lox);
    expr = parseBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
static Expr *parseComparison(Lox *lox) {
  Expr *expr = parseTerm(lox);

  while (matchAnyTokenAdvance(lox, 4, TOKEN_GREATER, TOKEN_GREATER_EQUAL,
                              TOKEN_LESS, TOKEN_LESS_EQUAL)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseTerm(lox);
    expr = parseBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
static Expr *parseEquality(Lox *lox) {
  Expr *expr = parseComparison(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_EQUAL_EQUAL, TOKEN_NOT_EQUAL)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseComparison(lox);
    expr = parseBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

static Expr *parseLogicAnd(Lox *lox) {
  Expr *expr = parseEquality(lox);

  while (matchAnyTokenAdvance(lox, 1, TOKEN_AND)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseEquality(lox);
    expr = parseLogicalExpr(lox, expr, op, right);
  }

  return expr;
}

static Expr *parseLogicOr(Lox *lox) {
  Expr *expr = parseLogicAnd(lox);

  while (matchAnyTokenAdvance(lox, 1, TOKEN_OR)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseLogicAnd(lox);
    expr = parseLogicalExpr(lox, expr, op, right);
  }

  return expr;
}

// assignment     → IDENTIFIER "=" assignment
//                | equality ;
static Expr *parseAssignment(Lox *lox) {
  Expr *expr = parseLogicOr(lox);
  if (!expr)
    return NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_EQUAL)) {
    Expr *value = parseAssignment(lox);
    if (!value)
      return NULL;

    if (expr->type == EXPR_VARIABLE) {
      Token name = expr->as.var.name;
      return parseAssignExpr(lox, name, value);
    }

    parseError(lox, "Invalid assignment target.");
  }

  return expr;
}

Expr *parseExpression(Lox *lox) { return parseAssignment(lox); }

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

static Value evaluateFunctionCall(Lox *lox, Expr *expr) {

  Value callee = evaluate(lox, expr->as.call.callee);

  if (callee.type != VAL_FUNCTION && callee.type != VAL_NATIVE) {
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
    envDefine(lox->env, fn->params[i].lexeme, args[i]);
  }

  // Execute body
  executeStmt(lox, fn->body);

  Value result = NIL_VALUE;

  if (lox->returnSignal) {
    result = lox->returnSignal->value;
  }

  // Restore environment
  lox->env = previous;

  lox->returnSignal = NULL;

  return result;
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
      runtimeError(lox, expr->as.var.name, "Undefined variable.");
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

  case EXPR_CALL: {
    return evaluateFunctionCall(lox, expr);
  }
  }

  lox->indent--;
  return result;
}
