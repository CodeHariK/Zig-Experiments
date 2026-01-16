#include "clox.h"
#include <string.h>

typedef struct {
  const char *source;
  const char *expected;
  bool expectError;
} TestCase;

static void replaceNewlinesWithSemicolons(char *str) {
  for (char *p = str; *p; p++) {
    if (*p == '\n') {
      *p = ';';
    }
  }
}

TestCase tests[] = {
    {"print 1 + 2 * 3;", "7;", false},
    {"print 1 == 2;", "false;", false},
    {"print 1 != 2;", "true;", false},
    {"print 1 > 2;", "false;", false},
    {"print 1 < 2;", "true;", false},
    {"print 1 >= 2;", "false;", false},
    {"print 1 <= 2;", "true;", false},
    {"!(5 - 4 > 3 * 2 == !nil);", "", false},
    {"print \"hello\" + \" \" + \"world\";", "hello world;", false},
    {"var hello = \"hello\"; var world = \"world\"; "
     "hello = hello + \" \" + world; print hello;",
     "hello world;", false},

    {"{ var a = 1; var a = 2; print a; }", "", true},
    {"var a = 1; { var a = 2; print a; } print a;", "2;1;", false},
    {"var a = 1; print (a = 2) + 3;", "5;", false},
    {"var a = 1; print a = 2 == 2;", "true;", false},
    {"var a = 1; { var a = 2; print a; } print a;", "2;1;", false},
    {"var a = 1; { a = 2; } print a;", "2;", false},
    {"var a = 1; { var a = 2; a = 3; } print a;", "1;", false},

    // If statements
    {"if (true) print 1;", "1;", false},
    {"if (false) print 1;", "", false},
    {"if (true) print 1; else print 2;", "1;", false},
    {"if (false) print 1; else print 2;", "2;", false},
    {"var a = 1; if (a == 1) { a = 2; } print a;", "2;", false},

    // Logical and
    {"print true and true;", "true;", false},
    {"print true and false;", "false;", false},
    {"print false and true;", "false;", false},
    {"print false and false;", "false;", false},
    {"print 1 and 2;", "2;", false},
    {"print nil and 2;", "nil;", false},

    // Logical or
    {"print true or true;", "true;", false},
    {"print true or false;", "true;", false},
    {"print false or true;", "true;", false},
    {"print false or false;", "false;", false},
    {"print nil or 2;", "2;", false},
    {"print 1 or 2;", "1;", false},

    // Combined
    {"print true and true or false;", "true;", false},
    {"print false or true and true;", "true;", false},

    // While loops
    {"var i = 0; while (i < 3) { print i; i = i + 1; }", "0;1;2;", false},
    {"var i = 0; while (i < 0) { print i; i = i + 1; }", "", false},

    // For loops
    {"for (var i = 0; i < 3; i = i + 1) print i;", "0;1;2;", false},
    {"var i = 0; for (; i < 3; i = i + 1) print i;", "0;1;2;", false},
    {"var i = 0; for (; i < 3;) { print i; i = i + 1; }", "0;1;2;", false},

    // Nested loops
    {"var sum = 0; for (var i = 0; i < 3; i = i + 1) { for (var j = 0; j < 2; "
     "j = j + 1) { sum = sum + 1; } } print sum;",
     "6;", false},

    // Functions - basic
    {"fun sayHi() { print 1; } sayHi();", "1;", false},
    {"fun add(a, b) { return a + b; } print add(1, 2);", "3;", false},
    {"fun fib(n) { if (n < 2) return n; return fib(n - 1) + fib(n - 2); } "
     "print fib(10);",
     "55;", false},

    // Functions - return
    {"fun noReturn() { } print noReturn();", "nil;", false},
    {"fun earlyReturn() { return 1; print 2; } print earlyReturn();", "1;",
     false},

    // Closures - basic upvalue capture
    {"fun outer() { var x = 1; fun inner() { return x; } return inner(); } "
     "print outer();",
     "1;", false},

    // Closures - closed upvalue
    {"fun outer() { var x = 1; fun inner() { return x; } var f = inner; x = 2; "
     "return f(); } print outer();",
     "2;", false},

    // Closures - upvalue in loop
    {"var f; for (var i = 0; i < 1; i = i + 1) { fun g() { return i; } f = g; "
     "} print f();",
     "1;", false},

    // Closures - nested
    {"fun outer() { var x = 1; fun middle() { fun inner() { return x; } "
     "return inner(); } return middle(); } print outer();",
     "1;", false},

    // Functions - recursion with locals
    {"fun count(n) { if (n > 0) { print n; count(n - 1); } } count(3);",
     "3;2;1;", false},

    // Native functions
    {"print clock() > 0;", "true;", false},

    // Error cases
    {"return 1;", "", true},            // Can't return from top-level
    {"fun foo() {} foo(1);", "", true}, // Wrong arity
};

int main(void) {
  printf("Running %zu test cases...\n\n", sizeof(tests) / sizeof(tests[0]));

  int passCount = 0;
  int failCount = 0;
  int passErrorCount = 0;

  for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
    TestCase *test = &tests[i];

    VM vm;
    vmInit(&vm);
    vmClearPrintBuffer(&vm);

    InterpretResult result = interpret(&vm, test->source);

    bool hadError = (result == INTERPRET_COMPILE_ERROR ||
                     result == INTERPRET_RUNTIME_ERROR);

    // Get actual output from print buffer
    char actualOutput[4096];
    strncpy(actualOutput, vmGetPrintBuffer(&vm), sizeof(actualOutput) - 1);
    actualOutput[sizeof(actualOutput) - 1] = '\0';
    replaceNewlinesWithSemicolons(actualOutput);

    // Process expected output
    char expectedOutput[4096];
    if (test->expected) {
      strncpy(expectedOutput, test->expected, sizeof(expectedOutput) - 1);
      expectedOutput[sizeof(expectedOutput) - 1] = '\0';
      replaceNewlinesWithSemicolons(expectedOutput);
    } else {
      expectedOutput[0] = '\0';
    }

    printf("TEST %zu: %s\n", i + 1, test->source);
    printf("[RESULT]: %s\n", actualOutput);

    bool passed = false;
    if (test->expectError) {
      if (hadError) {
        printf("[PassError]\n");
        passed = true;
        passErrorCount++;
      } else {
        printf("[FAIL] Expected error but got success\n");
        failCount++;
      }
    } else {
      if (hadError) {
        printf("[FAIL] Expected success but got error\n");
        failCount++;
      } else {
        if (test->expected && strlen(test->expected) > 0) {
          if (strcmp(actualOutput, expectedOutput) == 0) {
            printf("[PASS]\n");
            passed = true;
            passCount++;
          } else {
            printf("[FAIL] Expected: '%s', Got: '%s'\n", expectedOutput,
                   actualOutput);
            failCount++;
          }
        } else {
          printf("[PASS]\n");
          passed = true;
          passCount++;
        }
      }
    }
    printf("\n");

    vmFree(&vm);
    (void)passed; // Suppress unused warning
  }

  printf("Summary: %d passed, %d failed, %d passError\n", passCount, failCount,
         passErrorCount);

  return failCount > 0 ? 1 : 0;
}
