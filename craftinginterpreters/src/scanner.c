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
    {"and", TOKEN_AND},       {"class", TOKEN_CLASS},
    {"else", TOKEN_ELSE},     {"false", TOKEN_FALSE},
    {"fun", TOKEN_FUN},       {"nil", TOKEN_NIL},
    {"or", TOKEN_OR},         {"print", TOKEN_PRINT},
    {"return", TOKEN_RETURN}, {"super", TOKEN_SUPER},
    {"this", TOKEN_THIS},     {"true", TOKEN_TRUE},
    {"var", TOKEN_VAR},       {"if", TOKEN_IF},
    {"while", TOKEN_WHILE},   {"for", TOKEN_FOR},
    {"break", TOKEN_BREAK},   {"continue", TOKEN_CONTINUE},
};

static TokenType checkKeyword(const char *text, u8 length) {
  u8 numKeywords = sizeof(keywords) / sizeof(keywords[0]);
  for (u8 i = 0; i < numKeywords; i++) {
    if (strlen(keywords[i].name) == length &&
        strncmp(text, keywords[i].name, length) == 0) {
      return keywords[i].type;
    }
  }
  return TOKEN_IDENTIFIER; // default
}

void initScanner(Scanner *scanner, const char *source) {
  *scanner = (Scanner){
      .source = source,
      .capacity = 8,
      .tokens = malloc(sizeof(Token) * 8),
      .count = 0,
      .start = 0,
      .current = 0,
      .line = 1,
  };
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

  printToken(lox, &token, "");
}

static void addToken(Lox *lox, TokenType type, void *literal) {
  Scanner *scanner = &lox->scanner;
  u32 len = scanner->current - scanner->start;
  char *lex = malloc(len + 1);
  memcpy(lex, &scanner->source[scanner->start], len);
  lex[len] = '\0'; // null-terminate

  Token token = {
      .type = type,
      .lexeme = lex,
      .length = len,
      .literal = literal,
      .line = scanner->line,
  };

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
      reportError(lox, scanner->line, "", "Unexpected character.");
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
  Token eof = {
      .type = TOKEN_EOF,
      .lexeme = "",
      .length = 0,
      .literal = NULL,
      .line = scanner->line,
  };
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
    reportError(lox, scanner->line, "", "Unterminated string.");
    return;
  }

  // Consume the closing quote
  advanceChar(scanner);

  // Trim the surrounding quotes
  u32 length = scanner->current - scanner->start - 2; // exclude quotes
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
  u32 length = scanner->current - scanner->start;
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
