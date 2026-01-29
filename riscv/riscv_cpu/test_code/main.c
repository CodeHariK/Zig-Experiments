#define WRITE_TO(addr, value) (*((volatile unsigned int *)(addr)) = value)
#define RAM_START 0x20000000

int fortyTwoWithSideEffects() {
  WRITE_TO(RAM_START, 0x30040f00);

  return 42;
}

int main() {
  int result = fortyTwoWithSideEffects();

  WRITE_TO(RAM_START + 4, result);

  return 0;
}
