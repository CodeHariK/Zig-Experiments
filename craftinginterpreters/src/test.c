#include "lox.h"
#include <string.h>

typedef struct {
  const char *source;
  const char *expected;
  bool pass;
} TestCase;

void replaceNewlinesWithSemicolons(char *output) {
  if (!output)
    return;

  for (char *p = output; *p; p++) {
    if (*p == '\n') {
      *p = ';';
    }
  }
}

static void assertOutputTest(Lox *lox, const TestCase *test, char *output) {
  if (test->pass) {

    if (!(lox->hadError || lox->hadRuntimeError)) {

      if (test->expected && strlen(test->expected) > 0) {

        char actualBuf[1024];
        char expectedBuf[1024];

        strncpy(actualBuf, output, sizeof(actualBuf));
        actualBuf[sizeof(actualBuf) - 1] = '\0';

        strncpy(expectedBuf, test->expected, sizeof(expectedBuf));
        expectedBuf[sizeof(expectedBuf) - 1] = '\0';

        replaceNewlinesWithSemicolons(actualBuf);
        replaceNewlinesWithSemicolons(expectedBuf);

        if (strcmp(actualBuf, expectedBuf) == 0) {
          printf("[PASS] expected: %s\n", expectedBuf);
        } else {
          printf("[FAIL] got: %s, expected: %s\n", actualBuf, expectedBuf);
        }

      } else {
        printf("[INFO] no expected output\n");
      }
    } else {
      printf("[FAIL]\n");
    }
  } else {
    if (!(lox->hadError || lox->hadRuntimeError)) {
      printf("[FAIL] expected error\n");
    } else {
      printf("[PassError]\n");
    }
  }

  printf("\n");
}

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
      {"2 / 4", "0.5", true},
  };

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

    char buffer[64];
    valueToString(result, buffer, sizeof(buffer));

    assertOutputTest(&lox, &test, buffer);

    freeLox(&lox);
  }
}

// Run a single statement test
void runStmtTests(void) {
  TestCase stmtTests[] = {
      {"2 / 4", "0.5", false},
      {"print 1 + 2;", "3\n", true},
      {"1 + 2;", "", true}, // exprStmt, no print output
      {"print 2 * 3;", "6\n", true},
      {"print !false;", "true\n", true},
      {"print \"hello\";", "hello\n", true},
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

    executeStmt(&lox, stmt);

    assertOutputTest(&lox, &test, lox.output);

    freeLox(&lox);
  }
}

void runVarTests(void) {
  TestCase tests[] = {
      {"var a = 42; print a;", "42\n", true},
      {"var b = 3.14; print b;", "3.14\n", true},
      {"var s = \"hello\"; print s;", "hello\n", true},
      {"var x; print x;", "nil\n", true}, // uninitialized variable
      {"var y = true; print y;", "true\n", true},
      {"var c = 10; var d = 5; print c;", "10\n", true},
      {"var c = 10; c = 20; print c;", "20\n", true},
      {"var a = 1; print a = 2;", "2\n", true},

      {"print 1 = 2;", "", false}, // Invalid assignment

      // Empty block
      {"{}", "", true},

      // Chained assignment (right-associative)
      {"var a = 0; var b = 0; print a = b = 3;", "3\n", true},

      // Assignment inside expression
      {"var a = 1; print (a = 2) + 3;", "5\n", true},

      // Assignment precedence vs equality
      {"var a = 1; print a = 2 == 2;", "true\n", true},

      // Block creates a new scope
      {"{ var a = 1; print a; }", "1\n", true},

      // Outer variable still accessible inside block
      {"var a = 1; { print a; }", "1\n", true},

      // Block shadows outer variable
      {"var a = 1; { var a = 2; print a; } print a;", "2\n1\n", true},

      // Assignment affects nearest scope
      {"var a = 1; { a = 2; } print a;", "2\n", true},

      // Inner assignment does not affect outer shadowed variable
      {"var a = 1; { var a = 2; a = 3; } print a;", "1\n", true},

      {"if (true) print 1;", "1\n", true},
      {"if (false) {print 1;} else if (false) {print 2;} else {print 3;}",
       "3\n", true},
      {"var i = 0; while (i < 3) { print i; i = i + 1; }", "0\n1\n2\n", true},

      {"print \"hi\" or 2;", "hi\n", true},
      {"print nil or \"yes\";", "yes\n", true},
      {"print {false and 123};", "false\n", false},
      {"print (true and 123);", "123\n", true},
      {"print nil and boom;", "nil\n", true},
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
    executeProgram(&lox, prog);

    assertOutputTest(&lox, &test, lox.output);

    freeLox(&lox);
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
