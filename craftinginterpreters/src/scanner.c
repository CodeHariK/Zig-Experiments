#include "lox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void multiLineStringScan(Lox *lox);
static void numberScan(Lox *lox);
static void identifierScan(Scanner *scanner);

static inline bool isDigit(char c) { return c >= '0' && c <= '9'; }
static inline bool isAlpha(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}
static inline bool isAlphaNumeric(char c) { return isAlpha(c) || isDigit(c); }

static const Keyword keywords[] = {
    {"and", TOKEN_AND},     {"class", TOKEN_CLASS},   {"else", TOKEN_ELSE},
    {"false", TOKEN_FALSE}, {"for", TOKEN_FOR},       {"fun", TOKEN_FUN},
    {"if", TOKEN_IF},       {"nil", TOKEN_NIL},       {"or", TOKEN_OR},
    {"print", TOKEN_PRINT}, {"return", TOKEN_RETURN}, {"super", TOKEN_SUPER},
    {"this", TOKEN_THIS},   {"true", TOKEN_TRUE},     {"var", TOKEN_VAR},
    {"while", TOKEN_WHILE},
};

static TokenType checkKeyword(const char *text, size_t length) {
  size_t numKeywords = sizeof(keywords) / sizeof(keywords[0]);
  for (size_t i = 0; i < numKeywords; i++) {
    if (strlen(keywords[i].name) == length &&
        strncmp(text, keywords[i].name, length) == 0) {
      return keywords[i].type;
    }
  }
  return TOKEN_IDENTIFIER; // default
}

const char *tokenTypeToString(TokenType type) {
  switch (type) {
  case TOKEN_LEFT_PAREN:
    return "LEFT_PAREN";
  case TOKEN_RIGHT_PAREN:
    return "RIGHT_PAREN";
  case TOKEN_LEFT_BRACE:
    return "LEFT_BRACE";
  case TOKEN_RIGHT_BRACE:
    return "RIGHT_BRACE";
  case TOKEN_COMMA:
    return "COMMA";
  case TOKEN_DOT:
    return "DOT";
  case TOKEN_MINUS:
    return "MINUS";
  case TOKEN_PLUS:
    return "PLUS";
  case TOKEN_SEMICOLON:
    return "SEMICOLON";
  case TOKEN_SLASH:
    return "SLASH";
  case TOKEN_STAR:
    return "STAR";
  case TOKEN_NOT:
    return "NOT";
  case TOKEN_NOT_EQUAL:
    return "NOT_EQUAL";
  case TOKEN_EQUAL:
    return "EQUAL";
  case TOKEN_EQUAL_EQUAL:
    return "EQUAL_EQUAL";
  case TOKEN_GREATER:
    return "GREATER";
  case TOKEN_GREATER_EQUAL:
    return "GREATER_EQUAL";
  case TOKEN_LESS:
    return "LESS";
  case TOKEN_LESS_EQUAL:
    return "LESS_EQUAL";
  case TOKEN_IDENTIFIER:
    return "IDENTIFIER";
  case TOKEN_STRING:
    return "STRING";
  case TOKEN_NUMBER:
    return "NUMBER";
  case TOKEN_AND:
    return "AND";
  case TOKEN_CLASS:
    return "CLASS";
  case TOKEN_ELSE:
    return "ELSE";
  case TOKEN_FALSE:
    return "FALSE";
  case TOKEN_FUN:
    return "FUN";
  case TOKEN_FOR:
    return "FOR";
  case TOKEN_IF:
    return "IF";
  case TOKEN_NIL:
    return "NIL";
  case TOKEN_OR:
    return "OR";
  case TOKEN_PRINT:
    return "PRINT";
  case TOKEN_RETURN:
    return "RETURN";
  case TOKEN_SUPER:
    return "SUPER";
  case TOKEN_THIS:
    return "THIS";
  case TOKEN_TRUE:
    return "TRUE";
  case TOKEN_VAR:
    return "VAR";
  case TOKEN_WHILE:
    return "WHILE";
  case TOKEN_EOF:
    return "EOF";
  default:
    return "UNKNOWN";
  }
}

void printToken(const Token *token) {
  printf("%s %s %p\n", tokenTypeToString(token->type), token->lexeme,
         token->literal);
}

void initScanner(Scanner *scanner, const char *source) {
  scanner->source = source;
  scanner->tokens = NULL;
  scanner->count = 0;
  scanner->capacity = 0;
  scanner->start = 0;
  scanner->current = 0;
  scanner->line = 1;
}

void freeScanner(Scanner *scanner) {
  free(scanner->tokens);

  for (size_t i = 0; i < scanner->count; i++) {
    // free((void *)scanner->tokens[i].lexeme);
    free(scanner->tokens[i].literal);
  }
}

void addTokenToArray(Scanner *scanner, Token token) {
  // Resize array if needed
  if (scanner->count + 1 > scanner->capacity) {
    size_t oldCapacity = scanner->capacity;
    scanner->capacity = oldCapacity < 8 ? 8 : oldCapacity * 2;
    scanner->tokens =
        realloc(scanner->tokens, sizeof(Token) * scanner->capacity);
    if (!scanner->tokens) {
      // Handle allocation failure
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
  }

  // Add the token
  scanner->tokens[scanner->count++] = token;
}

static void addToken(Scanner *scanner, TokenType type) {
  // size_t length = scanner->current - scanner->start;
  Token token = {.type = type,
                 .lexeme = &scanner->source[scanner->start],
                 .length = scanner->current - scanner->start,
                 .literal = NULL,
                 .line = scanner->line};
  addTokenToArray(scanner, token); // dynamic array helper from before
}

static void addTokenWithLiteral(Scanner *scanner, TokenType type,
                                void *literal) {
  // size_t length = scanner->current - scanner->start;

  // Point lexeme directly into source
  const char *text = &scanner->source[scanner->start];

  Token token = {
      .type = type, .lexeme = text, .literal = literal, .line = scanner->line};

  addTokenToArray(scanner, token); // dynamic array helper
}

static inline bool isAtEnd(Scanner *scanner) {
  return scanner->source[scanner->current] == '\0';
}

static char advance(Scanner *scanner) {
  return scanner->source[scanner->current++];
}

static inline bool match(Scanner *scanner, char expected) {
  if (isAtEnd(scanner))
    return false;
  if (scanner->source[scanner->current] != expected)
    return false;

  scanner->current++;
  return true;
}

static inline char peek(Scanner *scanner) {
  if (isAtEnd(scanner))
    return '\0';
  return scanner->source[scanner->current];
}

static char peekNext(Scanner *scanner) {
  if (scanner->source[scanner->current + 1] == '\0')
    return '\0';
  return scanner->source[scanner->current + 1];
}

static void scanToken(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  char c = advance(scanner);

  switch (c) {
  case '(':
    addToken(scanner, TOKEN_LEFT_PAREN);
    break;
  case ')':
    addToken(scanner, TOKEN_RIGHT_PAREN);
    break;
  case '{':
    addToken(scanner, TOKEN_LEFT_BRACE);
    break;
  case '}':
    addToken(scanner, TOKEN_RIGHT_BRACE);
    break;
  case ',':
    addToken(scanner, TOKEN_COMMA);
    break;
  case '.':
    addToken(scanner, TOKEN_DOT);
    break;
  case '-':
    addToken(scanner, TOKEN_MINUS);
    break;
  case '+':
    addToken(scanner, TOKEN_PLUS);
    break;
  case ';':
    addToken(scanner, TOKEN_SEMICOLON);
    break;
  case '*':
    addToken(scanner, TOKEN_STAR);
    break;

    // Two-character tokens
  case '!':
    addToken(scanner, match(scanner, '=') ? TOKEN_NOT_EQUAL : TOKEN_NOT);
    break;
  case '=':
    addToken(scanner, match(scanner, '=') ? TOKEN_EQUAL_EQUAL : TOKEN_EQUAL);
    break;
  case '<':
    addToken(scanner, match(scanner, '=') ? TOKEN_LESS_EQUAL : TOKEN_LESS);
    break;
  case '>':
    addToken(scanner,
             match(scanner, '=') ? TOKEN_GREATER_EQUAL : TOKEN_GREATER);
    break;

  case '/':
    if (match(scanner, '/')) {
      // A comment goes until the end of the line.
      while (!isAtEnd(scanner) && peek(scanner) != '\n')
        advance(scanner);
    } else {
      addToken(scanner, TOKEN_SLASH);
    }
    break;

  case ' ':
  case '\r':
  case '\t':
    // Ignore whitespace.
    break;

  case '\n':
    scanner->line++;
    break;

  case '"':
    multiLineStringScan(lox);
    break;

    // case 'o':
    //   if (match(scanner, 'r')) {
    //     addToken(scanner, TOKEN_OR);
    //   }
    //   break;

  default:
    if (isDigit(c)) {
      numberScan(lox);
    } else if (isAlpha(c)) {
      identifierScan(&lox->scanner);
    } else {
      loxError(lox, scanner->line, "Unexpected character.");
    }
    break;
  }
}

Token *scanTokens(Lox *lox, size_t *outCount) {
  Scanner *scanner = &lox->scanner;
  while (!isAtEnd(scanner)) {
    scanner->start = scanner->current;
    scanToken(lox); // implement this next
  }

  // Add EOF token
  addToken(scanner, TOKEN_EOF);

  if (outCount)
    *outCount = scanner->count;
  return scanner->tokens;
}

static void multiLineStringScan(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  while (peek(scanner) != '"' && !isAtEnd(scanner)) {
    if (peek(scanner) == '\n')
      scanner->line++;
    advance(scanner);
  }

  if (isAtEnd(scanner)) {
    loxError(lox, scanner->line, "Unterminated string.");
    return;
  }

  // Consume the closing quote
  advance(scanner);

  // Trim the surrounding quotes
  size_t length = scanner->current - scanner->start - 2; // exclude quotes
  char *value = malloc(length + 1);
  if (!value) {
    fprintf(stderr, "Memory allocation failed\n");
    exit(1);
  }

  memcpy(value, &scanner->source[scanner->start + 1], length);
  value[length] = '\0';

  addTokenWithLiteral(scanner, TOKEN_STRING, value);
}

static void numberScan(Lox *lox) {
  Scanner *scanner = &lox->scanner;

  // Consume integer part
  while (isDigit(peek(scanner)))
    advance(scanner);

  // Look for fractional part
  if (peek(scanner) == '.' && isDigit(peekNext(scanner))) {
    advance(scanner); // consume '.'

    while (isDigit(peek(scanner)))
      advance(scanner);
  }

  // Convert substring to double
  size_t length = scanner->current - scanner->start;
  char *text = malloc(length + 1);
  if (!text) {
    fprintf(stderr, "Memory allocation failed\n");
    exit(1);
  }

  memcpy(text, &scanner->source[scanner->start], length);
  text[length] = '\0';

  double value = strtod(text, NULL);
  free(text);

  addTokenWithLiteral(scanner, TOKEN_NUMBER,
                      (void *)(double *)malloc(sizeof(double)));
  *((double *)scanner->tokens[scanner->count - 1].literal) = value;
}

static void identifierScan(Scanner *scanner) {
  while (isAlphaNumeric(peek(scanner)))
    advance(scanner);

  const char *text = &scanner->source[scanner->start];
  TokenType type = checkKeyword(text, scanner->current - scanner->start);

  addToken(scanner, type);
}
