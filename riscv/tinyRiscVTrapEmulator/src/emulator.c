#include "emulator.h"
#include <stdio.h>
#include <string.h>

void emu_init(Emulator *emu) {
  cpu_init(&emu->cpu);
  memset(emu->dram, 0, DRAM_SIZE);
}

void emu_load_program(Emulator *emu, const uint8_t *code, size_t size) {
  if (size > DRAM_SIZE) {
    fprintf(stderr, "Program too large for RAM\n");
    return;
  }
  memcpy(emu->dram, code, size);
}

/*
 * Fetch-Decode-Execute Cycle
 */
bool emu_step(Emulator *emu) {
  CPU *cpu = &emu->cpu;

  // 1. Fetch
  if (cpu->pc >= DRAM_SIZE) {
    printf("PC out of bounds: %016llx\n", cpu->pc);
    return false;
  }

  // RISC-V instructions are 32-bit (4 bytes)
  uint32_t inst = *(uint32_t *)&emu->dram[cpu->pc];

  // 2. Decode
  uint32_t opcode = inst & 0x7F;        // opcode is in bits [6:0]
  uint32_t rd = (inst >> 7) & 0x1F;     // destination register [11:7]
  uint32_t funct3 = (inst >> 12) & 0x7; // funct3 [14:12]
  uint32_t rs1 = (inst >> 15) & 0x1F;   // source register 1 [19:15]
  // I-type immediate (sign extended)
  int32_t imm_i = (int32_t)inst >> 20; // bits [31:20]

  printf("\n--------------\nopcode=%02x rd=%02x funct3=%x rs1=%02x imm_i=%d\n",
         opcode, rd, funct3, rs1, imm_i);

  // 3. Execute
  if (inst == 0) {
    printf("Halt hit at %016llx\n", cpu->pc);
    return false;
  }

  bool executed = false;
  switch (opcode) {
  case 0x13:           // OP-IMM (ADDI, etc)
    if (funct3 == 0) { // ADDI
      uint64_t val = (rs1 == 0 ? 0 : cpu->x[rs1]) + (int64_t)imm_i;
      if (rd != 0)
        cpu->x[rd] = val;
      executed = true;
    }
    break;
  case 0x73:                  // SYSTEM
    if (inst == 0x00000073) { // ECALL
      printf("ECALL triggered at PC=%016llx\n", cpu->pc);
      executed = true;
    }
    break;
  }

  if (!executed) {
    printf("Unknown instruction %08x at %016llx\n", inst, cpu->pc);
    return false;
  }

  // Update PC
  cpu->pc += 4;
  return true;
}
