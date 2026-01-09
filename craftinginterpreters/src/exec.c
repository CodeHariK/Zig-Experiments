#include "lox.h"
#include <string.h>

static void executeBlock(Lox *lox, Stmt **stmts, int count) {
  Environment *previous = lox->env;
  lox->env = envNew(previous);

  for (int i = 0; i < count; i++) {
    executeStmt(lox, stmts[i]);

    if (lox->signal.type != SIGNAL_NONE)
      break;
  }

  lox->env = previous;
}

void executeStmt(Lox *lox, Stmt *stmt) {

  if (!stmt)
    return;

  indentPrint(lox->execDepth);
  lox->execDepth++;

  switch (stmt->type) {
  case STMT_PRINT: {
    if (!stmt->as.expr_print) {
      runtimeErrorAt(lox, 0, "Null expression in print statement.");
      return;
    }
    Value result = evaluate(lox, stmt->as.expr_print);

    char buf[64];
    valueToString(result, buf, sizeof(buf));

    loxAppendOutput(lox, buf);
    loxAppendOutput(lox, "\n");

    printStmt(lox, stmt, result, 0);
    break;
  }

  case STMT_EXPR: {
    if (stmt->as.expr) {
      Value val = evaluate(lox, stmt->as.expr);
      printStmt(lox, stmt, val, 0);
    }
    break;
  }

  case STMT_VAR: {
    Value val = NIL_VALUE;
    if (stmt->as.var.initializer) {
      val = evaluate(lox, stmt->as.var.initializer);
    }
    envDefine(lox->env, lox, stmt->as.var.name.lexeme, val);

    printStmt(lox, stmt, val, 0);

    break;
  }

  case STMT_BLOCK:
    executeBlock(lox, stmt->as.block.statements, stmt->as.block.count);
    break;

  case STMT_IF: {
    printf("IF\n");
    if (isTruthy(evaluate(lox, stmt->as.ifStmt.condition))) {
      executeStmt(lox, stmt->as.ifStmt.then_branch);
    } else if (stmt->as.ifStmt.else_branch) {
      executeStmt(lox, stmt->as.ifStmt.else_branch);
    }

    if (lox->signal.type == SIGNAL_BREAK) {
      return;
    }

    break;
  }

  case STMT_WHILE: {
    printf("WHILE\n");

    while (!lox->hadRuntimeError && !lox->hadError &&
           isTruthy(evaluate(lox, stmt->as.whileStmt.condition))) {

      executeStmt(lox, stmt->as.whileStmt.body);

      if (lox->signal.type == SIGNAL_BREAK) {
        lox->signal.type = SIGNAL_NONE;
        break;
      }

      if (lox->signal.type == SIGNAL_CONTINUE) {
        lox->signal.type = SIGNAL_NONE;
        // continue;
      }
    }
    break;
  }

  case STMT_FOR: {
    printf("FOR\n");

    while (!lox->hadRuntimeError && !lox->hadError) {
      if (stmt->as.forStmt.condition &&
          !isTruthy(evaluate(lox, stmt->as.forStmt.condition))) {
        break;
      }

      executeStmt(lox, stmt->as.forStmt.body);

      if (lox->signal.type == SIGNAL_BREAK) {
        lox->signal.type = SIGNAL_NONE;
        break;
      }

      if (lox->signal.type == SIGNAL_CONTINUE) {
        lox->signal.type = SIGNAL_NONE;
        // fall through to increment
      }

      if (stmt->as.forStmt.increment) {
        evaluate(lox, stmt->as.forStmt.increment);
      }
    }
    break;
  }

  case STMT_FUNCTION: {
    Value fnValue = makeFunction(lox, stmt, false);
    envDefine(lox->env, lox, fnValue.as.function->name.lexeme, fnValue);

    break;
  }

  case STMT_CLASS: {
    printf("Class %s\n", stmt->as.classStmt.name.lexeme);

    LoxClass *klass = arenaAlloc(&lox->astArena, sizeof(LoxClass));
    klass->name = stmt->as.classStmt.name;
    klass->methods = envNew(NULL);

    for (int i = 0; i < stmt->as.classStmt.methodCount; i++) {
      Stmt *method = stmt->as.classStmt.methods[i];

      Value fnValue = makeFunction(lox, method, true);
      envDefine(klass->methods, lox, fnValue.as.function->name.lexeme, fnValue);
    }

    Value classValue;
    classValue.type = VAL_CLASS;
    classValue.as.klass = klass;

    envDefine(lox->env, lox, klass->name.lexeme, classValue);

    break;
  }

  case STMT_BREAK: {
    lox->signal.type = SIGNAL_BREAK;
    printf("BREAK\n");
    break;
  }
  case STMT_CONTINUE: {
    lox->signal.type = SIGNAL_CONTINUE;
    printf("CONTINUE\n");
    break;
  }
  case STMT_RETURN: {
    Value value = NIL_VALUE;

    if (stmt->as.returnStmt.value) {
      value = evaluate(lox, stmt->as.returnStmt.value);

      if (lox->currentFunction && lox->currentFunction->isInitializer) {
        runtimeError(lox, stmt->as.returnStmt.keyword,
                     "Can't return a value from an initializer.");
        return;
      }
    }

    lox->signal.type = SIGNAL_RETURN;
    lox->signal.returnValue = value;

    printf("RETURN ");
    printValue(value);
    printf("\n");

    return;
  }
  }

  lox->execDepth--;
}

void executeProgram(Lox *lox, Program *prog) {
  if (!prog)
    return;

  Resolver resolver = {0};

  for (u32 i = 0; i < prog->count; i++) {
    resolveStmt(&resolver, lox, prog->statements[i]);
  }

  if (lox->hadError || lox->hadRuntimeError) {
    printf("Resolve error. No execution\n");
    return;
  }

  // Now execute statements, not recurse
  for (u32 i = 0; i < prog->count; i++) {
    executeStmt(lox, prog->statements[i]);

    if (lox->hadError || lox->hadRuntimeError) {
      return;
    }
  }
}
