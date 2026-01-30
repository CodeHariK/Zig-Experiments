#define WRITE_TO(addr, value) (*((volatile unsigned int *)(addr)) = value)
#define RAM_START 0x20000000

int sideEffect() {
  WRITE_TO(RAM_START, 0xAE0);

  return 0xAE4;
}

int main() {
  int result = sideEffect();

  WRITE_TO(RAM_START + 4, result);
  WRITE_TO(RAM_START + 8, 0xAE8);

  return 0;
}
