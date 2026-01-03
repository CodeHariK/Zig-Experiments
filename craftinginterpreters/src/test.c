#include "lox.h"
#include <string.h>

typedef struct {
  const char *source;
  const char *expected;
  bool pass;
} TestCase;

static void runExprTests(void) {
  TestCase exprTests[] = {

      {"()", NULL, false},
      {"{}", NULL, false},
      {"!true == false", "true", true},
      {"123.45", "123.45", true},
      {"nil", "nil", true},
      {"var x = 10;", NULL, false},
      {"print 1 + 2;", NULL, false},
      {"// comment\n123", "123", true},
      {"\"hello world\"", "hello world", true},
      {"!-!-3", "0", false},
      {"1 + 2 * 3", "7", true},
      {"(1 + 2) * 3", "9", true},
      {"5 > 3", "true", true},
      {"5 < 3", "false", true},
      {"nil == nil", "true", true},
      {"!false", "true", true},
      {"5 > 3", "true", true},
      {"5 < 3", "false", true},
      {"5 >= 5", "true", true},
      {"5 <= 4", "false", true},
      {"true == false", "false", true},
      {"true != false", "true", true},
      {"nil == nil", "true", true},
      {"!false", "true", true},
      {"-(1 + 2)", "-3", true},
      {"(1 + 2) * (3 - 1)", "6", true},
      {"2 / 4", "0.5", true}};

  for (size_t i = 0; i < sizeof(exprTests) / sizeof(exprTests[0]); i++) {

    TestCase test = exprTests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, true);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    Expr *expr = parseExpression(&lox);
    Value result = evaluate(&lox, expr);

    if (test.pass && !(lox.hadError || lox.hadRuntimeError)) {
      char buffer[64];
      valueToString(result, buffer, sizeof(buffer));
      if (strcmp(buffer, test.expected) == 0) {
        printf("[PASS] %s => %s\n", test.source, buffer);
      } else {
        printf("[FAIL] %s => %s (expected %s)\n", test.source, buffer,
               test.expected);
      }
    } else {
      printf("[PASSError]\n");
    }

    printError(&lox);
  }
}

// Run a single statement test
void runStmtTests(void) {
  TestCase stmtTests[] = {
      {"2 / 4", "0.5", false},
      {"print 1 + 2;", "3", true},
      {"1 + 2;", "", true}, // exprStmt, no print output
      {"print 2 * 3;", "6", true},
      {"print !false;", "true", true},
      {"print \"hello\";", "hello", true},
  };

  for (size_t i = 0; i < sizeof(stmtTests) / sizeof(stmtTests[0]); i++) {
    TestCase test = stmtTests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, true);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    Stmt *stmt = parseStmt(&lox);

    char buffer[64] = "";
    executeStmt(&lox, stmt, buffer, sizeof(buffer));

    if (test.pass && !(lox.hadError || lox.hadRuntimeError)) {
      if (test.expected && strlen(test.expected) > 0) {
        if (strcmp(buffer, test.expected) == 0) {
          printf("[PASS] expected: %s\n\n", test.expected);
        } else {
          printf("[FAIL] got: %s, expected: %s\n\n", buffer, test.expected);
        }
      } else {
        printf("[INFO] no expected output\n\n");
      }
    } else {
      printf("[PASSError]\n");
    }

    printError(&lox);
  }
}

void runVarTests(void) {
  TestCase tests[] = {
      {"var a = 42; print a;", "42", true},
      {"var b = 3.14; print b;", "3.14", true},
      {"var s = \"hello\"; print s;", "hello", true},
      {"var x; print x;", "nil", true}, // uninitialized variable
      {"var y = true; print y;", "true", true},
      {"var c = 10; var d = 5; print c;", "10", true},
      {"var c = 10; c = 20; print c;", "20", true},
  };

  for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {

    TestCase test = tests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, true);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    Program *prog = parseProgram(&lox);

    printProgram(&lox, prog);

    char buffer[128] = "";
    executeProgram(&lox, prog, buffer, sizeof(buffer));

    if (test.expected) {
      if (strcmp(buffer, test.expected) == 0) {
        printf("[PASS] %s => %s\n", test.source, buffer);
      } else {
        printf("[FAIL] %s => %s (expected %s)\n", test.source, buffer,
               test.expected);
      }
    }

    freeLox(&lox);

    printf("\n");
  }
}

int main(void) {

  printf("====== Expression Tests ======\n");
  runExprTests();

  printf("====== Statement Tests ======\n");
  runStmtTests();

  printf("====== Variable Tests ======\n");
  runVarTests();
}
