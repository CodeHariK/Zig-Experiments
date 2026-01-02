#include "lox.h"
#include "token.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

Token peek(Parser *parser) { return parser->tokens[parser->current]; }

void parserError(Lox *lox, const char *message) {
  Token token = peek(&lox->parser);
  if (token.type == TOKEN_EOF) {
    loxReport(lox, token.line, " at end", message);
  } else {
    char where[64];
    snprintf(where, sizeof(where), " at '%s'", token.lexeme);
    loxReport(lox, token.line, where, message);
  }
}

Token previous(Parser *parser) { return parser->tokens[parser->current - 1]; }

bool isAtEnd(Parser *parser) { return peek(parser).type == TOKEN_EOF; }

Token advance(Parser *parser) {
  if (!isAtEnd(parser))
    parser->current++;
  return previous(parser);
}

bool check(Parser *parser, TokenType type) {
  if (isAtEnd(parser))
    return false;
  return peek(parser).type == type;
}

bool match(Parser *parser, int count, ...) {
  va_list args;
  va_start(args, count);

  for (int i = 0; i < count; i++) {
    TokenType type = va_arg(args, TokenType);
    if (check(parser, type)) {
      advance(parser);
      va_end(args);
      return true;
    }
  }

  va_end(args);
  return false;
}

Token consume(Lox *lox, TokenType type, const char *message) {
  Parser *parser = &lox->parser;
  if (check(parser, type))
    return advance(parser);

  parserError(lox, message);
  return peek(parser); // error recovery will improve later
}

static Expr *expression(Lox *lox);

Expr *parseExpression(Lox *lox) { return expression(lox); }

// primary        → NUMBER | STRING | "true" | "false" | "nil"
//                | "(" expression ")" ;
static Expr *primary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (match(parser, 1, TOKEN_FALSE))
    return newLiteralExpr(boolValue(false));

  if (match(parser, 1, TOKEN_TRUE))
    return newLiteralExpr(boolValue(true));

  if (match(parser, 1, TOKEN_NIL))
    return newLiteralExpr(nilValue());

  if (match(parser, 1, TOKEN_NUMBER))
    return newLiteralExpr(numberValue(*(double *)previous(parser).literal));

  if (match(parser, 1, TOKEN_STRING))
    return newLiteralExpr((Value){
        .type = VAL_STRING, .as.string = (char *)previous(parser).literal});

  if (match(parser, 1, TOKEN_LEFT_PAREN)) {
    Expr *expr = expression(lox);
    consume(lox, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
    return newGroupingExpr(expr);
  }

  loxError(lox, peek(parser).line, "Expect expression.");
  return NULL;
}

// unary          → ( "!" | "-" ) unary
//                | primary ;
static Expr *unary(Lox *lox) {
  Parser *parser = &lox->parser;
  if (match(parser, 2, TOKEN_NOT, TOKEN_MINUS)) {
    Token operator= previous(parser);
    Expr *right = unary(lox);
    return newUnaryExpr(operator, right);
  }

  return primary(lox);
}

// factor         → unary ( ( "/" | "*" ) unary )* ;
static Expr *factor(Lox *lox) {
  Expr *expr = unary(lox);

  while (match(&lox->parser, 2, TOKEN_STAR, TOKEN_SLASH)) {
    Token operator= previous(&lox->parser);
    Expr *right = unary(lox);
    expr = newBinaryExpr(expr, operator, right);
  }

  return expr;
}

// term           → factor ( ( "-" | "+" ) factor )* ;
static Expr *term(Lox *lox) {
  Expr *expr = factor(lox);

  while (match(&lox->parser, 2, TOKEN_PLUS, TOKEN_MINUS)) {
    Token operator= previous(&lox->parser);
    Expr *right = factor(lox);
    expr = newBinaryExpr(expr, operator, right);
  }

  return expr;
}

// comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
static Expr *comparison(Lox *lox) {
  Expr *expr = term(lox);

  while (match(&lox->parser, 4, TOKEN_GREATER, TOKEN_GREATER_EQUAL, TOKEN_LESS,
               TOKEN_LESS_EQUAL)) {
    Token operator= previous(&lox->parser);
    Expr *right = term(lox);
    expr = newBinaryExpr(expr, operator, right);
  }

  return expr;
}

// equality       → comparison ( ( "!=" | "==" ) comparison )* ;
static Expr *equality(Lox *lox) {
  Expr *expr = comparison(lox);

  while (match(&lox->parser, 2, TOKEN_EQUAL_EQUAL, TOKEN_NOT_EQUAL)) {
    Token operator= previous(&lox->parser);
    Expr *right = comparison(lox);
    expr = newBinaryExpr(expr, operator, right);
  }

  return expr;
}

// expression     → equality ;
static Expr *expression(Lox *lox) { return equality(lox); }
