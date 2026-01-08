#include "lox.h"

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
    printf("BLOCK\n");
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
    printf("FUNCTION\n");

    LoxFunction *fn = arenaAlloc(&lox->astArena, sizeof(LoxFunction));

    fn->name = stmt->as.functionStmt.name;
    fn->params = stmt->as.functionStmt.params;
    fn->paramCount = stmt->as.functionStmt.paramCount;
    fn->body = stmt->as.functionStmt.body;
    fn->closure = lox->env; // 🔥 closure captured here

    Value fnValue = makeFunction(fn);
    envDefine(lox->env, lox, fn->name.lexeme, fnValue);

    break;
  }

  case STMT_CLASS: {
    printf("CLASS\n");

    LoxClass *klass = arenaAlloc(&lox->astArena, sizeof(LoxClass));
    klass->name = stmt->as.classStmt.name;
    klass->methods = envNew(NULL);

    for (int i = 0; i < stmt->as.classStmt.methodCount; i++) {
      Stmt *method = stmt->as.classStmt.methods[i];

      LoxFunction *fn = arenaAlloc(&lox->astArena, sizeof(LoxFunction));
      fn->name = method->as.functionStmt.name;
      fn->params = method->as.functionStmt.params;
      fn->paramCount = method->as.functionStmt.paramCount;
      fn->body = method->as.functionStmt.body;
      fn->closure = lox->env;

      envDefine(klass->methods, lox, fn->name.lexeme, makeFunction(fn));
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
    }

    lox->signal.type = SIGNAL_RETURN;
    lox->signal.returnValue = value;

    printf("RETURN");
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
