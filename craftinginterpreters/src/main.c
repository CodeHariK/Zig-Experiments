#include "lox.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {

  Lox lox;
  loxInit(&lox);

  if (argc > 2) {
    printf("Usage: lox [script]\n");
    return 64;
  } else if (argc == 2) {
    loxRunFile(&lox, argv[1]);
  } else {
    loxRunPrompt(&lox);
  }

  return 0;
}
