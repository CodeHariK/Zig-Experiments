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

  while (!lox->hadRuntimeError && !lox->hadError) {

    if (stmt->as.forStmt.condition &&
        !isTruthy(evaluate(lox, stmt->as.forStmt.condition))) {
      break;
    }

    executeStmt(lox, stmt->as.whileStmt.body);

    if (lox->signal.type == SIGNAL_BREAK) {
      lox->signal.type = SIGNAL_NONE;
      break;
    }

    if (lox->signal.type == SIGNAL_CONTINUE) {
      lox->signal.type = SIGNAL_NONE;
      // continue;
    }

    printf("---\n");
  }
}

static void execForStmt(Lox *lox, Stmt *stmt) {

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

    printf("---\n");
  }
}

static void execFuncstmt(Lox *lox, Environment *parent, Stmt *func,
                         bool isClass) {

  LoxFunction *fn = arenaAlloc(&lox->astArena, sizeof(LoxFunction));
  fn->name = func->as.functionStmt.name;
  fn->params = func->as.functionStmt.params;
  fn->paramCount = func->as.functionStmt.paramCount;
  fn->body = func->as.functionStmt.body;
  fn->closure = lox->env;
  if (isClass) {
    fn->isInitializer = strcmp(fn->name.lexeme, "init") == 0;
  } else {
    fn->isInitializer = false;
  }

  envDefine(parent, lox, fn->name.lexeme,
            (Value){.type = VAL_FUNCTION, .as.function = fn});
}

static void execClassStmt(Lox *lox, Stmt *stmt) {

  // Evaluate superclass if present
  Value superclassVal = NIL_VALUE;
  if (stmt->as.classStmt.superclass) {
    superclassVal = evaluate(lox, stmt->as.classStmt.superclass);

    if (superclassVal.type != VAL_CLASS) {
      runtimeError(lox, &stmt->as.classStmt.superclass->as.var.name, NULL,
                   "Superclass must be a class.");
      return;
    }

    Environment *prevEnv = lox->env;
    lox->env = envNew(prevEnv);
    envDefine(lox->env, lox, "super", superclassVal);
    lox->env = prevEnv;
  }

  LoxClass *klass = arenaAlloc(&lox->astArena, sizeof(LoxClass));
  klass->name = stmt->as.classStmt.name;
  klass->methodsEnv = envNew(NULL);
  klass->superclass =
      stmt->as.classStmt.superclass ? superclassVal.as.klass : NULL;
  for (int i = 0; i < stmt->as.classStmt.methodCount; i++) {
    Stmt *method = stmt->as.classStmt.methods[i];
    execFuncstmt(lox, klass->methodsEnv, method, true);
  }

  envDefine(lox->env, lox, stmt->as.classStmt.name.lexeme,
            (Value){
                .type = VAL_CLASS,
                .as.klass = klass,
            });
  printf("---\n");
}

static void execReturnStmt(Lox *lox, Stmt *stmt) {
  Value value = NIL_VALUE;

  if (stmt->as.returnStmt.value) {
    if (lox->currentFunction && lox->currentFunction->isInitializer) {
      runtimeError(lox, &stmt->as.returnStmt.keyword, NULL,
                   "Can't return a value from an initializer.");
      return;
    }

    value = evaluate(lox, stmt->as.returnStmt.value);
  }

  lox->signal.type = SIGNAL_RETURN;
  lox->signal.returnValue = value;
}

void executeStmt(Lox *lox, Stmt *stmt) {

  if (!stmt)
    return;

  printStmt(lox, stmt, NO_VALUE, lox->indent, false);

  switch (stmt->type) {
  case STMT_PRINT: {

    Value result = evaluate(lox, stmt->as.expr_print);

    char buf[64];
    valueToString(result, buf, sizeof(buf));

    loxAppendOutput(lox, buf);
    loxAppendOutput(lox, "\n");

    break;
  }

  case STMT_EXPR: {
    evaluate(lox, stmt->as.expr);
    break;
  }

  case STMT_VAR: {

    Value val = UNDEFINED_VALUE;
    if (stmt->as.var.initializer) {
      val = evaluate(lox, stmt->as.var.initializer);
    }

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
    execFuncstmt(lox, lox->env, stmt, false);
    break;
  }

  case STMT_CLASS: {
    execClassStmt(lox, stmt);
    break;
  }

  case STMT_BREAK: {
    lox->signal.type = SIGNAL_BREAK;
    break;
  }
  case STMT_CONTINUE: {
    lox->signal.type = SIGNAL_CONTINUE;
    break;
  }
  case STMT_RETURN: {
    execReturnStmt(lox, stmt);
    break;
  }
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
