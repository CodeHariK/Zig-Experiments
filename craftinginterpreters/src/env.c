#include "lox.h"
#include <stdlib.h>
#include <string.h>

Environment *envNew(Environment *enclosing) {
  Environment *env = malloc(sizeof(Environment));
  if (!env)
    exit(1);

  *env = (Environment){
      .entries = malloc(sizeof(EnvKV) * 8),
      .count = 0,
      .capacity = 8,
      .enclosing = enclosing,
  };

  return env;
}

void envFree(Environment *env) {
  free(env->entries);
  free(env);
}

void envDefine(Environment *env, Lox *lox, const char *name, Value value) {
  /* If the key already exists in this environment, overwrite it instead
     of appending a duplicate entry. This ensures assignments to fields and
     variables update the previous value as expected. */
  for (u32 i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      env->entries[i].value = value;

      printEnv(lox, name, value, "overwrite");
      return;
    }
  }

  if (env->count >= env->capacity) {
    env->capacity *= 2;
    env->entries = realloc(env->entries, sizeof(EnvKV) * env->capacity);
  }

  env->entries[env->count] = (EnvKV){
      .key = strdup(name),
      .value = value,
  };

  env->count++;

  printEnv(lox, name, value, "define");
}

static Environment *envAncestor(Environment *env, int depth) {
  Environment *current = env;
  for (int i = 0; i < depth; i++) {
    if (!current) {
      return NULL;
    }
    current = current->enclosing;
  }
  return current;
}

bool envGet(Environment *env, const char *name, Value *out) {
  for (u32 i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      *out = env->entries[i].value;
      return true;
    }
  }
  return false;
}

Value envGetAt(Environment *env, int depth, const char *name) {
  if (depth < 0) {
    return NIL_VALUE;
  }

  Environment *target = envAncestor(env, depth);
  if (!target) {
    return NIL_VALUE;
  }

  for (u32 i = 0; i < target->count; i++) {
    if (strcmp(target->entries[i].key, name) == 0) {
      return target->entries[i].value;
    }
  }

  return NIL_VALUE;
}

static bool envGetGlobal(Environment *env, const char *name, Value *out) {
  while (env->enclosing) {
    env = env->enclosing;
  }

  for (u32 i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      if (out) {
        *out = env->entries[i].value;
      }
      return true;
    }
  }

  return false; // not found
}

bool envAssign(Lox *lox, Environment *env, const char *name, Value value) {
  for (u32 i = 0; i < env->count; i++) {
    if (strcmp(env->entries[i].key, name) == 0) {
      env->entries[i].value = value;

      printEnv(lox, name, value, "assign");

      return true;
    }
  }

  if (env->enclosing) {
    return envAssign(lox, env->enclosing, name, value);
  }

  return false;
}

static bool envAssignAt(Environment *env, int depth, const char *name,
                        Value value) {
  Environment *target = envAncestor(env, depth);
  if (!target)
    return false;

  for (u32 i = 0; i < target->count; i++) {
    if (strcmp(target->entries[i].key, name) == 0) {
      target->entries[i].value = value;
      return true;
    }
  }
  return false;
}

static void resolveLocal(Resolver *r, Expr *expr, Token name) {
  for (i32 i = r->scopeCount - 1; i >= 0; i--) {
    ResolverScope *scope = &r->scopes[i];

    for (i32 j = 0; j < scope->varCount; j++) {
      if (strcmp(scope->vars[j].name, name.lexeme) == 0) {
        i32 depth = r->scopeCount - 1 - i;

        if (expr->type == EXPR_VARIABLE) {
          expr->as.var.depth = depth;
        } else if (expr->type == EXPR_ASSIGN) {
          expr->as.assign.depth = depth;
        } else if (expr->type == EXPR_THIS) {
          expr->as.thisExpr.depth = depth;
        } else if (expr->type == EXPR_SUPER) {
          /* For 'super', the depth we store should allow us to locate the
             "this" binding at runtime. Because the bound method creates an
             extra environment (that holds 'this') that will be one ancestor
             above the environment that contains 'super', subtract 1 from
             the computed depth here so envGetAt(..., depth, "this") will
             find the instance. */
          expr->as.superExpr.depth = depth - 1;
        }
        return;
      }
    }
  }
}

static void resolveExpr(Resolver *r, Lox *lox, Expr *expr) {
  if (!expr)
    return;

  switch (expr->type) {

  case EXPR_LITERAL:
    break;

  case EXPR_GROUPING: {
    resolveExpr(r, lox, expr->as.grouping.expression);
    break;
  }

  case EXPR_UNARY: {
    resolveExpr(r, lox, expr->as.unary.right);
    break;
  }

  case EXPR_BINARY: {
    resolveExpr(r, lox, expr->as.binary.left);
    resolveExpr(r, lox, expr->as.binary.right);
    break;
  }
  case EXPR_LOGICAL: {
    resolveExpr(r, lox, expr->as.logical.left);
    resolveExpr(r, lox, expr->as.logical.right);
    break;
  }

  case EXPR_VARIABLE: {
    if (r->scopeCount > 0) {
      ResolverScope *scope = &r->scopes[r->scopeCount - 1];
      for (i32 i = 0; i < scope->varCount; i++) {
        if (strcmp(scope->vars[i].name, expr->as.var.name.lexeme) == 0 &&
            !scope->vars[i].defined) {
          reportError(lox, expr->as.var.name.line, "",
                      "Can't read local variable in its own initializer.");
        }
      }
    }

    resolveLocal(r, expr, expr->as.var.name);
    break;
  }

  case EXPR_ASSIGN: {
    // a = value;
    resolveExpr(r, lox, expr->as.assign.value);
    resolveLocal(r, expr, expr->as.assign.name);
    break;
  }

  case EXPR_CALL: {
    resolveExpr(r, lox, expr->as.call.callee);
    for (i32 i = 0; i < expr->as.call.argCount; i++) {
      resolveExpr(r, lox, expr->as.call.arguments[i]);
    }
    break;
  }

  case EXPR_GET:
    resolveExpr(r, lox, expr->as.getExpr.object);
    break;
  case EXPR_SET:
    // this.x = value;  or  obj.x = value;
    resolveExpr(r, lox, expr->as.setExpr.object);
    resolveExpr(r, lox, expr->as.setExpr.value);
    break;
  case EXPR_THIS: {
    if (r->scopeCount == 0) {
      reportError(lox, expr->as.thisExpr.keyword.line, "",
                  "Can't use 'this' outside of a class.");
      return;
    }
    resolveLocal(r, expr, expr->as.thisExpr.keyword);
    break;
  }

  case EXPR_SUPER: {
    if (r->currentClass == CLASS_NONE) {
      reportError(lox, expr->as.superExpr.keyword.line, "",
                  "Can't use 'super' outside of a class.");
    } else if (r->currentClass != CLASS_SUBCLASS) {
      reportError(lox, expr->as.superExpr.keyword.line, "",
                  "Can't use 'super' in a class with no superclass.");
    }

    resolveLocal(r, expr, expr->as.superExpr.keyword);
    break;
  }
  }
}

static void beginScope(Resolver *r) {
  r->scopes[r->scopeCount].varCount = 0;
  r->scopeCount++;
}

static void endScope(Resolver *r) { r->scopeCount--; }

static void declareVar(Resolver *r, Lox *lox, Token name) {
  if (r->scopeCount == 0)
    return;

  ResolverScope *scope = &r->scopes[r->scopeCount - 1];

  for (i32 i = 0; i < scope->varCount; i++) {
    if (strcmp(scope->vars[i].name, name.lexeme) == 0) {
      reportError(lox, name.line, "",
                  "Variable already declared in this scope.");
      return;
    }
  }

  scope->vars[scope->varCount++] = (ResolverVar){
      .name = name.lexeme,
      .defined = false,
  };
}

static void defineVar(Resolver *r) {
  if (r->scopeCount == 0)
    return;

  ResolverScope *scope = &r->scopes[r->scopeCount - 1];
  scope->vars[scope->varCount - 1].defined = true;
}

static void declareThis(Resolver *r) {
  if (r->scopeCount == 0)
    return;

  ResolverScope *scope = &r->scopes[r->scopeCount - 1];
  scope->vars[scope->varCount++] = (ResolverVar){
      .name = "this",
      .defined = true,
  };
}

void resolveStmt(Resolver *r, Lox *lox, Stmt *stmt) {
  if (!stmt)
    return;

  switch (stmt->type) {

  case STMT_EXPR:
    resolveExpr(r, lox, stmt->as.expr);
    break;

  case STMT_PRINT:
    resolveExpr(r, lox, stmt->as.expr_print);
    break;

  case STMT_VAR:
    declareVar(r, lox, stmt->as.var.name);

    if (stmt->as.var.initializer)
      resolveExpr(r, lox, stmt->as.var.initializer);

    defineVar(r);
    break;

  case STMT_BLOCK:
    beginScope(r);

    for (i32 i = 0; i < stmt->as.block.count; i++) {
      resolveStmt(r, lox, stmt->as.block.statements[i]);
    }

    endScope(r);
    break;

  case STMT_IF:
    resolveExpr(r, lox, stmt->as.ifStmt.condition);
    resolveStmt(r, lox, stmt->as.ifStmt.then_branch);
    if (stmt->as.ifStmt.else_branch)
      resolveStmt(r, lox, stmt->as.ifStmt.else_branch);
    break;

  case STMT_WHILE:
    resolveExpr(r, lox, stmt->as.whileStmt.condition);
    resolveStmt(r, lox, stmt->as.whileStmt.body);
    break;

  case STMT_FOR:
    if (stmt->as.forStmt.condition)
      resolveExpr(r, lox, stmt->as.forStmt.condition);
    if (stmt->as.forStmt.increment)
      resolveExpr(r, lox, stmt->as.forStmt.increment);
    resolveStmt(r, lox, stmt->as.forStmt.body);
    break;

  case STMT_FUNCTION:
    // Declare function name in enclosing scope
    declareVar(r, lox, stmt->as.functionStmt.name);
    defineVar(r);

    // Resolve function body in its own scope
    beginScope(r);

    for (u8 i = 0; i < stmt->as.functionStmt.paramCount; i++) {
      declareVar(r, lox, stmt->as.functionStmt.params[i]);
      defineVar(r);
    }

    resolveStmt(r, lox, stmt->as.functionStmt.body);

    endScope(r);
    break;

  case STMT_CLASS:
    ClassType enclosingClass = r->currentClass;
    r->currentClass = CLASS_CLASS;

    if (stmt->as.classStmt.superclass) {
      r->currentClass = CLASS_SUBCLASS;

      resolveExpr(r, lox, stmt->as.classStmt.superclass);

      beginScope(r);

      ResolverScope *scope = &r->scopes[r->scopeCount - 1];
      scope->vars[scope->varCount++] =
          (ResolverVar){.name = "super", .defined = true};
    }

    declareVar(r, lox, stmt->as.classStmt.name);
    defineVar(r);

    beginScope(r);  // for methods
    declareThis(r); // mark "this" valid

    for (int i = 0; i < stmt->as.classStmt.methodCount; i++) {
      resolveStmt(r, lox, stmt->as.classStmt.methods[i]);
    }

    endScope(r);

    if (stmt->as.classStmt.superclass) {
      endScope(r);
    }

    r->currentClass = enclosingClass;

    break;

  case STMT_RETURN:
    if (r->scopeCount == 0) {
      reportError(lox, stmt->as.returnStmt.keyword.line, "",
                  "Can't return from top-level code.");
    }

    if (stmt->as.returnStmt.value)
      resolveExpr(r, lox, stmt->as.returnStmt.value);
    break;

  case STMT_BREAK:
  case STMT_CONTINUE:
    // Syntax validity is already handled via loopDepth in parser
    break;
  }
}

Value evalVariable(Lox *lox, Expr *expr) {
  Value result;

  printExpr(lox, expr, NO_VALUE, lox->indent, true, "");

  if (expr->as.var.depth != -1) {
    // Local or non-global resolved by resolver
    result = envGetAt(lox->env, expr->as.var.depth, expr->as.var.name.lexeme);
  } else {
    // Global
    if (!envGetGlobal(lox->env, expr->as.var.name.lexeme, &result)) {
      return errorValue(lox, &expr->as.var.name, NULL, "Undefined variable",
                        true);
    }
  }

  printExpr(lox, expr, result, lox->indent + 1, true, "envget ");
  return result;
}

Value evalAssign(Lox *lox, Expr *expr) {
  Value result = evaluate(lox, expr->as.assign.value);

  if (expr->as.assign.depth != -1) {
    envAssignAt(lox->env, expr->as.assign.depth, expr->as.assign.name.lexeme,
                result);
  } else {
    if (!envAssign(lox, lox->env, expr->as.assign.name.lexeme, result)) {
      return errorValue(lox, &expr->as.assign.name, NULL, "Undefined variable",
                        true);
    }
  }

  return result;
}

Value evalGet(Lox *lox, Expr *expr) {

  printExpr(lox, expr, NO_VALUE, lox->indent, true, "");

  Value obj = evaluate(lox, expr->as.getExpr.object);

  if (obj.type != VAL_INSTANCE) {
    return errorValue(lox, &expr->as.getExpr.name, NULL,
                      "Only instances have properties, Invalid access", true);
  }

  LoxInstance *inst = obj.as.instance;

  Value value;
  if (envGet(inst->fields, expr->as.getExpr.name.lexeme, &value)) {
    printExpr(lox, expr, value, lox->indent, true, "[EVAL_GET] ");
    return value;
  }

  if (envGet(inst->class->methodsEnv, expr->as.getExpr.name.lexeme, &value)) {
    Value bound_method = bindMethod(lox, value, inst);
    return bound_method;
  }

  return errorValue(lox, &expr->as.getExpr.name, NULL, "Undefined property",
                    true);
}

Value evalSet(Lox *lox, Expr *expr) {
  printExpr(lox, expr, NO_VALUE, lox->indent, true, "[EVAL_SET] ");

  Value obj = evaluate(lox, expr->as.setExpr.object);

  if (obj.type != VAL_INSTANCE) {
    return errorValue(lox, &expr->as.setExpr.name, NULL,
                      "Only instances have fields, Invalid set", true);
  }

  Value value = evaluate(lox, expr->as.setExpr.value);

  envDefine(obj.as.instance->fields, lox, expr->as.setExpr.name.lexeme, value);

  // printExpr(lox, expr, value, lox->indent, true, "[EVAL_SET] ");
  return value;
}

Value evalSuper(Lox *lox, Expr *expr) {
  printExpr(lox, expr, NO_VALUE, lox->indent, true, "[> EVAL_SUPER] ");

  // 1. Get `this`
  Value thisVal = envGetAt(lox->env, expr->as.superExpr.depth, "this");

  if (thisVal.type != VAL_INSTANCE) {
    return errorValue(lox, &expr->as.superExpr.keyword, expr,
                      "Invalid 'this' binding.", true);
  }

  LoxInstance *instance = thisVal.as.instance;

  // 2. Get superclass from the class, NOT the environment
  LoxClass *superclass = instance->class->superclass;

  if (!superclass) {
    return errorValue(lox, &expr->as.superExpr.keyword, expr,
                      "Invalid superclass.", true);
  }

  // 3. Look up method on superclass
  Value method;
  if (!envGet(superclass->methodsEnv, expr->as.superExpr.method.lexeme,
              &method)) {
    return errorValue(lox, &expr->as.superExpr.method, expr,
                      "Undefined property on superclass", true);
  }

  // 4. Bind to instance
  Value bound = bindMethod(lox, method, instance);

  printExpr(lox, expr, bound, lox->indent, true, "[EVAL_SUPER] ");
  return bound;
}
