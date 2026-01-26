#ifndef CPU_H
#define CPU_H
#include <stdint.h>

typedef enum { MODE_USER = 0, MODE_SUPERVISOR = 1 } Mode;

typedef struct {
  uint64_t x[32];
  uint64_t pc;
  uint64_t stvec;
  uint64_t sepc;
  uint64_t scause;
  uint64_t sstatus;
  Mode mode;
} CPU;

void cpu_init(CPU *cpu);
const char *scause_to_str(uint64_t scause);
/* Debug helper to dump state */
void cpu_dump(const CPU *cpu);

#endif // CPU_H
