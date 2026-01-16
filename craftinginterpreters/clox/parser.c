#include "clox.h"

static void parseNumber(VM *vm, bool canAssign);
static void parseUnary(VM *vm, bool canAssign);
static void parseGrouping(VM *vm, bool canAssign);
static void parseBinary(VM *vm, bool canAssign);
static void parseLiteral(VM *vm, bool canAssign);
static void parseString(VM *vm, bool canAssign);
static void parseVariable(VM *vm, bool canAssign);
static void this_(VM *vm, bool canAssign);
static void super_(VM *vm, bool canAssign);
static void call(VM *vm, bool canAssign);
static void dot(VM *vm, bool canAssign);
static void declaration(VM *vm);
static void declareVariable(VM *vm);
static void classDeclaration(VM *vm);
static void statement(VM *vm);
static void varDeclaration(VM *vm);
static void and_(VM *vm, bool canAssign);
static void or_(VM *vm, bool canAssign);
static u8 parseVariableDeclaration(VM *vm, const char *errorMessage);
static void defineVariable(VM *vm, u8 global);
static void returnStatement(VM *vm);
static void block(VM *vm);
static void beginScope(VM *vm);
static u8 argumentList(VM *vm);

ParseRule rules[] = {
    [TOKEN_LEFT_PAREN] = {parseGrouping, call, PREC_CALL},
    [TOKEN_RIGHT_PAREN] = {NULL, NULL, PREC_NONE},
    [TOKEN_LEFT_BRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_RIGHT_BRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_COMMA] = {NULL, NULL, PREC_NONE},
    [TOKEN_DOT] = {NULL, dot, PREC_CALL},
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
    [TOKEN_IDENTIFIER] = {parseVariable, NULL, PREC_NONE},
    [TOKEN_STRING] = {parseString, NULL, PREC_NONE},
    [TOKEN_NUMBER] = {parseNumber, NULL, PREC_NONE},
    [TOKEN_AND] = {NULL, and_, PREC_AND},
    [TOKEN_CLASS] = {NULL, NULL, PREC_NONE},
    [TOKEN_ELSE] = {NULL, NULL, PREC_NONE},
    [TOKEN_FALSE] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_FOR] = {NULL, NULL, PREC_NONE},
    [TOKEN_FUN] = {NULL, NULL, PREC_NONE},
    [TOKEN_IF] = {NULL, NULL, PREC_NONE},
    [TOKEN_NIL] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_OR] = {NULL, or_, PREC_OR},
    [TOKEN_PRINT] = {NULL, NULL, PREC_NONE},
    [TOKEN_RETURN] = {NULL, NULL, PREC_NONE},
    [TOKEN_SUPER] = {super_, NULL, PREC_NONE},
    [TOKEN_THIS] = {this_, NULL, PREC_NONE},
    [TOKEN_TRUE] = {parseLiteral, NULL, PREC_NONE},
    [TOKEN_VAR] = {NULL, NULL, PREC_NONE},
    [TOKEN_WHILE] = {NULL, NULL, PREC_NONE},
    [TOKEN_ERROR] = {NULL, NULL, PREC_NONE},
    [TOKEN_EOF] = {NULL, NULL, PREC_NONE},
};

static void errorAtVM(VM *vm, Token *token, const char *message) {
  if (vm->parser->panicMode)
    return;

  vm->parser->panicMode = true;
  fprintf(stderr, "[line %d] Error", token->line);

  // Write to error buffer
  char temp[512];
  int len = 0;

  if (token->type == TOKEN_EOF) {
    fprintf(stderr, " at end");
    len = snprintf(temp, sizeof(temp), "[line %d] Error at end: %s\n",
                   token->line, message);
  } else if (token->type == TOKEN_ERROR) {
    len = snprintf(temp, sizeof(temp), "[line %d] Error: %s\n", token->line,
                   message);
  } else {
    fprintf(stderr, " at '%.*s'", (i32)token->length, token->start);
    len = snprintf(temp, sizeof(temp), "[line %d] Error at '%.*s': %s\n",
                   token->line, (i32)token->length, token->start, message);
  }

  fprintf(stderr, ": %s\n", message);

  // Append to error buffer
  if (len > 0 && vm->errorBufferLen + len < sizeof(vm->errorBuffer) - 1) {
    memcpy(vm->errorBuffer + vm->errorBufferLen, temp, len);
    vm->errorBufferLen += len;
    vm->errorBuffer[vm->errorBufferLen] = '\0';
  }

  vm->parser->hadError = true;
}

static void error(VM *vm, const char *message) {
  errorAtVM(vm, &vm->parser->previous, message);
}

static void errorAtCurrent(VM *vm, const char *message) {
  errorAtVM(vm, &vm->parser->current, message);
}

static void advance(VM *vm) {
  vm->parser->previous = vm->parser->current;

  for (;;) {
    vm->parser->current = scanToken(vm->scanner);
    if (vm->parser->current.type != TOKEN_ERROR)
      break;

    errorAtCurrent(vm, vm->parser->current.start);
  }

  debugTokenAdvance(vm->parser, &vm->parser->current);
}

static bool check(VM *vm, TokenType type) {
  return vm->parser->current.type == type;
}

static bool match(VM *vm, TokenType type) {
  if (!check(vm, type))
    return false;
  advance(vm);
  return true;
}

static void consume(VM *vm, TokenType type, const char *message) {
  if (vm->parser->current.type == type) {
    advance(vm);
    return;
  }

  errorAtCurrent(vm, message);
}

static void synchronize(VM *vm) {
  vm->parser->panicMode = false;

  printf("======================Synchronizing======================\n");

  while (vm->parser->current.type != TOKEN_EOF) {
    if (vm->parser->previous.type == TOKEN_SEMICOLON)
      return;
    switch (vm->parser->current.type) {
    case TOKEN_CLASS:
    case TOKEN_FUN:
    case TOKEN_VAR:
    case TOKEN_FOR:
    case TOKEN_IF:
    case TOKEN_WHILE:
    case TOKEN_PRINT:
    case TOKEN_RETURN:
      return;

    default:; // Do nothing.
    }

    advance(vm);
  }
  // If we're at EOF, we've synchronized (nothing more to skip)
}

static Chunk *currentChunk(VM *vm) { return &vm->compiler->function->chunk; }

static void emitByte(VM *vm, u8 byte) {
  chunkWrite(currentChunk(vm), byte, vm->parser->previous.line);
}

static void emitBytes(VM *vm, u8 byte1, u8 byte2) {
  emitByte(vm, byte1);
  emitByte(vm, byte2);
}

static u8 makeConstant(VM *vm, Value value) {
  size_t constant = addConstant(vm, currentChunk(vm), value);
  if (constant > UINT8_MAX) {
    error(vm, "Too many constants in one chunk.");
    return 0;
  }

  return (u8)constant;
}

static void emitConstant(VM *vm, Value value) {
  emitBytes(vm, OP_CONSTANT, makeConstant(vm, value));
}

static void emitReturn(VM *vm) {
  if (vm->compiler->type == TYPE_INITIALIZER) {
    emitBytes(vm, OP_GET_LOCAL, 0);
  } else {
    emitByte(vm, OP_NIL);
  }
  emitByte(vm, OP_RETURN);
}

static int emitJump(VM *vm, u8 instruction) {
  emitByte(vm, instruction);
  emitByte(vm, 0xff);
  emitByte(vm, 0xff);
  return (int)currentChunk(vm)->code.count - 2;
}

static void patchJump(VM *vm, int offset) {
  // -2 to adjust for the bytecode for the jump offset itself.
  int jump = (int)currentChunk(vm)->code.count - offset - 2;

  if (jump > UINT16_MAX) {
    error(vm, "Too much code to jump over.");
  }

  getCodeArr(currentChunk(vm))[offset] = (jump >> 8) & 0xff;
  getCodeArr(currentChunk(vm))[offset + 1] = jump & 0xff;
}

static void emitLoop(VM *vm, int loopStart) {
  emitByte(vm, OP_LOOP);

  int offset = (int)currentChunk(vm)->code.count - loopStart + 2;
  if (offset > UINT16_MAX) {
    error(vm, "Loop body too large.");
  }

  emitByte(vm, (offset >> 8) & 0xff);
  emitByte(vm, offset & 0xff);
}

#define DEBUG_PRINT_CODE

static void initCompiler(VM *vm, Compiler *compiler, FunctionType type) {
  compiler->enclosing = vm->compiler;
  compiler->function = NULL;
  compiler->type = type;
  compiler->localCount = 0;
  compiler->scopeDepth = 0;
  compiler->function = newFunction(vm);
  vm->compiler = compiler;

  if (type != TYPE_SCRIPT) {
    vm->compiler->function->name =
        copyString(vm, vm->parser->previous.start, vm->parser->previous.length);
  }

  // Claim slot zero for the VM's internal use
  Local *local = &vm->compiler->locals[vm->compiler->localCount++];
  local->depth = 0;
  local->isCaptured = false;
  if (type != TYPE_FUNCTION) {
    local->name.start = "this";
    local->name.length = 4;
  } else {
    local->name.start = "";
    local->name.length = 0;
  }
}

static ObjFunction *endCompiler(VM *vm) {
  emitReturn(vm);
  ObjFunction *function = vm->compiler->function;

#ifdef DEBUG_PRINT_CODE
  if (!vm->parser->hadError) {
    chunkDisassemble(currentChunk(vm), function->name != NULL
                                           ? function->name->chars
                                           : "<script>");
  }
#endif

  vm->compiler = vm->compiler->enclosing;
  return function;
}

static inline ParseRule *getRule(TokenType type) { return &rules[type]; }

static void parsePrecedence(VM *vm, Precedence precedence) {
  debugEnterParsePrecedence(precedence);

  advance(vm);
  ParseRule *rule = getRule(vm->parser->previous.type);
  debugRuleLookup(vm->parser->previous.type, rule);

  ParseFn prefixRule = rule->prefix;
  if (prefixRule == NULL) {
    error(vm, "Expect expression.");
    debugExitParsePrecedence(precedence);
    return;
  }

  bool canAssign = precedence <= PREC_ASSIGNMENT;
  debugPrefixCall(vm->parser->previous.type);
  debugParsePrecedence(precedence, vm->parser->previous.type, rule->precedence,
                       true);
  prefixRule(vm, canAssign);

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
    infixRule->infix(vm, canAssign);
  }

  if (canAssign && match(vm, TOKEN_EQUAL)) {
    error(vm, "Invalid assignment target.");
  }

  debugExitParsePrecedence(precedence);
}

static void parseExpression(VM *vm) { parsePrecedence(vm, PREC_ASSIGNMENT); }

static void parseLiteral(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
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

void parseNumber(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
  double value = strtod(vm->parser->previous.start, NULL);
  emitConstant(vm, NUMBER_VAL(value));
}

void parseGrouping(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
  parseExpression(vm);
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

void parseUnary(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
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

void parseBinary(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
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

static bool identifiersEqual(Token *a, Token *b) {
  if (a->length != b->length)
    return false;
  return memcmp(a->start, b->start, a->length) == 0;
}

static void addLocal(VM *vm, Token name) {
  if (vm->compiler->localCount == UINT8_COUNT) {
    error(vm, "Too many local variables in function.");
    return;
  }
  Local *local = &vm->compiler->locals[vm->compiler->localCount++];
  local->name = name;
  local->depth = -1;
  local->isCaptured = false;
}

static int resolveLocalInCompiler(Compiler *compiler, Token *name) {
  for (int i = compiler->localCount - 1; i >= 0; i--) {
    Local *local = &compiler->locals[i];
    if (identifiersEqual(name, &local->name)) {
      return i;
    }
  }
  return -1;
}

static int resolveLocal(VM *vm, Token *name) {
  int slot = resolveLocalInCompiler(vm->compiler, name);
  if (slot != -1) {
    Local *local = &vm->compiler->locals[slot];
    if (local->depth == -1) {
      error(vm, "Can't read local variable in its own initializer.");
    }
  }
  return slot;
}

static int addUpvalue(VM *vm, Compiler *compiler, u8 index, bool isLocal) {
  int upvalueCount = compiler->function->upvalueCount;

  for (int i = 0; i < upvalueCount; i++) {
    Upvalue *upvalue = &compiler->upvalues[i];
    if (upvalue->index == index && upvalue->isLocal == isLocal) {
      return i;
    }
  }

  if (upvalueCount == UINT8_COUNT) {
    error(vm, "Too many closure variables in function.");
    return 0;
  }

  compiler->upvalues[upvalueCount].isLocal = isLocal;
  compiler->upvalues[upvalueCount].index = index;
  return compiler->function->upvalueCount++;
}

static int resolveUpvalue(VM *vm, Compiler *compiler, Token *name) {
  if (compiler->enclosing == NULL)
    return -1;

  int local = resolveLocalInCompiler(compiler->enclosing, name);
  if (local != -1) {
    compiler->enclosing->locals[local].isCaptured = true;
    return addUpvalue(vm, compiler, (u8)local, true);
  }

  int upvalue = resolveUpvalue(vm, compiler->enclosing, name);
  if (upvalue != -1) {
    return addUpvalue(vm, compiler, (u8)upvalue, false);
  }

  return -1;
}

static void markInitialized(VM *vm) {
  if (vm->compiler->scopeDepth == 0)
    return;
  vm->compiler->locals[vm->compiler->localCount - 1].depth =
      vm->compiler->scopeDepth;
}

static u8 identifierConstant(VM *vm, Token *name) {
  return makeConstant(
      vm, OBJ_VAL((Obj *)copyString(vm, name->start, name->length)));
}

static void namedVariable(VM *vm, Token *name, bool canAssign) {
  u8 getOp, setOp;
  int arg = resolveLocal(vm, name);
  if (arg != -1) {
    getOp = OP_GET_LOCAL;
    setOp = OP_SET_LOCAL;
  } else if ((arg = resolveUpvalue(vm, vm->compiler, name)) != -1) {
    getOp = OP_GET_UPVALUE;
    setOp = OP_SET_UPVALUE;
  } else {
    arg = identifierConstant(vm, name);
    getOp = OP_GET_GLOBAL;
    setOp = OP_SET_GLOBAL;
  }

  if (canAssign && match(vm, TOKEN_EQUAL)) {
    parseExpression(vm);
    emitBytes(vm, setOp, (u8)arg);
  } else {
    emitBytes(vm, getOp, (u8)arg);
  }
}

static void parseVariable(VM *vm, bool canAssign) {
  namedVariable(vm, &vm->parser->previous, canAssign);
}

static Token syntheticToken(const char *text) {
  Token token;
  token.start = text;
  token.length = (int)strlen(text);
  return token;
}

static void this_(VM *vm, bool canAssign) {
  (void)canAssign;
  if (vm->currentClass == NULL) {
    error(vm, "Can't use 'this' outside of a class.");
    return;
  }
  parseVariable(vm, false);
}

static void super_(VM *vm, bool canAssign) {
  (void)canAssign;
  if (vm->currentClass == NULL) {
    error(vm, "Can't use 'super' outside of a class.");
  } else if (!vm->currentClass->hasSuperclass) {
    error(vm, "Can't use 'super' in a class with no superclass.");
  }

  consume(vm, TOKEN_DOT, "Expect '.' after 'super'.");
  consume(vm, TOKEN_IDENTIFIER, "Expect superclass method name.");
  u8 name = identifierConstant(vm, &vm->parser->previous);

  Token thisToken = syntheticToken("this");
  Token superToken = syntheticToken("super");
  namedVariable(vm, &thisToken, false);

  if (match(vm, TOKEN_LEFT_PAREN)) {
    u8 argCount = argumentList(vm);
    namedVariable(vm, &superToken, false);
    emitBytes(vm, OP_SUPER_INVOKE, name);
    emitByte(vm, argCount);
  } else {
    namedVariable(vm, &superToken, false);
    emitBytes(vm, OP_GET_SUPER, name);
  }
}

static void parseString(VM *vm, bool canAssign) {
  (void)canAssign; // Unused
  emitConstant(vm, OBJ_VAL((Obj *)copyString(vm, vm->parser->previous.start + 1,
                                             vm->parser->previous.length - 2)));
}

static void printStatement(VM *vm) {
  parseExpression(vm);
  consume(vm, TOKEN_SEMICOLON, "Expect ';' after value.");
  emitByte(vm, OP_PRINT);
}

static void expressionStatement(VM *vm) {
  parseExpression(vm);
  consume(vm, TOKEN_SEMICOLON, "Expect ';' after expression.");
  emitByte(vm, OP_POP);
}

static void block(VM *vm) {
  while (!check(vm, TOKEN_RIGHT_BRACE) && !check(vm, TOKEN_EOF)) {
    declaration(vm);
  }

  consume(vm, TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}

static void beginScope(VM *vm) { vm->compiler->scopeDepth++; }

static void endScope(VM *vm) {
  vm->compiler->scopeDepth--;

  while (vm->compiler->localCount > 0 &&
         vm->compiler->locals[vm->compiler->localCount - 1].depth >
             vm->compiler->scopeDepth) {
    if (vm->compiler->locals[vm->compiler->localCount - 1].isCaptured) {
      emitByte(vm, OP_CLOSE_UPVALUE);
    } else {
      emitByte(vm, OP_POP);
    }
    vm->compiler->localCount--;
  }
}

static void ifStatement(VM *vm) {
  consume(vm, TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
  parseExpression(vm);
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after condition.");

  int thenJump = emitJump(vm, OP_JUMP_IF_FALSE);
  emitByte(vm, OP_POP);
  statement(vm);

  int elseJump = emitJump(vm, OP_JUMP);

  patchJump(vm, thenJump);
  emitByte(vm, OP_POP);

  if (match(vm, TOKEN_ELSE))
    statement(vm);
  patchJump(vm, elseJump);
}

static void whileStatement(VM *vm) {
  int loopStart = (int)currentChunk(vm)->code.count;
  consume(vm, TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
  parseExpression(vm);
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after condition.");

  int exitJump = emitJump(vm, OP_JUMP_IF_FALSE);
  emitByte(vm, OP_POP);
  statement(vm);
  emitLoop(vm, loopStart);

  patchJump(vm, exitJump);
  emitByte(vm, OP_POP);
}

static void forStatement(VM *vm) {
  beginScope(vm);
  consume(vm, TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");

  // Initializer clause
  if (match(vm, TOKEN_SEMICOLON)) {
    // No initializer.
  } else if (match(vm, TOKEN_VAR)) {
    varDeclaration(vm);
  } else {
    expressionStatement(vm);
  }

  int loopStart = (int)currentChunk(vm)->code.count;

  // Condition clause
  int exitJump = -1;
  if (!match(vm, TOKEN_SEMICOLON)) {
    parseExpression(vm);
    consume(vm, TOKEN_SEMICOLON, "Expect ';' after loop condition.");

    // Jump out of the loop if the condition is false.
    exitJump = emitJump(vm, OP_JUMP_IF_FALSE);
    emitByte(vm, OP_POP); // Condition.
  }

  // Increment clause
  if (!match(vm, TOKEN_RIGHT_PAREN)) {
    int bodyJump = emitJump(vm, OP_JUMP);
    int incrementStart = (int)currentChunk(vm)->code.count;
    parseExpression(vm);
    emitByte(vm, OP_POP);
    consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");

    emitLoop(vm, loopStart);
    loopStart = incrementStart;
    patchJump(vm, bodyJump);
  }

  statement(vm);
  emitLoop(vm, loopStart);

  if (exitJump != -1) {
    patchJump(vm, exitJump);
    emitByte(vm, OP_POP); // Condition.
  }

  endScope(vm);
}

static void statement(VM *vm) {
  if (match(vm, TOKEN_PRINT)) {
    printStatement(vm);
  } else if (match(vm, TOKEN_IF)) {
    ifStatement(vm);
  } else if (match(vm, TOKEN_RETURN)) {
    returnStatement(vm);
  } else if (match(vm, TOKEN_WHILE)) {
    whileStatement(vm);
  } else if (match(vm, TOKEN_FOR)) {
    forStatement(vm);
  } else if (match(vm, TOKEN_LEFT_BRACE)) {
    beginScope(vm);
    block(vm);
    endScope(vm);
  } else {
    expressionStatement(vm);
  }

  if (vm->parser->panicMode)
    synchronize(vm);
}

static void and_(VM *vm, bool canAssign) {
  (void)canAssign;
  int endJump = emitJump(vm, OP_JUMP_IF_FALSE);

  emitByte(vm, OP_POP);
  parsePrecedence(vm, PREC_AND);

  patchJump(vm, endJump);
}

static void or_(VM *vm, bool canAssign) {
  (void)canAssign;
  int elseJump = emitJump(vm, OP_JUMP_IF_FALSE);
  int endJump = emitJump(vm, OP_JUMP);

  patchJump(vm, elseJump);
  emitByte(vm, OP_POP);

  parsePrecedence(vm, PREC_OR);
  patchJump(vm, endJump);
}

static u8 argumentList(VM *vm) {
  u8 argCount = 0;
  if (!check(vm, TOKEN_RIGHT_PAREN)) {
    do {
      parseExpression(vm);
      if (argCount == 255) {
        error(vm, "Can't have more than 255 arguments.");
      }
      argCount++;
    } while (match(vm, TOKEN_COMMA));
  }
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");
  return argCount;
}

static void call(VM *vm, bool canAssign) {
  (void)canAssign;
  u8 argCount = argumentList(vm);
  emitBytes(vm, OP_CALL, argCount);
}

static void dot(VM *vm, bool canAssign) {
  consume(vm, TOKEN_IDENTIFIER, "Expect property name after '.'.");
  u8 name = identifierConstant(vm, &vm->parser->previous);

  if (canAssign && match(vm, TOKEN_EQUAL)) {
    parseExpression(vm);
    emitBytes(vm, OP_SET_PROPERTY, name);
  } else if (match(vm, TOKEN_LEFT_PAREN)) {
    u8 argCount = argumentList(vm);
    emitBytes(vm, OP_INVOKE, name);
    emitByte(vm, argCount);
  } else {
    emitBytes(vm, OP_GET_PROPERTY, name);
  }
}

static void function_(VM *vm, FunctionType type) {
  Compiler compiler;
  initCompiler(vm, &compiler, type);
  beginScope(vm);

  consume(vm, TOKEN_LEFT_PAREN, "Expect '(' after function name.");
  if (!check(vm, TOKEN_RIGHT_PAREN)) {
    do {
      vm->compiler->function->arity++;
      if (vm->compiler->function->arity > 255) {
        errorAtCurrent(vm, "Can't have more than 255 parameters.");
      }
      u8 constant = parseVariableDeclaration(vm, "Expect parameter name.");
      defineVariable(vm, constant);
    } while (match(vm, TOKEN_COMMA));
  }
  consume(vm, TOKEN_RIGHT_PAREN, "Expect ')' after parameters.");
  consume(vm, TOKEN_LEFT_BRACE, "Expect '{' before function body.");
  block(vm);

  ObjFunction *function = endCompiler(vm);
  emitBytes(vm, OP_CLOSURE, makeConstant(vm, OBJ_VAL((Obj *)function)));

  for (int i = 0; i < function->upvalueCount; i++) {
    emitByte(vm, compiler.upvalues[i].isLocal ? 1 : 0);
    emitByte(vm, compiler.upvalues[i].index);
  }
}

static void method(VM *vm) {
  consume(vm, TOKEN_IDENTIFIER, "Expect method name.");
  u8 constant = identifierConstant(vm, &vm->parser->previous);

  FunctionType type = TYPE_METHOD;
  if (vm->parser->previous.length == 4 &&
      memcmp(vm->parser->previous.start, "init", 4) == 0) {
    type = TYPE_INITIALIZER;
  }

  function_(vm, type);
  emitBytes(vm, OP_METHOD, constant);
}

static void classDeclaration(VM *vm) {
  consume(vm, TOKEN_IDENTIFIER, "Expect class name.");
  Token className = vm->parser->previous;
  u8 nameConstant = identifierConstant(vm, &vm->parser->previous);
  declareVariable(vm);

  emitBytes(vm, OP_CLASS, nameConstant);
  defineVariable(vm, nameConstant);

  ClassCompiler classCompiler;
  classCompiler.hasSuperclass = false;
  classCompiler.enclosing = vm->currentClass;
  vm->currentClass = &classCompiler;

  if (match(vm, TOKEN_LESS)) {
    consume(vm, TOKEN_IDENTIFIER, "Expect superclass name.");
    parseVariable(vm, false);

    if (identifiersEqual(&className, &vm->parser->previous)) {
      error(vm, "A class can't inherit from itself.");
    }

    beginScope(vm);
    Token superToken = syntheticToken("super");
    addLocal(vm, superToken);
    defineVariable(vm, 0);

    namedVariable(vm, &className, false);
    emitByte(vm, OP_INHERIT);
    classCompiler.hasSuperclass = true;
  }

  namedVariable(vm, &className, false);

  consume(vm, TOKEN_LEFT_BRACE, "Expect '{' before class body.");
  while (!check(vm, TOKEN_RIGHT_BRACE) && !check(vm, TOKEN_EOF)) {
    method(vm);
  }
  consume(vm, TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
  emitByte(vm, OP_POP);

  if (classCompiler.hasSuperclass) {
    endScope(vm);
  }

  vm->currentClass = vm->currentClass->enclosing;
}

static void funDeclaration(VM *vm) {
  u8 global = parseVariableDeclaration(vm, "Expect function name.");
  markInitialized(vm);
  function_(vm, TYPE_FUNCTION);
  defineVariable(vm, global);
}

static void returnStatement(VM *vm) {
  if (vm->compiler->type == TYPE_SCRIPT) {
    error(vm, "Can't return from top-level code.");
  }

  if (match(vm, TOKEN_SEMICOLON)) {
    emitReturn(vm);
  } else {
    if (vm->compiler->type == TYPE_INITIALIZER) {
      error(vm, "Can't return a value from an initializer.");
    }
    parseExpression(vm);
    consume(vm, TOKEN_SEMICOLON, "Expect ';' after return value.");
    emitByte(vm, OP_RETURN);
  }
}

static u8 parseVariableDeclaration(VM *vm, const char *errorMessage) {
  consume(vm, TOKEN_IDENTIFIER, errorMessage);

  declareVariable(vm);
  if (vm->compiler->scopeDepth > 0)
    return 0;

  return identifierConstant(vm, &vm->parser->previous);
}

static void declareVariable(VM *vm) {
  if (vm->compiler->scopeDepth == 0)
    return;

  Token *name = &vm->parser->previous;
  for (int i = vm->compiler->localCount - 1; i >= 0; i--) {
    Local *local = &vm->compiler->locals[i];
    if (local->depth != -1 && local->depth < vm->compiler->scopeDepth) {
      break;
    }

    if (identifiersEqual(name, &local->name)) {
      error(vm, "Already a variable with this name in this scope.");
    }
  }

  addLocal(vm, *name);
}

static void defineVariable(VM *vm, u8 global) {
  if (vm->compiler->scopeDepth > 0) {
    markInitialized(vm);
    return;
  }

  emitBytes(vm, OP_DEFINE_GLOBAL, global);
}

static void varDeclaration(VM *vm) {
  u8 global = parseVariableDeclaration(vm, "Expect variable name.");

  if (match(vm, TOKEN_EQUAL)) {
    parseExpression(vm);
  } else {
    emitByte(vm, OP_NIL);
  }
  consume(vm, TOKEN_SEMICOLON, "Expect ';' after variable declaration.");

  defineVariable(vm, global);
}

static void declaration(VM *vm) {
  if (match(vm, TOKEN_CLASS)) {
    classDeclaration(vm);
  } else if (match(vm, TOKEN_FUN)) {
    funDeclaration(vm);
  } else if (match(vm, TOKEN_VAR)) {
    varDeclaration(vm);
  } else {
    statement(vm);
  }

  if (vm->parser->panicMode)
    synchronize(vm);
}

ObjFunction *compile(VM *vm) {
  Compiler compiler;
  initCompiler(vm, &compiler, TYPE_SCRIPT);

  advance(vm);
  while (!match(vm, TOKEN_EOF)) {
    declaration(vm);
  }
  ObjFunction *function = endCompiler(vm);
  return vm->parser->hadError ? NULL : function;
}
