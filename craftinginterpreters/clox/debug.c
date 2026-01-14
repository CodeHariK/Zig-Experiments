#include "clox.h"

#ifdef DEBUG_TRACE_EXECUTION

static void printStack(VM *vm) {
  printf("STACK ");
  for (Value *slot = vm->stack; slot < vm->stackTop; slot++) {
    printf("| ");
    printValue(*slot);
    printf(" ");
  }
  printf("|\n");
}

void traceExecution(VM *vm) {
  printStack(vm);
  instructionDisassemble(vm->chunk, (u32)(vm->ip - (u8 *)vm->chunk->code.data));
}
#else
void traceExecution(VM *vm) { (void)vm; }
#endif

#ifdef DEBUG_PARSER

static const char *precedenceName(Precedence prec) {
  switch (prec) {
  case PREC_NONE:
    return "NONE";
  case PREC_ASSIGNMENT:
    return "ASSIGNMENT";
  case PREC_OR:
    return "OR";
  case PREC_AND:
    return "AND";
  case PREC_EQUALITY:
    return "EQUALITY";
  case PREC_COMPARISON:
    return "COMPARISON";
  case PREC_TERM:
    return "TERM";
  case PREC_FACTOR:
    return "FACTOR";
  case PREC_UNARY:
    return "UNARY";
  case PREC_CALL:
    return "CALL";
  case PREC_PRIMARY:
    return "PRIMARY";
  default:
    return "UNKNOWN";
  }
}

static const char *tokenTypeName(TokenType type) {
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
  case TOKEN_BANG:
    return "BANG";
  case TOKEN_BANG_EQUAL:
    return "BANG_EQUAL";
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
  case TOKEN_FOR:
    return "FOR";
  case TOKEN_FUN:
    return "FUN";
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
  case TOKEN_ERROR:
    return "ERROR";
  case TOKEN_EOF:
    return "EOF";
  default:
    return "UNKNOWN";
  }
}

static void printToken(Token *token) {
  if (token->type == TOKEN_EOF) {
    printf("EOF");
  } else if (token->type == TOKEN_ERROR) {
    printf("ERROR");
  } else {
    printf("'%.*s'", (int)token->length, token->start);
  }
}

void debugTokenAdvance(Parser *parser, Token *newToken) {
  printf("[PARSER] Advanced: previous=");
  printToken(&parser->previous);
  printf(" (%s), current=", tokenTypeName(parser->previous.type));
  printToken(newToken);
  printf(" (%s)\n", tokenTypeName(newToken->type));
}

void debugParsePrecedence(Precedence minPrec, TokenType tokenType,
                          Precedence tokenPrec, bool isPrefix) {
  printf("[PARSER] parsePrecedence: minPrec=%s, token=%s, tokenPrec=%s, "
         "isPrefix=%s\n",
         precedenceName(minPrec), tokenTypeName(tokenType),
         precedenceName(tokenPrec), isPrefix ? "true" : "false");
}

void debugRuleLookup(TokenType tokenType, ParseRule *rule) {
  const char *prefixName = rule->prefix ? "HAS_PREFIX" : "NO_PREFIX";
  const char *infixName = rule->infix ? "HAS_INFIX" : "NO_INFIX";
  printf("[PARSER] Rule lookup: token=%s, prefix=%s, infix=%s, precedence=%s\n",
         tokenTypeName(tokenType), prefixName, infixName,
         precedenceName(rule->precedence));
}

void debugPrefixCall(TokenType tokenType) {
  printf("[PARSER] Calling prefix rule for token=%s\n",
         tokenTypeName(tokenType));
}

void debugInfixCall(TokenType tokenType) {
  printf("[PARSER] Calling infix rule for token=%s\n",
         tokenTypeName(tokenType));
}

void debugPrecedenceCheck(Precedence minPrec, TokenType currentToken,
                          Precedence currentPrec, bool willContinue) {
  printf("[PARSER] Precedence check: minPrec=%s <= currentPrec=%s (%s) -> %s\n",
         precedenceName(minPrec), precedenceName(currentPrec),
         tokenTypeName(currentToken), willContinue ? "CONTINUE" : "STOP");
}

void debugEnterParsePrecedence(Precedence minPrec) {
  printf("[PARSER] >>> Entering parsePrecedence with minPrec=%s\n",
         precedenceName(minPrec));
}

void debugExitParsePrecedence(Precedence minPrec) {
  printf("[PARSER] <<< Exiting parsePrecedence with minPrec=%s\n",
         precedenceName(minPrec));
}

#else

void debugTokenAdvance(Parser *parser, Token *newToken) {
  (void)parser;
  (void)newToken;
}
void debugParsePrecedence(Precedence minPrec, TokenType tokenType,
                          Precedence tokenPrec, bool isPrefix) {
  (void)minPrec;
  (void)tokenType;
  (void)tokenPrec;
  (void)isPrefix;
}
void debugRuleLookup(TokenType tokenType, ParseRule *rule) {
  (void)tokenType;
  (void)rule;
}
void debugPrefixCall(TokenType tokenType) { (void)tokenType; }
void debugInfixCall(TokenType tokenType) { (void)tokenType; }
void debugPrecedenceCheck(Precedence minPrec, TokenType currentToken,
                          Precedence currentPrec, bool willContinue) {
  (void)minPrec;
  (void)currentToken;
  (void)currentPrec;
  (void)willContinue;
}
void debugEnterParsePrecedence(Precedence minPrec) { (void)minPrec; }
void debugExitParsePrecedence(Precedence minPrec) { (void)minPrec; }

#endif
