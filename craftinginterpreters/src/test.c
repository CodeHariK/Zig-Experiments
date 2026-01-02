#include "lox.h"
#include "scanner.h"
#include "stmt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

bool DEBUG_PRINT = false;

typedef struct {
  const char *source;
  const char *expected;
} TestCase;

// Evaluate a single expression and return the Value
Value runExpression(Lox *lox, const char *source) {
  lox->hadRuntimeError = false;
  lox->hadError = false;

  initScanner(&lox->scanner, source);
  size_t count;
  Token *tokens = scanTokens(lox, &count);
  if (!tokens)
    printf("Failed to scan tokens for %s\n", source);

  lox->parser.tokens = tokens;
  lox->parser.count = count;
  lox->parser.current = 0;

  Expr *expr = parseExpression(lox);
  if (!expr)
    return nilValue();
  return evaluate(lox, expr);
}

static void runExprTests(void) {
  TestCase exprTests[] = {
      {"1 + 2 * 3", "7"},         {"(1 + 2) * 3", "9"},
      {"5 > 3", "true"},          {"5 < 3", "false"},
      {"nil == nil", "true"},     {"!false", "true"},
      {"(1 + 2) * 3", "9"},       {"5 > 3", "true"},
      {"5 < 3", "false"},         {"5 >= 5", "true"},
      {"5 <= 4", "false"},        {"true == false", "false"},
      {"true != false", "true"},  {"nil == nil", "true"},
      {"!false", "true"},         {"-(1 + 2)", "-3"},
      {"(1 + 2) * (3 - 1)", "6"}, {"2 / 4", "0.5"}};

  for (size_t i = 0; i < sizeof(exprTests) / sizeof(exprTests[0]); i++) {

    TestCase test = exprTests[i];

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);

    Value result = runExpression(&lox, test.source);
    char buffer[64];
    valueToString(result, buffer, sizeof(buffer));

    if (strcmp(buffer, test.expected) == 0) {
      printf("[PASS] %s => %s\n", test.source, buffer);
    } else {
      printf("[FAIL] %s => %s (expected %s)\n", test.source, buffer,
             test.expected);
    }
  }
}

void runScannerTests(void) {
  const char *sources[] = {"()",
                           "{}",
                           "1 + 2 * 3",
                           "!true == false",
                           "123.45",
                           "nil",
                           "var x = 10;",
                           "print 1 + 2;",
                           "// comment\n123",
                           "\"hello world\""};

  for (size_t i = 0; i < sizeof(sources) / sizeof(sources[0]); i++) {
    const char *source = sources[i];

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);
    initScanner(&lox.scanner, source);

    size_t count;
    Token *tokens = scanTokens(&lox, &count);

    printf("SOURCE:\n%s\n", source);
    for (size_t i = 0; i < count; i++) {
      Token t = tokens[i];
      printf("  %-15s '%.*s'\n", tokenTypeToString(t.type), t.length, t.lexeme);
    }
    printf("\n");
  }
}

void testParser(void) {
  Lox lox;
  loxInit(&lox, DEBUG_PRINT);

  const char *parserTests[] = {
      "1 + 2 * 3",
      "(1 + 2) * 3",
      "!true == false",
      "nil",
  };

  for (size_t i = 0; i < sizeof(parserTests) / sizeof(parserTests[0]); i++) {
    printf("SOURCE: %s\n", parserTests[i]);

    initScanner(&lox.scanner, parserTests[i]);
    size_t count;
    Token *tokens = scanTokens(&lox, &count);

    lox.parser.tokens = tokens;
    lox.parser.count = count;
    lox.parser.current = 0;

    Expr *expr = parseExpression(&lox);
    printExpr(expr);
    printf("\n\n");
  }
}

// Run a single statement test
void runStmtTests(void) {
  TestCase stmtTests[] = {
      {"print 1 + 2;", "3"},
      {"1 + 2;", ""}, // exprStmt, no print output
      {"print 2 * 3;", "6"},
      {"print !false;", "true"},
      {"print \"hello\";", "hello"},
  };

  for (size_t i = 0; i < sizeof(stmtTests) / sizeof(stmtTests[0]); i++) {
    TestCase test = stmtTests[i];

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);

    initScanner(&lox.scanner, test.source);
    size_t count;
    Token *tokens = scanTokens(&lox, &count);

    lox.parser.tokens = tokens;
    lox.parser.count = count;
    lox.parser.current = 0;

    Stmt *stmt = parseStmt(&lox);
    printf("SOURCE: %s\n", test.source);
    printStmt(stmt);

    char buffer[64] = "";
    executeStmt(&lox, stmt, buffer, sizeof(buffer));

    if (test.expected && strlen(test.expected) > 0) {
      if (strcmp(buffer, test.expected) == 0) {
        printf("[PASS] expected: %s\n\n", test.expected);
      } else {
        printf("[FAIL] got: %s, expected: %s\n\n", buffer, test.expected);
      }
    } else {
      printf("[INFO] no expected output\n\n");
    }
  }
}

void runVarTests(void) {
  TestCase tests[] = {
      {"var a = 42; print a;", "42"},
      {"var b = 3.14; print b;", "3.14"},
      {"var s = \"hello\"; print s;", "hello"},
      {"var x; print x;", "nil"}, // uninitialized variable
      {"var y = true; print y;", "true"},
      // Using previously declared variable
      {"var c = 10; var d = 5; print c;", "10"},
  };

  for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {

    TestCase test = tests[i];

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);

    initScanner(&lox.scanner, test.source);
    size_t count;
    Token *tokens = scanTokens(&lox, &count);

    lox.parser.tokens = tokens;
    lox.parser.count = count;
    lox.parser.current = 0;

    Program *prog = parseProgram(&lox);

    char buffer[128] = "";

    for (size_t i = 0; i < prog->count; i++) {
      executeStmt(&lox, prog->statements[i], buffer, sizeof(buffer));
    }

    if (test.expected) {
      if (strcmp(buffer, test.expected) == 0) {
        printf("[PASS] %s => %s\n", test.source, buffer);
      } else {
        printf("[FAIL] %s => %s (expected %s)\n", test.source, buffer,
               test.expected);
      }
    }

    for (size_t i = 0; i < prog->count; i++)
      freeStmt(prog->statements[i]);
    free(prog->statements);
    free(prog);
    loxFree(&lox);
  }
}

int main(void) {

  runScannerTests();

  testParser();

  runExprTests();

  runStmtTests();

  runVarTests();
}
