#include "lox.h"
#include <string.h>

const bool DEBUG_PRINT = true;

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

  char actualBuf[1024];
  strncpy(actualBuf, output, sizeof(actualBuf));
  replaceNewlinesWithSemicolons(actualBuf);
  printf("[RESULT] : %s\n", actualBuf);

  if (test->pass) {

    if (!(lox->hadError || lox->hadRuntimeError)) {

      if (test->expected && strlen(test->expected) > 0) {

        char expectedBuf[1024];

        actualBuf[sizeof(actualBuf) - 1] = '\0';

        strncpy(expectedBuf, test->expected, sizeof(expectedBuf));
        expectedBuf[sizeof(expectedBuf) - 1] = '\0';

        replaceNewlinesWithSemicolons(expectedBuf);

        if (strcmp(actualBuf, expectedBuf) == 0) {
          printf("[PASS]\n");
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
      {"!true", "false", true},
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

  for (u32 i = 0; i < sizeof(exprTests) / sizeof(exprTests[0]); i++) {

    TestCase test = exprTests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    printf("=================\n");
    Expr *expr = parseExpression(&lox);
    printf("=================\n");
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
      {"print !false;", "true\n", true},
      {"print \"hello\";", "hello\n", true},
  };

  for (u32 i = 0; i < sizeof(stmtTests) / sizeof(stmtTests[0]); i++) {
    TestCase test = stmtTests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    printf("=================\n");
    Stmt *stmt = parseStmt(&lox);
    printf("=================\n");

    executeStmt(&lox, stmt);

    assertOutputTest(&lox, &test, lox.output);

    freeLox(&lox);
  }
}

void runVarTests(void) {
  TestCase tests[] = {
      {"var a = 7 * 7; print a/7;", "7\n", true},
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

      {"if (false) {print 1;} else if (false) {print 2;} else {print 3;}",
       "3\n", true},
      {"var i = 0; while (i < 3) { print i; i = i + 1; }", "0\n1\n2\n", true},

      {"print \"hi\" or 2;", "hi\n", true},
      {"print nil or \"yes\";", "yes\n", true},
      {"print {false and 123};", "false\n", false},
      {"print (true and 123);", "123\n", true},
      {"print nil and boom;", "nil\n", true},

      // basic counting
      {"for (var i = 0; i < 3; i = i + 1) {print i;}", "0;1;2;", true},
      // initializer without var
      {"var i = 0; for (i = 1; i < 4; i = i + 1) {print i;}", "1;2;3;", true},
      // empty initializer
      {"var i = 0; for (; i < 3; i = i + 1) {print i;}", "0;1;2;", true},
      // empty increment
      {"for (var i = 0; i < 3;) { print i; i = i + 1; }", "0;1;2;", true},

      // block scoping
      {"var i = 100; for (var i = 0; i < 2; i = i + 1) {print i;} print i;",
       "0;1;100;", true},
      // nested for
      {"for (var i = 0; i < 2; i = i + 1) {"
       "for (var j = 0; j < 2; j = j + 1) "
       "{print i + j;}}",
       "0;1;1;2;", true},
      // for with expression body
      {"for (var i = 0; i < 3; i = i + 1) i = i + 10; print i;", "13;", false},
      // for inside block
      {"{ for (var i = 0; i < 2; i = i + 1) {print i;} }", "0;1;", true},

      // empty condition (infinite loop with break simulation)
      {"var i = 0; for (;;){ print i; i = i + 1; if (i == 3) {break;} }",
       "0;1;2;", true},
      // break exits only the nearest loop
      {"var i = 0; var j = 0; "
       "while (i < 2) { "
       "  j = 0; "
       "  while (true) { "
       "    print i; "
       "    break; "
       "  } "
       "  i = i + 1; "
       "} ",
       "0;1;", true},

      // break inside nested blocks and if
      {"var i = 0; "
       "while (true) { "
       "  { "
       "    if (i == 2) {break;} "
       "  } "
       "  print i; "
       "  i = i + 1; "
       "} ",
       "0;1;", true},

      {"var i = 0; while (i < 3) { "
       "{ i = i + 1; if (i == 2) {continue;} print i; } }",
       "1;3;", true},
      {"for (var i = 1; i < 4; i = i + 1) { "
       "if (i == 2) {continue;} print i; }",
       "1;3;", true},

      {"fun hello() { print 123; } hello();", "123;", true},
      {"fun add(a, b) { print a + b; } add(2, 3);", "5;", true},
      {"fun outer() { var x = 10; fun inner() { print x; } inner(); } outer();",
       "10;", true},

      {"fun f() { return 123; print 0; } print f();", "123;", true},
      {"fun f() {} print f();", "nil;", true},
      {"fun f() { if (true) {return 1;} return 2; } print f();", "1;", true},
      {"fun fact(n) { if (n <= 1) {return 1;} return n * fact(n - 1); } print "
       "fact(5);",
       "120;", true},

      {"fun makeCounter() { var i = 0; fun count() { i = i + 1; return i; } "
       "return count; } var c = makeCounter(); print c(); print c();",
       "1;2;", true},

      {"print clock();", "", true},

      {"var a = 8; { fun show() { print a;  } var a = 5;  show(); }", "8\n",
       true},

      {"var a = a;", "", false},
      {"return 123;", "", false},
      {"break;", "", false},

      {"class Foo {} print Foo;", "<class Foo>;", true},
      {"class Foo {} var f = Foo(); print f;", "<instance Foo>;", true},
      {"class Foo { get() { return 123; } } print Foo().get();", "123;", true},
      {"class Foo { init(x){ this.x = x; } get(){ return this.x; } } "
       "var f = Foo(42); print f.get();",
       "42;", true},
      {"class Foo { init() { return 123; } } print Foo();", "<instance Foo>;",
       false},
      {"fun init() { return 123; } print init();", "123;", true},
      {"class Foo { init(x){ this.x = x; } inc(){ this.x = this.x + 1; return "
       "this.x; } } print "
       "Foo(42).inc();",
       "43;", true},
  };

  for (u32 i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {

    TestCase test = tests[i];

    printf("SOURCE: %s\n", test.source);

    Lox lox;
    loxInit(&lox, DEBUG_PRINT);
    initScanner(&lox.scanner, test.source);
    scanTokens(&lox);
    initParser(&lox);

    printf("=================\n");
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
