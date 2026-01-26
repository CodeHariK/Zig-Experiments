#ifndef EMULATOR_H
#define EMULATOR_H

#include "cpu.h"
#include <stddef.h>

/*
 * The Bus / Memory interface.
 * For this tiny emulator, we can just have a fixed size memory array.
 * We treat 0x0 as the start of RAM.
 */
#define DRAM_SIZE (1024 * 1024) // 1MB RAM

typedef struct {
  CPU cpu;
  uint8_t dram[DRAM_SIZE];
} Emulator;

void emu_init(Emulator *emu);
bool emu_step(Emulator *emu); // Returns false if halted/error
void emu_load_program(Emulator *emu, const uint8_t *code, size_t size);

#endif
