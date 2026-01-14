#include "clox.h"

void parseNumber(VM *vm);
void parseUnary(VM *vm);
void parseGrouping(VM *vm);
void parseBinary(VM *vm);
static void parseLiteral(VM *vm);

ParseRule rules[] = {
    [TOKEN_LEFT_PAREN] = {parseGrouping, NULL, PREC_NONE},
    [TOKEN_RIGHT_PAREN] = {NULL, NULL, PREC_NONE},
    [TOKEN_LEFT_BRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_RIGHT_BRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_COMMA] = {NULL, NULL, PREC_NONE},
    [TOKEN_DOT] = {NULL, NULL, PREC_NONE},
    [TOKEN_MINUS] = {parseUnary, parseBinary, PREC_TERM},
    [TOKEN_PLUS] = {NULL, parseBinary, PREC_TERM},
    [TOKEN_SEMICOLON] = {NULL, NULL, PREC_NONE},
    [TOKEN_SLASH] = {NULL, parseBinary, PREC_FACTOR},
    [TOKEN_STAR] = {NULL, parseBinary, PREC_FACTOR},
    [TOKEN_NOT] = {parseUnary, NULL, PREC_NONE},
    [TOKEN_NOT_EQUAL] = {NULL, parseBinary, PREC_EQUALITY},
    [TOKEN_EQUAL] = {NULL, NULL, PREC_NONE},
    [TOKEN_EQUAL_EQUAL] = {NULL, parseBinary, PREC_EQUALITY},
    [TOKEN_GREATER] = {NULL, parseBinary, PREC_COMPARISON},
    [TOKEN_GREATER_EQUAL] = {NULL, parseBinary, PREC_COMPARISON},
    [TOKEN_LESS] = {NULL, parseBinary, PREC_COMPARISON},
    [TOKEN_LESS_EQUAL] = {NULL, parseBinary, PREC_COMPARISON},
    [TOKEN_IDENTIFIER] = {NULL, NULL, PREC_NONE},
    [TOKEN_STRING] = {NULL, NULL, PREC_NONE},
    [TOKEN_NUMBER] = {parseNumber, NULL, PREC_NONE},
    [TOKEN_AND] = {NULL, NULL, PREC_NONE},
    [TOKEN_CLASS] = {NULL, NULL, PREC_NONE},
    [TOKEN_ELSE] = {NULL, NULL, PREC_NONE},
    [TOKEN_FALSE] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_FOR] = {NULL, NULL, PREC_NONE},
    [TOKEN_FUN] = {NULL, NULL, PREC_NONE},
    [TOKEN_IF] = {NULL, NULL, PREC_NONE},
    [TOKEN_NIL] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_OR] = {NULL, NULL, PREC_NONE},
    [TOKEN_PRINT] = {NULL, NULL, PREC_NONE},
    [TOKEN_RETURN] = {NULL, NULL, PREC_NONE},
    [TOKEN_SUPER] = {NULL, NULL, PREC_NONE},
    [TOKEN_THIS] = {NULL, NULL, PREC_NONE},
    [TOKEN_TRUE] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_VAR] = {NULL, NULL, PREC_NONE},
    [TOKEN_WHILE] = {NULL, NULL, PREC_NONE},
    [TOKEN_ERROR] = {NULL, NULL, PREC_NONE},
    [TOKEN_EOF] = {NULL, NULL, PREC_NONE},
};

static void errorAt(Parser *parser, Token *token, const char *message) {
  if (parser->panicMode)
    return;

  parser->panicMode = true;
  fprintf(stderr, "[line %d] Error", token->line);

  if (token->type == TOKEN_EOF) {
    fprintf(stderr, " at end");
  } else if (token->type == TOKEN_ERROR) {
    // Nothing.
  } else {
    fprintf(stderr, " at '%.*s'", token->length, token->start);
  }

  fprintf(stderr, ": %s\n", message);
  parser->hadError = true;
}

static void error(Parser *parser, const char *message) {
  errorAt(parser, &parser->previous, message);
}

static void errorAtCurrent(Parser *parser, const char *message) {
  errorAt(parser, &parser->current, message);
}

static void advance(VM *vm) {
  vm->parser->previous = vm->parser->current;

  for (;;) {
    vm->parser->current = scanToken(vm->scanner);
    if (vm->parser->current.type != TOKEN_ERROR)
      break;

    errorAtCurrent(vm->parser, vm->parser->current.start);
  }

  debugTokenAdvance(vm->parser, &vm->parser->current);
}

static void consume(VM *vm, TokenType type, const char *message) {
  if (vm->parser->current.type == type) {
    advance(vm);
    return;
  }

  errorAtCurrent(vm->parser, message);
}

static void emitByte(VM *vm, u8 byte) {
  chunkWrite(vm->chunk, byte, vm->parser->previous.line);
}

static void emitBytes(VM *vm, u8 byte1, u8 byte2) {
  emitByte(vm, byte1);
  emitByte(vm, byte2);
}

static u8 makeConstant(VM *vm, Value value) {
  u32 constant = addConstant(vm->chunk, value);
  if (constant > UINT8_MAX) {
    error(vm->parser, "Too many constants in one chunk.");
    return 0;
  }

  return (u8)constant;
}

static void emitConstant(VM *vm, Value value) {
  emitBytes(vm, OP_CONSTANT, makeConstant(vm, value));
}

static void emitReturn(VM *vm) { emitByte(vm, OP_RETURN); }

#define DEBUG_PRINT_CODE

static void endCompiler(VM *vm) {
  emitReturn(vm);

#ifdef DEBUG_PRINT_CODE
  if (!vm->parser->hadError) {
    chunkDisassemble(vm->chunk, "code");
  }
#endif
}

static inline ParseRule *getRule(TokenType type) { return &rules[type]; }

static void parsePrecedence(VM *vm, Precedence precedence) {
  debugEnterParsePrecedence(precedence);

  advance(vm);
  ParseRule *rule = getRule(vm->parser->previous.type);
  debugRuleLookup(vm->parser->previous.type, rule);

  ParseFn prefixRule = rule->prefix;
  if (prefixRule == NULL) {
    error(vm->parser, "Expect expression.");
    debugExitParsePrecedence(precedence);
    return;
  }

  debugPrefixCall(vm->parser->previous.type);
  debugParsePrecedence(precedence, vm->parser->previous.type, rule->precedence,
                       true);
  prefixRule(vm);

  while (precedence <= getRule(vm->parser->current.type)->precedence) {
    ParseRule *currentRule = getRule(vm->parser->current.type);
    bool willContinue = precedence <= currentRule->precedence;
    debugPrecedenceCheck(precedence, vm->parser->current.type,
                         currentRule->precedence, willContinue);

    advance(vm);
    ParseRule *infixRule = getRule(vm->parser->previous.type);
    debugInfixCall(vm->parser->previous.type);
    debugParsePrecedence(precedence, vm->parser->previous.type,
                         infixRule->precedence, false);
    infixRule->infix(vm);
  }

  debugExitParsePrecedence(precedence);
}

static void parseExpression(VM *vm) { parsePrecedence(vm, PREC_ASSIGNMENT); }

static void parseLiteral(VM *vm) {
  switch (vm->parser->previous.type) {
  case TOKEN_FALSE:
    emitByte(vm, OP_FALSE);
    break;
  case TOKEN_NIL:
    emitByte(vm, OP_NIL);
    break;
  case TOKEN_TRUE:
    emitByte(vm, OP_TRUE);
    break;
  default:
    return; // Unreachable.
  }
}

void parseNumber(VM *vm) {
  double value = strtod(vm->parser->previous.start, NULL);
  emitConstant(vm, NUMBER_VAL(value));
}

void parseGrouping(VM *vm) {
  parseExpression(vm);
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

void parseUnary(VM *vm) {
  TokenType operatorType = vm->parser->previous.type;

  // Compile the operand.
  parsePrecedence(vm, PREC_UNARY);

  // Emit the operator instruction.
  switch (operatorType) {
  case TOKEN_MINUS:
    emitByte(vm, OP_NEGATE);
    break;
  case TOKEN_NOT:
    emitByte(vm, OP_NOT);
    break;
  default:
    return; // Unreachable.
  }
}

void parseBinary(VM *vm) {
  TokenType operatorType = vm->parser->previous.type;
  ParseRule *rule = getRule(operatorType);
  parsePrecedence(vm, (Precedence)(rule->precedence + 1));

  switch (operatorType) {
  case TOKEN_NOT_EQUAL:
    emitBytes(vm, OP_EQUAL, OP_NOT);
    break;
  case TOKEN_EQUAL_EQUAL:
    emitByte(vm, OP_EQUAL);
    break;
  case TOKEN_GREATER:
    emitByte(vm, OP_GREATER);
    break;
  case TOKEN_GREATER_EQUAL:
    emitBytes(vm, OP_LESS, OP_NOT);
    break;
  case TOKEN_LESS:
    emitByte(vm, OP_LESS);
    break;
  case TOKEN_LESS_EQUAL:
    emitBytes(vm, OP_GREATER, OP_NOT);
    break;
  case TOKEN_PLUS:
    emitByte(vm, OP_ADD);
    break;
  case TOKEN_MINUS:
    emitByte(vm, OP_SUBTRACT);
    break;
  case TOKEN_STAR:
    emitByte(vm, OP_MULTIPLY);
    break;
  case TOKEN_SLASH:
    emitByte(vm, OP_DIVIDE);
    break;
  default:
    return; // Unreachable.
  }
}

bool compile(VM *vm) {

  advance(vm);
  parseExpression(vm);
  consume(vm, TOKEN_EOF, "Expect end of expression.");
  endCompiler(vm);
  return !vm->parser->hadError;
}
