#ifndef CLOX_H
#define CLOX_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STACK_MAX 256

typedef uint32_t u32;
typedef int32_t i32;
typedef uint8_t u8;

typedef enum {
  VAL_BOOL,
  VAL_NIL,
  VAL_NUMBER,
} ValueType;

typedef struct {
  ValueType type;
  union {
    bool boolean;
    double number;
  } as;
} Value;

typedef struct {
  u32 count;
  u32 capacity;
  u32 elementSize;
  void *data;
} Array;

void arrayInit(Array *array, u32 elementSize);
void arrayWrite(Array *array, const void *element);
void arrayFree(Array *array);

typedef enum {
  OP_CONSTANT,

  // Literals
  OP_NIL,
  OP_TRUE,
  OP_FALSE,

  // Comparison operators
  OP_EQUAL,
  OP_NOT_EQUAL,
  OP_GREATER,
  OP_LESS,
  OP_GREATER_EQUAL,
  OP_LESS_EQUAL,

  // Binary operators
  OP_ADD,
  OP_SUBTRACT,
  OP_MULTIPLY,
  OP_DIVIDE,

  // Unary operators
  OP_NOT,
  OP_NEGATE,

  OP_RETURN,
} OpCode;

typedef struct {
  Array values;
} ValueArray;

void initValueArray(ValueArray *array);
void writeValueArray(ValueArray *array, Value value);
void freeValueArray(ValueArray *array);

typedef enum {
  INTERPRET_OK,
  INTERPRET_COMPILE_ERROR,
  INTERPRET_RUNTIME_ERROR
} InterpretResult;

typedef struct {
  Array code;
  Array lines;
  ValueArray constants;
} Chunk;

void chunkInit(Chunk *chunk);
void chunkWrite(Chunk *chunk, u8 byte, u32 line);
void chunkFree(Chunk *chunk);
void chunkDisassemble(Chunk *chunk, const char *name);
u32 instructionDisassemble(Chunk *chunk, u32 offset);
u32 addConstant(Chunk *chunk, Value value);

Value *getConstantArr(Chunk *chunk);
u8 *getCodeArr(Chunk *chunk);
u32 *getLineArr(Chunk *chunk);

typedef enum {
  // Single-character tokens.
  TOKEN_LEFT_PAREN,
  TOKEN_RIGHT_PAREN,
  TOKEN_LEFT_BRACE,
  TOKEN_RIGHT_BRACE,
  TOKEN_COMMA,
  TOKEN_DOT,
  TOKEN_MINUS,
  TOKEN_PLUS,
  TOKEN_SEMICOLON,
  TOKEN_SLASH,
  TOKEN_STAR,
  // One or two character tokens.
  TOKEN_NOT,
  TOKEN_NOT_EQUAL,
  TOKEN_EQUAL,
  TOKEN_EQUAL_EQUAL,
  TOKEN_GREATER,
  TOKEN_GREATER_EQUAL,
  TOKEN_LESS,
  TOKEN_LESS_EQUAL,
  // Literals.
  TOKEN_IDENTIFIER,
  TOKEN_STRING,
  TOKEN_NUMBER,
  // Keywords.
  TOKEN_AND,
  TOKEN_CLASS,
  TOKEN_ELSE,
  TOKEN_FALSE,
  TOKEN_FOR,
  TOKEN_FUN,
  TOKEN_IF,
  TOKEN_NIL,
  TOKEN_OR,
  TOKEN_PRINT,
  TOKEN_RETURN,
  TOKEN_SUPER,
  TOKEN_THIS,
  TOKEN_TRUE,
  TOKEN_VAR,
  TOKEN_WHILE,

  TOKEN_ERROR,
  TOKEN_EOF
} TokenType;

typedef struct {
  TokenType type;
  const char *start;
  u32 length;
  u32 line;
} Token;

typedef struct {
  const char *start;
  const char *current;
  u32 line;
} Scanner;

typedef struct {
  Token current;
  Token previous;
  bool hadError;
  bool panicMode;
} Parser;

typedef struct {
  Chunk *chunk;
  u8 *ip;

  Value stack[STACK_MAX];
  Value *stackTop;

  Parser *parser;
  Scanner *scanner;
} VM;

typedef enum {
  PREC_NONE,
  PREC_ASSIGNMENT, // =
  PREC_OR,         // or
  PREC_AND,        // and
  PREC_EQUALITY,   // == !=
  PREC_COMPARISON, // < > <= >=
  PREC_TERM,       // + -
  PREC_FACTOR,     // * /
  PREC_UNARY,      // ! -
  PREC_CALL,       // . ()
  PREC_PRIMARY
} Precedence;

typedef void (*ParseFn)(VM *vm);

typedef struct {
  ParseFn prefix;
  ParseFn infix;
  Precedence precedence;
} ParseRule;

void vmInit(VM *vm);
void vmFree(VM *vm);
InterpretResult interpret(VM *vm, const char *source);

void initScanner(Scanner *scanner, const char *source);
Token scanToken(Scanner *scanner);

bool compile(VM *vm);

void printValue(Value value);

extern Value NIL_VAL;
Value BOOL_VAL(bool value);
Value NUMBER_VAL(double value);
bool AS_BOOL(Value value);
double AS_NUMBER(Value value);
bool IS_BOOL(Value value);
bool IS_NIL(Value value);
bool IS_NUMBER(Value value);
bool VAL_EQUAL(Value a, Value b);

void traceExecution(VM *vm);

void debugTokenAdvance(Parser *parser, Token *newToken);
void debugParsePrecedence(Precedence minPrec, TokenType tokenType,
                          Precedence tokenPrec, bool isPrefix);
void debugRuleLookup(TokenType tokenType, ParseRule *rule);
void debugPrefixCall(TokenType tokenType);
void debugInfixCall(TokenType tokenType);
void debugPrecedenceCheck(Precedence minPrec, TokenType currentToken,
                          Precedence currentPrec, bool willContinue);
void debugEnterParsePrecedence(Precedence minPrec);
void debugExitParsePrecedence(Precedence minPrec);

#endif
