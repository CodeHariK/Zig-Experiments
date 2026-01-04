#include "lox.h"
#include <stdarg.h>

void initParser(Lox *lox) {
  lox->parser.tokens = lox->scanner.tokens;
  lox->parser.count = lox->scanner.count;
  lox->parser.current = 0;
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

inline bool matchAnyTokenAdvance(Lox *lox, int count, ...) {
  va_list args;
  va_start(args, count);

  for (int i = 0; i < count; i++) {
    TokenType type = va_arg(args, TokenType);
    if (checkToken(&lox->parser, type)) {

      printf("MatchAdv %-12s %s\n", "", tokenTypeToString(type));

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
    printf("CONSUME ");
    printToken(lox, &tok);

    advanceToken(lox);
  } else {
    parserError(lox, message);
  }

  return tok; // error recovery will improve later
}

static Expr *_parseExpression(Lox *lox);

Expr *parseExpression(Lox *lox) {
  printf("================\n");
  return _parseExpression(lox);
}

// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
static Expr *parsePrimary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (matchAnyTokenAdvance(lox, 1, TOKEN_FALSE))
    return newLiteralExpr(lox, boolValue(false));

  if (matchAnyTokenAdvance(lox, 1, TOKEN_TRUE))
    return newLiteralExpr(lox, boolValue(true));

  if (matchAnyTokenAdvance(lox, 1, TOKEN_NIL))
    return newLiteralExpr(lox, nilValue());

  if (matchAnyTokenAdvance(lox, 1, TOKEN_NUMBER))
    return newLiteralExpr(lox,
                          numberValue(*(double *)prevToken(parser).literal));

  if (matchAnyTokenAdvance(lox, 1, TOKEN_STRING))
    return newLiteralExpr(lox, stringValue((char *)prevToken(parser).literal));

  if (matchAnyTokenAdvance(lox, 1, TOKEN_LEFT_PAREN)) {
    Expr *expr = _parseExpression(lox);
    consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
    return newGroupingExpr(lox, expr);
  }

  if (matchAnyTokenAdvance(lox, 1, TOKEN_IDENTIFIER)) {
    return newVariableExpr(lox, prevToken(parser));
  }

  loxError(lox, peekToken(parser).line, ": Expect expression. Got",
           peekToken(parser).lexeme);
  return NULL;
}

// unary          → ( "!" | "-" ) unary
//                | primary ;
static Expr *parseUnary(Lox *lox) {
  if (matchAnyTokenAdvance(lox, 2, TOKEN_NOT, TOKEN_MINUS)) {
    Token op = prevToken(&lox->parser);
    Expr *right = parseUnary(lox);
    return newUnaryExpr(lox, op, right);
  }

  return parsePrimary(lox);
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

// assignment     → IDENTIFIER "=" assignment
//                | equality ;
static Expr *parseAssignment(Lox *lox) {
  Expr *expr = parseEquality(lox);
  if (!expr)
    return NULL;

  if (matchAnyTokenAdvance(lox, 1, TOKEN_EQUAL)) {
    Expr *value = parseAssignment(lox);
    if (!value)
      return NULL;

    if (expr->type == EXPR_VARIABLE) {
      Token name = expr->as.var.name;
      return newAssignExpr(lox, name, value);
    }

    parserError(lox, "Invalid assignment target.");
  }

  return expr;
}

static Expr *_parseExpression(Lox *lox) {
  printf("====>\n");
  return parseAssignment(lox);
}
