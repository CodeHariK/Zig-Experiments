#define WRITE_TO(addr, value) (*((volatile unsigned int *)(addr)) = value)
#define RAM_START 0x20000000

int sideEffect() {
  WRITE_TO(RAM_START, 0xAE0);

  return 0xAE4;
}

void branchTest() {
  int a = 4;
  int b = 5;
  if (a <= b)
    WRITE_TO(RAM_START + 8, 0xBE0);
  else
    WRITE_TO(RAM_START + 8, 0xBE4);
}

int main() {
  int result = sideEffect();

  WRITE_TO(RAM_START + 4, result);

  branchTest();

  int i = 0;
  while (i < 2) {
    WRITE_TO(RAM_START + 12 + 4 * i, 0xCE0 + i);
    i++;
  }

  return 0;
}
