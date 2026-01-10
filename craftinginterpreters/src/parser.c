#include "lox.h"
#include <stdarg.h>
#include <string.h>

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
      printToken(lox, &t, "[MatchAdv]                 ");

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

    printToken(lox, &tok, "[CONSUME]                  ");

    advanceToken(lox);
  } else {
    parseError(lox, message);
  }

  return tok; // error recovery will improve later
}

// ====================== New Expr ======================

static Expr *newBinaryExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_BINARY;
  expr->as.binary.left = left;
  expr->as.binary.op = op;
  expr->as.binary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_BINARY] ");
  return expr;
}

static Expr *newUnaryExpr(Lox *lox, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_UNARY;
  expr->as.unary.op = op;
  expr->as.unary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_UNARY] ");
  return expr;
}

static Expr *newLiteralExpr(Lox *lox, Value value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LITERAL;
  expr->as.literal.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_LITERAL] ");
  return expr;
}

static Expr *newGroupingExpr(Lox *lox, Expr *expression) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_GROUPING;
  expr->as.grouping.expression = expression;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_GROUP] ");
  return expr;
}

Expr *newVariableExpr(Lox *lox, Token token) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_VARIABLE;
  expr->as.var.name = token;
  expr->as.var.depth = -1;
  return expr;
}

static Expr *newAssignExpr(Lox *lox, Token name, Expr *value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_ASSIGN;
  expr->as.assign.name = name;
  expr->as.assign.value = value;
  expr->as.var.depth = -1;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_ASSIGN] ");
  return expr;
}

static Expr *newLogicalExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LOGICAL;
  expr->as.logical.left = left;
  expr->as.logical.op = op;
  expr->as.logical.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_LOGICAL] ");
  return expr;
}

static Expr *newCallExpr(Lox *lox, Expr *callee, Expr **args, u8 argCount,
                         u32 line) {
  Expr *callExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
  callExpr->type = EXPR_CALL;
  callExpr->as.call.callee = callee;
  callExpr->as.call.arguments = args;
  callExpr->as.call.argCount = argCount;
  callExpr->line = line;
  printExpr(lox, callExpr, NO_VALUE, 0, true, "[EXPR_CALL] ");
  return callExpr;
}

static Expr *newGetExpr(Lox *lox, Expr *callee, Token methodIdentifier) {
  Expr *getExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
  getExpr->type = EXPR_GET;
  getExpr->as.getExpr.object = callee;
  getExpr->as.getExpr.name = methodIdentifier;
  printExpr(lox, getExpr, NO_VALUE, 0, true, "");
  return getExpr;
}

static Expr *newSetExpr(Lox *lox, Expr *expr, Expr *value) {
  Expr *setExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
  setExpr->type = EXPR_SET;
  setExpr->as.setExpr.object = expr->as.getExpr.object;
  setExpr->as.setExpr.name = expr->as.getExpr.name;
  setExpr->as.setExpr.value = value;
  setExpr->line = expr->line;
  printExpr(lox, setExpr, NO_VALUE, 0, true, "");
  return setExpr;
}

static Expr *newThisExpr(Lox *lox) {
  Expr *thisExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
  thisExpr->type = EXPR_THIS;
  thisExpr->as.thisExpr.keyword = prevToken(&lox->parser);
  thisExpr->as.thisExpr.depth = -1;
  // printExpr(lox, thisExpr, NO_VALUE, 0, true, "[EXPR_THIS] ");
  return thisExpr;
}

static Expr *newSuperExpr(Lox *lox, Token keyword, Token method) {
  Expr *superExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
  superExpr->type = EXPR_SUPER;
  superExpr->as.superExpr.keyword = keyword;
  superExpr->as.superExpr.method = method;
  superExpr->as.superExpr.depth = -1;
  return superExpr;
}

// ====================== Parser ======================

// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
static Expr *parsePrimary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_FALSE)) {
    return newLiteralExpr(lox, boolValue(false));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_TRUE)) {
    return newLiteralExpr(lox, boolValue(true));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_NIL)) {
    return newLiteralExpr(lox, NIL_VALUE);
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_NUMBER)) {
    return newLiteralExpr(lox,
                          numberValue(*(double *)prevToken(parser).literal));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_STRING)) {
    return newLiteralExpr(lox, stringValue((char *)prevToken(parser).literal));
  }
  if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {
    Expr *expr = parseExpression(lox);
    consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
    return newGroupingExpr(lox, expr);
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_THIS)) {
    return newThisExpr(lox);
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_SUPER)) {
    Token keyword = prevToken(&lox->parser);
    consumeToken(lox, TOKEN_DOT, "Expect '.' after 'super'.");
    consumeToken(lox, TOKEN_IDENTIFIER, "Expect superclass method name.");
    return newSuperExpr(lox, keyword, prevToken(&lox->parser));
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_IDENTIFIER)) {
    Expr *e = newVariableExpr(lox, prevToken(parser));
    printExpr(lox, e, NO_VALUE, 0, true, "[EXPR_VAR] ");
    return e;
  }

  parseError(lox, "Expect expression.");
  return NULL;
}

typedef struct {
  Expr **args;
  u8 argCount;
} CallArgs;

static CallArgs parseCallArgs(Lox *lox) {
  Expr **args = NULL;
  u32 argCount = 0;
  u32 capacity = 0;

  if (!checkToken(&lox->parser, TOKEN_RIGHT_PAREN)) {
    do {
      if (argCount >= 255) {
        parseError(lox, "Can't have more than 255 arguments.");
      }

      if (argCount + 1 > capacity) {
        capacity = capacity < 8 ? 8 : capacity * 2;
        Expr **newArgs = arenaAlloc(&lox->astArena, sizeof(Expr *) * capacity);
        if (args) {
          memcpy(newArgs, args, sizeof(Expr *) * argCount);
        }
        args = newArgs;
      }

      args[argCount++] = parseExpression(lox);
    } while (matchAnyTokenAdvance(lox, 1, TOKEN_COMMA));
  }
  return (CallArgs){
      .args = args,
      .argCount = argCount,
  };
}

static Expr *parseCall(Lox *lox) {
  Expr *callee = parsePrimary(lox);

  while (true) {
    if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {

      CallArgs callArgs = parseCallArgs(lox);

      Token paren =
          consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");

      callee = newCallExpr(lox, callee, callArgs.args, callArgs.argCount,
                           paren.line);
    }
    //
    else if (matchAnyTokenAdvance(lox, 1, TOKEN_DOT)) {
      Token methodIdentifier =
          consumeToken(lox, TOKEN_IDENTIFIER, "Expect property name after '.'");

      callee = newGetExpr(lox, callee, methodIdentifier);
    }
    //
    else {
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
    return newUnaryExpr(lox, op, right);
  }

  return parseCall(lox);
}

// factor         → unary ( ( "/" | "*" ) unary )* ;
static Expr *parseFactor(Lox *lox) {
  Expr *expr = parseUnary(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_STAR, TOKEN_SLASH)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseUnary(lox);
    expr = newBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

// term           → factor ( ( "-" | "+" ) factor )* ;
static Expr *parseTerm(Lox *lox) {
  Expr *expr = parseFactor(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_PLUS, TOKEN_MINUS)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseFactor(lox);
    expr = newBinaryExpr(lox, expr, op, right);
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
    expr = newBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
static Expr *parseEquality(Lox *lox) {
  Expr *expr = parseComparison(lox);

  while (matchAnyTokenAdvance(lox, 2, TOKEN_EQUAL_EQUAL, TOKEN_NOT_EQUAL)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseComparison(lox);
    expr = newBinaryExpr(lox, expr, op, right);
  }

  return expr;
}

static Expr *parseLogicAnd(Lox *lox) {
  Expr *expr = parseEquality(lox);

  while (matchAnyTokenAdvance(lox, 1, TOKEN_AND)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseEquality(lox);
    expr = newLogicalExpr(lox, expr, op, right);
  }

  return expr;
}

static Expr *parseLogicOr(Lox *lox) {
  Expr *expr = parseLogicAnd(lox);

  while (matchAnyTokenAdvance(lox, 1, TOKEN_OR)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseLogicAnd(lox);
    expr = newLogicalExpr(lox, expr, op, right);
  }

  return expr;
}

// assignment     → IDENTIFIER "=" assignment
//                | equality ;
static Expr *parseAssignment(Lox *lox) {
  Expr *prev = parseLogicOr(lox);
  if (!prev)
    return NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_EQUAL)) {
    Expr *value = parseAssignment(lox);
    if (!value)
      return NULL;

    if (prev->type == EXPR_VARIABLE) {
      Token name = prev->as.var.name;
      return newAssignExpr(lox, name, value); // existing variable assignment
    } else if (prev->type == EXPR_GET) {
      return newSetExpr(lox, prev, value);
    } else {
      parseError(lox, "Invalid assignment target.");
    }
  }

  return prev;
}

Expr *parseExpression(Lox *lox) { return parseAssignment(lox); }
