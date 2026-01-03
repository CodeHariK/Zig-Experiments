#include "lox.h"
#include <stdlib.h>
#include <string.h>

static void multiLineStringScan(Lox *lox);
static void numberScan(Lox *lox);
static void identifierScan(Lox *lox);

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

void initScanner(Scanner *scanner, const char *source) {
  scanner->source = source;
  scanner->capacity = 8;
  scanner->tokens = malloc(sizeof(Token) * scanner->capacity);
  scanner->count = 0;
  scanner->start = 0;
  scanner->current = 0;
  scanner->line = 1;
}

void addTokenToArray(Lox *lox, Token token) {
  // Resize array if needed
  Scanner *scanner = &lox->scanner;
  if (scanner->count + 1 > scanner->capacity) {
    scanner->capacity *= 2;
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

  printToken(lox, &token);
}

static void addToken(Lox *lox, TokenType type, void *literal) {
  Scanner *scanner = &lox->scanner;
  size_t len = scanner->current - scanner->start;
  char *lex = malloc(len + 1);
  memcpy(lex, &scanner->source[scanner->start], len);
  lex[len] = '\0'; // null-terminate

  Token token = {.type = type,
                 .lexeme = lex,
                 .length = len,
                 .literal = literal,
                 .line = scanner->line};

  addTokenToArray(lox, token);
}

static inline bool isEOFchar(Scanner *scanner) {
  return scanner->source[scanner->current] == '\0';
}

static inline void advanceChar(Scanner *scanner) { scanner->current++; }
static inline void advanceLine(Scanner *scanner) { scanner->line++; }

static inline bool matchCharAdvance(Scanner *scanner, char expected) {
  if (isEOFchar(scanner) || scanner->source[scanner->current] != expected)
    return false;

  scanner->current++;
  return true;
}

static inline char peekChar(Scanner *scanner) {
  return scanner->source[scanner->current];
}

static inline char peekNextChar(Scanner *scanner) {
  return scanner->source[scanner->current + 1];
}

static void scanToken(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  char c = peekChar(scanner);
  advanceChar(scanner);

  switch (c) {
  case '(':
    addToken(lox, TOKEN_LEFT_PAREN, NULL);
    break;
  case ')':
    addToken(lox, TOKEN_RIGHT_PAREN, NULL);
    break;
  case '{':
    addToken(lox, TOKEN_LEFT_BRACE, NULL);
    break;
  case '}':
    addToken(lox, TOKEN_RIGHT_BRACE, NULL);
    break;
  case ',':
    addToken(lox, TOKEN_COMMA, NULL);
    break;
  case '.':
    addToken(lox, TOKEN_DOT, NULL);
    break;
  case '-':
    addToken(lox, TOKEN_MINUS, NULL);
    break;
  case '+':
    addToken(lox, TOKEN_PLUS, NULL);
    break;
  case ';':
    addToken(lox, TOKEN_SEMICOLON, NULL);
    break;
  case '*':
    addToken(lox, TOKEN_STAR, NULL);
    break;

    // Two-character tokens
  case '!':
    addToken(lox, matchCharAdvance(scanner, '=') ? TOKEN_NOT_EQUAL : TOKEN_NOT,
             NULL);
    break;
  case '=':
    addToken(lox,
             matchCharAdvance(scanner, '=') ? TOKEN_EQUAL_EQUAL : TOKEN_EQUAL,
             NULL);
    break;
  case '<':
    addToken(lox,
             matchCharAdvance(scanner, '=') ? TOKEN_LESS_EQUAL : TOKEN_LESS,
             NULL);
    break;
  case '>':
    addToken(lox,
             matchCharAdvance(scanner, '=') ? TOKEN_GREATER_EQUAL
                                            : TOKEN_GREATER,
             NULL);
    break;

  case '/':
    if (matchCharAdvance(scanner, '/')) {
      // A comment goes until the end of the line.
      while (!isEOFchar(scanner) && peekChar(scanner) != '\n')
        advanceChar(scanner);
    } else {
      addToken(lox, TOKEN_SLASH, NULL);
    }
    break;

  case ' ':
  case '\r':
  case '\t':
    // Ignore whitespace.
    break;

  case '\n':
    advanceLine(scanner);
    break;

  case '"':
    multiLineStringScan(lox);
    break;

  default:
    if (isDigit(c)) {
      numberScan(lox);
    } else if (isAlpha(c)) {
      identifierScan(lox);
    } else {
      loxError(lox, scanner->line, " @ ", "Unexpected character.");
    }
    break;
  }
}

Token *scanTokens(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  while (!isEOFchar(scanner)) {
    scanner->start = scanner->current;
    scanToken(lox); // implement this next
  }

  // Add EOF token
  Token eof = {.type = TOKEN_EOF,
               .lexeme = "",
               .length = 0,
               .literal = NULL,
               .line = scanner->line};
  addTokenToArray(lox, eof);

  return scanner->tokens;
}

static void multiLineStringScan(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  while (peekChar(scanner) != '"' && !isEOFchar(scanner)) {
    if (peekChar(scanner) == '\n')
      advanceLine(scanner);
    advanceChar(scanner);
  }

  if (isEOFchar(scanner)) {
    loxError(lox, scanner->line, " @ ", "Unterminated string.");
    return;
  }

  // Consume the closing quote
  advanceChar(scanner);

  // Trim the surrounding quotes
  size_t length = scanner->current - scanner->start - 2; // exclude quotes
  char *value = malloc(length + 1);
  if (!value) {
    fprintf(stderr, "Memory allocation failed\n");
    exit(1);
  }

  memcpy(value, &scanner->source[scanner->start + 1], length);
  value[length] = '\0';

  addToken(lox, TOKEN_STRING, value);
}

static void numberScan(Lox *lox) {
  Scanner *scanner = &lox->scanner;

  // Consume integer part
  while (isDigit(peekChar(scanner)))
    advanceChar(scanner);

  // Look for fractional part
  if (peekChar(scanner) == '.' && isDigit(peekNextChar(scanner))) {
    advanceChar(scanner); // consume '.'

    while (isDigit(peekChar(scanner)))
      advanceChar(scanner);
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

  addToken(lox, TOKEN_NUMBER, (void *)(double *)malloc(sizeof(double)));
  *((double *)scanner->tokens[scanner->count - 1].literal) = value;
}

static void identifierScan(Lox *lox) {
  Scanner *scanner = &lox->scanner;
  while (isAlphaNumeric(peekChar(scanner)))
    advanceChar(scanner);

  const char *text = &scanner->source[scanner->start];
  TokenType type = checkKeyword(text, scanner->current - scanner->start);

  addToken(lox, type, NULL);
}
