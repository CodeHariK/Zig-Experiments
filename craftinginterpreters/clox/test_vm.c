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

    // Classes and instances
    {"class Foo {} print Foo;", "Foo\n", false},
    {"class Foo {} var foo = Foo(); print foo;", "Foo instance\n", false},
    {"class Foo {} var foo = Foo(); foo.bar = 42; print foo.bar;", "42\n",
     false},
    {"class Foo {} var foo = Foo(); foo.x = 1; foo.y = 2; print foo.x + foo.y;",
     "3\n", false},
    {"class Foo {} var foo = Foo(); foo.bar = \"baz\"; print foo.bar;", "baz\n",
     false},

    // Methods
    {"class Bacon { eat() { print \"Crunch\"; } } Bacon().eat();", "Crunch\n",
     false},
    {"class Bacon { eat() { print \"Crunch\"; } } var b = Bacon(); b.eat();",
     "Crunch\n", false},

    // this keyword
    {"class Person { sayName() { print this.name; } } var p = Person(); "
     "p.name = \"Bob\"; p.sayName();",
     "Bob\n", false},
    {"class Nested { method() { fun f() { print this.field; } f(); } } "
     "var n = Nested(); n.field = 42; n.method();",
     "42\n", false},

    // Initializer
    {"class Circle { init(r) { this.radius = r; } } var c = Circle(3); "
     "print c.radius;",
     "3\n", false},
    {"class Foo { init() { this.x = 1; } } var f = Foo(); print f.x;", "1\n",
     false},
    {"class Foo { init() { return; } } var f = Foo(); print f;",
     "Foo instance\n", false},

    // Method returning this
    {"class Builder { setX(x) { this.x = x; return this; } "
     "setY(y) { this.y = y; return this; } } "
     "var b = Builder().setX(1).setY(2); print b.x + b.y;",
     "3\n", false},

    // OP_INVOKE optimization
    {"class Scone { topping(first, second) { "
     "print \"scone with \" + first + \" and \" + second; } } "
     "var s = Scone(); s.topping(\"berries\", \"cream\");",
     "scone with berries and cream\n", false},

    // Bound method
    {"class Foo { method() { print this.x; } } var foo = Foo(); foo.x = 123; "
     "var m = foo.method; m();",
     "123\n", false},

    // Error: 'this' outside class
    {"fun notMethod() { print this; }", "", true},

    // Error: return value from init
    {"class Foo { init() { return 123; } }", "", true},

    // Error: calling class with wrong args
    {"class Foo { init(a, b) {} } Foo(1);", "", true},

    // Inheritance - basic
    {"class A { method() { print \"A\"; } } "
     "class B < A {} "
     "B().method();",
     "A\n", false},

    // Inheritance - override
    {"class A { method() { print \"A\"; } } "
     "class B < A { method() { print \"B\"; } } "
     "B().method();",
     "B\n", false},

    // Inheritance - super call
    {"class A { method() { print \"A\"; } } "
     "class B < A { method() { super.method(); print \"B\"; } } "
     "B().method();",
     "A\nB\n", false},

    // Inheritance - super in init
    {"class A { init(x) { this.x = x; } } "
     "class B < A { init(x, y) { super.init(x); this.y = y; } } "
     "var b = B(1, 2); print b.x + b.y;",
     "3\n", false},

    // Inheritance - deep chain
    {"class A { foo() { return \"A\"; } } "
     "class B < A {} "
     "class C < B {} "
     "print C().foo();",
     "A\n", false},

    // Inheritance - super invoke optimization
    {"class A { method(x) { return x * 2; } } "
     "class B < A { method(x) { return super.method(x) + 1; } } "
     "print B().method(5);",
     "11\n", false},

    // Error: inherit from non-class
    {"var NotAClass = \"string\"; class Foo < NotAClass {}", "", true},

    // Error: inherit from self
    {"class Foo < Foo {}", "", true},

    // Error: super outside class
    {"super.method();", "", true},

    // Error: super without superclass
    {"class Foo { bar() { super.bar(); } }", "", true},
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
    vmClearErrorBuffer(&vm);

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
        const char *errorMsg = vmGetErrorBuffer(&vm);
        if (errorMsg && strlen(errorMsg) > 0) {
          printf("[PassError] %s", errorMsg);
        } else {
          printf("[PassError]\n");
        }
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
