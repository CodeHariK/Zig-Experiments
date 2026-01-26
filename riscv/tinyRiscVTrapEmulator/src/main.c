#include "cpu.h"
#include "emulator.h"
#include <stdio.h>

int main() {
  printf("RISC-V Trap Emulator initializing...\n");

  Emulator emu;
  emu_init(&emu);

  // Manual "Assembly"
  // ADDI x1, x0, 10  (0x00A00093)
  // ADDI x2, x1, 5   (0x00508113)
  // ECALL            (0x00000073)
  uint32_t program[] = {
      0x00A00093, // ADDI x1, x0, 10
      //
      0x00508113, // ADDI x2, x1, 5
      //
      0x00000073, // ECALL
      //
      0x00000000 // halt
  };

  emu_load_program(&emu, (uint8_t *)program, sizeof(program));

  printf("Initial State:\n");
  cpu_dump(&emu.cpu);

  printf("\nRunning...\n");
  while (emu_step(&emu)) {
    cpu_dump(&emu.cpu);
  }

  printf("Done.\n");
  return 0;
}
