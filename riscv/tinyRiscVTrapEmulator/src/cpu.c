#include "cpu.h"
#include <stdio.h>
#include <string.h>

void cpu_init(CPU *cpu) {
  memset(cpu, 0, sizeof(*cpu));
  cpu->pc = 0;
  cpu->mode = MODE_USER;
  cpu->stvec = 0;
}

const char *scause_to_str(uint64_t scause) {
  switch (scause) {
  case 8:
    return "ECALL from U-mode";
  case 9:
    return "ECALL from S-mode";
  default:
    return "UNKNOWN";
  }
}

void cpu_dump(const CPU *cpu) {
  printf("CPU State:\n");
  printf("  PC: %016llx  Mode: %s\n", cpu->pc,
         cpu->mode == MODE_USER ? "USER" : "SUPERVISOR");

  printf("  Registers:\n");
  for (int i = 0; i < 32; i += 4) {
    printf(
        "    x%02d: %016llx  x%02d: %016llx  x%02d: %016llx  x%02d: %016llx\n",
        i, cpu->x[i],
        //
        i + 1, cpu->x[i + 1],
        //
        i + 2, cpu->x[i + 2],
        //
        i + 3, cpu->x[i + 3]);
  }

  printf("  CSRs:\n");
  printf("    stvec:   %016llx (Trap Vector Base)\n", cpu->stvec);
  printf("    sepc:    %016llx (Exception PC)\n", cpu->sepc);
  printf("    scause:  %016llx (Trap Cause)\n", cpu->scause);
  printf("    sstatus: %016llx (Status)\n", cpu->sstatus);
}
