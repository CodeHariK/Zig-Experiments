#ifndef CLOX_H
#define CLOX_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FRAMES_MAX 64
#define STACK_MAX (FRAMES_MAX * UINT8_COUNT)
#define UINT8_COUNT (UINT8_MAX + 1)

typedef uint32_t u32;
typedef int32_t i32;
typedef uint16_t u16;
typedef uint8_t u8;

// Forward declarations
typedef struct Obj Obj;
typedef struct ObjString ObjString;
typedef struct ObjFunction ObjFunction;
typedef struct ObjClosure ObjClosure;
typedef struct ObjUpvalue ObjUpvalue;
typedef struct ObjClass ObjClass;
typedef struct ObjInstance ObjInstance;
typedef struct ObjBoundMethod ObjBoundMethod;

typedef enum {
  VAL_BOOL,
  VAL_NIL,
  VAL_NUMBER,
  VAL_OBJ,
} ValueType;

typedef struct {
  ValueType type;
  union {
    bool boolean;
    double number;
    Obj *obj;
  } as;
} Value;

typedef struct {
  size_t count;
  size_t capacity;
  size_t elementSize;
  void *data;
} Array;

void arrayInit(Array *array, size_t elementSize);
void arrayWrite(Array *array, const void *element);
void arrayFree(Array *array);

typedef struct {
  Array values;
} ValueArray;

void initValueArray(ValueArray *array);
void writeValueArray(ValueArray *array, Value value);
void freeValueArray(ValueArray *array);

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

  OP_POP,
  OP_PRINT,

  OP_GET_GLOBAL,
  OP_SET_GLOBAL,
  OP_DEFINE_GLOBAL,
  OP_GET_LOCAL,
  OP_SET_LOCAL,
  OP_GET_UPVALUE,
  OP_SET_UPVALUE,

  OP_JUMP,
  OP_JUMP_IF_FALSE,
  OP_LOOP,

  OP_CALL,
  OP_CLOSURE,
  OP_CLOSE_UPVALUE,

  OP_CLASS,
  OP_GET_PROPERTY,
  OP_SET_PROPERTY,
  OP_METHOD,
  OP_INVOKE,
  OP_INHERIT,
  OP_GET_SUPER,
  OP_SUPER_INVOKE,

  OP_RETURN,
} OpCode;

typedef struct {
  Array code;
  Array lines;
  ValueArray constants;
} Chunk;

typedef enum {
  OBJ_BOUND_METHOD,
  OBJ_CLASS,
  OBJ_CLOSURE,
  OBJ_FUNCTION,
  OBJ_INSTANCE,
  OBJ_NATIVE,
  OBJ_STRING,
  OBJ_UPVALUE,
} ObjType;

struct Obj {
  ObjType type;
  bool isMarked;
  struct Obj *next;
};

struct ObjFunction {
  Obj obj;
  int arity;
  int upvalueCount;
  Chunk chunk;
  ObjString *name;
};

struct ObjUpvalue {
  Obj obj;
  Value *location;
  Value closed;
  struct ObjUpvalue *next;
};

struct ObjClosure {
  Obj obj;
  ObjFunction *function;
  ObjUpvalue **upvalues;
  int upvalueCount;
};

typedef Value (*NativeFn)(int argCount, Value *args);

typedef struct {
  Obj obj;
  NativeFn function;
} ObjNative;

struct ObjString {
  Obj obj;
  i32 length;
  char *chars;
  u32 hash;
};

typedef struct {
  ObjString *key;
  Value value;
} Entry;

typedef struct {
  i32 count;
  i32 capacity;
  Entry *entries;
} Table;

struct ObjClass {
  Obj obj;
  ObjString *name;
  Table methods;
};

struct ObjBoundMethod {
  Obj obj;
  Value receiver;
  ObjClosure *method;
};

struct ObjInstance {
  Obj obj;
  ObjClass *klass;
  Table fields;
};

#define ARRAY_MAX_LOAD 0.75

void initTable(Table *table);
void freeTable(Table *table);
bool tableGet(Table *table, ObjString *key, Value *value);
bool tableSet(Table *table, ObjString *key, Value value);
bool tableDelete(Table *table, ObjString *key);
void tableAddAll(Table *from, Table *to);
ObjString *tableFindString(Table *table, const char *chars, i32 length,
                           u32 hash);

typedef enum {
  INTERPRET_OK,
  INTERPRET_COMPILE_ERROR,
  INTERPRET_RUNTIME_ERROR
} InterpretResult;

// Forward declaration for addConstant
typedef struct VM VM;

void chunkInit(Chunk *chunk);
void chunkWrite(Chunk *chunk, u8 byte, u32 line);
void chunkFree(Chunk *chunk);
void chunkDisassemble(Chunk *chunk, const char *name);
size_t instructionDisassemble(Chunk *chunk, size_t offset);
size_t addConstant(VM *vm, Chunk *chunk, Value value);

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
  size_t length;
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
  Token name;
  i32 depth;
  bool isCaptured;
} Local;

typedef struct {
  u8 index;
  bool isLocal;
} Upvalue;

typedef enum {
  TYPE_FUNCTION,
  TYPE_INITIALIZER,
  TYPE_METHOD,
  TYPE_SCRIPT
} FunctionType;

typedef struct ClassCompiler {
  struct ClassCompiler *enclosing;
  bool hasSuperclass;
} ClassCompiler;

typedef struct Compiler {
  struct Compiler *enclosing;
  ObjFunction *function;
  FunctionType type;

  Local locals[UINT8_COUNT];
  i32 localCount;
  Upvalue upvalues[UINT8_COUNT];
  i32 scopeDepth;
} Compiler;

typedef struct {
  ObjClosure *closure;
  u8 *ip;
  Value *slots;
} CallFrame;

struct VM {
  CallFrame frames[FRAMES_MAX];
  int frameCount;

  Value stack[STACK_MAX];
  Value *stackTop;

  Table globals;
  Table strings;
  ObjString *initString;
  ObjUpvalue *openUpvalues;

  size_t bytesAllocated;
  size_t nextGC;
  Obj *objects;
  int grayCount;
  int grayCapacity;
  Obj **grayStack;

  Parser *parser;
  Scanner *scanner;
  Compiler *compiler;
  ClassCompiler *currentClass;

  // Print output buffer for testing
  char printBuffer[4096];
  size_t printBufferLen;

  // Error buffer for testing
  char errorBuffer[4096];
  size_t errorBufferLen;
};

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

typedef void (*ParseFn)(VM *vm, bool canAssign);

typedef struct {
  ParseFn prefix;
  ParseFn infix;
  Precedence precedence;
} ParseRule;

void vmInit(VM *vm);
void vmFree(VM *vm);
Value pop(VM *vm);
void push(VM *vm, Value value);
InterpretResult interpret(VM *vm, const char *source);

void initScanner(Scanner *scanner, const char *source);
Token scanToken(Scanner *scanner);

ObjFunction *compile(VM *vm);

ObjString *copyString(VM *vm, const char *chars, i32 length);
ObjString *allocateString(VM *vm, char *chars, i32 length, u32 hash);
ObjString *takeString(VM *vm, char *chars, i32 length);
void concatenate(VM *vm);

void printValue(Value value);
void printValueToBuffer(VM *vm, Value value);
const char *vmGetPrintBuffer(VM *vm);
void vmClearPrintBuffer(VM *vm);
const char *vmGetErrorBuffer(VM *vm);
void vmClearErrorBuffer(VM *vm);

extern Value NIL_VAL;

bool VAL_EQUAL(Value a, Value b);

// Value constructors and accessors
Value BOOL_VAL(bool value);
Value NUMBER_VAL(double value);
bool AS_BOOL(Value value);
double AS_NUMBER(Value value);
bool IS_BOOL(Value value);
bool IS_NIL(Value value);
bool IS_NUMBER(Value value);
Value OBJ_VAL(Obj *obj);
bool IS_OBJ(Value value);
Obj *AS_OBJ(Value value);
ObjType OBJ_TYPE(Value value);
bool IS_OBJ_TYPE(Value value, ObjType type);
bool IS_STRING(Value value);
ObjString *AS_STRING(Value value);
char *AS_CSTRING(Value value);
bool isFalsey(Value value);

bool IS_FUNCTION(Value value);
ObjFunction *AS_FUNCTION(Value value);
bool IS_NATIVE(Value value);
NativeFn AS_NATIVE(Value value);
bool IS_CLOSURE(Value value);
ObjClosure *AS_CLOSURE(Value value);
bool IS_CLASS(Value value);
ObjClass *AS_CLASS(Value value);
bool IS_INSTANCE(Value value);
ObjInstance *AS_INSTANCE(Value value);
bool IS_BOUND_METHOD(Value value);
ObjBoundMethod *AS_BOUND_METHOD(Value value);

ObjFunction *newFunction(VM *vm);
ObjNative *newNative(VM *vm, NativeFn function);
ObjClosure *newClosure(VM *vm, ObjFunction *function);
ObjUpvalue *newUpvalue(VM *vm, Value *slot);
ObjClass *newClass(VM *vm, ObjString *name);
ObjInstance *newInstance(VM *vm, ObjClass *klass);
ObjBoundMethod *newBoundMethod(VM *vm, Value receiver, ObjClosure *method);

void freeObjects(VM *vm);
void collectGarbage(VM *vm);
void markValue(VM *vm, Value value);
void markObject(VM *vm, Obj *object);
void markTable(VM *vm, Table *table);
void tableRemoveWhite(Table *table);

#define GC_HEAP_GROW_FACTOR 2

// Memory management - regular functions (implemented in helper.c)
void *reallocate(VM *vm, void *pointer, size_t oldSize, size_t newSize);
void *allocateType(size_t count, size_t elementSize);
void freeType(void *pointer, size_t size);
void freeTypeArray(void *pointer, size_t count, size_t elementSize);

// Memory management - wrappers
void *allocate(size_t size);
void freePtr(void *pointer);

// Memory allocation helpers
void *ALLOCATE(size_t count, size_t elementSize);
void *ALLOCATE_OBJ(VM *vm, size_t size, ObjType type);
void FREE(size_t size, void *pointer);
void FREE_ARRAY(size_t count, size_t elementSize, void *pointer);

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
