#include "lox.h"
#include <stdarg.h>

void initParser(Lox *lox, Token *tokens, size_t count) {
  lox->parser.tokens = tokens;
  lox->parser.count = count;
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

inline void advanceToken(Parser *parser) {
  if (!isTokenEOF(parser))
    parser->current++;
}

bool checkToken(Parser *parser, TokenType type) {
  if (isTokenEOF(parser))
    return false;
  return peekToken(parser).type == type;
}

inline bool matchAnyTokenAdvance(Parser *parser, int count, ...) {
  va_list args;
  va_start(args, count);

  for (int i = 0; i < count; i++) {
    TokenType type = va_arg(args, TokenType);
    if (checkToken(parser, type)) {
      advanceToken(parser);
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
    advanceToken(parser);
  } else {
    parserError(lox, message);
  }
  return tok; // error recovery will improve later
}

static Expr *expression(Lox *lox);

Expr *parseExpression(Lox *lox) { return expression(lox); }

// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
static Expr *primary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (matchAnyTokenAdvance(parser, 1, TOKEN_FALSE))
    return newLiteralExpr(lox, boolValue(false));

  if (matchAnyTokenAdvance(parser, 1, TOKEN_TRUE))
    return newLiteralExpr(lox, boolValue(true));

  if (matchAnyTokenAdvance(parser, 1, TOKEN_NIL))
    return newLiteralExpr(lox, nilValue());

  if (matchAnyTokenAdvance(parser, 1, TOKEN_NUMBER))
    return newLiteralExpr(lox,
                          numberValue(*(double *)prevToken(parser).literal));

  if (matchAnyTokenAdvance(parser, 1, TOKEN_STRING))
    return newLiteralExpr(lox, stringValue((char *)prevToken(parser).literal));

  if (matchAnyTokenAdvance(parser, 1, TOKEN_LEFT_PAREN)) {
    Expr *expr = expression(lox);
    consumeToken(lox, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
    return newGroupingExpr(lox, expr);
  }

  if (matchAnyTokenAdvance(parser, 1, TOKEN_IDENTIFIER)) {
    return newVariableExpr(lox, prevToken(parser));
  }

  loxError(lox, peekToken(parser).line, "Expect expression.");
  return NULL;
}

// unary          → ( "!" | "-" ) unary
//                | primary ;
static Expr *unary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (matchAnyTokenAdvance(parser, 2, TOKEN_NOT, TOKEN_MINUS)) {
    Token operator= prevToken(parser);
    Expr *right = unary(lox);
    return newUnaryExpr(lox, operator, right);
  }

  return primary(lox);
}

// factor         → unary ( ( "/" | "*" ) unary )* ;
static Expr *factor(Lox *lox) {
  Expr *expr = unary(lox);

  while (matchAnyTokenAdvance(&lox->parser, 2, TOKEN_STAR, TOKEN_SLASH)) {
    Token operator= prevToken(&lox->parser);
    Expr *right = unary(lox);
    expr = newBinaryExpr(lox, expr, operator, right);
  }

  return expr;
}

// term           → factor ( ( "-" | "+" ) factor )* ;
static Expr *term(Lox *lox) {
  Expr *expr = factor(lox);

  while (matchAnyTokenAdvance(&lox->parser, 2, TOKEN_PLUS, TOKEN_MINUS)) {
    Token operator= prevToken(&lox->parser);
    Expr *right = factor(lox);
    expr = newBinaryExpr(lox, expr, operator, right);
  }

  return expr;
}

// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
static Expr *comparison(Lox *lox) {
  Expr *expr = term(lox);

  while (matchAnyTokenAdvance(&lox->parser, 4, TOKEN_GREATER,
                              TOKEN_GREATER_EQUAL, TOKEN_LESS,
                              TOKEN_LESS_EQUAL)) {
    Token operator= prevToken(&lox->parser);
    Expr *right = term(lox);
    expr = newBinaryExpr(lox, expr, operator, right);
  }

  return expr;
}

// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
static Expr *equality(Lox *lox) {
  Expr *expr = comparison(lox);

  while (matchAnyTokenAdvance(&lox->parser, 2, TOKEN_EQUAL_EQUAL,
                              TOKEN_NOT_EQUAL)) {
    Token operator= prevToken(&lox->parser);
    Expr *right = comparison(lox);
    expr = newBinaryExpr(lox, expr, operator, right);
  }

  return expr;
}

// expression     → equality ;
static Expr *expression(Lox *lox) { return equality(lox); }
