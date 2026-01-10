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

static void execIfStmt(Lox *lox, Stmt *stmt) {
  indentPrint(lox->indent);
  printf("IF\n");
  if (isTruthy(evaluate(lox, stmt->as.ifStmt.condition))) {
    executeStmt(lox, stmt->as.ifStmt.then_branch);
  } else if (stmt->as.ifStmt.else_branch) {
    executeStmt(lox, stmt->as.ifStmt.else_branch);
  }

  if (lox->signal.type == SIGNAL_BREAK) {
    return;
  }
}

static void execWhileStmt(Lox *lox, Stmt *stmt) {
  indentPrint(lox->indent);
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
}

static void execForStmt(Lox *lox, Stmt *stmt) {
  indentPrint(lox->indent);
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
}

static void execClassStmt(Lox *lox, Stmt *stmt) {
  printf("@%d: Class %s\n", stmt->line, stmt->as.classStmt.name.lexeme);

  // 1. Define class name early (allows self-reference)
  envDefine(lox->env, lox, stmt->as.classStmt.name.lexeme, NIL_VALUE);

  // 2. Evaluate superclass if present
  Value superclassVal = NIL_VALUE;
  if (stmt->as.classStmt.superclass) {
    superclassVal = evaluate(lox, stmt->as.classStmt.superclass);

    if (superclassVal.type != VAL_CLASS) {
      runtimeError(lox, &stmt->as.classStmt.superclass->as.var.name, NULL,
                   "Superclass must be a class.");
      return;
    }
  }

  // 3. Create temporary env for 'super'
  if (stmt->as.classStmt.superclass) {
    Environment *prevEnv = lox->env;
    lox->env = envNew(prevEnv);
    envDefine(lox->env, lox, "super", superclassVal);
    lox->env = prevEnv;
  }

  // 4. Create class object
  LoxClass *klass = arenaAlloc(&lox->astArena, sizeof(LoxClass));
  klass->name = stmt->as.classStmt.name;
  klass->methodsEnv = envNew(NULL);
  klass->superclass =
      stmt->as.classStmt.superclass ? superclassVal.as.klass : NULL;

  // 5. Define methods
  for (int i = 0; i < stmt->as.classStmt.methodCount; i++) {
    Stmt *method = stmt->as.classStmt.methods[i];
    Value fnValue = makeFunction(lox, method, true);
    envDefine(klass->methodsEnv, lox, fnValue.as.function->name.lexeme,
              fnValue);
  }

  // 6. Assign class value
  Value classValue;
  classValue.type = VAL_CLASS;
  classValue.as.klass = klass;

  envAssign(lox, lox->env, stmt->as.classStmt.name.lexeme, classValue);
  printf("--------\n");
}

static void execReturnStmt(Lox *lox, Stmt *stmt) {
  Value value = NIL_VALUE;

  if (stmt->as.returnStmt.value) {
    value = evaluate(lox, stmt->as.returnStmt.value);

    if (lox->currentFunction && lox->currentFunction->isInitializer) {
      runtimeError(lox, &stmt->as.returnStmt.keyword, NULL,
                   "Can't return a value from an initializer.");
      return;
    }
  }

  lox->signal.type = SIGNAL_RETURN;
  lox->signal.returnValue = value;

  printStmt(lox, stmt, value, lox->indent);
}

void executeStmt(Lox *lox, Stmt *stmt) {

  if (!stmt)
    return;

  if (stmt->type != STMT_BLOCK && stmt->type != STMT_EXPR &&
      stmt->type != STMT_PRINT) {
    lox->indent++;
  }

  switch (stmt->type) {
  case STMT_PRINT: {

    Value result = evaluate(lox, stmt->as.expr_print);

    char buf[64];
    valueToString(result, buf, sizeof(buf));

    loxAppendOutput(lox, buf);
    loxAppendOutput(lox, "\n");

    printStmt(lox, stmt, result, lox->indent);

    break;
  }

  case STMT_EXPR: {
    Value val = evaluate(lox, stmt->as.expr);
    printStmt(lox, stmt, val, 0);
    break;
  }

  case STMT_VAR: {
    Value val = UNDEFINED_VALUE;
    if (stmt->as.var.initializer) {
      val = evaluate(lox, stmt->as.var.initializer);
    }

    printStmt(lox, stmt, val, 0);
    if (val.type != UNDEFINED_VALUE.type) {
      envDefine(lox->env, lox, stmt->as.var.name.lexeme, val);
    }

    break;
  }

  case STMT_BLOCK: {
    executeBlock(lox, stmt->as.block.statements, stmt->as.block.count);
    break;
  }

  case STMT_IF: {
    execIfStmt(lox, stmt);
    break;
  }
  case STMT_WHILE: {
    execWhileStmt(lox, stmt);
    break;
  }
  case STMT_FOR: {
    execForStmt(lox, stmt);
    break;
  }

  case STMT_FUNCTION: {
    Value fnValue = makeFunction(lox, stmt, false);
    envDefine(lox->env, lox, fnValue.as.function->name.lexeme, fnValue);

    indentPrint(lox->indent);
    printf("@%d Fn %s\n", stmt->line, stmt->as.functionStmt.name.lexeme);
    break;
  }

  case STMT_CLASS: {
    execClassStmt(lox, stmt);
    break;
  }

  case STMT_BREAK: {
    lox->signal.type = SIGNAL_BREAK;
    indentPrint(lox->indent);
    printf("BREAK\n");
    break;
  }
  case STMT_CONTINUE: {
    lox->signal.type = SIGNAL_CONTINUE;
    indentPrint(lox->indent);
    printf("CONTINUE\n");
    break;
  }
  case STMT_RETURN: {
    execReturnStmt(lox, stmt);
    break;
  }
  }

  if (stmt->type != STMT_BLOCK && stmt->type != STMT_EXPR &&
      stmt->type != STMT_PRINT) {
    lox->indent--;
  }
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
