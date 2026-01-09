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

static Expr *parseBinaryExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_BINARY;
  expr->as.binary.left = left;
  expr->as.binary.op = op;
  expr->as.binary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_BINARY] ");
  return expr;
}

static Expr *parseUnaryExpr(Lox *lox, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_UNARY;
  expr->as.unary.op = op;
  expr->as.unary.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_UNARY] ");
  return expr;
}

static Expr *parseLiteralExpr(Lox *lox, Value value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LITERAL;
  expr->as.literal.value = value;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_LITERAL] ");
  return expr;
}

static Expr *parseGroupingExpr(Lox *lox, Expr *expression) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_GROUPING;
  expr->as.grouping.expression = expression;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_GROUP] ");
  return expr;
}

Expr *parseVariableExpr(Lox *lox, Token token) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_VARIABLE;
  expr->as.var.name = token;
  expr->as.var.depth = -1;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_VAR] ");
  return expr;
}

static Expr *parseAssignExpr(Lox *lox, Token name, Expr *value) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_ASSIGN;
  expr->as.assign.name = name;
  expr->as.assign.value = value;
  expr->as.var.depth = -1;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_ASSIGN] ");
  return expr;
}

static Expr *parseLogicalExpr(Lox *lox, Expr *left, Token op, Expr *right) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_LOGICAL;
  expr->as.logical.left = left;
  expr->as.logical.op = op;
  expr->as.logical.right = right;
  printExpr(lox, expr, NO_VALUE, 0, true, "[EXPR_LOGICAL] ");
  return expr;
}

static Expr *makeSuperExpr(Lox *lox, Token keyword, Token method) {
  Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
  expr->type = EXPR_SUPER;
  expr->as.superExpr.keyword = keyword;
  expr->as.superExpr.method = method;
  expr->as.superExpr.depth = -1;
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

  if (matchAnyTokenAdvance(lox, 1, TOKEN_THIS)) {
    Expr *expr = arenaAlloc(&lox->astArena, sizeof(Expr));
    expr->type = EXPR_THIS;
    expr->as.thisExpr.keyword = prevToken(&lox->parser);
    expr->as.thisExpr.depth = -1;
    return expr;
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_SUPER)) {
    Token keyword = prevToken(&lox->parser);
    consumeToken(lox, TOKEN_DOT, "Expect '.' after 'super'.");
    consumeToken(lox, TOKEN_IDENTIFIER, "Expect superclass method name.");
    return makeSuperExpr(lox, keyword, prevToken(&lox->parser));
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_IDENTIFIER)) {
    return parseVariableExpr(lox, prevToken(parser));
  }

  parseError(lox, "Expect expression.");
  return NULL;
}

static Expr *parseCall(Lox *lox) {
  Expr *callee = parsePrimary(lox);

  while (true) {
    if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {
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

      printExpr(lox, callee, NO_VALUE, 0, true, "[EXPR_CALL] ");
    }
    //
    else if (matchAnyTokenAdvance(lox, 1, TOKEN_DOT)) {
      Token name =
          consumeToken(lox, TOKEN_IDENTIFIER, "Expect property name after '.'");

      Expr *get = arenaAlloc(&lox->astArena, sizeof(Expr));
      get->type = EXPR_GET;
      get->as.getExpr.object = callee;
      get->as.getExpr.name = name;

      callee = get;
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
    return parseUnaryExpr(lox, op, right);
  }

  return parseCall(lox);
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
      return parseAssignExpr(lox, name, value); // existing variable assignment
    } else if (expr->type == EXPR_GET) {
      // Convert EXPR_GET into EXPR_SET
      Expr *setExpr = arenaAlloc(&lox->astArena, sizeof(Expr));
      setExpr->type = EXPR_SET;
      setExpr->as.setExpr.object = expr->as.getExpr.object;
      setExpr->as.setExpr.name = expr->as.getExpr.name;
      setExpr->as.setExpr.value = value;
      setExpr->line = expr->line;
      return setExpr;
    } else {
      parseError(lox, "Invalid assignment target.");
    }
  }

  return expr;
}

Expr *parseExpression(Lox *lox) { return parseAssignment(lox); }
