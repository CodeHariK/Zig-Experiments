#include "clox.h"

inline Value BOOL_VAL(bool value) {
  Value v;
  v.type = VAL_BOOL;
  v.as.boolean = value;
  return v;
}

Value NIL_VAL = {VAL_NIL, {.boolean = false}};

inline Value NUMBER_VAL(double value) {
  Value v;
  v.type = VAL_NUMBER;
  v.as.number = value;
  return v;
}

inline bool AS_BOOL(Value value) { return value.as.boolean; }

inline double AS_NUMBER(Value value) { return value.as.number; }

inline bool IS_BOOL(Value value) { return value.type == VAL_BOOL; }

inline bool IS_NIL(Value value) { return value.type == VAL_NIL; }

inline bool IS_NUMBER(Value value) { return value.type == VAL_NUMBER; }
